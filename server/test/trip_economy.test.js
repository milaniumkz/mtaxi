const test = require("node:test"),
  assert = require("node:assert/strict"),
  fs = require("node:fs"),
  os = require("node:os"),
  path = require("node:path");
const dir = fs.mkdtempSync(path.join(os.tmpdir(), "mtaxi-economy-"));
process.env.MTAXI_DATA_DIR = dir;
process.env.MTAXI_STORE = process.env.MTAXI_TEST_POSTGRES_URL
  ? "postgres"
  : "json";
if (process.env.MTAXI_TEST_POSTGRES_URL)
  process.env.DATABASE_URL = process.env.MTAXI_TEST_POSTGRES_URL;
process.env.MTAXI_FCM_ENABLED = "false";
const { readStoreAsync: read, withStoreAsync: write } = require("../src/store");
const {
  createPassengerOrderAsync: create,
  acceptOrderAsync: accept,
  cancelPassengerOrderAsync: cancel,
  advanceDriverOrderStatusAsync: advance,
  expirePendingOrderIfNeededAsync: expire,
} = require("../src/orders");
const {
  submitOrderOfferAsync: offer,
  listOrderOffersAsync: list,
  respondOrderOfferAsync: respond,
  getTripTrackingAsync: track,
  rateTripDriverAsync: rate,
} = require("../src/order_offers");
const { adminManageOrderAsync: manage } = require("../src/admin");
const {
  createPassengerTopUpPaymentAsync: topup,
  createDriverTopUpPaymentAsync: driverTopup,
  confirmDriverTopUpPaymentAsync: confirm,
} = require("../src/payments");
const { observeDriverPosition } = require("../src/trip_automation");
const { updateUserPreferencesAsync: preferences } = require("../src/users");
const p = {
    id: "p",
    phone: "+77010000101",
    city: "Железинка",
    roleState: "PASSENGER",
    balance: 1000,
    passengerBonusBalance: 200,
  },
  d = {
    id: "d",
    phone: "+77010000102",
    isDriver: true,
    statusDriver: "approved",
    balance: 1000,
    bonusBalance: 1000,
    displayName: "Водитель",
  },
  a = { id: "a", role: "admin", isAdmin: true },
  x = { id: "x", phone: "+77010000103", balance: 0 };
const auth = (user) => ({ user }),
  u = (s, id) => s.users.find((v) => v.id === id);
const make = (extra = {}) =>
  create(
    {
      type: "taxi",
      city: "Железинка",
      ot: "Абая 1",
      kuda: "Абая 10",
      price: 500,
      ...extra,
    },
    auth(p),
  );
