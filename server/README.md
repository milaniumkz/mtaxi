# MTaxi local backend

Локальный backend для постепенного переноса приложения на отдельный сервер.
Firebase в новой архитектуре используется только как FCM transport для push-уведомлений.

## Запуск

```bash
cd server
npm install
npm run start
```

Если Docker недоступен, можно запустить тот же HTTP backend локально на JSON-store из корня проекта:

```bash
./scripts/start_local_json_backend.sh
```

Скрипт включает только local-dev режимы: JSON-store, local SMS, local payment page и simulated push без Firebase. Он ждет `/readyz`, запускает `npm run smoke` и печатает команды Flutter для Web/Desktop (`127.0.0.1`) и Android emulator (`10.0.2.2`). Остановить процесс можно через `Ctrl+C`.

Одноразовая проверка без ручной остановки:

```bash
./scripts/check_local_json_backend.sh
```

## Docker + PostgreSQL

Полный пошаговый перенос на арендный сервер: `docs/backend_deployment_checklist.md`.

Для локальной проверки полноценного backend с PostgreSQL из корня проекта:

```bash
./scripts/start_local_backend.sh
```

Скрипт поднимает `docker-compose.backend.yml`, ждет `/readyz`, запускает `npm run smoke` с проверкой локального админа и печатает команды Flutter с `MTAXI_BACKEND_URL`: отдельно для Web/Desktop (`127.0.0.1`) и Android emulator (`10.0.2.2`). Локальный админ compose: `+77000000000` / `local-compose-admin-password`.
Ручной вариант: `docker compose -f docker-compose.backend.yml up --build`.
Остановить локальный backend без удаления базы и upload-файлов:

```bash
./scripts/stop_local_backend.sh
```

Compose поднимает:

- `postgres` с применением `server/db/schema.sql` при первом создании volume;
- `backend` на `http://localhost:8080`;
- volume для PostgreSQL и volume для `/var/lib/mtaxi/uploads`.

Backend-контейнер перед стартом выполняет `npm run db:apply-schema`, затем `npm run preflight`. Это применяет PostgreSQL-схему и к уже существующему volume, а не только при первом создании базы; после применения скрипт проверяет baseline в `schema_migrations`. Если `MTAXI_SEED_ADMIN_ON_START=true`, перед HTTP-стартом также выполнится `npm run seed:admin` и первый админ будет создан или обновлен автоматически. Для VPS используйте `docker-compose.production.yml` с `server/.env`; в этом файле задаются `POSTGRES_PASSWORD` и `DATABASE_URL` с тем же паролем. Перед запуском можно выполнить `npm run validate:production-deploy`, чтобы проверить compose/env без подключения к базе. Для автозапуска, ежедневного backup и регулярного monitor есть шаблоны `deploy/systemd/mtaxi-backend.service`, `deploy/systemd/mtaxi-backup.service`, `deploy/systemd/mtaxi-backup.timer`, `deploy/systemd/mtaxi-monitor.service`, `deploy/systemd/mtaxi-monitor.timer` и установщик `deploy/install_vps_units.sh`. Локальный `docker-compose.backend.yml` оставлен для development.

При остановке контейнера backend обрабатывает `SIGTERM`/`SIGINT`: останавливает maintenance-worker и закрывает HTTP server.

Пример production/local env лежит в `server/.env.example`. На сервере значения можно задать в process manager или скопировать в `.env`. Backend загружает `.env` через `dotenv` при `npm run start`, `npm run preflight` и `npm run db:migrate-json`.
Runtime backend рассчитан на Node.js 20 или новее; `npm run preflight` проверяет это до production-запуска.

Перед запуском production можно проверить окружение:

```bash
npm run preflight
npm run preflight:production
```

Preflight проверяет обязательные env, корректный `PORT`, внешний HTTPS `MTAXI_PUBLIC_BASE_URL`, PostgreSQL `DATABASE_URL`, production payment provider, безопасный режим payment callback secret и запись в upload-папку. Локальный public URL (`localhost`, `127.0.0.1`, LAN) проходит только при `MTAXI_ALLOW_LOCAL_PUBLIC_BASE_URL=true` для dev/compose.
`npm run preflight:production` принудительно ставит `NODE_ENV=production` и ловит случайно включенные dev-флаги до запуска на VPS.
Секреты и пароли с placeholder-текстом вроде `replace-with`, `change-this` или `mtaxi_change_me` preflight не пропустит.
При `NODE_ENV=production` прямой `npm start` тоже выполняет preflight перед открытием порта.

Проверка:

```bash
curl http://127.0.0.1:8080/health
curl http://127.0.0.1:8080/livez
curl http://127.0.0.1:8080/readyz
curl -X POST http://127.0.0.1:8080/call/getStoreHealth -H 'Content-Type: application/json' -d '{}'
npm run smoke
```

Удаленный backend проверяется так:

```bash
MTAXI_SMOKE_BASE_URL=https://api.example.kz MTAXI_SMOKE_EXPECT_STORE=postgres npm run smoke
```

