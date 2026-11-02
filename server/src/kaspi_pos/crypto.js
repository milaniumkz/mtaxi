// Protocol primitives adapted from tapter-dev/kaspi-pos-automation, MIT.
// Pinned upstream: 9b0000d38716a7c4b36867a5642a4768a3a4552f. See LICENSE.
const crypto = require('node:crypto');
function createIdentity() {
  const pair = crypto.generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  return {
    privateKey: pair.privateKey.export({ type: 'pkcs8', format: 'der' }).toString('base64'),
    publicKey: pair.publicKey.export({ type: 'spki', format: 'der' }).toString('base64'),
    deviceId: crypto.randomUUID().toUpperCase(), installId: crypto.randomUUID().toUpperCase(),
    pinHash: crypto.createHash('md5').update(crypto.randomBytes(16)).digest('hex'),
  };
}
function deviceInfo(identity) {
  const pub = Buffer.from(identity.publicKey, 'base64');
  const pk = pub.subarray(pub.length - 65).toString('base64');
  return { ...identity, pk, pkTag: crypto.createHash('md5').update(pk).digest('hex'), x509: identity.publicKey };
}
function sign(identity, data) {
  return crypto.sign('sha256', Buffer.from(data), {
    key: Buffer.from(identity.privateKey, 'base64'), format: 'der', type: 'pkcs8',
  }).toString('base64');
}
function signRequest(identity, url, headers, fields, body) {
  const lines = fields.split(',').map(k => k === 'url' ? 'url:' + url.toLowerCase() : k.toLowerCase() + ':' + (headers[k] || ''));
  const text = lines.join('\n') + (body ? '\n' + body : '');
  return sign(identity, crypto.createHash('sha256').update(text, 'utf8').digest());
}
function tokenMac(tokenSN, secret, now = Date.now()) {
  if (!secret) throw new Error('KASPI_SECRET_MISSING');
  const q = Buffer.from(String(tokenSN)).toString('hex').substring(0, 64).padEnd(256, '0');
  const time = (BigInt(now) / 30000n).toString(16).padStart(16, '0');
  const hash = crypto.createHmac('sha256', secret).update(Buffer.concat([
    Buffer.from('OCRA-1:HOTP-SHA256-6:QH64-T1M'), Buffer.from([0]), Buffer.from(q, 'hex'), Buffer.from(time, 'hex'),
  ])).digest();
  const offset = hash[hash.length - 1] & 15;
  return ((hash.readUInt32BE(offset) & 0x7fffffff) % 1000000).toString().padStart(6, '0');
}
function newAgreement() {
  const pair = crypto.generateKeyPairSync('ec', { namedCurve: 'prime256v1' });
  return { privateKey: pair.privateKey, publicKey: pair.publicKey.export({ type: 'spki', format: 'der' }).toString('base64') };
}
function completeAgreement(agreement, serverKey) {
  return crypto.diffieHellman({ privateKey: agreement.privateKey,
    publicKey: crypto.createPublicKey({ key: Buffer.from(serverKey, 'base64'), type: 'spki', format: 'der' }) });
}
module.exports = { createIdentity, deviceInfo, sign, signRequest, tokenMac, newAgreement, completeAgreement };
