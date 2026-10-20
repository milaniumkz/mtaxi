# MTaxi: перенос на полноценный backend

Цель: полностью вынести приложение на отдельный backend. Firebase оставляем только для push-уведомлений через FCM. Firebase Auth, Firestore, Cloud Functions, SMS и Storage не должны быть частью backend-режима. Пока сервер неизвестен, работаем локально.

Текущая готовность: примерно 99%. Основной backend, PostgreSQL, Docker/VPS-шаблоны, preflight/smoke/monitor/backup, backend-only guard, source archive, handoff package, VPS prerequisite check и production env generator уже готовы; финальный процент зависит от реального VPS, домена, боевого env, миграции данных и production smoke после деплоя.

Главный мелкий пошаговый файл переноса: `docs/backend_migration_small_steps.md`.
Серверный чеклист передачи на VPS: `docs/backend_transfer_steps.md`.

## 1. Подготовка

1. Зафиксировать список текущих серверных точек:
   - авторизация: `passwordLogin`, `lookupUserByPhone`, `requestSmsCode`, `verifySmsCode`, `createSmsSession`, `getSessionBootstrap`;
   - заказы: `createPassengerOrder`, `getOrderQuote`, `acceptOrder`, `advanceDriverOrderStatus`, `cancelPassengerOrder`, `expirePendingOrderIfNeeded`;
   - профиль: `submitPassengerRegistration`, `submitDriverRegistration`, `updateUserPreferences`;
   - админка: `adminUpdateUserDocument`, `adminManageOrder`, `approveDriver`, `blockDriver`, `unblockDriver`;
   - чаты: `ensureSupportChat`, `sendSupportChatMessage`, `markSupportChatRead`;
   - платежи: `createDriverTopUpPayment`, `getDriverTopUpPaymentStatus`, `kassa24*`;
   - пуши: `addFcmToken`, `updateFcmTokenState`, триггеры уведомлений.
2. Разделить функции на домены: `auth`, `users`, `orders`, `admin`, `payments`, `support`, `push`, `settings`.
3. Сделать локальный backend с тем же форматом ответа, что ожидает Flutter: `{ success, ... }`.
4. Добавить переключатель клиента через `--dart-define=MTAXI_BACKEND_URL=http://127.0.0.1:8080`.
5. Постепенно заменить клиентские зависимости от Firebase Auth/Firestore на REST/WebSocket API backend.
6. Не использовать Firebase для данных, авторизации, функций, SMS или загрузки файлов. Firebase допускается только для FCM push.

## 2. Локальный backend

1. Поднять `server/` на Node.js + Express.
2. Добавить healthcheck: `GET /health`. Готово: endpoint возвращает `service`, `time`, `store.type` и `store.ok`; для PostgreSQL health проверяет `DATABASE_URL`/подключение и отдает `503`, если база недоступна. Добавлены production endpoints `GET /livez` для проверки процесса и `GET /readyz` для readiness с проверкой store.
3. Добавить единый callable endpoint: `POST /call/:name`.
4. Добавить совместимость для старого token API: `POST /create-token`. Готово с production-guard: endpoint оставлен только для dev-совместимости, в `NODE_ENV=production` отключен, а `npm run preflight` не пропускает `MTAXI_ENABLE_LEGACY_CREATE_TOKEN=true`.
5. Данные хранить через backend repository layer. Быстрый запуск `npm run dev` использует локальный JSON store, а локальный Docker Compose и production работают через PostgreSQL (`MTAXI_STORE=postgres`).
5. Изолировать доменные модули от конкретного хранилища. Готово: добавлен `server/src/store/index.js`, все backend-домены и тесты импортируют `./store`, а не `./store/json_store`; entrypoint выбирает JSON для быстрого dev-запуска и PostgreSQL при `MTAXI_STORE=postgres`.
5. Подготовить схему полноценной базы. Готово: добавлен `server/db/schema.sql` для PostgreSQL с таблицами users/sms/orders/payments/withdrawals/ledger/support/push/settings/content/generic/audit и индексами под основные запросы; схема пишет версию в `schema_migrations`, чтобы на сервере было видно примененный backend baseline.
5. Подготовить перенос текущих локальных данных в PostgreSQL. Готово: добавлен `server/scripts/migrate_json_to_postgres.js`, dependency `pg`, npm scripts `db:schema` и `db:migrate-json`; скрипт применяет схему и переносит JSON-store в PostgreSQL по основным доменам backend.
5. Сделать миграцию проверяемой. Готово: `db:migrate-json` теперь печатает отчет по количеству исходных и PostgreSQL-записей (`users/orders/payments/...`), перед `COMMIT` падает с `ROLLBACK`, если PostgreSQL содержит меньше записей, и не запускается при обычном `require()`, поэтому миграционную логику можно безопасно тестировать и использовать в tooling.
5. Добавить явный переключатель хранилища. Готово: `server/src/store/index.js` выбирает JSON по умолчанию и PostgreSQL при `MTAXI_STORE=postgres`; `postgres_store.js` защищает старый sync-контракт явной ошибкой, но поддерживает `withPgClient` и `withPgTransaction` для async repository операций.
5. Добавить async store-контракт. Готово: JSON-store поддерживает `readStoreAsync`, `writeStoreAsync`, `withStoreAsync`; PostgreSQL-store уже реализует эти методы для пользователей, SMS-кодов, заказов, платежей, выводов, ledger, чатов поддержки, push-данных, настроек, справочного контента, тарифов поселков, маршрутов межгорода, generic-коллекций и audit log через `users`, `sms_codes`, `orders`, `payments`, `withdrawals`, `ledger`, `support_chats`, `support_messages`, `fcm_tokens`, `notifications`, `notification_deliveries`, `push_delivery_acks`, `app_settings`, `content_documents`, `city_prices`, `intercity_routes`, `generic_documents`, `audit_logs`.
5. Начать перевод доменов на async store-контракт. Готово: `settings.js` получил `getRuntimeSettingsAsync` и `updateRuntimeSettingsAsync`, а `call_router` для runtime settings вызывает async-версии через `readStoreAsync/withStoreAsync`.
5. Продолжить перевод доменов на async store-контракт. Готово: справочный content API получил `getContentDocumentAsync`, `adminUpdateContentDocumentAsync`, `adminSavePolitikaAsync`; `call_router` вызывает async-версии через `readStoreAsync/withStoreAsync`.
5. Продолжить перевод доменов на async store-контракт. Готово: тарифы поселков получили `listCityTariffsAsync`, `adminListCityTariffsAsync`, `adminUpsertCityTariffAsync`; `call_router` вызывает async-версии через `readStoreAsync/withStoreAsync`.
5. Продолжить перевод доменов на async store-контракт. Готово: маршруты межгорода получили `listIntercityRoutesAsync`, `adminListIntercityRoutesAsync`, `adminUpsertIntercityRouteAsync`; `call_router` вызывает async-версии через `readStoreAsync/withStoreAsync`.
5. Продолжить перевод доменов на async store-контракт. Готово: generic-коллекции админки получили `adminListGenericCollectionAsync`, `adminUpsertGenericDocumentAsync`, `adminDeleteGenericDocumentAsync`; `call_router` вызывает async-версии через `readStoreAsync/withStoreAsync`.
5. Продолжить перевод доменов на async store-контракт. Готово: auth/user-session/order операции уже используют `readStoreAsync/withStoreAsync`, а PostgreSQL-store теперь читает и сохраняет `users`, `sms_codes` и `orders`.
5. Продолжить перевод доменов на async store-контракт. Готово: bootstrap сессии получил `getSessionBootstrapAsync`; `call_router` вызывает async-версию через `withStoreAsync`, а старый sync API оставлен только для совместимости.
5. Продолжить перевод доменов на async store-контракт. Готово: backend-авторизация (`passwordLogin`, `lookupUserByPhone`, `createSmsSession`, `requestSmsCode`, `verifyBearerToken`) переведена на `readStoreAsync/withStoreAsync`; sync-поиск пользователя оставлен как совместимый helper.
5. Продолжить перевод доменов на async store-контракт. Готово: пользовательские операции регистрации, настроек профиля, установки пароля и глубокого удаления аккаунта получили async-версии; `call_router` использует async API через `withStoreAsync`.
5. Продолжить перевод доменов заказов на async store-контракт. Готово: read-only операции заказов (`getOrderQuoteAsync`, `getOrderDetailsAsync`, `listAvailableDriverOrdersAsync`, `listMyOrdersAsync`, `adminListOrdersAsync`) подключены в `call_router` через `readStoreAsync/withStoreAsync`.
5. Продолжить перевод доменов заказов на async store-контракт. Готово: write-операции заказов (`createPassengerOrderAsync`, `adminCreateOrderAsync`, `expirePendingOrderIfNeededAsync`, `acceptOrderAsync`, `cancelPassengerOrderAsync`, `advanceDriverOrderStatusAsync`) подключены в `call_router`; жизненный цикл заказа, баланс, активные ссылки и push-очередь сохраняются через `withStoreAsync`.
5. Продолжить перевод денежных доменов на async store-контракт. Готово: пополнения, статусы/подтверждение/ошибка платежей, заявки на вывод, админские списки платежей/выводов и денежная статистика получили async-версии и подключены в `call_router` через `withStoreAsync`; PostgreSQL-store читает и сохраняет `payments`, `withdrawals`, `ledger`.
5. Продолжить перевод чатов поддержки на async store-контракт. Готово: support API уже подключен в `call_router` через async-версии, а PostgreSQL-store читает и сохраняет `support_chats` и `support_messages`.
5. Продолжить перевод чатов поддержки на async store-контракт. Готово: создание/получение чата, отправка/чтение сообщений, отметка прочтения, админские списки и удаление чатов получили async-версии и подключены в `call_router` через `withStoreAsync`.
5. Продолжить перевод push-домена на async store-контракт. Готово: FCM-токены, очередь уведомлений, broadcast, история уведомлений, flush очереди и ack доставки получили async-версии; `call_router` использует async API, PostgreSQL-store читает и сохраняет `fcm_tokens`, `notifications`, `notification_deliveries`, `push_delivery_acks`, Firebase остается только транспортом отправки.
5. Продолжить перевод админских операций на async store-контракт. Готово: `adminListUsersAsync`, `adminListAuditLogsAsync`, `adminUpdateUserDocumentAsync`, `adminCreateDriverAsync`, `adminCreatePassengerAsync`, `approveVehiclePhotoDeletionAsync`, `rejectVehiclePhotoDeletionAsync`, `approveDriverAsync`, `adminUpdateDriverCityAsync`, `adminUpdateDriverOrderDelayAsync`, `blockDriverAsync`, `unblockDriverAsync`, `adminTopUpDriverBalanceAsync` и `adminManageOrderAsync` подключены в `call_router` через `withStoreAsync`.
5. Продолжить перевод сервисных операций на async store-контракт. Готово: `runMaintenanceTasksAsync` подключен в `call_router`, использует async-истечение заказов и async-flush push-очереди.
5. Перевести файловую загрузку на async backend API. Готово: `uploadFileAsync` пишет файлы через `fs.promises`, `call_router` вызывает async-версию, Firebase Storage не используется; upload ограничен разрешенными MIME-типами JPEG/PNG/HEIC/HEIF/WebP/PDF/MP4, проверяет сигнатуру файла и отдает `/uploads` с controlled cache/security headers.
5. Подготовить upload URL для reverse proxy. Готово: `publicBaseUrl()` использует `MTAXI_PUBLIC_BASE_URL` либо первые значения `x-forwarded-proto/x-forwarded-host`, чтобы ссылки на `/uploads` были публичными и не ломались за proxy.
5. Убрать sync-store зависимость из backend auth runtime. Готово: `auth.js` больше не импортирует `readStore`; поиск пользователя идет через `readStoreAsync`, а старые sync helper exports удалены.
5. Защитить backend auth от битых Bearer-токенов. Готово: некорректный access token возвращает `UNAUTHENTICATED`, а не 500; это закреплено backend-тестом.
5. Убрать sync-store зависимость из runtime settings. Готово: `settings.js` экспортирует только `getRuntimeSettingsAsync` и `updateRuntimeSettingsAsync`, общий update-helper не использует sync `withStore`.
5. Убрать sync-store зависимость из session bootstrap. Готово: `session.js` экспортирует только `getSessionBootstrapAsync`; sync `withStore` из runtime session удален.
5. Убрать sync-store зависимость из user runtime. Готово: `users.js` экспортирует только async операции регистрации, настроек, пароля и удаления аккаунта; sync `withStore` wrappers удалены.
5. Убрать sync-store зависимость из support runtime. Готово: `support.js` экспортирует только async операции чатов поддержки; sync `withStore` wrappers удалены.
5. Убрать sync-store зависимость из payments runtime. Готово: `payments.js` экспортирует только async операции платежей, выводов и статистики денег; sync `withStore` wrappers удалены.
5. Убрать sync-store зависимость из push runtime. Готово: `push.js` экспортирует только async операции FCM-токенов, broadcast, очереди, flush и ack; sync `readStore/writeStore/withStore` wrappers удалены.
5. Убрать sync-store зависимость из orders runtime. Готово: `orders.js` экспортирует только async runtime операции заказов; sync `readStore/withStore` wrappers удалены, внутренние `InStore` helper-ы оставлены для транзакционной логики и тестов.
5. Убрать sync-store зависимость из admin runtime. Готово: `admin.js` экспортирует только async админские операции пользователей, заказов, тарифов, межгорода, content и generic-коллекций; sync `readStore/withStore` wrappers удалены.
5. Защитить PostgreSQL-переход от возврата sync-store. Готово: добавлен тест `runtime backend modules do not import the old sync store contract`, который падает, если runtime-модуль вне `store/*` снова импортирует или использует `readStore/writeStore/withStore`.
5. Подготовить production env-шаблон для арендного сервера. Готово: добавлен `server/.env.example` с переменными HTTP, public base URL, CORS, JWT secret, PostgreSQL, uploads, geocoding, payment callback и FCM.
5. Добавить production preflight перед запуском на сервере. Готово: `npm run preflight` проверяет обязательные env, PostgreSQL-подключение и запись в upload-папку.
5. Добавить базовую HTTP hardening-настройку. Готово: Express отключает `x-powered-by`, добавляет `X-Content-Type-Options`, `Referrer-Policy`, `X-Frame-Options`, а `MTAXI_TRUST_PROXY` готовит backend к работе за reverse proxy.
5. Добавить эксплуатационные HTTP request id и access logs. Готово: каждый ответ получает `X-Request-Id`, входящий `x-request-id` переиспользуется после валидации, access logs включаются через `MTAXI_ACCESS_LOGS` и не пишут тело запроса.
5. Подготовить Docker-запуск полноценного backend. Готово: добавлены `server/Dockerfile`, `server/.dockerignore` и `docker-compose.backend.yml`; compose поднимает PostgreSQL, применяет `server/db/schema.sql`, запускает backend с `MTAXI_STORE=postgres`, upload-volume и `npm run preflight` перед стартом.
5. Сделать применение PostgreSQL-схемы устойчивым при существующем volume. Готово: добавлен `npm run db:apply-schema` на Node/`pg`; Docker выполняет его перед `preflight`, поэтому новые таблицы/индексы подтягиваются без пересоздания базы. Скрипт после применения проверяет наличие baseline-версии в `schema_migrations`.
5. Защитить PostgreSQL store-write операции от гонок. Готово: `withPgTransaction` берет `pg_advisory_xact_lock(hashtext('mtaxi_store_write'))`, поэтому операции принятия заказа, баланса, платежей, refund и админских правок через общий store snapshot выполняются последовательно до перехода на точечные SQL repository-методы.
5. Подготовить graceful shutdown для контейнера. Готово: `server/src/index.js` экспортирует lifecycle, а production entrypoint на `SIGTERM`/`SIGINT` останавливает maintenance-worker и закрывает HTTP server.
5. Подготовить bootstrap первого администратора. Готово: добавлен `npm run seed:admin`, который по `MTAXI_ADMIN_PHONE/MTAXI_ADMIN_PASSWORD/MTAXI_ADMIN_NAME/MTAXI_ADMIN_CITY` создает или обновляет admin-пользователя через backend store, сохраняет пароль как `scrypt` hash и работает на JSON/PostgreSQL.
5. Подключить bootstrap первого администратора к Docker. Готово: `MTAXI_SEED_ADMIN_ON_START=true` запускает `npm run seed:admin` перед стартом backend, а `npm run preflight` проверяет admin env и формат телефона только когда auto seed включен.
5. Добавить штатный backup/restore для арендного сервера. Готово: `npm run db:backup` создает PostgreSQL custom dump, архив upload-папки и переносимый manifest с относительными именами файлов; `npm run db:restore -- manifest.json` восстанавливает базу через `pg_restore`, очищает текущую `MTAXI_UPLOAD_DIR` и распаковывает uploads прямо в нее только при `MTAXI_RESTORE_CONFIRM=YES`.
5. Подготовить чеклист переноса на арендный сервер. Готово: `docs/backend_deployment_checklist.md` описывает env, Docker/PostgreSQL запуск, миграцию JSON, HTTPS proxy, Flutter release, smoke test, backup и rollback.
6. Первый перенос без Firebase:
   - backend password/session auth;
   - `getSessionBootstrap`;
   - `getOrderQuote`;
   - `createPassengerOrder`;
   - `acceptOrder`;
   - `cancelPassengerOrder`;
   - `advanceDriverOrderStatus`;
   - `expirePendingOrderIfNeeded`.