Можно дополнительно проверить авторизацию и админские callable:

```bash
MTAXI_SMOKE_BASE_URL=https://api.example.kz \
MTAXI_SMOKE_EXPECT_STORE=postgres \
MTAXI_SMOKE_ADMIN_PHONE=77000000000 \
MTAXI_SMOKE_ADMIN_PASSWORD='password' \
MTAXI_SMOKE_PASSENGER_PHONE=77000000001 \
MTAXI_SMOKE_PASSENGER_PASSWORD='password' \
MTAXI_SMOKE_DRIVER_PHONE=77000000002 \
MTAXI_SMOKE_DRIVER_PASSWORD='password' \
npm run smoke
```

Если `MTAXI_SMOKE_EXPECT_STORE=postgres`, внешний smoke URL должен быть `https://...`. `http://127.0.0.1:8080` остается допустимым для локальной проверки на самом сервере.

Для регулярной read-only проверки после деплоя используйте monitor:

```bash
MTAXI_MONITOR_BASE_URL=https://api.example.kz MTAXI_MONITOR_EXPECT_STORE=postgres npm run monitor
```

Monitor также проверяет backend-only архитектуру. Если добавить `MTAXI_MONITOR_ADMIN_PHONE` и `MTAXI_MONITOR_ADMIN_PASSWORD`, он дополнительно проверит админские read-only вызовы: пользователи, деньги и push-журнал.

Для диагностики VPS из корня проекта есть read-only helper:

```bash
MTAXI_OPS_BASE_URL=http://127.0.0.1:8080 ./deploy/ops_check.sh
```

## Локальные данные

По умолчанию backend пишет локальные данные в:

```bash
server/data/local-db.json
```

Можно задать другое место:

```bash
export MTAXI_DATA_DIR=/tmp/mtaxi-data
npm run start
```

Для публичного сервера задайте внешний адрес backend. Он используется для ссылок на загруженные файлы и страницу оплаты:

```bash
export MTAXI_PUBLIC_BASE_URL=https://api.example.kz
```

`MTAXI_ALLOW_LOCAL_PUBLIC_BASE_URL=true` и `MTAXI_ALLOW_INSECURE_PUBLIC_BASE_URL=true` используйте только локально. На арендном сервере оба флага должны быть `false`, иначе платежи и файлы могут получить внутренние или небезопасные ссылки.

Для продакшена нужно ограничить CORS только origin-доменами приложения и админки. `npm run preflight` проверяет, что `MTAXI_CORS_ORIGINS` содержит реальные `http/https` origins без path/query и без `*`. Без этой переменной CORS остается открытым только для локальной разработки. `MTAXI_JSON_BODY_LIMIT` должен быть положительным значением с единицей `b/kb/mb/gb`, это тоже проверяет `preflight`:

```bash
export MTAXI_CORS_ORIGINS=https://mtaxi.example.kz,https://admin.example.kz
export MTAXI_JSON_BODY_LIMIT=25mb
export MTAXI_TRUST_PROXY=1
```

Backend отключает `x-powered-by` и ставит базовые security headers. Если backend стоит за nginx/Caddy/Traefik, задайте `MTAXI_TRUST_PROXY=true` или количество proxy-hop, например `1`; `npm run preflight` проверяет формат.

Каждый HTTP-ответ получает `X-Request-Id`. Access logs включены по умолчанию (`MTAXI_ACCESS_LOGS=true`) и пишут только method/path/status/duration/requestId без тела запроса и без query-параметров. Ошибки HTTP тоже возвращаются JSON-ом с `success:false`, `code` и `requestId`, включая неизвестные routes и некорректный JSON.

Файлы из `/uploads` отдаются с `nosniff`, `Cross-Origin-Resource-Policy: cross-origin` и управляемым cache TTL. По умолчанию TTL 30 дней, изменить можно через `MTAXI_UPLOAD_CACHE_MAX_AGE_SEC`; значение `0` отключает кеш. `npm run preflight` проверяет, что TTL не отрицательный.

Для полноценного сервера подготовлена PostgreSQL-схема:

```bash
psql "$DATABASE_URL" -f server/db/schema.sql
```

Из папки `server/` можно использовать npm-команды:

```bash
npm run db:schema
npm run db:apply-schema
npm run db:migrate-json
npm run db:backup
npm run db:restore
npm run smoke
```

Проверить примененную версию схемы на сервере:

```bash
psql "$DATABASE_URL" -c "select version, applied_at from schema_migrations order by applied_at desc;"
```

`GET /readyz`, `GET /health` и `getStoreHealth` в PostgreSQL-режиме также возвращают `schemaVersion` и `schemaAppliedAt`.

На чистой базе создать или обновить первого администратора:

```bash
export MTAXI_ADMIN_PHONE=+77000000000
export MTAXI_ADMIN_PASSWORD='strong-admin-password'
export MTAXI_ADMIN_NAME='Администратор'
npm run seed:admin
```

Команда idempotent: если админ с таким телефоном уже есть, она обновит роль, имя и пароль. Пароль сохраняется только как `scrypt` hash.

