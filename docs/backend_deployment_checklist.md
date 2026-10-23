# MTaxi backend deployment checklist

Цель: поднять полноценный backend на арендном сервере. Firebase остается только для FCM push.

Перед финальным cutover подготовить входные данные из `docs/vps_required_inputs.md`.
Для проверки заполните `docs/vps_inputs.template.env` в отдельный файл и запустите
`./scripts/check_vps_inputs.sh path/to/vps_inputs.env`.

## 1. Сервер

- Ubuntu/Debian VPS, 2 CPU, 2-4 GB RAM минимум.
- Домен для API, например `https://api.mtaxi.kz`.
- Открыть только `80/443`, SSH оставить по ключу.
- Рекомендуемый запуск: Docker Compose.
- Node.js 20 или новее и `npm` нужны для predeploy/validate/ops tooling; backend в production запускается через Docker Compose.

## 2. Env

Взять шаблон:

```bash
cp server/.env.example server/.env
```

Обязательно заменить:

```bash
MTAXI_PUBLIC_BASE_URL=https://api.mtaxi.kz
MTAXI_ALLOW_LOCAL_PUBLIC_BASE_URL=false
MTAXI_ALLOW_INSECURE_PUBLIC_BASE_URL=false
MTAXI_CORS_ORIGINS=https://mtaxi-user-vzqw6a.web.app,https://mtaxi-controls.web.app
MTAXI_TOKEN_SECRET=replace-with-long-random-secret
MTAXI_AUTH_RATE_LIMIT_WINDOW_SEC=60
MTAXI_AUTH_RATE_LIMIT_MAX=20
MTAXI_STORE=postgres
DATABASE_URL=postgres://mtaxi:strong-password@postgres:5432/mtaxi
POSTGRES_PASSWORD=strong-password
MTAXI_PAYMENT_CALLBACK_SECRET=replace-with-payment-callback-secret
MTAXI_UPLOAD_DIR=/var/lib/mtaxi/uploads
MTAXI_UPLOAD_CACHE_MAX_AGE_SEC=2592000
MTAXI_BACKUP_RETENTION_DAYS=30
MTAXI_ACCESS_LOGS=true
MTAXI_MAINTENANCE_INTERVAL_SEC=30
MTAXI_PENDING_ORDER_TTL_MIN=15
MTAXI_MAINTENANCE_ORDER_LIMIT=100
MTAXI_MAINTENANCE_PUSH_LIMIT=100
MTAXI_PAYMENT_PROVIDER=redirect
MTAXI_PAYMENT_URL_TEMPLATE=https://pay-provider.example/start?invoice={{paymentId}}&amount={{amount}}
MTAXI_SMS_PROVIDER=disabled
MTAXI_SMS_DEV_RETURN_CODE=false
MTAXI_ALLOW_LOCAL_SMS=false
MTAXI_FCM_ENABLED=true
MTAXI_ALLOW_SIMULATED_PUSH=false
```

Можно сгенерировать production env с реальными внешними URL и FCM credentials:

```bash
MTAXI_PUBLIC_BASE_URL=https://api.mtaxi.kz \
MTAXI_PAYMENT_URL_TEMPLATE='https://pay-provider.example/start?invoice={{paymentId}}&amount={{amount}}' \
GOOGLE_APPLICATION_CREDENTIALS=/etc/mtaxi/firebase-service-account.json \
./scripts/generate_production_env.sh server/.env
```

Если уже заполнен и проверен `vps_inputs.env`, загрузить его перед generator:

```bash
set -a
. /tmp/mtaxi-vps-inputs.env
set +a
./scripts/generate_production_env.sh server/.env
```

Скрипт сам генерирует `MTAXI_TOKEN_SECRET`, `POSTGRES_PASSWORD` и `MTAXI_PAYMENT_CALLBACK_SECRET`, но все равно нужно проверить payment, admin и FCM значения перед запуском.