7. Геокодинг адресов вести через backend. Готово в локальном backend: `forwardGeocodeLookup`, `reverseGeocodeLookup`, `placesAutocomplete`, `placeDetails`, `suggestAddressesLookup`; Flutter custom actions и web-карта при `MTAXI_BACKEND_URL` получают координаты, reverse geocode и подсказки через backend.
8. Поиск адресов и детали Places вести через backend. Готово в локальном backend: `placesAutocomplete`, `placeDetails`, `suggestAddressesLookup`; `GooglePlacesAutocomplete`, `GetStritCall`, `GetCityCall`, `CoordsCall`, `SearchStreetCall` и web-подсказки адресов больше не требуют клиентские Google/Mapbox ключи.
9. Клиент не содержит Google Places SDK и API-key параметры для подсказок адресов: `FlutterFlowPlacePicker` удален, `editkuda` использует backend actions `getAddressSuggestions/getCoordinatesFromAddress`.
9. Убрать старые прямые Cloud Functions/Cloud Run вызовы из `api_calls.dart`. Готово: `CityCall`, `AdresCall`, `CreatePaymentCall`, `VivodCall`, `SearchStreetCall`, `CoordsCall`, `GetCityCall`, `GetStritCall` не содержат прямых URL/Cloud Functions fallback и всегда идут через backend endpoints.
10. Перенести вывод средств водителя на backend. Готово в локальном backend: `createDriverWithdrawal`, `adminListWithdrawals`, `adminResolveWithdrawal`; `VivodCall` вызывает backend, админ может подтвердить/отклонить заявку, баланс и `ledger` обновляются сервером.
11. Показать выводы в финансовой статистике админки. Готово: `AdminMoneyStatsWidget` в backend-режиме читает `withdrawals`, `pendingWithdrawals` и операции вывода из `getMoneyStats`, показывает карточки подтвержденных и ожидающих выводов.
12. Добавить управление заявками на вывод в админке. Готово: backend-коллекция `withdrawals` в `AdminCollectionWidget` показывает заявки через `adminListWithdrawals`, позволяет подтвердить или отклонить pending-заявку через `adminResolveWithdrawal`, из финансовой статистики добавлен быстрый переход.
13. Добавить заявки на вывод на главную админки. Готово: `AdminHomeWidget` показывает раздел `withdrawals` в списке коллекций и backend-карточку выводов с суммой ожидающих и уже выплаченных заявок из `getMoneyStats`.
14. Расширить полное удаление аккаунта под новые backend-данные. Готово: `deleteCurrentAccountDeep` удаляет `withdrawals` пользователя вместе с users/orders/payments/ledger/chats/push/SMS; тест проверяет удаление заявки на вывод.
   - `listAvailableDriverOrders`;
   - `getOrderDetails`;
   - `listMyOrders`;
   - `adminListOrders`.

## 3. Подключение приложения

1. В `makeCloudCall()` вызывать только backend REST `POST /call/:name`. Готово: Firebase Functions SDK из клиента удален, wrapper перенесен в `lib/backend/backend_calls/backend_calls.dart`, старый путь `backend/cloud_functions` удален.
2. Если URL пустой, использовать локальный backend `http://localhost:8080`, не Firebase Functions.
3. Если URL задан, отправлять `POST /call/:name`.
4. Передавать backend access token в `Authorization: Bearer ...`.
5. Временный режим совместимости заменен backend-only режимом. Финальный клиент не требует Firebase Auth/Firestore.
6. Firebase в целевой архитектуре используется только для FCM push-уведомлений. Auth, база, файлы, платежи, заказы, настройки, чаты и админка должны работать через backend.
6. Защитить production-сборку от локального или insecure backend URL. Готово: добавлен `MTAXI_REQUIRE_REMOTE_BACKEND=true`; при этом флаге Flutter-клиент принимает только внешний `https://` backend и запрещает `localhost`, `127.0.0.1`, `10.0.2.2` и локальные LAN-адреса в `MTAXI_BACKEND_URL`.
6. Инициализация Firebase на клиенте не должна настраивать Firestore. Готово: `firebase_config.dart` оставляет только `Firebase.initializeApp()` для FCM/Firebase Core, Firestore persistence settings удалены.
6. Backend-режим теперь принудительный: `isMTaxiBackendEnabled` всегда `true`; старые сетевые Firebase SDK удалены, оставшиеся compatibility-типы не открывают Firebase-сеть.
7. Убрать Flutter-зависимость `cloud_functions`. Готово: `pubspec.yaml`, `pubspec.lock`, Android/iOS registrant больше не подключают Firebase Functions.
8. Убрать Flutter-зависимости `firebase_storage`, `firebase_crashlytics`, `firebase_performance`, `cloud_firestore`. Готово: загрузка файлов идет через backend `uploadFile`, Crashlytics/Performance отключены, Firestore SDK удален из `pubspec.yaml`/`pubspec.lock`; для старых FlutterFlow-моделей используется локальный `backend_refs_compat.dart` без сетевого Firebase runtime.
8. Очистить iOS/Flutter generated зависимости от старых Firebase SDK. Готово: из `ios/Podfile` удалены ручные старые Firebase SDK hooks, выполнены `flutter pub get` и `pod install`; в `.flutter-plugins-dependencies`, `ios/Podfile.lock` и Android/iOS registrant остались только `firebase_core` и `firebase_messaging` для FCM. `ios/Pods` не хранится как исходник и пересобирается при iOS-сборке.
9. Убрать Firebase Auth из главного runtime-потока приложения. Готово: `main.dart` использует только `mtaxiBackendUserStream`, `signInWithJwtToken` сохраняет backend access token и делает `getSessionBootstrap`, `signOut` в backend-режиме не вызывает `FirebaseAuth.signOut`.
10. Перевести `BackendAuthManager` в backend-only режим. Готово: файл перенесен в `auth/backend_auth`, не импортирует `firebase_auth` и не вызывает `FirebaseAuth.instance`; SMS/JWT вход работает через backend token/session.
10. Закрепить backend-only auth guard-ом. Готово: `test/backend_only_guard_test.dart` проверяет, что auth manager не возвращает `firebase_auth`, `verifyPhoneNumber`, `PhoneAuthProvider`, `signInWithCredential`, а вход/пароль/удаление остаются через backend API.
11. Удалить Firebase Auth SDK из клиента. Готово: `firebase_auth` удален из `pubspec.yaml`, `pubspec.lock`, Android/iOS registrant; старые provider-файлы удалены, `auth_util.dart` больше не использует Firebase Auth user stream.
12. Защитить клиент от возврата старых Firebase data/auth SDK. Готово: `test/backend_only_guard_test.dart` проверяет, что в `pubspec.yaml` остались только `firebase_core`/`firebase_messaging` для FCM, а `lib/` не импортирует прямые пакеты `cloud_firestore`, `cloud_functions`, `firebase_auth`, `firebase_storage`, `firebase_crashlytics`, `firebase_performance` или `firebase_database`.
13. Оставить Firebase только для push и в native config. Готово: из `android/app/google-services.json` и `ios/Runner/GoogleService-Info.plist` убраны Storage/Auth/AppInvite-настройки, guard проверяет, что остаются только Core/FCM-поля.
12. Убрать старые Firebase/Firestore имена из совместимого FlutterFlow-слоя. Готово: `FirestoreRecord`, `FFFirestorePage`, `FFFirebaseStruct`, `FirestoreUtilData`, `mapFromFirestore`, `mapToFirestore` и старый `firestore_util.dart` заменены backend-compat именами; guard-тест запрещает вернуть эти маркеры в `lib/`.
12. Зафиксировать backend-only runtime-флаги. Готово: guard-тест проверяет, что клиент всегда работает через MTaxi backend (`isMTaxiBackendEnabled => true`), а общий экран админских коллекций не может включить прямой Firebase fallback (`_useBackendOnlyCollections => true`).
13. Защитить generated/mobile зависимости от возврата старых Firebase SDK. Готово: guard-тест проверяет `pubspec.lock`, `.flutter-plugins-dependencies`, Android/iOS registrant и `ios/Podfile.lock`; разрешены только `firebase_core` и `firebase_messaging` для FCM.
14. Убрать legacy Firebase deploy/runtime артефакты из исходников. Готово: удалены старые `firebase/`, `public/`, `public_user/`, `ios/build` и старые `ios/Pods` с Auth/Firestore/Functions/Storage; добавлен `.gitignore` и guard-тест, который не даст вернуть Firebase Hosting/Functions/Firestore/Storage в backend-only проект.
15. Защитить старые generated API wrappers от прямых внешних вызовов. Готово: `SmsCall`/`TokenCall` оставлены только как локальные заглушки совместимости, платежи и геокодинг идут через `mtaxiBackendCall`, auth-экраны больше не имеют fallback на старые SMS/token вызовы, а guard-тест по всему `lib/` запрещает возврат старых Cloud Functions/Cloud Run/Wappi/Pult24 endpoints в клиент.
6. Runtime-настройки приложения должны читаться и сохраняться через backend. Готово: `getRuntimeSettings`, `updateRuntimeSettings`, Flutter `app_settings.dart` и админский `appSettings` используют backend; Firestore `appSettings` fallback из runtime helper и `AdminCollectionWidget` удален.
7. Тарифы и список поселков должны идти через backend. Готово: `listCityTariffs`, `adminListCityTariffs`, `adminUpsertCityTariff`; админский раздел `City`, оформление заказа, настройки, пассажирская и водительская регистрация не читают Firestore для списка поселков.
8. Централизовать клиентское чтение поселков/тарифов. Готово: `app_city_tariffs.dart`; HomePage, Settings, SetProfile и SetProfileDriver используют общий helper, Firestore `City` fallback из helper удален.
9. Маршруты межгорода должны читаться и редактироваться через backend. Готово: `listIntercityRoutes`, `adminListIntercityRoutes`, `adminUpsertIntercityRoute`, админский раздел маршрутов и пассажирский виджет карты больше не читают Firestore. Старый Firestore stream fallback для админского раздела межгорода удален, `_buildIntercityRoutesBody` всегда использует backend `adminListIntercityRoutes`.
9. Тариф км/минимальная цена межгорода должны браться из backend runtime settings. Готово: экран `cityToCity` больше не читает Firestore `intercityTariff`.
9. Справочный контент должен читаться и сохраняться через backend. Готово: `getContentDocument`, `adminUpdateContentDocument`; политика, экран "О приложении", тарифные тексты и контакты поддержки читаются только через backend, без Firestore fallback.
10. Денежная статистика админки считается через backend. Готово: `AdminMoneyStatsWidget` использует `getMoneyStats`; Firestore fallback не используется.
11. Главная админки работает через backend. Готово: карточки сводки берутся через `adminListOrders`, `adminListUsers`, `getMoneyStats`; блок проверки водителей берет анкеты через `adminListUsers` и approve/reject через `approveDriver`. Firestore fallback не используется.
10. Загрузка файлов должна идти через backend. Готово: `uploadFile`, локальная раздача `/uploads/...`; Flutter `uploadData()` использует `lib/backend/uploads/storage.dart`, Firebase Storage SDK и старый путь `backend/firebase_storage` из клиента удалены. Backend отклоняет произвольные MIME-типы через `UPLOAD_TYPE_NOT_ALLOWED` и поддельные сигнатуры через `UPLOAD_SIGNATURE_INVALID`.
11. Главная статистика админки должна считаться через backend. Готово: `AdminHomeWidget` использует `adminListOrders`, `adminListUsers`, `getMoneyStats`; Firestore fallback для карточек удаляется из runtime-пути.
12. Статистика водителя в админке считается через backend. Готово: `AdminDriverStatsWidget` использует `adminListUsers`, `adminListOrders`, `getRuntimeSettings`; Firestore fallback не используется.
13. История заказов пользователя в админке читается через backend. Готово: модальное окно заказов в `AdminCollectionWidget` для пользователей использует `adminListOrders` по пассажиру и водителю; Firestore fallback не используется.
14. Быстрое создание и правки водителя в админке при `MTAXI_BACKEND_URL` должны идти через backend. Готово: `adminCreateDriver`, `adminUpdateDriverCity`, `adminUpdateDriverOrderDelay`; Flutter `AdminCollectionWidget` уже вызывает эти endpoint-ы.

