"""LDAP client for user authentication and management."""

import logging
from typing import Optional

import ldap3
from ldap3 import ALL, MODIFY_ADD, MODIFY_DELETE, MODIFY_REPLACE, Connection, Server
from ldap3.core.exceptions import LDAPException
from ldap3.utils.dn import escape_rdn

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

    def _get_group_search_base(self) -> str:
        """Get the full group search base DN."""
        group_search_base = self.settings.ldap_group_search_base
        if not group_search_base.endswith(self.settings.ldap_base_dn):
            group_search_base = f"{group_search_base},{self.settings.ldap_base_dn}"
        return group_search_base

    def _get_group_dn(self, group_name: str) -> str:
        """Construct the group DN from group name."""
        return f"cn={group_name},{self._get_group_search_base()}"

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
            logger.warning("Error getting next UID, using default: %s", e)
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
        logger.debug("Attempting to authenticate user DN: %s", user_dn)

        try:
            conn = Connection(
                self.server,
                user=user_dn,
                password=password,
                auto_bind=True,
                raise_exceptions=True,
            )
            conn.unbind()
            logger.info("Successfully authenticated user: %s", username)
            return True, "Authentication successful"
        except ldap3.core.exceptions.LDAPBindError as e:
            logger.warning("Authentication failed for user %s: %s", username, e)
            return False, "Invalid username or password"
        except LDAPException as e:
            logger.error("LDAP error during authentication: %s", e)
            return False, f"LDAP error: {e!s}"
        except Exception as e:
            logger.error("Unexpected error during authentication: %s", e)
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
            logger.error("LDAP error checking user existence: %s", e)
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
            logger.error("LDAP error getting user attribute: %s", e)
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
                logger.info("Created LDAP user: %s (UID: %s)", username, uid_number)
                conn.unbind()
                return True, f"User {username} created successfully"
            else:
                error_msg = conn.result.get("description", "Unknown error")
                logger.error("Failed to create LDAP user %s: %s", username, error_msg)
                conn.unbind()
                return False, f"Failed to create user: {error_msg}"

        except LDAPException as e:
            logger.error("LDAP error creating user %s: %s", username, e)
            return False, f"LDAP error: {e!s}"
        except Exception as e:
            logger.error("Unexpected error creating user %s: %s", username, e)
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
                logger.info("Deleted LDAP user: %s", username)
                conn.unbind()
                return True, f"User {username} deleted successfully"
            else:
                error_msg = conn.result.get("description", "Unknown error")
                logger.error("Failed to delete LDAP user %s: %s", username, error_msg)
                conn.unbind()
                return False, f"Failed to delete user: {error_msg}"

        except LDAPException as e:
            logger.error("LDAP error deleting user %s: %s", username, e)
            return False, f"LDAP error: {e!s}"
        except Exception as e:
            logger.error("Unexpected error deleting user %s: %s", username, e)
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
                logger.debug("Admin group not found: %s", admin_group_dn)
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
            logger.error("LDAP error checking admin status for %s: %s", username, e)
            return False
        except Exception as e:
            logger.error("Unexpected error checking admin status for %s: %s", username, e)
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
                logger.info("Added user %s to group %s", username, group_dn)
                conn.unbind()
                return True, f"User added to group successfully"
            else:
                error_msg = conn.result.get("description", "Unknown error")
                logger.error("Failed to add %s to group: %s", username, error_msg)
                conn.unbind()
                return False, f"Failed to add to group: {error_msg}"

        except LDAPException as e:
            logger.error("LDAP error adding user to group: %s", e)
            return False, f"LDAP error: {e!s}"
        except Exception as e:
            logger.error("Unexpected error adding user to group: %s", e)
            return False, f"Error: {e!s}"

    def remove_user_from_group(self, username: str, group_dn: str) -> tuple[bool, str]:
        """
        Remove a user from an LDAP group.

        Args:
            username: The username to remove
            group_dn: The DN of the group

        Returns:
            Tuple of (success: bool, message: str)
        """
        user_dn = self._get_user_dn(username)

        try:
            conn = self._get_admin_connection()

            # Try to remove as member (for groupOfNames/groupOfUniqueNames)
            success = conn.modify(
                group_dn,
                {"member": [(MODIFY_DELETE, [user_dn])]}
            )

            if not success:
                # Try memberUid instead (for posixGroup)
                success = conn.modify(
                    group_dn,
                    {"memberUid": [(MODIFY_DELETE, [username])]}
                )

            if success:
                logger.info("Removed user %s from group %s", username, group_dn)
                conn.unbind()
                return True, "User removed from group successfully"
            else:
                error_msg = conn.result.get("description", "Unknown error")
                logger.error("Failed to remove %s from group: %s", username, error_msg)
                conn.unbind()
                return False, f"Failed to remove from group: {error_msg}"

        except LDAPException as e:
            logger.error("LDAP error removing user from group: %s", e)
            return False, f"LDAP error: {e!s}"
        except Exception as e:
            logger.error("Unexpected error removing user from group: %s", e)
            return False, f"Error: {e!s}"

    def list_groups(self) -> list[dict]:
        """
        List all LDAP groups.

        Returns:
            List of group dictionaries with dn, name, description, and members
        """
        groups = []
        try:
            conn = self._get_admin_connection()

            # Search for all groups
            conn.search(
                search_base=self._get_group_search_base(),
                search_filter="(|(objectClass=groupOfNames)(objectClass=groupOfUniqueNames)(objectClass=posixGroup))",
                attributes=["cn", "description", "member", "memberUid", "uniqueMember"],
            )

            for entry in conn.entries:
                group_data = {
                    "dn": str(entry.entry_dn),
                    "name": entry.cn.value if hasattr(entry, "cn") else "",
                    "description": entry.description.value if hasattr(entry, "description") and entry.description.value else "",
                    "members": [],
                }

                # Get members from different attribute types
                if hasattr(entry, "member") and entry.member.values:
                    group_data["members"].extend(entry.member.values)
                if hasattr(entry, "uniqueMember") and entry.uniqueMember.values:
                    group_data["members"].extend(entry.uniqueMember.values)
                if hasattr(entry, "memberUid") and entry.memberUid.values:
                    group_data["members"].extend(entry.memberUid.values)

                groups.append(group_data)

            conn.unbind()
            logger.info("Listed %s LDAP groups", len(groups))
            return groups

        except LDAPException as e:
            logger.error("LDAP error listing groups: %s", e)
            return []
        except Exception as e:
            logger.error("Unexpected error listing groups: %s", e)
            return []

    def create_group(
        self,
        name: str,
        description: str = "",
    ) -> tuple[bool, str, Optional[str]]:
        """
        Create a new LDAP group.

        Args:
            name: The group name (cn)
            description: Group description

        Returns:
            Tuple of (success: bool, message: str, group_dn: Optional[str])
        """
        # Escape the group name before using it in a DN or as the cn attribute
        safe_name = escape_rdn(name)
        group_dn = self._get_group_dn(safe_name)

        try:
            conn = self._get_admin_connection()

            # Check if group already exists
            conn.search(
                search_base=group_dn,
                search_filter="(objectClass=*)",
                attributes=["cn"],
            )
            if conn.entries:
                conn.unbind()
                return False, f"Group {name} already exists", None

            # Create group with groupOfNames objectClass
            # Note: groupOfNames requires at least one member, using admin as placeholder
            attributes = {
                "objectClass": ["groupOfNames", "top"],
                "cn": safe_name,
                "description": description or f"Group: {name}",
                "member": [self.settings.ldap_admin_dn],  # Required initial member
            }

            success = conn.add(group_dn, attributes=attributes)

            if success:
                logger.info("Created LDAP group: %s", name)
                conn.unbind()
                return True, f"Group {name} created successfully", group_dn
            else:
                error_msg = conn.result.get("description", "Unknown error")
                logger.error("Failed to create LDAP group %s: %s", name, error_msg)
                conn.unbind()
                return False, f"Failed to create group: {error_msg}", None

        except LDAPException as e:
            logger.error("LDAP error creating group %s: %s", name, e)
            return False, f"LDAP error: {e!s}", None
        except Exception as e:
            logger.error("Unexpected error creating group %s: %s", name, e)
            return False, f"Error creating group: {e!s}", None

    def delete_group(self, group_dn: str) -> tuple[bool, str]:
        """
        Delete an LDAP group.

        Args:
            group_dn: The DN of the group to delete

        Returns:
            Tuple of (success: bool, message: str)
        """
        try:
            conn = self._get_admin_connection()

            success = conn.delete(group_dn)

            if success:
                logger.info("Deleted LDAP group: %s", group_dn)
                conn.unbind()
                return True, "Group deleted successfully"
            else:
                error_msg = conn.result.get("description", "Unknown error")
                logger.error("Failed to delete LDAP group %s: %s", group_dn, error_msg)
                conn.unbind()
                return False, f"Failed to delete group: {error_msg}"

        except LDAPException as e:
            logger.error("LDAP error deleting group %s: %s", group_dn, e)
            return False, f"LDAP error: {e!s}"
        except Exception as e:
            logger.error("Unexpected error deleting group %s: %s", group_dn, e)
            return False, f"Error deleting group: {e!s}"

    def update_group(
        self,
        group_dn: str,
        description: Optional[str] = None,
    ) -> tuple[bool, str]:
        """
        Update an LDAP group's description.

        Args:
            group_dn: The DN of the group
            description: New description (if provided)

        Returns:
            Tuple of (success: bool, message: str)
        """
        try:
            conn = self._get_admin_connection()

            modifications = {}
            if description is not None:
                modifications["description"] = [(MODIFY_REPLACE, [description])]

            if not modifications:
                conn.unbind()
                return True, "No changes to apply"

            success = conn.modify(group_dn, modifications)

            if success:
                logger.info("Updated LDAP group: %s", group_dn)
                conn.unbind()
                return True, "Group updated successfully"
            else:
                error_msg = conn.result.get("description", "Unknown error")
                logger.error("Failed to update LDAP group %s: %s", group_dn, error_msg)
                conn.unbind()
                return False, f"Failed to update group: {error_msg}"

        except LDAPException as e:
            logger.error("LDAP error updating group %s: %s", group_dn, e)
            return False, f"LDAP error: {e!s}"
        except Exception as e:
            logger.error("Unexpected error updating group %s: %s", group_dn, e)
            return False, f"Error updating group: {e!s}"

    def get_user_groups(self, username: str) -> list[dict]:
        """
        Get all groups a user belongs to.

        Args:
            username: The username to check

        Returns:
            List of group dictionaries with dn and name
        """
        user_dn = self._get_user_dn(username)
        groups = []

        try:
            conn = self._get_admin_connection()

            # Search for groups containing this user
            # Check both member (DN) and memberUid (username)
            search_filter = f"(|(member={user_dn})(memberUid={username})(uniqueMember={user_dn}))"
            conn.search(
                search_base=self._get_group_search_base(),
                search_filter=search_filter,
                attributes=["cn", "description"],
            )

            for entry in conn.entries:
                groups.append({
                    "dn": str(entry.entry_dn),
                    "name": entry.cn.value if hasattr(entry, "cn") else "",
                    "description": entry.description.value if hasattr(entry, "description") and entry.description.value else "",
                })

            conn.unbind()
            logger.debug("User %s belongs to %s groups", username, len(groups))
            return groups

        except LDAPException as e:
            logger.error("LDAP error getting user groups for %s: %s", username, e)
            return []
        except Exception as e:
            logger.error("Unexpected error getting user groups for %s: %s", username, e)
            return []

    def get_admin_emails(self) -> list[str]:
        """
        Get email addresses of all admin group members.

        Returns:
            List of email addresses
        """
        emails = []
        try:
            conn = self._get_admin_connection()

            admin_group_dn = self.settings.ldap_admin_group_dn

            # Get admin group members
            conn.search(
                search_base=admin_group_dn,
                search_filter="(objectClass=*)",
                attributes=["member", "memberUid", "uniqueMember"],
            )

            if not conn.entries:
                logger.warning("Admin group not found: %s", admin_group_dn)
                conn.unbind()
                return []

            entry = conn.entries[0]
            member_dns = []
            member_uids = []

            # Collect member DNs
            if hasattr(entry, "member") and entry.member.values:
                member_dns.extend(entry.member.values)
            if hasattr(entry, "uniqueMember") and entry.uniqueMember.values:
                member_dns.extend(entry.uniqueMember.values)
            if hasattr(entry, "memberUid") and entry.memberUid.values:
                member_uids.extend(entry.memberUid.values)

            # Fetch email for each member DN
            for member_dn in member_dns:
                try:
                    conn.search(
                        search_base=member_dn,
                        search_filter="(objectClass=*)",
                        attributes=["mail"],
                    )
                    if conn.entries and hasattr(conn.entries[0], "mail"):
                        mail = conn.entries[0].mail.value
                        if mail:
                            emails.append(mail)
                except Exception as e:
                    logger.debug("Could not fetch email for %s: %s", member_dn, e)

            # Fetch email for each memberUid
            for uid in member_uids:
                try:
                    search_filter = self.settings.ldap_user_search_filter.format(uid)
                    conn.search(
                        search_base=self._get_user_search_base(),
                        search_filter=search_filter,
                        attributes=["mail"],
                    )
                    if conn.entries and hasattr(conn.entries[0], "mail"):
                        mail = conn.entries[0].mail.value
                        if mail:
                            emails.append(mail)
                except Exception as e:
                    logger.debug("Could not fetch email for uid %s: %s", uid, e)

            conn.unbind()

            # Remove duplicates while preserving order
            seen = set()
            unique_emails = []
            for email in emails:
                if email not in seen:
                    seen.add(email)
                    unique_emails.append(email)

            logger.info("Found %s admin email addresses", len(unique_emails))
            return unique_emails

        except LDAPException as e:
            logger.error("LDAP error getting admin emails: %s", e)
            return []
        except Exception as e:
            logger.error("Unexpected error getting admin emails: %s", e)
            return []

    def get_group_members(self, group_dn: str) -> list[str]:
        """
        Get all members of a group.

        Args:
            group_dn: The DN of the group

        Returns:
            List of member usernames
        """
        members = []
        try:
            conn = self._get_admin_connection()

            conn.search(
                search_base=group_dn,
                search_filter="(objectClass=*)",
                attributes=["member", "memberUid", "uniqueMember"],
            )

            if not conn.entries:
                conn.unbind()
                return []

            entry = conn.entries[0]

            # Get members from different attribute types
            if hasattr(entry, "memberUid") and entry.memberUid.values:
                members.extend(entry.memberUid.values)

            # Extract username from DN for member/uniqueMember
            if hasattr(entry, "member") and entry.member.values:
                for member_dn in entry.member.values:
                    # Extract uid from DN like "uid=username,ou=users,..."
                    if member_dn.lower().startswith("uid="):
                        parts = member_dn.split(",")
                        if parts:
                            uid = parts[0].split("=")[1] if "=" in parts[0] else ""
                            if uid:
                                members.append(uid)

            if hasattr(entry, "uniqueMember") and entry.uniqueMember.values:
                for member_dn in entry.uniqueMember.values:
                    if member_dn.lower().startswith("uid="):
                        parts = member_dn.split(",")
                        if parts:
                            uid = parts[0].split("=")[1] if "=" in parts[0] else ""
                            if uid:
                                members.append(uid)

            conn.unbind()

            # Remove duplicates
            return list(set(members))

        except LDAPException as e:
            logger.error("LDAP error getting group members for %s: %s", group_dn, e)
            return []
        except Exception as e:
            logger.error("Unexpected error getting group members for %s: %s", group_dn, e)
            return []
