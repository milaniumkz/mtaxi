# Push для Firebase mtaxi-52990

В коде выбран проект `mtaxi-52990`. Android/iOS уже используют FCM-токены,
серверную очередь, обновление токенов и обработку нажатий на уведомления.
Добавлены регистрация браузерного токена по кнопке в админке и service worker.
Firebase остаётся только транспортом push: авторизация и данные работают через
Node.js backend и PostgreSQL.

## Выполненная настройка

Доступ к проекту через сервисную учётную запись проверен. В Firebase созданы:

- Android `1:842255533405:android:753efd6c37706cdf4a14b4`;
- iOS `1:842255533405:ios:ea6412793cdf08e84a14b4`;
- Web `1:842255533405:web:e6ef5608cf028db14a14b4`.

Конфигурации скачаны в игнорируемые файлы Android/iOS и
`.firebase-web-config.local.json`. Серверный API FCM успешно выполнил
`validate_only` запрос: авторизация и право отправки работают, сообщения
пользователям не отправлялись. Получение на устройстве этим не проверяется.

Повторное получение конфигураций без создания дубликатов:

```bash
NODE_USE_ENV_PROXY=1 node server/scripts/configure_firebase_apps.js
```

Проверка через тот же Firebase Admin SDK, что использует backend:

```bash
NODE_USE_ENV_PROXY=1 node server/scripts/check_firebase_fcm.js
```

Она прошла успешно; этот скрипт всегда использует dry run.
В облачной среде используется Node 24 и настроенный HTTPS proxy. Скрипт читает
готовый `FIREBASE_SERVICE_ACCOUNT_JSON` из среды, не сохраняет приватный ключ.
Новый приватный ключ для этой настройки создавать не нужно.

## Что осталось

### Android

В [настройках проекта](https://console.firebase.google.com/project/mtaxi-52990/settings/general)
Android-приложение с package name `com.milanium.mtaxi` уже зарегистрировано.
`google-services.json` сохранён в `android/app/google-services.json`.
Файл исключён из Git. Для FCM не требуется подключать Firebase Auth/Firestore.

### iOS

iOS-приложение с bundle ID `com.milanium.mtaxi` зарегистрировано.
`GoogleService-Info.plist` сохранён в `ios/Runner/GoogleService-Info.plist`.
В Firebase → Project settings → Cloud Messaging добавьте APNs authentication key
из Apple Developer. У приложения в Xcode должны быть Push Notifications и
Background Modes → Remote notifications. Проверяется на подписанной сборке и
реальном устройстве; для сборки нужны macOS/Xcode.

### Веб-админка

Публичная конфигурация зарегистрированного Web app уже сохранена в
`.firebase-web-config.local.json` (исключён из Git). Она содержит настоящие
`apiKey`, `appId`, `projectId`, `messagingSenderId` этого проекта.
В Cloud Messaging → Web Push certificates создайте/возьмите публичный VAPID key
и добавьте как `vapidKey` в тот же JSON. Приватный сервисный ключ сюда не входит.

Сборка:

```bash
bash scripts/build_firebase_web.sh /path/to/firebase-web-config.json https://YOUR-REAL-BACKEND
```

Скрипт формирует игнорируемый `web/firebase-config.js` и согласованные параметры
Flutter. Движок включается в сборку без внешнего CDN.
Содержимое `build/web` разместите на HTTPS-хостинге с SPA fallback на index.html.
`firebase-messaging-sw.js` и `firebase-config.js` должны отдаваться как JavaScript,
без подмены на HTML и без бессрочного кэширования.
В админке нажмите «Включить push-уведомления» и разрешите уведомления браузеру.
Кнопка появляется в сборке с полной конфигурацией Firebase/VAPID.
Отказ в разрешении не блокирует обычную работу админки.

### Backend

Рабочий ключ уже предоставлен через защищённую конфигурацию облачной среды.
На хостинге backend передайте его **через секреты окружения** как прямое значение
`FIREBASE_SERVICE_ACCOUNT_JSON` либо смонтируйте секретный файл и укажите путь
в `GOOGLE_APPLICATION_CREDENTIALS`. Не отправляйте приватный ключ в чат или Git.
Proxy-placeholder вместо JSON не подходит: SDK должен прочитать настоящий JSON
локально. Учётной записи требуется право отправки FCM-сообщений этого проекта.

Настройки backend после предоставления ключа:

```dotenv
FIREBASE_PROJECT_ID=mtaxi-52990
# В этой облачной среде Node 24 должен использовать настроенный proxy:
NODE_USE_ENV_PROXY=1
MTAXI_FCM_ENABLED=true
MTAXI_ALLOW_SIMULATED_PUSH=false
```

После этого выполните `npm run preflight --prefix server` и перезапустите backend.
Проверки FCM в preflight прошли. Полный production preflight в текущей среде
не проходит без конфигурации реального HTTPS backend, CORS, PostgreSQL и SMS;
это отдельные требования публикации, не ошибка доступа к Firebase.
Сервер и preflight отклоняют сервисный ключ другого проекта. Скрипт
`start_local_json_backend.sh` намеренно включает simulated push для обычных
локальных тестов; для настоящего FCM запускайте backend напрямую с флагами выше.

## Проверка настоящей доставки

1. Установить новые сборки Android/iOS и войти; разрешить уведомления.
2. Войти в HTTPS-админку и включить push. Проверить регистрацию токенов Web,
   Android и iOS в backend.
3. Через «Рассылка уведомлений» отправить тестовое уведомление только выбранному
   тестовому пользователю. Проверить журнал доставки и отсутствие simulated-local.
4. Проверить foreground, фон и открытие по нажатию на каждом устройстве.
5. Создать тестовую заявку Kaspi: уведомление должно приходить только
   администратору. В вебе нажатие ведёт в раздел платежей.
6. Проверить выход/смену пользователя: уведомления прошлого аккаунта не должны
   доставляться новому пользователю того же браузера.

Серверная авторизация и dry run FCM подтверждены. Настоящее получение push
ещё не проверено: нужны VAPID для веба, APNs для iOS и тестовые устройства.
В этой среде нет авторизованной пользовательской сессии Firebase Console или
Apple Developer. Открытый Firebase Management API, использованный для
регистрации приложений, не предоставляет управления VAPID/APNs. Добавьте эти
ключи в Console → Project settings → Cloud Messaging; пароль и коды входа
в чат передавать не нужно. Затем выполните проверку доставки выше.
