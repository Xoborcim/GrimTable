import http from 'node:http';
import { randomInt, randomUUID } from 'node:crypto';
import { WebSocketServer, WebSocket } from 'ws';
import { turnCredentials, issueSessionToken, tokenDigest, verifySessionToken, parseSessionToken } from './credentials.js';

const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const nameOf = value => typeof value === 'string' ? value.replace(/[^\p{L}\p{N} _.-]/gu, '').trim().slice(0, 32) || 'Player' : null;
const text = (s, max) => typeof s === 'string' && s.length > 0 && s.length <= max;
export function createSignaling(options = {}) {
  const rooms = new Map(), clients = new Set(), limits = new Map();
  const now = options.now || Date.now;
  const ttl = options.roomTTL || 30 * 60_000;
  const matchTTL = options.matchTTL || 12 * 60 * 60_000;
  const started = now();
  const counters = { rooms_created: 0, join_failures: 0, expired_rooms: 0, turn_credential_requests: 0 };
  const logger = options.logger || (() => {});
  const secret = options.turnSecret || '';
  const turnURLs = options.turnURLs || [];
  const stunURLs = options.stunURLs || [];
  const send = (ws, data) => { if (ws?.readyState === WebSocket.OPEN) ws.send(JSON.stringify({ version: 1, ...data })); };
  const fail = (ws, code, message) => { send(ws, { type: 'error', code, message }); logger('signaling_error', { code }); };
  function allowance(key, max, window = 60_000) {
    let item = limits.get(key);
    if (!item || item.until <= now()) { item = { count: 0, until: now() + window }; limits.set(key, item); }
    return ++item.count <= max;
  }
  function ice(ws) {
    const ice_servers = [];
    const server_time = Math.floor(now() / 1000);
    let turn_expires_at = null;
    if (stunURLs.length) ice_servers.push({ urls: stunURLs });
    if (turnURLs.length && secret) {
      turn_expires_at = server_time + (options.turnTTL || 7200);
      ice_servers.push({ urls: turnURLs, ...turnCredentials(secret, ws.identity, turn_expires_at) });
      counters.turn_credential_requests++;
    }
    return { ice_servers, server_time, turn_expires_at };
  }
  function drop(ws, explicit = false) {
    const room = rooms.get(ws.room);
    if (!room) return;
    if (!explicit && room.persistent && room.joined) {
      // Losing signaling need not end the live P2P game or its renewal lease.
      // Rebinding signaling requires the member's private token, never a name.
      send(room.host === ws ? room.guest : room.host, { type: 'signaling_unavailable' });
      ws.room = null;
      logger('signaling_disconnected', {});
      return;
    }
    if (room.host === ws) {
      send(room.guest, { type: 'peer_left', reason: 'Host left. Room closed.' });
      if (room.guest) room.guest.room = null;
      rooms.delete(ws.room);
    } else {
      room.guest = null;
      // One negotiation per room: avoid stale ICE/SDP crossing generations.
      send(room.host, { type: 'peer_left', reason: 'Opponent disconnected. Create a new room to invite again.' });
      room.host.room = null;
      rooms.delete(ws.room);
    }
    logger('peer_disconnected', {});
    ws.room = null;
  }
  function sweep() {
    for (const [code, room] of rooms) if (now() >= (room.persistent && room.joined ? room.expiresAt : room.created + ttl)) {
      for (const ws of [room.host, room.guest]) if (ws) { send(ws, { type: 'error', code: 'room_expired', message: 'Room expired.' }); ws.room = null; }
      rooms.delete(code); counters.expired_rooms++; logger('room_expired', {});
    }
    for (const [key, item] of limits) if (item.until <= now()) limits.delete(key);
  }
  const server = http.createServer((req, res) => {
    const health = req.method === 'GET' && req.url === '/health';
    const metrics = options.metrics && req.method === 'GET' && req.url === '/metrics';
    res.writeHead(health || metrics ? 200 : 404, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
    res.end(JSON.stringify(health ? { ok: true, protocol: 1, service_version: '1.1.0', uptime_seconds: Math.floor((now() - started) / 1000) } : metrics ? { active_connections: clients.size, active_rooms: rooms.size, ...counters } : { error: 'not_found' }));
  });
  const wss = new WebSocketServer({ noServer: true, maxPayload: 65536, perMessageDeflate: false });
  server.on('upgrade', (req, socket, head) => {
    // Trust no forwarding headers. Proxy deployments share limits unless the operator sets trustedProxy.
    const ip = options.trustedProxy ? req.headers['x-real-ip'] || req.socket.remoteAddress : req.socket.remoteAddress;
    if (req.url !== '/' || clients.size >= (options.maxConnections || 1000) || !allowance(`connect:${ip}`, 30) || (options.origins?.length && !options.origins.includes(req.headers.origin))) { socket.destroy(); return; }
    wss.handleUpgrade(req, socket, head, ws => { ws.ip = ip; wss.emit('connection', ws); });
  });
  wss.on('connection', ws => {
    ws.identity = randomUUID(); ws.alive = true; clients.add(ws);
    ws.on('error', () => {});
    ws.on('pong', () => { ws.alive = true; });
    ws.on('close', () => { drop(ws); clients.delete(ws); });
    ws.on('message', (raw, binary) => {
      if (!allowance(`message:${ws.identity}`, 240)) { fail(ws, 'rate_limited', 'Too many messages.'); ws.close(1008); return; }
      let msg;
      try { msg = JSON.parse(raw.toString()); } catch { fail(ws, 'bad_json', 'Malformed JSON.'); return; }
      if (binary || !msg || Array.isArray(msg) || msg.version !== 1 || typeof msg.type !== 'string') { fail(ws, 'bad_protocol', 'Unsupported protocol version or message.'); return; }
      if (msg.type === 'ping') { send(ws, { type: 'pong' }); return; }
      if (msg.type === 'close_room') { drop(ws, true); return; }
      if (msg.type === 'refresh_ice') {
        if (!allowance(`refresh:${ws.ip}`, 20)) { fail(ws, 'rate_limited', 'Too many credential requests.'); return; }
        const code = typeof msg.room_code === 'string' ? msg.room_code.trim().toUpperCase() : '';
        const room = rooms.get(code);
        if (!room || !room.persistent || now() >= (room.joined ? room.expiresAt : room.created + ttl) || !parseSessionToken(msg.session_token)) { fail(ws, 'invalid_session', 'Match credential lease expired or invalid.'); return; }
        let role;
        for (const candidate of ['host', 'guest']) if (room.tokens[candidate] && verifySessionToken(msg.session_token, room.tokens[candidate], room.expiresAt, now())) role = candidate;
        if (!role || (ws.room && ws.room !== code)) { fail(ws, 'invalid_session', 'Match credential lease expired or invalid.'); return; }
        const old = room[role];
        if (old !== ws && old?.readyState === WebSocket.OPEN) { fail(ws, 'session_in_use', 'Signaling session is still connected.'); return; }
        // This only restores signaling authorization, not a gameplay peer.
        if (old && old !== ws) old.room = null;
        room[role] = ws; ws.room = code;
        send(ws, { type: 'ice_credentials', ...ice(ws), session_expires_at: Math.floor(room.expiresAt / 1000) });
        logger('credentials_refreshed', {});
        return;
      }
      if (['create_room', 'join_room'].includes(msg.type)) {
        if (!allowance(`${msg.type}:${ws.ip}`, msg.type === 'create_room' ? 6 : 20)) { fail(ws, 'rate_limited', 'Too many room requests. Try again later.'); return; }
        if (ws.room) { fail(ws, 'already_in_room', 'Leave the current room first.'); return; }
        const player_name = nameOf(msg.player_name);
        if (!player_name) { fail(ws, 'bad_name', 'Player name required.'); return; }
        if (msg.capabilities !== undefined && (!Array.isArray(msg.capabilities) || msg.capabilities.length > 8 || msg.capabilities.some(c => !text(c, 64)))) { fail(ws, 'bad_capabilities', 'Invalid client capabilities.'); return; }
        const persistent = msg.capabilities?.includes('credential_refresh') || false;
        const token = persistent ? issueSessionToken() : null;
        if (msg.type === 'create_room') {
          let code;
          do { code = Array.from({ length: 6 }, () => alphabet[randomInt(alphabet.length)]).join(''); } while (rooms.has(code));
          if (rooms.size >= (options.maxRooms || 500)) { fail(ws, 'server_full', 'Server is full.'); return; }
          const expiresAt = now() + matchTTL;
          rooms.set(code, { host: ws, guest: null, created: now(), player_name, joined: false, persistent, expiresAt, tokens: { host: token ? tokenDigest(token) : null } }); ws.room = code;
          send(ws, { type: 'room_created', room_code: code, ...ice(ws), ...(token ? { session_token: token, session_expires_at: Math.floor(expiresAt / 1000) } : {}) }); counters.rooms_created++; logger('room_created', {});
        } else {
          const code = typeof msg.room_code === 'string' ? msg.room_code.trim().toUpperCase() : '';
          const room = rooms.get(code);
          if (!room) { counters.join_failures++; fail(ws, 'room_not_found', 'Room not found or expired.'); return; }
          if (now() - room.created >= ttl) { sweep(); fail(ws, 'room_expired', 'Room expired.'); return; }
          if (room.guest) { counters.join_failures++; fail(ws, 'room_full', 'Room already full.'); return; }
          room.guest = ws; ws.room = code; room.joined = true;
          room.tokens.guest = token ? tokenDigest(token) : null;
          send(ws, { type: 'room_joined', room_code: code, player_name: room.player_name, ...ice(ws), ...(room.persistent && token ? { session_token: token, session_expires_at: Math.floor(room.expiresAt / 1000) } : {}) });
          send(room.host, { type: 'peer_joined', player_name }); logger('peer_joined', {});
        }
        return;
      }
      if (!['offer', 'answer', 'ice_candidate'].includes(msg.type)) { fail(ws, 'unknown_type', 'Unknown message type.'); return; }
      const room = rooms.get(ws.room), host = room?.host === ws;
      if (!room || !room.guest) { fail(ws, 'no_peer', 'No opponent in room.'); return; }
      if (['offer', 'answer'].includes(msg.type)) {
        if ((msg.type === 'offer') !== host || !text(msg.sdp, 60000)) { fail(ws, 'bad_sdp', 'Invalid session description or role.'); return; }
        send(host ? room.guest : room.host, { type: msg.type, sdp: msg.sdp });
      } else {
        if (!text(msg.media, 128) || !Number.isInteger(msg.index) || msg.index < 0 || msg.index > 32 || !text(msg.candidate, 2048)) { fail(ws, 'bad_ice', 'Invalid ICE candidate.'); return; }
        send(host ? room.guest : room.host, { type: 'ice_candidate', media: msg.media, index: msg.index, candidate: msg.candidate });
      }
    });
  });
  const timer = setInterval(() => {
    sweep();
    for (const ws of clients) { if (!ws.alive) ws.terminate(); else { ws.alive = false; ws.ping(); } }
  }, 30_000);
  timer.unref();
  return { server, rooms, sweep, async close() { clearInterval(timer); for (const ws of clients) ws.terminate(); await new Promise(resolve => wss.close(resolve)); await new Promise(resolve => server.close(resolve)); } };
}
