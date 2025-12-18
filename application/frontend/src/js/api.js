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
     * JWT token storage key
     */
    tokenKey: 'ldap2fa_token',

    /**
     * Get stored JWT token
     */
    getToken() {
        return localStorage.getItem(this.tokenKey);
    },

    /**
     * Store JWT token
     */
    setToken(token) {
        if (token) {
            localStorage.setItem(this.tokenKey, token);
        } else {
            localStorage.removeItem(this.tokenKey);
        }
    },

    /**
     * Clear JWT token (logout)
     */
    clearToken() {
        localStorage.removeItem(this.tokenKey);
    },

    /**
     * Make an API request
     * @param {string} endpoint - API endpoint (e.g., '/auth/login')
     * @param {Object} options - Fetch options
     * @param {boolean} auth - Whether to include auth token
     * @returns {Promise<Object>} Response data
     */
    async request(endpoint, options = {}, auth = false) {
        const url = `${this.basePath}${endpoint}`;

        const defaultOptions = {
            headers: {
                'Content-Type': 'application/json',
            },
        };

        // Add auth header if requested and token exists
        if (auth) {
            const token = this.getToken();
            if (token) {
                defaultOptions.headers['Authorization'] = `Bearer ${token}`;
            }
        }

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
     * Make an authenticated API request
     */
    async authRequest(endpoint, options = {}) {
        return this.request(endpoint, options, true);
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

    // =========================================================================
    // Profile (Authenticated)
    // =========================================================================

    /**
     * Get user profile
     * @param {string} username - Username
     * @returns {Promise<Object>} Profile response
     */
    async getProfile(username) {
        return this.authRequest(`/profile/${encodeURIComponent(username)}`);
    },

    /**
     * Update user profile
     * @param {string} username - Username
     * @param {Object} updates - Profile updates
     * @returns {Promise<Object>} Updated profile response
     */
    async updateProfile(username, updates) {
        return this.authRequest(`/profile/${encodeURIComponent(username)}`, {
            method: 'PUT',
            body: JSON.stringify(updates),
        });
    },

    // =========================================================================
    // Groups (Admin, Authenticated)
    // =========================================================================

    /**
     * List all groups
     * @param {Object} params - Query parameters (search, sort_by, sort_order)
     * @returns {Promise<Object>} Groups list response
     */
    async listGroups(params = {}) {
        const query = new URLSearchParams();
        if (params.search) query.set('search', params.search);
        if (params.sort_by) query.set('sort_by', params.sort_by);
        if (params.sort_order) query.set('sort_order', params.sort_order);

        const queryStr = query.toString();
        return this.authRequest(`/admin/groups${queryStr ? '?' + queryStr : ''}`);
    },

    /**
     * Create a new group
     * @param {string} name - Group name
     * @param {string} description - Group description
     * @returns {Promise<Object>} Created group response
     */
    async createGroup(name, description = '') {
        return this.authRequest('/admin/groups', {
            method: 'POST',
            body: JSON.stringify({ name, description }),
        });
    },

    /**
     * Get group details
     * @param {string} groupId - Group ID
     * @returns {Promise<Object>} Group details response
     */
    async getGroup(groupId) {
        return this.authRequest(`/admin/groups/${encodeURIComponent(groupId)}`);
    },

    /**
     * Update a group
     * @param {string} groupId - Group ID
     * @param {Object} updates - Group updates
     * @returns {Promise<Object>} Updated group response
     */
    async updateGroup(groupId, updates) {
        return this.authRequest(`/admin/groups/${encodeURIComponent(groupId)}`, {
            method: 'PUT',
            body: JSON.stringify(updates),
        });
    },

    /**
     * Delete a group
     * @param {string} groupId - Group ID
     * @returns {Promise<Object>} Deletion response
     */
    async deleteGroup(groupId) {
        return this.authRequest(`/admin/groups/${encodeURIComponent(groupId)}`, {
            method: 'DELETE',
        });
    },

    // =========================================================================
    // User-Group Assignment (Admin, Authenticated)
    // =========================================================================

    /**
     * Get user's groups
     * @param {string} userId - User ID
     * @returns {Promise<Object>} User groups response
     */
    async getUserGroups(userId) {
        return this.authRequest(`/admin/users/${encodeURIComponent(userId)}/groups`);
    },

    /**
     * Assign user to groups
     * @param {string} userId - User ID
     * @param {string[]} groupIds - Array of group IDs to assign
     * @returns {Promise<Object>} Assignment response
     */
    async assignUserGroups(userId, groupIds) {
        return this.authRequest(`/admin/users/${encodeURIComponent(userId)}/groups`, {
            method: 'POST',
            body: JSON.stringify({ group_ids: groupIds }),
        });
    },

    /**
     * Replace user's groups
     * @param {string} userId - User ID
     * @param {string[]} groupIds - Array of group IDs to set
     * @returns {Promise<Object>} Assignment response
     */
    async replaceUserGroups(userId, groupIds) {
        return this.authRequest(`/admin/users/${encodeURIComponent(userId)}/groups`, {
            method: 'PUT',
            body: JSON.stringify({ group_ids: groupIds }),
        });
    },

    /**
     * Remove user from a group
     * @param {string} userId - User ID
     * @param {string} groupId - Group ID
     * @returns {Promise<Object>} Removal response
     */
    async removeUserFromGroup(userId, groupId) {
        return this.authRequest(`/admin/users/${encodeURIComponent(userId)}/groups/${encodeURIComponent(groupId)}`, {
            method: 'DELETE',
        });
    },

    // =========================================================================
    // Enhanced Admin (Authenticated)
    // =========================================================================

    /**
     * List users with enhanced filtering/sorting/search
     * @param {Object} params - Query parameters
     * @returns {Promise<Object>} Users list response
     */
    async adminListUsersEnhanced(params = {}) {
        const query = new URLSearchParams();
        if (params.status_filter) query.set('status_filter', params.status_filter);
        if (params.group_filter) query.set('group_filter', params.group_filter);
        if (params.search) query.set('search', params.search);
        if (params.sort_by) query.set('sort_by', params.sort_by);
        if (params.sort_order) query.set('sort_order', params.sort_order);

        const queryStr = query.toString();
        return this.authRequest(`/admin/users/enhanced${queryStr ? '?' + queryStr : ''}`);
    },

    /**
     * Revoke an active user
     * @param {string} userId - User ID
     * @returns {Promise<Object>} Revoke response
     */
    async revokeUser(userId) {
        return this.authRequest(`/admin/users/${encodeURIComponent(userId)}/revoke`, {
            method: 'POST',
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
