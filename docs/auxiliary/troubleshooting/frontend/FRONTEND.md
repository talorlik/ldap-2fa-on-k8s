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
