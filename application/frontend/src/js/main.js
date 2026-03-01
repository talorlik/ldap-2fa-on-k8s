/**
 * Main application logic for LDAP 2FA Frontend
 */

document.addEventListener('DOMContentLoaded', () => {
    // Initialize the application
    App.init();
});

/**
 * Escape HTML to prevent XSS attacks
 * Uses string replacement to avoid DOM-based escaping
 * @param {string} str - String to escape
 * @returns {string} Escaped string
 */
function escapeHtml(str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}

/**
 * Two distinct "active" concepts (no duplication):
 * - Application: appConfig.isActive from GET /api/app-config (can the service accept logins?).
 * - User: enforced by backend (ProfileStatus ACTIVE/REVOKED); frontend has no separate
 *   user-active flag; 401/403 from API or session restore failure indicate user state.
 */
const App = {
    // State
    smsEnabled: false,
    userMfaMethod: null,
    currentUser: null, // Store current signup user for verification
    /** Logged-in user state: { username, isAdmin, token }. Persisted via localStorage
     *  (API.tokenKey); restored in checkSession(), cleared in showLoggedOutState(). */
    session: null,
    groups: [], // Cache of groups for admin
    users: [], // Cache of users for admin
    sortState: { field: 'created_at', order: 'desc' },
    // Login MFA step state (after login/start)
    loginChallenge: null, // { challenge_token, totp_enrolled, sms_available }
    // Pending profile verification (after request-phone-change; show enter-code row until verified)
    pendingVerifyPhone: false,
    // Application-level only: GET /api/app-config (isActive, mode). Drives login/signup button.
    appConfig: null,

    /**
     * Remove login credentials from the URL so they never appear in Referer or
     * browser history. Strips password always; strips username only when password
     * is present (login leak). Leaves token/username for email verification links.
     */
    stripCredentialsFromUrl() {
        const url = new URL(window.location.href);
        if (!url.searchParams.has('password')) return;
        url.searchParams.delete('password');
        if (url.searchParams.has('username')) {
            url.searchParams.delete('username');
        }
        const clean = url.pathname + url.search + url.hash;
        window.history.replaceState({}, document.title, clean);
    },

    /**
     * Initialize the application
     */
    async init() {
        this.stripCredentialsFromUrl();
        this.setupTabs();
        this.setupLoginForm();
        this.setupForgotPassword();
        this.setupResetPasswordForm();
        this.setupSignupForm();
        this.setupMfaStepPanel();
        this.setupCopySecret();
        this.setupVerification();
        this.setupTopBar();
        this.setupProfile();
        this.setupProfileTabs();
        this.setupProfileVerification();
        this.setupProfileMfaSection();
        this.setupAdminUsers();
        this.setupAdminGroups();
        this.setupModals();

        this.populateCountryCodeSelects();

        // Check for reset password link (must run before other URL checks)
        this.checkResetPasswordToken();

        // Check if SMS is enabled
        await this.checkMfaMethods();

        // Fetch app config (isActive) so we can enable/disable login UI
        await this.fetchAppConfig();
        this.applyAppConfigUI();

        // Check for email verification token in URL
        this.checkEmailVerificationToken();

        // Check for existing session
        this.checkSession();
    },

    /**
     * Fetch app config from backend (isActive, mode). On failure assume active so
     * backend can return 503 if really down.
     */
    async fetchAppConfig() {
        try {
            this.appConfig = await API.getAppConfig();
        } catch (_) {
            this.appConfig = { isActive: true, mode: 'full' };
        }
    },

    /**
     * Apply app config to UI: show banner and disable login/signup when isActive false.
     */
    applyAppConfigUI() {
        const banner = document.getElementById('app-config-banner');
        const loginSubmit = document.querySelector('#login-form button[type="submit"]');
        const signupSubmit = document.querySelector('#signup-form button[type="submit"]');
        const active = this.appConfig && (this.appConfig.isActive ?? this.appConfig.is_active) !== false;
        if (banner) {
            if (active) {
                banner.classList.add('hidden');
            } else {
                banner.classList.remove('hidden');
            }
        }
        if (loginSubmit) {
            loginSubmit.disabled = !active;
        }
        if (signupSubmit) {
            signupSubmit.disabled = !active;
        }
    },

    /**
     * Restore logged-in state from persisted JWT. Token is in localStorage (API.tokenKey);
     * we decode payload to get username/is_admin and set App.session, then show app view.
     * Expired tokens are cleared. User-level disabled/revoked is enforced by the backend
     * (401/403 on subsequent API calls).
     */
    checkSession() {
        const token = API.getToken();
        if (token) {
            try {
                // Decode JWT payload (without verification)
                const payload = JSON.parse(atob(token.split('.')[1]));

                // Check if token is expired
                if (payload.exp * 1000 < Date.now()) {
                    API.clearToken();
                    return;
                }

                // Restore session
                this.session = {
                    username: payload.username,
                    isAdmin: payload.is_admin,
                    token: token,
                };

                this.showLoggedInState();
            } catch (e) {
                API.clearToken();
            }
        }
    },

    /**
     * Show logged in state with top bar and app view
     */
    showLoggedInState() {
        // Show top bar
        document.getElementById('top-bar').classList.remove('hidden');
        document.getElementById('user-display-name').textContent = this.session.username;

        // Show admin menu items if admin
        if (this.session.isAdmin) {
            document.getElementById('admin-menu-items').classList.remove('hidden');
        }

        // Switch to app view: hide auth view, show app view
        const authView = document.getElementById('auth-view');
        const appView = document.getElementById('app-view');
        if (authView) authView.classList.add('hidden');
        if (appView) appView.classList.remove('hidden');

        // Show profile section (only app-view sections are toggled)
        this.showSection('profile');

        // Adjust container for logged in state
        document.getElementById('main-container').classList.add('logged-in');
    },

    /**
     * Show logged out state
     */
    showLoggedOutState() {
        // Hide top bar
        document.getElementById('top-bar').classList.add('hidden');
        document.getElementById('admin-menu-items').classList.add('hidden');

        // Switch to auth view: show auth view, hide app view
        const authView = document.getElementById('auth-view');
        const appView = document.getElementById('app-view');
        const mfaPage = document.getElementById('mfa-page');
        if (appView) appView.classList.add('hidden');
        if (authView) authView.classList.remove('hidden');
        if (mfaPage) mfaPage.classList.add('hidden');

        // Show login tab and reset auth tab state
        const authTabContents = document.querySelectorAll('#auth-view .tab-content');
        authTabContents.forEach(el => {
            el.classList.remove('active');
            el.classList.add('hidden');
        });
        const loginTab = document.getElementById('login-tab');
        if (loginTab) {
            loginTab.classList.add('active');
            loginTab.classList.remove('hidden');
        }

        // Reset login view: show form, hide MFA step panel
        const loginForm = document.getElementById('login-form');
        const mfaPage = document.getElementById('mfa-page');
        if (loginForm) loginForm.classList.remove('hidden');
        if (mfaPage) mfaPage.classList.add('hidden');
        this.loginChallenge = null;

        // Adjust container
        document.getElementById('main-container').classList.remove('logged-in');

        // Clear session
        this.session = null;
        API.clearToken();
    },

    /**
     * Show a specific section
     */
    showSection(section) {
        this.hideAllSections();

        let sectionEl = null;
        switch (section) {
            case 'profile':
                sectionEl = document.getElementById('profile-section');
                if (sectionEl) {
                    sectionEl.classList.remove('hidden');
                    sectionEl.classList.add('active');
                }
                this.loadProfile();
                break;
            case 'admin-users':
                sectionEl = document.getElementById('admin-users-section');
                if (sectionEl) {
                    sectionEl.classList.remove('hidden');
                    sectionEl.classList.add('active');
                }
                this.loadAdminUsers();
                break;
            case 'admin-groups':
                sectionEl = document.getElementById('admin-groups-section');
                if (sectionEl) {
                    sectionEl.classList.remove('hidden');
                    sectionEl.classList.add('active');
                }
                this.loadAdminGroups();
                break;
        }
    },

    /**
     * Hide all app-view sections (profile, admin-users, admin-groups only)
     */
    hideAllSections() {
        const appView = document.getElementById('app-view');
        if (!appView) return;
        appView.querySelectorAll('.tab-content').forEach(el => {
            el.classList.remove('active');
            el.classList.add('hidden');
        });
    },

    /**
     * Setup top bar functionality
     */
    setupTopBar() {
        const userMenuBtn = document.getElementById('user-menu-btn');
        const userDropdown = document.getElementById('user-dropdown');
        if (!userMenuBtn || !userDropdown) return;

        // Toggle dropdown
        userMenuBtn.addEventListener('click', (e) => {
            e.stopPropagation();
            userDropdown.classList.toggle('hidden');
        });

        // Close dropdown when clicking outside
        document.addEventListener('click', () => {
            userDropdown.classList.add('hidden');
        });

        // Menu item handlers
        document.getElementById('menu-profile').addEventListener('click', (e) => {
            e.preventDefault();
            userDropdown.classList.add('hidden');
            this.showSection('profile');
        });

        document.getElementById('menu-admin-users').addEventListener('click', (e) => {
            e.preventDefault();
            userDropdown.classList.add('hidden');
            this.showSection('admin-users');
        });

        document.getElementById('menu-admin-groups').addEventListener('click', (e) => {
            e.preventDefault();
            userDropdown.classList.add('hidden');
            this.showSection('admin-groups');
        });

        document.getElementById('menu-logout').addEventListener('click', (e) => {
            e.preventDefault();
            userDropdown.classList.add('hidden');
            this.logout();
        });
    },

    /**
     * Logout
     */
    logout() {
        this.showLoggedOutState();
        this.showStatus('Logged out successfully', 'success');
    },

    /**
     * Check available MFA methods
     */
    async checkMfaMethods() {
        try {
            const response = await API.getMfaMethods();
            this.smsEnabled = response.sms_enabled;

            // Update SMS options in all forms
            this.updateSmsOptions();
        } catch (error) {
            console.warn('Could not fetch MFA methods:', error.message);
            this.smsEnabled = false;
        }
    },

    /**
     * Update SMS options based on availability
     */
    updateSmsOptions() {
        // Only update MFA step SMS option (used during login MFA enrollment)
        const smsOptions = document.querySelectorAll('#mfa-step-sms-option');
        smsOptions.forEach(option => {
            if (!this.smsEnabled) {
                option.classList.add('disabled');
                option.querySelector('input').disabled = true;
                option.querySelector('small').textContent = 'SMS not available';
            } else {
                option.classList.remove('disabled');
                option.querySelector('input').disabled = false;
            }
        });
    },

    /**
     * Check for email verification token in URL
     */
    async checkEmailVerificationToken() {
        const urlParams = new URLSearchParams(window.location.search);
        const token = urlParams.get('token');
        const username = urlParams.get('username');

        if (token && username) {
            try {
                const response = await API.verifyEmail(username, token);
                this.showStatus('Email verified! You can now click Save again to confirm your profile.', 'success');

                window.history.replaceState({}, document.title, window.location.pathname);

                if (this.currentUser && this.currentUser.username === username) {
                    this.updateVerificationStatus(response.profile_status);
                }
                if (this.session && this.session.username === username) {
                    await this.loadProfile();
                }
            } catch (error) {
                this.showStatus(error.message, 'error');
            }
        }
    },

    /**
     * Check for reset password link in hash (#reset-password?token=...&username=...)
     */
    checkResetPasswordToken() {
        const hash = window.location.hash.slice(1) || '';
        if (!hash.startsWith('reset-password')) return;
        const q = hash.indexOf('?');
        const params = q >= 0 ? new URLSearchParams(hash.substring(q + 1)) : new URLSearchParams();
        const token = params.get('token');
        const username = params.get('username');
        if (!token || !username) return;

        document.getElementById('reset-password-token').value = token;
        document.getElementById('reset-password-username').value = username;
        document.getElementById('auth-header').classList.add('hidden');
        document.getElementById('auth-tabs').classList.add('hidden');
        document.getElementById('login-tab').classList.add('hidden');
        document.getElementById('signup-tab').classList.add('hidden');
        document.getElementById('reset-password-section').classList.remove('hidden');
        document.getElementById('reset-password-section').classList.add('active');
    },

    /**
     * Setup forgot password link and panel
     */
    setupForgotPassword() {
        const link = document.getElementById('login-forgot-password');
        const backBtn = document.getElementById('forgot-password-back-btn');
        const loginForm = document.getElementById('login-form');
        const forgotPanel = document.getElementById('forgot-password-panel');
        const form = document.getElementById('forgot-password-form');
        const resultContainer = document.getElementById('forgot-password-result');

    if (!link || !forgotPanel || !form) return;

        link.addEventListener('click', (e) => {
            e.preventDefault();
            loginForm.classList.add('hidden');
            document.getElementById('mfa-page').classList.add('hidden');
            document.getElementById('login-result').classList.add('hidden');
            forgotPanel.classList.remove('hidden');
            resultContainer.classList.add('hidden');
        });

        backBtn.addEventListener('click', () => {
            forgotPanel.classList.add('hidden');
            loginForm.classList.remove('hidden');
            resultContainer.classList.add('hidden');
        });

        // Form submission handled by handleForgotPasswordSubmit via onsubmit
    },

    async doForgotPasswordSubmit() {
        const form = document.getElementById('forgot-password-form');
        const resultContainer = document.getElementById('forgot-password-result');
        if (!form || !resultContainer) return;

        const submitBtn = form.querySelector('button[type="submit"]');
        const email = form.querySelector('#forgot-password-email').value.trim();
        if (!email) return;

        submitBtn.classList.add('loading');
        submitBtn.disabled = true;
        resultContainer.classList.add('hidden');

        try {
            await API.forgotPassword(email);
            resultContainer.innerHTML = `
                <h3>✓ Check your email</h3>
                <p>If an account exists with this email, you will receive a password reset link shortly.</p>
            `;
            resultContainer.className = 'result-container success';
            resultContainer.classList.remove('hidden');
        } catch (error) {
            resultContainer.innerHTML = `
                <h3>❌ Error</h3>
                <p>${escapeHtml(error.message)}</p>
            `;
            resultContainer.className = 'result-container error';
            resultContainer.classList.remove('hidden');
        } finally {
            submitBtn.classList.remove('loading');
            submitBtn.disabled = false;
        }
    },

    /**
     * Setup reset password form (from email link)
     */
    setupResetPasswordForm() {
        // Form submission handled by handleResetPasswordSubmit via onsubmit
    },

    async doResetPasswordSubmit() {
        const form = document.getElementById('reset-password-form');
        const resultContainer = document.getElementById('reset-password-result');
        if (!form) return;

        const submitBtn = form.querySelector('button[type="submit"]');
        const token = document.getElementById('reset-password-token').value;
        const username = document.getElementById('reset-password-username').value;
        const newPassword = form.querySelector('#reset-new-password').value;
        const confirmPassword = form.querySelector('#reset-confirm-password').value;

        if (newPassword !== confirmPassword) {
            resultContainer.innerHTML = '<h3>❌ Passwords do not match</h3>';
            resultContainer.className = 'result-container error';
            resultContainer.classList.remove('hidden');
            return;
        }
        if (newPassword.length < 8) {
            resultContainer.innerHTML = '<h3>❌ Password must be at least 8 characters</h3>';
            resultContainer.className = 'result-container error';
            resultContainer.classList.remove('hidden');
            return;
        }

        submitBtn.classList.add('loading');
        submitBtn.disabled = true;
        resultContainer.classList.add('hidden');

        try {
            await API.resetPassword(token, username, newPassword, confirmPassword);
            resultContainer.innerHTML = `
                <h3>✓ Password reset successfully</h3>
                <p>You can now log in with your new password.</p>
            `;
            resultContainer.className = 'result-container success';
            resultContainer.classList.remove('hidden');
            window.history.replaceState({}, document.title, window.location.pathname + window.location.search);
            this.showStatus('Password reset successfully. You can now log in.', 'success');
            setTimeout(() => {
                document.getElementById('reset-password-section').classList.add('hidden');
                this.showLoggedOutState();
            }, 2000);
        } catch (error) {
            resultContainer.innerHTML = `
                <h3>❌ Reset failed</h3>
                <p>${escapeHtml(error.message)}</p>
            `;
            resultContainer.className = 'result-container error';
            resultContainer.classList.remove('hidden');
        } finally {
            submitBtn.classList.remove('loading');
            submitBtn.disabled = false;
        }
    },

    /**
     * Setup tab navigation (auth view only: Login / Sign Up)
     */
    setupTabs() {
        const tabButtons = document.querySelectorAll('#auth-view .tab-btn');
        const tabContents = document.querySelectorAll('#auth-view .tab-content');

        tabButtons.forEach(button => {
            button.addEventListener('click', () => {
                const targetTab = button.dataset.tab;

                // Update button states
                tabButtons.forEach(btn => btn.classList.remove('active'));
                button.classList.add('active');

                // Update content visibility (auth-view tabs only)
                tabContents.forEach(content => {
                    content.classList.remove('active');
                    content.classList.add('hidden');
                    if (content.id === `${targetTab}-tab`) {
                        content.classList.add('active');
                        content.classList.remove('hidden');
                    }
                });

                // Clear previous results
                this.clearResults();
            });
        });
    },

    /**
     * Setup login form (handled via onsubmit handler)
     */
    setupLoginForm() {
        // Form submission handled by handleLoginFormSubmit via onsubmit
    },

    /**
     * Login form submit logic (called from handleLoginFormSubmit)
     */
    async doLoginFormSubmit() {
        const form = document.getElementById('login-form');
        const resultContainer = document.getElementById('login-result');
        if (!form || !resultContainer) return;

        const submitBtn = form.querySelector('button[type="submit"]');
        const username = form.querySelector('#login-username').value.trim();
        const password = form.querySelector('#login-password').value;
        const rememberMe = form.querySelector('#login-remember-me')?.checked ?? false;

        submitBtn.classList.add('loading');
        submitBtn.disabled = true;
        resultContainer.classList.add('hidden');

        try {
            const response = await API.loginStart(username, password, rememberMe);

            this.loginChallenge = {
                challenge_token: response.challenge_token,
                totp_enrolled: response.totp_enrolled,
                sms_available: response.sms_available,
            };

            form.classList.add('hidden');
            this.showMfaStepPanel();
        } catch (error) {
            const message = (error && error.message) || 'Login failed. Please try again.';
            resultContainer.innerHTML = `
                <h3>❌ Login Failed</h3>
                <p>${escapeHtml(message)}</p>
            `;
            resultContainer.className = 'result-container error';
            resultContainer.classList.remove('hidden');
            this.showStatus(message, 'error');
        } finally {
            submitBtn.classList.remove('loading');
            submitBtn.disabled = false;
        }
    },

    /**
     * Show 2FA page (method selection / enrollment / authentication)
     */
    showMfaStepPanel() {
        const mfaPage = document.getElementById('mfa-page');
        const totpOption = document.getElementById('mfa-step-totp-option');
        const smsOption = document.getElementById('mfa-step-sms-option');
        const totpHint = document.getElementById('mfa-step-totp-hint');

        if (!this.loginChallenge || !mfaPage) return;

        totpOption.classList.remove('disabled');
        totpOption.querySelector('input').disabled = false;
        totpHint.textContent = this.loginChallenge.totp_enrolled
            ? 'Enter code from your app'
            : 'Set up Authenticator app (one-time)';

        if (this.loginChallenge.sms_available) {
            smsOption.classList.remove('disabled');
            smsOption.querySelector('input').disabled = false;
        } else {
            smsOption.classList.add('disabled');
            smsOption.querySelector('input').disabled = true;
        }

        this.updateMfaStepMethodVisibility();

        // Switch to 2FA page: hide login/signup tabs and content, show mfa-page
        document.getElementById('auth-tabs').classList.add('hidden');
        document.querySelectorAll('#auth-view .tab-content').forEach(el => {
            el.classList.remove('active');
            el.classList.add('hidden');
        });
        mfaPage.classList.remove('hidden');
    },

    /**
     * Update MFA step UI based on selected method (TOTP vs SMS)
     */
    updateMfaStepMethodVisibility() {
        const method = document.querySelector('input[name="mfa_step_method"]:checked')?.value || 'totp';
        const totpSetup = document.getElementById('mfa-step-totp-setup');
        const smsSend = document.getElementById('mfa-step-sms-send');
        const smsStatus = document.getElementById('mfa-step-sms-status');

        totpSetup.classList.add('hidden');
        smsSend.classList.add('hidden');
        smsStatus.classList.add('hidden');

        if (method === 'totp') {
            if (!this.loginChallenge.totp_enrolled) {
                totpSetup.classList.remove('hidden');
                this.fetchTotpSetupIfNeeded();
            }
        } else {
            smsSend.classList.remove('hidden');
        }
    },

    /**
     * Fetch TOTP setup (QR + secret) when user selects TOTP and is not enrolled
     */
    async fetchTotpSetupIfNeeded() {
        if (!this.loginChallenge || this.loginChallenge.totp_enrolled) return;
        if (document.getElementById('mfa-step-secret').textContent) return; // already fetched

        const qrDiv = document.getElementById('mfa-step-qr');
        const secretEl = document.getElementById('mfa-step-secret');
        const setupErrorEl = document.getElementById('mfa-step-totp-setup-error');

        setupErrorEl.classList.add('hidden');
        setupErrorEl.textContent = '';

        try {
            const response = await API.loginTotpSetup(this.loginChallenge.challenge_token);
            qrDiv.innerHTML = '';
            if (typeof QRCode !== 'undefined') {
                const canvas = document.createElement('canvas');
                qrDiv.appendChild(canvas);
                await QRCode.toCanvas(canvas, response.otpauth_uri, {
                    width: 200,
                    margin: 2,
                    color: { dark: '#1e293b', light: '#ffffff' },
                });
            }
            secretEl.textContent = response.secret;
        } catch (error) {
            const isUnauthorized = error.statusCode === 401;
            const message = isUnauthorized
                ? 'Your login session expired or is invalid. Please click Back and sign in again.'
                : (error.message || 'Failed to load setup.');
            setupErrorEl.textContent = message;
            setupErrorEl.classList.remove('hidden');
            this.showStatus(message, 'error');
        }
    },

    /**
     * Setup MFA page (method selector, verify, back, copy secret, send SMS)
     */
    setupMfaStepPanel() {
        const mfaPage = document.getElementById('mfa-page');
        const backBtn = document.getElementById('mfa-step-back-btn');
        const verifyBtn = document.getElementById('mfa-step-verify-btn');
        const codeInput = document.getElementById('mfa-step-code');
        const methodRadios = document.querySelectorAll('input[name="mfa_step_method"]');
        const sendSmsBtn = document.getElementById('mfa-step-send-sms-btn');
        const smsStatus = document.getElementById('mfa-step-sms-status');

        backBtn.addEventListener('click', () => {
            this.loginChallenge = null;
            if (mfaPage) mfaPage.classList.add('hidden');
            document.getElementById('auth-tabs').classList.remove('hidden');
            const loginTab = document.getElementById('login-tab');
            if (loginTab) {
                loginTab.classList.add('active');
                loginTab.classList.remove('hidden');
            }
            document.querySelectorAll('#auth-view .tab-content').forEach(el => {
                if (el.id !== 'login-tab') {
                    el.classList.remove('active');
                    el.classList.add('hidden');
                }
            });
            const loginForm = document.getElementById('login-form');
            if (loginForm) loginForm.classList.remove('hidden');
            document.getElementById('mfa-step-secret').textContent = '';
            document.getElementById('mfa-step-qr').innerHTML = '';
            const setupErrorEl = document.getElementById('mfa-step-totp-setup-error');
            if (setupErrorEl) {
                setupErrorEl.textContent = '';
                setupErrorEl.classList.add('hidden');
            }
            codeInput.value = '';
        });

        methodRadios.forEach(radio => {
            radio.addEventListener('change', () => this.updateMfaStepMethodVisibility());
        });

        sendSmsBtn.addEventListener('click', async () => {
            if (!this.loginChallenge) return;
            sendSmsBtn.disabled = true;
            sendSmsBtn.textContent = 'Sending...';
            try {
                const response = await API.sendSmsCodeWithChallenge(this.loginChallenge.challenge_token);
                smsStatus.textContent = `Code sent. Expires in ${response.expires_in_seconds}s`;
                smsStatus.classList.remove('hidden');
                this.showStatus('Verification code sent!', 'success');
                this.startSmsCountdown(sendSmsBtn, response.expires_in_seconds);
            } catch (error) {
                this.showStatus(error.message, 'error');
                sendSmsBtn.disabled = false;
                sendSmsBtn.textContent = 'Send SMS code';
            }
        });

        // MFA form submission handled by handleMfaStepFormSubmit via onsubmit
    },

    async doMfaStepFormSubmit() {
        if (!this.loginChallenge) return;
        const codeInput = document.getElementById('mfa-step-code');
        const verifyBtn = document.getElementById('mfa-step-verify-btn');
        if (!codeInput || !verifyBtn) return;

        const code = codeInput.value.trim();
        if (!/^\d{6}$/.test(code)) {
            this.showStatus('Please enter a valid 6-digit code', 'error');
            return;
        }
        const method = document.querySelector('input[name="mfa_step_method"]:checked')?.value || 'totp';

        verifyBtn.querySelector('.btn-text').classList.add('hidden');
        verifyBtn.querySelector('.btn-loading').classList.remove('hidden');
        verifyBtn.disabled = true;

        try {
            const response = await API.loginVerify(
                this.loginChallenge.challenge_token,
                method,
                code
            );
            if (response.token) {
                API.setToken(response.token);
                this.session = {
                    username: response.username,
                    isAdmin: response.is_admin,
                    token: response.token,
                };
                this.loginChallenge = null;
                const mfaPageEl = document.getElementById('mfa-page');
                if (mfaPageEl) mfaPageEl.classList.add('hidden');
                document.getElementById('login-form').reset();
                codeInput.value = '';
                this.showStatus('Login successful!', 'success');
                this.showLoggedInState();
            }
        } catch (error) {
            this.showStatus(error.message || 'Invalid code', 'error');
        } finally {
            verifyBtn.querySelector('.btn-text').classList.remove('hidden');
            verifyBtn.querySelector('.btn-loading').classList.add('hidden');
            verifyBtn.disabled = false;
        }
    },

    /**
     * Setup signup form handling
     */
    setupSignupForm() {
        // Form submission handled by handleSignupFormSubmit via onsubmit
    },

    async doSignupFormSubmit() {
        const form = document.getElementById('signup-form');
        const resultContainer = document.getElementById('signup-result');
        const verificationPanel = document.getElementById('verification-status');
        if (!form || !resultContainer) return;

        const submitBtn = form.querySelector('button[type="submit"]');
        const password = form.querySelector('#signup-password').value;
        const confirmPassword = form.querySelector('#signup-confirm-password').value;

        // Validate passwords match
        if (password !== confirmPassword) {
            this.showStatus('Passwords do not match', 'error');
            return;
        }

        const userData = {
            username: form.querySelector('#signup-username').value.trim().toLowerCase(),
            email: form.querySelector('#signup-email').value.trim().toLowerCase(),
            firstName: form.querySelector('#signup-firstname').value.trim(),
            lastName: form.querySelector('#signup-lastname').value.trim(),
            phoneCountryCode: form.querySelector('#signup-country-code').value,
            phoneNumber: form.querySelector('#signup-phone').value.trim(),
            password: password,
        };

        submitBtn.classList.add('loading');
        submitBtn.disabled = true;
        resultContainer.classList.add('hidden');
        if (verificationPanel) verificationPanel.classList.add('hidden');

        try {
            const response = await API.signup(userData);

            this.currentUser = {
                username: userData.username,
                email: userData.email,
            };

            // Show verification panel
            form.classList.add('hidden');
            if (verificationPanel) verificationPanel.classList.remove('hidden');

            // Update verification hints
            if (response.email_verification_sent) {
                const hint = document.getElementById('email-verify-hint');
                if (hint) hint.textContent = `Check ${userData.email} for verification link`;
            }
            if (response.phone_verification_sent) {
                const hint = document.getElementById('phone-verify-hint');
                if (hint) hint.textContent =
                    `Enter code sent to ${userData.phoneCountryCode}${userData.phoneNumber}`;
            }

            this.showStatus('Account created! Please verify your email and phone.', 'success');

        } catch (error) {
            resultContainer.innerHTML = `
                <h3>❌ Signup Failed</h3>
                <p>${escapeHtml(error.message)}</p>
            `;
            resultContainer.className = 'result-container error';
            resultContainer.classList.remove('hidden');

            this.showStatus(error.message, 'error');
        } finally {
            submitBtn.classList.remove('loading');
            submitBtn.disabled = false;
        }
    },

    /**
     * Setup verification functionality
     */
    setupVerification() {
        const resendEmailBtn = document.getElementById('resend-email-btn');
        const resendPhoneBtn = document.getElementById('resend-phone-btn');
        const verifyPhoneBtn = document.getElementById('verify-phone-btn');
        const phoneCodeInput = document.getElementById('phone-verify-code');
        if (!resendEmailBtn || !resendPhoneBtn || !verifyPhoneBtn) return;

        // Resend email verification
        resendEmailBtn.addEventListener('click', async () => {
            if (!this.currentUser) return;

            resendEmailBtn.disabled = true;
            resendEmailBtn.textContent = 'Sending...';

            try {
                await API.resendVerification(this.currentUser.username, 'email');
                this.showStatus('Verification email sent!', 'success');

                // Countdown before allowing another resend
                this.startResendCountdown(resendEmailBtn, 60);
            } catch (error) {
                this.showStatus(error.message, 'error');
                resendEmailBtn.disabled = false;
                resendEmailBtn.textContent = 'Resend';
            }
        });

        // Resend phone verification
        resendPhoneBtn.addEventListener('click', async () => {
            if (!this.currentUser) return;

            resendPhoneBtn.disabled = true;
            resendPhoneBtn.textContent = 'Sending...';

            try {
                await API.resendVerification(this.currentUser.username, 'phone');
                this.showStatus('Verification code sent!', 'success');

                this.startResendCountdown(resendPhoneBtn, 60);
            } catch (error) {
                this.showStatus(error.message, 'error');
                resendPhoneBtn.disabled = false;
                resendPhoneBtn.textContent = 'Resend';
            }
        });

        // Verify phone
        verifyPhoneBtn.addEventListener('click', async () => {
            if (!this.currentUser) return;

            const code = phoneCodeInput.value.trim();
            if (!/^\d{6}$/.test(code)) {
                this.showStatus('Please enter a valid 6-digit code', 'error');
                return;
            }

            verifyPhoneBtn.disabled = true;
            verifyPhoneBtn.textContent = 'Verifying...';

            try {
                const response = await API.verifyPhone(this.currentUser.username, code);

                document.getElementById('phone-verify-status').textContent = '✅';
                document.getElementById('phone-verify-hint').textContent = 'Verified!';
                phoneCodeInput.disabled = true;
                verifyPhoneBtn.classList.add('hidden');

                this.showStatus('Phone verified successfully!', 'success');
                this.updateVerificationStatus(response.profile_status);

            } catch (error) {
                this.showStatus(error.message, 'error');
                verifyPhoneBtn.disabled = false;
                verifyPhoneBtn.textContent = 'Verify';
            }
        });
    },

    /**
     * Update verification status display
     */
    updateVerificationStatus(status) {
        if (status === 'complete') {
            // All verifications complete
            document.getElementById('email-verify-status').textContent = '✅';
            document.getElementById('phone-verify-status').textContent = '✅';
            document.getElementById('verification-complete').classList.remove('hidden');
            document.querySelector('.phone-verify-input').classList.add('hidden');
            document.querySelectorAll('.verification-item button').forEach(btn => {
                btn.classList.add('hidden');
            });
        }
    },

    /**
     * Start countdown for resend buttons
     */
    startResendCountdown(button, seconds) {
        let remaining = seconds;
        button.disabled = true;

        const interval = setInterval(() => {
            remaining--;
            button.textContent = `Resend (${remaining}s)`;

            if (remaining <= 0) {
                clearInterval(interval);
                button.textContent = 'Resend';
                button.disabled = false;
            }
        }, 1000);
    },

    /**
     * Start countdown for SMS resend button
     */
    startSmsCountdown(button, seconds) {
        let remaining = seconds;
        button.disabled = true;

        const interval = setInterval(() => {
            remaining--;
            button.textContent = `Resend (${remaining}s)`;

            if (remaining <= 0) {
                clearInterval(interval);
                button.textContent = 'Send SMS';
                button.disabled = false;
            }
        }, 1000);
    },

    /**
     * Setup copy secret button (MFA step TOTP setup)
     */
    setupCopySecret() {
        const copyBtn = document.getElementById('mfa-step-copy-secret');
        const secretCode = document.getElementById('mfa-step-secret');
        if (!copyBtn || !secretCode) return;

        copyBtn.addEventListener('click', async () => {
            const secret = secretCode.textContent;
            if (!secret) return;

            try {
                await navigator.clipboard.writeText(secret);
                this.showStatus('Secret copied to clipboard!', 'success');
                const originalText = copyBtn.textContent;
                copyBtn.textContent = 'Copied!';
                setTimeout(() => { copyBtn.textContent = originalText; }, 2000);
            } catch (err) {
                const textArea = document.createElement('textarea');
                textArea.value = secret;
                document.body.appendChild(textArea);
                textArea.select();
                document.execCommand('copy');
                document.body.removeChild(textArea);
                this.showStatus('Secret copied to clipboard!', 'success');
            }
        });
    },

    /**
     * Populate country code dropdowns from COUNTRY_CODES (country-codes.js).
     * Ensures profile and signup phone selects show all countries with flags.
     */
    populateCountryCodeSelects() {
        if (typeof window.COUNTRY_CODES === 'undefined' || !Array.isArray(window.COUNTRY_CODES)) {
            return;
        }
        const list = window.COUNTRY_CODES.slice()
            .filter((c) => c.dial_code && (c.flag != null && c.flag !== ''))
            .sort((a, b) => (a.name || '').localeCompare(b.name || ''));
        const addOptions = (selectEl) => {
            if (!selectEl) return;
            const placeholder = selectEl.querySelector('option[value=""]');
            selectEl.innerHTML = '';
            if (placeholder) {
                selectEl.appendChild(placeholder);
            } else {
                const empty = document.createElement('option');
                empty.value = '';
                empty.textContent = 'Country code';
                selectEl.appendChild(empty);
            }
            list.forEach((c) => {
                const opt = document.createElement('option');
                opt.value = c.dial_code;
                opt.textContent = c.flag + ' ' + c.dial_code;
                selectEl.appendChild(opt);
            });
        };
        addOptions(document.getElementById('profile-country-code'));
        addOptions(document.getElementById('signup-country-code'));

        this.makeCountryCodeSearchable('profile-country-code');
        this.makeCountryCodeSearchable('signup-country-code');
    },

    /**
     * Convert a country code select into a searchable dropdown.
     * Keeps the original select in DOM (hidden) for form submission.
     */
    makeCountryCodeSearchable(selectId) {
        const select = document.getElementById(selectId);
        if (!select || typeof window.COUNTRY_CODES === 'undefined') return;

        const list = window.COUNTRY_CODES.slice()
            .filter((c) => c.dial_code && (c.flag != null && c.flag !== ''))
            .sort((a, b) => (a.name || '').localeCompare(b.name || ''));

        const wrapper = document.createElement('div');
        wrapper.className = 'country-code-search-wrapper';

        const trigger = document.createElement('button');
        trigger.type = 'button';
        trigger.className = 'country-code-trigger';
        trigger.setAttribute('aria-haspopup', 'listbox');
        trigger.setAttribute('aria-expanded', 'false');
        const selectedOpt = select.options[select.selectedIndex];
        trigger.textContent = selectedOpt ? selectedOpt.textContent : 'Country code';

        const dropdown = document.createElement('div');
        dropdown.className = 'country-code-dropdown';
        dropdown.setAttribute('role', 'listbox');

        const searchInput = document.createElement('input');
        searchInput.type = 'text';
        searchInput.className = 'country-code-search';
        searchInput.placeholder = 'Search country or code...';
        searchInput.setAttribute('autocomplete', 'off');

        const optionsContainer = document.createElement('div');
        optionsContainer.className = 'country-code-options';

        list.forEach((c) => {
            const item = document.createElement('div');
            item.className = 'country-code-option';
            item.setAttribute('role', 'option');
            item.dataset.value = c.dial_code;
            item.dataset.search = (c.name + ' ' + c.dial_code).toLowerCase();
            item.textContent = c.flag + ' ' + c.dial_code + ' ' + c.name;
            optionsContainer.appendChild(item);
        });

        dropdown.appendChild(searchInput);
        dropdown.appendChild(optionsContainer);

        select.parentNode.insertBefore(wrapper, select);
        wrapper.appendChild(select);
        wrapper.appendChild(trigger);
        wrapper.appendChild(dropdown);

        select.classList.add('country-code-select-hidden');

        const updateTrigger = () => {
            const opt = select.options[select.selectedIndex];
            trigger.textContent = opt ? opt.textContent : 'Country code';
        };

        const closeDropdown = () => {
            dropdown.classList.remove('open');
            trigger.setAttribute('aria-expanded', 'false');
            searchInput.value = '';
            list.forEach((c, i) => {
                optionsContainer.children[i].classList.remove('hidden');
            });
        };

        const filterOptions = (q) => {
            const lower = q.trim().toLowerCase();
            Array.from(optionsContainer.children).forEach((el) => {
                el.classList.toggle('hidden', lower && !el.dataset.search.includes(lower));
            });
        };

        trigger.addEventListener('click', (e) => {
            e.preventDefault();
            const isOpen = dropdown.classList.toggle('open');
            trigger.setAttribute('aria-expanded', isOpen);
            if (isOpen) {
                searchInput.focus();
                filterOptions(searchInput.value);
            }
        });

        searchInput.addEventListener('input', () => filterOptions(searchInput.value));
        searchInput.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                closeDropdown();
                trigger.focus();
            }
        });

        optionsContainer.addEventListener('click', (e) => {
            const item = e.target.closest('.country-code-option');
            if (!item || item.classList.contains('hidden')) return;
            select.value = item.dataset.value;
            updateTrigger();
            closeDropdown();
        });

        document.addEventListener('click', (e) => {
            if (dropdown.classList.contains('open') && !wrapper.contains(e.target)) {
                closeDropdown();
            }
        });

        this.updateCountryCodeTrigger = this.updateCountryCodeTrigger || {};
        this.updateCountryCodeTrigger[selectId] = updateTrigger;
    },

    /**
     * Update the visible trigger text for a country code select (e.g. after loadProfile).
     */
    updateCountryCodeTriggerText(selectId) {
        const fn = this.updateCountryCodeTrigger && this.updateCountryCodeTrigger[selectId];
        if (typeof fn === 'function') fn();
    },

    /**
     * Setup profile functionality
     */
    toggleProfilePasswordFields(enabled) {
        const fields = document.querySelectorAll('.profile-password-fields input');
        fields.forEach((el) => {
            el.disabled = !enabled;
        });
    },

    setupProfile() {
        const form = document.getElementById('profile-form');
        if (!form) return;

        const changePwdCheckbox = document.getElementById('profile-change-password-checkbox');
        if (changePwdCheckbox) {
            changePwdCheckbox.addEventListener('change', () => {
                this.toggleProfilePasswordFields(changePwdCheckbox.checked);
            });
            this.toggleProfilePasswordFields(changePwdCheckbox.checked);
        }

        // Form submission handled by handleProfileFormSubmit via onsubmit
    },

    async doProfileFormSubmit() {
        const form = document.getElementById('profile-form');
        if (!form || !this.session) return;

        const submitBtn = form.querySelector('button[type="submit"]');
        const errorEl = document.getElementById('profile-password-error');
        const changePwdCheckbox = document.getElementById('profile-change-password-checkbox');
        const wantToChangePwd = changePwdCheckbox?.checked ?? false;
        const currentPwd = document.getElementById('profile-current-password')?.value;
        const newPwd = document.getElementById('profile-new-password')?.value;
        const confirmPwd = document.getElementById('profile-confirm-password')?.value;

        if (errorEl) {
            errorEl.textContent = '';
            errorEl.classList.add('hidden');
        }

        if (wantToChangePwd && (currentPwd || newPwd || confirmPwd)) {
            if (!currentPwd?.trim()) {
                this.showStatus('Enter your current password to change it.', 'error');
                if (errorEl) {
                    errorEl.textContent = 'Enter your current password.';
                    errorEl.classList.remove('hidden');
                    errorEl.classList.add('form-error');
                }
                return;
            }
            if (!newPwd?.trim()) {
                this.showStatus('Enter a new password.', 'error');
                if (errorEl) {
                    errorEl.textContent = 'Enter a new password.';
                    errorEl.classList.remove('hidden');
                    errorEl.classList.add('form-error');
                }
                return;
            }
            if (newPwd.length < 8) {
                this.showStatus('New password must be at least 8 characters.', 'error');
                if (errorEl) {
                    errorEl.textContent = 'New password must be at least 8 characters.';
                    errorEl.classList.remove('hidden');
                    errorEl.classList.add('form-error');
                }
                return;
            }
            if (newPwd !== confirmPwd) {
                this.showStatus('New password and confirmation do not match.', 'error');
                if (errorEl) {
                    errorEl.textContent = 'New password and confirmation do not match.';
                    errorEl.classList.remove('hidden');
                    errorEl.classList.add('form-error');
                }
                return;
            }
        }

        submitBtn.classList.add('loading');
        submitBtn.disabled = true;

        const email = document.getElementById('profile-email').value.trim();
        const phoneCountryCode = document.getElementById('profile-country-code').value;
        const phoneNumber = document.getElementById('profile-phone').value.trim();

        try {
            const profile = await API.getProfile(this.session.username);
            const emailChanged = email && email.toLowerCase() !== (profile.email || '').toLowerCase();
            const phoneChanged =
                (phoneCountryCode !== (profile.phone_country_code || '')) ||
                (phoneNumber !== (profile.phone_number || ''));

            const needEmailVerify = emailChanged && profile.email_verified;
            const needPhoneVerify = phoneChanged && profile.phone_verified;
            if (needEmailVerify || needPhoneVerify) {
                if (needEmailVerify) {
                    await API.requestEmailChange(email);
                }
                if (needPhoneVerify) {
                    await API.requestPhoneChange(phoneCountryCode, phoneNumber);
                    this.pendingVerifyPhone = true;
                }
                const parts = [];
                if (needEmailVerify) parts.push('email (click the link we sent)');
                if (needPhoneVerify) parts.push('phone (enter the code below)');
                this.showStatus(
                    'Verification sent. Please verify your new ' + parts.join(' and ') + ', then click Save again.',
                    'success',
                );
                await this.loadProfile();
                submitBtn.classList.remove('loading');
                submitBtn.disabled = false;
                return;
            }

            const updates = {};
            const firstName = document.getElementById('profile-firstname').value.trim();
            const lastName = document.getElementById('profile-lastname').value.trim();
            if (firstName) updates.first_name = firstName;
            if (lastName) updates.last_name = lastName;
            updates.email = email;
            updates.phone_country_code = phoneCountryCode;
            updates.phone_number = phoneNumber;

            if (wantToChangePwd && currentPwd && newPwd && confirmPwd) {
                updates.current_password = currentPwd;
                updates.new_password = newPwd;
                updates.confirm_password = confirmPwd;
            }

            await API.updateProfile(this.session.username, updates);
            this.showStatus('Profile updated successfully', 'success');
            if (wantToChangePwd && (currentPwd || newPwd || confirmPwd)) {
                document.getElementById('profile-current-password').value = '';
                document.getElementById('profile-new-password').value = '';
                document.getElementById('profile-confirm-password').value = '';
                const cb = document.getElementById('profile-change-password-checkbox');
                if (cb) cb.checked = false;
                this.toggleProfilePasswordFields(false);
            }
            await this.loadProfile();
        } catch (error) {
            this.showStatus(error.message, 'error');
        } finally {
            submitBtn.classList.remove('loading');
            submitBtn.disabled = false;
        }
    },

    /**
     * Setup profile tab navigation (Personal Details | Security).
     */
    setupProfileTabs() {
        const container = document.getElementById('profile-section');
        if (!container) return;

        const tabButtons = container.querySelectorAll('#profile-tabs .tab-btn');
        const tabContents = container.querySelectorAll('.profile-tab-content');

        tabButtons.forEach(button => {
            button.addEventListener('click', () => {
                const targetTab = button.dataset.tab;

                tabButtons.forEach(btn => btn.classList.remove('active'));
                button.classList.add('active');

                tabContents.forEach(content => {
                    content.classList.remove('active');
                    content.classList.add('hidden');
                    if (content.id === `profile-${targetTab}-tab`) {
                        content.classList.add('active');
                        content.classList.remove('hidden');
                    }
                });
            });
        });
    },

    /**
     * Load profile data
     */
    async loadProfile() {
        if (!this.session) return;

        try {
            const profile = await API.getProfile(this.session.username);

            document.getElementById('profile-username').value = profile.username;
            document.getElementById('profile-firstname').value = profile.first_name;
            document.getElementById('profile-lastname').value = profile.last_name;
            document.getElementById('profile-email').value = profile.email;

            const countrySelect = document.getElementById('profile-country-code');
            const code = profile.phone_country_code || '';
            countrySelect.value = code;
            if (code && countrySelect.value !== code) {
                const opt = document.createElement('option');
                opt.value = code;
                opt.textContent = code;
                countrySelect.appendChild(opt);
                countrySelect.value = code;
            }
            this.updateCountryCodeTriggerText('profile-country-code');
            document.getElementById('profile-phone').value = profile.phone_number;
            document.getElementById('profile-status').value = profile.status.toUpperCase();

            // 2FA methods list and add buttons
            this.renderProfileMfaMethods(profile);

            // Email and phone are always editable on profile; changing requires re-verification after save
            const emailInput = document.getElementById('profile-email');
            const phoneInput = document.getElementById('profile-phone');
            const countryCodeSelect = document.getElementById('profile-country-code');
            emailInput.readOnly = false;
            emailInput.classList.remove('readonly-input');
            phoneInput.readOnly = false;
            phoneInput.classList.remove('readonly-input');
            countryCodeSelect.disabled = false;
            const wrapper = countryCodeSelect.closest('.country-code-search-wrapper');
            if (wrapper) {
                const trigger = wrapper.querySelector('.country-code-trigger');
                if (trigger) trigger.disabled = false;
            }
            document.getElementById('profile-email-hint').textContent =
                'Changing email will require verification after saving.';
            document.getElementById('profile-phone-hint').textContent =
                'Changing phone will require verification after saving.';

            // Show or hide profile verification block (when logged in, email or phone unverified)
            this.updateProfileVerificationBlock(profile);

            // 2FA methods list is rendered in renderProfileMfaMethods(profile) above

            // Display groups
            const groupsContainer = document.getElementById('profile-groups');
            if (profile.groups && profile.groups.length > 0) {
                groupsContainer.innerHTML = profile.groups.map(g =>
                    `<span class="group-badge">${escapeHtml(g.name)}</span>`
                ).join('');
            } else {
                groupsContainer.innerHTML = '<span class="no-groups">No groups assigned</span>';
            }

        } catch (error) {
            this.showStatus('Failed to load profile', 'error');
        }
    },

    /**
     * Show or hide the profile verification block and wire buttons (when email or phone unverified).
     */
    updateProfileVerificationBlock(profile) {
        const block = document.getElementById('profile-verification-block');
        const emailRow = document.getElementById('profile-verify-email-row');
        const phoneRow = document.getElementById('profile-verify-phone-row');
        if (!block || !emailRow || !phoneRow) return;

        const needEmail = !profile.email_verified;
        const needPhone = !profile.phone_verified || this.pendingVerifyPhone;
        if (needEmail || needPhone) {
            block.classList.remove('hidden');
            emailRow.classList.toggle('hidden', !needEmail);
            phoneRow.classList.toggle('hidden', !needPhone);
        } else {
            block.classList.add('hidden');
        }
    },

    /**
     * Render the 2FA methods list and toggle Add TOTP / Add SMS visibility.
     */
    renderProfileMfaMethods(profile) {
        const listEl = document.getElementById('profile-mfa-methods-list');
        const addTotpBtn = document.getElementById('profile-mfa-add-totp-btn');
        const addSmsBtn = document.getElementById('profile-mfa-add-sms-btn');
        const totpSetupEl = document.getElementById('profile-mfa-totp-setup');
        if (!listEl || !addTotpBtn || !addSmsBtn) return;

        const methods = profile.mfa_methods || [];
        const hasTotp = methods.some(m => m.method === 'totp');
        const hasSms = methods.some(m => m.method === 'sms');
        const canRemove = methods.length > 1;

        listEl.innerHTML = '';
        methods.forEach(m => {
            const label = m.method === 'totp'
                ? 'Authenticator app (TOTP)'
                : `SMS${m.phone_number ? ` (${m.phone_number})` : ''}`;
            const item = document.createElement('div');
            item.className = 'profile-mfa-method-item';
            item.innerHTML = `
                <span class="profile-mfa-method-label">${escapeHtml(label)}</span>
                <button type="button" class="btn btn-secondary btn-small profile-mfa-remove-btn"
                    data-method="${escapeHtml(m.method)}" ${canRemove ? '' : 'disabled'}
                    title="${canRemove ? 'Remove this method' : 'At least one method must remain'}">
                    Remove
                </button>
            `;
            listEl.appendChild(item);
        });
        if (methods.length === 0) {
            listEl.innerHTML = '<p class="form-hint">No 2FA methods yet. Add one below.</p>';
        }

        addTotpBtn.classList.toggle('hidden', hasTotp);
        addSmsBtn.classList.toggle('hidden', !this.smsEnabled || hasSms);
        if (totpSetupEl) totpSetupEl.classList.add('hidden');
    },

    /**
     * Setup profile 2FA section: Add TOTP, Add SMS, Remove, TOTP setup panel (Copy, Done).
     */
    setupProfileMfaSection() {
        const addTotpBtn = document.getElementById('profile-mfa-add-totp-btn');
        const addSmsBtn = document.getElementById('profile-mfa-add-sms-btn');
        const listEl = document.getElementById('profile-mfa-methods-list');
        const totpSetupEl = document.getElementById('profile-mfa-totp-setup');
        const totpSecretInput = document.getElementById('profile-mfa-totp-secret');
        const totpCopyBtn = document.getElementById('profile-mfa-totp-copy-btn');
        const totpDoneBtn = document.getElementById('profile-mfa-totp-done-btn');
        const totpQrEl = document.getElementById('profile-mfa-totp-qr');
        if (!addTotpBtn || !addSmsBtn || !listEl) return;

        addTotpBtn.addEventListener('click', async () => {
            if (!this.session) return;
            addTotpBtn.disabled = true;
            try {
                const res = await API.addProfileMfaMethod(this.session.username, { mfa_method: 'totp' });
                totpSecretInput.value = res.secret || '';
                totpQrEl.innerHTML = '';
                if (typeof QRCode !== 'undefined' && res.otpauth_uri) {
                    const canvas = document.createElement('canvas');
                    totpQrEl.appendChild(canvas);
                    await QRCode.toCanvas(canvas, res.otpauth_uri, { width: 180 });
                }
                if (totpSetupEl) totpSetupEl.classList.remove('hidden');
                this.showStatus('Scan the QR code with your app, then click Done.', 'success');
            } catch (e) {
                this.showStatus(e.message || 'Failed to add Authenticator app', 'error');
            } finally {
                addTotpBtn.disabled = false;
            }
        });

        addSmsBtn.addEventListener('click', async () => {
            if (!this.session) return;
            addSmsBtn.disabled = true;
            try {
                await API.addProfileMfaMethod(this.session.username, { mfa_method: 'sms' });
                this.showStatus('SMS 2FA added. Codes will be sent to your profile phone.', 'success');
                await this.loadProfile();
            } catch (e) {
                this.showStatus(e.message || 'Failed to add SMS', 'error');
            } finally {
                addSmsBtn.disabled = false;
            }
        });

        listEl.addEventListener('click', async (e) => {
            const btn = e.target.closest('.profile-mfa-remove-btn');
            if (!btn || btn.disabled || !this.session) return;
            const method = btn.getAttribute('data-method');
            if (!method) return;
            btn.disabled = true;
            try {
                await API.removeProfileMfaMethod(this.session.username, method);
                this.showStatus('2FA method removed.', 'success');
                await this.loadProfile();
            } catch (err) {
                this.showStatus(err.message || 'Failed to remove method', 'error');
                btn.disabled = false;
            }
        });

        if (totpCopyBtn && totpSecretInput) {
            totpCopyBtn.addEventListener('click', () => {
                totpSecretInput.select();
                document.execCommand('copy');
                this.showStatus('Secret copied to clipboard', 'success');
            });
        }
        if (totpDoneBtn && totpSetupEl) {
            totpDoneBtn.addEventListener('click', () => {
                totpSetupEl.classList.add('hidden');
                totpQrEl.innerHTML = '';
                totpSecretInput.value = '';
                this.loadProfile();
            });
        }
    },

    /**
     * Setup profile verification buttons (resend email, resend phone, verify phone code).
     */
    setupProfileVerification() {
        const resendEmailBtn = document.getElementById('profile-resend-email-btn');
        const resendPhoneBtn = document.getElementById('profile-resend-phone-btn');
        const verifyPhoneBtn = document.getElementById('profile-verify-phone-btn');
        const codeInput = document.getElementById('profile-phone-code');
        if (!resendEmailBtn || !resendPhoneBtn || !verifyPhoneBtn || !codeInput) return;

        resendEmailBtn.addEventListener('click', async () => {
            if (!this.session) return;
            resendEmailBtn.disabled = true;
            try {
                await API.resendVerification(this.session.username, 'email');
                this.showStatus('Verification email sent', 'success');
            } catch (e) {
                this.showStatus(e.message || 'Failed to send', 'error');
            } finally {
                resendEmailBtn.disabled = false;
            }
        });

        resendPhoneBtn.addEventListener('click', async () => {
            if (!this.session) return;
            resendPhoneBtn.disabled = true;
            try {
                await API.resendVerification(this.session.username, 'phone');
                this.showStatus('Verification code sent', 'success');
            } catch (e) {
                this.showStatus(e.message || 'Failed to send', 'error');
            } finally {
                resendPhoneBtn.disabled = false;
            }
        });

        verifyPhoneBtn.addEventListener('click', async () => {
            if (!this.session) return;
            const code = (codeInput.value || '').trim();
            if (!code) {
                this.showStatus('Enter the 6-digit code', 'error');
                return;
            }
            verifyPhoneBtn.disabled = true;
            try {
                await API.verifyPhone(this.session.username, code);
                this.pendingVerifyPhone = false;
                this.showStatus('Phone verified! Click Save again to confirm your profile.', 'success');
                codeInput.value = '';
                await this.loadProfile();
            } catch (e) {
                this.showStatus(e.message || 'Invalid code', 'error');
            } finally {
                verifyPhoneBtn.disabled = false;
            }
        });
    },

    /**
     * Setup admin users functionality
     */
    setupAdminUsers() {
        const searchInput = document.getElementById('users-search');
        const statusFilter = document.getElementById('users-status-filter');
        const groupFilter = document.getElementById('users-group-filter');
        const refreshBtn = document.getElementById('users-refresh-btn');
        if (!searchInput || !statusFilter || !groupFilter || !refreshBtn) return;

        // Search
        let searchTimeout;
        searchInput.addEventListener('input', () => {
            clearTimeout(searchTimeout);
            searchTimeout = setTimeout(() => this.loadAdminUsers(), 300);
        });

        // Filters
        statusFilter.addEventListener('change', () => this.loadAdminUsers());
        groupFilter.addEventListener('change', () => this.loadAdminUsers());

        // Refresh
        refreshBtn.addEventListener('click', () => this.loadAdminUsers());

        // Sortable headers
        document.querySelectorAll('#users-table th.sortable').forEach(th => {
            th.addEventListener('click', () => {
                const field = th.dataset.sort;
                if (this.sortState.field === field) {
                    this.sortState.order = this.sortState.order === 'asc' ? 'desc' : 'asc';
                } else {
                    this.sortState.field = field;
                    this.sortState.order = 'asc';
                }
                this.updateSortIndicators('users-table');
                this.loadAdminUsers();
            });
        });
    },

    /**
     * Load admin users list
     */
    async loadAdminUsers() {
        if (!this.session || !this.session.isAdmin) return;

        const tableBody = document.getElementById('users-table-body');
        const loading = document.getElementById('users-loading');
        const empty = document.getElementById('users-empty');

        loading.classList.remove('hidden');
        empty.classList.add('hidden');
        tableBody.innerHTML = '';

        try {
            const params = {
                status_filter: document.getElementById('users-status-filter').value || undefined,
                group_filter: document.getElementById('users-group-filter').value || undefined,
                search: document.getElementById('users-search').value || undefined,
                sort_by: this.sortState.field,
                sort_order: this.sortState.order,
            };

            const response = await API.adminListUsersEnhanced(params);
            this.users = response.users;

            // Also load groups for filter dropdown
            await this.loadGroupsForFilter();

            if (response.users.length === 0) {
                empty.classList.remove('hidden');
            } else {
                tableBody.innerHTML = response.users.map(user => `
                    <tr>
                        <td>${escapeHtml(user.first_name)} ${escapeHtml(user.last_name)}</td>
                        <td>${escapeHtml(user.username)}</td>
                        <td>${escapeHtml(user.email)}</td>
                        <td><span class="status-badge status-${escapeHtml(user.status)}">${escapeHtml(user.status.toUpperCase())}</span></td>
                        <td>${user.groups.map(g => `<span class="group-badge-small">${escapeHtml(g.name)}</span>`).join(' ') || '-'}</td>
                        <td>${new Date(user.created_at).toLocaleDateString()}</td>
                        <td class="action-buttons">
                            ${user.status === 'complete' ? `
                                <button class="btn btn-primary btn-xs" onclick="App.showApproveModal('${escapeHtml(user.id)}', '${escapeHtml(user.username)}')">Approve</button>
                                <button class="btn btn-danger btn-xs" onclick="App.confirmAction('Reject this user?', () => App.rejectUser('${escapeHtml(user.id)}'))">Reject</button>
                            ` : ''}
                            ${user.status === 'active' ? `
                                <button class="btn btn-danger btn-xs" onclick="App.confirmAction('Revoke this user?', () => App.revokeUser('${escapeHtml(user.id)}'))">Revoke</button>
                            ` : ''}
                        </td>
                    </tr>
                `).join('');
            }

        } catch (error) {
            this.showStatus(error.message, 'error');
        } finally {
            loading.classList.add('hidden');
        }
    },

    /**
     * Load groups for filter dropdown
     */
    async loadGroupsForFilter() {
        try {
            const response = await API.listGroups();
            this.groups = response.groups;

            const filterSelect = document.getElementById('users-group-filter');
            const currentValue = filterSelect.value;

            // Keep first option, update rest
            filterSelect.innerHTML = '<option value="">All Groups</option>' +
                response.groups.map(g => `<option value="${escapeHtml(g.id)}">${escapeHtml(g.name)}</option>`).join('');

            filterSelect.value = currentValue;
        } catch (error) {
            console.warn('Could not load groups for filter', error);
        }
    },

    /**
     * Setup admin groups functionality
     */
    setupAdminGroups() {
        const searchInput = document.getElementById('groups-search');
        const createBtn = document.getElementById('create-group-btn');
        if (!searchInput || !createBtn) return;

        // Search
        let searchTimeout;
        searchInput.addEventListener('input', () => {
            clearTimeout(searchTimeout);
            searchTimeout = setTimeout(() => this.loadAdminGroups(), 300);
        });

        // Create button
        createBtn.addEventListener('click', () => this.showGroupModal());

        // Sortable headers
        document.querySelectorAll('#groups-table th.sortable').forEach(th => {
            th.addEventListener('click', () => {
                const field = th.dataset.sort;
                if (this.sortState.field === field) {
                    this.sortState.order = this.sortState.order === 'asc' ? 'desc' : 'asc';
                } else {
                    this.sortState.field = field;
                    this.sortState.order = 'asc';
                }
                this.updateSortIndicators('groups-table');
                this.loadAdminGroups();
            });
        });
    },

    /**
     * Load admin groups list
     */
    async loadAdminGroups() {
        if (!this.session || !this.session.isAdmin) return;

        const tableBody = document.getElementById('groups-table-body');
        const loading = document.getElementById('groups-loading');
        const empty = document.getElementById('groups-empty');

        loading.classList.remove('hidden');
        empty.classList.add('hidden');
        tableBody.innerHTML = '';

        try {
            const params = {
                search: document.getElementById('groups-search').value || undefined,
                sort_by: this.sortState.field,
                sort_order: this.sortState.order,
            };

            const response = await API.listGroups(params);
            this.groups = response.groups;

            if (response.groups.length === 0) {
                empty.classList.remove('hidden');
            } else {
                tableBody.innerHTML = response.groups.map(group => `
                    <tr>
                        <td><strong>${escapeHtml(group.name)}</strong></td>
                        <td>${escapeHtml(group.description || '-')}</td>
                        <td>
                            <a href="#" onclick="App.showGroupMembers('${escapeHtml(group.id)}', '${escapeHtml(group.name)}'); return false;">
                                ${group.member_count} members
                            </a>
                        </td>
                        <td>${new Date(group.created_at).toLocaleDateString()}</td>
                        <td class="action-buttons">
                            <button class="btn btn-secondary btn-xs" onclick="App.showGroupModal('${escapeHtml(group.id)}')">Edit</button>
                            <button class="btn btn-danger btn-xs" onclick="App.confirmAction('Delete this group?', () => App.deleteGroup('${escapeHtml(group.id)}'))">Delete</button>
                        </td>
                    </tr>
                `).join('');
            }

        } catch (error) {
            this.showStatus(error.message, 'error');
        } finally {
            loading.classList.add('hidden');
        }
    },

    /**
     * Update sort indicators in table headers
     */
    updateSortIndicators(tableId) {
        document.querySelectorAll(`#${tableId} th.sortable`).forEach(th => {
            th.classList.remove('sort-asc', 'sort-desc');
            if (th.dataset.sort === this.sortState.field) {
                th.classList.add(`sort-${this.sortState.order}`);
            }
        });
    },

    /**
     * Setup modals
     */
    setupModals() {
        const overlay = document.getElementById('modal-overlay');

        // Close buttons
        document.querySelectorAll('[data-close-modal]').forEach(btn => {
            btn.addEventListener('click', () => this.closeModals());
        });

        // Close on overlay click
        overlay.addEventListener('click', (e) => {
            if (e.target === overlay) {
                this.closeModals();
            }
        });

        // Group modal form submission handled by handleGroupModalFormSubmit via onsubmit

        // Approve modal form submission handled by handleApproveModalFormSubmit via onsubmit
        const approveForm = document.getElementById('approve-modal-form');
        if (approveForm) {
            // Enter key submits when focused on checkboxes (no text inputs in this form)
            approveForm.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && e.target.type === 'checkbox') {
                e.preventDefault();
                approveForm.requestSubmit();
            }
        });
        }
    },

    /**
     * Close all modals
     */
    closeModals() {
        document.getElementById('modal-overlay').classList.add('hidden');
        document.querySelectorAll('.modal').forEach(m => m.classList.add('hidden'));
    },

    /**
     * Show group create/edit modal
     */
    async showGroupModal(groupId = null) {
        const modal = document.getElementById('group-modal');
        const title = document.getElementById('group-modal-title');
        const nameInput = document.getElementById('group-name');
        const descInput = document.getElementById('group-description');

        if (groupId) {
            title.textContent = 'Edit Group';
            try {
                const group = await API.getGroup(groupId);
                nameInput.value = group.name;
                descInput.value = group.description || '';
                modal.dataset.groupId = groupId;
            } catch (error) {
                this.showStatus(error.message, 'error');
                return;
            }
        } else {
            title.textContent = 'Create Group';
            nameInput.value = '';
            descInput.value = '';
            delete modal.dataset.groupId;
        }

        document.getElementById('modal-overlay').classList.remove('hidden');
        modal.classList.remove('hidden');
        nameInput.focus();
    },

    /**
     * Group modal form submit (called from handleGroupModalFormSubmit)
     */
    async doGroupModalFormSubmit() {
        await this.saveGroup();
    },

    /**
     * Save group (create or update)
     */
    async saveGroup() {
        const modal = document.getElementById('group-modal');
        const groupId = modal.dataset.groupId;
        const name = document.getElementById('group-name').value.trim();
        const description = document.getElementById('group-description').value.trim();

        if (!name) {
            this.showStatus('Group name is required', 'error');
            return;
        }

        try {
            if (groupId) {
                await API.updateGroup(groupId, { name, description });
                this.showStatus('Group updated successfully', 'success');
            } else {
                await API.createGroup(name, description);
                this.showStatus('Group created successfully', 'success');
            }

            this.closeModals();
            this.loadAdminGroups();
        } catch (error) {
            this.showStatus(error.message, 'error');
        }
    },

    /**
     * Delete group
     */
    async deleteGroup(groupId) {
        try {
            await API.deleteGroup(groupId);
            this.showStatus('Group deleted successfully', 'success');
            this.loadAdminGroups();
        } catch (error) {
            this.showStatus(error.message, 'error');
        }
    },

    /**
     * Show group members modal
     */
    async showGroupMembers(groupId, groupName) {
        const modal = document.getElementById('members-modal');
        const title = document.getElementById('members-modal-title');
        const membersList = document.getElementById('members-list');

        title.textContent = `Members of ${groupName}`;
        membersList.innerHTML = '<div class="loading-spinner">Loading...</div>';

        document.getElementById('modal-overlay').classList.remove('hidden');
        modal.classList.remove('hidden');

        try {
            const group = await API.getGroup(groupId);

            if (group.members.length === 0) {
                membersList.innerHTML = '<div class="empty-state">No members in this group</div>';
            } else {
                membersList.innerHTML = group.members.map(m => `
                    <div class="member-item">
                        <span class="member-name">${escapeHtml(m.full_name)}</span>
                        <span class="member-username">@${escapeHtml(m.username)}</span>
                    </div>
                `).join('');
            }
        } catch (error) {
            membersList.innerHTML = `<div class="error-message">${escapeHtml(error.message)}</div>`;
        }
    },

    /**
     * Show approve user modal with group selection
     */
    async showApproveModal(userId, username) {
        const modal = document.getElementById('approve-modal');
        const userNameEl = document.getElementById('approve-user-name');
        const groupsList = document.getElementById('approve-groups-list');

        userNameEl.textContent = username;
        modal.dataset.userId = userId;

        // Load groups
        groupsList.innerHTML = '<div class="loading-spinner">Loading groups...</div>';

        document.getElementById('modal-overlay').classList.remove('hidden');
        modal.classList.remove('hidden');

        try {
            const response = await API.listGroups();

            if (response.groups.length === 0) {
                groupsList.innerHTML = '<div class="warning-message">No groups available. Please create a group first.</div>';
            } else {
                groupsList.innerHTML = response.groups.map(g => `
                    <label class="checkbox-option">
                        <input type="checkbox" name="approve_group" value="${escapeHtml(g.id)}">
                        <span>${escapeHtml(g.name)}</span>
                    </label>
                `).join('');
            }
        } catch (error) {
            groupsList.innerHTML = `<div class="error-message">${escapeHtml(error.message)}</div>`;
        }
    },

    /**
     * Approve modal form submit (called from handleApproveModalFormSubmit)
     */
    async doApproveModalFormSubmit() {
        await this.approveUser();
    },

    /**
     * Approve user (from modal)
     */
    async approveUser() {
        const modal = document.getElementById('approve-modal');
        const userId = modal.dataset.userId;
        const selectedGroups = Array.from(
            document.querySelectorAll('input[name="approve_group"]:checked')
        ).map(cb => cb.value);

        if (selectedGroups.length === 0) {
            this.showStatus('Please select at least one group', 'error');
            return;
        }

        try {
            // Activate user with group assignment (uses JWT authentication)
            await API.adminActivateUser(userId, selectedGroups);
            this.showStatus('User activated and assigned to groups successfully', 'success');
            this.closeModals();
            this.loadAdminUsers();
        } catch (error) {
            this.showStatus(error.message, 'error');
        }
    },

    /**
     * Reject user
     */
    async rejectUser(userId) {
        try {
            // Note: This uses legacy auth - would need JWT-based version
            this.showStatus('Please use legacy admin panel to reject users for now.', 'warning');
        } catch (error) {
            this.showStatus(error.message, 'error');
        }
    },

    /**
     * Revoke user
     */
    async revokeUser(userId) {
        try {
            await API.revokeUser(userId);
            this.showStatus('User revoked successfully', 'success');
            this.loadAdminUsers();
        } catch (error) {
            this.showStatus(error.message, 'error');
        }
    },

    /**
     * Show confirmation dialog
     */
    confirmAction(message, callback) {
        const modal = document.getElementById('confirm-modal');
        const messageEl = document.getElementById('confirm-modal-message');
        const okBtn = document.getElementById('confirm-modal-ok');

        messageEl.textContent = message;

        // Remove old event listener
        const newOkBtn = okBtn.cloneNode(true);
        okBtn.parentNode.replaceChild(newOkBtn, okBtn);

        newOkBtn.addEventListener('click', () => {
            this.closeModals();
            callback();
        });

        document.getElementById('modal-overlay').classList.remove('hidden');
        modal.classList.remove('hidden');
    },

    /**
     * Show status message
     * @param {string} message - Message to display
     * @param {string} type - Message type (success, error, warning)
     */
    showStatus(message, type = 'success') {
        const statusEl = document.getElementById('status-message');

        statusEl.textContent = message;
        statusEl.className = `status-message ${type}`;
        statusEl.classList.remove('hidden');

        setTimeout(() => {
            statusEl.classList.add('hidden');
        }, 4000);
    },

    /**
     * Clear all result containers
     */
    clearResults() {
        document.getElementById('login-result').classList.add('hidden');
        document.getElementById('signup-result').classList.add('hidden');
    }
};

