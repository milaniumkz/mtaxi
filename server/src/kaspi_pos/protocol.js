// Adapted mobile protocol, not an official Kaspi partner API. See LICENSE/NOTICE.md.
const crypto = require('node:crypto');
const fetch = require('node-fetch');
const { HttpsProxyAgent } = require('https-proxy-agent');
const { deviceInfo, sign, signRequest, tokenMac, newAgreement, completeAgreement } = require('./crypto');
const ENTRANCE = 'https://entrance-pay.kaspi.kz';
const MTOKEN = 'https://mtoken.kaspi.kz';
const QRPAY = 'https://qrpay.kaspi.kz';
const HOSTS = new Set([ENTRANCE, MTOKEN, QRPAY]);
const digits = value => String(value ?? '').replace(/\D/g, '');
const phone10 = value => { const d = digits(value); return d.length === 11 && /^[78]/.test(d) ? d.slice(1) : d; };
function bankAmount(value) {
  if (typeof value === 'number') return Number.isFinite(value) ? value : NaN;
  if (typeof value !== 'string') return NaN;
  const text = value.trim().replace(/^\+\s*/, '');
  if (!/^\d+(?:[ \u00a0\u202f]\d{3})*(?:[.,]\d{1,2})?\s*(?:₸|KZT|тг\.?|тенге)?$/iu.test(text)) return NaN;
  return Number(text.replace(/(?:₸|KZT|тг\.?|тенге)$/iu, '').replace(/[ \u00a0\u202f]/g, '').replace(',', '.'));
}
class KaspiError extends Error {
  constructor(code, uncertain = false, bankCode = '') { super(code); this.code = code; this.uncertain = uncertain; this.bankCode = /^[A-Za-z][A-Za-z0-9_.-]{0,79}$/.test(bankCode) ? bankCode : ''; }
}
function rejectionCode(body) { return body?.view?.onOpenAlarm?.error?.code || body?.error?.code || body?.Code || (Number.isFinite(Number(body?.StatusCode)) && Number(body.StatusCode) !== 0 ? 'StatusCode_' + Number(body.StatusCode) : ''); }
function bankData(body) {
  if (!body || body.success === false || body.error || body.Error || body.Data?.error || body.Data?.Error || (body.StatusCode != null && Number(body.StatusCode) !== 0) || body.Data == null)
    throw new KaspiError('KASPI_BANK_REJECTED', false, String(rejectionCode(body)));
  return body.Data;
}
function organization(raw) {
  if (!raw || !Number.isSafeInteger(Number(raw.OrganizationId)) || Number(raw.OrganizationId) <= 0) return null;
  return { id: String(raw.OrganizationId), name: String(raw.OrganizationName || '').slice(0, 120),
    iin: digits(raw.OrganizationIdn), profileId: raw.ProfileId == null ? null : String(raw.ProfileId) };
}
class KaspiProtocol {
  constructor(identity, { env = process.env, fetchImpl = fetch } = {}) {
    this.identity = identity; this.device = deviceInfo(identity); this.fetchImpl = fetchImpl;
    this.app = { version: env.MTAXI_KASPI_POS_APP_VERSION || '26.1029', build: env.MTAXI_KASPI_POS_APP_BUILD || '1128',
      platform: 'iOS', platformVer: '18.4', locale: 'ru-RU', model: 'iPhone16,2', brand: 'Apple',
      deviceName: 'iPhone', screenW: '430.0', screenH: '932.0' };
    if (!/^[0-9.]{1,24}$/.test(this.app.version) || !/^\d{1,12}$/.test(this.app.build)) throw new KaspiError('KASPI_APP_VERSION_INVALID');
    const proxy = env.HTTPS_PROXY || env.https_proxy || env.HTTP_PROXY || env.http_proxy;
    this.agent = proxy ? new HttpsProxyAgent(proxy) : undefined;
    this.ua = `Kaspi%20Pay/${this.app.build} CFNetwork/3826.400.120 Darwin/24.4.0`;
  }
  async request(host, pathname, headers, payload) {
    if (!HOSTS.has(host) || !pathname.startsWith('/')) throw new KaspiError('KASPI_HOST_FORBIDDEN');
    const controller = new AbortController(); const timer = setTimeout(() => controller.abort(), 12000);
    try {
      const response = await this.fetchImpl(host + pathname, { method: payload === undefined ? 'GET' : 'POST', headers,
        ...(payload === undefined ? {} : { body: payload }), signal: controller.signal, redirect: 'error', size: 1024 * 1024,
        ...(this.agent ? { agent: this.agent } : {}) });
      const body = await response.json();
      if (!response.ok) throw new KaspiError('KASPI_BANK_REJECTED', false, String(rejectionCode(body)));
      const cookies = response.headers.raw?.()['set-cookie'] || [];
      const cookie = cookies.map(c => c.match(/user_token=([^;]+)/)?.[1]).find(Boolean);
      return { body, cookie };
    } catch (error) {
      if (error instanceof KaspiError) throw error;
      // Never leak request/response payloads, cookies, OTP or signing secrets.
      throw new KaspiError('KASPI_NETWORK_UNCERTAIN', true);
    } finally { clearTimeout(timer); }
  }
  cookie(userToken) {
    const d = this.device, a = this.app;
    return `deviceId=${d.deviceId}; installId=${d.installId}; is_mobile_app=true; locale=${a.locale}; ma_bld=${a.build}; ma_platform_type=iOS; ma_platform_ver=${a.platformVer}; ma_ver=${a.version}; pk=${d.pk}; pkTag=${d.pkTag}; xs=R:0|E:0|RH:0|N:0` + (userToken ? `; user_token=${userToken}` : '');
  }
  entranceHeaders(referer, userToken) {
    return { Accept: 'application/json, text/plain, */*', 'Content-Type': 'application/json', 'Accept-Language': 'ru',
      Origin: ENTRANCE, Referer: referer, Cookie: this.cookie(userToken), 'Sec-Fetch-Site': 'same-origin',
      'Sec-Fetch-Mode': 'cors', 'Sec-Fetch-Dest': 'empty',
      'User-Agent': `Mozilla/5.0 (iPhone; CPU iPhone OS 18_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148` };
  }
  async init(phone) {
    const d = this.device, a = this.app;
    const data = { auth: '2', appBuild: a.build, appVersion: a.version, platformVersion: a.platformVer, platformType: 'IOS',
      deviceBrand: a.brand, deviceModel: a.model, deviceId: d.deviceId, installId: d.installId, frontCameraAvailable: 'true', sf: 'registration', pc: 'KPEntrance', noPass: '0' };
    const referer = ENTRANCE + '/process/entrance/?' + new URLSearchParams(data);
    const result = await this.request(ENTRANCE, '/api/v1/entrance/step', this.entranceHeaders(referer), JSON.stringify({ data: {}, Data: data, actType: 'Success' }));
    const processId = result.body.meta?.pId;
    if (typeof processId !== 'string' || !processId || processId.length > 1024) throw new KaspiError('KASPI_AUTH_PROTOCOL', false, String(rejectionCode(result.body)));
    return { processId, phone: phone10(phone), userToken: result.cookie || '' };
  }
  async step(attempt, stage, data) {
    const referer = ENTRANCE + '/process/universal-enter-phone-number?' + new URLSearchParams({ pId: attempt.processId, firstPage: 'KPUniversalEnterPhoneNumber' });
    const result = await this.request(ENTRANCE, '/api/v1/entrance/step', this.entranceHeaders(referer, attempt.userToken),
      JSON.stringify({ meta: { pId: attempt.processId, sn: stage }, data, actType: 'Success' }));
    if (result.cookie) attempt.userToken = result.cookie;
    return result.body;
  }
  async sendPhone(attempt) {
    const body = await this.step(attempt, 'EnterPhoneNumber', { phoneNumber: attempt.phone });
    if (body.view?.code !== 'EnterOtp') throw new KaspiError('KASPI_SMS_NOT_SENT', false, String(rejectionCode(body)));
  }
  async verify(attempt, otp) {
    const body = await this.step(attempt, 'ViewEnterOtp', { userOtp: otp, inputType: 'auto' });
    if (body.data?.type !== 'kpDeviceRegistration' && body.view?.code !== 'KPMobileCall')
      throw new KaspiError('KASPI_OTP_REJECTED', false, String(rejectionCode(body)));
    const agreement = newAgreement();
    const data = Buffer.from(JSON.stringify({ installId: this.device.installId, time: new Date().toISOString(), auth: [{ value: '', type: 'pincode' }], userIdHash: '' })).toString('base64');
    const payload = JSON.stringify({ signed: { sign: sign(this.identity, data), data }, guard: { pinHash: this.device.pinHash, x509: agreement.publicKey }, processId: attempt.processId });
    const url = ENTRANCE + '/api/v1/kpentrance/finish';
    const headers = { 'Content-Type': 'application/json', Accept: '*/*', 'Accept-Language': 'ru', 'User-Agent': this.ua,
      'X-Time': new Date().toISOString(), 'X-Call': 'notConnected', 'X-Platform-Type': 'iOS', 'X-PkTag': this.device.pkTag,
      'X-SU': this.hashUrl(url), 'X-Net-Type': 'WIFI/ETHERNET', 'X-Emulator': '0', 'X-Locale': this.app.locale,
      'X-SV': '2', 'X-Request-ID': crypto.randomUUID().toUpperCase(), 'X-Time-Zone': 'GMT+05:00',
      'X-SH': 'url,X-Time-Zone,X-Request-ID,X-Net-Type,X-Emulator,X-Call,X-Platform-Type,X-Locale,X-Time,X-SV' };
    headers['X-Sign'] = signRequest(this.identity, url, headers, headers['X-SH'], payload);
    const result = (await this.request(ENTRANCE, '/api/v1/kpentrance/finish', headers, payload)).body;
    if (result.success !== true || typeof result.data?.tokenSN !== 'string' || !result.data.tokenSN.trim() || !result.data.x509)
      throw new KaspiError('KASPI_AUTH_NOT_FINISHED', false, String(rejectionCode(result)));
    const secret = completeAgreement(agreement, result.data.x509);
    const session = { tokenSN: result.data.tokenSN, secretB64: secret.toString('base64'), phone: attempt.phone, connectedAt: new Date().toISOString() };
    return this.selectOrganization(session, '0');
  }
  hashUrl(url) { return crypto.createHash('md5').update(url.toLowerCase()).digest('hex'); }
  headers(host, pathname, session, payload) {
    const url = host + pathname, d = this.device, a = this.app;
    const fields = 'url,X-Install-ID,X-PI,X-App-Bld,X-Platform-Ver,X-Locale,X-App-Ver,X-Device-ID,X-SV,X-Time,X-Platform-Type,X-Call,X-Kb-TokenSnMac,X-Kb-TokenSn';
    const headers = { 'X-Kb-TokenSn': session.tokenSN, 'X-Kb-TokenSnMac': tokenMac(session.tokenSN, Buffer.from(session.secretB64, 'base64')),
      'X-PI': session.profileId || '', 'X-Install-ID': d.installId, 'X-Device-ID': d.deviceId, 'X-App-Ver': a.version,
      'X-App-Bld': a.build, 'X-Platform-Type': 'iOS', 'X-Platform-Ver': a.platformVer, 'X-Locale': a.locale,
      'X-Time': new Date().toISOString(), 'X-Request-ID': crypto.randomUUID().toUpperCase(), 'X-Call': 'notConnected',
      'X-SV': '2', 'X-SH': fields, 'User-Agent': this.ua, Accept: '*/*', 'Accept-Language': 'ru', 'Content-Type': 'application/json' };
    headers['X-Sign'] = signRequest(this.identity, url, headers, fields, payload); return headers;
  }
  async selectOrganization(session, id) {
    const d = this.device, a = this.app, pathname = '/v08/organizations/org-context-otp', url = MTOKEN + pathname;
    const payload = JSON.stringify({ DeviceInformation: { SdkVersion: 'AOTP service', DeviceId: d.deviceId, ApplicationId: 'kz.kaspi.business',
      ScreenWidth: a.screenW, Model: a.model, ScreenHeight: a.screenH, DeviceName: a.deviceName, VersionName: a.version,
      BuildRelease: `iOS ${a.platformVer}`, Brand: a.brand, Board: a.platformVer, Platform: 'iOS', Product: 'Kaspi Pay',
      frontCameraAvailable: true, VersionCode: a.build, InstallId: d.installId }, OrganizationId: Number(id) });
    const fields = 'url,X-Kb-Client-Ip,X-Time,X-App-Ver,X-SV,X-Locale,X-App-Bld,X-Install-ID,X-Kb-TokenSn,X-S,X-Kb-TokenSnMac,X-Call';
    const headers = { 'Content-Type': 'application/json', Accept: '*/*', 'Accept-Language': 'ru', 'User-Agent': this.ua,
      'X-Kb-TokenSn': session.tokenSN, 'X-Kb-TokenSnMac': tokenMac(session.tokenSN, Buffer.from(session.secretB64, 'base64')),
      'X-Install-ID': d.installId, 'X-App-Ver': a.version, 'X-App-Bld': a.build, 'X-Locale': a.locale,
      'X-Call': 'notConnected', 'X-Time': new Date().toISOString(), 'X-S': 'R:0|E:0|RH:0|N:0', 'X-SV': '2',
      'X-Kb-Client-Ip': '192.168.1.96', 'X-PkTag': d.pkTag, 'X-SU': this.hashUrl(url), 'X-SH': fields,
      'X-Request-ID': crypto.randomUUID().toUpperCase() };
    headers['X-Sign'] = signRequest(this.identity, url, headers, fields, payload);
    const data = bankData((await this.request(MTOKEN, pathname, headers, payload)).body);
    const current = organization(data.Current);
    if (!current?.profileId || current.profileId === '0' || !current.iin || (id !== '0' && current.id !== String(id))) throw new KaspiError('KASPI_ORGANIZATION_UNCONFIRMED');
    const organizations = [current, ...(Array.isArray(data.Organizations) ? data.Organizations.map(organization).filter(Boolean) : [])];
    return { ...session, profileId: current.profileId, organizationId: current.id, organizationIin: current.iin,
      orgName: current.name, organizations: [...new Map(organizations.slice(0, 50).map(o => [o.id, o])).values()] };
  }
  async check(session) {
    const path = '/v02/history/operations', body = JSON.stringify({ EndDate: new Date().toISOString().slice(0, 10), LastTransactionDate: '', StatementPeriodCode: 0 });
    bankData((await this.request(QRPAY, path, this.headers(QRPAY, path, session, body), body)).body); return true;
  }
  async createInvoice(session, payment) {
    const path = '/v01/remote/create';
    const body = JSON.stringify({ PhoneNumber: phone10(payment.kaspiPhone), Amount: payment.amount, Comment: `MTaxi ${payment.paymentId}` });
    const data = bankData((await this.request(QRPAY, path, this.headers(QRPAY, path, session, body), body)).body);
    const id = data.QrOperationId ?? data.Id;
    if ((typeof id === 'number' && !Number.isSafeInteger(id)) || !/^[1-9]\d{0,29}$/.test(String(id)) || bankAmount(data.Amount) !== Number(payment.amount) || phone10(data.ClientMobile) !== phone10(payment.kaspiPhone))
      throw new KaspiError('KASPI_INVOICE_RESPONSE_UNCERTAIN', true);
    return { operationId: String(id) };
  }
  async createTestLink(session, data = {}) { return this.createPaymentLink(session, { amount: 100 }, data); }
  async createPaymentLink(session, payment, { latitude, longitude } = {}) {
    const amount = Number(payment.amount);
    if (!Number.isFinite(amount) || amount < 1 || amount > 1000000 || Math.abs(amount * 100 - Math.round(amount * 100)) > 0.00001) throw new KaspiError('KASPI_AMOUNT_INVALID');
    const path = '/v01/qr-token/create';
    const body = JSON.stringify({ PaymentAmount: amount, DeviceInterface: 'Pos',
      ...(Number.isFinite(latitude) && Number.isFinite(longitude) && Math.abs(latitude) <= 90 && Math.abs(longitude) <= 180 ? { Latitude: latitude, Longitude: longitude } : {}) });
    const data = bankData((await this.request(QRPAY, path, this.headers(QRPAY, path, session, body), body)).body);
    const id = data.QrOperationId;
    let url; try { url = new URL(data.QrToken); } catch { throw new KaspiError('KASPI_QR_URL_MISSING', true); }
    if ((typeof id === 'number' && !Number.isSafeInteger(id)) || !/^[1-9]\d{0,29}$/.test(String(id))) throw new KaspiError('KASPI_QR_OPERATION_INVALID', true);
    // Creation can report zero before payment; settlement must match the persisted requested amount.
    if (data.Amount != null && ![0, amount].includes(bankAmount(data.Amount))) throw new KaspiError('KASPI_QR_AMOUNT_MISMATCH', true);
    if (url.protocol !== 'https:' || url.username || url.password || url.port || !['qr.kaspi.kz', 'pay.kaspi.kz'].includes(url.hostname)) throw new KaspiError('KASPI_QR_URL_INVALID', true);
    if (url.hostname === 'qr.kaspi.kz') { url.hostname = 'pay.kaspi.kz'; url.pathname = '/pay' + url.pathname; }
    return { operationId: String(id), paymentUrl: url.href, expiresAt: data.ExpireDate || null };
  }
  async qrOperationDetails(session, id) {
    if (!Number.isSafeInteger(Number(id)) || Number(id) <= 0) throw new KaspiError('KASPI_PAYMENT_BINDING_MISMATCH');
    const path = '/v01/kaspi-qr/operations/details', body = JSON.stringify({ Id: Number(id), OperationMethod: 0 });
    return bankData((await this.request(QRPAY, path, this.headers(QRPAY, path, session, body), body)).body);
  }
  async testLinkStatus(session, id) {
    const path = '/v02/kaspi-qr/status?qrOperationId=' + encodeURIComponent(id);
    return bankData((await this.request(QRPAY, path, this.headers(QRPAY, path, session))).body);
  }
  async invoiceDetails(session, id) {
    const path = '/v02/remote/details?operationId=' + encodeURIComponent(id);
    return bankData((await this.request(QRPAY, path, this.headers(QRPAY, path, session))).body);
  }
}
module.exports = { KaspiProtocol, KaspiError, phone10, bankAmount };
