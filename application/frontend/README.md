# LDAP 2FA Frontend

A modern, responsive single-page application (SPA) for LDAP two-factor authentication,
user registration, and administrative management. Built with vanilla JavaScript,
HTML5, and CSS3, served via nginx.

## Overview

The frontend is a static web application that provides a complete user interface
for the LDAP 2FA authentication system. It offers self-service user registration,
MFA enrollment, authentication, profile management, and administrative functions
for user and group management.

### Key Features

- **User Authentication**: Login with LDAP credentials and 6-digit verification
code (TOTP or SMS)
- **Self-Service Registration**: User signup with email and phone verification
- **MFA Enrollment**: Support for TOTP (authenticator apps) and SMS-based verification
- **Profile Management**: User profile editing with verification-based restrictions
- **Admin Dashboard**: Comprehensive user and group management interface
- **Responsive Design**: Mobile-friendly UI that works on all screen sizes
- **Modern UX**: Clean, intuitive interface with real-time feedback and error handling

## Architecture

### Single-Page Application (SPA)

The frontend is a client-side rendered SPA that communicates with the backend API
via REST endpoints. All routing and state management is handled client-side using
vanilla JavaScript.

### Deployment Architecture

```ascii
┌─────────────────────────────────────────────────────────┐
│                    Internet-Facing ALB                  │
│              (HTTPS, TLS termination)                   │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ Path: /
                       │ Host: app.<domain>
                       ▼
┌─────────────────────────────────────────────────────────┐
│              Kubernetes Ingress Resource                │
│              (EKS Auto Mode managed)                    │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ Service Port: 80
                       ▼
┌─────────────────────────────────────────────────────────┐
│              Kubernetes Service (ClusterIP)             │
│              Port: 80 → Container Port: 8080            │
└──────────────────────┬──────────────────────────────────┘
                       │
                       │ Container Port: 8080
                       ▼
┌─────────────────────────────────────────────────────────┐
│              nginx Container (non-root user)            │
│              - Serves static files from /usr/share/     │
│                nginx/html/                              │
│              - Health check endpoint: /health           │
│              - Security headers configured              │
└─────────────────────────────────────────────────────────┘
```

### Routing Pattern

The frontend uses a **single-domain routing pattern**:

- **Public Hostname**: `app.<domain>` (e.g., `app.talorlik.com`)
- **Frontend Path**: `/` (serves `index.html` and static assets)
- **Backend API Path**: `/api/*` (proxied to backend service via ALB)
- **No CORS Required**: Same-origin requests since frontend and backend share the
same domain

## File Structure

```bash
frontend/
├── Dockerfile                    # Container image definition
├── nginx.conf                    # nginx server configuration
├── README.md                     # This file
└── src/
    ├── index.html               # Main HTML file (SPA structure)
    ├── css/
    │   └── styles.css           # Complete styling (CSS variables, responsive)
    └── js/
        ├── api.js               # API client (REST endpoints, JWT handling)
        └── main.js              # Application logic (state, forms, UI)
└── helm/
    └── ldap-2fa-frontend/       # Helm chart for Kubernetes deployment
        ├── Chart.yaml           # Chart metadata
        ├── values.yaml          # Default configuration values
        └── templates/
            ├── deployment.yaml  # Kubernetes Deployment
            ├── service.yaml     # Kubernetes Service
            ├── ingress.yaml     # Kubernetes Ingress
            ├── serviceaccount.yaml
            ├── hpa.yaml         # Horizontal Pod Autoscaler
            └── tests/
                └── test-connection.yaml
```

## Technologies Used

### Core Technologies

- **HTML5**: Semantic markup, form validation, accessibility features
- **CSS3**: Modern styling with CSS variables, flexbox, grid, animations
- **Vanilla JavaScript (ES6+)**: No frameworks - pure JavaScript for better
performance and smaller bundle size
- **nginx**: High-performance web server for static file serving

### External Libraries