`MTAXI_PUBLIC_BASE_URL` на сервере должен быть `https://...`; `http://...` разрешен только для локальной разработки через отдельный dev-флаг.
Все значения `replace-with...`, `change-this...` и `mtaxi_change_me` перед запуском заменить на реальные секреты.
При `NODE_ENV=production` preflight не пропустит включенные dev-флаги: `MTAXI_ALLOW_LOCAL_PUBLIC_BASE_URL`, `MTAXI_ALLOW_INSECURE_PUBLIC_BASE_URL`, `MTAXI_ALLOW_LOCAL_SMS`, `MTAXI_ALLOW_LOCAL_PAYMENT`, `MTAXI_ENABLE_LEGACY_CREATE_TOKEN`, `MTAXI_ALLOW_SIMULATED_PUSH`.
Локальную страницу оплаты `/local-payment/:paymentId` не использовать в production; нужен реальный `MTAXI_PAYMENT_PROVIDER=redirect`.
`MTAXI_PAYMENT_URL_TEMPLATE` должен быть внешним `https://` URL, не localhost/LAN/private (`10.*`, `100.64.0.0/10`, `169.254.*`, `172.16.0.0/12`, `192.168.*`, `::1`, `fc*`, `fd*`, `fe80::/10`).
Если шаблон содержит `{{publicBaseUrl}}`, итоговая ссылка оплаты проверяется с реальным `MTAXI_PUBLIC_BASE_URL`; локальный или `http://` API URL не пройдет preflight.

Вход и регистрация используют номер телефона и пароль. SMS-провайдер не нужен.
Оставьте `MTAXI_SMS_PROVIDER=disabled`. Старые SMS-эндпоинты всегда отклоняют запросы.
Восстановление доступа выполняет администратор после проверки личности.

Если включаем реальные push:

```bash
MTAXI_FCM_ENABLED=true
FIREBASE_SERVICE_ACCOUNT_JSON='{"project_id":"...","client_email":"...","private_key":"..."}'
```

Firebase credentials нужны только для FCM push. Не подключать Firebase Auth, Firestore, Cloud Functions, SMS или Storage к production backend.
Production preflight не пропустит Firebase env для данных/Auth/Storage/Functions/SMS (`FIREBASE_DATABASE_URL`, `FIRESTORE_*`, `FIREBASE_STORAGE_*`, `FIREBASE_FUNCTIONS_*`, `FIREBASE_AUTH_*` и похожие). Разрешены только FCM credentials: `FIREBASE_SERVICE_ACCOUNT_JSON` или `GOOGLE_APPLICATION_CREDENTIALS`.
`FIREBASE_SERVICE_ACCOUNT_JSON` или файл `GOOGLE_APPLICATION_CREDENTIALS` должен содержать полный service account JSON с `project_id`, `client_email` и PEM `private_key` вида `-----BEGIN PRIVATE KEY-----...-----END PRIVATE KEY-----`; короткая строка вместо ключа preflight не пройдет.

В production нельзя оставлять `MTAXI_FCM_ENABLED=false`: это отключит реальную доставку push и оставит только локальную симуляцию. `MTAXI_ALLOW_SIMULATED_PUSH=true` разрешен только для локального compose/dev; при `NODE_ENV=production` preflight завершится ошибкой.

## 3. Docker запуск

Перед передачей проекта на VPS одним локальным gate проверить backend, shell-скрипты и source archive:

```bash
./scripts/check_backend_migration_ready.sh
```

Чтобы сразу подготовить папку для передачи на сервер:

```bash
./scripts/package_vps_handoff.sh
```

Она создаст новую пустую `output/mtaxi-vps-handoff-*` с source archive, `.sha256`, `HANDOFF_MANIFEST.json`, `HANDOFF_STATUS.md`, `READINESS_REPORT.json`, `API_CONTRACT.json`, `ENV_CONTRACT.json`, `verify_vps_handoff.sh` и коротким `DEPLOY_NEXT_STEPS.md`.
`READINESS_REPORT.json` фиксирует текущие 99%, backend-only архитектуру, FCM-only Firebase и список внешних условий для финальных 100%.
`API_CONTRACT.json` фиксирует все backend callable-функции и сверку вызовов клиента с `server/src/call_router.js`.
`ENV_CONTRACT.json` фиксирует production env: PostgreSQL, парольный вход без SMS, реальный payment provider и Firebase только для FCM push.
Отдельно отчет можно проверить командой: `./scripts/verify_backend_migration_status.sh READINESS_REPORT.json`.
Если указать свою папку, она должна быть пустой: упаковщик не собирает handoff поверх старых файлов.
Упаковщик проверяет папку дважды: текущим verifier из исходников и bundled verifier из самой handoff-папки, который будет запускаться на VPS. Проверить готовую папку можно отдельно:

```bash
./scripts/verify_vps_handoff.sh output/mtaxi-vps-handoff-YYYYMMDD-HHMMSS
```

Verifier принимает только ожидаемый состав handoff-папки и падает при любом лишнем файле.

На самом VPS перед установкой проверить prerequisites:

```bash
./deploy/vps_prereq_check.sh
```

Скрипт ничего не устанавливает: проверяет Docker Compose, systemd, curl/tar/shasum, nginx/reverse proxy, свободное место и предупреждает по занятым `80/443`.

Из корня проекта:

```bash
docker compose -f docker-compose.production.yml up -d --build
docker compose -f docker-compose.production.yml logs -f backend
```

Если нужно перенести проект на VPS архивом, собрать только исходники без тяжелых папок и секретов:

```bash
./scripts/package_source_archive.sh
```

Скрипт исключает `build`, `node_modules`, `ios/Pods`, `server/.env`, локальные данные, uploads, backups и private keys. По умолчанию архив не должен превышать 500 MiB. Рядом создается `.sha256` checksum для проверки после загрузки на VPS.
После создания автоматически запускается `scripts/verify_source_archive.sh`: проверяется размер, наличие ключевых backend/deploy/client файлов и отсутствие секретов/тяжелых папок.

`docker-compose.production.yml` использует `server/.env`, `NODE_ENV=production`, PostgreSQL volume и backend healthcheck `/readyz`.
Пароль PostgreSQL должен быть задан в `server/.env` как `POSTGRES_PASSWORD`; `DATABASE_URL` должен использовать тот же пароль.
`docker-compose.backend.yml` оставлен как локальный compose (`NODE_ENV=development`) с local payment/simulated push.
Локальная dev-проверка при необходимости: `docker compose -f docker-compose.backend.yml up -d --build`.

Для автозапуска на VPS установить systemd/nginx-шаблоны:

```bash
sudo ./deploy/install_vps_units.sh
sudo systemctl enable --now mtaxi-backend.service
sudo systemctl enable --now mtaxi-backup.timer
sudo systemctl enable --now mtaxi-monitor.timer
```

Шаблоны рассчитаны на путь проекта `/opt/mtaxi`. Если проект лежит в другом месте, заменить `WorkingDirectory` и `/opt/mtaxi/...` в service-файлах до запуска `install_vps_units.sh`; установщик не продолжит установку с другим путем, чтобы не поставить сломанные service-файлы.
Основные systemd-файлы: `deploy/systemd/mtaxi-backend.service`, `deploy/systemd/mtaxi-backup.service`, `deploy/systemd/mtaxi-backup.timer`, `deploy/systemd/mtaxi-monitor.service`, `deploy/systemd/mtaxi-monitor.timer`.
Установщик также создает `/var/backups/mtaxi` с правами `0750`; если задаете другой `MTAXI_BACKUP_DIR`, он должен совпадать с volume в `docker-compose.production.yml` и `mtaxi-backup.service`.

Проверка:

```bash
curl http://127.0.0.1:8080/readyz
curl -X POST http://127.0.0.1:8080/call/getStoreHealth -H 'Content-Type: application/json' -d '{}'
cd server && npm run smoke
```

Перед production запуском backend сам выполняет:

```bash
npm run db:apply-schema
npm run preflight
```

После release-сборки `scripts/build_backend_release.sh` дополнительно проверяет готовый артефакт:
web проверяется по `build/web/main.dart.js`, APK/IPA проверяются по строкам внутри бинарников. В артефакте должен быть production `MTAXI_BACKEND_URL`, а `localhost`/`127.0.0.1`/`10.0.2.2` не допускаются.

Перед первым запуском контейнеров можно проверить production compose и `server/.env` без подключения к базе:

```bash
./deploy/predeploy_check.sh
```