В Docker/Compose это можно включить автоматически через `MTAXI_SEED_ADMIN_ON_START=true`; `npm run preflight` проверит admin env до запуска.
Телефон первого админа должен быть в казахстанском формате, например `+77000000000` или `77000000000`; дефолтный placeholder `+70000000000` preflight не пропустит.

`db:migrate-json` читает `server/data/local-db.json`, либо `MTAXI_JSON_FILE`, применяет `db/schema.sql` и переносит данные в PostgreSQL. Перед `COMMIT` команда сверяет количество перенесенных записей в PostgreSQL с исходным JSON и падает с `ROLLBACK`, если целевых записей меньше. После переноса команда печатает отчет (`users=..., orders=..., payments=...`) по источнику и PostgreSQL. Текущий локальный JSON-store остается для разработки без сервера.

`db:backup` создает PostgreSQL dump, архив upload-папки и manifest в `MTAXI_BACKUP_DIR` или `server/backups`. Старые backup-файлы чистятся по `MTAXI_BACKUP_RETENTION_DAYS` (по умолчанию 30). Manifest помечается `type: mtaxi-backup`, хранит имена файлов относительно папки backup, поэтому его можно переносить вместе с dump/archive на другой сервер. `db:restore` принимает путь к manifest, отклоняет manifest другого типа и требует `MTAXI_RESTORE_CONFIRM=YES`, чтобы случайно не перезаписать production-данные; uploads восстанавливаются прямо в текущую `MTAXI_UPLOAD_DIR`.

Доменные backend-модули импортируют store через `src/store/index.js`, а не напрямую через `json_store.js`. По умолчанию используется JSON-store, а для полноценного сервера включается PostgreSQL:

```bash
MTAXI_STORE=postgres DATABASE_URL="postgres://..." npm start
```

`MTAXI_STORE=postgres` подключает `src/store/postgres_store.js`. Старые sync-методы `readStore/writeStore/withStore` намеренно падают. Это защита от тихого запуска продакшена на неперенесенном контракте. Production endpoint-ы используют `readStoreAsync/withStoreAsync`.

Async-контракт уже добавлен: JSON-store поддерживает `readStoreAsync`, `writeStoreAsync`, `withStoreAsync`. PostgreSQL-store реализует эти методы для `users`, `sms_codes`, `orders`, `payments`, `withdrawals`, `ledger`, `support_chats`, `support_messages`, `fcm_tokens`, `notifications`, `notification_deliveries`, `push_delivery_acks`, `settings`, `intercityTariff`, `content_documents`, `city_prices`, `intercity_routes`, `generic_documents` и `audit_logs`.

Справочный content API тоже переведен на async-контракт: `getContentDocumentAsync`, `adminUpdateContentDocumentAsync`, `adminSavePolitikaAsync`.

Тарифы поселков (`City`) тоже переведены на async-контракт: `listCityTariffsAsync`, `adminListCityTariffsAsync`, `adminUpsertCityTariffAsync`.

Маршруты межгорода тоже переведены на async-контракт: `listIntercityRoutesAsync`, `adminListIntercityRoutesAsync`, `adminUpsertIntercityRouteAsync`.

Bootstrap сессии тоже переведен на async-контракт: `getSessionBootstrapAsync`. `call_router` использует async-версию, чтобы маршрутизация входа приложения уже шла через переходный backend-store слой.

Backend-авторизация тоже переведена на async-контракт: вход по паролю, поиск номера, локальная SMS-сессия, запись SMS-кода и проверка bearer-токена используют `readStoreAsync/withStoreAsync`.

JWT и SMS hash подписываются текущим `MTAXI_TOKEN_SECRET`. Смена этого секрета инвалидирует существующие access-token и неиспользованные SMS-коды, поэтому на production его нужно задать один раз длинным случайным значением и хранить как secret.

Публичные auth endpoint-ы (`passwordLogin`, `requestSmsCode`, `verifySmsCode`, `createSmsSession`) защищены in-memory rate limit по IP и телефону. Настройки: `MTAXI_AUTH_RATE_LIMIT_WINDOW_SEC` и `MTAXI_AUTH_RATE_LIMIT_MAX`; `npm run preflight` проверяет, что оба значения положительные.

SMS-код отправляется и проверяется на backend через `requestSmsCode`/`verifySmsCode`; `createSmsSession` выдает токен только после verified SMS-кода и помечает код как `consumed`. Клиент больше не обязан знать правильный код для backend-режима. Новые коды в store/PostgreSQL сохраняются как `smsCodeHash`, открытый код возвращается только в локальном dev-режиме. `MTAXI_SMS_CODE_TTL_SEC` задает срок кода, `MTAXI_SMS_RESEND_COOLDOWN_SEC` ограничивает повторную отправку. `MTAXI_SMS_PROVIDER=local`, `MTAXI_ALLOW_LOCAL_SMS=true` и `MTAXI_SMS_DEV_RETURN_CODE=true` разрешены только для локальной разработки. Для production использовать `MTAXI_SMS_PROVIDER=http`, `MTAXI_SMS_DEV_RETURN_CODE=false` и реальные env SMS-провайдера. `npm run preflight` проверяет, что SMS URL внешний `https://` и не localhost/LAN, метод `POST/PUT/PATCH`, JSON headers, JSON body template с `{{phone}}` и `{{message}}` или `{{code}}`, а также запрещает возврат SMS-кода клиенту без local-dev флага.