const args = (o) => ({ orderDocPath: o.orderDocPath });
const status = (o, nextStatus) => advance({ ...args(o), nextStatus }, auth(d));
async function finish(o) {
  for (const n of [3, 4, 5]) assert.equal((await status(o, n)).success, true);
}
test.before(async () => {
  if (process.env.MTAXI_TEST_POSTGRES_URL)
    await require("../scripts/apply_schema").applySchema();
});
test.beforeEach(() =>
  write((s) => {
    s.users = structuredClone([p, d, a, x]);
    s.orders = [];
    s.ledger = [];
    s.payments = [];
    s.notifications = [];
    s.notificationDeliveries = [];
    s.fcmTokens = [];
    s.settings = {
      orderCommissionPercent: 10,
      passengerBonusPercent: 2,
      passengerBonusSpendPercent: 100,
      driverBonusEnabled: false,
    };
  }),
);
test.after(() => fs.rmSync(dir, { recursive: true, force: true }));
test("minimum fare and insufficient wallet are atomic", async () => {
  for (const price of [0, 499, -500, 500.5, "bad", 10000001])
    assert.equal((await make({ price })).code, "PRICE_MINIMUM");
  assert.equal(
    (
      await make({
        price: 1500,
        paymentMode: "wallet",
        usePassengerBonuses: true,
      })
    ).code,
    "PASSENGER_BALANCE_INSUFFICIENT",
  );
  const s = await read();
  assert.equal(u(s, "p").balance, 1000);
  assert.equal(u(s, "p").passengerBonusBalance, 200);
  assert.equal(s.orders.length, 0);
  assert.equal(s.ledger.length, 0);
});
test("mixed wallet and bonus payment credits driver cash and cashback exactly once", async () => {
  const o = await make({ paymentMode: "wallet", usePassengerBonuses: true });
  let s = await read();
  assert.equal(u(s, "p").balance, 700);
  assert.equal(u(s, "p").passengerBonusBalance, 0);
  assert.equal(s.orders[0].cashToDriver, 0);
  assert.equal((await accept(args(o), auth(d))).accepted, true);
  assert.equal((await status(o, 5)).code, "ORDER_STATUS_SEQUENCE_REQUIRED");
  await finish(o);
  s = await read();
  assert.equal(u(s, "d").balance, 1500);
  assert.equal(u(s, "d").bonusBalance, 950);
  assert.equal(u(s, "p").passengerBonusBalance, 10);
  assert.equal((await status(o, 5)).success, false);
  assert.equal(
    s.ledger.filter((v) => v.type === "passenger_trip_payment").length,
    1,
  );
});
test("full bonus fare is permitted and driver receives withdrawable cash", async () => {
  await write((s) => {
    u(s, "p").passengerBonusBalance = 500;
  });
  const o = await make({ usePassengerBonuses: true });
  await accept(args(o), auth(d));
  await finish(o);
  const s = await read();
  assert.equal(s.orders[0].cashToDriver, 0);
  assert.equal(u(s, "d").balance, 1500);
  assert.equal(u(s, "d").bonusBalance, 950);
  assert.equal(u(s, "p").balance, 1000);
});
test("only owner can cancel; reserve and commission refund once", async () => {
  const o = await make({ paymentMode: "wallet", usePassengerBonuses: true });
  await accept(args(o), auth(d));
  assert.equal((await cancel(args(o), auth(x))).code, "ORDER_FORBIDDEN");
  for (let i = 0; i < 2; i++)
    assert.equal((await cancel(args(o), auth(p))).success, true);
  const s = await read();
  assert.equal(u(s, "p").balance, 1000);
  assert.equal(u(s, "p").passengerBonusBalance, 200);
  assert.equal(u(s, "d").bonusBalance, 1000);
  assert.equal(
    s.ledger.filter((v) => v.type === "passenger_trip_refund").length,
    1,
  );
});
test("started trip cannot be cancelled, reopened or rolled back even by admin", async () => {
  const o = await make({ paymentMode: "wallet", usePassengerBonuses: true });
  await accept(args(o), auth(d));
  await status(o, 3);
  await status(o, 4);
  assert.equal((await cancel(args(o), auth(p))).code, "TRIP_ALREADY_STARTED");
  for (const action of ["cancel", "reopen", "setstatus"])
    assert.equal(
      (await manage({ ...args(o), action, targetStatus: 6 }, auth(a))).success,
      false,
    );
  const s = await read();
  assert.equal(s.orders[0].status, 4);
  assert.equal(u(s, "p").balance, 700);
  assert.equal(u(s, "d").bonusBalance, 950);
  assert.equal(s.ledger.filter((v) => v.type.includes("refund")).length, 0);
});
test("expiry returns funds and reopen reserves again", async () => {
  const o = await make({ paymentMode: "wallet", usePassengerBonuses: true });
  await expire({ ...args(o), ttlMinutes: 0 }, auth(p));
  assert.equal(u(await read(), "p").balance, 1000);
  assert.equal(
    (await manage({ ...args(o), action: "reopen" }, auth(a))).success,
    true,
  );
  assert.equal(u(await read(), "p").balance, 700);
  await cancel(args(o), auth(p));
  assert.equal(u(await read(), "p").balance, 1000);
});
test("counteroffer needs owner acceptance and atomically reprices reservation", async () => {
  const o = await make({ paymentMode: "wallet", usePassengerBonuses: true });
  const r = await offer({ ...args(o), price: 700 }, auth(d));
  assert.equal(r.success, true);
  assert.equal(r.offer.rating, null);
  assert.equal(r.offer.etaMinutes, null);
  assert.equal((await read()).orders[0].status, 0);
  assert.equal((await list(args(o), auth(x))).success, false);
  assert.equal(
    (await respond({ ...args(o), offerId: r.offer.id, accept: true }, auth(x)))
      .success,
    false,
  );
  for (let i = 0; i < 2; i++)
    assert.equal(
      (
        await respond(
          { ...args(o), offerId: r.offer.id, accept: true },
          auth(p),
        )
      ).accepted,
      true,
    );
  let s = await read();
  assert.equal(s.orders[0].price, 700);
  assert.equal(u(s, "p").balance, 500);
  assert.equal(u(s, "d").bonusBalance, 930);
  await finish(o);
  s = await read();
  assert.equal(u(s, "d").balance, 1700);
  assert.equal(u(s, "p").passengerBonusBalance, 14);
});
test("unaffordable counteroffer rolls back balances, price and ledger", async () => {
  const o = await make({ paymentMode: "wallet", usePassengerBonuses: true });
  const r = await offer({ ...args(o), price: 2000 }, auth(d)),
    before = await read();
  assert.equal(
    (await respond({ ...args(o), offerId: r.offer.id, accept: true }, auth(p)))
      .code,
    "PASSENGER_BALANCE_INSUFFICIENT",
  );
  const after = await read();
  assert.deepEqual(after.ledger, before.ledger);
  assert.equal(u(after, "p").balance, u(before, "p").balance);
  assert.equal(after.orders[0].price, 500);
  assert.equal(after.orders[0].status, 0);
});
test("expired offer cannot be accepted; direct accept closes proposals", async () => {
  const o = await make(),
    r = await offer({ ...args(o), price: 600 }, auth(d));
  await write((s) => {
    s.orders[0].offers[0].expiresAt = new Date(0).toISOString();
  });
  assert.equal(
    (await respond({ ...args(o), offerId: r.offer.id, accept: true }, auth(p)))
      .code,
    "OFFER_EXPIRED",
  );
  assert.equal((await accept(args(o), auth(d))).accepted, true);
  assert.deepEqual((await list(args(o), auth(p))).offers, []);
});
test("passenger Kaspi request credits cash only after admin confirms and only once", async () => {
  const params = {
    amount: 2000,
    kaspiPhone: "+77010000101",
    idempotencyKey: "passenger-topup",
  };
  assert.equal(
    (await driverTopup(params, auth(p))).code,
    "DRIVER_PROFILE_REQUIRED",
  );
  const r = await topup(params, auth(p));
  assert.equal(r.success, true);
  assert.equal(u(await read(), "p").balance, 1000);
  assert.equal(
    (await confirm({ paymentId: r.paymentId }, auth(p))).code,
    "ADMIN_REQUIRED",
  );
  for (let i = 0; i < 2; i++)
    assert.equal(
      (await confirm({ paymentId: r.paymentId }, auth(a))).success,
      true,
    );
  assert.equal(u(await read(), "p").balance, 3000);
});
test("tracking is private and fresh; rating is once after completion", async () => {
  const o = await make();
  await accept(args(o), auth(d));
  assert.equal((await track(args(o), auth(x))).success, false);
  await preferences(
    { coords: { latitude: 53, longitude: 75, accuracy: 10 } },
    auth(d),
  );
  assert.ok((await track(args(o), auth(p))).driverPosition);
  await write((s) => {
    u(s, "d").coordsUpdatedAt = new Date(0).toISOString();
  });
  assert.equal((await track(args(o), auth(p))).driverPosition, null);
  assert.equal((await rate({ ...args(o), stars: 5 }, auth(p))).success, false);
  await finish(o);
  for (let i = 0; i < 2; i++)
    assert.equal((await rate({ ...args(o), stars: 4 }, auth(p))).success, true);
  assert.equal(u(await read(), "d").ratingCount, 1);
  assert.equal(u(await read(), "d").ratingTotal, 4);
});
test("15 seconds of continuous accurate position triggers arrival then departure", () => {
  const driver = { id: "d", activeDriverOrderId: "t" },
    o = {
      id: "t",
      driverId: "d",
      status: 2,
      fromPoint: { latitude: 53, longitude: 75 },
    },
    s = { orders: [o] },
    changes = [];
  const apply = (status) => {
      o.status = status;
      changes.push(status);
      return { success: true };
    },
    near = { latitude: 53, longitude: 75, accuracy: 10 },
    far = { latitude: 53.0012, longitude: 75, accuracy: 10 };
  for (const ms of [0, 8000, 16000])
    observeDriverPosition(s, driver, near, apply, 100000 + ms);
  assert.deepEqual(changes, [3]);
  for (const ms of [24000, 32000, 40000])
    observeDriverPosition(s, driver, far, apply, 100000 + ms);
  assert.deepEqual(changes, [3, 4]);
});
test("bad GPS accuracy and teleport reset automatic status timers", () => {
  for (const bad of [
    { latitude: 53, longitude: 75, accuracy: 200 },
    { latitude: 54, longitude: 75, accuracy: 10 },
  ]) {
    const driver = { id: "d", activeDriverOrderId: "t" },
      o = {
        id: "t",
        driverId: "d",
        status: 2,
        fromPoint: { latitude: 53, longitude: 75 },
      },
      s = { orders: [o] },
      apply = () => {
        throw Error("must not transition");
      };
    observeDriverPosition(
      s,
      driver,
      { latitude: 53, longitude: 75, accuracy: 10 },
      apply,
      100000,
    );
    observeDriverPosition(s, driver, bad, apply, 108000);
    observeDriverPosition(s, driver, bad, apply, 116000);
    assert.equal(o.status, 2);
  }
});
test("manual arrival cannot be faked away from pickup or with stale inaccurate GPS", async () => {
  const from = { latitude: 53, longitude: 75 };
  const o = await make({ from });
  await accept(args(o), auth(d));
  assert.equal((await status(o, 3)).code, "PICKUP_GPS_REQUIRED");
  await preferences(
    { coords: { latitude: 54, longitude: 75, accuracy: 10 } },
    auth(d),
  );
  assert.equal((await status(o, 3)).code, "PICKUP_GPS_REQUIRED");
  await preferences({ coords: { ...from, accuracy: 200 } }, auth(d));
  assert.equal((await status(o, 3)).code, "PICKUP_GPS_REQUIRED");
  await preferences({ coords: { ...from, accuracy: 10 } }, auth(d));
  assert.equal((await status(o, 3)).success, true);
  assert.equal((await status(o, 4)).success, true);
});
test("admin edits cashback percent; invalid percentages and non-admin changes are refused", async () => {
  const { updateRuntimeSettingsAsync: update } = require("../src/settings");
  assert.equal(
    (await update({ fields: { passengerBonusPercent: 5 } }, auth(p))).success,
    false,
  );
  assert.equal((await update({fields:{passengerBonusPercent:101}},auth(a))).code,'SETTING_INVALID');
  assert.equal(
    (
      await update(
        {
          fields: { passengerBonusPercent: 5, passengerBonusSpendPercent: 100 },
        },
        auth(a),
      )
    ).success,
    true,
  );
  const o = await make();
  await accept(args(o), auth(d));
  await finish(o);
  assert.equal(u(await read(), "p").passengerBonusBalance, 225);
});

