import https from 'node:https';
import fs from 'node:fs';
import { createHash } from 'node:crypto';
const url = 'https://github.com/godotengine/webrtc-native/releases/download/1.2.2-stable/godot-extension-webrtc_native.zip';
const expected = '98e9446921740d995bd9ca1be48798dc3c2ceed51e044a25ce18b3cff11f56e5';
const destination = new URL('../.runtime/webrtc-native-1.2.2.zip', import.meta.url);
fs.mkdirSync(new URL('../.runtime/', import.meta.url), { recursive: true });
async function get(address, remaining = 8) {
  if (!remaining) throw Error('Too many redirects');
  return new Promise((resolve, reject) => {
    https.get(address, response => {
      if (response.statusCode >= 300 && response.statusCode < 400) { response.resume(); resolve(get(new URL(response.headers.location, address), remaining - 1)); return; }
      if (response.statusCode !== 200) { response.resume(); reject(Error(`Download HTTP ${response.statusCode}`)); return; }
      const pieces = []; let size = 0;
      response.on('data', piece => { size += piece.length; if (size > 100_000_000) response.destroy(Error('Archive too large')); else pieces.push(piece); });
      response.on('end', () => resolve(Buffer.concat(pieces)));
      response.on('error', reject);
    }).on('error', reject);
  });
}
const bytes = await get(url);
if (createHash('sha256').update(bytes).digest('hex') !== expected) throw Error('WebRTC archive checksum mismatch');
fs.writeFileSync(destination, bytes);
console.log(`Verified archive: ${destination.pathname}. Extract at the project root.`);
