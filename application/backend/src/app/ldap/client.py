"""LDAP client for user authentication and management."""

import logging
from typing import Optional

import ldap3
from ldap3 import ALL, MODIFY_ADD, Connection, Server
from ldap3.core.exceptions import LDAPException

from app.config import Settings, get_settings

logger = logging.getLogger(__name__)


class LDAPClient:
    """Client for LDAP authentication and user management operations."""

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

    def _get_admin_connection(self) -> Connection:
        """Get an admin connection to LDAP."""
        return Connection(
            self.server,
            user=self.settings.ldap_admin_dn,
            password=self.settings.ldap_admin_password,
            auto_bind=True,
            raise_exceptions=True,
        )

    def _get_user_search_base(self) -> str:
        """Get the full user search base DN."""
        user_search_base = self.settings.ldap_user_search_base
        if not user_search_base.endswith(self.settings.ldap_base_dn):
            user_search_base = f"{user_search_base},{self.settings.ldap_base_dn}"
        return user_search_base

    def _get_user_dn(self, username: str) -> str:
        """Construct the user DN from username."""
        return f"uid={username},{self._get_user_search_base()}"

    def _get_next_uid_number(self, conn: Connection) -> int:
        """Get the next available UID number."""
        try:
            conn.search(
                search_base=self._get_user_search_base(),
                search_filter="(objectClass=posixAccount)",
                attributes=["uidNumber"],
            )

            max_uid = self.settings.ldap_uid_start
            for entry in conn.entries:
                if hasattr(entry, "uidNumber") and entry.uidNumber.value:
                    uid = int(entry.uidNumber.value)
                    if uid >= max_uid:
                        max_uid = uid + 1

            return max_uid
        except Exception as e:
            logger.warning(f"Error getting next UID, using default: {e}")
            return self.settings.ldap_uid_start

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
            conn = self._get_admin_connection()

            search_filter = self.settings.ldap_user_search_filter.format(username)
            conn.search(
                search_base=self._get_user_search_base(),
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
            conn = self._get_admin_connection()

            search_filter = self.settings.ldap_user_search_filter.format(username)
            conn.search(
                search_base=self._get_user_search_base(),
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

    def create_user(
        self,
        username: str,
        password: str,
        first_name: str,
        last_name: str,
        email: str,
    ) -> tuple[bool, str]:
        """
        Create a new user in LDAP.

        Args:
            username: The username (uid)
            password: The user's password
            first_name: User's first name
            last_name: User's last name
            email: User's email address

        Returns:
            Tuple of (success: bool, message: str)
        """
        user_dn = self._get_user_dn(username)

        try:
            conn = self._get_admin_connection()

            # Check if user already exists
            if self.user_exists(username):
                conn.unbind()
                return False, f"User {username} already exists in LDAP"

            # Get next available UID number
            uid_number = self._get_next_uid_number(conn)

            # Build user attributes
            # Using inetOrgPerson + posixAccount for compatibility
            attributes = {
                "objectClass": [
                    "inetOrgPerson",
                    "posixAccount",
                    "shadowAccount",
                    "top",
                ],
                "uid": username,
                "cn": f"{first_name} {last_name}",
                "sn": last_name,
                "givenName": first_name,
                "mail": email,
                "userPassword": password,
                "uidNumber": str(uid_number),
                "gidNumber": str(self.settings.ldap_users_gid),
                "homeDirectory": f"/home/{username}",
                "loginShell": "/bin/bash",
            }

            # Create the user
            success = conn.add(user_dn, attributes=attributes)

            if success:
                logger.info(f"Created LDAP user: {username} (UID: {uid_number})")
                conn.unbind()
                return True, f"User {username} created successfully"
            else:
                error_msg = conn.result.get("description", "Unknown error")
                logger.error(f"Failed to create LDAP user {username}: {error_msg}")
                conn.unbind()
                return False, f"Failed to create user: {error_msg}"

        except LDAPException as e:
            logger.error(f"LDAP error creating user {username}: {e}")
            return False, f"LDAP error: {e!s}"
        except Exception as e:
            logger.error(f"Unexpected error creating user {username}: {e}")
            return False, f"Error creating user: {e!s}"

    def delete_user(self, username: str) -> tuple[bool, str]:
        """
        Delete a user from LDAP.

        Args:
            username: The username to delete

        Returns:
            Tuple of (success: bool, message: str)
        """
        user_dn = self._get_user_dn(username)

        try:
            conn = self._get_admin_connection()

            success = conn.delete(user_dn)

            if success:
                logger.info(f"Deleted LDAP user: {username}")
                conn.unbind()
                return True, f"User {username} deleted successfully"
            else:
                error_msg = conn.result.get("description", "Unknown error")
                logger.error(f"Failed to delete LDAP user {username}: {error_msg}")
                conn.unbind()
                return False, f"Failed to delete user: {error_msg}"

        except LDAPException as e:
            logger.error(f"LDAP error deleting user {username}: {e}")
            return False, f"LDAP error: {e!s}"
        except Exception as e:
            logger.error(f"Unexpected error deleting user {username}: {e}")
            return False, f"Error deleting user: {e!s}"

    def is_admin(self, username: str) -> bool:
        """
        Check if a user is a member of the admin group.

        Args:
            username: The username to check

        Returns:
            True if user is an admin, False otherwise
        """
        try:
            conn = self._get_admin_connection()

            admin_group_dn = self.settings.ldap_admin_group_dn

            # Search for the admin group and check membership
            # Groups typically use 'member' or 'memberUid' attribute
            conn.search(
                search_base=admin_group_dn,
                search_filter="(objectClass=*)",
                attributes=["member", "memberUid", "uniqueMember"],
            )

            if not conn.entries:
                logger.debug(f"Admin group not found: {admin_group_dn}")
                conn.unbind()
                return False

            entry = conn.entries[0]
            user_dn = self._get_user_dn(username)

            # Check different membership attribute types
            # member/uniqueMember uses full DN
            if hasattr(entry, "member") and entry.member.values:
                if user_dn.lower() in [m.lower() for m in entry.member.values]:
                    conn.unbind()
                    return True

            if hasattr(entry, "uniqueMember") and entry.uniqueMember.values:
                if user_dn.lower() in [m.lower() for m in entry.uniqueMember.values]:
                    conn.unbind()
                    return True

            # memberUid uses just the username
            if hasattr(entry, "memberUid") and entry.memberUid.values:
                if username.lower() in [m.lower() for m in entry.memberUid.values]:
                    conn.unbind()
                    return True

            conn.unbind()
            return False

        except LDAPException as e:
            logger.error(f"LDAP error checking admin status for {username}: {e}")
            return False
        except Exception as e:
            logger.error(f"Unexpected error checking admin status for {username}: {e}")
            return False

    def add_user_to_group(self, username: str, group_dn: str) -> tuple[bool, str]:
        """
        Add a user to an LDAP group.

        Args:
            username: The username to add
            group_dn: The DN of the group

        Returns:
            Tuple of (success: bool, message: str)
        """
        user_dn = self._get_user_dn(username)

        try:
            conn = self._get_admin_connection()

            # Try to add as member (for groupOfNames/groupOfUniqueNames)
            success = conn.modify(
                group_dn,
                {"member": [(MODIFY_ADD, [user_dn])]}
            )

            if not success:
                # Try memberUid instead (for posixGroup)
                success = conn.modify(
                    group_dn,
                    {"memberUid": [(MODIFY_ADD, [username])]}
                )

            if success:
                logger.info(f"Added user {username} to group {group_dn}")
                conn.unbind()
                return True, f"User added to group successfully"
            else:
                error_msg = conn.result.get("description", "Unknown error")
                logger.error(f"Failed to add {username} to group: {error_msg}")
                conn.unbind()
                return False, f"Failed to add to group: {error_msg}"

        except LDAPException as e:
            logger.error(f"LDAP error adding user to group: {e}")
            return False, f"LDAP error: {e!s}"
        except Exception as e:
            logger.error(f"Unexpected error adding user to group: {e}")
            return False, f"Error: {e!s}"