test("account deletion cannot bypass an assigned trip or erase escrow", async () => {
  const { deleteCurrentAccountDeepAsync: remove } = require("../src/users");
  const o = await make({ paymentMode: "wallet" });
  await accept(args(o), auth(d));
  for (const who of [p, d])
    assert.equal(
      (await remove({}, auth(who))).code,
      "ACTIVE_TRIP_ACCOUNT_DELETE_DENIED",
    );
  assert.equal((await read()).orders.length, 1);
});

test('concurrent acceptances assign one driver and charge only one commission', async()=>{
  const o=await make({paymentMode:'wallet',usePassengerBonuses:true});
  await write(s=>s.users.push({...d,id:'d2',phone:'+77010000109'}));
  const one=await offer({...args(o),price:600},auth(d)),two=await offer({...args(o),price:700},auth({id:'d2'}));
  assert.equal((await read()).notifications.filter(n=>n.type==='DRIVER_PRICE_OFFER').length,2);
  const results=await Promise.all([one,two].map(r=>respond({...args(o),offerId:r.offer.id,accept:true},auth(p))));
  assert.equal(results.filter(r=>r.accepted).length,1);
  const s=await read();assert.equal(s.ledger.filter(e=>e.type==='order_commission').length,1);
  assert.equal(u(s,'p').balance,1000-(s.orders[0].price-200));
});
test('insufficient driver commission rolls back a repriced reservation',async()=>{
 const o=await make({paymentMode:'wallet',usePassengerBonuses:true});const r=await offer({...args(o),price:700},auth(d));
 await write(s=>{u(s,'d').balance=0;u(s,'d').bonusBalance=0;});const before=await read();
 assert.equal((await respond({...args(o),offerId:r.offer.id,accept:true},auth(p))).code,'INSUFFICIENT_DRIVER_BALANCE');
 const after=await read();assert.equal(u(after,'p').balance,u(before,'p').balance);assert.equal(after.orders[0].price,500);assert.deepEqual(after.ledger,before.ledger);
});

