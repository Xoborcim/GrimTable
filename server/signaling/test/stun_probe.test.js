import { test } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes, createHash } from 'node:crypto';
import { attribute, message, parseMessage, parseIceURL } from '../src/stun_probe.js';

test('STUN message framing, padding, transaction IDs and error decoding', () => {
  const transaction = randomBytes(12);
  const packet = message(0x0113, transaction, [attribute(0x0009, Buffer.from([0, 0, 4, 1])), attribute(0x0014, Buffer.from('realm'))]);
  const parsed = parseMessage(packet, transaction);
  assert.equal(parsed.error, 401); assert.equal(parsed.attributes.get(0x0014).toString(), 'realm');
  assert.throws(() => parseMessage(packet, randomBytes(12)));
  assert.throws(() => parseMessage(packet.subarray(0, 19), transaction));
  assert.throws(() => parseMessage(packet.subarray(0, packet.length - 1), transaction));
});
test('authenticated TURN probe verifies message integrity and rejects corruption', () => {
  const transaction = randomBytes(12), key = createHash('md5').update('user:realm:credential').digest();
  const packet = message(0x0103, transaction, [attribute(0x0016, Buffer.from([0, 1, 0, 1, 127, 0, 0, 1]))], key);
  assert.equal(parseMessage(packet, transaction, key).type, 0x0103);
  const corrupted = Buffer.from(packet); corrupted[25] ^= 1;
  assert.throws(() => parseMessage(corrupted, transaction, key), /integrity/);
  assert.throws(() => parseMessage(message(0x0103, transaction), transaction, key), /integrity/);
});
test('STUN/TURN probe URL parsing retains TLS verification and transport', () => {
  assert.deepEqual(parseIceURL('turns:turn.example.com:5349?transport=tcp'), { host: 'turn.example.com', port: 5349, secure: true, tcp: true });
  assert.deepEqual(parseIceURL('stun:127.0.0.1:3478'), { host: '127.0.0.1', port: 3478, secure: false, tcp: false });
  assert.equal(parseIceURL('turn:[::1]:3478').host, '::1');
  for (const url of ['https://example.com', 'turn:host:0', 'turn:host:65536', 'stun:host?transport=tcp']) assert.throws(() => parseIceURL(url));
});
