// Full browser journey against the isolated backend; providers remain test adapters.
const fs=require('node:fs');
module.exports=async function journey(){
 const screenshot=async(q,name)=>shot(q,'journey-'+name);
 const passengerBefore=(await call(40,'getSessionBootstrap')).user;
 const driverBefore=(await call(1,'getSessionBootstrap')).user;
 try {
  await p.getByRole('button',{name:'Куда едем?',exact:true}).click();
  await p.getByRole('textbox',{name:'Откуда',exact:true}).fill('Тестовая 1');
  await p.getByRole('button',{name:'Тестовая 1, Железинка',exact:true}).click({timeout:15000});
  await p.getByRole('textbox',{name:'Куда',exact:true}).fill('Тестовая 10');
  await p.getByRole('button',{name:'Тестовая 10, Железинка',exact:true}).click({timeout:15000});
  await p.getByRole('button',{name:'Готово',exact:true}).click();
  await p.getByRole('button',{name:'Заказать',exact:true}).click();
  await p.getByRole('textbox',{name:'Цена поездки',exact:true}).fill('500');
  await p.getByRole('checkbox',{name:/Со счёта приложения/}).click();
  await p.getByRole('switch').click();
  await p.getByRole('button',{name:'Искать водителя',exact:true}).click();
  await d.getByRole('button',{name:'Смотреть заказы',exact:true}).click();
  await d.getByRole('button',{name:/Тестовая 1.*Тестовая 10/}).click({timeout:15000});
  await d.getByRole('button',{name:'Предложить свою цену',exact:true}).click();
  await d.getByRole('textbox',{name:'Цена, ₸',exact:true}).fill('700');
  await d.getByRole('button',{name:'Предложить',exact:true}).click();
  await p.getByRole('button',{name:'Принять предложение',exact:true}).waitFor({timeout:15000});
  await screenshot(p,'counteroffer');
  await p.getByRole('button',{name:'Принять предложение',exact:true}).click();
  const ref=(await call(40,'getSessionBootstrap')).activePassengerOrderRef;
  await d.getByRole('button',{name:'Начать поездку',exact:true}).waitFor({timeout:35000});
  const arrived=(await call(1,'getSessionBootstrap')).activeDriverOrder;
  await d.getByRole('button',{name:'Начать поездку',exact:true}).click();
  await p.getByText('После начала поездки отмена недоступна.',{exact:true}).waitFor({timeout:10000});
  const started=await text(p);await screenshot(p,'started');
  await d.getByRole('button',{name:'Завершить поездку',exact:true}).click();
  await p.getByText('Поездка завершена',{exact:true}).waitFor({timeout:10000});
  await screenshot(p,'passenger-receipt');await screenshot(d,'driver-receipt');
  const passengerAfter=(await call(40,'getSessionBootstrap')).user;
  const driverAfter=(await call(1,'getSessionBootstrap')).user;
  const actual={ref,passengerBefore:{cash:passengerBefore.balance,bonus:passengerBefore.passengerBonusBalance},passengerAfter:{cash:passengerAfter.balance,bonus:passengerAfter.passengerBonusBalance},driverBefore:{cash:driverBefore.balance,bonus:driverBefore.bonusBalance},driverAfter:{cash:driverAfter.balance,bonus:driverAfter.bonusBalance},arrivedStatus:arrived.status,cancelAbsent:!started.includes('Отменить заказ')};
  check('Final browser: counteroffer, automatic arrival, trip and full bonus payment','passenger/driver','Driver cash+700, bonus-70; passenger bonus-700+14, cash unchanged; no cancellation after start',actual,
   actual.cancelAbsent&&arrived.status===3&&driverAfter.balance===driverBefore.balance+700&&driverAfter.bonusBalance===driverBefore.bonusBalance-70&&passengerAfter.balance===passengerBefore.balance&&passengerAfter.passengerBonusBalance===passengerBefore.passengerBonusBalance-686,
   'journey-counteroffer.png;journey-started.png;journey-passenger-receipt.png;journey-driver-receipt.png');
  await p.getByRole('button',{name:'Оценка 5 из 5',exact:true}).click();
  await p.getByRole('button',{name:'Оценить поездку',exact:true}).click();
  const tracking=await call(40,'getTripTracking',{orderDocPath:ref});
  check('Final browser: rating and completed trips','passenger','Rating5, one rating, one completed trip',tracking.driver,tracking.driver?.rating===5&&tracking.driver?.ratingCount===1&&tracking.driver?.completedTrips===1,'browser-api-trace.json');
 }catch(e){await screenshot(p,'failure-passenger');await screenshot(d,'failure-driver');check('Final browser journey','passenger/driver','Full visible flow',e.message,false,'journey-failure-passenger.png;journey-failure-driver.png');}
 fs.writeFileSync(auditOutputDir+'/browser-api-trace.json',JSON.stringify(apiTrace,null,2));
 fs.writeFileSync(auditOutputDir+'/browser-errors.json',JSON.stringify(errors,null,2));
 return {checks:checks.length,failed:checks.filter(x=>x.status==='failed'),errors};
};
