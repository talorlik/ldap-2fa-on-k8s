# PRD: User Signup Management System

## Document Information

| Field | Value |
| ------- | ------- |
| Document ID | PRD-SIGNUP-MAN |
| Version | 1.0 |
| Status | Implemented |
| Last Updated | December 2024 |

## 1. Overview

### 1.1 Purpose

This document defines the requirements for a self-service user signup system that
allows users to register their own accounts, verify their identity through email
and phone verification, and be activated by an administrator before gaining access
to LDAP-authenticated resources.

### 1.2 Background

The existing LDAP 2FA application requires administrators to manually create users
in LDAP. This creates a bottleneck and doesn't scale well for organizations with
frequent user onboarding. A self-service signup system reduces administrative overhead
while maintaining security through multi-step verification.

### 1.3 Scope

This PRD covers:

- User self-registration with profile fields
- Email verification via AWS SES
- Phone verification via AWS SNS
- Profile state management with automatic transitions:
  - **PENDING**: User registered, verification incomplete
  - **COMPLETE**: Both email and phone verified (automatic transition)
  - **ACTIVE**: Admin activated with required group assignment
- Administrator user activation with mandatory group assignment
- PostgreSQL storage for user data before LDAP activation
- Login restrictions based on profile status

> [!NOTE]
>
> MFA method selection and enrollment occurs during the login process,
> not during signup. Users enroll in their preferred MFA method (TOTP or SMS)
> when they log in after account activation.

### 1.4 Complete User Flow Summary

**Sign Up Flow:**

1. User signs up → Status: **PENDING** (email and phone verification sent)
2. User verifies email → `email_verified = true`
3. User verifies phone → `phone_verified = true`
4. When both verified → Status automatically changes to **COMPLETE**
5. Admin activates user and assigns group(s) (required) → Status: **ACTIVE**

**Login Flow (ACTIVE users only):**

1. User enters username and password
2. System presents MFA selection screen (Authenticator app or SMS)
3. User selects MFA method and completes verification
4. User is logged in → Actions available based on assigned group(s):
   - Admin group members → Admin dashboard access
   - User group members → Standard user access

**Login Restrictions:**

- **PENDING** users: Cannot log in, see error listing missing verifications
- **COMPLETE** users: Cannot log in, see "awaiting admin approval" message
- **ACTIVE** users: Can complete login flow

## 2. User Stories

### 2.1 New User Registration

> **As a** new user,
> **I want to** sign up for an account myself,
> **So that** I don't need to wait for an administrator to create my account.

**Acceptance Criteria:**

- User can access a signup form from the main application
- Form collects: first name, last name, username, email, phone (with country code),
password
- Password must be at least 8 characters
- Username must be unique and follow format rules (letters, numbers, underscores,
hyphens)
- Email must be unique and valid format
- Phone number validated with country code
- MFA method selection and enrollment occurs during login, not during signup

### 2.2 Email Verification

> **As a** newly registered user,
> **I want to** verify my email address,
> **So that** the system can confirm I own this email.

**Acceptance Criteria:**

- Verification email sent automatically upon signup
- Email contains a clickable verification link
- Link expires after 24 hours
- User can request resend of verification email
- Clicking link marks email as verified (`email_verified = true`)
- If phone is already verified, status automatically changes from PENDING to COMPLETE
- User sees confirmation of successful verification with current profile status

### 2.3 Phone Verification

> **As a** newly registered user,
> **I want to** verify my phone number,
> **So that** the system can confirm I own this phone.

**Acceptance Criteria:**

- 6-digit verification code sent via SMS upon signup
- Code expires after 1 hour
- User enters code in the application
- User can request resend of verification code
- Correct code marks phone as verified (`phone_verified = true`)
- If email is already verified, status automatically changes from PENDING to COMPLETE
- User sees confirmation of successful verification with current profile status

### 2.4 Login Restrictions

> **As a** user with incomplete verification or pending activation,
> **I want to** receive a clear message when I try to log in,
> **So that** I understand what steps I need to complete.

**Acceptance Criteria:**

