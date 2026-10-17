import { test } from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import WebSocket from 'ws';
import { createSignaling } from '../src/server.js';
import { turnCredentials, parseSessionToken, issueSessionToken, tokenDigest, verifySessionToken } from '../src/credentials.js';

async function fixture(t, options = {}) {
  const events = [];
  const app = createSignaling({ ...options, logger: (event, fields) => events.push({ event, ...fields }) });
  app.server.listen(0, '127.0.0.1'); await once(app.server, 'listening');
  t.after(() => app.close());
  const base = `http://127.0.0.1:${app.server.address().port}`;
  async function client() {
    const ws = new WebSocket(base.replace('http:', 'ws:'));
    const queue = [], waiting = [];
    ws.on('message', data => { const message = JSON.parse(data); if (waiting.length) waiting.shift()(message); else queue.push(message); });
    await once(ws, 'open');
    return { ws, send: message => ws.send(JSON.stringify({ version: 1, ...message })), next: () => queue.length ? Promise.resolve(queue.shift()) : new Promise((resolve, reject) => { const timer = setTimeout(() => reject(Error('Response timed out')), 2000); waiting.push(message => { clearTimeout(timer); resolve(message); }); }) };
  }
  return { app, client, base, events };
}

test('known expected HMAC-SHA1 vector and TURN REST username', () => {
  const credentials = turnCredentials('test-shared-secret', 'test-peer', 1700000060);
  assert.equal(credentials.username, '1700000060:test-peer');
  assert.equal(credentials.credential, '4X2Oq2brQWSOJM0nLQN72osnYbg=');
});
test('session tokens have 256 bits, strict parsing, digest verification and expiration', () => {
  const token = issueSessionToken(), another = issueSessionToken();
  assert.equal(token.length, 43); assert.notEqual(token, another);
  assert.equal(parseSessionToken(token), token);
  for (const bad of [null, {}, '', 'x'.repeat(42), 'x'.repeat(44), '='.repeat(43), token + '\n']) assert.equal(parseSessionToken(bad), null);
  const digest = tokenDigest(token);
  assert(verifySessionToken(token, digest, 2000, 1999));
  assert(!verifySessionToken(token, digest, 2000, 2000));
  assert(!verifySessionToken(another, digest, 2000, 1999));
});
test('health and optional metrics expose no match contents', async t => {
  const { client, base } = await fixture(t, { metrics: true });
  const health = await (await fetch(base + '/health')).json();
  assert.equal(health.ok, true); assert.equal(health.protocol, 1);
  assert.equal(typeof health.uptime_seconds, 'number');
  const a = await client(); a.send({ type: 'create_room', player_name: 'PrivatePlayer' }); const room = await a.next();
  const response = await fetch(base + '/metrics'); const metrics = await response.json();
  assert.equal(metrics.active_rooms, 1); assert.equal(metrics.rooms_created, 1);
  assert(!JSON.stringify(metrics).includes(room.room_code)); assert(!JSON.stringify(metrics).includes('PrivatePlayer'));
});
test('metrics are disabled by default', async t => {
  const { base } = await fixture(t); assert.equal((await fetch(base + '/metrics')).status, 404);
});
test('credential renewal survives signaling disconnect, authenticates role, expires and never logs credentials', async t => {
  let now = 1700000000000;
  const { app, client, events } = await fixture(t, { now: () => now, turnTTL: 60, matchTTL: 120000, roomTTL: 1000, turnSecret: 'test-shared-secret', turnURLs: ['turn:localhost:3478'] });
  const a = await client(), b = await client();
  a.send({ type: 'create_room', player_name: 'Host', capabilities: ['credential_refresh'] }); const room = await a.next();
  assert(parseSessionToken(room.session_token)); assert.equal(room.turn_expires_at, 1700000060);
  b.send({ type: 'join_room', player_name: 'Guest', room_code: room.room_code, capabilities: ['credential_refresh'] }); const guest = await b.next(); await a.next();
  assert.notEqual(guest.session_token, room.session_token);
  now += 50000;
  b.send({ type: 'refresh_ice', room_code: room.room_code, session_token: guest.session_token });
  const renewed = await b.next(); assert.equal(renewed.type, 'ice_credentials'); assert.equal(renewed.turn_expires_at, 1700000110);
  const closing = once(a.ws, 'close'); a.ws.close(); await closing;
  assert.equal((await b.next()).type, 'signaling_unavailable'); assert.equal(app.rooms.size, 1);
  const resumedSignal = await client();
  resumedSignal.send({ type: 'refresh_ice', room_code: room.room_code, session_token: room.session_token });
  assert.equal((await resumedSignal.next()).type, 'ice_credentials');
  const attacker = await client();
  attacker.send({ type: 'refresh_ice', room_code: room.room_code, session_token: issueSessionToken() }); assert.equal((await attacker.next()).code, 'invalid_session');
  attacker.send({ type: 'refresh_ice', room_code: room.room_code, session_token: guest.session_token }); assert.equal((await attacker.next()).code, 'session_in_use');
  const serialized = JSON.stringify(events);
  for (const sensitive of [room.session_token, guest.session_token, room.ice_servers[0].credential, 'test-shared-secret']) assert(!serialized.includes(sensitive));
  now += 70001; app.sweep(); assert.equal(app.rooms.size, 0);
  resumedSignal.send({ type: 'refresh_ice', room_code: room.room_code, session_token: room.session_token });
  assert.equal((await resumedSignal.next()).type, 'error'); // queued room_expired
  assert.equal((await resumedSignal.next()).code, 'invalid_session');
});
test('explicit leave revokes both match capabilities', async t => {
  const { app, client } = await fixture(t); const a = await client(), b = await client();
  a.send({ type: 'create_room', player_name: 'Host', capabilities: ['credential_refresh'] }); const room = await a.next();
  b.send({ type: 'join_room', player_name: 'Guest', room_code: room.room_code, capabilities: ['credential_refresh'] }); await b.next(); await a.next();
  a.send({ type: 'close_room' }); await b.next(); assert.equal(app.rooms.size, 0);
  b.send({ type: 'refresh_ice', room_code: room.room_code, session_token: room.session_token }); assert.equal((await b.next()).code, 'invalid_session');
});
