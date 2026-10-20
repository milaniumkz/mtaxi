# MTaxi backend transfer steps

Цель: перенести MTaxi на отдельный backend. Firebase остается только для FCM push-уведомлений.

Главный мелкий план по шагам: `docs/backend_migration_small_steps.md`.

## Что уже готово локально

1. Backend работает через `server/` и endpoint `POST /call/:name`.
2. Данные backend идут через JSON-store локально и PostgreSQL на сервере.
3. Firebase Auth, Firestore, Cloud Functions, Storage и SMS убраны из backend-режима.
4. Push-уведомления оставлены через FCM.
5. Клиент подключается к backend через `MTAXI_BACKEND_URL`.
6. Release-сборки защищены от локального URL через `MTAXI_REQUIRE_REMOTE_BACKEND=true`.
7. Есть Docker/VPS, nginx, systemd, backup, restore, monitor, smoke и preflight scripts.

## Локальная проверка перед VPS

1. Открыть корень проекта.
2. Запустить полный gate:
   ```bash
   ./scripts/check_backend_migration_ready.sh
   ```
3. Проверить мелкий план переноса:
   ```bash
   ./scripts/check_backend_migration_small_steps.sh
   ```
4. Проверить входные данные VPS:
   ```bash
   ./scripts/check_vps_inputs.sh path/to/vps_inputs.env
   ```
5. Собрать пакет передачи:
   ```bash
   ./scripts/package_vps_handoff.sh
   ```
6. Проверить готовую папку:
   ```bash
   ./scripts/verify_vps_handoff.sh output/mtaxi-vps-handoff-YYYYMMDD-HHMMSS
   ```
7. Перед загрузкой на VPS вывести последний проверенный пакет:
   ```bash
   ./scripts/latest_vps_handoff.sh
   ```
   Тот же путь автоматически сохраняется в `output/LATEST_MTAXI_VPS_HANDOFF.txt`.
8. Проверить, что в `output` нет битых handoff-папок:
   ```bash
   ./scripts/check_output_handoffs.sh
   ```
9. Посмотреть старые сломанные handoff без удаления:
   ```bash
   ./scripts/cleanup_output_handoffs.sh output --dry-run
   ```
10. Вывести готовые команды загрузки handoff на VPS:
   ```bash
   ./scripts/print_vps_upload_commands.sh
   ```
11. Проверить production env-контракт:
   ```bash
   ./scripts/check_backend_env_contract.sh
   ```
12. Проверить, что handoff распакуется как на VPS:
   ```bash
   ./scripts/check_vps_handoff_extract_smoke.sh
   ```
13. Запустить общий локальный dry-run перед реальным VPS:
   ```bash
   ./scripts/check_vps_cutover_dry_run.sh
   ```
14. Открыть короткий runbook реального переноса:
   ```bash
   ./scripts/check_vps_cutover_runbook.sh
   ```

## Локальное подключение приложения

1. Запустить локальный backend с PostgreSQL через Docker:
   ```bash
   ./scripts/start_local_backend.sh
   ```
2. Если Docker недоступен, запустить fallback backend на JSON-store:
   ```bash
   ./scripts/start_local_json_backend.sh
   ```
3. В отдельном терминале проверить контракт backend перед запуском приложения:
   ```bash
   ./scripts/check_local_backend_contract.sh http://127.0.0.1:8080
   ```
4. Вывести готовые команды подключения Flutter:
   ```bash
   ./scripts/print_local_flutter_commands.sh http://127.0.0.1:8080
   ```
5. Для web/Desktop подключить приложение к локальному backend:
   ```bash
   flutter run -d chrome --dart-define=MTAXI_BACKEND_URL=http://127.0.0.1:8080
   ```
6. Для Android emulator использовать адрес хоста `10.0.2.2`:
   ```bash
   flutter run -d emulator --dart-define=MTAXI_BACKEND_URL=http://10.0.2.2:8080
   ```
7. В локальном режиме не включать `MTAXI_REQUIRE_REMOTE_BACKEND=true`; этот флаг нужен только для production release.
8. Локально SMS, платежи и push работают в dev/simulated режиме; реальные SMS, платежи и FCM включаются только на production backend.
9. Остановить локальный Docker-backend без удаления PostgreSQL/uploads volume:
   ```bash
   ./scripts/stop_local_backend.sh
   ```
   Не использовать `docker compose down -v`, если нужно сохранить локальные данные.

## Что нужно от VPS

1. SSH-доступ.
2. Домен API, например `api.mtaxi.kz`.
3. DNS на IP VPS.
4. HTTPS через nginx/reverse proxy.
5. Docker Compose, systemd, Node.js 20+ и `npm`.
6. PostgreSQL через production compose.
7. Реальный SMS provider.
8. Реальная ссылка оплаты и callback secret.
9. FCM service account только для push.
10. Первый админ: телефон, пароль, имя, город.

## Установка на VPS

1. Загрузить handoff-папку в `/tmp/mtaxi-handoff`.
2. Проверить checksum и manifest:
   ```bash
   cd /tmp/mtaxi-handoff
   chmod +x verify_vps_handoff.sh
   shasum -a 256 -c mtaxi-source-*.tar.gz.sha256
   ./verify_vps_handoff.sh .
   ```
3. Распаковать исходники:
   ```bash
   sudo mkdir -p /opt/mtaxi
   sudo tar -xzf mtaxi-source-*.tar.gz -C /opt/mtaxi
   cd /opt/mtaxi
   ```
4. Проверить VPS:
   ```bash
   ./deploy/vps_prereq_check.sh
   ```
5. Заполнить `/tmp/mtaxi-vps-inputs.env` из шаблона:
   ```bash
   cp docs/vps_inputs.template.env /tmp/mtaxi-vps-inputs.env
   ./scripts/check_vps_inputs.sh /tmp/mtaxi-vps-inputs.env
   ```
6. Создать production env:
   ```bash
   set -a
   . /tmp/mtaxi-vps-inputs.env
   set +a
   ./scripts/generate_production_env.sh server/.env
   ```
7. Запустить predeploy:
   ```bash
   ./deploy/predeploy_check.sh
   ```
8. Установить и запустить systemd:
   ```bash
   sudo ./deploy/install_vps_units.sh
   sudo systemctl enable --now mtaxi-backend.service mtaxi-backup.timer mtaxi-monitor.timer
   ```
9. Проверить production backend:
   ```bash
   ./scripts/check_vps_postdeploy.sh
   ```

## Подключение приложения

1. После успешного `check_vps_postdeploy.sh` собрать web/APK/iOS только с боевым HTTPS backend:
   ```bash
   MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/build_backend_release.sh web
   MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/build_backend_release.sh apk
   MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/build_backend_release.sh ios
   ```
2. Проверить release:
   ```bash
   MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/check_release_ready.sh
   ```

## Запрещено

1. Не возвращать Firebase Auth.
2. Не возвращать Firestore.
3. Не возвращать Firebase Cloud Functions.
4. Не возвращать Firebase Storage.
5. Не отправлять SMS напрямую из клиента.
6. Не собирать production app с `localhost`, `127.0.0.1`, `10.0.2.2` или HTTP backend.

## Готовность

Локально готово примерно 99%. Финальные 100% можно подтвердить только после реального VPS, домена, production env и успешного `check_vps_postdeploy.sh`.