// Export for use in console/testing
window.App = App;

// ---------------------------------------------------------------------------
// Form submit handlers (called from onsubmit; must be on window for inline handlers)
// ---------------------------------------------------------------------------

window.handleLoginFormSubmit = function (e) {
    e.preventDefault();
    App.doLoginFormSubmit().catch(() => {});
    return false;
};

window.handleForgotPasswordSubmit = function (e) {
    e.preventDefault();
    App.doForgotPasswordSubmit().catch(() => {});
    return false;
};

window.handleResetPasswordSubmit = function (e) {
    e.preventDefault();
    App.doResetPasswordSubmit().catch(() => {});
    return false;
};

window.handleSignupFormSubmit = function (e) {
    e.preventDefault();
    App.doSignupFormSubmit().catch(() => {});
    return false;
};

window.handleMfaStepFormSubmit = function (e) {
    e.preventDefault();
    App.doMfaStepFormSubmit().catch(() => {});
    return false;
};

window.handleProfileFormSubmit = function (e) {
    e.preventDefault();
    App.doProfileFormSubmit().catch(() => {});
    return false;
};

window.handleGroupModalFormSubmit = function (e) {
    e.preventDefault();
    App.doGroupModalFormSubmit().catch(() => {});
    return false;
};

window.handleApproveModalFormSubmit = function (e) {
    e.preventDefault();
    App.doApproveModalFormSubmit().catch(() => {});
    return false;
};