## 4. Перенос заказов

1. Перенести расчет стоимости `getOrderQuote`. Готово в локальном backend.
2. Перенести создание заказа `createPassengerOrder`. Готово в локальном backend.
3. Перенести атомарное взятие заказа `acceptOrder`. Готово в локальном backend.
4. Перенести смену статусов `advanceDriverOrderStatus`. Готово в локальном backend.
5. Перенести отмену пассажиром `cancelPassengerOrder`. Готово в локальном backend.
6. Перенести истечение заказа `expirePendingOrderIfNeeded`. Готово в локальном backend.
7. Для каждой операции добавить транзакции и защиту от двойного взятия заказа. Готово: операции идут через `withStoreAsync`; в JSON-store запись последовательная на уровне файла, в PostgreSQL-store используется DB-транзакция с `pg_advisory_xact_lock`, поэтому двойное взятие и повторные денежные операции сериализуются на backend.
8. Серверное правило баланса водителя: для взятия заказа нужен баланс не меньше комиссии заказа. Сейчас комиссия зашита на backend как `settings.orderCommissionPercent`, по умолчанию `10`.
9. `getSessionBootstrap` возвращает активные заказы пассажира/водителя и чистит устаревшие ссылки, если заказ уже закрыт.
10. Добавить backend чтение заказов вместо Firestore streams. Готово локально: `listAvailableDriverOrders`, `getOrderDetails`, `listMyOrders`, `adminListOrders`.
11. Лента водителя должна работать в радиусе 10 км независимо от выбранного поселка. Готово в backend API: при координатах фильтр идет по радиусу, не по поселку.
12. Подключить Flutter-ленту водителя к backend API. Готово: `HomeDriverWidget` читает `listAvailableDriverOrders`, проверяет исчезнувшие заказы через `getOrderDetails`, открывает карточку и контакты из backend-данных заказа; Firestore stream/document fallback удален.
13. Подключить экран активного заказа водителя к backend API. Готово: `HomeDriverOrderWidget` читает `getOrderDetails` polling-стримом; проверка назначения водителя, закрытие по последнему серверному состоянию и контакты пассажира идут через backend, без Firestore snapshots/get fallback.
14. Подключить пассажирский экран активного заказа к backend API. Готово: `SeachDriverWidget` читает `getOrderDetails` polling-стримом, контакты водителя берет из backend JSON, отмену/истечение отправляет через backend, не использует `currentUserReference` для cancel API и не имеет Firestore stream fallback для заказа/водителя.
15. Подключить историю заказов пользователя к backend API. Готово: `MeOrderWidget` читает `listMyOrders(includeClosed: true)`, Firebase query не используется.
16. Подключить создание заказа из админки к backend API. Готово: `adminCreateOrder` создает заказ, находит или создает пассажира по телефону, ставит push-событие водителям; форма `AdminCollectionWidget` для новых заказов не пишет напрямую в Firestore и больше не имеет Firestore fallback при сохранении заказа.
15. Подключить восстановление активных заказов к backend session bootstrap. Готово: `recoverActivePassengerOrderRefFromServer` и `recoverActiveDriverOrderRefFromServer` при `MTAXI_BACKEND_URL` используют `getSessionBootstrap` и не валидируют заказ через Firestore.
16. Убрать Firestore-дочитку пассажира/водителя из водительских экранов. Готово: `HomeDriverWidget` и `HomeDriverOrderWidget` используют данные заказа (`customerName`, `customerPhone`) и `getSessionBootstrap`; `UsersRecord.getDocument`, `OrderRecord.getDocument`, Firestore snapshots/get fallback удалены.

## 5. Перенос профиля и ролей

1. Перенести регистрацию пассажира. Готово в локальном backend: `submitPassengerRegistration`.
2. Перенести регистрацию водителя. Готово в локальном backend: `submitDriverRegistration`.
3. Перенести настройку поселка, звука, темы. Готово в локальном backend: `updateUserPreferences`.
4. Перенести фото профиля пассажира. Готово в локальном backend: `updateUserPreferences.photoUrl`; Flutter `ProfileWidget` пишет туда при `MTAXI_BACKEND_URL`.
5. Перенести координаты водителя. Готово в локальном backend: `updateUserPreferences.coords`; Flutter `HomeDriverWidget` и `HomeDriverOrderWidget` пишут координаты через backend, без Firestore `users.update` fallback.
6. Перенести backend user JSON в совместимый `UsersRecord` без чтения Firestore. Готово: `backend_user_adapter.dart` используется в backend auth stream и session bootstrap.
7. Перенести сохранение поселка из настроек. Готово: `SettingsWidget` сохраняет поселок только через backend `updateUserPreferences.city`; прямой Firestore `users.update/get` fallback удален.
8. Убрать запись черновиков регистрации в Firestore. Готово: `SetRoleWidget`, `SetProfileWidget` и `SetProfileDriverWidget` больше не пишут draft-документы в Firestore; выбранная роль держится локально до финальной анкеты, реальные данные уходят только через `submitPassengerRegistration` и `submitDriverRegistration`.
9. Перенести role-state machine из `firebase/functions/domain`. Готово в локальном backend: роли нормализуются на сервере, `DRIVER_PENDING_REVIEW` от старых записей отдается клиенту как `DRIVER_PENDING`, переключение пассажир/водитель идет через `updateUserPreferences`, а Flutter-роутер понимает тот же набор состояний.
10. Проверить сценарии: пассажир, водитель на проверке, одобренный водитель, заблокированный пользователь. Готово: `getSessionBootstrap` и `passwordLogin` отдают явные состояния `PASSENGER`, `DRIVER_PENDING`, `DRIVER_ONLINE`, `BLOCKED`; общий `call_router` блокирует рабочие операции заблокированного аккаунта с `USER_BLOCKED`, но оставляет bootstrap для корректного экрана блокировки.
11. Перенести установку пароля. Готово в локальном backend: `setPassword`.
11. Перенести удаление аккаунта. Готово в локальном backend: `deleteCurrentAccountDeep` удаляет пользователя и связанные заказы, платежи, ledger, чаты, FCM токены, push-доставки и SMS-коды.
12. Перенести поиск пользователя по телефону при входе/SMS. Готово: `lookupUserByPhone`; `LoginWidget` и `SmsVireficationWidget` читают пользователя только через backend, Firestore fallback поиска по телефону удален.
13. Запретить auth fallback к Firestore при включенном backend URL. Готово: `resolveAuthenticatedUserReference` не делает Firestore lookup после ошибки backend bootstrap; `BackendAuthManager` не вызывает `maybeCreateUser` в backend-режиме.
13. Перенести текущую auth-сессию клиента. Готово: `authenticatedUserStream`, `mtaxiBackendUserStream` и `resolveSignedInUserRecord` берут пользователя из backend access token + `getSessionBootstrap`, без Firebase Auth/Firestore.
14. Перенести создание сессии после SMS. Готово: `createSmsSession` создает/находит пользователя по телефону и выдает backend token только после verified SMS-кода; использованный код помечается как `consumed`. `SmsVireficationWidget` при `MTAXI_BACKEND_URL` после правильного кода больше не входит через Firebase custom token.
15. Развести вход по паролю и регистрацию. Готово: `LoginWidget` при `MTAXI_BACKEND_URL` просит пароль только у уже зарегистрированного пользователя с заданным паролем; новые пользователи и пользователи без пароля идут через SMS в backend-сессию.
15. Хранить новые пароли безопасно на backend. Готово: добавлен `passwords.js` с `scrypt` hash/verify; регистрация, `setPassword`, `adminCreateDriver` сохраняют hash, `publicUser` не отдает `passwordHash`, старые plaintext-пароли автоматически обновляются до hash после успешного `passwordLogin`.
15. Зафиксировать production-secret для auth. Готово: JWT и SMS hash используют текущий `MTAXI_TOKEN_SECRET`, тест проверяет, что смена секрета меняет SMS hash и инвалидирует старые access-token.
15. Добавить rate limit на публичные auth endpoint-ы. Готово: `passwordLogin`, `requestSmsCode`, `verifySmsCode`, `createSmsSession` ограничиваются по IP и телефону через `MTAXI_AUTH_RATE_LIMIT_WINDOW_SEC`/`MTAXI_AUTH_RATE_LIMIT_MAX`; `preflight` проверяет эти env до запуска.
16. Отключить Firebase Auth listeners в backend-режиме. Готово: `jwtTokenStream`, проверка отсутствующего user document и стартовая обработка пользователя не обращаются к Firebase Auth.
17. Перенести отправку SMS-кода на backend. Готово: `requestSmsCode` отправляет код через backend SMS-provider; локально доступен `local`, для production preflight требует реальный `http` provider и проверяет URL, method, headers и body template. `LoginWidget` и повторная отправка в `SmsVireficationWidget` при `MTAXI_BACKEND_URL` больше не вызывают прямой клиентский Wappi API. Firebase для SMS/Auth не используется.
17. Перенести проверку SMS-кода на backend. Готово: добавлен `verifySmsCode`, SMS-экран в backend-режиме отправляет введенный код на сервер, backend помечает код как `verified`; добавлен TTL и cooldown повторной отправки. Проверка кода использует сохраненный backend store/PostgreSQL, поэтому переживает рестарт процесса. Новые SMS-коды в базе хранятся как `smsCodeHash`, старые plaintext-записи читаются только для совместимости миграции.
18. Убрать клиентские секреты и старые auth/SMS endpoints. Готово: `SmsCall` и `TokenCall` больше не содержат Wappi token, Wappi URL и старый Cloud Run `getcustomtoken` URL; SMS и auth-токены должны идти через локальный backend.

## 6. Админка

