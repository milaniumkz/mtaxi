# MTaxi VPS cutover runbook

Цель: выполнить перенос MTaxi на полноценный backend на VPS. Firebase остается только для FCM push.

## 1. Локально перед загрузкой

```bash
./scripts/check_backend_migration_ready.sh
./scripts/package_vps_handoff.sh
./scripts/latest_vps_handoff.sh
./scripts/check_vps_cutover_dry_run.sh
./scripts/print_vps_upload_commands.sh
```

## 2. Загрузка handoff на VPS

```bash
export MTAXI_VPS_USER=root
export MTAXI_VPS_HOST=YOUR_VPS_IP_OR_DOMAIN
./scripts/print_vps_upload_commands.sh
```

Выполнить напечатанные `ssh` и `scp` команды.

## 3. Проверка handoff на VPS

```bash
cd /tmp/mtaxi-handoff
chmod +x verify_vps_handoff.sh
shasum -a 256 -c mtaxi-source-*.tar.gz.sha256
./verify_vps_handoff.sh .
```

## 4. Распаковка backend

```bash
sudo rm -rf /opt/mtaxi
sudo mkdir -p /opt/mtaxi
sudo tar -xzf mtaxi-source-*.tar.gz -C /opt/mtaxi
cd /opt/mtaxi
```

## 5. Данные VPS и production env

```bash
./deploy/vps_prereq_check.sh
cp docs/vps_inputs.template.env /tmp/mtaxi-vps-inputs.env
# заполнить реальные VPS, domain, SMS, payment, FCM, admin значения
./scripts/check_vps_inputs.sh /tmp/mtaxi-vps-inputs.env
set -a
. /tmp/mtaxi-vps-inputs.env
set +a
./scripts/generate_production_env.sh server/.env
```

## 6. Запуск backend

```bash
./deploy/predeploy_check.sh
sudo ./deploy/install_vps_units.sh
sudo systemctl enable --now mtaxi-backend.service mtaxi-backup.timer mtaxi-monitor.timer
./scripts/check_vps_postdeploy.sh
```

## 7. Сборка приложений после smoke

```bash
MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/build_backend_release.sh web
MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/build_backend_release.sh apk
MTAXI_BACKEND_URL=https://api.mtaxi.kz ./scripts/build_backend_release.sh ios
```

## 8. Rollback

```bash
./deploy/ops_check.sh
npm run db:verify-backup -- /var/backups/mtaxi/LATEST_MANIFEST.json
MTAXI_RESTORE_DRY_RUN=true npm run db:restore -- /var/backups/mtaxi/LATEST_MANIFEST.json
```

Боевой restore запускать только после проверки backup manifest и подтверждения владельца.

## Нельзя

1. Не возвращать Firebase Auth.
2. Не возвращать Firestore.
3. Не возвращать Cloud Functions.
4. Не возвращать Firebase Storage.
5. Не отправлять SMS напрямую из клиента.
6. Не собирать release с localhost, `10.0.2.2` или LAN backend URL.