Пользовательские операции тоже переведены на async-контракт: регистрация пассажира и водителя, настройки профиля, установка пароля и глубокое удаление аккаунта имеют async-версии, а `call_router` вызывает именно их.

Read-only операции заказов тоже переведены на async-контракт: расчет цены, детали заказа, лента водителя, мои заказы и админский список заказов. `call_router` вызывает async-версии через переходный store-слой.

Write-операции заказов тоже переведены на async-контракт: создание пассажиром и админом, истечение, принятие водителем, отмена пассажиром и смена статуса водителем. Баланс, активные ссылки и push-очередь сохраняются в той же транзакционной точке `withStoreAsync`.

Денежные операции тоже переведены на async-контракт: пополнения, проверка статуса, подтверждение/ошибка платежа, заявки на вывод, админские списки и статистика денег. `call_router` вызывает async-версии через `withStoreAsync`.

Создание платежа в боевом режиме должно идти через backend в Kassa24: backend создает инвойс в `https://ecommerce.pult24.kz/payment/create`, сохраняет `paymentId` и отдает приложению только готовый `paymentUrl`. Локальная HTML-страница `/local-payment/:paymentId` разрешена только для явных dev-тестов с `MTAXI_PAYMENT_PROVIDER=local` и `MTAXI_ALLOW_LOCAL_PAYMENT=true`.

```bash
export MTAXI_PAYMENT_PROVIDER=kassa24
export MTAXI_KASSA24_LOGIN='...'
export MTAXI_KASSA24_PASSWORD='...'
export MTAXI_KASSA24_MERCHANT_ID='...'
export MTAXI_ALLOW_LOCAL_PAYMENT=false
```

Временный `redirect` provider тоже поддерживается, но только если задан внешний `MTAXI_PAYMENT_URL_TEMPLATE`. Для redirect provider `npm run preflight` проверяет, что `MTAXI_PAYMENT_URL_TEMPLATE` является внешним `https://` URL, не localhost/LAN, и содержит `{{paymentId}}` и `{{amount}}`. Если в шаблоне используется `{{publicBaseUrl}}`, проверяется итоговый URL с текущим `MTAXI_PUBLIC_BASE_URL`.

Платежный callback подготовлен отдельным HTTP endpoint-ом:

```bash
curl -X POST http://127.0.0.1:8080/payments/kassa24/callback \
  -H 'Content-Type: application/json' \
  -H 'x-mtaxi-payment-secret: optional-secret' \
  -d '{"paymentId":"kassa24_id","status":"paid"}'
```

Если задан `MTAXI_PAYMENT_CALLBACK_SECRET`, callback принимает совпадающий секрет только из headers `x-mtaxi-payment-secret` или `x-kassa24-secret`. При необходимости legacy body-secret можно временно включить через `MTAXI_ALLOW_PAYMENT_CALLBACK_SECRET_IN_BODY=true`, но для production это должно быть `false`. Успешный callback зачисляет баланс один раз, повторный возвращает `PAYMENT_ALREADY_APPLIED`.

Чаты поддержки тоже переведены на async-контракт: создание/получение чата, отправка сообщений, прочтение, списки и удаление. `call_router` вызывает async-версии через `withStoreAsync`.

Push-домен тоже переведен на async-контракт: FCM-токены, очередь уведомлений, broadcast, история, flush очереди и ack доставки. Firebase используется только как транспорт отправки пушей.

Админские операции тоже переведены на async-контракт: список пользователей, audit log, обновление и создание пользователей, подтверждение/отклонение удаления фото авто, статус водителя, поселок, задержка, блокировка, баланс и управление заказом подключены в `call_router` через `withStoreAsync`.

Maintenance-задачи тоже подключены через async API: `runMaintenanceTasksAsync` закрывает просроченные заказы и отправляет push-очередь без sync-store вызовов в роутере.

Файловая загрузка подключена через async API: `uploadFileAsync` сохраняет файлы локально через `fs.promises` и возвращает `/uploads/...`; Firebase Storage не используется. Backend принимает только разрешенные MIME-типы JPEG, PNG, HEIC/HEIF, WebP, PDF и MP4, сверяет тип с сигнатурой файла и отдает сохраненные файлы с controlled cache headers.

## Подключение Flutter

Web:

```bash
flutter run -d chrome --dart-define=MTAXI_BACKEND_URL=http://127.0.0.1:8080
```

Android emulator:

```bash
flutter run -d emulator --dart-define=MTAXI_BACKEND_URL=http://10.0.2.2:8080
```

Production/release:

```bash
flutter build apk --release \
  --dart-define=MTAXI_BACKEND_URL=https://api.example.kz \
  --dart-define=MTAXI_REQUIRE_REMOTE_BACKEND=true
```

Перед релизом `scripts/check_release_ready.sh` требует доступный Flutter SDK. Если `flutter` не в `PATH`, передайте `FLUTTER_BIN=/path/to/flutter`.

`MTAXI_REQUIRE_REMOTE_BACKEND=true` запрещает клиенту работать с `localhost`, `127.0.0.1`, `10.0.2.2`, локальными LAN-адресами и публичным `http://` API. Это защита от случайной релизной сборки без внешнего HTTPS backend.

Firebase используется только для FCM push. Если `MTAXI_BACKEND_URL` не задан, клиент берет локальный backend `http://localhost:8080`; старый Firebase Functions/Firestore/Auth/Storage fallback в обычном режиме больше не включается.

Flutter `makeCloudCall()` отправляет все callable-запросы только в backend REST `POST /call/:name`. Wrapper находится в `lib/backend/backend_calls/backend_calls.dart`; пакет `cloud_functions` и старый путь `backend/cloud_functions` из клиента удалены.

Firebase Auth, Cloud Functions, Storage, Firestore, Crashlytics и Performance SDK из клиента удалены. Неиспользуемые platform-auth SDK `google_sign_in`/`sign_in_with_apple` тоже удалены, чтобы вход оставался только через backend SMS/password. Android Gradle больше не подключает Crashlytics plugin. В Firebase-клиенте остаются только `firebase_core` и `firebase_messaging` для FCM push. Старые FlutterFlow-типы `DocumentReference/Timestamp/GeoPoint` теперь приходят из локального compatibility layer `lib/backend/backend_refs_compat.dart` и не открывают сетевые Firestore операции.

Старые имена совместимого слоя `FirestoreRecord`, `FFFirestorePage`, `FFFirebaseStruct`, `FirestoreUtilData`, `mapFromFirestore`, `mapToFirestore` и путь `firestore_util.dart` заменены backend-compat именами и запрещены guard-тестом.

`ios/Podfile` больше не подключает `BackendRefs` вручную. После `flutter pub get` и `pod install` в generated dependencies и iOS lock-файлах остаются только `firebase_core`/`firebase_messaging` и `Firebase/Messaging` для FCM.

Если зависимости менялись повторно, на машине со Flutter выполнить:

```bash
flutter pub get
cd ios && pod install
```

Это пересоберет generated caches (`.dart_tool`, `.flutter-plugins-dependencies`, `ios/Podfile.lock`) без старых Firebase Auth/Functions/Storage/Firestore/Crashlytics/Performance pods.

Главный auth runtime Flutter работает через backend: `main.dart` слушает `mtaxiBackendUserStream`, `signInWithJwtToken` сохраняет backend access token и обновляет профиль через `getSessionBootstrap`, `signOut` не вызывает Firebase Auth в backend-режиме.

`main.dart` сохраняет пароль через backend `setPassword`, heartbeat через `updateUserPreferences(lastActive: true)` и проверяет активные пассажирские/водительские заказы через `getOrderDetails`; Firestore fallback для этих runtime-путей удален.

`BackendAuthManager` оставлен только как совместимый facade для старых импортов FlutterFlow. Внутри он backend-only: не импортирует `firebase_auth`, не вызывает Firebase Auth и работает с backend session.

Новые пароли backend хранит как `scrypt` hash. Старые локальные plaintext-пароли поддерживаются только для входа и автоматически обновляются до hash после успешного `passwordLogin`.

Ролевая маршрутизация backend отдает явные состояния `PASSENGER`, `DRIVER_PENDING`, `DRIVER_ONLINE`/`DRIVER_OFFLINE`, `DRIVER_ON_TRIP` и `BLOCKED`. Legacy `DRIVER_PENDING_REVIEW` нормализуется в `DRIVER_PENDING`. Заблокированный пользователь может получить bootstrap для экрана блокировки, но рабочие операции через `call_router` возвращают `USER_BLOCKED`.

Auth runtime полностью использует async-store: `passwordLogin`, `lookupUserByPhone`, SMS-сессия и bearer-token проверка не импортируют sync `readStore`.

Runtime settings тоже работают только через async-store: публичные exports `getRuntimeSettingsAsync` и `updateRuntimeSettingsAsync`.

Session bootstrap тоже работает только через async-store: `getSessionBootstrapAsync` очищает устаревшие active refs без sync `withStore`.

PostgreSQL readiness защищен тестом `runtime backend modules do not import the old sync store contract`: runtime-файлы вне `src/store/*` не должны использовать `readStore/writeStore/withStore`. Это не дает случайно вернуть старый JSON-only путь перед запуском `MTAXI_STORE=postgres`.

User runtime тоже работает только через async-store: регистрация пассажира/водителя, настройки профиля, пароль и удаление аккаунта экспортируются только как async операции.

Orders runtime тоже работает только через async-store: расчет цены, создание, получение, списки, принятие, отмена, истечение и смена статуса заказов экспортируются только как async операции.

