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
     * @param {string} username - LDAP username
     * @returns {Promise<Object>} MFA status response
     */
    async getMfaStatus(username) {
        return this.request(`/mfa/status/${encodeURIComponent(username)}`);
    },

    /**
     * Enroll a user for MFA
     * @param {string} username - LDAP username
     * @param {string} password - LDAP password
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

    /**
     * Send SMS verification code
     * @param {string} username - LDAP username
     * @param {string} password - LDAP password
     * @returns {Promise<Object>} SMS send response
     */
    async sendSmsCode(username, password) {
        return this.request('/auth/sms/send-code', {
            method: 'POST',
            body: JSON.stringify({ username, password }),
        });
    },

    /**
     * Login with LDAP credentials and verification code
     * @param {string} username - LDAP username
     * @param {string} password - LDAP password
     * @param {string} verificationCode - 6-digit verification code (TOTP or SMS)
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
     * Check if error is due to user not being enrolled
     */
    isNotEnrolled() {
        return this.statusCode === 403;
    }

    /**
     * Check if error is a server error
     */
    isServerError() {
        return this.statusCode >= 500;
    }
}

// Export for use in other modules
window.API = API;
window.APIError = APIError;