- **QRCode.js** (CDN): QR code generation for TOTP enrollment
  - CDN: `https://cdn.jsdelivr.net/npm/qrcode@1.5.3/build/qrcode.min.js`
  - Used for: Generating QR codes from TOTP `otpauth://` URIs

### Browser APIs Used

- **Fetch API**: HTTP requests to backend
- **localStorage**: JWT token storage
- **URLSearchParams**: URL parameter parsing (email verification tokens)
- **Clipboard API**: Copy TOTP secret to clipboard
- **History API**: Clean URL after email verification

## Features in Detail

### 1. Authentication Flow

#### Login Tab

- Username and password input
- 6-digit verification code input
- SMS send button (shown for SMS MFA users)
- Real-time MFA method detection based on username
- Automatic form validation
- Loading states and error handling

#### Enrollment Tab

- MFA method selection (TOTP or SMS)
- Phone number input for SMS enrollment
- QR code display for TOTP enrollment
- Manual secret entry option with copy button
- Success confirmation for both methods

### 2. User Registration

#### Signup Tab

- Form fields:
  - First name and last name
  - Username (validated: letters, numbers, underscores, hyphens)
  - Email address
  - Phone number with country code selector (30+ countries)
  - Password (minimum 8 characters)
  - Password confirmation
  - MFA method selection (TOTP or SMS)
- Email verification panel:
  - Status indicators for email and phone verification
  - Resend buttons with countdown timers
  - Phone verification code input
  - Completion status display

### 3. Profile Management

- **View Profile**: Display user information, groups, MFA method, account status
- **Edit Profile**: Update name, email (if not verified), phone (if not verified)
- **Read-Only Fields**: Username, MFA method, account status
- **Verification Restrictions**: Email and phone become read-only after verification
- **Group Display**: Visual badges showing user's group memberships

### 4. Admin Dashboard

#### User Management

- **User List Table**: Sortable columns (name, username, email, status,
created date)
- **Search**: Real-time search across user fields
- **Filters**: Status filter (pending, complete, active, revoked) and group filter
- **Actions**:
  - Approve users (with group assignment modal)
  - Reject users
  - Revoke active users
- **User Details**: Full name, username, email, status badges, group memberships

#### Group Management

- **Group List Table**: Sortable columns (name, description, members, created date)
- **Search**: Real-time search across group fields
- **CRUD Operations**:
  - Create groups (modal form)
  - Edit groups (modal form)
  - Delete groups (with confirmation)
  - View group members (modal)
- **Member Count**: Clickable link to view members

### 5. UI Components

#### Navigation

- **Top Bar**: Fixed navigation bar (shown when logged in)
- **User Menu**: Dropdown with profile, admin links (if admin), logout
- **Tab Navigation**: Pre-login tabs (Login, Sign Up, Enroll)

#### Modals

- **Group Create/Edit Modal**: Form for group name and description
- **Approve User Modal**: Group selection checkboxes (at least one required)
- **Group Members Modal**: List of group members with names and usernames
- **Confirm Modal**: Generic confirmation dialog for destructive actions

#### Status Messages

- **Toast Notifications**: Fixed top-center status messages (success, error, warning)
- **Auto-Dismiss**: Messages automatically hide after 4 seconds
- **Color-Coded**: Visual indicators for message types

#### Form Elements

- **Input Validation**: HTML5 validation with custom patterns
- **Loading States**: Button loading indicators during API calls
- **Error Display**: Inline error messages and result containers
- **Disabled States**: Proper disabled states during operations

## Configuration

### nginx Configuration

The `nginx.conf` file configures:

- **Port**: 8080 (non-root user requirement)
- **Root Directory**: `/usr/share/nginx/html`
- **Security Headers**:
  - `X-Frame-Options: SAMEORIGIN`
  - `X-Content-Type-Options: nosniff`
  - `X-XSS-Protection: 1; mode=block`
  - `Referrer-Policy: strict-origin-when-cross-origin`