- Users with PENDING status cannot log in
- Error message specifies which verifications are missing (email, phone, or both)
- Users with COMPLETE status see message about awaiting admin approval
- Only ACTIVE users can complete the login flow
- Status automatically transitions from PENDING to COMPLETE when both email and
phone are verified
- After successful login, users can execute actions based on their assigned group(s)
(e.g., Admin group members see admin dashboard, User group members have
standard access)

### 2.5 Admin User Management

> **As an** administrator,
> **I want to** view and manage pending user registrations,
> **So that** I can approve or reject new user requests.

**Acceptance Criteria:**

- Admin tab visible only to authenticated administrators
- Admin can filter users by status (pending, complete, active)
- Admin can view user details (name, email, phone, verification status)
- Admin can activate users (creates them in LDAP)
- Admin can reject users (deletes their registration)
- Activated users receive welcome email notification

## 3. Functional Requirements

### 3.1 Profile States

| State | Description | Allowed Actions | Login Status |
| ------- | ------------- | ----------------- | ------------ |
| **PENDING** | User registered but verification incomplete (email or phone not verified) | Verify email, verify phone, resend verification | ❌ Cannot log in - shows error listing missing verifications |
| **COMPLETE** | All verifications complete (both email and phone verified), awaiting admin activation | Wait for admin activation | ❌ Cannot log in - shows "awaiting admin approval" message |
| **ACTIVE** | Admin activated, exists in LDAP, assigned to group(s) | Login, use application, execute actions based on group permissions | ✅ Can log in |

**State Transitions:**

```ascii
┌─────────────┐
│   SIGNUP    │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   PENDING   │ (email_verified = false OR phone_verified = false)
└──────┬──────┘
       │
       │ User verifies email → email_verified = true
       │ User verifies phone → phone_verified = true
       │
       │ When BOTH verified → Automatic transition
       │
       ▼
┌─────────────┐
│  COMPLETE   │ (email_verified = true AND phone_verified = true)
└──────┬──────┘
       │
       │ Admin activates user
       │ Admin assigns group(s) (REQUIRED)
       │ Creates user in LDAP
       │
       ▼
┌─────────────┐
│   ACTIVE    │ (user exists in LDAP, assigned to group(s))
└──────┬──────┘
       │
       │ User logs in (username + password)
       │ → MFA selection screen (Authenticator app or SMS)
       │ → MFA verification
       │
       ▼
┌─────────────┐
│  LOGGED IN  │
│             │
│ Actions based on group:
│ - Admin group → Admin dashboard access
│ - User group → Standard user access
└─────────────┘
```

> [!IMPORTANT]
>
> - **Automatic Status Transition**: When a user verifies their email or phone,
> the system automatically checks if both verifications are complete. If both
> `email_verified` and `phone_verified` are `true`, the status automatically
> changes from `PENDING` to `COMPLETE` (via `update_status_if_complete()` method).
> - **Group Assignment Requirement**: During admin activation, at least one group
> must be assigned. Group assignment is required and cannot be skipped.
> - **Login Restrictions**:
>
>   - `PENDING` users cannot log in and receive an error message listing which
>   verifications are missing (email, phone, or both).
>   - `COMPLETE` users cannot log in and receive a message that their profile is
>   awaiting admin approval.
>   - Only `ACTIVE` users can complete the login flow.
>   - **MFA Enrollment**: MFA method selection and enrollment occurs during the
>   login process, not during signup. Users choose between Authenticator app
>   (TOTP) or SMS when they log in after account activation.

### 3.2 Signup Form Fields

| Field | Type | Required | Validation |
| ------- | ------ | ---------- | ------------ |
| First Name | Text | Yes | 1-100 characters |
| Last Name | Text | Yes | 1-100 characters |
| Username | Text | Yes | 3-64 characters, alphanumeric + underscore/hyphen, starts with letter, unique |
| Email | Email | Yes | Valid email format, unique |
| Phone Country Code | Select | Yes | Valid country code (e.g., +1, +44) |
| Phone Number | Tel | Yes | 5-15 digits |
| Password | Password | Yes | Minimum 8 characters |
| Confirm Password | Password | Yes | Must match password |

> [!NOTE]
>
> MFA method selection and enrollment occurs during the login process,
> not during signup. Users will enroll in their preferred MFA method (TOTP or SMS)
> after their account is activated by an administrator.

### 3.3 Email Verification