Скрипт запускает `./deploy/vps_prereq_check.sh`, выполняет `npm ci --omit=dev`, проверяет `./scripts/check_backend_env_contract.sh`, запускает `npm run validate:production-deploy`, проверяет наличие production-файлов/systemd/nginx install-шаблонов, backup/restore скриптов, исполняемых `scripts/check_release_ready.sh` и `scripts/build_backend_release.sh`, запрещает `NODE_ENV=development` в `server/.env` и, если доступны команды, выполняет `docker compose -f docker-compose.production.yml config` и nginx syntax check.

В `server/.env` не ставить `NODE_ENV=development`; валидатор пропустит только пустое значение или `NODE_ENV=production`.

Перед ручным запуском на VPS можно отдельно проверить именно production-режим:

```bash
cd server
npm run preflight:production
```

Если backend запускают напрямую через `NODE_ENV=production npm start`, entrypoint тоже выполнит preflight до открытия порта.

Если `MTAXI_SEED_ADMIN_ON_START=true`, контейнер также выполнит:

```bash
npm run seed:admin
```

## 4. Первый админ

Задать:

```bash
MTAXI_ADMIN_PHONE=+77000000000
MTAXI_ADMIN_PASSWORD=strong-admin-password
MTAXI_ADMIN_NAME=Администратор
MTAXI_ADMIN_CITY=Белоусовка
```

Телефон первого админа указывать в формате `+77000000000` или `77000000000`; placeholder `+70000000000` заменить обязательно.

Для ручного запуска:

```bash
cd server
npm run seed:admin
```

## 5. Перенос данных

Если нужно перенести локальный JSON-store:

```bash
cd server
MTAXI_JSON_FILE=/path/to/local-db.json npm run db:migrate-json
```

Перед сохранением миграция сама сверяет количество записей в PostgreSQL с исходным JSON и делает `ROLLBACK`, если целевых записей меньше. В конце она печатает отчет вида `users=..., orders=..., payments=...` по источнику и PostgreSQL, чтобы быстро проверить перенос на VPS.

Потом проверить:

```bash
curl -X POST https://api.mtaxi.kz/call/getStoreHealth -H 'Content-Type: application/json' -d '{}'
cd server && MTAXI_SMOKE_BASE_URL=https://api.mtaxi.kz MTAXI_SMOKE_EXPECT_STORE=postgres npm run smoke
```

В ответе должен быть PostgreSQL store, `schemaVersion` и `schemaAppliedAt`; при `MTAXI_SMOKE_EXPECT_STORE=postgres` smoke упадет, если `schemaVersion` пустой.
Для публичной проверки используйте только `https://...`; `http://127.0.0.1:8080` подходит только для локального smoke на самом сервере.
Smoke всегда проверяет `livez`, `readyz`, `getStoreHealth`, `getRuntimeSettings` и `getBackendArchitectureStatus`.
Для расширенной проверки добавьте реальные тестовые учетные записи: `MTAXI_SMOKE_ADMIN_PHONE/MTAXI_SMOKE_ADMIN_PASSWORD`, `MTAXI_SMOKE_PASSENGER_PHONE/MTAXI_SMOKE_PASSENGER_PASSWORD`, `MTAXI_SMOKE_DRIVER_PHONE/MTAXI_SMOKE_DRIVER_PASSWORD`. Тогда smoke дополнительно проверит `passwordLogin`, `getSessionBootstrap`, `adminListUsers`, `getMoneyStats`, `listCityTariffs` и `listIntercityRoutes`.

## 6. Мониторинг

После деплоя можно поставить read-only проверку в cron. Она проверяет API, PostgreSQL-схему, runtime-настройки, backend-only архитектуру, а при админском логине еще пользователей, денежную статистику и push-журнал.

```bash
cd server
MTAXI_MONITOR_BASE_URL=https://api.mtaxi.kz MTAXI_MONITOR_EXPECT_STORE=postgres npm run monitor
```

Расширенный вариант:

```bash
MTAXI_MONITOR_BASE_URL=https://api.mtaxi.kz \
MTAXI_MONITOR_EXPECT_STORE=postgres \
MTAXI_MONITOR_ADMIN_PHONE=77000000000 \
MTAXI_MONITOR_ADMIN_PASSWORD='password' \
npm run monitor
```

