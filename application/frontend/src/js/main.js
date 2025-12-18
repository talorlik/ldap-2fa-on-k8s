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

    /**
     * Initialize the application
     */
    async init() {
        this.setupTabs();
        this.setupLoginForm();
        this.setupEnrollForm();
        this.setupCopySecret();
        this.setupMfaMethodSelector();

        // Check if SMS is enabled
        await this.checkMfaMethods();
    },

    /**
     * Check available MFA methods
     */
    async checkMfaMethods() {
        try {
            const response = await API.getMfaMethods();
            this.smsEnabled = response.sms_enabled;

            // Show/hide SMS option based on availability
            const smsOption = document.getElementById('sms-option');
            if (smsOption) {
                if (!this.smsEnabled) {
                    smsOption.classList.add('disabled');
                    smsOption.querySelector('input').disabled = true;
                    smsOption.querySelector('small').textContent = 'SMS not available';
                } else {
                    smsOption.classList.remove('disabled');
                    smsOption.querySelector('input').disabled = false;
                }
            }
        } catch (error) {
            console.warn('Could not fetch MFA methods:', error.message);
            // Default to TOTP only
            this.smsEnabled = false;
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
        const methodRadios = document.querySelectorAll('input[name="mfa_method"]');
        const phoneGroup = document.getElementById('phone-group');
        const phoneInput = document.getElementById('enroll-phone');

        methodRadios.forEach(radio => {
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

                // Start countdown
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
                    // User may not be enrolled yet
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

            // Validate verification code format
            if (!/^\d{6}$/.test(verificationCode)) {
                this.showStatus('Please enter a valid 6-digit code', 'error');
                return;
            }

            // Show loading state
            submitBtn.classList.add('loading');
            submitBtn.disabled = true;
            resultContainer.classList.add('hidden');

            try {
                const response = await API.login(username, password, verificationCode);

                // Show success
                resultContainer.innerHTML = `
                    <h3>✅ Login Successful!</h3>
                    <p>${response.message}</p>
                `;
                resultContainer.className = 'result-container success';
                resultContainer.classList.remove('hidden');

                this.showStatus('Login successful!', 'success');

                // Clear form
                form.reset();
                sendSmsBtn.classList.add('hidden');
                smsStatus.classList.add('hidden');

            } catch (error) {
                let errorMessage = error.message;

                if (error.isNotEnrolled && error.isNotEnrolled()) {
                    errorMessage = 'You are not enrolled for MFA. Please enroll first.';
                }

                resultContainer.innerHTML = `
                    <h3>❌ Login Failed</h3>
                    <p>${errorMessage}</p>
                `;
                resultContainer.className = 'result-container error';
                resultContainer.classList.remove('hidden');

                this.showStatus(errorMessage, 'error');
            } finally {
                submitBtn.classList.remove('loading');
                submitBtn.disabled = false;
            }
        });
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

            // Validate phone for SMS
            if (mfaMethod === 'sms' && !phoneNumber) {
                this.showStatus('Please enter a phone number for SMS verification', 'error');
                return;
            }

            // Show loading state
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
                        // TOTP enrollment - show QR code
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
                        // SMS enrollment - show confirmation
                        enrolledPhone.textContent = response.phone_number;
                        smsSection.classList.remove('hidden');

                        this.showStatus('SMS verification setup complete!', 'success');
                    }

                    // Clear password field only
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

                // Visual feedback
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
     * Show status message
     * @param {string} message - Message to display
     * @param {string} type - Message type (success, error, warning)
     */
    showStatus(message, type = 'success') {
        const statusEl = document.getElementById('status-message');

        statusEl.textContent = message;
        statusEl.className = `status-message ${type}`;
        statusEl.classList.remove('hidden');

        // Auto-hide after 4 seconds
        setTimeout(() => {
            statusEl.classList.add('hidden');
        }, 4000);
    },

    /**
     * Clear all result containers
     */
    clearResults() {
        document.getElementById('login-result').classList.add('hidden');
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
