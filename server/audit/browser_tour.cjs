// Run from the interactive browser controller: return await require('./browser_tour.cjs')();
// Source declarations and successful screen loads do not imply every control was clicked.
const fs = require('node:fs');
module.exports = async function tour() {
  const cases = [
    ['passenger', p, [
      ['/homePage', 'Куда поедем'], ['/profile', 'Synthetic passenger 40'],
      ['/settings', 'Настройки'], ['/meOrder', 'История'],
      ['/supportChat', 'поддерж'], ['/about', 'О приложении'],
      ['/politika', 'Полит'], ['/tarif', 'Тариф'], ['/cityToCity', 'Куда поедем'],
    ]],
    ['driver', d, [
      ['/homeDriver', 'Денежный счёт'], ['/profile', 'Synthetic driver 1'],
      ['/meOrder', 'История'],
    ]],
    ['admin', a, [
      ['/admin', 'MTaxi'], ['/admin/moneyStats', 'Статистика денег'],
      ['/admin/driverStats', 'Статистика'], ['/admin/notifications', 'Рассыл'],
      ['/admin/support', 'поддерж'],
    ]],
  ];
  global.tourInventory = [];
  for (const [role, existing, paths] of cases) {
    const q = await existing.context().newPage();
    q.setDefaultTimeout(8000);
    q.setDefaultNavigationTimeout(20000);
    q.on('pageerror', e => errors.push({role, error:e.message}));
    for (const [path, expected] of paths) {
      const name = 'tour-' + role + '-' + path.replace(/[^a-zA-Z]/g, '-');
      try {
        await q.goto(base + path, {waitUntil:'domcontentloaded'});
        await q.locator('flutter-view').waitFor({timeout:20000});
        await q.waitForTimeout(1000);
        await q.locator('flt-semantics-placeholder').evaluateAll(es => es.forEach(e => e.click()));
        let body = '';
        for (let attempt = 0; attempt < 20; attempt++) {
          body = await text(q);
          if (body.toLowerCase().includes(expected.toLowerCase())) break;
          await q.waitForTimeout(500);
          await q.locator('flt-semantics-placeholder').evaluateAll(es => es.forEach(e => e.click()));
        }
        await shot(q, name);
        tourInventory.push({role, path, actualUrl:q.url(), observed:body,
          buttons:await q.getByRole('button').evaluateAll(es => es.map(e => e.getAttribute('aria-label') || e.innerText)),
          inputs:await q.getByRole('textbox').evaluateAll(es => es.map(e => e.getAttribute('aria-label')))});
        check('Open screen ' + path + ' (' + role + ')', role,
          'Screen renders its expected content', body,
          body.toLowerCase().includes(expected.toLowerCase()), name + '.png');
      } catch (e) {
        check('Open screen ' + path + ' (' + role + ')', role,
          'Screen renders its expected content', e.message, false, name + '.png');
      }
      fs.writeFileSync('/workspace/mtaxi/output/full-audit/browser-elements.json', JSON.stringify(tourInventory, null, 2));
    }
    await q.close();
  }
  return {screens:tourInventory.length, failed:checks.filter(x => x.status === 'failed').map(x => x.name)};
};