- **Gzip Compression**: Enabled for text, CSS, JavaScript, JSON, XML, SVG
- **Static Asset Caching**: 1-year cache for CSS, JS, images, fonts
- **Health Check Endpoint**: `/health` returns `200 OK` with "healthy"
- **SPA Routing**: All routes fallback to `index.html` for client-side routing
- **Error Pages**: Custom error page handling

### Helm Chart Configuration

Key configuration options in `values.yaml`:

```yaml
# Replicas
replicaCount: 2

# Container image
image:
  repository: ""  # Set via CI/CD or ArgoCD
  tag: ""         # Set via CI/CD
  pullPolicy: IfNotPresent

# Service
service:
  type: ClusterIP
  port: 80
  containerPort: 8080

# Ingress
ingress:
  enabled: true
  className: ""  # Set to IngressClass name
  annotations:
    alb.ingress.kubernetes.io/group.order: "20"  # Lower priority than /api
  hosts:
    - host: app.<domain>
      paths:
        - path: /
          pathType: Prefix

# Resources
resources:
  limits:
    cpu: 200m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi

# Health checks
livenessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 5
  periodSeconds: 30

readinessProbe:
  httpGet:
    path: /health
    port: http
  initialDelaySeconds: 3
  periodSeconds: 10

# Security context
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
```

## Deployment

### Container Image

The frontend is containerized using a multi-stage Dockerfile:

```dockerfile
FROM nginx:1.29.4-alpine

WORKDIR /usr/share/nginx/html/

# Copy source files
COPY src/ .

# Copy custom nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Create non-root user and set permissions
RUN addgroup -g 1000 -S appgroup && \
    adduser -u 1000 -S appuser -G appgroup && \
    chown -R appuser:appgroup /usr/share/nginx/html && \
    chown -R appuser:appgroup /var/cache/nginx && \
    chown -R appuser:appgroup /var/log/nginx && \
    chown -R appuser:appgroup /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R appuser:appgroup /var/run/nginx.pid

# Switch to non-root user
USER appuser

# Expose port 8080 (non-root requirement)
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]
```

**Key Security Features**:

- Runs as non-root user (UID 1000)
- Minimal base image (Alpine Linux)
- Proper file permissions
- Health check configured

### Kubernetes Deployment

The frontend is deployed via Helm chart:

```bash
# Build and push image (via CI/CD)
docker build -t <ecr-repo>/ldap-2fa-frontend:<tag> .
docker push <ecr-repo>/ldap-2fa-frontend:<tag>

# Deploy via Helm (or ArgoCD)
helm install ldap-2fa-frontend ./helm/ldap-2fa-frontend \
  --namespace 2fa-app \
  --set image.repository=<ecr-repo>/ldap-2fa-frontend \
  --set image.tag=<tag> \
  --set ingress.hosts[0].host=app.<domain>
```

### CI/CD Integration

The frontend is built and deployed via GitHub Actions workflow (`frontend_build_push.yaml`):

1. **Build**: Docker image build from `Dockerfile`
2. **Push**: Image pushed to ECR repository
3. **Deploy**: ArgoCD syncs Helm chart (if GitOps enabled)

> [!IMPORTANT]
>
> **Deployment Dependency:** The frontend application deployment **depends on running
> both** the **Backend Build and Push** (`backend_build_push.yaml`) and **Frontend
> Build and Push** (`frontend_build_push.yaml`) workflows. Both workflows must be
> completed before ArgoCD can sync the applications or manual Helm deployment can
> succeed. Without both images in ECR, the deployment will fail.

## Development

### Local Development

#### Prerequisites

- Node.js (optional, for local development server)
- Docker (for containerized development)
- Backend API running (for API calls)

#### Running Locally

##### Option 1: Simple HTTP Server

```bash
cd frontend/src
python3 -m http.server 8080
# Or
npx serve -p 8080
```

##### Option 2: Docker

```bash
cd frontend
docker build -t ldap-2fa-frontend:dev .
docker run -p 8080:8080 ldap-2fa-frontend:dev
```

