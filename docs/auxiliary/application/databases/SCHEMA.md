# Backend Schema Reference

PostgreSQL, OpenLDAP, and Redis schema used by the LDAP 2FA backend.

## PostgreSQL

Tables are defined in `app/database/models.py` and created/updated on startup
via `app/database/connection.py` (create_all plus migrations).

### users

User accounts. Created at signup (`POST /api/auth/signup`) or by admin-seed
job. LDAP user is created only when admin activates (status PENDING/COMPLETE
to ACTIVE).

| Column | Type | Nullable | Set where | Description |
| ------ | ---- | -------- | --------- | ----------- |
| id | UUID | NO | Auto | Primary key |
| username | VARCHAR(64) | NO | Signup, seed | Lowercase; used as LDAP uid |
| email | VARCHAR(255) | NO | Signup, profile, seed | Unique |
| first_name | VARCHAR(100) | NO | Signup, profile, seed | |
| last_name | VARCHAR(100) | NO | Signup, profile, seed | |
| phone_country_code | VARCHAR(5) | NO | Signup, profile, seed | e.g. +1, +44 |
| phone_number | VARCHAR(20) | NO | Signup, profile, seed | PostgreSQL only; not in LDAP |
| password_hash | TEXT | NO | Signup, activation, seed | bcrypt hash |
| email_verified | BOOLEAN | NO | verify-email, seed | |
| phone_verified | BOOLEAN | NO | verify-phone, seed | |
| status | VARCHAR(20) | NO | Signup, verify, activate | PENDING, COMPLETE, ACTIVE, REVOKED |
| mfa_method | VARCHAR(10) | YES | Legacy | Prefer user_mfa_methods |
| totp_secret | TEXT | YES | Legacy | Prefer user_mfa_methods |
| created_at | TIMESTAMPTZ | NO | Auto | |
| updated_at | TIMESTAMPTZ | NO | Auto | |
| activated_at | TIMESTAMPTZ | YES | Admin activate, seed | |
| activated_by | VARCHAR(64) | YES | Admin activate, seed | Admin username or "seed" |

### user_mfa_methods

Per-user MFA methods (TOTP or SMS). A user can have multiple methods.

| Column | Type | Nullable | Set where | Description |
| ------ | ---- | -------- | --------- | ----------- |
| id | UUID | NO | Auto | Primary key |
| user_id | UUID | NO | MFA enrollment | FK to users.id |
| method | VARCHAR(10) | NO | MFA enrollment | totp or sms |
| totp_secret | TEXT | YES | TOTP enrollment | For TOTP method |
| phone_country_code | VARCHAR(5) | YES | SMS enrollment | Override; else use user profile |
| phone_number | VARCHAR(20) | YES | SMS enrollment | Override; else use user profile |
| created_at | TIMESTAMPTZ | NO | Auto | |

### groups

Group definitions. Created by admin (`POST /api/admin/groups`) or mirrored
from OpenLDAP by admin-seed job.

| Column | Type | Nullable | Set where | Description |
| ------ | ---- | -------- | --------- | ----------- |
| id | UUID | NO | Auto | Primary key |
| name | VARCHAR(100) | NO | Admin create, seed | Unique; used as LDAP cn |
| description | TEXT | YES | Admin create, seed | |
| ldap_dn | VARCHAR(500) | NO | Admin create, seed | e.g. cn=admins,ou=groups,dc=ldap,... |
| created_at | TIMESTAMPTZ | NO | Auto | |
| updated_at | TIMESTAMPTZ | NO | Auto | |

### user_groups

User-group membership. Created when admin activates user (assigns groups) or
when admin assigns groups to an active user.

| Column | Type | Nullable | Set where | Description |
| ------ | ---- | -------- | --------- | ----------- |
| user_id | UUID | NO | Admin activate/assign | FK to users.id |
| group_id | UUID | NO | Admin activate/assign | FK to groups.id |
| assigned_at | TIMESTAMPTZ | NO | Auto | |
| assigned_by | VARCHAR(64) | NO | Admin activate/assign | Admin username or "seed" |

### verification_tokens