| Requirement | Specification |
| ------------- | --------------- |
| Delivery Method | AWS SES |
| Token Format | UUID |
| Token Expiry | 24 hours (configurable) |
| Verification URL | `{APP_URL}/verify-email?token={token}&username={username}` |
| Resend Cooldown | 60 seconds |
| Status Update | Sets `email_verified = true`. If phone is already verified, status automatically changes from PENDING to COMPLETE |

### 3.4 Phone Verification

| Requirement | Specification |
| ------------- | --------------- |
| Delivery Method | AWS SNS SMS |
| Code Format | 6-digit numeric |
| Code Expiry | 1 hour |
| Entry Method | Manual input in application |
| Resend Cooldown | 60 seconds |
| Status Update | Sets `phone_verified = true`. If email is already verified, status automatically changes from PENDING to COMPLETE |

### 3.5 Admin Activation

When an administrator activates a user:

1. Admin selects user from "Awaiting Approval" list (status = COMPLETE)
2. Admin selects one or more groups to assign to the user (**required** - at
least one group must be selected)
3. On confirmation:
    - Create user in LDAP with attributes:
      - `uid`: username
      - `cn`: full name
      - `sn`: last name
      - `givenName`: first name
      - `mail`: email
      - `userPassword`: temporary password
      - `uidNumber`: auto-incremented
      - `gidNumber`: default users group
      - `homeDirectory`: `/home/{username}`
      - `objectClass`: inetOrgPerson, posixAccount, shadowAccount
    - Add user to selected LDAP group(s) (required - activation fails if no groups
    are successfully assigned)
    - Update user status to ACTIVE in PostgreSQL
    - Record activation timestamp and admin username
    - Send welcome email to user

> [!IMPORTANT]
>
> - **Group Assignment Requirement**: Group assignment is mandatory for activation.
> The backend validates that at least one group is provided and successfully assigned.
> Activation will fail if no groups are assigned.
> - **User Actions After Login**: After logging in, users can execute actions based
> on their assigned group(s):
>   - **Admin group members**: Can access admin dashboard, manage users, manage
>   groups, activate users
>   - **User group members**: Standard user access (profile management, etc.)
>   - Group membership determines which features and endpoints are accessible

### 3.6 Admin Authorization

| Requirement | Specification |
| ------------- | --------------- |
| Authentication | LDAP credentials + MFA code |
| Authorization | Member of admin group in LDAP |
| Admin Group DN | Configurable (default: `cn=admins,ou=groups,{base_dn}`) |

## 4. API Endpoints

### 4.1 Signup Endpoints

| Method | Endpoint | Description |
| -------- | ---------- | ------------- |
| POST | `/api/auth/signup` | Register new user |
| POST | `/api/auth/verify-email` | Verify email with token |
| POST | `/api/auth/verify-phone` | Verify phone with code |
| POST | `/api/auth/resend-verification` | Resend email or phone verification |
| GET | `/api/profile/status/{username}` | Get user profile status |

### 4.2 Admin Endpoints

| Method | Endpoint | Description |
| -------- | ---------- | ------------- |
| POST | `/api/admin/login` | Admin login (same as regular + admin check) |
| GET | `/api/admin/users` | List users with optional status filter |
| POST | `/api/admin/users/{id}/activate` | Activate user to LDAP |
| POST | `/api/admin/users/{id}/reject` | Reject and delete user |

### 4.3 Request/Response Examples

#### Signup Request

```json
{
  "username": "jsmith",
  "email": "john.smith@example.com",
  "first_name": "John",
  "last_name": "Smith",
  "phone_country_code": "+1",
  "phone_number": "5551234567",
  "password": "securepassword123"
}
```

> [!NOTE]
>
> The `mfa_method` field is not included in signup. MFA method selection and
> enrollment occurs during the login process after account activation.

#### Signup Response

```json
{
  "success": true,
  "message": "Account created. Please verify your email and phone number.",
  "user_id": "550e8400-e29b-41d4-a716-446655440000",
  "email_verification_sent": true,
  "phone_verification_sent": true
}
```

#### Login Error (Pending User)

```json
{
  "detail": "Profile incomplete. Please verify your: email, phone"
}
```

#### Login Error (Complete User)

