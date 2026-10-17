import { test } from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import { createHmac } from 'node:crypto';
import WebSocket from 'ws';
import { createSignaling } from '../src/server.js';

async function fixture(t, options = {}) {
  const app = createSignaling(options);
  app.server.listen(0, '127.0.0.1'); await once(app.server, 'listening');
  t.after(() => app.close());
  async function client() {
    const ws = new WebSocket(`ws://127.0.0.1:${app.server.address().port}`);
    const queue = [], waiting = [];
    ws.on('message', data => { const m = JSON.parse(data); if (waiting.length) waiting.shift()(m); else queue.push(m); });
    await once(ws, 'open');
    return { ws, send: m => ws.send(JSON.stringify({ version: 1, ...m })), next: () => queue.length ? Promise.resolve(queue.shift()) : new Promise((resolve, reject) => { const timer = setTimeout(() => reject(Error('Message timeout')), 2000); waiting.push(m => { clearTimeout(timer); resolve(m); }); }) };
  }
  return { app, client };
}
test('room creation, sanitized names, case insensitive join, full and invalid rooms', async t => {
  const { client } = await fixture(t);
  const a = await client(), b = await client(), c = await client();
  a.send({ type: 'create_room', player_name: '<Host>' });
  const room = await a.next(); assert.match(room.room_code, /^[A-HJ-NP-Z2-9]{6}$/);
  b.send({ type: 'join_room', player_name: 'Guest', room_code: room.room_code.toLowerCase() });
  assert.equal((await b.next()).player_name, 'Host'); assert.equal((await a.next()).type, 'peer_joined');
  c.send({ type: 'join_room', player_name: 'Third', room_code: room.room_code }); assert.equal((await c.next()).code, 'room_full');
  c.send({ type: 'join_room', player_name: 'Third', room_code: 'ZZZZZZ' }); assert.equal((await c.next()).code, 'room_not_found');
});
test('active room codes are unique', async t => {
  const { client } = await fixture(t); const codes = new Set();
  for (let i = 0; i < 6; i++) { const c = await client(); c.send({ type: 'create_room', player_name: 'Test' }); codes.add((await c.next()).room_code); }
  assert.equal(codes.size, 6);
});
for (const role of ['host', 'guest']) test(`${role} disconnect closes room and notifies other peer`, async t => {
  const { app, client } = await fixture(t); const a = await client(), b = await client();
  a.send({ type: 'create_room', player_name: 'Host' }); const room = await a.next();
  b.send({ type: 'join_room', player_name: 'Guest', room_code: room.room_code }); await b.next(); await a.next();
  (role === 'host' ? a : b).ws.close();
  assert.equal((await (role === 'host' ? b : a).next()).type, 'peer_left'); assert.equal(app.rooms.size, 0);
});
test('schema validation, malformed JSON, protocol version, role checks and forwarding', async t => {
  const { client } = await fixture(t); const a = await client(), b = await client();
  a.ws.send('{'); assert.equal((await a.next()).code, 'bad_json');
  a.send({ version: 2, type: 'ping' }); assert.equal((await a.next()).code, 'bad_protocol');
  a.send({ type: 'execute' }); assert.equal((await a.next()).code, 'unknown_type');
  a.send({ type: 'create_room', player_name: 'Host' }); const room = await a.next();
  b.send({ type: 'join_room', player_name: 'Guest', room_code: room.room_code }); await b.next(); await a.next();
  a.send({ type: 'offer', sdp: 'offer-data', ignored: 'not forwarded' }); assert.deepEqual(await b.next(), { version: 1, type: 'offer', sdp: 'offer-data' });
  b.send({ type: 'answer', sdp: 'answer-data' }); assert.equal((await a.next()).sdp, 'answer-data');
  b.send({ type: 'offer', sdp: 'spoof' }); assert.equal((await b.next()).code, 'bad_sdp');
  for (const [from, to] of [[a,b], [b,a]]) { from.send({ type: 'ice_candidate', media: '0', index: 0, candidate: 'candidate:data' }); assert.equal((await to.next()).candidate, 'candidate:data'); }
  a.send({ type: 'ice_candidate', media: '0', index: '0', candidate: {} }); assert.equal((await a.next()).code, 'bad_ice');
});
test('expiry and temporary TURN REST credentials', async t => {
  let now = 1_700_000_000_000;
  const { app, client } = await fixture(t, { now: () => now, roomTTL: 1000, turnTTL: 60, turnSecret: 'test-only-secret', turnURLs: ['turn:localhost:3478'], stunURLs: ['stun:localhost:3478'] });
  const a = await client(); a.send({ type: 'create_room', player_name: 'Host' }); const room = await a.next();
  const credential = room.ice_servers[1]; assert.equal(Number(credential.username.split(':')[0]), now / 1000 + 60);
  assert.equal(credential.credential, createHmac('sha1', 'test-only-secret').update(credential.username).digest('base64'));
  now += 1001; app.sweep(); assert.equal((await a.next()).code, 'room_expired'); assert.equal(app.rooms.size, 0);
});
test('creation and join rate limits', async t => {
  const { client } = await fixture(t); const a = await client();
  for (let i = 0; i < 6; i++) { a.send({ type: 'create_room', player_name: 'Host' }); await a.next(); a.send({ type: 'close_room' }); }
  a.send({ type: 'create_room', player_name: 'Host' }); assert.equal((await a.next()).code, 'rate_limited');
  for (let i = 0; i < 20; i++) { a.send({ type: 'join_room', player_name: 'Guest', room_code: 'XXXXXX' }); assert.equal((await a.next()).code, 'room_not_found'); }
  a.send({ type: 'join_room', player_name: 'Guest', room_code: 'XXXXXX' }); assert.equal((await a.next()).code, 'rate_limited');
});
test('message size limit rejects oversized frames', async t => {
  const { client } = await fixture(t); const a = await client();
  const closed = once(a.ws, 'close');
  a.ws.send('x'.repeat(65537));
  assert.equal((await closed)[0], 1009);
});
test('display name schema and heartbeat messages', async t => {
  const { client } = await fixture(t); const a = await client();
  a.send({ type: 'create_room', player_name: {} }); assert.equal((await a.next()).code, 'bad_name');
  a.send({ type: 'ping' }); assert.equal((await a.next()).type, 'pong');
  a.ws.send(JSON.stringify({ version: 1, type: 'ping' }), { binary: true }); assert.equal((await a.next()).code, 'bad_protocol');
});
