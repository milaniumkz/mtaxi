# MTaxi

Flutter-приложение такси (Android, iOS, Web) и backend Node.js с JSON для разработки и PostgreSQL для production. Firebase используется для push-уведомлений.

## Облачная разработка

Откройте **Code → Codespaces → Create codespace on main**. Конфигурация `.devcontainer` установит Flutter stable, Node.js и зависимости. Установка требует доступа к сети.

Запустите backend с временными тестовыми данными:

```bash
MTAXI_TOKEN_SECRET="$(openssl rand -hex 32)" MTAXI_PAYMENT_PROVIDER=local MTAXI_ALLOW_LOCAL_PAYMENT=true bash scripts/start_local_json_backend.sh
```

Во втором терминале:

```bash
flutter run -d web-server --web-hostname=0.0.0.0 --web-port=3000 --dart-define=MTAXI_BACKEND_URL=https://YOUR-FORWARDED-8080-URL
```

Подставьте адрес порта 8080 из вкладки Ports. Для доступа браузера к API в Codespaces может потребоваться публичная видимость порта 8080: используйте только тестовые данные и временное окружение. Откройте порт 3000 в браузере.

iOS-сборка требует macOS/Xcode. Android release требует Android SDK и ключ подписи.

## Секреты и production

Ключи Apple, ключи подписи, реальные `.env`, Firebase service account, базы и загрузки исключены из Git и остаются на исходном компьютере. Нужные значения передавайте через Codespaces Secrets или секреты среды backend. Данные переносите отдельно в защищённое хранилище.

Шаблон: `server/.env.example`. Для production создайте `server/.env`, заполните значения и настройте PostgreSQL, SMS, платежи и FCM.

Подробнее: [backend](server/README.md), [локальный запуск](docs/local_backend_runbook.md), [развёртывание](docs/backend_deployment_checklist.md), [архитектура](ARCHITECTURE_STATUS.md).

## Проверки

```bash
npm ci --prefix server
npm test --prefix server
flutter pub get
flutter test
```

Firebase/Maps: передайте web-ключ через `--dart-define=FIREBASE_WEB_API_KEY=...`; замените `YOUR_GOOGLE_MAPS_API_KEY` в `web/index.html` собственным ключом с ограничениями доменов. Для мобильных сборок восстановите `android/app/google-services.json` и `ios/Runner/GoogleService-Info.plist` из консоли Firebase (файлы исключены из Git). Исходные настройки сохранены локально в `~/.codex/private-backups/mtaxi-before-public`.