1. Перенести операции пользователя. Готово в локальном backend: `adminUpdateUserDocument`, `approveDriver`, `blockDriver`, `unblockDriver`, `adminTopUpDriverBalance`.
1. Перенести legacy callable админки. Готово в локальном backend: `adminSavePolitika`, `approveVehiclePhotoDeletion`, `rejectVehiclePhotoDeletion`.
2. Перенести управление заказами. Готово в локальном backend: `adminManageOrder`.
3. Добавить audit log для каждого действия администратора. Готово в backend store/PostgreSQL: `auditLogs` пишутся админскими действиями и deep-delete.
3. Добавить чтение audit log через backend. Готово: `adminListAuditLogs`, фильтр по действию/цели/поиску, свежие записи сверху; Flutter админка открывает раздел `auditLogs` через backend.
3. Закрыть админские backend-вызовы от неавторизованного доступа. Готово: router-level тест проверяет ключевые admin/payment/support/push/maintenance endpoint-ы через `/call/:name`; без admin token они возвращают отказ и не выполняют действие.
4. Добавить ручные кнопки статусов заказа. Готово: backend и админка поддерживают `complete`, `cancel`, `reopen`, `setStatus`; `AdminCollectionWidget` меняет статус через `adminManageOrder`, без прямой записи в Firebase.
5. Перенести список пользователей для админских действий. Готово в локальном backend: `adminListUsers`.
6. Перенести runtime-настройки. Готово в локальном backend: `getRuntimeSettings`, `updateRuntimeSettings`.
7. Перенести тарифы и список населенных пунктов. Готово в локальном backend: `listCityTariffs`, `adminListCityTariffs`, `adminUpsertCityTariff`; расчет цены заказа и выбор поселка в приложении используют тот же источник.
8. Перенести маршруты межгорода. Готово в локальном backend: `listIntercityRoutes`, `adminListIntercityRoutes`, `adminUpsertIntercityRoute`; приложение читает маршруты через backend. В админке маршруты межгорода больше не имеют старой Firestore stream-ветки.
9. Убрать Firestore `intercityTariff` из backend-режима. Готово: `city_to_city_widget.dart` использует `getAppRuntimeSettings`.
10. Перенести статистику денег админки. Готово: backend `getMoneyStats` возвращает ledger, платежи и балансы водителей; Flutter админка использует этот endpoint при `MTAXI_BACKEND_URL`.
11. Перенести dashboard главной админки. Готово: карточки статистики и блок проверки водителей используют backend API при `MTAXI_BACKEND_URL`.
12. Перенести список платежей в админской коллекции. Готово: `adminListPayments`; экран `payments` в backend-режиме не читает Firestore и показывает свежие платежи сверху.
13. Перенести списки `users` и `order` в общем экране коллекций админки. Готово: экран использует `adminListUsers` и `adminListOrders`; Firestore fallback не используется.
14. Запретить общий Firestore fallback в админке при backend-режиме. Готово: для не перенесенных коллекций `AdminCollectionWidget` показывает сообщение "раздел не подключен", не открывает Firestore stream и не дает добавлять документы напрямую в Firebase.
15. Перенести старые редкие коллекции админки на backend. Готово: `adminListGenericCollection`, `adminUpsertGenericDocument`, `adminDeleteGenericDocument` хранят `cityToCity`, `CityToCityDriver`, `gruz`, `GruzDriver`, `bid` в backend `genericCollections`; `AdminCollectionWidget` умеет показывать, добавлять, редактировать и удалять эти разделы без Firestore.
9. Перенести справочные singleton-документы. Готово в локальном backend: `politika`, `about`, `supportContacts`, `tariffsContent`; админский экран этих разделов читает/сохраняет через backend без Firestore fallback.
10. Перенести загрузку медиа. Готово в локальном backend: фото профиля, регистрации и чата проходят через общий `uploadData()` на backend; Firebase Storage SDK удален.
7. Добавить финансовую статистику и журнал операций. Готово: `getMoneyStats`, ledger, `adminListAuditLogs`, `AdminMoneyStatsWidget` и раздел `auditLogs` работают через backend.

## 7. Платежи

1. Вынести Kassa24 в backend. Локальный backend уже имеет совместимый слой: `createDriverTopUpPayment`, `getDriverTopUpPaymentStatus`; production-ссылка оплаты настраивается через `MTAXI_PAYMENT_PROVIDER=redirect` и `MTAXI_PAYMENT_URL_TEMPLATE`.
2. Разделить создание платежа, callback, return URL и проверку статуса. Готово: платеж создается `pending`, статус проверяется отдельно, ручное подтверждение идет через `confirmDriverTopUpPayment`, а HTTP callback `/payments/kassa24/callback` подтверждает или отклоняет платеж по `paymentId/status` и `MTAXI_PAYMENT_CALLBACK_SECRET` из headers.
3. Все изменения баланса делать только серверной транзакцией. Готово: баланс меняется только backend-операциями внутри `withStoreAsync`; PostgreSQL write операции идут через транзакцию с advisory lock. Тесты закрепляют idempotency платежа и однократный refund комиссии при повторной отмене заказа.
4. Добавить idempotency key для платежей. Готово: `createDriverTopUpPayment` переиспользует существующий платеж для того же водителя и `idempotencyKey`, а при другой сумме возвращает `PAYMENT_IDEMPOTENCY_CONFLICT`.
5. Добавить финансовый ledger и статистику. Готово в локальном backend: `ledger`, `getMoneyStats`.
6. Убрать клиентские Firestore helper-ы платежей. Готово: неиспользуемый `getPaymentDocId()` удален, создание/проверка/админский список платежей идут через backend.

## 8. Пуши и фоновые задачи

1. Firebase используется только как FCM transport.
2. Хранить FCM токены в backend DB, не в Firestore. Готово в локальном backend: `addFcmToken`, `updateFcmTokenState`.
3. Отправку уведомлений делать backend worker-ом через Firebase Admin Messaging. Готово: `createPushNotification` ставит события в очередь, `flushQueuedPushDeliveries` обрабатывает очередь. Локально без env работает `simulated-local`, на сервере при `MTAXI_FCM_ENABLED=true` используется Firebase Admin Messaging.
3. Проверять FCM production credentials до запуска. Готово: `npm run preflight` требует реальный FCM на production, а выключенный FCM разрешает только для локальной разработки через `MTAXI_ALLOW_SIMULATED_PUSH=true`. При `MTAXI_FCM_ENABLED=true` нужны `FIREBASE_SERVICE_ACCOUNT_JSON` или существующий файл `GOOGLE_APPLICATION_CREDENTIALS`.
3. Усилить проверку `FIREBASE_SERVICE_ACCOUNT_JSON`. Готово: preflight принимает только service account JSON с `project_id`, email-форматом `client_email` и PEM `private_key`, чтобы production push не стартовал с мусорным Firebase ключом.
3. Усилить проверку `GOOGLE_APPLICATION_CREDENTIALS`. Готово: preflight не ограничивается существованием файла, а читает JSON и проверяет тот же service account формат с PEM `private_key`.
3. Запретить simulated push в production. Готово: `npm run preflight` падает, если `NODE_ENV=production` и `MTAXI_ALLOW_SIMULATED_PUSH=true`.
3. Запретить Firebase data/Auth/Storage/Functions/SMS env в production. Готово: `npm run preflight` разрешает Firebase credentials только для FCM push и падает при `FIREBASE_DATABASE_URL`, `FIRESTORE_*`, `FIREBASE_STORAGE_*`, `FIREBASE_FUNCTIONS_*`, `FIREBASE_AUTH_*` и похожих переменных.
4. Заменить Firestore triggers на backend workers или scheduled jobs. Готово в локальном backend: операции заказа сами ставят push-события в backend queue, `runMaintenanceTasks` закрывает просроченные свободные заказы и отправляет очередь push. Добавлен внутренний interval-worker `MTAXI_MAINTENANCE_INTERVAL_SEC`, чтобы на своем сервере запускать maintenance без Firebase scheduled functions и без HTTP cron.
5. Добавить защиту от дублей уведомлений по `orderId + eventType`. Готово через `dedupeKey`, включая события заказов.
6. Перенести подтверждение доставки/открытия push. Готово в локальном backend: `ackPushDelivery`.
7. Перенести админскую рассылку и историю push из Firestore. Готово: `adminQueueBroadcast`, `adminListPushNotifications`; `AdminNotificationsWidget` использует backend, `ff_push_notifications` не используется.
8. Убрать Firestore refresh пользователя после открытия push. Готово: `PushNotificationsHandler` обновляет пользователя через backend `getSessionBootstrap`; сетевой `UsersRecord.getDocumentOnce` fallback удален.

## 8a. Чаты поддержки

1. Перенести создание/поиск чата поддержки. Готово в локальном backend: `ensureSupportChat`.
2. Перенести отправку сообщений. Готово в локальном backend: `sendSupportChatMessage`, `adminSendSupportChatMessage`.
3. Перенести отметку прочтения. Готово в локальном backend: `markSupportChatRead`.
4. Перенести список чатов и сообщений для админки. Готово в локальном backend: `listSupportChats`, `getSupportChatMessages`.
4. Перенести админскую очистку чатов. Готово в локальном backend и Flutter админке: `adminDeleteSupportChat`, `adminClearSupportChats`; вместе с сообщениями чистятся ссылки пользователя, действие пишется в audit log.
5. Подключить пассажирский экран чата к backend API. Готово: `SupportChatWidget` читает сообщения через `getSupportChatMessages` polling-стримом, отправляет/отмечает прочтение через backend и больше не имеет Firestore stream/write fallback.
6. Подключить админский список чатов к backend API. Готово: `AdminSupportChatsWidget` читает `listSupportChats`; карточки используют краткие данные пользователя из backend, без `queryChatsRecord` и `UsersRecord.getDocument`.
7. Подключить админский экран переписки к backend API. Готово: `AdminSupportChatWidget` читает `getSupportChatMessages` polling-стримом, отправляет/отмечает прочтение через backend и больше не имеет Firestore stream/write fallback.
8. Подключить создание нового чата из админки к backend users API. Готово: выбор пользователя использует `adminListUsers`; старый `queryUsersRecordOnce` fallback удален.
9. Подключить badge/переход поддержки в профиле пассажира к backend API. Готово: `getMySupportChat`, `mySupportChatStreamFromBackend`; Firestore `queryChatsRecord` fallback из профиля удален.
10. Подключить shortcut чатов на главной админки к backend API. Готово: `AdminHomeWidget` использует `supportChatsStreamFromBackend` и считает непрочитанные по `unread_for_admin`; Firestore/currentUser fallback для счетчика удален.
11. Финальный клиент должен читать сообщения через backend API или WebSocket/SSE, не через Firestore stream. Готово: пассажирский и админский чат читают сообщения через `supportChatMessagesStreamFromBackend`, который polling-ом вызывает backend `getSupportChatMessages`; отправка идет через `sendSupportChatMessage`, Firestore stream/write fallback не используется.

## 9. Проверка

1. Локально: `cd server && npm install && npm run dev`.
2. Healthcheck: `curl http://127.0.0.1:8080/readyz` или `cd server && npm run smoke`.
3. Flutter Web локально:
   `flutter run -d chrome --dart-define=MTAXI_BACKEND_URL=http://127.0.0.1:8080`.
4. Android emulator:
   `--dart-define=MTAXI_BACKEND_URL=http://10.0.2.2:8080`.
5. Продакшен должен задавать `MTAXI_BACKEND_URL` на адрес нового backend. Без флага клиент использует локальный backend `http://localhost:8080`; Firebase fallback не используется.
6. Backend-router должен покрывать все вызовы клиента. Готово: серверный тест сканирует `makeCloudCall`/`mtaxiBackendCall` в `lib/` и проверяет, что каждый вызов есть в `server/src/call_router.js`.

## 10. Текущее состояние