```json
{
  "detail": "Your profile is awaiting admin approval. Please wait for activation."
}
```

## 5. Data Model

### 5.1 User Table

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(64) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone_country_code VARCHAR(5) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    password_hash TEXT NOT NULL,
    email_verified BOOLEAN DEFAULT FALSE,
    phone_verified BOOLEAN DEFAULT FALSE,
    status VARCHAR(20) DEFAULT 'pending',
    mfa_method VARCHAR(10) DEFAULT 'totp',
    totp_secret TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    activated_at TIMESTAMP WITH TIME ZONE,
    activated_by VARCHAR(64)
);
```

### 5.2 Verification Tokens Table

```sql
CREATE TABLE verification_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_type VARCHAR(10) NOT NULL,
    token VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## 6. Non-Functional Requirements

### 6.1 Security

| Requirement | Implementation |
| ------------- | ---------------- |
| Password Storage | bcrypt hashing |
| Token Comparison | Constant-time comparison (prevent timing attacks) |
| Rate Limiting | Resend cooldown prevents abuse |
| Session Security | Admin credentials validated per request |
| Input Validation | Server-side validation of all inputs |
| HTTPS | Required for all endpoints |

### 6.2 Performance

| Metric | Target |
| -------- | -------- |
| Signup Response Time | < 2 seconds |
| Verification Email Delivery | < 30 seconds |
| SMS Delivery | < 30 seconds |
| Database Queries | < 100ms |

### 6.3 Scalability

| Component | Scaling Strategy |
| ----------- | ------------------ |
| Backend API | Horizontal scaling (multiple pods) |
| PostgreSQL | Single instance (upgrade to HA if needed) |
| SES | AWS managed (scales automatically) |
| SNS | AWS managed (scales automatically) |

### 6.4 Availability

| Component | Target Availability |
| ----------- | --------------------- |
| API | 99.5% |
| Database | 99.5% |
| Email Delivery | 99.9% (AWS SES SLA) |
| SMS Delivery | 99.9% (AWS SNS SLA) |

## 7. Infrastructure Requirements

### 7.1 AWS Services

| Service | Purpose |
| --------- | --------- |
| SES | Email verification delivery |
| SNS | SMS verification delivery |
| IAM | IRSA roles for pod access |

### 7.2 Kubernetes Resources

| Resource | Purpose |
| ---------- | --------- |
| PostgreSQL (Helm) | User data storage (uses ECR image `postgresql-latest`) |
| ConfigMap | Application configuration |
| Secret | Database credentials |
| ServiceAccount | IRSA for AWS access |

> [!NOTE]
>
> **ECR Image Support**: PostgreSQL uses ECR images instead of Docker Hub.
> The image `bitnami/postgresql:18.1.0-debian-12-r4` is automatically mirrored to
> ECR with tag `postgresql-latest` by the `scripts/mirror-images-to-ecr.sh` script before
> Terraform operations. The ECR registry and repository are computed from
> `backend_infra` Terraform state.

### 7.3 Configuration Variables

| Variable | Description | Default |
| ---------- | ------------- | --------- |
| `DATABASE_URL` | PostgreSQL connection string | Required |
| `SES_SENDER_EMAIL` | Verified sender email | Required |
| `EMAIL_VERIFICATION_EXPIRY_HOURS` | Email token expiry | 24 |
| `APP_URL` | Application URL for links | Required |
| `LDAP_ADMIN_GROUP_DN` | Admin group DN | `cn=admins,ou=groups,{base_dn}` |
| `LDAP_USERS_GID` | Default GID for new users | 500 |
| `LDAP_UID_START` | Starting UID for new users | 10000 |

## 8. User Interface

### 8.1 Tab Structure

```ascii
┌─────────┬───────────┬─────────┐
│  Login  │  Sign Up  │  Admin  │
└─────────┴───────────┴─────────┘
                      (hidden until
                       logged in; admin
                       menu if admin)
```

MFA is completed on the second step after login (Authenticator app or SMS);
there is no separate Enroll MFA tab.

### 8.2 Signup Flow