Для production URL использовать `https://...`. Локальный `http://127.0.0.1:8080` допустим только на самом сервере.
`mtaxi-monitor.service` по умолчанию берет URL из `MTAXI_PUBLIC_BASE_URL` в `/opt/mtaxi/server/.env`; если нужно проверить другой endpoint, задайте `MTAXI_MONITOR_BASE_URL` отдельным override.

Быстрая диагностика VPS без изменения данных:

```bash
MTAXI_OPS_BASE_URL=http://127.0.0.1:8080 MTAXI_OPS_EXPECT_STORE=postgres ./deploy/ops_check.sh
```

Скрипт проверяет наличие production-файлов, status systemd/timers, последний backup manifest в `/var/backups/mtaxi`, возраст backup по `MTAXI_OPS_BACKUP_MAX_AGE_HOURS` (целое число, по умолчанию 36 часов), SHA-256 backup-файлов через `npm run db:verify-backup`, наличие `docker compose`, `docker compose ps`, `livez`, `readyz`, `getStoreHealth` и `npm run monitor`.

После первого запуска backend на VPS выполнить общий postdeploy-gate:

```bash
./scripts/check_vps_postdeploy.sh
```

По умолчанию он берет `MTAXI_PUBLIC_BASE_URL` из `server/.env`; если env еще не создан, проверяет `http://127.0.0.1:8080` на самом сервере. Скрипт требует PostgreSQL store, запускает `deploy/ops_check.sh` и `npm run smoke`. Для ручного override:

```bash
MTAXI_POSTDEPLOY_BASE_URL=https://api.mtaxi.kz ./scripts/check_vps_postdeploy.sh
```

## 7. HTTPS reverse proxy

Готовый nginx-шаблон лежит в `deploy/nginx/mtaxi-api.conf`. На VPS заменить `api.mtaxi.kz` и SSL-пути на реальные.

Быстрая установка:

```bash
sudo cp deploy/nginx/mtaxi-api.conf /etc/nginx/sites-available/mtaxi-api.conf
sudo ln -s /etc/nginx/sites-available/mtaxi-api.conf /etc/nginx/sites-enabled/mtaxi-api.conf
sudo nginx -t
sudo systemctl reload nginx
```

Nginx/Traefik должен проксировать API на backend:

```nginx
proxy_set_header Host $host;
proxy_set_header X-Forwarded-Proto https;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Host $host;
proxy_pass http://127.0.0.1:8080;
```

Публичные ссылки оплаты и файлов должны открываться через `MTAXI_PUBLIC_BASE_URL`.

## 8. Flutter release

Собирать только с реальным API. Безопасный способ:

```bash
MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/check_release_ready.sh
MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/build_backend_release.sh web
MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/build_backend_release.sh apk
MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/build_backend_release.sh ios
```

`check_release_ready.sh` проверяет remote backend smoke и Flutter backend-only guard без сборки. `build_backend_release.sh` перед сборкой сам запускает эту проверку и не даст собрать release на `localhost`, `10.0.2.2`, LAN/private (`10.*`, `100.64.0.0/10`, `169.254.*`, `172.16.0.0/12`, `192.168.*`, `::1`, `fc*`, `fd*`, `fe80::/10`) или `http://`.

Ручной APK-командой можно так:

```bash
flutter build apk --release \
  --dart-define=MTAXI_BACKEND_URL=https://api.mtaxi.kz \
  --dart-define=MTAXI_REQUIRE_REMOTE_BACKEND=true
```

Для iOS/App Store использовать те же `dart-define`.

`MTAXI_REQUIRE_REMOTE_BACKEND=true` не даст случайно выпустить сборку на `localhost`, `127.0.0.1`, `10.0.2.2`, LAN/private backend или публичный `http://` API. Для release нужен только внешний `https://` backend.

## 9. Smoke test после запуска

Проверить по порядку:

1. `GET /health` возвращает `200`.
1. `getStoreHealth` показывает PostgreSQL.
1. `getRuntimeSettings` отвечает через backend.
1. `getBackendArchitectureStatus` показывает `backend-only`, Firebase только `FCM transport`.
1. Админ входит по паролю.
1. Пассажир входит по паролю или ставит пароль, если его не было.
1. Водитель входит по паролю.
1. Тарифы поселков и межгород (`listCityTariffs`, `listIntercityRoutes`) отвечают авторизованному пользователю.
1. Пассажир создает заказ.
1. Заказ появляется у водителя в радиусе.
1. Водитель принимает заказ.
1. Второй водитель не может взять тот же заказ.
1. Пассажир видит активный заказ после перезапуска приложения.
1. Водитель меняет статусы заказа.
1. Отмена и завершение заказа очищают активный заказ у пассажира и водителя.
1. Фото профиля/регистрации загружаются и открываются по публичной ссылке.
1. Загрузка неизвестных типов файлов отклоняется `UPLOAD_TYPE_NOT_ALLOWED`.
1. Загрузка файла с поддельным MIME отклоняется `UPLOAD_SIGNATURE_INVALID`.
1. Пополнение создает платеж, callback применяет баланс один раз.
1. Push token сохраняется, тестовый push уходит через FCM.
1. Чат поддержки работает у пользователя и админа.

## 10. Backup и rollback

Перед обновлением:

```bash
docker compose -f docker-compose.production.yml exec -T \
  -e MTAXI_BACKUP_DIR=/var/backups/mtaxi \
  -e MTAXI_BACKUP_RETENTION_DAYS=30 \
  backend npm run db:backup
```

Скрипт создает PostgreSQL dump, архив upload-папки и manifest `mtaxi-backup-*.json` с `type: mtaxi-backup`, именами файлов и SHA-256.
Старые backup-файлы удаляются по `MTAXI_BACKUP_RETENTION_DAYS`, по умолчанию 30 дней; production preflight проверяет, что значение является неотрицательным целым числом.
Автоматический backup на VPS включает `mtaxi-backup.timer`: каждый день в 03:30 он запускает `mtaxi-backup.service` и пишет файлы в `/var/backups/mtaxi`.
`mtaxi-backup.service` требует `mtaxi-backend.service` и запускает `npm run db:backup` внутри backend-контейнера через `docker compose exec`, поэтому `DATABASE_URL=...@postgres...` работает через docker-сеть. `docker-compose.production.yml` монтирует `/var/backups/mtaxi` внутрь контейнера.

Проверить таймер:

```bash
systemctl list-timers mtaxi-backup.timer
systemctl start mtaxi-backup.service
docker compose -f docker-compose.production.yml exec -T \
  backend npm run db:verify-backup -- /var/backups/mtaxi/mtaxi-backup-YYYY-MM-DD.json
```

Rollback:

```bash
docker compose -f docker-compose.production.yml down
docker compose -f docker-compose.production.yml up -d postgres
docker compose -f docker-compose.production.yml run --rm \
  -e MTAXI_RESTORE_DRY_RUN=true \
  backend npm run db:restore -- /var/backups/mtaxi/mtaxi-backup-YYYY-MM-DD.json
docker compose -f docker-compose.production.yml run --rm \
  -e MTAXI_RESTORE_CONFIRM=YES \
  backend npm run db:restore -- /var/backups/mtaxi/mtaxi-backup-YYYY-MM-DD.json
docker compose -f docker-compose.production.yml up -d --build
```

Restore запускается внутри backend-контейнера через `docker compose run --rm`, поэтому `DATABASE_URL=...@postgres...`, `pg_restore` и backup-файлы из `/var/backups/mtaxi` работают в той же Docker-сети, что и production backend.
Dry-run проверяет manifest, читаемость PostgreSQL dump через `pg_restore --list` и upload-архив через `tar -tzf`, без восстановления базы и без очистки `MTAXI_UPLOAD_DIR`.
`npm run db:verify-backup -- manifest.json` дополнительно проверяет, что manifest ссылается только на файлы внутри backup-папки и что SHA-256 dump/uploads совпадают.
Restore очищает текущую `MTAXI_UPLOAD_DIR` и распаковывает upload-архив прямо в эту папку.

## 11. Cutover

- DNS API домена указывает на сервер.
- HTTPS сертификат активен.
- `npm run preflight:production` проходит без ошибок.
- `MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/check_release_ready.sh` проходит без ошибок.
- Web и APK/iOS собраны с `MTAXI_BACKEND_URL=https://api.mtaxi.kz` и `MTAXI_REQUIRE_REMOTE_BACKEND=true`.
- Firebase используется только для FCM.
