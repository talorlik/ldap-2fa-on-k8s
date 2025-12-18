/**
 * API client for LDAP 2FA Backend
 * Uses relative URLs to work with single-domain routing pattern
 */

const API = {
    /**
     * Base API path
     */
    basePath: '/api',

    /**
     * Make an API request
     * @param {string} endpoint - API endpoint (e.g., '/auth/login')
     * @param {Object} options - Fetch options
     * @returns {Promise<Object>} Response data
     */
    async request(endpoint, options = {}) {
        const url = `${this.basePath}${endpoint}`;

        const defaultOptions = {
            headers: {
                'Content-Type': 'application/json',
            },
        };

        const mergedOptions = {
            ...defaultOptions,
            ...options,
            headers: {
                ...defaultOptions.headers,
                ...options.headers,
            },
        };

        try {
            const response = await fetch(url, mergedOptions);
            const data = await response.json();

            if (!response.ok) {
                throw new APIError(
                    data.detail || 'An error occurred',
                    response.status,
                    data
                );
            }

            return data;
        } catch (error) {
            if (error instanceof APIError) {
                throw error;
            }

            // Network or other errors
            throw new APIError(
                error.message || 'Network error. Please check your connection.',
                0,
                null
            );
        }
    },

    /**
     * Health check endpoint
     * @returns {Promise<Object>} Health status
     */
    async healthCheck() {
        return this.request('/healthz');
    },

    /**
     * Get available MFA methods
     * @returns {Promise<Object>} MFA methods response
     */
    async getMfaMethods() {
        return this.request('/mfa/methods');
    },

    /**
     * Get user's MFA enrollment status
     * @param {string} username - Username
     * @returns {Promise<Object>} MFA status response
     */
    async getMfaStatus(username) {
        return this.request(`/mfa/status/${encodeURIComponent(username)}`);
    },

    // =========================================================================
    // Signup & Verification
    // =========================================================================

    /**
     * Sign up a new user
     * @param {Object} userData - User signup data
     * @returns {Promise<Object>} Signup response
     */
    async signup(userData) {
        return this.request('/auth/signup', {
            method: 'POST',
            body: JSON.stringify({
                username: userData.username,
                email: userData.email,
                first_name: userData.firstName,
                last_name: userData.lastName,
                phone_country_code: userData.phoneCountryCode,
                phone_number: userData.phoneNumber,
                password: userData.password,
                mfa_method: userData.mfaMethod || 'totp',
            }),
        });
    },

    /**
     * Verify email address
     * @param {string} username - Username
     * @param {string} token - Email verification token
     * @returns {Promise<Object>} Verification response
     */
    async verifyEmail(username, token) {
        return this.request('/auth/verify-email', {
            method: 'POST',
            body: JSON.stringify({ username, token }),
        });
    },

    /**
     * Verify phone number
     * @param {string} username - Username
     * @param {string} code - 6-digit verification code
     * @returns {Promise<Object>} Verification response
     */
    async verifyPhone(username, code) {
        return this.request('/auth/verify-phone', {
            method: 'POST',
            body: JSON.stringify({ username, code }),
        });
    },

    /**
     * Resend verification email or SMS
     * @param {string} username - Username
     * @param {string} type - 'email' or 'phone'
     * @returns {Promise<Object>} Response
     */
    async resendVerification(username, type) {
        return this.request('/auth/resend-verification', {
            method: 'POST',
            body: JSON.stringify({
                username,
                verification_type: type,
            }),
        });
    },

    /**
     * Get user's profile status
     * @param {string} username - Username
     * @returns {Promise<Object>} Profile status response
     */
    async getProfileStatus(username) {
        return this.request(`/profile/status/${encodeURIComponent(username)}`);
    },

    // =========================================================================
    // MFA Enrollment
    // =========================================================================

    /**
     * Enroll a user for MFA
     * @param {string} username - Username
     * @param {string} password - Password
     * @param {string} mfaMethod - MFA method ('totp' or 'sms')
     * @param {string} phoneNumber - Phone number (required for SMS)
     * @returns {Promise<Object>} Enrollment response with otpauth_uri and secret
     */
    async enroll(username, password, mfaMethod = 'totp', phoneNumber = null) {
        const body = { username, password, mfa_method: mfaMethod };
        if (phoneNumber) {
            body.phone_number = phoneNumber;
        }
        return this.request('/auth/enroll', {
            method: 'POST',
            body: JSON.stringify(body),
        });
    },

    // =========================================================================
    // Login
    // =========================================================================

    /**
     * Send SMS verification code for login
     * @param {string} username - Username
     * @param {string} password - Password
     * @returns {Promise<Object>} SMS send response
     */
    async sendSmsCode(username, password) {
        return this.request('/auth/sms/send-code', {
            method: 'POST',
            body: JSON.stringify({ username, password }),
        });
    },

    /**
     * Login with credentials and verification code
     * @param {string} username - Username
     * @param {string} password - Password
     * @param {string} verificationCode - 6-digit verification code
     * @returns {Promise<Object>} Login response
     */
    async login(username, password, verificationCode) {
        return this.request('/auth/login', {
            method: 'POST',
            body: JSON.stringify({
                username,
                password,
                verification_code: verificationCode,
            }),
        });
    },

    // =========================================================================
    // Admin
    // =========================================================================

    /**
     * Admin login
     * @param {string} username - Admin username
     * @param {string} password - Admin password
     * @param {string} verificationCode - 6-digit verification code
     * @returns {Promise<Object>} Login response
     */
    async adminLogin(username, password, verificationCode) {
        return this.request('/admin/login', {
            method: 'POST',
            body: JSON.stringify({
                username,
                password,
                verification_code: verificationCode,
            }),
        });
    },

    /**
     * List users (admin only)
     * @param {string} adminUsername - Admin username
     * @param {string} adminPassword - Admin password
     * @param {string} statusFilter - Optional status filter
     * @returns {Promise<Object>} User list response
     */
    async adminListUsers(adminUsername, adminPassword, statusFilter = null) {
        let url = `/admin/users?admin_username=${encodeURIComponent(adminUsername)}&admin_password=${encodeURIComponent(adminPassword)}`;
        if (statusFilter) {
            url += `&status_filter=${encodeURIComponent(statusFilter)}`;
        }
        return this.request(url);
    },

    /**
     * Activate a user (admin only)
     * @param {string} userId - User ID to activate
     * @param {string} adminUsername - Admin username
     * @param {string} adminPassword - Admin password
     * @returns {Promise<Object>} Activation response
     */
    async adminActivateUser(userId, adminUsername, adminPassword) {
        return this.request(`/admin/users/${encodeURIComponent(userId)}/activate`, {
            method: 'POST',
            body: JSON.stringify({
                admin_username: adminUsername,
                admin_password: adminPassword,
            }),
        });
    },

    /**
     * Reject/delete a user (admin only)
     * @param {string} userId - User ID to reject
     * @param {string} adminUsername - Admin username
     * @param {string} adminPassword - Admin password
     * @returns {Promise<Object>} Rejection response
     */
    async adminRejectUser(userId, adminUsername, adminPassword) {
        return this.request(`/admin/users/${encodeURIComponent(userId)}/reject`, {
            method: 'POST',
            body: JSON.stringify({
                admin_username: adminUsername,
                admin_password: adminPassword,
            }),
        });
    },
};

/**
 * Custom API Error class
 */
class APIError extends Error {
    constructor(message, statusCode, data) {
        super(message);
        this.name = 'APIError';
        this.statusCode = statusCode;
        this.data = data;
    }

    /**
     * Check if error is due to authentication failure
     */
    isAuthError() {
        return this.statusCode === 401;
    }

    /**
     * Check if error is due to forbidden action (not enrolled, not active, etc.)
     */
    isForbidden() {
        return this.statusCode === 403;
    }

    /**
     * Check if error is due to user not being enrolled
     */
    isNotEnrolled() {
        return this.statusCode === 403;
    }

    /**
     * Check if error is a not found error
     */
    isNotFound() {
        return this.statusCode === 404;
    }

    /**
     * Check if error is a server error
     */
    isServerError() {
        return this.statusCode >= 500;
    }

    /**
     * Check if error is a validation error
     */
    isValidationError() {
        return this.statusCode === 400 || this.statusCode === 422;
    }
}

// Export for use in other modules
window.API = API;
window.APIError = APIError;