```ascii
┌───────────────────────────────────────────────┐
│                 Sign Up Form                  │
├───────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐     │
│  │ First Name      │  │ Last Name       │     │
│  └─────────────────┘  └─────────────────┘     │
│  ┌─────────────────────────────────────────┐  │
│  │ Username                                │  │
│  └─────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────┐  │
│  │ Email                                   │  │
│  └─────────────────────────────────────────┘  │
│  ┌───────┐ ┌───────────────────────────────┐  │
│  │ +1  ▼ │ │ Phone Number                  │  │
│  └───────┘ └───────────────────────────────┘  │
│  ┌─────────────────────────────────────────┐  │
│  │ Password                                │  │
│  └─────────────────────────────────────────┘  │
│  ┌─────────────────────────────────────────┐  │
│  │ Confirm Password                        │  │
│  └─────────────────────────────────────────┘  │
│           ┌─────────────────────┐             │
│           │   Create Account    │             │
│           └─────────────────────┘             │
└───────────────────────────────────────────────┘
```

### 8.3 Verification Status Panel

```ascii
┌────────────────────────────────────────────────────────┐
│  📋 Complete Your Registration                         │
│  Please verify your email and phone to continue        │
├────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────┐   │
│  │ ⏳ Email Verification                 [Resend]  │   │
│  │    Check your inbox                             │   │
│  └─────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────┐   │
│  │ ⏳ Phone Verification                 [Resend]  │   │
│  │    Enter code sent to your phone                │   │
│  └─────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────┐   │
│  │ Phone Code: [______] [Verify]                   │   │
│  └─────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────┘
```

### 8.4 Admin Panel

```ascii
┌─────────────────────────────────────────────────────────┐
│  👥 User Management                          [Logout]   │
├─────────────────────────────────────────────────────────┤
│  Filter: [Awaiting Approval ▼]              [🔄 Refresh]│
├─────────────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────────────┐    │
│  │ John Smith                                      │    │
│  │ @jsmith                                         │    │
│  │ 📧 j***h@example.com  📱 +1***4567              │    │
│  │ [COMPLETE] ✅ Email ✅ Phone                    │    │
│  │ Created: Dec 18, 2024                           │    │
│  │                    [✅ Activate] [❌ Reject]    │    │
│  └─────────────────────────────────────────────────┘    │
│  ┌─────────────────────────────────────────────────┐    │
│  │ Jane Doe                                        │    │
│  │ @jdoe                                           │    │
│  │ ...                                             │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

## 9. Testing Requirements

### 9.1 Unit Tests

- User model validation
- Password hashing and verification
- Token generation and validation
- Profile state transitions

### 9.2 Integration Tests

- Signup flow end-to-end
- Email verification flow
- Phone verification flow
- Admin activation flow
- LDAP user creation

### 9.3 Security Tests

- SQL injection prevention
- XSS prevention
- Authentication bypass attempts
- Rate limiting effectiveness

## 10. Deployment Checklist

### 10.1 Pre-Deployment

- [ ] PostgreSQL deployed and accessible
- [ ] SES sender email verified (or domain verified)
- [ ] SNS configured for SMS (if using SMS MFA)
- [ ] LDAP admin group exists with at least one member
- [ ] IAM roles created for IRSA (SES + SNS permissions)
- [ ] Environment variables configured

### 10.2 Post-Deployment

- [ ] Test signup flow with new user
- [ ] Verify email delivery and verification
- [ ] Verify SMS delivery and verification
- [ ] Test admin login and user listing
- [ ] Test user activation (verify LDAP user created)
- [ ] Test login as activated user

## 11. Future Enhancements

| Enhancement | Priority | Description |
| ------------- | ---------- | ------------- |
| Password Reset | High | Self-service password reset via email |
| Profile Editing | Medium | Users can update their profile info |
| Audit Logging | Medium | Track all admin actions |
| Bulk Operations | Low | Admin can activate/reject multiple users |
| Email Templates | Low | Customizable email templates |
| SSO Integration | Low | OAuth2/OIDC for additional auth options |

## 12. References

- [AWS SES Documentation](https://docs.aws.amazon.com/ses/)
- [AWS SNS SMS Documentation](https://docs.aws.amazon.com/sns/latest/dg/sms_publish-to-phone.html)
- [OpenLDAP Schema](https://www.openldap.org/doc/admin24/schema.html)
- [TOTP RFC 6238](https://tools.ietf.org/html/rfc6238)
