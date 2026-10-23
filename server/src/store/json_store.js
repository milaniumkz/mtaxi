const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const dataDir = process.env.MTAXI_DATA_DIR || path.join(__dirname, "../../data");
const dataFile = path.join(dataDir, "local-db.json");

const seed = {
  users: [
    {
      id: "u_driver_7086362153",
      phone: "+77086362153",
      password: "123456",
      displayName: "Данил Сельстьянов",
      city: "Белоусовка",
      roleState: "DRIVER_ONLINE",
      isDriver: true,
      statusDriver: "approved",
      balance: 10000,
    },
    {
      id: "u_passenger_7052597368",
      phone: "+77052597368",
      password: "123456",
      displayName: "Дмитрий Штрахов",
      city: "Белоусовка",
      roleState: "PASSENGER",
      isDriver: false,
      balance: 0,
    },
    {
      id: "u_admin_70000000000",
      phone: "+70000000000",
      password: "A7059012671!",
      displayName: "Администратор",
      city: "Белоусовка",
      roleState: "ADMIN",
      role: "admin",
      isDriver: false,
      balance: 0,
    },
  ],
  orders: [],
  payments: [],
  ledger: [],
  chats: [],
  chatMessages: [],
  fcmTokens: [],
  notifications: [],
  notificationDeliveries: [],
  pushDeliveryAcks: [],
  auditLogs: [],
  genericCollections: {},
  settings: {
    taxiFallbackPrice: 800,
    deliveryFallbackPrice: 1200,
    deliveryExtra: 400,
    nightMultiplier: 1.5,
    orderCommissionPercent: 10,
    pendingOrderLifetimeMin: 15,
    driverBonusEnabled: true,
    driverBonusTargetOrders: 10,
    driverBonusReward: 1000,
  },
  cityPrices: [
    ...['Жетекши', 'Железинка', 'Теренколь', 'Иртышск'].map(title => ({
      title, priceDay: 500, priceNight: 500,
    })),
    {
      title: "Белоусовка",
      priceDay: 1000,
      priceNight: 1500,
      deliveryPrice: 1500,
    },
  ],
  intercityTariff: {
    basePrice: 500,
    pricePerKm: 130,
    minPrice: 3000,
  },
  intercityRoutes: [
    {
      id: "route_belousovka_ust_kamenogorsk",
      ot: "Белоусовка",
      kuda: "Усть-Каменогорск",
      tarif: 5000,
      com: 10,
    },
  ],
  content: {
    politika: {
      text: "",
    },
    about: {
      title: "",
    },
    supportContacts: {
      whatsAppPhone: "",
      callPhone: "",
    },
    tariffsContent: {
      driverTariffs: "",
      passengerTariffs: "",
    },
  },
};

function ensureStore() {
  fs.mkdirSync(dataDir, { recursive: true });
  if (!fs.existsSync(dataFile)) {
    fs.writeFileSync(dataFile, JSON.stringify(seed, null, 2));
  }
}

function readStore() {
  ensureStore();
  return JSON.parse(fs.readFileSync(dataFile, "utf8"));
}

function writeStore(data) {
  ensureStore();
  fs.writeFileSync(dataFile, JSON.stringify(data, null, 2));
}

function withStore(mutator) {
  const data = readStore();
  const result = mutator(data);
  writeStore(data);
  return result;
}

async function readStoreAsync() {
  return readStore();
}

async function writeStoreAsync(data) {
  writeStore(data);
}

let mutationQueue = Promise.resolve();
function withStoreAsync(mutator) {
  // Serialize server mutations so concurrent confirmations and order completions
  // cannot overwrite each other's balances or reward markers.
  const operation = mutationQueue.then(async () => {
    const data = await readStoreAsync();
    const result = await mutator(data);
    await writeStoreAsync(data);
    return result;
  });
  mutationQueue = operation.catch(() => {});
  return operation;
}

function newId(prefix) {
  return `${prefix}_${crypto.randomUUID()}`;
}

async function storeHealth() {
  ensureStore();
  return {
    ok: true,
    type: "json",
    dataFile,
  };
}

module.exports = {
  storeHealth,
  readStore,
  writeStore,
  withStore,
  readStoreAsync,
  writeStoreAsync,
  withStoreAsync,
  newId,
};