##### Option 3: nginx

```bash
# Copy nginx.conf to /etc/nginx/sites-available/
# Symlink to sites-enabled
sudo ln -s /etc/nginx/sites-available/frontend /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

#### API Configuration

The frontend uses relative URLs for API calls (`/api/*`). For local development
with a separate backend:

1. **Proxy Setup**: Configure nginx or development server to proxy `/api/*` to backend
2. **CORS**: Enable CORS on backend for local development
3. **Environment Variables**: Consider adding API base URL configuration

### Code Structure

#### `index.html`

- **Structure**: Single HTML file with all UI sections
- **Sections**:
  - Top navigation bar (logged-in state)
  - Auth header and tabs (logged-out state)
  - Login form
  - Signup form with verification panel
  - Enrollment form
  - Profile section
  - Admin users section
  - Admin groups section
  - Modals (group, approve, members, confirm)
- **Scripts**: Loads `api.js` and `main.js` at the bottom

#### `js/api.js`

- **API Client**: Centralized API communication
- **JWT Handling**: Token storage in localStorage
- **Error Handling**: Custom `APIError` class with status code handling
- **Methods**: All backend API endpoints wrapped in methods
- **Authentication**: Automatic Bearer token injection for authenticated requests

#### `js/main.js`

- **Application State**: Global `App` object with state management
- **Initialization**: `App.init()` sets up all event listeners
- **Form Handlers**: Login, signup, enrollment, profile, admin forms
- **UI Management**: Show/hide sections, modals, status messages
- **Session Management**: JWT token validation and session restoration
- **XSS Protection**: `escapeHtml()` function for safe HTML rendering

#### `css/styles.css`

- **CSS Variables**: Theme colors, spacing, shadows defined in `:root`
- **Responsive Design**: Mobile-first approach with media queries
- **Dark Mode**: Automatic dark mode support via `prefers-color-scheme`
- **Animations**: Fade-in, slide-down animations for smooth UX
- **Component Styles**: Buttons, forms, tables, modals, badges, etc.

### Adding New Features

#### Adding a New API Endpoint

1. **Add method to `api.js`**:

    ```javascript
    async newEndpoint(params) {
        return this.authRequest('/new-endpoint', {
            method: 'POST',
            body: JSON.stringify(params),
        });
    }
    ```

2. **Call from `main.js`**:

    ```javascript
    try {
        const response = await API.newEndpoint({ param: value });
        this.showStatus('Success!', 'success');
    } catch (error) {
        this.showStatus(error.message, 'error');
    }
    ```

#### Adding a New UI Section

1. **Add HTML to `index.html`**:

    ```html
    <section id="new-section" class="tab-content hidden">
        <!-- Section content -->
    </section>
    ```

2. **Add CSS to `styles.css`**:

    ```css
    #new-section {
        /* Styles */
    }
    ```

3. **Add JavaScript to `main.js`**:

    ```javascript
    setupNewSection() {
        // Event listeners and logic
    }

    // Call in App.init()
    async init() {
        // ...
        this.setupNewSection();
    }
    ```

## Security Features

### Client-Side Security

1. **XSS Protection**:
   - HTML escaping via `escapeHtml()` function
   - No `innerHTML` usage with user input
   - Content Security Policy headers (via nginx)

2. **JWT Token Storage**:
   - Stored in `localStorage` (not cookies to avoid CSRF)
   - Automatic expiration checking
   - Token cleared on logout

3. **Input Validation**:
   - HTML5 form validation
   - Custom pattern validation (username, phone, verification codes)
   - Server-side validation (backend validates all inputs)

4. **Password Handling**:
   - Passwords never stored client-side
   - Password fields use `type="password"`
   - Password confirmation validation

### Server-Side Security (nginx)

1. **Security Headers**:
   - `X-Frame-Options: SAMEORIGIN` (prevents clickjacking)
   - `X-Content-Type-Options: nosniff` (prevents MIME sniffing)
   - `X-XSS-Protection: 1; mode=block` (XSS protection)
   - `Referrer-Policy: strict-origin-when-cross-origin`

2. **File Access**:
   - Hidden files denied (`.htaccess`, `.git`, etc.)
   - No directory listing

3. **HTTPS Enforcement**:
   - TLS termination at ALB (not nginx)
   - HTTP to HTTPS redirect configured at ALB level

## API Integration

### API Client (`api.js`)

The frontend communicates with the backend via REST API:

- **Base Path**: `/api` (relative URLs)
- **Authentication**: JWT Bearer tokens in `Authorization` header
- **Content-Type**: `application/json` for all requests
- **Error Handling**: Custom `APIError` class with status codes

### Key API Methods

#### Authentication

- `API.login(username, password, verificationCode)` - User login
- `API.enroll(username, password, mfaMethod, phoneNumber)` - MFA enrollment
- `API.sendSmsCode(username, password)` - Request SMS code

#### User Registration

- `API.signup(userData)` - Create new user account
- `API.verifyEmail(username, token)` - Verify email address
- `API.verifyPhone(username, code)` - Verify phone number
- `API.resendVerification(username, type)` - Resend verification

#### Profile

- `API.getProfile(username)` - Get user profile
- `API.updateProfile(username, updates)` - Update profile

#### Admin (requires admin JWT)

- `API.adminListUsersEnhanced(params)` - List users with filters
- `API.revokeUser(userId)` - Revoke user access
- `API.listGroups(params)` - List groups
- `API.createGroup(name, description)` - Create group
- `API.updateGroup(groupId, updates)` - Update group
- `API.deleteGroup(groupId)` - Delete group
- `API.assignUserGroups(userId, groupIds)` - Assign user to groups

### Error Handling

The API client provides error handling with status codes:

```javascript
try {
    const response = await API.login(username, password, code);
} catch (error) {
    if (error.isAuthError()) {
        // 401 - Authentication failed
    } else if (error.isForbidden()) {
        // 403 - Not authorized
    } else if (error.isNotFound()) {
        // 404 - Resource not found
    } else if (error.isServerError()) {
        // 500+ - Server error
    } else if (error.isValidationError()) {
        // 400/422 - Validation error
    }
}
```

## Browser Support

### Supported Browsers

- **Chrome**: Latest 2 versions
- **Firefox**: Latest 2 versions
- **Safari**: Latest 2 versions
- **Edge**: Latest 2 versions

### Required Features

- **ES6+ JavaScript**: Arrow functions, async/await, template literals
- **Fetch API**: For HTTP requests
- **localStorage**: For JWT token storage
- **CSS Grid/Flexbox**: For layout
- **CSS Variables**: For theming

### Fallbacks

- **Clipboard API**: Falls back to `document.execCommand('copy')` for older browsers
- **QR Code Library**: Loaded from CDN (works in all modern browsers)

## Performance

### Optimization Strategies

1. **Static Assets**:
   - Gzip compression enabled
   - Long-term caching (1 year) for CSS, JS, images
   - Cache-Control headers set

2. **Code Size**:
   - No framework overhead (vanilla JavaScript)
   - Minimal external dependencies (only QRCode.js)
   - Minified production builds (via CI/CD)

3. **Loading**:
   - Scripts loaded at end of HTML (non-blocking)
   - QRCode library loaded from CDN (cached across sites)

4. **Network**:
   - Same-origin API calls (no CORS overhead)
   - Relative URLs (no DNS lookups for API)

## Troubleshooting

### Common Issues

#### 1. API Calls Failing

**Symptoms**: Network errors, CORS errors, 404s

**Solutions**:

- Verify backend is running and accessible
- Check API base path (`/api`) is correct
- Verify ALB routing is configured correctly
- Check browser console for detailed error messages

#### 2. JWT Token Not Persisting

**Symptoms**: User logged out after page refresh

**Solutions**:

- Check browser localStorage is enabled
- Verify token is being stored: `localStorage.getItem('ldap2fa_token')`
- Check token expiration time
- Verify token format (should be JWT with 3 parts)

#### 3. QR Code Not Displaying

**Symptoms**: TOTP enrollment shows blank QR code

**Solutions**:

- Check QRCode.js library loaded from CDN
- Verify `otpauth://` URI format from backend
- Check browser console for JavaScript errors
- Try manual secret entry as fallback

