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
- Profile state management (PENDING → COMPLETE → ACTIVE)
- Administrator user management interface
- PostgreSQL storage for user data before LDAP activation

## 2. User Stories

### 2.1 New User Registration

> **As a** new user,
> **I want to** sign up for an account myself,
> **So that** I don't need to wait for an administrator to create my account.

**Acceptance Criteria:**

- User can access a signup form from the main application
- Form collects: first name, last name, username, email, phone (with country code),
password
- User selects preferred MFA method (TOTP or SMS)
- Password must be at least 8 characters
- Username must be unique and follow format rules (letters, numbers, underscores,
hyphens)
- Email must be unique and valid format
- Phone number validated with country code

### 2.2 Email Verification

> **As a** newly registered user,
> **I want to** verify my email address,
> **So that** the system can confirm I own this email.

**Acceptance Criteria:**

- Verification email sent automatically upon signup
- Email contains a clickable verification link
- Link expires after 24 hours
- User can request resend of verification email
- Clicking link marks email as verified
- User sees confirmation of successful verification

### 2.3 Phone Verification

> **As a** newly registered user,
> **I want to** verify my phone number,
> **So that** the system can confirm I own this phone.

**Acceptance Criteria:**

- 6-digit verification code sent via SMS upon signup
- Code expires after 1 hour
- User enters code in the application
- User can request resend of verification code
- Correct code marks phone as verified
- User sees confirmation of successful verification

### 2.4 Login Restrictions

> **As a** user with incomplete verification,
> **I want to** receive a clear message when I try to log in,
> **So that** I understand what steps I need to complete.

**Acceptance Criteria:**

- Users with PENDING status cannot log in
- Error message specifies which verifications are missing (email, phone, or both)
- Users with COMPLETE status see message about awaiting admin approval
- Only ACTIVE users can complete the login flow

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

| State | Description | Allowed Actions |
| ------- | ------------- | ----------------- |
| PENDING | User registered but verification incomplete | Verify email, verify phone, resend verification |
| COMPLETE | All verifications complete, awaiting admin | Wait for admin activation |
| ACTIVE | Admin activated, exists in LDAP | Login, use application |

**State Transitions:**

```ascii
┌─────────────┐
│   SIGNUP    │
└──────┬──────┘
       │
       ▼
┌─────────────┐     Email AND Phone
│   PENDING   │ ─────────────────────┐
└─────────────┘                      │
                                     ▼
                              ┌─────────────┐
                              │  COMPLETE   │
                              └──────┬──────┘
                                     │ Admin Activation
                                     ▼
                              ┌─────────────┐
                              │   ACTIVE    │
                              └─────────────┘
```

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
| MFA Method | Radio | Yes | TOTP (default) or SMS |

### 3.3 Email Verification

| Requirement | Specification |
| ------------- | --------------- |
| Delivery Method | AWS SES |
| Token Format | UUID |
| Token Expiry | 24 hours (configurable) |
| Verification URL | `{APP_URL}/verify-email?token={token}&username={username}` |
| Resend Cooldown | 60 seconds |

### 3.4 Phone Verification

| Requirement | Specification |
| ------------- | --------------- |
| Delivery Method | AWS SNS SMS |
| Code Format | 6-digit numeric |
| Code Expiry | 1 hour |
| Entry Method | Manual input in application |
| Resend Cooldown | 60 seconds |

### 3.5 Admin Activation

When an administrator activates a user:

1. Create user in LDAP with attributes:
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

2. Update user status to ACTIVE in PostgreSQL

3. Record activation timestamp and admin username

4. Send welcome email to user

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
  "password": "securepassword123",
  "mfa_method": "totp"
}
```

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
| PostgreSQL (Helm) | User data storage (uses ECR image `postgresql-18.1.0`) |
| ConfigMap | Application configuration |
| Secret | Database credentials |
| ServiceAccount | IRSA for AWS access |

> [!NOTE]
>
> **ECR Image Support**: PostgreSQL uses ECR images instead of Docker Hub.
> The image `bitnami/postgresql:18.1.0-debian-12-r4` is automatically mirrored to
> ECR with tag `postgresql-18.1.0` by the `mirror-images-to-ecr.sh` script before
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
┌─────────┬───────────┬────────────┬─────────┐
│  Login  │  Sign Up  │ Enroll MFA │  Admin  │
└─────────┴───────────┴────────────┴─────────┘
                                    (hidden until
                                     admin login)
```

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
│  ┌─────────────────────────────────────────┐  │
│  │ ○ 📱 Authenticator App                  │  │
│  │ ○ 💬 SMS                                │  │
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
