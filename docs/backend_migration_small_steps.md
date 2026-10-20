# MTaxi backend migration small steps

Цель: перевести MTaxi на полноценный backend. Пока реальный сервер не выдан,
использовать локальный backend. Firebase разрешен только для FCM push.

## Правило архитектуры

1. Firebase Auth не использовать.
2. Firestore не использовать.
3. Firebase Cloud Functions не использовать.
4. Firebase Storage не использовать.
5. SMS не отправлять с клиента.
6. Firebase оставить только как FCM transport для push-уведомлений.

## Локальный этап

1. Открыть корень проекта.
2. Быстро посмотреть текущую готовность и последний пакет переноса:
   ```bash
   ./scripts/check_backend_migration_quick_status.sh
   ```
2. Проверить весь backend-gate:
   ```bash
   ./scripts/check_backend_migration_ready.sh
   ```
3. Проверить контракт backend API:
   ```bash
   ./scripts/check_backend_api_contract.sh
   ```
4. Проверить production env-контракт:
   ```bash
   ./scripts/check_backend_env_contract.sh
   ```
5. Проверить client backend config:
   ```bash
   ./scripts/check_client_backend_config.sh
   ```
6. Запустить локальный PostgreSQL backend:
   ```bash
   ./scripts/start_local_backend.sh
   ```
7. Если Docker недоступен, запустить JSON fallback:
   ```bash
   ./scripts/start_local_json_backend.sh
   ```
8. Проверить контракт локального backend:
   ```bash
   ./scripts/check_local_backend_contract.sh http://127.0.0.1:8080
   ```
9. Прогнать локальный функциональный smoke:
   ```bash
   ./scripts/check_local_functional_smoke.sh
   ```
10. Вывести команды подключения Flutter:
   ```bash
   ./scripts/print_local_flutter_commands.sh http://127.0.0.1:8080
   ```
11. Открыть локальный runbook:
   ```bash
   ./scripts/check_local_backend_runbook.sh
   ```
12. Запустить web против локального backend:
   ```bash
   flutter run -d chrome --dart-define=MTAXI_BACKEND_URL=http://127.0.0.1:8080
   ```
13. Запустить Android emulator против локального backend:
   ```bash
   flutter run -d emulator --dart-define=MTAXI_BACKEND_URL=http://10.0.2.2:8080
   ```
14. Проверить вход, регистрацию, профиль, создание заказа, ленту водителя,
   принятие заказа, отмену, завершение, чат, платежи и админку.
15. Остановить локальный backend без удаления данных:
    ```bash
    ./scripts/stop_local_backend.sh
    ```

## Подготовка к VPS

1. Получить SSH host/user.
2. Получить домен API, например `api.mtaxi.kz`.
3. Направить DNS домена на VPS.
4. Подготовить HTTPS через nginx/reverse proxy.
5. Получить SMS provider URL, method, headers/token и body template.
6. Получить payment redirect URL template и callback secret.
7. Подготовить FCM service account только для push.
8. Подготовить первого админа: телефон, пароль, имя, город.
9. Заполнить файл из шаблона:
   ```bash
   cp docs/vps_inputs.template.env /tmp/mtaxi-vps-inputs.env
   ```
10. Проверить входные данные:
    ```bash
    ./scripts/check_vps_inputs.sh /tmp/mtaxi-vps-inputs.env
    ```

## Пакет передачи

1. Собрать handoff:
   ```bash
   ./scripts/package_vps_handoff.sh
   ```
2. Найти последний проверенный пакет:
   ```bash
   ./scripts/latest_vps_handoff.sh
   ```
   Быстрый указатель на него: `output/LATEST_MTAXI_VPS_HANDOFF.txt`.
3. Проверить все handoff-папки:
   ```bash
   ./scripts/check_output_handoffs.sh
   ```
4. Посмотреть старые сломанные handoff без удаления:
   ```bash
   ./scripts/cleanup_output_handoffs.sh output --dry-run
   ```
   Удалять только после проверки:
   ```bash
   ./scripts/cleanup_output_handoffs.sh output --delete
   ```
5. Проверить выбранный пакет:
   ```bash
   ./scripts/verify_vps_handoff.sh output/mtaxi-vps-handoff-YYYYMMDD-HHMMSS
   ```
6. Проверить распаковку как на VPS:
   ```bash
   ./scripts/check_vps_handoff_extract_smoke.sh output/mtaxi-vps-handoff-YYYYMMDD-HHMMSS
   ```
7. Запустить общий dry-run перед загрузкой:
   ```bash
   ./scripts/check_vps_cutover_dry_run.sh output/mtaxi-vps-handoff-YYYYMMDD-HHMMSS
   ```
8. Напечатать команды загрузки на VPS:
   ```bash
   ./scripts/print_vps_upload_commands.sh output/mtaxi-vps-handoff-YYYYMMDD-HHMMSS
   ```

## Установка на VPS

1. Загрузить handoff в `/tmp/mtaxi-handoff`.
2. На VPS проверить checksum и manifest:
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
5. Сгенерировать production env:
   ```bash
   set -a
   . /tmp/mtaxi-vps-inputs.env
   set +a
   ./scripts/generate_production_env.sh server/.env
   ```
6. Запустить predeploy:
   ```bash
   ./deploy/predeploy_check.sh
   ```
7. Установить systemd units:
   ```bash
   sudo ./deploy/install_vps_units.sh
   ```
8. Запустить backend, backup и monitor:
   ```bash
   sudo systemctl enable --now mtaxi-backend.service mtaxi-backup.timer mtaxi-monitor.timer
   ```
9. Проверить production backend:
   ```bash
   ./scripts/check_vps_postdeploy.sh
   ```

## Подключение release

1. Проверить release-gate против production URL:
   ```bash
   MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/check_release_ready.sh
   ```
2. Собрать web release:
   ```bash
   MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/build_backend_release.sh web
   ```
3. Собрать APK release:
   ```bash
   MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/build_backend_release.sh apk
   ```
4. Собрать iOS release:
   ```bash
   MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/build_backend_release.sh ios
   ```

## Готовность

1. Локально готово, когда проходит `./scripts/check_backend_migration_ready.sh`.
2. Пакет готов к передаче, когда проходит `./scripts/check_vps_cutover_dry_run.sh`.
3. Production готов, когда проходит `./scripts/check_vps_postdeploy.sh`.
4. Финальные 100% ставить только после реального VPS, домена, env и production smoke.
