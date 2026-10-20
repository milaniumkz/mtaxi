-- MTaxi backend PostgreSQL schema.
-- Firebase remains only as FCM transport; all app data belongs in backend DB.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS schema_migrations (
  version text PRIMARY KEY,
  description text NOT NULL DEFAULT '',
  applied_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO schema_migrations(version, description)
VALUES ('2026-07-22-backend-base', 'MTaxi backend PostgreSQL base schema')
ON CONFLICT (version) DO NOTHING;

CREATE TABLE IF NOT EXISTS users (
  id text PRIMARY KEY DEFAULT ('u_' || gen_random_uuid()::text),
  phone text UNIQUE NOT NULL,
  password_hash text,
  display_name text NOT NULL DEFAULT '',
  role text NOT NULL DEFAULT 'passenger',
  role_state text NOT NULL DEFAULT 'PASSENGER',
  active_mode text NOT NULL DEFAULT 'passenger',
  preferred_client_mode text NOT NULL DEFAULT 'passenger',
  is_driver boolean NOT NULL DEFAULT false,
  status_driver text NOT NULL DEFAULT '',
  driver_registration_status text NOT NULL DEFAULT '',
  driver_online boolean NOT NULL DEFAULT false,
  blocked boolean NOT NULL DEFAULT false,
  vip boolean NOT NULL DEFAULT false,
  balance numeric(12,2) NOT NULL DEFAULT 0,
  active_passenger_order_id text,
  active_driver_order_id text,
  has_active_passenger_order boolean NOT NULL DEFAULT false,
  has_active_driver_order boolean NOT NULL DEFAULT false,
  city text NOT NULL DEFAULT '',
  lat double precision,
  lng double precision,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS users_role_idx ON users(role);
CREATE INDEX IF NOT EXISTS users_driver_status_idx ON users(is_driver, status_driver);
CREATE INDEX IF NOT EXISTS users_active_orders_idx
  ON users(has_active_passenger_order, has_active_driver_order);

CREATE TABLE IF NOT EXISTS sms_codes (
  id text PRIMARY KEY,
  phone text NOT NULL,
  sms_code text NOT NULL DEFAULT '',
  sms_code_hash text NOT NULL DEFAULT '',
  provider text NOT NULL DEFAULT 'local',
  status text NOT NULL DEFAULT 'sent',
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz
);

ALTER TABLE sms_codes
  ADD COLUMN IF NOT EXISTS sms_code_hash text NOT NULL DEFAULT '';

CREATE INDEX IF NOT EXISTS sms_codes_phone_created_idx
  ON sms_codes(phone, created_at DESC);

CREATE TABLE IF NOT EXISTS orders (
  id text PRIMARY KEY DEFAULT ('order_' || gen_random_uuid()::text),
  user_id text REFERENCES users(id) ON DELETE SET NULL,
  driver_id text REFERENCES users(id) ON DELETE SET NULL,
  type text NOT NULL DEFAULT 'taxi',
  status integer NOT NULL DEFAULT 0,
  ot text NOT NULL DEFAULT '',
  kuda text NOT NULL DEFAULT '',
  ot_lat double precision,
  ot_lng double precision,
  kuda_lat double precision,
  kuda_lng double precision,
  price numeric(12,2) NOT NULL DEFAULT 0,
  accepted_commission numeric(12,2) NOT NULL DEFAULT 0,
  comment text NOT NULL DEFAULT '',
  cancelled_by text NOT NULL DEFAULT '',
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  accepted_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz
);

CREATE INDEX IF NOT EXISTS orders_status_idx ON orders(status);
CREATE INDEX IF NOT EXISTS orders_user_status_idx ON orders(user_id, status);
CREATE INDEX IF NOT EXISTS orders_driver_status_idx ON orders(driver_id, status);
CREATE INDEX IF NOT EXISTS orders_created_at_idx ON orders(created_at DESC);

CREATE TABLE IF NOT EXISTS payments (
  id text PRIMARY KEY DEFAULT ('payment_' || gen_random_uuid()::text),
  user_id text REFERENCES users(id) ON DELETE SET NULL,
  payment_id text UNIQUE,
  status text NOT NULL DEFAULT 'pending',
  amount numeric(12,2) NOT NULL DEFAULT 0,
  idempotency_key text,
  provider text NOT NULL DEFAULT 'local',
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS payments_user_created_idx ON payments(user_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS payments_user_idempotency_idx
  ON payments(user_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL AND idempotency_key <> '';

CREATE TABLE IF NOT EXISTS withdrawals (
  id text PRIMARY KEY DEFAULT ('withdrawal_' || gen_random_uuid()::text),
  user_id text REFERENCES users(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'pending',
  amount numeric(12,2) NOT NULL DEFAULT 0,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz
);

CREATE INDEX IF NOT EXISTS withdrawals_status_created_idx ON withdrawals(status, created_at DESC);

CREATE TABLE IF NOT EXISTS ledger (
  id text PRIMARY KEY DEFAULT ('ledger_' || gen_random_uuid()::text),
  user_id text REFERENCES users(id) ON DELETE SET NULL,
  order_id text REFERENCES orders(id) ON DELETE SET NULL,
  payment_id text,
  type text NOT NULL,
  source text NOT NULL DEFAULT 'backend',
  amount numeric(12,2) NOT NULL DEFAULT 0,
  balance_before numeric(12,2),
  balance_after numeric(12,2),
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ledger_user_created_idx ON ledger(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS ledger_type_created_idx ON ledger(type, created_at DESC);

ALTER TABLE ledger
  DROP CONSTRAINT IF EXISTS ledger_payment_id_fkey;

CREATE TABLE IF NOT EXISTS support_chats (
  id text PRIMARY KEY DEFAULT ('chat_' || gen_random_uuid()::text),
  user_id text REFERENCES users(id) ON DELETE SET NULL,
  admin_id text REFERENCES users(id) ON DELETE SET NULL,
  support_chat_key text UNIQUE,
  last_message text NOT NULL DEFAULT '',
  unread_for_admin integer NOT NULL DEFAULT 0,
  unread_for_user integer NOT NULL DEFAULT 0,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS support_messages (
  id text PRIMARY KEY DEFAULT ('message_' || gen_random_uuid()::text),
  chat_id text REFERENCES support_chats(id) ON DELETE CASCADE,
  user_id text REFERENCES users(id) ON DELETE SET NULL,
  text text NOT NULL DEFAULT '',
  image_url text NOT NULL DEFAULT '',
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS support_messages_chat_created_idx
  ON support_messages(chat_id, created_at);

CREATE TABLE IF NOT EXISTS fcm_tokens (
  id text PRIMARY KEY DEFAULT ('fcm_' || gen_random_uuid()::text),
  user_id text REFERENCES users(id) ON DELETE CASCADE,
  token text UNIQUE NOT NULL,
  platform text NOT NULL DEFAULT '',
  enabled boolean NOT NULL DEFAULT true,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS fcm_tokens_user_idx ON fcm_tokens(user_id);

CREATE TABLE IF NOT EXISTS notifications (
  id text PRIMARY KEY DEFAULT ('notification_' || gen_random_uuid()::text),
  dedupe_key text UNIQUE,
  event_type text NOT NULL,
  title text NOT NULL DEFAULT '',
  body text NOT NULL DEFAULT '',
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notification_deliveries (
  id text PRIMARY KEY DEFAULT ('delivery_' || gen_random_uuid()::text),
  notification_id text REFERENCES notifications(id) ON DELETE CASCADE,
  token_id text REFERENCES fcm_tokens(id) ON DELETE SET NULL,
  user_id text REFERENCES users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'queued',
  attempts integer NOT NULL DEFAULT 0,
  last_error text NOT NULL DEFAULT '',
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS notification_deliveries_status_idx
  ON notification_deliveries(status, created_at);

CREATE TABLE IF NOT EXISTS push_delivery_acks (
  id text PRIMARY KEY DEFAULT ('ack_' || gen_random_uuid()::text),
  user_id text REFERENCES users(id) ON DELETE CASCADE,
  notification_id text NOT NULL DEFAULT '',
  event_type text NOT NULL,
  order_id text,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE push_delivery_acks
  ADD COLUMN IF NOT EXISTS notification_id text NOT NULL DEFAULT '';

UPDATE push_delivery_acks
SET notification_id = COALESCE(NULLIF(data->>'notificationId', ''), id)
WHERE notification_id = '';

ALTER TABLE push_delivery_acks
  DROP CONSTRAINT IF EXISTS push_delivery_acks_user_id_event_type_order_id_key;

CREATE UNIQUE INDEX IF NOT EXISTS push_delivery_acks_user_notification_event_idx
  ON push_delivery_acks(user_id, event_type, notification_id);

CREATE TABLE IF NOT EXISTS city_prices (
  id text PRIMARY KEY DEFAULT ('city_' || gen_random_uuid()::text),
  title text UNIQUE NOT NULL,
  price_day numeric(12,2) NOT NULL DEFAULT 0,
  price_night numeric(12,2) NOT NULL DEFAULT 0,
  delivery_price numeric(12,2) NOT NULL DEFAULT 0,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS intercity_routes (
  id text PRIMARY KEY DEFAULT ('route_' || gen_random_uuid()::text),
  ot text NOT NULL,
  kuda text NOT NULL,
  tarif numeric(12,2) NOT NULL DEFAULT 0,
  com numeric(6,2) NOT NULL DEFAULT 0,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS intercity_routes_points_idx ON intercity_routes(ot, kuda);

CREATE TABLE IF NOT EXISTS app_settings (
  key text PRIMARY KEY,
  value jsonb NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS content_documents (
  collection text PRIMARY KEY,
  fields jsonb NOT NULL DEFAULT '{}'::jsonb,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS generic_documents (
  collection text NOT NULL,
  id text NOT NULL,
  fields jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (collection, id)
);

CREATE TABLE IF NOT EXISTS audit_logs (
  id text PRIMARY KEY DEFAULT ('audit_' || gen_random_uuid()::text),
  action text NOT NULL,
  target text NOT NULL DEFAULT '',
  admin_id text REFERENCES users(id) ON DELETE SET NULL,
  admin_phone text NOT NULL DEFAULT '',
  before_data jsonb,
  after_data jsonb,
  extra jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS audit_logs_created_idx ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS audit_logs_action_idx ON audit_logs(action);