- Добавлен локальный backend-каркас.
- Подготовлен переключатель клиента `MTAXI_BACKEND_URL`.
- Добавлен guard релизной сборки клиента: `--dart-define=MTAXI_REQUIRE_REMOTE_BACKEND=true` не даст приложению работать с локальным или `http://` backend URL.
- Добавлен `scripts/build_backend_release.sh` для web/APK/iOS: release-сборки идут только с внешним `https://` backend и автоматически получают `MTAXI_REQUIRE_REMOTE_BACKEND=true`.
- Guard релизного backend URL усилен тестом: проверяются пустой URL, `localhost`, `127.0.0.1`, `0.0.0.0`, Android emulator `10.0.2.2`, LAN `192.168.*` и private `172.16-31.*`; guard должен выполниться до HTTP-запроса.
- Firebase в новом backend больше не используется для Auth/DB/Functions/SMS/Storage; оставлен только FCM push.
- Клиентские SDK Firebase Auth, Cloud Functions, Storage, Firestore, Crashlytics и Performance удалены из runtime; Firebase оставлен только для FCM push. Старые `DocumentReference/Timestamp/GeoPoint` работают через локальный compatibility layer без сетевого Firestore.
- Профиль пользователя больше не грузит внешнюю placeholder-картинку с CDN, если фото нет: используется локальная иконка, а guard-тест запрещает вернуть `placeholder.com` в клиентский runtime.
- Backend auth/session/order слой работает через единый store layer: быстрый dev использует JSON, локальный Docker Compose и production используют PostgreSQL.
- Backend уже контролирует создание заказа, расчет цены, взятие заказа, нехватку баланса, двойное взятие, отмену пассажиром, смену статусов водителя и истечение свободного заказа.
- Backend уже отдает ленту заказов водителя, детали заказа, мои заказы и админский список заказов.
- Flutter-лента водителя в backend-режиме уже читает заказы через backend API и переиспользует существующие карточки заказов.
- Flutter-экран активного заказа водителя в backend-режиме уже читает детали, проверяет назначение и отправляет статусы через backend API.
- Flutter-экран активного заказа пассажира в backend-режиме уже читает детали через backend API, отменяет/истекает заказ через backend callable и не требует Firestore/currentUserReference для контактов водителя или cancel API.
- Восстановление активного заказа пассажира/водителя в backend-режиме уже идет через `getSessionBootstrap`, без поиска и валидации в Firestore.
- Backend уже сохраняет профиль пассажира, заявку водителя, настройки пользователя и пароль.
- Backend уже поддерживает глубокое удаление текущего аккаунта без Firebase через `deleteCurrentAccountDeep`.
- Backend уже сохраняет фото профиля пассажира и координаты водителя через `updateUserPreferences`; водительская лента и активный заказ водителя больше не пишут координаты напрямую в Firestore.
- Backend уже обрабатывает админское approve/reject удаления фото авто водителя без очистки фото профиля.
- Flutter в backend-режиме уже собирает `currentUserDocument` из backend JSON через `backend_user_adapter.dart`, без чтения Firestore.
- Flutter уже сохраняет поселок через backend и не пишет черновики выбора роли/регистрации пассажира/водителя в Firestore.
- Экраны входа/SMS/регистрации пассажира/водителя больше не записывают auth-роли, admin-role или registrationDraft в Firestore; роли и регистрация идут через backend/session state.
- Push handler и push-token sync используют backend `getSessionBootstrap`, `addFcmToken`, `updateFcmTokenState`, `ackPushDelivery`; сетевого Firestore refresh после push больше нет.
- Flutter читает список поселков и локальные тарифы через общий `app_city_tariffs.dart` только из backend `listCityTariffs`, без `queryCityRecordOnce`.
- Backend уже поддерживает базовые операции админки: редактирование пользователя, одобрение/блокировка, баланс водителя, ручное управление заказом и audit log.
- Backend уже отдает audit log админки через `adminListAuditLogs`, без Firestore.
- Backend уже поддерживает админский список пользователей: `adminListUsers`.
- Flutter-экран коллекций `users` и `order` в backend-режиме читает данные через backend API, а не через Firestore streams.
- Backend уже поддерживает runtime-настройки приложения: `getRuntimeSettings`, `updateRuntimeSettings`.
- Backend уже поддерживает локальный платежный слой: создание пополнения, проверка статуса, подтверждение/ошибка, ledger и финансовую статистику.
- Backend уже отдает админский список платежей через `adminListPayments`; Flutter-экран коллекции `payments` в backend-режиме не читает Firestore.
- Backend уже поддерживает чаты поддержки: создание чата, сообщения, прочтение, список для админки.
- Backend и Flutter админка уже поддерживают админское удаление одного или всех чатов поддержки без Firebase.
- Flutter-пассажирский чат поддержки уже читает сообщения, отправляет сообщения и отмечает прочтение через backend API, без Firestore stream/write fallback.
- Flutter-профиль пассажира получает счетчик поддержки и отмечает чат прочитанным через backend API, без Firestore `queryChatsRecord` fallback.
- Flutter-админские чаты поддержки уже читают список и сообщения через backend API, без Firestore stream/write fallback.
- Flutter-создание нового чата поддержки из админки выбирает пользователя через `adminListUsers`, без `queryUsersRecordOnce`.
- Flutter runtime-настройки читаются и сохраняются через backend, без Firestore `appSettings` fallback в runtime helper.
- Справочный контент приложения: политика, "О приложении", тарифные тексты и контакты поддержки читаются через backend, без Firestore fallback.
- Backend auth/session возвращает публичного пользователя без поля `password`; клиент получает только `hasPassword`.
- Backend auth уже поддерживает безопасный `lookupUserByPhone`; экраны входа/SMS в backend-режиме используют его вместо Firestore `queryUsersRecordOnce`.
- Backend auth проверяет SMS-код через `verifySmsCode`; клиент в backend-режиме больше не сравнивает код только локально.
- Backend auth не выдает SMS-сессию без verified кода: прямой вызов `createSmsSession` до `verifySmsCode` возвращает `SMS_CODE_NOT_VERIFIED`.
- Экраны входа и SMS больше не содержат Firestore fallback поиска пользователя по номеру; поиск идет через backend `lookupUserByPhone`.
- Auth слой в backend-режиме больше не создает и не ищет Firestore `users` как fallback после входа.
- Backend уже хранит FCM токены, состояние приложения, ack доставки и локальную очередь push-уведомлений с дедупликацией.
- Backend уже имеет `runMaintenanceTasks` для фонового обслуживания без Firebase Functions: истечение старых свободных заказов и отправка очереди push.
- Backend получил внутренний maintenance scheduler: при `MTAXI_MAINTENANCE_INTERVAL_SEC>0` сервер сам закрывает просроченные свободные заказы и отправляет push-очередь без Firebase scheduled functions.
- После открытия push Flutter в backend-режиме обновляет состояние пользователя/заказов через backend bootstrap, не через Firestore user document.
- Backend уже создает push-события из жизненного цикла заказа: новый заказ, заказ взят, взял другой водитель, водитель приехал, поездка началась, заказ завершен, отмена пассажиром.
- Firebase будет использоваться только для push-уведомлений FCM.
- Подсказки адресов `getAddressSuggestions` на всех платформах идут через backend `suggestAddressesLookup`; прямой Nominatim-вызов из клиента убран.
- Геокодинг и маршруты карт идут через backend: `forwardGeocodeLookup`, `reverseGeocodeLookup`, `suggestAddressesLookup`, `routeLookup`. Прямые Nominatim/OSRM вызовы из custom-карт и address actions убраны.
- `DeliveryTaxiMap` больше не имеет Firestore fallback для межгород-маршрутов: маршруты читаются только через backend `listIntercityRoutes`.
- `cityToCity` больше не читает Firestore `intercityTariff`: тарифы межгорода берутся из backend runtime settings.
- Backend polling streams заказов и чатов больше не зависят от `isMTaxiBackendEnabled`: `backend_orders.dart` и `backend_support_chat.dart` всегда опрашивают backend.
- `AdminNotificationsWidget` больше не читает Firestore `ff_push_notifications`: история рассылок идет только через backend `adminListPushNotifications`, отправка через `adminQueueBroadcast`.
- `MeOrderWidget` больше не имеет Firestore fallback для истории заказов: список всегда читается через backend `listMyOrders`.
- `AdminMoneyStatsWidget` больше не читает Firestore `payments/order/users`: вся финансовая статистика строится только через backend `getMoneyStats`.
- `AdminDriverStatsWidget` больше не читает Firestore `appSettings/users/order`: выбор водителя и статистика идут через backend `adminListUsers`, `adminListOrders`, `getRuntimeSettings`.
- `AdminHomeWidget` больше не читает Firestore для dashboard, проверки водителей и shortcut чатов: сводка идет через `adminListOrders`, `adminListUsers`, `getMoneyStats`, чаты и счетчик непрочитанных сообщений идут через backend support stream без `currentUserReference` fallback.
- Runtime-router `AdminCollectionWidget` больше не зависит от `isMTaxiBackendEnabled`: все поддержанные разделы открывают backend-экраны, неподдержанные показывают backend-only заглушку без перехода в Firestore runtime.
- История заказов пользователя в `AdminCollectionWidget` больше не ищет заказы через Firestore `order.where(...)`: пассажирские и водительские заказы загружаются через backend `adminListOrders`.
- Форма заказа в `AdminCollectionWidget` больше не читает Firestore для выбора пассажира/водителя/города: списки идут через `adminListUsers` и `adminListCityTariffs`, а создание заказа по телефону пассажира обрабатывает backend.
- Карточки заказов в `AdminCollectionWidget` больше не дочитывают пассажира/водителя через `UsersRecord.getDocumentOnce`: подписи пользователей собираются через backend `adminListUsers`, совместимый `UsersRecord` создается локально из backend JSON.
- Создание пользователя из общей формы `users` больше не пишет напрямую в Firestore. Водитель создается через `adminCreateDriver`, пассажир через новый backend endpoint `adminCreatePassenger`; оба действия пишут audit log.
- Профиль пассажира больше не держит backend/Firebase ветвление для счетчика и отметки прочтения чата поддержки: данные идут через backend support API. Оставшиеся `BackendRefs.instance.doc(path)` в этом экране только собирают совместимый `DocumentReference` из backend path без сетевого чтения.
- Проверка исчезнувшего заказа в водительской ленте больше не дочитывает заказ из Firestore: используется `loadOrderDetailsFromBackend`.
- Heartbeat активности пользователя больше не пишет `last_active` в Firestore: `main.dart` отправляет `updateUserPreferences(lastActive: true)`, backend сохраняет `lastActive`.
- Восстановление активного заказа в `main.dart` больше не валидирует пассажирский/водительский заказ через `orderRef.get()`: детали берутся через `loadOrderDetailsFromBackend`, Firestore-read fallback удален.
- Push serialization больше не содержит неиспользуемый `getDocumentParameter()` с Firestore `doc().get()`: скрытый read из helper-а удален.
- Runtime settings helper `app_settings.dart` больше не содержит Firestore fallback: `getRuntimeSettings`, `updateRuntimeSettings` и polling `watchAppRuntimeSettings` работают только через backend.
- FlutterFlow nav serialization больше не содержит неиспользуемые `getDoc/getDocList` с Firestore `.get()`: навигация оставляет только совместимое преобразование path в `DocumentReference` без сетевого чтения.
- `order_state_compat.dart` больше не содержит старые Firestore recovery-поиски активных заказов по пользователю, телефону и водителю: восстановление пассажирского/водительского заказа идет только через backend `getSessionBootstrap`.
- Старые FlutterFlow query helper-ы `queryCollection*` в `backend.dart` больше не содержат сетевых Firestore `.get()`, `.count()` или `.snapshots()` fallback: они возвращают пустой совместимый результат, а реальные данные должны идти через backend API; это закреплено в `backend_only_guard_test.dart`.
- Сгенерированные record-модели `*_record.dart` больше не содержат сетевого Firestore `ref.snapshots()`/`ref.get()` fallback: `getDocument/getDocumentOnce` возвращают локальную совместимую модель по `DocumentReference`, а реальные данные читаются через backend API. Это закреплено в `backend_only_guard_test.dart`.
- Legacy `createCustomAuthToken` убран из клиента и backend-router: вход по паролю идет через явный endpoint `passwordLogin`, SMS-сессия через `createSmsSession`.
- Старый универсальный редактор админки защищен от прямого `set/delete` в Firebase: при backend-only режиме сохранение и удаление через fallback-редактор блокируются. Общий список неподдержанных коллекций показывает backend-only заглушку без старого Firestore `StreamBuilder`, а `_buildQuery()` больше не создает Firestore collection query; это закреплено guard-тестом.
- Прямые write-вызовы старого fallback-редактора админки удалены из рабочего кода: `reference.set`, `collection.add` и `reference.delete` больше не доступны даже в недостижимой ветке; guard-тест проверяет это отдельно.
- Backend callable `getStoreHealth` добавлен для проверки активного хранилища через тот же `/call/:name` контракт: локально показывает JSON-store, на сервере будет показывать PostgreSQL health/error.
- PostgreSQL-store начал поддерживать async-контракт для `users`, `sms_codes`, `orders`, `payments`, `withdrawals`, `ledger`, `support_chats`, `support_messages`, `fcm_tokens`, `notifications`, `notification_deliveries`, `push_delivery_acks`, `settings`, `intercityTariff`, `content_documents`, `city_prices`, `intercity_routes`, `generic_documents` и `audit_logs`: `readStoreAsync/writeStoreAsync/withStoreAsync` работают через PostgreSQL для уже переведенных async-доменов; старые sync-методы остаются заблокированы.
- Основные admin write операции уже вызываются из `call_router` через async API: создание/обновление пользователей, approve/reject фото авто, approve/block/unblock водителя, поселок, задержка, баланс и ручное управление заказом.
- Android Gradle больше не подключает Firebase Crashlytics plugin; в клиентском `pubspec.yaml` нет Firebase Auth/Functions/Storage/Crashlytics/Performance/Firestore и неиспользуемых platform-auth SDK `google_sign_in`/`sign_in_with_apple`. Остаются `firebase_core`/`firebase_messaging` для FCM. Старые `DocumentReference/Timestamp/GeoPoint` заменены локальным compatibility layer `lib/backend/backend_refs_compat.dart`, который не обращается в Firebase.
- Клиентский backend-only режим закреплен Flutter-тестом `test/backend_only_guard_test.dart`: старые Firebase Auth/DB/Functions/Storage/Crashlytics/Performance зависимости и прямые SDK imports теперь ловятся автоматически.
- Общий клиентский `lib/backend/backend.dart` больше не экспортирует `firebase_core`: Firebase Core остается только в FCM initialization path, а не в generic backend layer.
- Старый iOS generated-кэш `ios/Flutter/ephemeral` удален из рабочего дерева; guard-тест теперь проверяет `FlutterGeneratedPluginSwiftPackage/Package.swift`, если Flutter снова его создаст, чтобы туда не вернулись Firebase Auth/Firestore/Storage.
- Текст согласия/политики в приложении больше не заявляет хранение персональных данных в Google Firebase: данные хранятся на backend-серверах оператора, Firebase используется только для push-уведомлений FCM.
- `server/src/admin.js` больше не экспортирует старые sync-store админские операции. Наружу доступны только async admin API и общие helpers `requireAdmin`/`addAudit`, чтобы production-router не мог случайно использовать заблокированный sync-store в PostgreSQL-режиме.
- PostgreSQL-store теперь сохраняет и читает `paymentSequence` через `app_settings`, а JSON→PostgreSQL миграция переносит это значение. Нумерация/последовательность платежей не сбрасывается при переходе на полноценную базу.
- PostgreSQL схема, store и JSON→PostgreSQL миграция для `push_delivery_acks` приведены к реальной idempotency-модели backend: повторный ack дедуплицируется по `user_id + event_type + notification_id`, а не по `order_id`.
- PostgreSQL schema migration для `push_delivery_acks.notification_id` безопасна для уже существующих строк: старые записи получают `notification_id` из JSON `data.notificationId`, а при отсутствии - из собственного `id`, чтобы уникальный индекс создавался без конфликтов.
- Role-state machine синхронизирован между backend и Flutter: legacy `DRIVER_PENDING_REVIEW` нормализуется в `DRIVER_PENDING`, поэтому старые записи не ломают маршрутизацию.
- Сценарии ролей закреплены тестами backend: пассажир, водитель на проверке, одобренный водитель и заблокированный пользователь. Заблокированный аккаунт не может создавать заказы и выполнять рабочие backend-операции.
- Чаты поддержки на клиенте закрыты как backend-only: пассажирский и админский экран используют polling-stream поверх backend API `getSupportChatMessages/listSupportChats`, без сетевого Firestore stream.
- Платежный callback подготовлен для полноценного сервера: `POST /payments/kassa24/callback` применяет успешное пополнение один раз, отклоняет неверный secret и не требует клиентского подтверждения оплаты.
- Создание платежа больше не привязано только к локальной странице: production может отдавать provider redirect URL через `MTAXI_PAYMENT_URL_TEMPLATE`; preflight проверяет внешний HTTPS шаблон с обязательными `{{paymentId}}`/`{{amount}}`, а local provider разрешается только с `MTAXI_ALLOW_LOCAL_PAYMENT=true`.
- `/local-payment/:paymentId` закрыт runtime-guard-ом: production без local-payment dev-флага возвращает `LOCAL_PAYMENT_DISABLED`, поэтому локальная HTML-заглушка не остается публичным платежным экраном.
- Секрет платежного callback в production принимается из headers `x-mtaxi-payment-secret`/`x-kassa24-secret`; передача секрета в JSON body отключена по умолчанию.
- PostgreSQL readiness закреплен тестом: runtime backend-модули больше не могут незаметно вернуть старый sync-store контракт.
- Для будущего арендного сервера добавлен `server/.env.example`: все нужные env-переменные собраны в одном месте.
- `server/.env.example` приведен к production-oriented режиму: PostgreSQL, HTTP SMS provider, redirect payment provider, maintenance worker и FCM включены как целевые настройки; локальные SMS/payment/push режимы оставлены только как явно разрешаемые dev-флаги.
- Добавлен `npm run preflight`: перед production-запуском он проверяет env, корректный `PORT`, внешний HTTPS `MTAXI_PUBLIC_BASE_URL`, PostgreSQL `DATABASE_URL`, upload-dir, production payment provider и безопасный режим платежного callback-secret. Локальные/insecure public URL разрешены только при явных dev-флагах.
- `npm run preflight` при `NODE_ENV=production` дополнительно запрещает dev-флаги `MTAXI_ALLOW_LOCAL_PUBLIC_BASE_URL`, `MTAXI_ALLOW_INSECURE_PUBLIC_BASE_URL`, `MTAXI_ALLOW_LOCAL_SMS`, `MTAXI_ALLOW_LOCAL_PAYMENT`, `MTAXI_ENABLE_LEGACY_CREATE_TOKEN` и simulated push.
- Добавлен `npm run preflight:production`, который принудительно запускает preflight с `NODE_ENV=production` для ручной проверки VPS env до старта backend.
- `npm run preflight` также проверяет env фоновых задач: `MTAXI_MAINTENANCE_INTERVAL_SEC`, `MTAXI_PENDING_ORDER_TTL_MIN`, `MTAXI_MAINTENANCE_ORDER_LIMIT`, `MTAXI_MAINTENANCE_PUSH_LIMIT`.
- `npm run preflight` также проверяет SMS env: срок действия кода и cooldown повторной отправки.
- `npm run preflight` требует для HTTP SMS provider внешний `https://` URL, не `localhost`/LAN и не `http://`.
- `npm run preflight` запрещает `MTAXI_SMS_DEV_RETURN_CODE=true` без local-dev SMS флага, чтобы production API не возвращал SMS-код клиенту.
- Добавлен Docker/Compose production-like запуск: `docker compose -f docker-compose.backend.yml up --build` поднимает backend + PostgreSQL, применяет схему и проверяет env через preflight.
- Backend entrypoint готов к контейнерным рестартам: `SIGTERM`/`SIGINT` закрывает HTTP server и останавливает maintenance scheduler.
- Добавлен bootstrap первого администратора без Firebase и ручного SQL: `npm run seed:admin`.
- `npm run preflight` проверяет, что при включенном `MTAXI_FCM_ENABLED=true` заданы Firebase Admin credentials только для FCM push, и в production запрещает Firebase env для данных/Auth/Storage/Functions/SMS.
- PostgreSQL схема `ledger.payment_id` приведена к фактическому backend-контракту: там хранится внешний `paymentId` (`kassa24_...`), а не внутренний `payments.id`, поэтому внешний ключ на `payments(id)` удален.
- Ссылки оплаты теперь строятся через общий публичный backend base URL (`MTAXI_PUBLIC_BASE_URL` или proxy headers), а не через жесткий `127.0.0.1`. На арендном сервере файлы и `/local-payment/:paymentId` будут отдавать публичные ссылки.
- HTTP-слой backend получил production-настройки: `MTAXI_CORS_ORIGINS` ограничивает разрешенные web-домены и проверяется `preflight` как список реальных `http/https` origins без wildcard/path/query, а `MTAXI_JSON_BODY_LIMIT` управляет лимитом JSON body и тоже проверяется `preflight`. Без env локальная разработка остается открытой.
- HTTP-слой backend получил базовые security headers и `MTAXI_TRUST_PROXY` для запуска за nginx/Caddy/Traefik; `false/no/off` корректно отключают proxy trust, а `preflight` ловит неверный формат. Access logs пишут requestId/method/path/status/duration без body и query-параметров. Неизвестные routes и некорректный JSON теперь возвращают единый JSON-ответ с `success:false`, `code` и `requestId`.
- Добавлен production nginx-шаблон `deploy/nginx/mtaxi-api.conf`: HTTP редиректит на HTTPS, API проксируется на `127.0.0.1:8080`, передаются `Host`, `X-Forwarded-*`, `X-Request-Id`, задан `client_max_body_size 25m` для upload.
- Добавлен `deploy/predeploy_check.sh`: перед первым запуском на VPS проверяет наличие production-файлов, `server/.env`, запрет `NODE_ENV=development`, запускает `npm run validate:production-deploy`, `docker compose config` и nginx syntax check при наличии команд.
- Static-раздача `/uploads` получила `nosniff`, `Cross-Origin-Resource-Policy: cross-origin` и управляемый `MTAXI_UPLOAD_CACHE_MAX_AGE_SEC`; `preflight` проверяет TTL, чтобы публичные фото/документы стабильно отдавались через production proxy.
- Backend теперь загружает `.env` через `dotenv` в `npm run start`, `npm run preflight` и `npm run db:migrate-json`, поэтому `server/.env.example` можно реально копировать в `.env` на локальном/арендном сервере.
- При `NODE_ENV=production` прямой backend entrypoint выполняет `runPreflight()` до `listen`, поэтому production `npm start` не поднимет порт с неправильным env даже вне Docker.
- Backend runtime зафиксирован на Node.js 20+: `package.json` содержит `engines.node`, а `preflight` проверяет текущую версию Node до production-запуска.
- Backend guard закрепляет целевую архитектуру Firebase: `firebase-admin` разрешен только в `push_transport.js` для FCM, а Firestore/Auth/Storage API на сервере запрещены тестом.
- Backend guard дополнительно запрещает прямые Firebase-зависимости на сервере кроме `firebase-admin`: если в `server/package.json` вернуть клиентские `firebase`/`@firebase/*` пакеты или другой `firebase-*` SDK, `npm test` упадет. Транзитивные пакеты внутри `firebase-admin` допустимы только как часть FCM Admin SDK.
- Docker/Compose умеет автоматически создать первого администратора перед стартом backend через `MTAXI_SEED_ADMIN_ON_START=true`; preflight проверяет телефон, пароль и имя только при включенном auto seed.
- Dockerfile получил container healthcheck на `/readyz`; локальный `docker-compose.backend.yml` явно запускается с `NODE_ENV=development`, чтобы dev SMS/payment/push флаги не конфликтовали со строгим production preflight.
- Добавлен `docker-compose.production.yml` для VPS: берет `server/.env`, запускает backend с `NODE_ENV=production`, PostgreSQL volume, backend `/readyz` healthcheck и без dev SMS/payment/push флагов; пароль PostgreSQL и `DATABASE_URL` задаются в `server/.env`, без опасной Compose-подстановки `${...}` до чтения env-file.
- Добавлен `npm run validate:production-deploy`: до первого запуска на VPS проверяет `docker-compose.production.yml`, `server/.env`, production preflight без подключения к базе и совпадение `POSTGRES_PASSWORD` с паролем внутри `DATABASE_URL`.
- `npm run validate:production-deploy` теперь проверяет, что `server/.env.example` содержит обязательные production-ключи для public URL, CORS, JWT, PostgreSQL, uploads, backup, payments, SMS, FCM и maintenance, чтобы VPS не копировал устаревший env-шаблон.
- `npm run validate:production-deploy` теперь проверяет `ENV_CONTRACT`: production должен оставаться на PostgreSQL, backend SMS/payment provider и Firebase только для FCM push.
- `npm run validate:production-deploy` теперь проверяет `server/package.json`: Node.js должен быть `>=20`, а production lifecycle scripts (`start`, `preflight`, `preflight:production`, `smoke`, `monitor`, `db:apply-schema`, `db:backup`, `db:restore`, `seed:admin`) должны оставаться на ожидаемых backend-скриптах.
- `npm run validate:production-deploy` теперь проверяет Docker build context: `package-lock.json` должен быть на месте для `npm ci`, Dockerfile должен использовать `COPY package*.json` + `npm ci --omit=dev`, а `.dockerignore` должен исключать `.env`, `data`, `uploads` и `node_modules`.
- `npm run validate:production-deploy` теперь проверяет порядок старта Dockerfile: сначала применяется PostgreSQL-схема, потом проходит preflight, затем при необходимости создается первый админ и только после этого открывается HTTP API.
- Docker/Compose закрыт guard-тестом: production Dockerfile/compose должны оставаться с `NODE_ENV=production`, PostgreSQL и без local SMS/payment/simulated push; local compose остается только development.
- `npm run validate:production-deploy` теперь проверяет PostgreSQL persistence в production compose: база должна храниться в named volume `mtaxi_postgres_data`, а `server/db/schema.sql` должен быть смонтирован как readonly init schema `001_schema.sql`.
- `npm run validate:production-deploy` теперь проверяет, что production backend port опубликован только как `127.0.0.1:8080:8080`, чтобы внешний доступ шел через HTTPS reverse proxy, а не напрямую в контейнер.
- Production deploy validator теперь проверяет `server/.env`: `NODE_ENV=development` в production env считается ошибкой, чтобы VPS не стартовал с dev-конфигурацией при ручном запуске.
- Preflight не пропускает дефолтный admin placeholder `+70000000000`, чтобы первый админ на сервере создавался только с реальным телефоном владельца.
- Preflight не пропускает placeholder-секреты `replace-with`, `change-this` и `mtaxi_change_me`, чтобы production не стартовал с шаблонными паролями.
- Docker перед стартом применяет PostgreSQL-схему через `npm run db:apply-schema`, поэтому обновление backend не требует удалять volume базы.
- PostgreSQL readiness/getStoreHealth возвращает `schemaVersion` и `schemaAppliedAt` из `schema_migrations`, чтобы после деплоя сразу видеть примененную версию схемы.
- Добавлен guard, который сверяет все Flutter backend-вызовы с `server/src/call_router.js`: приложение не должно получать `NOT_IMPLEMENTED` из-за забытого endpoint-а.
- Добавлен guard, который проверяет, что старый универсальный редактор админки не сможет обойти backend-only режим и выполнить прямые Firebase `set/add/delete` до защитного условия.
- Добавлен production deployment checklist: `docs/backend_deployment_checklist.md` фиксирует перенос на VPS, env, Docker/PostgreSQL, миграцию, HTTPS, release-сборки, smoke test, backup и rollback.
- Production smoke усилен read-only проверками `getRuntimeSettings`, а при наличии тестового логина еще `listCityTariffs` и `listIntercityRoutes`, чтобы после запуска сразу ловить проблему с настройками, поселками, тарифами и межгородом до выдачи сборки пользователям.
- `npm run smoke` получил production guard `MTAXI_SMOKE_EXPECT_STORE=postgres`, чтобы после деплоя сразу падать, если backend случайно запущен на JSON-store вместо PostgreSQL или PostgreSQL-схема не применена (`schemaVersion` пустой); для публичного production smoke также требуется HTTPS base URL. При переданных smoke-логинах скрипт дополнительно проверяет `passwordLogin`, `getSessionBootstrap`, `adminListUsers` и `getMoneyStats`; backend-тест запускает smoke против реального локального Express server.
- Добавлен `npm run status`: быстрая read-only диагностика backend без логина и без записей в базу. Проверяет `livez`, `readyz`, `getStoreHealth`, `getBackendArchitectureStatus` и печатает JSON-сводку с `baseUrl`, типом store, `schemaVersion` и подтверждением `backend-only`/`FCM transport`.
- Добавлен `npm run monitor`: легкая read-only проверка для cron после VPS-деплоя. Скрипт проверяет `livez`, `readyz`, `getStoreHealth`, `getRuntimeSettings`, `getBackendArchitectureStatus`, PostgreSQL `schemaVersion`, а при админском логине еще `adminListUsers`, `getMoneyStats` и `adminListPushNotifications`.
- Production smoke/monitor теперь проверяют не только `backend-only` и `FCM transport`, но и явный запрет Firebase Auth, Firestore, Cloud Functions, Storage и SMS в `getBackendArchitectureStatus`.
- Добавлены systemd-шаблоны для VPS: `mtaxi-backend.service` поднимает production Docker Compose после перезагрузки сервера, `mtaxi-monitor.service` запускает `npm run monitor`, `mtaxi-monitor.timer` повторяет проверку каждые 5 минут.
- `npm run validate:production-deploy` теперь проверяет `mtaxi-backend.service`: service должен ждать Docker/network, запускать `/opt/mtaxi/docker-compose.production.yml up -d --build`, останавливаться через `down`, оставаться active через `RemainAfterExit=yes` и устанавливаться в `multi-user.target`.
- `npm run validate:production-deploy` теперь проверяет systemd timers: backup должен запускаться ежедневно в `03:30` с `Persistent=true` и `RandomizedDelaySec=10min`, monitor должен стартовать через `2min` после boot и повторяться каждые `5min`.
- Добавлен `deploy/ops_check.sh`: read-only диагностика VPS проверяет production-файлы, systemd, последний backup manifest в `/var/backups/mtaxi`, возраст backup через `MTAXI_OPS_BACKUP_MAX_AGE_HOURS` (валидирует целое число, по умолчанию 36 часов), SHA-256 backup-файлов через `npm run db:verify-backup`, наличие `docker compose`, `docker compose ps`, `livez`, `readyz`, `getStoreHealth` и `npm run monitor`, чтобы быстро понять проблему после переноса.
- `npm run validate:production-deploy` теперь проверяет `deploy/ops_check.sh`: диагностика должна оставаться read-only, проверять systemd/timers, backup age, backup manifest verification, `docker compose ps`, `livez`, `readyz`, `getStoreHealth`, `npm run monitor` и не содержать `docker compose down` или `db:restore`.
- Добавлен `deploy/install_vps_units.sh`: установщик systemd/nginx-шаблонов для VPS. Он копирует service/timer/nginx config и делает `systemctl daemon-reload`, но не запускает контейнеры и не меняет данные; если путь установки не `/opt/mtaxi`, скрипт падает до копирования, потому что service-шаблоны жестко указывают `/opt/mtaxi`.
- `deploy/install_vps_units.sh` теперь заранее создает backup-директорию `/var/backups/mtaxi` (`MTAXI_BACKUP_DIR`, права `0750`), чтобы scheduled backup не зависел от неявного создания bind mount Docker-ом.
- `npm run validate:production-deploy` теперь сверяет backup path между `docker-compose.production.yml`, `mtaxi-backup.service` и `install_vps_units.sh`, чтобы `/var/backups/mtaxi` не разъехался между volume, systemd env и установщиком.
- `npm run validate:production-deploy` теперь проверяет `mtaxi-backup.service`: service должен зависеть от `mtaxi-backend.service`, читать `/opt/mtaxi/server/.env`, запускать `docker compose exec -T` внутри backend-контейнера, пробрасывать `MTAXI_BACKUP_DIR`/`MTAXI_BACKUP_RETENTION_DAYS` и выполнять только `npm run db:backup`.
- `npm run validate:production-deploy` теперь сверяет upload path: production compose должен монтировать `mtaxi_uploads` в `/var/lib/mtaxi/uploads`, а `server/.env` должен указывать `MTAXI_UPLOAD_DIR=/var/lib/mtaxi/uploads`, чтобы медиа не терялись при пересборке контейнера.
- `npm run validate:production-deploy` теперь проверяет, что `DATABASE_URL` использует docker-host `postgres`, а не `localhost`, чтобы backend на VPS подключался к базе внутри compose-сети.
- `npm run validate:production-deploy` теперь проверяет nginx reverse proxy template: HTTP должен редиректить на HTTPS, HTTPS должен проксировать API на `127.0.0.1:8080`, передавать `Host`, `X-Forwarded-*`, `X-Request-Id` и сохранять upload limit `25m`.
- `deploy/predeploy_check.sh` теперь проверяет наличие не только systemd backup timer, но и самих `server/scripts/backup_backend.js`/`restore_backend.js`, чтобы VPS не прошел predeploy без rollback-инструментов.
- `deploy/vps_prereq_check.sh` теперь явно требует Node.js 20+ и `npm` для predeploy/validate/ops tooling, а `deploy/predeploy_check.sh` сначала запускает VPS prerequisite check и перед validation сам выполняет `npm ci --omit=dev`, потому что source archive намеренно не содержит `server/node_modules`.
- Добавлен `scripts/start_local_backend.sh`: локальный helper проверяет `docker`, `docker compose` и `curl`, поднимает PostgreSQL/backend через `docker-compose.backend.yml`, ждет `/readyz`, запускает `npm run smoke` с `MTAXI_SMOKE_EXPECT_STORE=postgres` и логином локального админа, печатает локального админа и отдельные команды Flutter для Web/Desktop (`127.0.0.1`) и Android emulator (`10.0.2.2`).
- Docker/PostgreSQL local helper теперь создает временный compose override и синхронизирует host-порт/public URL с `MTAXI_LOCAL_BACKEND_URL`, чтобы локальная проверка могла работать не только на `8080`.
- Добавлен `scripts/start_local_json_backend.sh`: fallback helper для машин без Docker, запускает тот же HTTP backend на JSON-store, включает только local-dev SMS/payment/simulated push, ждет `/readyz`, запускает smoke и печатает Flutter команды для Web/Desktop и Android emulator.
- Добавлен `scripts/check_local_json_backend.sh`: одноразовая проверка local JSON backend без Docker для CI/локального gate, стартует backend на временных data/uploads, ждет `/readyz`, запускает smoke и гарантированно останавливает процесс через cleanup.
- Local JSON backend helper-ы теперь синхронизируют `PORT` с портом в `MTAXI_LOCAL_BACKEND_URL`, чтобы проверка не зависала при запуске на нестандартном локальном порту.
- Добавлен `scripts/stop_local_backend.sh`: проверяет `docker compose` и безопасно останавливает локальный compose без `-v`, чтобы не удалить PostgreSQL volume и uploads.
- Добавлен callable `getBackendArchitectureStatus`: backend через API возвращает контракт `backend-only`, список backend-authoritative доменов и запрет Firebase для Auth/Firestore/Functions/Storage/SMS/данных; `npm run smoke` теперь проверяет этот контракт.
- Добавлен `scripts/check_release_ready.sh`: перед web/APK/iOS release без сборки проверяет внешний `https://` backend URL, запускает production smoke с PostgreSQL guard и Flutter backend-only guard.
- `scripts/check_release_ready.sh` теперь заранее проверяет наличие Flutter SDK (`FLUTTER_BIN`), чтобы release readiness не проходил и не падал неясно без клиентского backend-only guard.
- `scripts/build_backend_release.sh` перед каждой web/APK/iOS сборкой теперь сам запускает `check_release_ready.sh`, поэтому релиз не стартует без успешного production smoke и Flutter backend-only guard.
- Проверка release backend URL вынесена в общий `scripts/remote_backend_url_guard.sh`, чтобы readiness-check и web/APK/iOS build использовали один и тот же запрет `http`, `localhost`, emulator, LAN/private и link-local адресов.
- `scripts/build_backend_release.sh web` после сборки запускает `scripts/check_web_backend_artifact.sh`: готовый `build/web/main.dart.js` должен содержать production `MTAXI_BACKEND_URL` и не должен содержать локальные backend URL.
- `scripts/build_backend_release.sh apk|ios` после сборки запускает `scripts/check_mobile_backend_artifact.sh`: APK/IPA проверяются по строкам внутри бинарников, чтобы релиз не ушел с локальным backend URL.
- Web/APK artifact guards закреплены execution-тестом: тест создает временный web artifact и APK-like zip, проверяет успешный production URL и падение на локальном backend URL.
- Web/APK artifact guards теперь ловят не только `http://localhost`, но и embedded `https://` private/LAN/CGNAT/link-local backend URL внутри готового артефакта.
- Добавлен `scripts/package_source_archive.sh`: архивирует только исходники для переноса на VPS, исключает build/node_modules/Pods/local data/uploads/backups/secrets и падает, если архив больше 500 MiB.
- Добавлен `scripts/verify_source_archive.sh`: проверяет source archive на размер, обязательные backend/deploy/client файлы и отсутствие секретов/тяжелых папок; `package_source_archive.sh` запускает verifier автоматически.
- `scripts/verify_source_archive.sh` теперь требует ключевые VPS/release helper-скрипты внутри архива: build/release checks, migration-ready gate, source/handoff packaging, local backend start/stop и общий remote backend URL guard.
- `scripts/check_backend_migration_ready.sh` теперь проверяет синтаксис `package_vps_handoff.sh`, а archive verifier требует `deploy/vps_prereq_check.sh` и `scripts/generate_production_env.sh`, потому что они нужны для передачи на VPS.
- Source archive дополнительно защищен от попадания `.log`, `.DS_Store` и playwright-кэша, чтобы на сервер передавались только исходники и production-инструкции.
- Source archive теперь также исключает и verifier запрещает Android/iOS signing/release артефакты (`android/key.properties`, `.keystore.properties`, `.signing.properties`, `.jks`, `.keystore`, `.p12`, `.mobileprovision`, `.aab`, `.apk`, `.ipa`), чтобы ключи подписи и готовые сборки не уходили в VPS handoff.
- Source archive packager и verifier теперь также исключают/запрещают старые Firebase Hosting/Firestore/Storage deploy-артефакты (`firebase/`, `firebase.json`, `.firebaserc`, `firestore.rules`, `firestore.indexes.json`, `storage.rules`), чтобы VPS handoff оставался backend-only.
- Source archive verifier теперь требует критичные VPS/runtime файлы: `server/package-lock.json`, `.dockerignore`, production server scripts, nginx config, ops check и все systemd service/timer шаблоны, чтобы handoff не прошел с неполным серверным пакетом.
- Source archive теперь также исключает machine-specific Flutter/Android файлы (`android/local.properties`, `ios/Flutter/Generated.xcconfig`, `ios/Flutter/flutter_export_environment.sh`), чтобы VPS handoff не зависел от путей локального Mac/SDK.
- `scripts/verify_source_archive.sh` закреплен execution-тестом: тест создает минимальный tar.gz, проверяет успешную верификацию, отказ при `server/.env` и отказ при отсутствии обязательного release/VPS helper-скрипта.
- `scripts/package_source_archive.sh` теперь создает `.sha256` checksum рядом с архивом, а `verify_source_archive.sh` проверяет checksum при наличии sidecar-файла.
- Source archive теперь обязательно включает `ARCHITECTURE_STATUS.md`, а backend-тест проверяет, что этот статус не ссылается на удаленные Firebase-era файлы и все указанные source-файлы реально существуют.
- Добавлен `scripts/check_backend_migration_ready.sh`: единый локальный gate перед выдачей VPS, запускает backend tests, shell syntax, реальный local JSON backend smoke без Docker, сборку/проверку source archive и финальную сборку/проверку VPS handoff-пакета без требования реального сервера.
- Добавлен `scripts/package_vps_handoff.sh`: собирает папку `output/mtaxi-vps-handoff-*` с source archive, `.sha256` и `DEPLOY_NEXT_STEPS.md` для передачи на арендный сервер.
- VPS handoff теперь содержит `HANDOFF_MANIFEST.json` с типом пакета, датой, именем source archive, размером, SHA-256, verifier-скриптом, `API_CONTRACT.json`, `ENV_CONTRACT.json` и отметкой `FCM push only`, чтобы на сервере можно было сверить, что именно передано.
- VPS handoff manifest и `HANDOFF_STATUS.md` теперь явно фиксируют готовность `99%`: локальный backend/handoff готов, но `100%` допускается только после реального VPS, домена, production env и production smoke.
- Добавлены `scripts/backend_migration_status.sh` и `scripts/verify_backend_migration_status.sh`: формируют и проверяют machine-readable `READINESS_REPORT.json` с готовностью 99%, backend-only архитектурой, Firebase только FCM, локальными доказательствами и внешними условиями для 100%; handoff включает этот файл, а readiness gate и verifier проверяют его.
- VPS handoff теперь также содержит `HANDOFF_STATUS.md`: краткий статус готовности, список локально пройденных проверок и список того, что остается до 100% после выдачи VPS/домена/env.
- `HANDOFF_STATUS.md` теперь синхронизирован с manifest `verifiedChecks`: в статусе явно перечислены JavaScript syntax, Firebase FCM-only guard и client backend-only static check; `verify_vps_handoff.sh` требует эти строки.
- VPS handoff manifest теперь содержит `verifiedChecks`: backend tests, shell syntax, JavaScript syntax, Firebase FCM-only guard, client backend-only static check, local JSON backend smoke, source archive verification и handoff checksum verification; verifier требует эти пункты перед передачей на сервер.
- VPS handoff manifest теперь также фиксирует backup manifest verification script, чтобы пакет для сервера явно подтверждал наличие проверки резервных копий.
- VPS handoff manifest теперь также фиксирует VPS postdeploy check script, чтобы пакет для сервера явно подтверждал наличие финального read-only gate после деплоя.
- VPS handoff manifest теперь также фиксирует backend migration status report verification, чтобы readiness-процент и внешние условия для 100% были частью проверенного контракта.
- `DEPLOY_NEXT_STEPS.md` внутри VPS handoff теперь запускает `scripts/check_vps_postdeploy.sh` сразу после старта systemd-сервисов, а `ops_check.sh` оставлен как быстрая дополнительная диагностика.
- `docs/vps_required_inputs.md` синхронизирован с handoff flow: после systemd start сначала запускается `scripts/check_vps_postdeploy.sh`, а `ops_check.sh` остается дополнительной диагностикой.
- Добавлен `scripts/verify_vps_handoff.sh`: проверяет `HANDOFF_MANIFEST.json`, source archive, размер, SHA-256, sidecar checksum, bundled `verify_vps_handoff.sh`, `HANDOFF_STATUS.md`, `API_CONTRACT.json`, `ENV_CONTRACT.json` и `DEPLOY_NEXT_STEPS.md`; `package_vps_handoff.sh` запускает verifier автоматически.
- `scripts/verify_vps_handoff.sh` теперь shell-only: manifest читается через `awk`, без `node -e`, поэтому handoff можно проверить на чистом VPS до распаковки исходников и до установки Node.js.
- `scripts/verify_vps_handoff.sh` теперь запрещает лишние файлы в handoff-папке, а `scripts/package_vps_handoff.sh` отказывается собирать пакет поверх непустой папки.
- `scripts/package_vps_handoff.sh` дополнительно запускает bundled `verify_vps_handoff.sh` из самой handoff-папки, чтобы до передачи на VPS проверить именно тот verifier, который поедет на сервер.
- `DEPLOY_NEXT_STEPS.md` внутри VPS handoff теперь содержит точные команды для `/tmp/mtaxi-handoff`: `shasum`, запуск verifier, `sudo mkdir -p /opt/mtaxi`, распаковку `tar -C /opt/mtaxi` и вход в проект перед predeploy.
- VPS handoff-инструкции теперь явно выполняют `chmod +x verify_vps_handoff.sh` перед проверкой и используют `sudo` для создания/распаковки `/opt/mtaxi`, чтобы перенос не зависел от прав обычного пользователя и способа загрузки файлов.
- `DEPLOY_NEXT_STEPS.md` теперь ведет через `docs/vps_inputs.template.env` и `./scripts/check_vps_inputs.sh /tmp/mtaxi-vps-inputs.env` перед генерацией `server/.env`, чтобы домен, DNS/HTTPS, SMS, payment, FCM и первый админ были проверены до predeploy.
- `scripts/package_vps_handoff.sh` закреплен execution-тестом: тест реально собирает handoff-папку, проверяет source archive, `.sha256`, `HANDOFF_MANIFEST.json`, bundled verifier, `DEPLOY_NEXT_STEPS.md`, checksum, запуск bundled verifier, отказ при лишнем файле/непустой папке и наличие шагов VPS/predeploy/env/FCM-only.
- Клиентский backend-only guard теперь дополнительно проверяет generated Android/iOS registrant и `ios/Podfile.lock`: среди native Firebase plugins разрешены только `firebase_core` и `firebase_messaging`; Auth/Firestore/Functions/Storage не должны вернуться даже через generated-файлы.
- Добавлен `scripts/check_firebase_fcm_only.sh`: быстрый shell-guard без Flutter SDK, который запрещает возврат Firebase Auth/Firestore/Functions/Storage/Crashlytics/Performance/Database в клиенте и сервере; `firebase-admin` разрешен только в `server/src/push_transport.js` для FCM. Guard подключен в release readiness, migration readiness и source archive verifier.
- Добавлен `scripts/check_client_backend_only_static.sh`: быстрый static-check клиента без Flutter SDK, который дополнительно проверяет `pubspec`, `.flutter-plugins-dependencies`, `lib/`, Android/iOS registrants, `ios/Podfile.lock` и native Firebase config; он подключен в release readiness, migration readiness и source archive verifier.
- `scripts/check_client_backend_only_static.sh` теперь также ловит возврат старых FlutterFlow Firestore read/write fallback: `.snapshots()`, `.count()`, `ref.get()/ref.snapshots()` в generated record-моделях и `reference.set/add/delete` в общей админке.
- Добавлен `deploy/vps_prereq_check.sh`: read-only проверка VPS до установки, проверяет Docker Compose, systemd, curl/tar/shasum, nginx/reverse proxy, свободное место и занятость портов `80/443`.
- Добавлен `scripts/generate_production_env.sh`: генерирует production `.env` из `server/.env.example`, фиксирует `NODE_ENV=production`, сам создает сильные секреты для JWT/PostgreSQL/payment callback и требует реальные внешние `https` URL для API/SMS/payment плюс FCM credentials.
- `scripts/generate_production_env.sh` теперь подхватывает SMS method/token/headers/body и seed-admin значения из загруженного `vps_inputs.env`, валидирует SMS-шаблон и не пропускает включенный первый админ без реального телефона/пароля.
- `scripts/generate_production_env.sh` закреплен execution-тестом: тест реально запускает generator, проверяет `NODE_ENV=production`, внешний API/SMS/payment URL, сохранение `&amount={{amount}}` в payment query template, PostgreSQL URL и FCM credentials без лишней пустой `FIREBASE_SERVICE_ACCOUNT_JSON`.
- Добавлен `docs/vps_required_inputs.md`: короткий список данных, которые нужно получить для финального cutover на VPS.
- Добавлен `docs/vps_inputs.template.env` и `scripts/check_vps_inputs.sh`: перед выдачей сервера можно заполнить host/user/domain/DNS/HTTPS/SMS/payment/FCM/admin данные и машинно проверить, что нет placeholder-ов, URL внешние `https://`, payment template содержит `{{paymentId}}`/`{{amount}}`, SMS template содержит нужные поля, а Firebase credentials используются только для FCM push.
- `scripts/check_vps_inputs.sh` теперь сверяет `MTAXI_API_DOMAIN` с host внутри `MTAXI_PUBLIC_BASE_URL`, чтобы перед VPS не уехали разные домены API и публичного backend URL.
- Release backend URL guard закреплен execution-тестом: backend test реально запускает `bash`, принимает внешний `https://` URL и отклоняет `http`, localhost, emulator, private/LAN, CGNAT и IPv6 local адреса.
- Release guard для Flutter и shell-скриптов усилен: production `MTAXI_BACKEND_URL` теперь отклоняет не только localhost/LAN IPv4, но и link-local `169.254.*`, CGNAT `100.64.0.0/10`, private `172.16.0.0/12` и локальные/private IPv6 (`::1`, `fc*`, `fd*`, `fe80::/10`).
- Production smoke/monitor используют тот же строгий local/private URL guard, поэтому `MTAXI_SMOKE_EXPECT_STORE=postgres` и `MTAXI_MONITOR_EXPECT_STORE=postgres` не пройдут на внутреннем `http://`/private endpoint вместо публичного HTTPS backend.
- Добавлен `scripts/check_vps_postdeploy.sh`: один read-only gate после запуска VPS, который берет `MTAXI_PUBLIC_BASE_URL` из `server/.env` или проверяет локальный `http://127.0.0.1:8080`, требует PostgreSQL store, запускает `deploy/ops_check.sh` и `npm run smoke`.
- Production preflight использует тот же расширенный local/private URL guard для `MTAXI_PUBLIC_BASE_URL`, `MTAXI_PAYMENT_URL_TEMPLATE` и `MTAXI_SMS_HTTP_URL`, чтобы боевой env не прошел с внутренним API, SMS или payment endpoint.
- Production preflight теперь подставляет реальный `MTAXI_PUBLIC_BASE_URL` в платежный шаблон `{{publicBaseUrl}}`, поэтому return/callback payment URL не пройдет проверку, если API URL остался локальным или `http://`.
- `mtaxi-monitor.service` больше не содержит жестко зашитый `https://api.mtaxi.kz`: URL берется из `MTAXI_PUBLIC_BASE_URL` в `/opt/mtaxi/server/.env`, а `MTAXI_MONITOR_BASE_URL` остается явным override для ручной проверки другого endpoint; `npm run validate:production-deploy` теперь ловит устаревший monitor service до запуска на VPS.
- `npm run validate:production-deploy` теперь полностью проверяет `mtaxi-monitor.service`: service должен ждать backend/network, запускаться как `oneshot` из `/opt/mtaxi/server`, читать optional `/opt/mtaxi/server/.env`, использовать `MTAXI_PUBLIC_BASE_URL` по умолчанию и требовать `MTAXI_MONITOR_EXPECT_STORE=postgres`.
- Добавлен scheduled backup для VPS: `mtaxi-backup.service` требует `mtaxi-backend.service` и запускает `npm run db:backup` внутри backend-контейнера через `docker compose exec`, с `MTAXI_BACKUP_DIR=/var/backups/mtaxi` и `MTAXI_BACKUP_RETENTION_DAYS=30`; production compose монтирует `/var/backups/mtaxi` в контейнер, `mtaxi-backup.timer` выполняет backup ежедневно в 03:30.
- Production preflight теперь валидирует `MTAXI_BACKUP_RETENTION_DAYS` как неотрицательное целое число, чтобы backup-служба не падала уже после деплоя из-за плохого env.
- Restore получил безопасный dry-run режим: `MTAXI_RESTORE_DRY_RUN=true npm run db:restore -- manifest.json` проверяет manifest, читаемость PostgreSQL dump через `pg_restore --list` и upload-архив через `tar -tzf`, без восстановления базы и без очистки папки uploads.
- Rollback в VPS-чеклисте переведен на запуск restore внутри backend-контейнера через `docker compose run --rm`, чтобы `DATABASE_URL=...@postgres...`, `pg_restore` и `/var/backups/mtaxi` работали в production Docker-сети, а не зависели от host-окружения.
- Backup-скрипт теперь применяет тот же строгий контракт, что и preflight: `MTAXI_BACKUP_RETENTION_DAYS` должен быть неотрицательным целым числом, дробные и отрицательные значения отклоняются до запуска retention-очистки.
- Backup manifest теперь помечается `type: mtaxi-backup` и `version: 1`, а restore отклоняет manifest другого типа, чтобы не восстановить случайный JSON вместо резервной копии MTaxi.
- Backup manifest теперь содержит SHA-256 для PostgreSQL dump и upload-архива; добавлена команда `npm run db:verify-backup -- manifest.json`, которая проверяет manifest, пути внутри backup-папки и совпадение хэшей до rollback.
- Добавлен `scripts/check_backend_transfer_steps.sh`: короткая инструкция переноса `docs/backend_transfer_steps.md` теперь проверяется отдельным gate, входит в readiness, source archive и VPS handoff manifest.
- `docs/backend_transfer_steps.md` теперь прямо показывает `./scripts/latest_vps_handoff.sh`, чтобы перед VPS брать последний уже проверенный handoff-пакет, а не старую папку из `output`.
- `scripts/latest_vps_handoff.sh` теперь закреплен в `READINESS_REPORT.json` и VPS handoff manifest как отдельное доказательство готовности.
- Добавлен `scripts/check_local_flutter_commands.sh`: readiness теперь реально проверяет, что локальные Flutter-команды выводят web URL `127.0.0.1/localhost`, а Android emulator получает `10.0.2.2`.
- `deploy/predeploy_check.sh` теперь перед VPS-запуском также проверяет `docs/backend_transfer_steps.md` и локальные Flutter-команды, чтобы передача на сервер не прошла без актуальной инструкции подключения клиента к backend.
- `deploy/predeploy_check.sh` теперь после `npm ci --omit=dev` запускает `scripts/check_backend_env_contract.sh`, чтобы VPS predeploy не прошел с устаревшим или dev-oriented env-шаблоном.
- `docs/backend_transfer_steps.md` теперь явно показывает безопасную остановку локального Docker-backend через `./scripts/stop_local_backend.sh` и предупреждает не использовать `docker compose down -v`, если нужно сохранить PostgreSQL/uploads volume.
- Добавлен `scripts/check_output_handoffs.sh`: перед переносом можно проверить все `output/mtaxi-vps-handoff-*` и увидеть, нет ли битых пакетов рядом с последним валидным.
- VPS handoff теперь содержит `HANDOFF_QUICK_COMMANDS.md` с готовыми командами upload/check/extract/start/build для VPS, чтобы перенос можно было выполнить по короткому copy-paste сценарию после выдачи сервера.
- Добавлен `scripts/print_vps_upload_commands.sh`: локально печатает команды `ssh/scp` для загрузки последнего проверенного handoff на VPS и проверки checksum/verifier уже на сервере.
- Добавлен `scripts/check_vps_handoff_extract_smoke.sh`: локально распаковывает handoff во временную папку и проверяет, что ключевые transfer/predeploy helper-скрипты есть и запускаются из распакованного проекта.
- Добавлен `scripts/check_vps_cutover_dry_run.sh`: одна локальная команда проверяет последний handoff, печать upload-команд и smoke распаковки перед реальной загрузкой на VPS.
- Добавлен `docs/vps_cutover_runbook.md` и `scripts/check_vps_cutover_runbook.sh`: короткий боевой runbook переноса на VPS теперь проверяется readiness gate и входит в handoff/source archive.