test('driver counteroffer lasts 30 seconds and expiry never changes money or assigns the order', async () => {
  const o = await make();
  const before = await read();
  const result = await offer({...args(o),price:700},auth(d));
  assert.equal(result.success,true);
  const life=Date.parse(result.offer.expiresAt)-Date.parse(result.offer.createdAt);
  assert.ok(life>=30000&&life<=30005);
  const own=await list(args(o),auth(d));
  assert.equal(own.success,true);assert.equal(own.offers.length,1);assert.equal(own.offers[0].driverId,d.id);
  assert.equal((await list(args(o),auth(x))).code,'ORDER_FORBIDDEN');
  await write(s=>{s.orders.find(v=>v.id===o.orderDocPath.split('/').pop()).offers[0].expiresAt=new Date(Date.now()-1).toISOString();});
  assert.equal((await list(args(o),auth(d))).offers[0].status,'expired');
  assert.equal((await respond({...args(o),offerId:result.offer.id,accept:true},auth(p))).code,'OFFER_EXPIRED');
  const after=await read();
  const order=after.orders.find(v=>v.id===o.orderDocPath.split('/').pop());
  assert.equal(order.status,0);assert.equal(order.price,500);assert.ok(!order.driverId);
  assert.equal(u(after,d.id).balance,u(before,d.id).balance);
  assert.equal(u(after,d.id).bonusBalance,u(before,d.id).bonusBalance);
});

test('driver waiting can observe acceptance without seeing competing driver offers', async () => {
  const o=await make();const result=await offer({...args(o),price:700},auth(d));
  assert.equal((await respond({...args(o),offerId:result.offer.id,accept:true},auth(p))).success,true);
  const state=await list(args(o),auth(d));
  assert.equal(state.assignedToCurrentDriver,true);assert.equal(state.orderStatus,2);
  assert.equal(state.offers.length,1);assert.equal(state.offers[0].id,result.offer.id);
});
