import { createHmac, createHash, randomBytes, timingSafeEqual } from 'node:crypto';

export function turnCredentials(secret, identity, expiresAt) {
  const username = `${expiresAt}:${identity}`;
  return { username, credential: createHmac('sha1', secret).update(username).digest('base64') };
}

// Opaque match-specific bearer capabilities. Store only digests on the server.
// This parser is also the foundation for the documented future game reconnect.
export function parseSessionToken(value) {
  return typeof value === 'string' && /^[A-Za-z0-9_-]{43}$/.test(value) ? value : null;
}
export function issueSessionToken() { return randomBytes(32).toString('base64url'); }
export function tokenDigest(token) { return createHash('sha256').update(token).digest(); }
export function verifySessionToken(token, digest, expiresAt, now) {
  return !!parseSessionToken(token) && now < expiresAt && Buffer.isBuffer(digest) && digest.length === 32 && timingSafeEqual(tokenDigest(token), digest);
}
