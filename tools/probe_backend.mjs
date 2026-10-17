import { createRequire } from 'node:module';
import { probeStun, probeTurn } from '../server/signaling/src/stun_probe.js';
const require = createRequire(new URL('../server/signaling/package.json', import.meta.url));
const WebSocket = require('ws');
const args = process.argv.slice(2);
const signal = args.find(a => a.startsWith('--signal-url='))?.slice(13) || 'ws://127.0.0.1:8080';
const url = new URL(signal);
if (!['wss:', 'ws:'].includes(url.protocol) || (url.protocol === 'ws:' && !['127.0.0.1', 'localhost', '[::1]'].includes(url.hostname))) throw Error('Use WSS for public signaling');
const healthURL = new URL('/health', url); healthURL.protocol = url.protocol === 'wss:' ? 'https:' : 'http:';
const health = await fetch(healthURL, { signal: AbortSignal.timeout(10000) });
if (!health.ok || !(await health.json()).ok) throw Error('Signaling health check failed');
console.log('PASS health (TLS verified by Node when WSS; Windows Godot trust requires its own test)');
async function client() {
  const ws = new WebSocket(url, { rejectUnauthorized: true, maxPayload: 65536, handshakeTimeout: 10000 });
  ws.on('error', () => {});
  const queue = [], waiters = [];
  ws.on('message', bytes => { const message = JSON.parse(bytes); if (waiters.length) waiters.shift()(message); else queue.push(message); });
  await new Promise((resolve, reject) => { ws.once('open', resolve); ws.once('error', reject); });
  return { ws, send: message => ws.send(JSON.stringify({ version: 1, ...message })), next: () => queue.length ? Promise.resolve(queue.shift()) : new Promise((resolve, reject) => { const timer = setTimeout(() => reject(Error('Signaling response timed out')), 10000); waiters.push(message => { clearTimeout(timer); resolve(message); }); }) };
}
const host = await client(); let guest;
try {
  host.send({ type: 'create_room', player_name: 'Deployment Probe', capabilities: ['credential_refresh'] });
  const room = await host.next(); if (room.type !== 'room_created') throw Error(`Room creation failed: ${room.code}`);
  console.log('PASS WSS/WS upgrade and room creation');
  guest = await client(); guest.send({ type: 'join_room', player_name: 'Deployment Probe', room_code: room.room_code, capabilities: ['credential_refresh'] });
  if ((await guest.next()).type !== 'room_joined' || (await host.next()).type !== 'peer_joined') throw Error('Room join failed');
  for (const [from, to, message] of [[host, guest, { type: 'offer', sdp: 'probe-only-not-a-WebRTC-description' }], [guest, host, { type: 'answer', sdp: 'probe-only-not-a-WebRTC-description' }], [host, guest, { type: 'ice_candidate', media: '0', index: 0, candidate: 'probe-only-not-a-WebRTC-candidate' }]]) {
    from.send(message); if ((await to.next()).type !== message.type) throw Error('Signaling forwarding failed');
  }
  console.log('PASS room join and SDP/ICE forwarding (not a WebRTC connection test)');
  host.send({ type: 'refresh_ice', room_code: room.room_code, session_token: room.session_token });
  const fresh = await host.next(); if (fresh.type !== 'ice_credentials') throw Error('Credential renewal failed');
  console.log('PASS authenticated credential renewal');
  let turnCount = 0, stunCount = 0;
  if (!args.includes('--signaling-only')) for (const server of fresh.ice_servers) for (const iceURL of server.urls) {
    if (iceURL.startsWith('stun:')) { await probeStun(iceURL); stunCount++; console.log('PASS STUN binding'); }
    else { await probeTurn(iceURL, server.username, server.credential); turnCount++; console.log('PASS authenticated TURN allocation and release'); }
  }
  if (!args.includes('--signaling-only') && (!turnCount || !stunCount)) throw Error('Backend did not supply both STUN and TURN; full backend probe incomplete');
  if (args.includes('--check-expiry')) {
    const lifetime = fresh.turn_expires_at - fresh.server_time;
    if (!Number.isInteger(lifetime) || lifetime < 1 || lifetime > 90) throw Error('Expiry test requires a separate test server with TURN_TTL_SECONDS=60');
    console.log('Waiting for test credential expiry; no credentials will be logged.');
    await new Promise(resolve => setTimeout(resolve, (lifetime + 2) * 1000));
    for (const server of fresh.ice_servers) for (const iceURL of server.urls) if (iceURL.startsWith('turn:') || iceURL.startsWith('turns:')) {
      let rejected = false;
      try { await probeTurn(iceURL, server.username, server.credential); }
      catch (error) { if (/TURN allocation rejected \((401|441)\)/.test(error.message)) rejected = true; else throw error; }
      if (!rejected) throw Error('Expired TURN credentials were accepted');
      console.log('PASS coturn rejected the expired credentials');
    }
  }
  console.log('Backend probe complete. A two-machine gameplay test is still required.');
} finally { host.send({ type: 'close_room' }); host.ws.close(); guest?.ws.close(); }
