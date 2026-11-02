const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
class KaspiVault {
  constructor(directory, keyFile) { this.directory = directory; this.file = path.join(directory, 'session.enc'); this.keyFile = keyFile; }
  key() {
    const fd = fs.openSync(this.keyFile, fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW);
    try {
      if ((fs.fstatSync(fd).mode & 0o077) !== 0) throw new Error('KASPI_KEY_PERMISSIONS');
      const hex = fs.readFileSync(fd, 'utf8').trim();
      if (!/^[0-9a-fA-F]{64}$/.test(hex)) throw new Error('KASPI_KEY_INVALID');
      return Buffer.from(hex, 'hex');
    } finally { fs.closeSync(fd); }
  }
  load() {
    const key = this.key();
    if (!fs.existsSync(this.file)) return {};
    const fd = fs.openSync(this.file, fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW);
    let data;
    try { data = fs.readFileSync(fd); } finally { fs.closeSync(fd); }
    if (data.length < 29 || data[0] !== 1) throw new Error('KASPI_VAULT_INVALID');
    const decipher = crypto.createDecipheriv('aes-256-gcm', key, data.subarray(1, 13));
    decipher.setAuthTag(data.subarray(13, 29));
    return JSON.parse(Buffer.concat([decipher.update(data.subarray(29)), decipher.final()]).toString('utf8'));
  }
  save(state) {
    fs.mkdirSync(this.directory, { recursive: true, mode: 0o700 });
    if (fs.lstatSync(this.directory).isSymbolicLink()) throw new Error('KASPI_VAULT_PATH_INVALID');
    fs.chmodSync(this.directory, 0o700);
    const iv = crypto.randomBytes(12);
    const cipher = crypto.createCipheriv('aes-256-gcm', this.key(), iv);
    const encrypted = Buffer.concat([cipher.update(JSON.stringify(state), 'utf8'), cipher.final()]);
    const temp = this.file + '.' + crypto.randomUUID() + '.tmp';
    const fd = fs.openSync(temp, 'wx', 0o600);
    try { fs.writeFileSync(fd, Buffer.concat([Buffer.from([1]), iv, cipher.getAuthTag(), encrypted])); fs.fsyncSync(fd); }
    finally { fs.closeSync(fd); }
    fs.renameSync(temp, this.file);
  }
}
module.exports = { KaspiVault };
