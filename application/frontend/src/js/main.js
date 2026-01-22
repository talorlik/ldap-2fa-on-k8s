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

const App = {
    // State
    smsEnabled: false,
    userMfaMethod: null,
    currentUser: null, // Store current signup user for verification
    session: null, // Store logged in session { username, isAdmin, token }
    groups: [], // Cache of groups for admin
    users: [], // Cache of users for admin
    sortState: { field: 'created_at', order: 'desc' },

    /**
     * Initialize the application
     */
    async init() {
        this.setupTabs();
        this.setupLoginForm();
        this.setupSignupForm();
        this.setupEnrollForm();
        this.setupCopySecret();
        this.setupMfaMethodSelector();
        this.setupVerification();
        this.setupTopBar();
        this.setupProfile();
        this.setupAdminUsers();
        this.setupAdminGroups();
        this.setupModals();

        // Check if SMS is enabled
        await this.checkMfaMethods();

        // Check for email verification token in URL
        this.checkEmailVerificationToken();

        // Check for existing session
        this.checkSession();
    },

    /**
     * Check for existing session from stored token
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
     * Show logged in state with top bar
     */
    showLoggedInState() {
        // Show top bar
        document.getElementById('top-bar').classList.remove('hidden');
        document.getElementById('user-display-name').textContent = this.session.username;

        // Show admin menu items if admin
        if (this.session.isAdmin) {
            document.getElementById('admin-menu-items').classList.remove('hidden');
        }

        // Hide auth header and tabs
        document.getElementById('auth-header').classList.add('hidden');
        document.getElementById('auth-tabs').classList.add('hidden');

        // Show profile by default
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

        // Show auth header and tabs
        document.getElementById('auth-header').classList.remove('hidden');
        document.getElementById('auth-tabs').classList.remove('hidden');

        // Hide all sections, show login
        this.hideAllSections();
        document.getElementById('login-tab').classList.add('active');

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

        switch (section) {
            case 'profile':
                document.getElementById('profile-section').classList.remove('hidden');
                this.loadProfile();
                break;
            case 'admin-users':
                document.getElementById('admin-users-section').classList.remove('hidden');
                this.loadAdminUsers();
                break;
            case 'admin-groups':
                document.getElementById('admin-groups-section').classList.remove('hidden');
                this.loadAdminGroups();
                break;
        }
    },

    /**
     * Hide all content sections
     */
    hideAllSections() {
        document.querySelectorAll('.tab-content').forEach(el => {
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
        const smsOptions = document.querySelectorAll('#sms-option, #signup-sms-option');
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
                this.showStatus('Email verified successfully!', 'success');

                // Clear URL params
                window.history.replaceState({}, document.title, window.location.pathname);

                // If user was signing up, update verification status
                if (this.currentUser && this.currentUser.username === username) {
                    this.updateVerificationStatus(response.profile_status);
                }
            } catch (error) {
                this.showStatus(error.message, 'error');
            }
        }
    },

    /**
     * Setup tab navigation
     */
    setupTabs() {
        const tabButtons = document.querySelectorAll('.tab-btn');
        const tabContents = document.querySelectorAll('.tab-content');

        tabButtons.forEach(button => {
            button.addEventListener('click', () => {
                const targetTab = button.dataset.tab;

                // Update button states
                tabButtons.forEach(btn => btn.classList.remove('active'));
                button.classList.add('active');

                // Update content visibility
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
     * Setup MFA method selector
     */
    setupMfaMethodSelector() {
        // Enroll form
        const enrollMethodRadios = document.querySelectorAll('input[name="mfa_method"]');
        const phoneGroup = document.getElementById('phone-group');
        const phoneInput = document.getElementById('enroll-phone');

        enrollMethodRadios.forEach(radio => {
            radio.addEventListener('change', () => {
                if (radio.value === 'sms') {
                    phoneGroup.classList.remove('hidden');
                    phoneInput.required = true;
                } else {
                    phoneGroup.classList.add('hidden');
                    phoneInput.required = false;
                    phoneInput.value = '';
                }
            });
        });
    },

    /**
     * Setup login form handling
     */
    setupLoginForm() {
        const form = document.getElementById('login-form');
        const resultContainer = document.getElementById('login-result');
        const sendSmsBtn = document.getElementById('send-sms-btn');
        const smsStatus = document.getElementById('sms-status');

        // Send SMS code button
        sendSmsBtn.addEventListener('click', async () => {
            const username = form.querySelector('#login-username').value.trim();
            const password = form.querySelector('#login-password').value;

            if (!username || !password) {
                this.showStatus('Please enter username and password first', 'warning');
                return;
            }

            sendSmsBtn.disabled = true;
            sendSmsBtn.textContent = 'Sending...';

            try {
                const response = await API.sendSmsCode(username, password);

                smsStatus.textContent = `Code sent to ${response.phone_number}. Expires in ${response.expires_in_seconds}s`;
                smsStatus.classList.remove('hidden');

                this.showStatus('Verification code sent!', 'success');
                this.startSmsCountdown(sendSmsBtn, response.expires_in_seconds);

            } catch (error) {
                this.showStatus(error.message, 'error');
                sendSmsBtn.disabled = false;
                sendSmsBtn.textContent = 'Send SMS';
            }
        });

        // Check MFA status when username is entered
        let mfaCheckTimeout;
        form.querySelector('#login-username').addEventListener('blur', async (e) => {
            const username = e.target.value.trim();
            if (!username) return;

            clearTimeout(mfaCheckTimeout);
            mfaCheckTimeout = setTimeout(async () => {
                try {
                    const status = await API.getMfaStatus(username);
                    this.userMfaMethod = status.mfa_method;

                    // Show/hide SMS button based on user's MFA method
                    if (status.enrolled && status.mfa_method === 'sms') {
                        sendSmsBtn.classList.remove('hidden');
                        smsStatus.textContent = `SMS will be sent to ${status.phone_number}`;
                        smsStatus.classList.remove('hidden');
                    } else {
                        sendSmsBtn.classList.add('hidden');
                        smsStatus.classList.add('hidden');
                    }
                } catch (error) {
                    sendSmsBtn.classList.add('hidden');
                    smsStatus.classList.add('hidden');
                }
            }, 500);
        });

        form.addEventListener('submit', async (e) => {
            e.preventDefault();

            const submitBtn = form.querySelector('button[type="submit"]');
            const username = form.querySelector('#login-username').value.trim();
            const password = form.querySelector('#login-password').value;
            const verificationCode = form.querySelector('#login-code').value.trim();

            if (!/^\d{6}$/.test(verificationCode)) {
                this.showStatus('Please enter a valid 6-digit code', 'error');
                return;
            }

            submitBtn.classList.add('loading');
            submitBtn.disabled = true;
            resultContainer.classList.add('hidden');

            try {
                const response = await API.login(username, password, verificationCode);

                // Store session
                if (response.token) {
                    API.setToken(response.token);
                    this.session = {
                        username: response.username || username,
                        isAdmin: response.is_admin,
                        token: response.token,
                    };

                    this.showStatus('Login successful!', 'success');
                    form.reset();
                    sendSmsBtn.classList.add('hidden');
                    smsStatus.classList.add('hidden');

                    // Show logged in state
                    this.showLoggedInState();
                } else {
                    resultContainer.innerHTML = `
                        <h3>✅ Login Successful!</h3>
                        <p>${response.message}</p>
                    `;
                    resultContainer.className = 'result-container success';
                    resultContainer.classList.remove('hidden');
                }

            } catch (error) {
                resultContainer.innerHTML = `
                    <h3>❌ Login Failed</h3>
                    <p>${escapeHtml(error.message)}</p>
                `;
                resultContainer.className = 'result-container error';
                resultContainer.classList.remove('hidden');

                this.showStatus(error.message, 'error');
            } finally {
                submitBtn.classList.remove('loading');
                submitBtn.disabled = false;
            }
        });
    },

    /**
     * Setup signup form handling
     */
    setupSignupForm() {
        const form = document.getElementById('signup-form');
        const resultContainer = document.getElementById('signup-result');
        const verificationPanel = document.getElementById('verification-status');

        form.addEventListener('submit', async (e) => {
            e.preventDefault();

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
                mfaMethod: form.querySelector('input[name="signup_mfa_method"]:checked').value,
            };

            submitBtn.classList.add('loading');
            submitBtn.disabled = true;
            resultContainer.classList.add('hidden');
            verificationPanel.classList.add('hidden');

            try {
                const response = await API.signup(userData);

                this.currentUser = {
                    username: userData.username,
                    email: userData.email,
                };

                // Show verification panel
                form.classList.add('hidden');
                verificationPanel.classList.remove('hidden');

                // Update verification hints
                if (response.email_verification_sent) {
                    document.getElementById('email-verify-hint').textContent =
                        `Check ${userData.email} for verification link`;
                }
                if (response.phone_verification_sent) {
                    document.getElementById('phone-verify-hint').textContent =
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
        });
    },

    /**
     * Setup verification functionality
     */
    setupVerification() {
        const resendEmailBtn = document.getElementById('resend-email-btn');
        const resendPhoneBtn = document.getElementById('resend-phone-btn');
        const verifyPhoneBtn = document.getElementById('verify-phone-btn');
        const phoneCodeInput = document.getElementById('phone-verify-code');

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
     * Setup enrollment form handling
     */
    setupEnrollForm() {
        const form = document.getElementById('enroll-form');
        const resultContainer = document.getElementById('enroll-result');
        const qrSection = document.getElementById('qr-section');
        const smsSection = document.getElementById('sms-enroll-section');
        const qrCodeDiv = document.getElementById('qr-code');
        const secretCode = document.getElementById('secret-code');
        const enrolledPhone = document.getElementById('enrolled-phone');

        form.addEventListener('submit', async (e) => {
            e.preventDefault();

            const submitBtn = form.querySelector('button[type="submit"]');
            const username = form.querySelector('#enroll-username').value.trim();
            const password = form.querySelector('#enroll-password').value;
            const mfaMethod = form.querySelector('input[name="mfa_method"]:checked').value;
            const phoneNumber = form.querySelector('#enroll-phone').value.trim();

            if (mfaMethod === 'sms' && !phoneNumber) {
                this.showStatus('Please enter a phone number for SMS verification', 'error');
                return;
            }

            submitBtn.classList.add('loading');
            submitBtn.disabled = true;
            resultContainer.classList.add('hidden');
            qrSection.classList.add('hidden');
            smsSection.classList.add('hidden');

            try {
                const response = await API.enroll(username, password, mfaMethod, phoneNumber);

                if (response.success) {
                    resultContainer.classList.remove('hidden');

                    if (response.mfa_method === 'totp' && response.otpauth_uri) {
                        qrCodeDiv.innerHTML = '';

                        await QRCode.toCanvas(qrCodeDiv, response.otpauth_uri, {
                            width: 200,
                            margin: 2,
                            color: {
                                dark: '#1e293b',
                                light: '#ffffff'
                            }
                        });

                        secretCode.textContent = response.secret;
                        qrSection.classList.remove('hidden');

                        this.showStatus('MFA enrollment successful! Scan the QR code.', 'success');
                    } else if (response.mfa_method === 'sms') {
                        enrolledPhone.textContent = response.phone_number;
                        smsSection.classList.remove('hidden');

                        this.showStatus('SMS verification setup complete!', 'success');
                    }

                    form.querySelector('#enroll-password').value = '';
                } else {
                    throw new Error(response.message || 'Enrollment failed');
                }

            } catch (error) {
                resultContainer.innerHTML = `
                    <div class="result-container error">
                        <h3>❌ Enrollment Failed</h3>
                        <p>${escapeHtml(error.message)}</p>
                    </div>
                `;
                resultContainer.classList.remove('hidden');
                qrSection.classList.add('hidden');
                smsSection.classList.add('hidden');

                this.showStatus(error.message, 'error');
            } finally {
                submitBtn.classList.remove('loading');
                submitBtn.disabled = false;
            }
        });
    },

    /**
     * Setup copy secret button
     */
    setupCopySecret() {
        const copyBtn = document.getElementById('copy-secret');
        const secretCode = document.getElementById('secret-code');

        copyBtn.addEventListener('click', async () => {
            const secret = secretCode.textContent;

            try {
                await navigator.clipboard.writeText(secret);
                this.showStatus('Secret copied to clipboard!', 'success');

                const originalText = copyBtn.textContent;
                copyBtn.textContent = 'Copied!';
                setTimeout(() => {
                    copyBtn.textContent = originalText;
                }, 2000);
            } catch (err) {
                // Fallback for older browsers
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
     * Setup profile functionality
     */
    setupProfile() {
        const form = document.getElementById('profile-form');

        form.addEventListener('submit', async (e) => {
            e.preventDefault();

            if (!this.session) return;

            const submitBtn = form.querySelector('button[type="submit"]');
            submitBtn.classList.add('loading');
            submitBtn.disabled = true;

            const updates = {};
            const firstName = document.getElementById('profile-firstname').value.trim();
            const lastName = document.getElementById('profile-lastname').value.trim();
            const email = document.getElementById('profile-email').value.trim();
            const phoneCountryCode = document.getElementById('profile-country-code').value;
            const phoneNumber = document.getElementById('profile-phone').value.trim();

            if (firstName) updates.first_name = firstName;
            if (lastName) updates.last_name = lastName;
            if (email && !document.getElementById('profile-email').readOnly) {
                updates.email = email;
            }
            if (!document.getElementById('profile-phone').readOnly) {
                updates.phone_country_code = phoneCountryCode;
                updates.phone_number = phoneNumber;
            }

            try {
                await API.updateProfile(this.session.username, updates);
                this.showStatus('Profile updated successfully', 'success');
            } catch (error) {
                this.showStatus(error.message, 'error');
            } finally {
                submitBtn.classList.remove('loading');
                submitBtn.disabled = false;
            }
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
            document.getElementById('profile-country-code').value = profile.phone_country_code;
            document.getElementById('profile-phone').value = profile.phone_number;
            document.getElementById('profile-mfa').value = profile.mfa_method.toUpperCase();
            document.getElementById('profile-status').value = profile.status.toUpperCase();

            // Set read-only based on verification status
            const emailInput = document.getElementById('profile-email');
            const phoneInput = document.getElementById('profile-phone');
            const countryCodeSelect = document.getElementById('profile-country-code');

            if (profile.email_verified) {
                emailInput.readOnly = true;
                emailInput.classList.add('readonly-input');
                document.getElementById('profile-email-hint').textContent = 'Email cannot be changed after verification';
            } else {
                emailInput.readOnly = false;
                emailInput.classList.remove('readonly-input');
                document.getElementById('profile-email-hint').textContent = '';
            }

            if (profile.phone_verified) {
                phoneInput.readOnly = true;
                phoneInput.classList.add('readonly-input');
                countryCodeSelect.disabled = true;
                document.getElementById('profile-phone-hint').textContent = 'Phone cannot be changed after verification';
            } else {
                phoneInput.readOnly = false;
                phoneInput.classList.remove('readonly-input');
                countryCodeSelect.disabled = false;
                document.getElementById('profile-phone-hint').textContent = '';
            }

            // Display groups
            const groupsContainer = document.getElementById('profile-groups');
            if (profile.groups && profile.groups.length > 0) {
                groupsContainer.innerHTML = profile.groups.map(g =>
                    `<span class="group-badge">${g.name}</span>`
                ).join('');
            } else {
                groupsContainer.innerHTML = '<span class="no-groups">No groups assigned</span>';
            }

        } catch (error) {
            this.showStatus('Failed to load profile', 'error');
        }
    },

    /**
     * Setup admin users functionality
     */
    setupAdminUsers() {
        const searchInput = document.getElementById('users-search');
        const statusFilter = document.getElementById('users-status-filter');
        const groupFilter = document.getElementById('users-group-filter');
        const refreshBtn = document.getElementById('users-refresh-btn');

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
                        <td>${user.first_name} ${user.last_name}</td>
                        <td>${user.username}</td>
                        <td>${user.email}</td>
                        <td><span class="status-badge status-${user.status}">${user.status.toUpperCase()}</span></td>
                        <td>${user.groups.map(g => `<span class="group-badge-small">${g.name}</span>`).join(' ') || '-'}</td>
                        <td>${new Date(user.created_at).toLocaleDateString()}</td>
                        <td class="action-buttons">
                            ${user.status === 'complete' ? `
                                <button class="btn btn-primary btn-xs" onclick="App.showApproveModal('${user.id}', '${user.username}')">Approve</button>
                                <button class="btn btn-danger btn-xs" onclick="App.confirmAction('Reject this user?', () => App.rejectUser('${user.id}'))">Reject</button>
                            ` : ''}
                            ${user.status === 'active' ? `
                                <button class="btn btn-danger btn-xs" onclick="App.confirmAction('Revoke this user?', () => App.revokeUser('${user.id}'))">Revoke</button>
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
                response.groups.map(g => `<option value="${g.id}">${g.name}</option>`).join('');

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
                        <td><strong>${group.name}</strong></td>
                        <td>${group.description || '-'}</td>
                        <td>
                            <a href="#" onclick="App.showGroupMembers('${group.id}', '${group.name}'); return false;">
                                ${group.member_count} members
                            </a>
                        </td>
                        <td>${new Date(group.created_at).toLocaleDateString()}</td>
                        <td class="action-buttons">
                            <button class="btn btn-secondary btn-xs" onclick="App.showGroupModal('${group.id}')">Edit</button>
                            <button class="btn btn-danger btn-xs" onclick="App.confirmAction('Delete this group?', () => App.deleteGroup('${group.id}'))">Delete</button>
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

        // Group modal form
        document.getElementById('group-modal-form').addEventListener('submit', async (e) => {
            e.preventDefault();
            await this.saveGroup();
        });

        // Approve modal form
        document.getElementById('approve-modal-form').addEventListener('submit', async (e) => {
            e.preventDefault();
            await this.approveUser();
        });
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
                        <span class="member-name">${m.full_name}</span>
                        <span class="member-username">@${m.username}</span>
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
                        <input type="checkbox" name="approve_group" value="${g.id}">
                        <span>${g.name}</span>
                    </label>
                `).join('');
            }
        } catch (error) {
            groupsList.innerHTML = `<div class="error-message">${escapeHtml(error.message)}</div>`;
        }
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
        document.getElementById('enroll-result').classList.add('hidden');
        document.getElementById('qr-section').classList.add('hidden');
        document.getElementById('sms-enroll-section').classList.add('hidden');

        // Reset SMS button state
        const sendSmsBtn = document.getElementById('send-sms-btn');
        const smsStatus = document.getElementById('sms-status');
        sendSmsBtn.classList.add('hidden');
        smsStatus.classList.add('hidden');
    }
};

// Export for use in console/testing
window.App = App;
