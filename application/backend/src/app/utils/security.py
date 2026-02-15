"""Security helpers to avoid leaking secrets into logs."""

import re


def redact_connection_strings(msg: str) -> str:
    """Redact connection URLs, passwords, and quoted secrets from a message safe for logging.

    Prevents database URLs, exception messages containing passwords (e.g. SQLAlchemy
    'Could not parse SQLAlchemy URL from string 'Passw0rd12345''), and similar
    from appearing in logs.
    """
    if not msg:
        return msg
    # Redact quoted strings that might be passwords (e.g. "from string 'Passw0rd12345'")
    out = re.sub(r"'[^']*'", "[REDACTED]", msg)
    # Redact anything that looks like a connection URL (scheme://user:...@host)
    out = re.sub(
        r"[a-zA-Z][a-zA-Z0-9+.-]*://[^\s]+",
        "[REDACTED]",
        out,
    )
    return out
