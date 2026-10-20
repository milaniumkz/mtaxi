# MTaxi local backend runbook

Цель: проверять приложение на локальном backend до получения VPS.
Firebase в этом режиме разрешен только для FCM push; локально push выключен или simulated.

## Быстрый старт

1. Открыть корень проекта.
2. Проверить общий статус:
   ```bash
   ./scripts/check_backend_migration_quick_status.sh
   ```
3. Проверить полный gate при изменениях backend:
   ```bash
   ./scripts/check_backend_migration_ready.sh
   ```
4. Запустить backend с PostgreSQL через Docker:
   ```bash
   ./scripts/start_local_backend.sh
   ```
5. Если Docker недоступен, запустить JSON fallback:
   ```bash
   ./scripts/start_local_json_backend.sh
   ```

## Проверка backend

1. Проверить health:
   ```bash
   curl -fsS http://127.0.0.1:8080/readyz
   ```
2. Проверить контракт API:
   ```bash
   ./scripts/check_local_backend_contract.sh http://127.0.0.1:8080
   ```
3. Прогнать функциональный smoke на одноразовой локальной базе:
   ```bash
   ./scripts/check_local_functional_smoke.sh
   ```
4. Напечатать команды Flutter:
   ```bash
   ./scripts/print_local_flutter_commands.sh http://127.0.0.1:8080
   ```

## Запуск приложения

1. Web/Desktop:
   ```bash
   flutter run -d chrome --dart-define=MTAXI_BACKEND_URL=http://127.0.0.1:8080
   ```
2. Android emulator:
   ```bash
   flutter run -d emulator --dart-define=MTAXI_BACKEND_URL=http://10.0.2.2:8080
   ```
3. В локальном режиме не включать `MTAXI_REQUIRE_REMOTE_BACKEND=true`.
4. Для release использовать только внешний `https://` backend.

## Что проверить руками

1. Вход существующего пользователя по паролю.
2. Регистрация нового пассажира через SMS.
3. Установка пароля после регистрации.
4. Профиль пассажира и смена фото.
5. Создание заказа пассажиром.
6. Восстановление активного заказа после обновления страницы.
7. Лента водителя.
8. Принятие заказа водителем.
9. Отмена заказа пассажиром.
10. Завершение заказа водителем.
11. Пополнение баланса в локальном payment режиме.
12. Чат поддержки.
13. Админка: пользователи, заказы, платежи, настройки, audit logs.

## Остановка

1. Остановить Docker backend без удаления данных:
   ```bash
   ./scripts/stop_local_backend.sh
   ```
2. Не использовать `docker compose down -v`, если нужно сохранить локальную PostgreSQL базу и uploads.

## Запрещено локально и в production

1. Не возвращать Firebase Auth.
2. Не возвращать Firestore.
3. Не возвращать Firebase Cloud Functions.
4. Не возвращать Firebase Storage.
5. Не отправлять SMS напрямую из клиента.