Support runtime тоже работает только через async-store: создание/получение чата, сообщения, прочтение, списки и удаление экспортируются только как async операции.

Payments runtime тоже работает только через async-store: пополнения, статусы платежей, подтверждение/ошибка, выводы, списки и денежная статистика экспортируются только как async операции.

Push runtime тоже работает только через async-store: FCM-токены, broadcast, история, очередь, flush доставки и ack экспортируются только как async операции. Firebase остается только транспортом отправки FCM.

Admin runtime тоже работает только через async-store: пользователи, audit log, статусы водителя, баланс, управление заказами, тарифы, межгород, content и generic-коллекции экспортируются только как async операции.

## Уже перенесено

- `GET /health`, `GET /livez`, `GET /readyz`
  Возвращает состояние сервиса и хранилища: `store.type`, `store.ok`, для JSON путь к файлу, для PostgreSQL результат проверки подключения.
- `POST /call/getStoreHealth`
  Callable-проверка активного backend-хранилища для клиента/админки: возвращает `store.type`, `store.ok`, путь JSON-файла или ошибку PostgreSQL-подключения.
- `POST /call/passwordLogin`
- `POST /call/getSessionBootstrap`
- `POST /call/getRuntimeSettings`
- `POST /call/updateRuntimeSettings`
- `POST /call/getOrderQuote`
- `POST /call/getOrderDetails`
- `POST /call/listAvailableDriverOrders`
- `POST /call/listMyOrders`
- `POST /call/adminListOrders`
- `POST /call/createPassengerOrder`
- `POST /call/adminCreateOrder`
- `POST /call/acceptOrder`
- `POST /call/cancelPassengerOrder`
- `POST /call/advanceDriverOrderStatus`
- `POST /call/expirePendingOrderIfNeeded`
- `POST /call/submitPassengerRegistration`
- `POST /call/submitDriverRegistration`
- `POST /call/updateUserPreferences`
- `POST /call/setPassword`
- `POST /call/deleteCurrentAccountDeep`
- `POST /call/adminUpdateUserDocument`
- `POST /call/adminSavePolitika`
- `POST /call/adminCreateDriver`
- `POST /call/adminListUsers`
- `POST /call/adminListAuditLogs`
- `POST /call/approveDriver`
- `POST /call/approveVehiclePhotoDeletion`
- `POST /call/rejectVehiclePhotoDeletion`
- `POST /call/adminUpdateDriverCity`
- `POST /call/adminUpdateDriverOrderDelay`
- `POST /call/blockDriver`
- `POST /call/unblockDriver`
- `POST /call/adminTopUpDriverBalance`
- `POST /call/adminManageOrder`
- `POST /call/listCityTariffs`
- `POST /call/adminListCityTariffs`
- `POST /call/adminUpsertCityTariff`
- `POST /call/listIntercityRoutes`
- `POST /call/adminListIntercityRoutes`
- `POST /call/adminUpsertIntercityRoute`
- `POST /call/getContentDocument`
- `POST /call/adminUpdateContentDocument`
- `POST /call/uploadFile`
- `POST /call/createDriverTopUpPayment`
- `POST /call/getDriverTopUpPaymentStatus`
- `POST /call/confirmDriverTopUpPayment`
- `POST /call/failDriverTopUpPayment`
- `POST /call/getMoneyStats`
- `POST /call/ensureSupportChat`
- `POST /call/sendSupportChatMessage`
- `POST /call/markSupportChatRead`
- `POST /call/listSupportChats`
- `POST /call/getSupportChatMessages`
- `POST /call/adminSendSupportChatMessage`
- `POST /call/adminDeleteSupportChat`
- `POST /call/adminClearSupportChats`
- `POST /call/forwardGeocodeLookup`
- `POST /call/reverseGeocodeLookup`
- `POST /call/placesAutocomplete`
- `POST /call/placeDetails`
- `POST /call/suggestAddressesLookup`
- `POST /call/addFcmToken`
- `POST /call/updateFcmTokenState`
- `POST /call/createPushNotification`
- `POST /call/flushQueuedPushDeliveries`
- `POST /call/runMaintenanceTasks`
- `POST /call/ackPushDelivery`
- `GET /local-payment/:paymentId` локальная HTML-заглушка оплаты только для dev/compose
- `POST /create-token` для совместимости со старым token endpoint только в dev; в `NODE_ENV=production` отключен, а `npm run preflight` не пропустит `MTAXI_ENABLE_LEGACY_CREATE_TOKEN=true`

Операции заказа уже создают push-события в `notifications` и `notificationDeliveries`. Отправка обрабатывается через `flushQueuedPushDeliveries`: локально это симуляция, на сервере можно включить реальную Firebase Admin Messaging доставку. Firestore triggers для этого больше не нужны.

`runMaintenanceTasks` запускает фоновые задачи backend: закрывает просроченные свободные заказы и отправляет очередь push. Firebase scheduled functions для этого не нужны.

Backend также умеет запускать эти задачи внутренним interval-worker-ом без HTTP и без admin-токена. По умолчанию worker выключен. На сервере включить:

