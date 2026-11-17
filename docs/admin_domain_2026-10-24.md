# Отдельная админка — 24 октября 2026

Админка: https://mtaxi-controls.89.126.192.185.sslip.io/
Пассажирская версия: https://mtaxi.89.126.192.185.sslip.io/

Отдельный hostname на том же VPS использует существующий Flutter web и уже предусмотренный режим `isWebAdminHost` (`mtaxi-controls.*`). На административном hostname скрыта регистрация, допускается только администратор; backend-проверки прав сохраняются. Два origin имеют независимые localStorage и сессии, поэтому можно пользоваться обеими версиями в одном браузере одновременно.

Настроен отдельный nginx vhost, HTTPS Let's Encrypt, явный CORS allowlist с двумя origin. Сертификат действителен до 2027-01-22; включён certbot.timer и deploy hook nginx reload. Фактическое продление по истечении срока не проверялось; timer и hook настроены. Существующий backend image переиспользован, база и APK не менялись. Конфигурация сохранена в `/var/backups/mtaxi/admin-domain-20261024T084751Z`.

Успешная настройка: https://github.com/milaniumkz/mtaxi/actions/runs/40079418637
Повторная идемпотентная настройка продления: https://github.com/milaniumkz/mtaxi/actions/runs/40079537446
Первая попытка сертификата вернула HTTP 403 на ACME challenge; права webroot исправлены на 755, добавлена предварительная проверка доступа, повторная выдача успешна.

Chromium с включённой TLS verification: открыт admin hostname, выполнен настоящий вход через API основного origin (CORS passed), отрисован дашборд. В том же browser context открыта пассажирская версия: токен и пользователь администратора отсутствуют на её origin, административная сессия сохранена. Ошибок JavaScript 0. Заказы/балансы не менялись. Логин и пароль администратора сохранены. Артефакты: `output/admin-domain-2026-10-24/verification.json` и скриншоты.
