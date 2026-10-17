import { test } from 'node:test';
import assert from 'node:assert/strict';
import { parseIceURL } from '../src/stun_probe.js';
test('ICE endpoint syntax excludes control characters and unsupported URL paths', () => {
  for (const url of ['turn:host\n', 'turn:host\r', 'turn:host/path', 'turn://host', 'stun:']) assert.throws(() => parseIceURL(url));
});