#### 4. SMS Button Not Showing

**Symptoms**: SMS option disabled or hidden

**Solutions**:

- Check SMS is enabled: `API.getMfaMethods()` returns `sms_enabled: true`
- Verify user's MFA method is SMS
- Check username is entered in login form
- Verify backend SMS configuration

#### 5. Admin Features Not Visible

**Symptoms**: Admin menu items hidden

**Solutions**:

- Verify user is logged in with admin JWT
- Check JWT payload contains `is_admin: true`
- Verify user is member of admin LDAP group
- Check browser console for authentication errors

#### 6. Styles Not Loading

**Symptoms**: Unstyled page, broken layout

**Solutions**:

- Verify `styles.css` is accessible at `/css/styles.css`
- Check nginx configuration serves static files
- Verify file permissions in container
- Check browser console for 404 errors

### Debugging

#### Enable Debug Logging

Add console logging to `main.js`:

```javascript
// At top of App.init()
console.log('App initialized', {
    smsEnabled: this.smsEnabled,
    session: this.session,
    currentUser: this.currentUser
});
```

#### Check API Responses

In browser console:

```javascript
// Test API endpoint
API.healthCheck().then(console.log).catch(console.error);

// Check stored token
console.log('Token:', API.getToken());

// Decode JWT payload (without verification)
const token = API.getToken();
if (token) {
    const payload = JSON.parse(atob(token.split('.')[1]));
    console.log('JWT Payload:', payload);
}
```

