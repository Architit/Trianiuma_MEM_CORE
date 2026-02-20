import hmac
import os
from typing import Dict, Tuple


class SecurityControls:
    """Runtime checks for key-version and admin MFA requirements."""

    def __init__(self) -> None:
        self.active_key_version = os.getenv("ACTIVE_KEY_VERSION", "v1")
        self.admin_mfa_code = os.getenv("ADMIN_MFA_CODE", "")

    def check_key_version(self, payload: Dict) -> Tuple[bool, str]:
        key_version = str(payload.get("key_version", "")).strip()
        if not key_version:
            return False, "missing key_version"
        if key_version != self.active_key_version:
            return False, "stale_or_invalid_key_version"
        return True, ""

    def check_admin_mfa(self, role: str, is_critical: bool, payload: Dict) -> Tuple[bool, str]:
        if role != "admin" or not is_critical:
            return True, ""
        if not self.admin_mfa_code:
            return False, "admin_mfa_not_configured"
        candidate = str(payload.get("admin_mfa_code", ""))
        if not candidate:
            return False, "admin_mfa_required"
        if not hmac.compare_digest(candidate, self.admin_mfa_code):
            return False, "admin_mfa_invalid"
        return True, ""
