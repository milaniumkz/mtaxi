# MTaxi VPS required inputs

Для финального переноса на полноценный backend нужны эти данные.
Можно заполнить шаблон `docs/vps_inputs.template.env` и проверить его командой
`./scripts/check_vps_inputs.sh path/to/vps_inputs.env`.

Главный мелкий план переноса: `docs/backend_migration_small_steps.md`.

## Обязательные данные

1. VPS SSH доступ: host, user, способ входа по ключу.
2. Домен API, например `api.mtaxi.kz`; он должен совпадать с host в `MTAXI_PUBLIC_BASE_URL`.
3. DNS доступ, чтобы направить домен на VPS.
4. HTTPS способ: nginx + сертификат или другой reverse proxy.
5. Node.js 20+ и `npm` для predeploy/validate/ops tooling.
6. Проверка входа по паролю и порядок ручного восстановления через администратора. SMS-провайдер не нужен.
7. Payment provider:
   - HTTPS redirect URL template с `{{paymentId}}` и `{{amount}}`;
   - callback secret;
   - callback URL, который нужно указать у провайдера.
8. FCM credentials только для push:
   - `FIREBASE_SERVICE_ACCOUNT_JSON`, или
   - путь `GOOGLE_APPLICATION_CREDENTIALS` на VPS.
9. Первый админ:
   - телефон;
   - пароль;
   - имя;
   - город.

## Команды после получения VPS

Сначала локально проверить и собрать пакет передачи:

```bash
./scripts/check_backend_migration_ready.sh
./scripts/check_backend_migration_small_steps.sh
./scripts/check_vps_inputs.sh path/to/vps_inputs.env
./scripts/check_local_backend_contract.sh http://127.0.0.1:8080
./scripts/print_local_flutter_commands.sh http://127.0.0.1:8080
./scripts/package_vps_handoff.sh
./scripts/check_output_handoffs.sh
./scripts/verify_vps_handoff.sh output/mtaxi-vps-handoff-YYYYMMDD-HHMMSS
./scripts/print_vps_upload_commands.sh
```

Папка handoff содержит исходники, checksum, `HANDOFF_MANIFEST.json`,
`HANDOFF_STATUS.md`, `HANDOFF_QUICK_COMMANDS.md`, `READINESS_REPORT.json`,
`API_CONTRACT.json`, `ENV_CONTRACT.json`, `verify_vps_handoff.sh` и
`DEPLOY_NEXT_STEPS.md`.
Для короткого copy-paste сценария открыть
`HANDOFF_QUICK_COMMANDS.md`.
После распаковки исходников первым открыть `docs/backend_migration_small_steps.md`,
затем `docs/backend_transfer_steps.md`.
Других файлов в handoff-папке быть не должно: verifier остановит установку при
лишнем файле, чтобы на VPS не попали старые данные.
Упаковка запускает проверку и через bundled `verify_vps_handoff.sh`, чтобы на
VPS проверялся тот же скрипт, который передан вместе с архивом.
Firebase в этом пакете разрешен только для FCM push.

На VPS загрузить содержимое handoff-папки, проверить и распаковать исходники:

```bash
mkdir -p /tmp/mtaxi-handoff
cd /tmp/mtaxi-handoff
chmod +x verify_vps_handoff.sh
shasum -a 256 -c mtaxi-source-*.tar.gz.sha256
./verify_vps_handoff.sh .
sudo mkdir -p /opt/mtaxi
sudo tar -xzf mtaxi-source-*.tar.gz -C /opt/mtaxi
cd /opt/mtaxi
```

После распаковки исходников на VPS:

```bash
./deploy/vps_prereq_check.sh
./scripts/check_backend_migration_small_steps.sh
./scripts/check_backend_transfer_steps.sh
set -a
. /tmp/mtaxi-vps-inputs.env
set +a
./scripts/generate_production_env.sh server/.env
./deploy/predeploy_check.sh
sudo ./deploy/install_vps_units.sh
sudo systemctl enable --now mtaxi-backend.service mtaxi-backup.timer mtaxi-monitor.timer
./scripts/check_vps_postdeploy.sh
MTAXI_OPS_BASE_URL=https://api.mtaxi.kz ./deploy/ops_check.sh
MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/check_release_ready.sh
```

`check_vps_postdeploy.sh` берет `MTAXI_PUBLIC_BASE_URL` из `server/.env`, требует PostgreSQL store и запускает read-only `ops_check` плюс `npm run smoke`. После этих проверок можно собирать web/APK/iOS release на новый backend.
