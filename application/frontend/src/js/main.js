/**
 * Main application logic for LDAP 2FA Frontend
 */

document.addEventListener('DOMContentLoaded', () => {
    // Initialize the application
    App.init();
});

const App = {
    // State
    smsEnabled: false,
    userMfaMethod: null,
    currentUser: null, // Store current signup user for verification
    adminCredentials: null, // Store admin credentials for API calls

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
        this.setupAdmin();

        // Check if SMS is enabled
        await this.checkMfaMethods();

        // Check for email verification token in URL
        this.checkEmailVerificationToken();
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
                    if (content.id === `${targetTab}-tab`) {
                        content.classList.add('active');
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

                resultContainer.innerHTML = `
                    <h3>✅ Login Successful!</h3>
                    <p>${response.message}</p>
                    ${response.is_admin ? '<p class="admin-badge">👑 Admin Access Granted</p>' : ''}
                `;
                resultContainer.className = 'result-container success';
                resultContainer.classList.remove('hidden');

                this.showStatus('Login successful!', 'success');

                // Show admin tab if user is admin
                if (response.is_admin) {
                    document.getElementById('admin-tab-btn').classList.remove('hidden');
                }

                form.reset();
                sendSmsBtn.classList.add('hidden');
                smsStatus.classList.add('hidden');

            } catch (error) {
                resultContainer.innerHTML = `
                    <h3>❌ Login Failed</h3>
                    <p>${error.message}</p>
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
                    <p>${error.message}</p>
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
                        <p>${error.message}</p>
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
     * Setup admin functionality
     */
    setupAdmin() {
        const authForm = document.getElementById('admin-auth-form');
        const adminLogin = document.getElementById('admin-login');
        const adminPanel = document.getElementById('admin-panel');
        const logoutBtn = document.getElementById('admin-logout-btn');
        const refreshBtn = document.getElementById('admin-refresh-btn');
        const statusFilter = document.getElementById('admin-status-filter');

        // Admin login
        authForm.addEventListener('submit', async (e) => {
            e.preventDefault();

            const submitBtn = authForm.querySelector('button[type="submit"]');
            const username = authForm.querySelector('#admin-username').value.trim();
            const password = authForm.querySelector('#admin-password').value;
            const code = authForm.querySelector('#admin-code').value.trim();

            if (!/^\d{6}$/.test(code)) {
                this.showStatus('Please enter a valid 6-digit code', 'error');
                return;
            }

            submitBtn.classList.add('loading');
            submitBtn.disabled = true;

            try {
                const response = await API.adminLogin(username, password, code);

                if (response.is_admin) {
                    this.adminCredentials = { username, password };
                    adminLogin.classList.add('hidden');
                    adminPanel.classList.remove('hidden');
                    await this.loadAdminUsers();
                    this.showStatus('Admin login successful!', 'success');
                } else {
                    throw new Error('Admin access denied');
                }

            } catch (error) {
                this.showStatus(error.message, 'error');
            } finally {
                submitBtn.classList.remove('loading');
                submitBtn.disabled = false;
            }
        });

        // Admin logout
        logoutBtn.addEventListener('click', () => {
            this.adminCredentials = null;
            adminLogin.classList.remove('hidden');
            adminPanel.classList.add('hidden');
            authForm.reset();
            this.showStatus('Logged out', 'success');
        });

        // Refresh users
        refreshBtn.addEventListener('click', () => {
            this.loadAdminUsers();
        });

        // Filter change
        statusFilter.addEventListener('change', () => {
            this.loadAdminUsers();
        });
    },

    /**
     * Load admin users list
     */
    async loadAdminUsers() {
        if (!this.adminCredentials) return;

        const usersList = document.getElementById('admin-users-list');
        const noUsers = document.getElementById('admin-no-users');
        const statusFilter = document.getElementById('admin-status-filter').value;

        usersList.innerHTML = '<div class="loading-spinner">Loading...</div>';
        noUsers.classList.add('hidden');

        try {
            const response = await API.adminListUsers(
                this.adminCredentials.username,
                this.adminCredentials.password,
                statusFilter || null
            );

            if (response.users.length === 0) {
                usersList.innerHTML = '';
                noUsers.classList.remove('hidden');
                return;
            }

            usersList.innerHTML = response.users.map(user => `
                <div class="user-card" data-user-id="${user.id}">
                    <div class="user-info">
                        <div class="user-name">${user.first_name} ${user.last_name}</div>
                        <div class="user-username">@${user.username}</div>
                        <div class="user-details">
                            <span>📧 ${user.email}</span>
                            <span>📱 ${user.phone}</span>
                        </div>
                        <div class="user-status">
                            <span class="status-badge status-${user.status}">${user.status.toUpperCase()}</span>
                            <span class="verification-badges">
                                ${user.email_verified ? '✅ Email' : '⏳ Email'}
                                ${user.phone_verified ? '✅ Phone' : '⏳ Phone'}
                            </span>
                        </div>
                        <div class="user-meta">
                            Created: ${new Date(user.created_at).toLocaleDateString()}
                            ${user.activated_at ? `| Activated: ${new Date(user.activated_at).toLocaleDateString()} by ${user.activated_by}` : ''}
                        </div>
                    </div>
                    <div class="user-actions">
                        ${user.status === 'complete' ? `
                            <button class="btn btn-primary btn-small activate-btn" data-user-id="${user.id}">
                                ✅ Activate
                            </button>
                            <button class="btn btn-secondary btn-small reject-btn" data-user-id="${user.id}">
                                ❌ Reject
                            </button>
                        ` : ''}
                        ${user.status === 'pending' ? `
                            <button class="btn btn-secondary btn-small reject-btn" data-user-id="${user.id}">
                                ❌ Delete
                            </button>
                        ` : ''}
                    </div>
                </div>
            `).join('');

            // Add event listeners to action buttons
            usersList.querySelectorAll('.activate-btn').forEach(btn => {
                btn.addEventListener('click', () => this.activateUser(btn.dataset.userId));
            });

            usersList.querySelectorAll('.reject-btn').forEach(btn => {
                btn.addEventListener('click', () => this.rejectUser(btn.dataset.userId));
            });

        } catch (error) {
            usersList.innerHTML = `<div class="error-message">${error.message}</div>`;
            this.showStatus(error.message, 'error');
        }
    },

    /**
     * Activate a user
     */
    async activateUser(userId) {
        if (!this.adminCredentials) return;

        if (!confirm('Are you sure you want to activate this user? They will be created in LDAP.')) {
            return;
        }

        try {
            const response = await API.adminActivateUser(
                userId,
                this.adminCredentials.username,
                this.adminCredentials.password
            );

            this.showStatus(response.message, 'success');
            await this.loadAdminUsers();

        } catch (error) {
            this.showStatus(error.message, 'error');
        }
    },

    /**
     * Reject/delete a user
     */
    async rejectUser(userId) {
        if (!this.adminCredentials) return;

        if (!confirm('Are you sure you want to reject/delete this user? This cannot be undone.')) {
            return;
        }

        try {
            const response = await API.adminRejectUser(
                userId,
                this.adminCredentials.username,
                this.adminCredentials.password
            );

            this.showStatus(response.message, 'success');
            await this.loadAdminUsers();

        } catch (error) {
            this.showStatus(error.message, 'error');
        }
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
