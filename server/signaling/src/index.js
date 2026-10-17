import { createSignaling } from './server.js';
import { parseIceURL } from './stun_probe.js';
const split = name => (process.env[name] || '').split(',').map(s => s.trim()).filter(Boolean);
const bounded = (name, fallback, min, max) => {
  const value = Number(process.env[name] || fallback);
  if (!Number.isInteger(value) || value < min || value > max) throw Error(`Invalid ${name}`);
  return value;
};
if (process.env.TURN_URLS && (!process.env.TURN_SHARED_SECRET || process.env.TURN_SHARED_SECRET.length < 32 || process.env.TURN_SHARED_SECRET === 'change_me')) throw Error('Set a private TURN_SHARED_SECRET of at least 32 characters before enabling TURN.');
for (const url of split('STUN_URLS')) { parseIceURL(url); if (!url.startsWith('stun:')) throw Error('Invalid STUN_URLS'); }
for (const url of split('TURN_URLS')) { parseIceURL(url); if (!url.startsWith('turn:') && !url.startsWith('turns:')) throw Error('Invalid TURN_URLS'); }
const service = createSignaling({
  stunURLs: split('STUN_URLS'), turnURLs: split('TURN_URLS'), turnSecret: process.env.TURN_SHARED_SECRET,
  roomTTL: bounded('ROOM_TTL_SECONDS', 1800, 60, 86400) * 1000,
  turnTTL: bounded('TURN_TTL_SECONDS', 7200, 60, 86400),
  matchTTL: bounded('MATCH_TTL_SECONDS', 43200, 60, 86400) * 1000,
  metrics: process.env.METRICS_ENABLED === 'true',
  trustedProxy: process.env.TRUST_PROXY === 'true', origins: split('ALLOWED_ORIGINS'),
  logger: (event, fields) => console.log(JSON.stringify({ time: new Date().toISOString(), event, ...fields }))
});
service.server.listen(bounded('PORT', 8080, 1, 65535), process.env.HOST || '127.0.0.1', () => console.log('GrimTable signaling protocol 1 listening'));
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, async () => { await service.close(); process.exit(0); });