#### Network Inspection

1. Open browser DevTools → Network tab
2. Filter by "XHR" or "Fetch"
3. Check request/response headers
4. Verify Authorization header contains Bearer token
5. Check response status codes and error messages

## Testing

### Manual Testing Checklist

#### Authentication

- [ ] Login with valid credentials and TOTP code
- [ ] Login with valid credentials and SMS code
- [ ] Login fails with invalid credentials
- [ ] Login fails with invalid verification code
- [ ] SMS send button appears for SMS users
- [ ] SMS code countdown timer works

#### Registration

- [ ] Signup form validates all fields
- [ ] Email verification link works
- [ ] Phone verification code works
- [ ] Resend buttons work with countdown
- [ ] Verification status updates correctly

#### Enrollment

- [ ] TOTP enrollment shows QR code
- [ ] QR code scans correctly in authenticator app
- [ ] Manual secret entry works
- [ ] Copy secret button works
- [ ] SMS enrollment sends code

#### Profile

- [ ] Profile loads user data
- [ ] Profile update works
- [ ] Verified email/phone are read-only
- [ ] Groups display correctly

#### Admin

- [ ] User list loads and filters work
- [ ] Group list loads and filters work
- [ ] Approve user modal shows groups
- [ ] Group CRUD operations work
- [ ] Member list displays correctly

## Contributing

### Code Style

- **JavaScript**: ES6+ syntax, camelCase for variables/functions
- **HTML**: Semantic HTML5, lowercase attributes
- **CSS**: BEM-like naming, CSS variables for theming
- **Comments**: JSDoc-style comments for functions

### Pull Request Process

1. Create feature branch
2. Make changes
3. Test locally
4. Update documentation if needed
5. Submit PR with description

## License

See main project LICENSE file.

## References

- [nginx Documentation](https://nginx.org/en/docs/)
- [FastAPI Backend Documentation](../backend/README.md)
- [Application Infrastructure README](../README.md)
- [MDN Web Docs](https://developer.mozilla.org/)
- [QRCode.js Documentation](https://github.com/soldair/node-qrcode)
