import { randomBytes, createHash, createHmac, timingSafeEqual } from 'node:crypto';
import dgram from 'node:dgram';
import net from 'node:net';
import tls from 'node:tls';

const COOKIE = 0x2112a442;
export function attribute(type, value) {
  const output = Buffer.alloc(4 + Math.ceil(value.length / 4) * 4);
  output.writeUInt16BE(type); output.writeUInt16BE(value.length, 2); value.copy(output, 4);
  return output;
}
export function message(type, transaction, attributes = [], key = null) {
  const body = Buffer.concat(attributes), header = Buffer.alloc(20);
  header.writeUInt16BE(type); header.writeUInt16BE(body.length + (key ? 24 : 0), 2); header.writeUInt32BE(COOKIE, 4); transaction.copy(header, 8);
  const prefix = Buffer.concat([header, body]);
  return key ? Buffer.concat([prefix, attribute(0x0008, createHmac('sha1', key).update(prefix).digest())]) : prefix;
}
export function parseMessage(bytes, transaction, key = null) {
  if (bytes.length < 20 || bytes.readUInt32BE(4) !== COOKIE || !bytes.subarray(8, 20).equals(transaction) || bytes.readUInt16BE(2) + 20 !== bytes.length) throw Error('Invalid STUN response framing/transaction');
  const attributes = new Map();
  let integrityOffset = -1;
  for (let offset = 20; offset < bytes.length;) {
    if (offset + 4 > bytes.length) throw Error('Truncated STUN attribute');
    const type = bytes.readUInt16BE(offset), length = bytes.readUInt16BE(offset + 2);
    if (offset + 4 + length > bytes.length) throw Error('Truncated STUN attribute');
    if (type === 0x0008) integrityOffset = offset;
    attributes.set(type, bytes.subarray(offset + 4, offset + 4 + length)); offset += 4 + Math.ceil(length / 4) * 4;
    if (offset > bytes.length) throw Error('Invalid STUN padding');
  }
  const error = attributes.get(0x0009);
  if (key && ((bytes.readUInt16BE(0) & 0x0110) === 0x0100 || integrityOffset >= 0)) {
    const integrity = attributes.get(0x0008);
    if (!integrity || integrity.length !== 20) throw Error('Missing TURN response integrity');
    const input = Buffer.from(bytes.subarray(0, integrityOffset));
    input.writeUInt16BE(integrityOffset + 24 - 20, 2);
    if (!timingSafeEqual(integrity, createHmac('sha1', key).update(input).digest())) throw Error('Invalid TURN response integrity');
  }
  return { type: bytes.readUInt16BE(0), attributes, error: error?.length >= 4 ? (error[2] & 7) * 100 + error[3] : 0 };
}

export function parseIceURL(value) {
  const match = /^(stun|turn|turns):([A-Za-z0-9](?:[A-Za-z0-9.-]*[A-Za-z0-9])?|\[[0-9a-fA-F:]+\])(?::([0-9]{1,5}))?(?:\?transport=(udp|tcp))?$/.exec(value);
  if (!match || match[0] !== value || value.length > 512 || match[2].includes('..') || (match[2].startsWith('[') && net.isIP(match[2].slice(1, -1)) !== 6) || Number(match[3] || 1) < 1 || Number(match[3] || 1) > 65535 || (match[1] === 'stun' && match[4])) throw Error('Invalid ICE probe URL');
  return { host: match[2].replace(/^\[|\]$/g, ''), port: Number(match[3] || (match[1] === 'turns' ? 5349 : 3478)), secure: match[1] === 'turns', tcp: match[1] === 'turns' || match[4] === 'tcp' };
}