Stores email/phone verification tokens (signup and profile change flows).

| Column | Type | Nullable | Description |
| ------ | ---- | -------- | ----------- |
| id | UUID | NO | Primary key |
| user_id | UUID | NO | FK to users.id |
| token_type | VARCHAR(10) | NO | `email`, `phone`, `eml_chg`, `phn_chg`, `pwd_rst` |
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

## OpenLDAP

OpenLDAP stores users and groups for authentication. The directory structure
is bootstrapped by custom LDIF files; users and groups are created by the
backend via `app/ldap/client.py`.

### Directory Bootstrap

The OpenLDAP Helm chart mounts custom LDIF files
(`application_infra/helm/openldap-values.tpl.yaml` `customLdifFiles`) that
run at startup on each pod:

1. **01-init-ous.ldif**: Creates `ou=users` and `ou=groups` under the base DN
   (e.g. `dc=ldap,dc=talorlik,dc=internal`).
2. **02-init-groups.ldif**: Creates `cn=admins` and `cn=users` in
   `ou=groups` with `groupOfUniqueNames` objectClass. Initial `uniqueMember`
   is the LDAP admin DN (required placeholder).

Search bases are configured via `LDAP_USER_SEARCH_BASE` (default `ou=users`)
and `LDAP_GROUP_SEARCH_BASE` (default `ou=groups`).

### User Entry (LDAP)

Created when admin activates a user (`POST /api/admin/users/{id}/activate`)
or by admin-seed job. DN: `uid={username},ou=users,{base_dn}`.

| Attribute | Set where | Description |
| --------- | --------- | ----------- |
| objectClass | create_user | inetOrgPerson, posixAccount, shadowAccount, top |
| uid | create_user | Username (from PostgreSQL) |
| cn | create_user | first_name + " " + last_name |
| sn | create_user | last_name |
| givenName | create_user | first_name |
| mail | create_user | email |
| userPassword | create_user, update_user | Plaintext (LDAP hashes internally) |
| uidNumber | create_user | Auto-incremented from `LDAP_UID_START` (default 10000) |
| gidNumber | create_user | From `LDAP_USERS_GID` (default 500) |
| homeDirectory | create_user | /home/{username} |
| loginShell | create_user | /bin/bash |

Phone number is stored only in PostgreSQL; LDAP user entries do not include
phone. Password changes (profile or reset) update LDAP via `update_user`.

### Group Entry (LDAP)

**Pre-created by bootstrap**: `cn=admins` and `cn=users` in `ou=groups`
(groupOfUniqueNames).

**Created by admin**: `POST /api/admin/groups` creates LDAP group first, then
PostgreSQL. New groups use `groupOfNames` objectClass with LDAP admin as
initial `member` (required placeholder).

| Attribute | Set where | Description |
| --------- | --------- | ----------- |
| objectClass | create_group, bootstrap | groupOfNames or groupOfUniqueNames |
| cn | create_group, bootstrap | Group name |
| description | create_group, bootstrap | Optional description |
| member | create_group | groupOfNames: user DNs (admin placeholder initially) |
| uniqueMember | bootstrap, add_user_to_group | groupOfUniqueNames: user DNs |
| memberUid | add_user_to_group | posixGroup: usernames only |

Membership attribute depends on group objectClass: `uniqueMember` for
groupOfUniqueNames, `member` for groupOfNames, `memberUid` for posixGroup.
`add_user_to_group` and `remove_user_from_group` detect the type and use the
correct attribute.

### Creation Flow Summary

- **PostgreSQL users**: Signup creates user (PENDING). verify-email/verify-phone
  can transition to COMPLETE. Admin activate creates LDAP user, assigns groups,
  sets ACTIVE.
- **PostgreSQL groups**: Admin create creates LDAP group then PostgreSQL.
  Admin-seed mirrors `cn=admins` and `cn=users` from LDAP to PostgreSQL.
- **LDAP users**: Created only on admin activation (or by admin-seed). Never
  created at signup.
- **LDAP groups**: Bootstrap creates admins/users. Admin create adds new groups
  via API.

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
