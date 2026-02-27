# 2FA Frontend Troubleshooting

This document covers common issues with the 2FA web frontend (API calls,
JWT, QR code, SMS button, admin features, styles).

## Common Issues

### 1. API Calls Failing

**Symptoms:** Network errors, CORS errors, 404s.

**Solutions:**

- Verify backend is running and accessible.
- Check API base path (`/api`) is correct.
- Verify ALB routing is configured correctly.
- Check browser console for detailed error messages.

### 2. JWT Token Not Persisting

**Symptoms:** User logged out after page refresh.

**Solutions:**

- Check browser localStorage is enabled.
- Verify token is stored: `localStorage.getItem('ldap2fa_token')`.
- Check token expiration time.
- Verify token format (should be JWT with 3 parts).

### 3. QR Code Not Displaying

**Symptoms:** TOTP enrollment shows blank QR code.

**Solutions:**

- Check QRCode.js library loaded from CDN.
- Verify `otpauth://` URI format from backend.
- Check browser console for JavaScript errors.
- Try manual secret entry as fallback.

### 4. SMS Button Not Showing

**Symptoms:** SMS option disabled or hidden.

**Solutions:**

- Check SMS is enabled: `API.getMfaMethods()` returns `sms_enabled: true`.
- Verify user's MFA method is SMS.
- Check username is entered in login form.
- Verify backend SMS configuration.

### 5. Admin Features Not Visible

**Symptoms:** Admin menu items hidden.

**Solutions:**

- Verify user is logged in with admin JWT.
- Check JWT payload contains `is_admin: true`.
- Verify user is member of admin LDAP group.
- Check browser console for authentication errors.

### 6. Styles Not Loading

**Symptoms:** Unstyled page, broken layout.

**Solutions:**

- Verify `styles.css` is accessible at `/css/styles.css`.
- Check nginx configuration serves static files.
- Verify file permissions in container.
- Check browser console for 404 errors.

### 7. Blank Page After Login / Menu Pages Blank / Logout Shows Only Tabs

**Symptoms:** After successful 2FA login the main content area is empty;
Profile, User Management, and Group Management show blank; after logout
only the Login/Sign Up tabs are visible and forms appear only after
refresh or switching tabs.

**Root cause:** Auth (login/signup/reset) and app (profile/admin) content
shared one container and one `hideAllSections()` that toggled every
`.tab-content`. That mixed visibility state and left logged-in sections
or the login form hidden at the wrong time.

**Fix:** The UI is split into two views that are shown one at a time:

- **`#auth-view`** (in `index.html`): Wraps the auth header, auth tabs,
  login tab, reset-password section, and signup tab. Shown when logged
  out.
- **`#app-view`** (in `index.html`): Wraps profile, admin-users, and
  admin-groups sections. Has class `hidden` by default; shown when logged
  in.

**JS changes (`main.js`):**

- `showLoggedInState()`: Hides `#auth-view`, shows `#app-view`, then
  calls `showSection('profile')`.
- `showLoggedOutState()`: Hides `#app-view`, shows `#auth-view`, then
  resets auth tab state and shows the login tab (active + not hidden).
- `hideAllSections()`: Only toggles `.tab-content` inside `#app-view`
  (profile, admin-users, admin-groups). No longer touches auth tabs.
- `showSection()`: Still adds `.active` and removes `.hidden` on the
  selected app section.
- `setupTabs()`: Tab buttons and content are scoped to `#auth-view`
  so Login/Sign Up only switch auth tab content, not app sections.

## Debugging

### Enable debug logging

Add console logging in `main.js` (e.g. at top of `App.init()`):

```javascript
console.log('App initialized', {
  smsEnabled: this.smsEnabled,
  session: this.session,
  currentUser: this.currentUser
});
```

### Check API responses

In browser console:

```javascript
API.healthCheck().then(console.log).catch(console.error);
console.log('Token:', API.getToken());
const token = API.getToken();
if (token) {
  const payload = JSON.parse(atob(token.split('.')[1]));
  console.log('JWT Payload:', payload);
}
```

### Network inspection

1. Open DevTools → Network tab.
2. Filter by "XHR" or "Fetch".
3. Check request/response headers.
4. Verify Authorization header contains Bearer token.
5. Check response status codes and error messages.

## Related Documentation

- [Troubleshooting Index](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/INDEX.md)
- [Application Layer Troubleshooting](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/docs/auxiliary/troubleshooting/application_layer/APPLICATION_LAYER.md)
- [application/frontend/README](https://github.com/talorlik/ldap-2fa-on-k8s/blob/main/application/frontend/README.md)