```bash
export MTAXI_MAINTENANCE_INTERVAL_SEC=30
export MTAXI_PENDING_ORDER_TTL_MIN=15
export MTAXI_MAINTENANCE_ORDER_LIMIT=100
export MTAXI_MAINTENANCE_PUSH_LIMIT=100
```

`npm run preflight` проверяет эти значения до запуска: интервал должен быть `0` или больше, TTL и лимиты должны быть положительными числами. SMS env тоже проверяется: `MTAXI_SMS_CODE_TTL_SEC > 0`, `MTAXI_SMS_RESEND_COOLDOWN_SEC >= 0`.

`flushQueuedPushDeliveries` обрабатывает очередь push-доставок. По умолчанию локально используется `simulated-local`, чтобы backend работал без Firebase. Для реальной отправки FCM на сервере включить:

```bash
export MTAXI_FCM_ENABLED=true
export MTAXI_ALLOW_SIMULATED_PUSH=false
export FIREBASE_SERVICE_ACCOUNT_JSON='{"project_id":"...","client_email":"...","private_key":"..."}'
# или GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
```

`npm run preflight` требует реальный FCM на production. Выключенный FCM разрешен только для локальной разработки через `MTAXI_ALLOW_SIMULATED_PUSH=true`; при `NODE_ENV=production` этот флаг запрещен. При `MTAXI_FCM_ENABLED=true` preflight проверяет Firebase Admin credentials; если используется `GOOGLE_APPLICATION_CREDENTIALS`, файл должен существовать.

Это единственное место backend, где используется Firebase: только FCM push transport. Auth, данные, файлы, заказы, платежи, чаты и настройки через Firebase не читаются.

Админская рассылка работает через `adminQueueBroadcast`: backend создает push-событие, считает получателей/токены и дублирует текст в чат поддержки. История рассылок читается через `adminListPushNotifications`; Firestore `ff_push_notifications` в backend-режиме не используется.

Адресные подсказки и геокодинг при `MTAXI_BACKEND_URL` идут через backend: `forwardGeocodeLookup`, `reverseGeocodeLookup`, `placesAutocomplete`, `placeDetails`, `suggestAddressesLookup`. Ключи Google/Yandex не должны уходить в клиент; `suggestAddressesLookup` сохраняет старый Flutter-формат `{ items: [...] }`.

Flutter API wrappers в `api_calls.dart` не имеют прямых Cloud Functions/Cloud Run URL fallback: адреса, геокодинг, платежи и вывод средств всегда вызывают backend.

Лента водителя через `listAvailableDriverOrders` фильтрует открытые заказы по радиусу, если переданы координаты водителя. Поселок водителя не отсекает заказ, чтобы заказ в пределах 10 км не пропадал из ленты. Flutter `HomeDriverWidget` больше не имеет Firestore stream/document fallback для ленты и карточки заказа.

Flutter `HomeDriverWidget` читает эту ленту через backend API. Старый Firebase stream fallback в backend-режиме не используется.

Flutter `HomeDriverOrderWidget` читает активный заказ через `getOrderDetails` polling-стримом, проверяет назначение водителя через backend, показывает контакты пассажира из backend-данных заказа и меняет статусы через `advanceDriverOrderStatus`. Firestore snapshots/get fallback в этом экране удален.

Flutter `SeachDriverWidget` читает активный заказ пассажира через `getOrderDetails` polling-стримом, показывает водителя из backend-данных заказа и отменяет заказ через backend. Firestore stream fallback для заказа и водителя удален.

Flutter `SeachDriverWidget` читает активный заказ через `getOrderDetails`, берет `driverName`/`driverPhone` из backend JSON и вызывает `cancelPassengerOrder`/`expirePendingOrderIfNeeded` через backend. Cancel API использует backend user path из текущей backend-сессии, не `currentUserReference`.

Flutter `MeOrderWidget` читает историю пассажира/водителя через `listMyOrders(includeClosed: true)`. Старый Firestore fallback в backend-режиме не используется.

Создание заказа из админки идет через `adminCreateOrder`: backend сам находит или создает пассажира по телефону, сохраняет заказ и ставит push-событие водителям. Сохранение заказа из `AdminCollectionWidget` не имеет Firestore fallback.

Flutter `ProfileWidget` сохраняет фото профиля через `updateUserPreferences.photoUrl`. Координаты водителя в `HomeDriverWidget` и `HomeDriverOrderWidget` сохраняются только через `updateUserPreferences.coords`, без Firestore `users.update` fallback.

Flutter `SettingsWidget` сохраняет поселок через `updateUserPreferences.city`. Прямое обновление Firestore `users` из настроек удалено.

Восстановление активного заказа в Flutter при `MTAXI_BACKEND_URL` идет через `getSessionBootstrap`: приложение берет `activePassengerOrderRef` и `activeDriverOrderRef` из backend, без Firestore-поиска.

Backend session возвращает публичного пользователя без поля пароля. Flutter получает только `hasPassword` и строит совместимый `UsersRecord` локально через `backend_user_adapter.dart`.

