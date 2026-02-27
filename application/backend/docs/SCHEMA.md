# Backend Schema Reference

PostgreSQL and Redis schema used by the LDAP 2FA backend.

## PostgreSQL

Tables are defined in `app/database/models.py` and created/updated on startup
via `app/database/connection.py` (create_all plus migrations).

### verification_tokens

Stores email/phone verification tokens (signup and profile change flows).

| Column | Type | Nullable | Description |
| ------ | ---- | -------- | ----------- |
| id | UUID | NO | Primary key |
| user_id | UUID | NO | FK to users.id |
| token_type | VARCHAR(10) | NO | `email`, `phone`, `eml_chg`, `phn_chg`, `password_reset` |
| token | VARCHAR(255) | NO | UUID (email/eml_chg) or 6-digit code (phone/phn_chg) |
| expires_at | TIMESTAMPTZ | NO | Expiration time |
| used | BOOLEAN | NO | Whether token was consumed |
| created_at | TIMESTAMPTZ | NO | Creation time |
| target_value | VARCHAR(255) | YES | For `eml_chg`: new email; for `phn_chg`: country_code + pipe + number |

- `eml_chg` / `phn_chg`: profile email/phone change; verification link or code
  is sent to the new address/number; after verification, `target_value` is
  applied to the user record.
- Migration: `target_value` is added automatically on startup if missing
  (see `_migrate_verification_tokens_target_value` in `connection.py`).

### users

User accounts (see `app/database/models.py` for full definition). No schema
change for profile email/phone change; new values are written after
verification via existing columns.

### Other tables

- `groups`, `user_groups`, etc.: see `app/database/models.py`.

## Redis

Redis is used for ephemeral data only. No schema change was required for
profile email/phone change (those flows use PostgreSQL `verification_tokens`).

### Key layout

- **SMS OTP (login or resend)**: `{REDIS_KEY_PREFIX}{username}`
  - Value: JSON `{"code": "123456", "phone_number": "+15551234567"}`
  - TTL: from `sms_code_expiry_seconds`
- **Login challenge**: `{REDIS_KEY_PREFIX}login_challenge:{challenge_token}`
  - Value: JSON with challenge data
  - TTL: per login flow

Profile phone change verification codes are stored in PostgreSQL
(`verification_tokens` with `token_type = 'phn_chg'`), not in Redis.
