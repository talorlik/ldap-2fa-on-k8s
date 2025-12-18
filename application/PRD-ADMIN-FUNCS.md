# PRD: Admin Functions and User Profile Management

## Overview

This document defines the requirements for admin functionality and user profile management features in the LDAP 2FA Authentication application.

## Table of Contents

1. [User Profile Management](#1-user-profile-management)
2. [SMS OTP Verification Requirements](#2-sms-otp-verification-requirements)
3. [Admin Dashboard](#3-admin-dashboard)
4. [Group Management](#4-group-management)
5. [User-Group Assignment](#5-user-group-assignment)
6. [Approve/Revoke Workflow](#6-approverevoke-workflow)
7. [List Features](#7-list-features)
8. [Admin Notifications](#8-admin-notifications)
9. [Top Navigation Bar](#9-top-navigation-bar)

---

## 1. User Profile Management

### 1.1 Profile Page

Users must be able to view and edit their profile details through a dedicated profile page.

**Viewable Fields:**

- Username (read-only)
- First Name
- Last Name
- Email Address
- Phone Number (with country code)
- MFA Method
- Account Status
- Account Creation Date

**Editable Fields:**

| Field | Editable | Condition |
|-------|----------|-----------|
| Username | No | Never editable |
| First Name | Yes | Always |
| Last Name | Yes | Always |
| Email | Yes | Only before email is verified |
| Phone Number | Yes | Only before phone is verified |
| MFA Method | No | Must re-enroll to change |

### 1.2 Edit Restrictions

- **Email Address**: Can only be modified if `email_verified = false`. Once verified, email becomes read-only to prevent account takeover.
- **Phone Number**: Can only be modified if `phone_verified = false`. Once verified, phone becomes read-only.
- Changing email or phone resets the respective verification status and triggers a new verification flow.

---

## 2. SMS OTP Verification Requirements

### 2.1 Phone Verification Requirement

Users can only use SMS OTP as their MFA method if their phone number has been verified.

**Behavior:**

- If a user selects SMS as MFA method during signup, phone verification is mandatory
- SMS OTP option is disabled/hidden for users with unverified phone numbers
- Login attempts with SMS MFA and unverified phone display error: "Phone verification required for SMS authentication"

### 2.2 Implementation Rules

- During MFA enrollment: SMS option only available if `phone_verified = true`
- During login: If `mfa_method = 'sms'` and `phone_verified = false`, reject with appropriate error
- UI should grey out or hide SMS option for unverified users

---

## 3. Admin Dashboard

### 3.1 Access Control

The Admin tab/section is only visible and accessible to users who are members of the LDAP admin group.

**Visibility Rules:**

- Admin tab hidden for non-admin users
- Admin routes protected by admin authentication
- Admin status determined by LDAP admin group membership

### 3.2 Admin Dashboard Features

**User Management Section:**

- View all users in the system
- See user details:
  - Full name
  - Username
  - Email
  - Phone number
  - Account status (pending, complete, active, revoked)
  - Email verification status
  - Phone verification status
  - MFA method
  - Group memberships
  - Creation date
  - Activation date and activating admin (if applicable)

**Group Management Section:**

- View all groups
- Create new groups
- Edit existing groups
- Delete groups
- View group members

---

## 4. Group Management

### 4.1 Group CRUD Operations

Admins must have full CRUD (Create, Read, Update, Delete) capabilities for groups.

**Create Group:**

- Name (required, unique)
- Description (optional)
- Automatically creates corresponding LDAP group

**Read Groups:**

- List all groups with member counts
- View group details including all members

**Update Group:**

- Modify group name
- Modify group description
- Changes sync to LDAP

**Delete Group:**

- Remove group from system
- Remove all user associations
- Delete corresponding LDAP group
- Confirmation required before deletion

### 4.2 Group Data Model

```
Group:
  - id: UUID (primary key)
  - name: string (unique)
  - description: string
  - ldap_dn: string (LDAP distinguished name)
  - created_at: timestamp
  - updated_at: timestamp
```

---

## 5. User-Group Assignment

### 5.1 Assignment Capabilities

Admins can manage user-group relationships with the following operations:

**Assign to Group(s):**

- Add user to one or more groups
- User can belong to multiple groups simultaneously
- Updates both database and LDAP group membership

**Remove from Group:**

- Remove user from a specific group
- User remains in other assigned groups

**Replace Groups:**

- Replace all user's group memberships with a new set
- Useful for role changes

### 5.2 User-Group Data Model

```
UserGroup:
  - user_id: UUID (foreign key to users)
  - group_id: UUID (foreign key to groups)
  - assigned_at: timestamp
  - assigned_by: string (admin username)
```

---

## 6. Approve/Revoke Workflow

### 6.1 User Approval (Activate)

When an admin approves a user:

1. Admin selects user from "Awaiting Approval" list (status = 'complete')
2. Admin clicks "Approve" button
3. Modal appears with group selection (multi-select)
4. Admin selects one or more groups to assign
5. On confirmation:
   - User is created in LDAP
   - User is added to selected LDAP groups
   - User status changes to 'active'
   - Welcome email is sent to user
   - Activation timestamp and admin recorded

**Note:** Group assignment is required for approval - at least one group must be selected.

### 6.2 User Revocation

When an admin revokes an active user:

1. Admin selects active user
2. Admin clicks "Revoke" button
3. Confirmation dialog appears
4. On confirmation:
   - User is removed from all LDAP groups
   - User is deleted from LDAP
   - User status changes to 'revoked' OR user is deleted from database
   - Revocation is logged for audit

---

## 7. List Features

### 7.1 Requirements

All displayable lists (users, groups) must support:

**Sorting:**

- Click column header to sort ascending/descending
- Visual indicator for current sort column and direction
- Sortable columns for users: Name, Username, Email, Status, Created Date
- Sortable columns for groups: Name, Member Count, Created Date

**Filtering:**

- Users: Filter by status (pending, complete, active, revoked)
- Users: Filter by group membership
- Groups: Filter by member count range

**Searching:**

- Real-time search as user types
- Users: Search by username, email, first name, last name
- Groups: Search by name, description

### 7.2 UI Components

- Search input field with icon
- Filter dropdowns/buttons
- Sortable column headers with sort indicators
- Pagination for large lists (optional, based on data volume)

---

## 8. Admin Notifications

### 8.1 New User Signup Notification

When a new user signs up, all admin users receive an email notification.

**Trigger:** Successful user signup (after user record created)

**Recipients:** All users in the LDAP admin group (fetched via `mail` attribute)

**Email Content:**

- Subject: "New User Signup - [Username]"
- Body includes:
  - New user's username
  - Full name
  - Email address
  - Phone number
  - Signup timestamp
  - Direct link to admin dashboard for review

**Implementation:**

- Use existing AWS SES email infrastructure
- Query LDAP admin group for member emails
- Send notification asynchronously (don't block signup response)

---

## 9. Top Navigation Bar

### 9.1 Requirements

After successful login, the UI must display a persistent top navigation bar.

**Components:**

- Application logo/name (left side)
- User information (right side):
  - Display name or username
  - Dropdown menu

### 9.2 User Menu Items

**For Regular Users:**

- Profile - Navigate to profile page
- Logout - End session and return to login

**For Admin Users:**

- Profile - Navigate to profile page
- Admin Dashboard - Navigate to admin section
- User Management - Navigate to user list
- Group Management - Navigate to group list
- Logout - End session and return to login

### 9.3 Visual Design

- Fixed position at top of viewport
- Consistent across all authenticated pages
- Dropdown menu appears on click/hover
- Visual distinction for admin menu items

---

## Technical Requirements

### Authentication

- JWT-based session management
- Token includes user ID, username, is_admin flag
- Token expiry with refresh mechanism
- All authenticated endpoints validate JWT

### API Endpoints

**Profile:**

- `GET /api/profile/{username}` - Get profile (authenticated)
- `PUT /api/profile/{username}` - Update profile (authenticated, owner only)

**Admin - Groups:**

- `GET /api/admin/groups` - List groups
- `POST /api/admin/groups` - Create group
- `GET /api/admin/groups/{id}` - Get group details
- `PUT /api/admin/groups/{id}` - Update group
- `DELETE /api/admin/groups/{id}` - Delete group

**Admin - User Groups:**

- `GET /api/admin/users/{id}/groups` - Get user's groups
- `POST /api/admin/users/{id}/groups` - Assign groups
- `PUT /api/admin/users/{id}/groups` - Replace groups
- `DELETE /api/admin/users/{id}/groups/{group_id}` - Remove from group

**Admin - User Management:**

- `GET /api/admin/users` - List users (with sorting, filtering, search)
- `POST /api/admin/users/{id}/revoke` - Revoke user

### Security Considerations

- All admin endpoints require admin authentication
- Profile edits require owner authentication
- Email/phone changes only allowed before verification
- Rate limiting on admin operations
- Audit logging for admin actions

---

## Success Criteria

1. Users can view and edit their profile with appropriate restrictions
2. SMS OTP only available for users with verified phone numbers
3. Admin tab only visible to admin users
4. Admins can perform full CRUD on groups
5. Admins can assign/remove users from groups
6. Approval workflow requires group assignment
7. Revoke removes user from LDAP and groups
8. All lists support sorting, filtering, and searching
9. Admins receive email when new users sign up
10. Top bar displays logged-in user with functional menu
