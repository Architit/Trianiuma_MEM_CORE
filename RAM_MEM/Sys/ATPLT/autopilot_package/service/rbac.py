# service/rbac.py
from typing import Tuple

class RBAC:
    def __init__(self, default_role: str = 'guest'):
        self.roles = {
            'guest': {'open','type','move','click','screenshot'},
            'resident': {'open','type','move','click','screenshot','run'},
            'user': {'open','type','move','click','screenshot','run','hotkey'},
            'avatar': {'open','type','move','click','screenshot','run','hotkey','delete'},
            'admin': {'open','type','move','click','screenshot','run','hotkey','delete','install'},
            'creator': {'*'}
        }
        self.critical_actions = {'delete','install','modify_system','change_models'}
        self.default_role = default_role

    def check_allowed(self, role: str, action: str, params: dict) -> Tuple[bool, str]:
        if role not in self.roles:
            return False, 'unknown role'
        allowed = self.roles[role]
        if '*' in allowed:
            return True, ''
        if action in allowed:
            return True, ''
        return False, 'action not allowed for role'

    def is_critical(self, action: str) -> bool:
        return action in self.critical_actions
