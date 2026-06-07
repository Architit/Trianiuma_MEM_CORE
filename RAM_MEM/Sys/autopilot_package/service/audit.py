# Copyright (c) 2026-06-07 RADRILONIUMA / TRIANIUMA Kingdom. All rights reserved.
# service/audit.py
import sqlite3
import os
import time
from loguru import logger

class AuditTrail:
    def __init__(self, db_path='B:\CORE\autopilot_data\autopilot.db', password='ELARiON'):
        self.db_path = db_path
        os.makedirs(os.path.dirname(db_path), exist_ok=True)
        self.conn = sqlite3.connect(self.db_path, check_same_thread=False)
        self._init_schema()

    def _init_schema(self):
        c = self.conn.cursor()
        c.execute('CREATE TABLE IF NOT EXISTS audit (id INTEGER PRIMARY KEY AUTOINCREMENT, tx TEXT, role TEXT, action TEXT, params TEXT, allowed INTEGER, result TEXT, reason TEXT, ts INTEGER)')
        self.conn.commit()

    def log(self, tx, role, action, params, allowed=True, result=None, reason=None):
        c = self.conn.cursor()
        c.execute('INSERT INTO audit (tx,role,action,params,allowed,result,reason,ts) VALUES (?,?,?,?,?,?,?,?)', (tx, role, action, str(params), 1 if allowed else 0, str(result), reason, int(time.time())))
        self.conn.commit()
        logger.info(f'audit log tx={tx} action={action} allowed={allowed}')