export async function createWire(url, timeout = 5000) {
  const target = parseIceURL(url);
  const socket = target.tcp ? (target.secure ? tls.connect({ host: target.host, port: target.port, servername: net.isIP(target.host) ? undefined : target.host, rejectUnauthorized: true }) : net.connect(target.port, target.host)) : dgram.createSocket(net.isIP(target.host) === 6 ? 'udp6' : 'udp4');
  let received = Buffer.alloc(0), waiting = null;
  let lastError = null;
  const onError = error => { lastError = error; if (waiting) { waiting.reject(error); waiting = null; } };
  socket.on('error', onError);
  socket.on(target.tcp ? 'data' : 'message', bytes => {
    if (!target.tcp) { if (waiting) { const handler = waiting; waiting = null; handler.resolve(bytes); } return; }
    received = Buffer.concat([received, bytes]);
    if (received.length > 65556) { onError(Error('TURN probe response too large')); return; }
    if (received.length >= 20 && received.length >= 20 + received.readUInt16BE(2)) {
      const length = 20 + received.readUInt16BE(2), packet = received.subarray(0, length); received = received.subarray(length);
      if (waiting) { const handler = waiting; waiting = null; handler.resolve(packet); }
    }
  });
  try {
    await new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(Error('TURN/STUN DNS, TLS or connection timeout')), timeout);
      const ready = () => { clearTimeout(timer); socket.off('error', failed); resolve(); };
      const failed = error => { clearTimeout(timer); socket.off(target.secure ? 'secureConnect' : 'connect', ready); reject(error); };
      socket.once('error', failed);
      socket.once(target.secure ? 'secureConnect' : 'connect', ready);
      if (!target.tcp) socket.connect(target.port, target.host);
    });
  } catch (error) { target.tcp ? socket.destroy() : socket.close(); throw error; }
  return {
    async exchange(type, attributes = [], key = null) {
      const transaction = randomBytes(12);
      const request = message(type, transaction, attributes, key);
      const bytes = await new Promise((resolve, reject) => {
        if (lastError) { reject(lastError); return; }
        const timer = setTimeout(() => { waiting = null; reject(Error('STUN/TURN response timeout; check listener/firewall')); }, timeout);
        waiting = { resolve: value => { clearTimeout(timer); resolve(value); }, reject: error => { clearTimeout(timer); reject(error); } };
        if (target.tcp) socket.write(request); else socket.send(request);
      });
      return parseMessage(bytes, transaction, key);
    },
    close() { if (target.tcp) socket.destroy(); else socket.close(); }
  };
}

export async function probeStun(url) {
  const wire = await createWire(url);
  try {
    const result = await wire.exchange(0x0001);
    if (result.type !== 0x0101 || (!result.attributes.has(0x0020) && !result.attributes.has(0x0001))) throw Error(`STUN binding rejected (${result.error})`);
    return true;
  } finally { wire.close(); }
}

export async function probeTurn(url, username, credential) {
  const wire = await createWire(url);
  try {
    const transport = attribute(0x0019, Buffer.from([17, 0, 0, 0]));
    const challenge = await wire.exchange(0x0003, [transport]);
    const realm = challenge.attributes.get(0x0014), nonce = challenge.attributes.get(0x0015);
    if (challenge.error !== 401 || !realm || !nonce) throw Error(`TURN auth challenge missing (${challenge.error})`);
    const key = createHash('md5').update(`${username}:${realm.toString()}:${credential}`).digest();
    const auth = [attribute(0x0006, Buffer.from(username)), attribute(0x0014, realm), attribute(0x0015, nonce)];
    const result = await wire.exchange(0x0003, [transport, ...auth], key);
    if (result.type !== 0x0103 || !result.attributes.has(0x0016)) throw Error(`TURN allocation rejected (${result.error}); check shared secret, expiry, realm and public IP`);
    // Release the test allocation rather than leave it consuming relay quota.
    const released = await wire.exchange(0x0004, [attribute(0x000d, Buffer.alloc(4)), ...auth], key);
    if (released.type !== 0x0104) throw Error('TURN allocation succeeded but release failed');
    return true;
  } finally { wire.close(); }
}
