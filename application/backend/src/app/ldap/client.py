"""LDAP client for user authentication and management."""

import logging
from typing import Optional

import ldap3
from ldap3 import ALL, Connection, Server
from ldap3.core.exceptions import LDAPException

from app.config import Settings, get_settings

logger = logging.getLogger(__name__)


class LDAPClient:
    """Client for LDAP authentication operations."""

    def __init__(self, settings: Optional[Settings] = None):
        """Initialize LDAP client with settings."""
        self.settings = settings or get_settings()
        self._server: Optional[Server] = None

    @property
    def server(self) -> Server:
        """Get or create LDAP server connection."""
        if self._server is None:
            self._server = Server(
                host=self.settings.ldap_host,
                port=self.settings.ldap_port,
                use_ssl=self.settings.ldap_use_ssl,
                get_info=ALL,
            )
        return self._server

    def _get_user_dn(self, username: str) -> str:
        """Construct the user DN from username."""
        user_search_base = self.settings.ldap_user_search_base
        if not user_search_base.endswith(self.settings.ldap_base_dn):
            user_search_base = f"{user_search_base},{self.settings.ldap_base_dn}"
        return f"uid={username},{user_search_base}"

    def authenticate(self, username: str, password: str) -> tuple[bool, str]:
        """
        Authenticate a user against LDAP.

        Args:
            username: The username to authenticate
            password: The user's password

        Returns:
            Tuple of (success: bool, message: str)
        """
        if not password:
            return False, "Password cannot be empty"

        user_dn = self._get_user_dn(username)
        logger.debug(f"Attempting to authenticate user DN: {user_dn}")

        try:
            conn = Connection(
                self.server,
                user=user_dn,
                password=password,
                auto_bind=True,
                raise_exceptions=True,
            )
            conn.unbind()
            logger.info(f"Successfully authenticated user: {username}")
            return True, "Authentication successful"
        except ldap3.core.exceptions.LDAPBindError as e:
            logger.warning(f"Authentication failed for user {username}: {e}")
            return False, "Invalid username or password"
        except LDAPException as e:
            logger.error(f"LDAP error during authentication: {e}")
            return False, f"LDAP error: {e!s}"
        except Exception as e:
            logger.error(f"Unexpected error during authentication: {e}")
            return False, f"Authentication error: {e!s}"

    def user_exists(self, username: str) -> bool:
        """
        Check if a user exists in LDAP.

        Args:
            username: The username to check

        Returns:
            True if user exists, False otherwise
        """
        try:
            conn = Connection(
                self.server,
                user=self.settings.ldap_admin_dn,
                password=self.settings.ldap_admin_password,
                auto_bind=True,
                raise_exceptions=True,
            )

            user_search_base = self.settings.ldap_user_search_base
            if not user_search_base.endswith(self.settings.ldap_base_dn):
                user_search_base = f"{user_search_base},{self.settings.ldap_base_dn}"

            search_filter = self.settings.ldap_user_search_filter.format(username)
            conn.search(
                search_base=user_search_base,
                search_filter=search_filter,
                attributes=["uid"],
            )

            exists = len(conn.entries) > 0
            conn.unbind()
            return exists
        except LDAPException as e:
            logger.error(f"LDAP error checking user existence: {e}")
            return False

    def get_user_attribute(
        self, username: str, attribute: str
    ) -> Optional[str]:
        """
        Get a user attribute from LDAP.

        Args:
            username: The username
            attribute: The attribute name to retrieve

        Returns:
            The attribute value or None if not found
        """
        try:
            conn = Connection(
                self.server,
                user=self.settings.ldap_admin_dn,
                password=self.settings.ldap_admin_password,
                auto_bind=True,
                raise_exceptions=True,
            )

            user_search_base = self.settings.ldap_user_search_base
            if not user_search_base.endswith(self.settings.ldap_base_dn):
                user_search_base = f"{user_search_base},{self.settings.ldap_base_dn}"

            search_filter = self.settings.ldap_user_search_filter.format(username)
            conn.search(
                search_base=user_search_base,
                search_filter=search_filter,
                attributes=[attribute],
            )

            if conn.entries:
                entry = conn.entries[0]
                if hasattr(entry, attribute):
                    value = getattr(entry, attribute).value
                    conn.unbind()
                    return value

            conn.unbind()
            return None
        except LDAPException as e:
            logger.error(f"LDAP error getting user attribute: {e}")
            return None
