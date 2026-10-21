require('dotenv').config();
const { withStoreAsync } = require('../src/store');

const VILLAGES = ['Жетекши', 'Железинка', 'Теренколь', 'Иртышск'];

function configureLaunchDefaultsInStore(store) {
  store.settings ||= {};
  if (store.settings.launchVillagesV1Applied === true) return false;
  store.cityPrices ||= [];
  for (const title of VILLAGES) {
    const existing = store.cityPrices.find(item => item.title === title);
    if (existing) {
      existing.priceDay = 500;
      existing.priceNight = 500;
    } else {
      store.cityPrices.push({ id: title, title, priceDay: 500, priceNight: 500 });
    }
  }
  store.settings.driverBonusEnabled ??= true;
  store.settings.driverBonusTargetOrders ??= 10;
  store.settings.driverBonusReward ??= 1000;
  store.settings.launchVillagesV1Applied = true;
  return true;
}

if (require.main === module) {
  withStoreAsync(async store => configureLaunchDefaultsInStore(store))
    .then(changed => { console.log(changed ? 'Launch defaults applied' : 'Launch defaults already applied'); process.exit(0); })
    .catch(error => { console.error(error.message); process.exit(1); });
}

module.exports = { VILLAGES, configureLaunchDefaultsInStore };