Экраны входа и SMS ищут существующего пользователя через backend `lookupUserByPhone`. Firestore fallback поиска по номеру в этих экранах удален.

Регистрация пассажира и водителя не пишет черновики в Firestore. Данные сохраняются только после явной отправки анкеты через `submitPassengerRegistration` или `submitDriverRegistration`.

Экраны входа/SMS/выбора роли/регистрации больше не пишут auth-роли, admin-role или `registrationDraft` в Firestore. Роль регистрации держится в локальном app state до финального backend submit.

Удаление текущего аккаунта при `MTAXI_BACKEND_URL` идет через `deleteCurrentAccountDeep`: backend удаляет пользователя и связанные заказы, платежи, ledger, чаты, FCM токены, push-доставки и SMS-коды. Firebase для удаления аккаунта не используется.

Пассажирский чат поддержки читает сообщения через `getSupportChatMessages` polling-стримом, отправляет через `sendSupportChatMessage` и отмечает прочтение через `markSupportChatRead`. Firestore streams/writes для пассажирского чата и профиля поддержки не используются.

Профиль пассажира получает счетчик непрочитанных сообщений и отмечает чат прочитанным через backend support API. Совместимые `DocumentReference` создаются только из backend path, без Firestore network read.

Админские чаты поддержки читают список через `listSupportChats`, а переписку через `getSupportChatMessages`. Создание нового чата из админки выбирает пользователя через `adminListUsers`. Firestore streams/writes и `queryUsersRecordOnce` в админских чатах не используются.

Удаление чатов поддержки администратором делается через backend: `adminDeleteSupportChat` удаляет один чат с сообщениями, `adminClearSupportChats` очищает все чаты поддержки. В Flutter админке при `MTAXI_BACKEND_URL` есть кнопки удаления одного чата и очистки всех чатов. Действия пишутся в `auditLogs`.

Runtime-настройки приложения читаются через `getRuntimeSettings` и сохраняются админом через `updateRuntimeSettings`. Runtime helper и админский раздел `appSettings` не имеют Firestore fallback.

Список поселков и городские тарифы читаются через `listCityTariffs`. Оформление заказа, настройки, пассажирская и водительская регистрация используют backend; Firestore `City` fallback из общего helper удален.

Тарифы межгорода читаются из backend runtime settings; админский список маршрутов и клиентский тариф межгорода не читают Firestore.

Файлы загружаются через `uploadFile` и отдаются по `/uploads/...`. Flutter helper лежит в `lib/backend/uploads/storage.dart`; Firebase Storage SDK и старый клиентский путь `backend/firebase_storage` удалены. Произвольные типы файлов backend отклоняет кодом `UPLOAD_TYPE_NOT_ALLOWED`, а файл с поддельным MIME - `UPLOAD_SIGNATURE_INVALID`.

Главная статистика админки читает `adminListOrders`, `adminListUsers` и `getMoneyStats`. Чаты и счетчик непрочитанных сообщений идут через backend support stream. Firestore карточки и chat-unread fallback в backend-режиме не используются.

Статистика водителя в админке читает список водителей, заказы и комиссию через backend API. Firestore в backend-режиме не используется.

История заказов пользователя в админке читает `adminListOrders` по пассажиру и водителю. Firestore в backend-режиме не используется.

Карточки заказов в админке показывают пассажира и водителя через backend `adminListUsers`; прямое `UsersRecord.getDocumentOnce` для этих подписей удалено.

`AdminCollectionWidget` в runtime-router больше не зависит от `isMTaxiBackendEnabled`: поддержанные разделы открывают backend-экраны, неподдержанные показывают backend-only заглушку.

Создание водителя и быстрые правки водителя в админке идут через `adminCreateDriver`, `adminUpdateDriverCity`, `adminUpdateDriverOrderDelay`, `approveDriver`, `blockDriver`, `unblockDriver`, `adminTopUpDriverBalance`.

Старая общая форма `users` больше не создает пользователей прямой записью в Firestore. Водитель создается через `adminCreateDriver`, пассажир через `adminCreatePassenger`; оба действия пишут audit log.

Политика, "О приложении", тарифные тексты и контакты поддержки в приложении читаются через `getContentDocument`; Firestore fallback для этих экранов удален.

Политика и справочные singleton-разделы админки идут через backend content API без Firestore fallback. Подтверждение удаления фото авто водителя идет через `approveVehiclePhotoDeletion`, `rejectVehiclePhotoDeletion`. Фото профиля пользователя при этом не очищается.

Журнал действий администратора при `MTAXI_BACKEND_URL` читается через `adminListAuditLogs`. Раздел `auditLogs` в Flutter админке использует этот endpoint. Записи создаются backend-операциями и сортируются свежие сверху.

Если клиент вызовет endpoint, которого нет в `server/src/call_router.js`, backend вернет `NOT_IMPLEMENTED`. Рабочие экраны приложения и админки должны использовать только перенесенные backend endpoint-ы, без Firebase data/auth fallback.
