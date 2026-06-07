# Copyright (c) 2026-06-07 RADRILONIUMA / TRIANIUMA Kingdom. All rights reserved.
# service/main.py
import os
import uuid
import asyncio
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from dotenv import load_dotenv
from loguru import logger
from service.executor import Executor
from service.rbac import RBAC
from service.llm_adapter import LLMAdapter
from service.asr_manager import ASRManager
from service.gesture_mouse import GestureListener
from service.audit import AuditTrail
from service.security_controls import SecurityControls

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
load_dotenv(os.path.join(BASE_DIR, '..', '.env'))
TOKEN = os.getenv('AUTOPILOT_TOKEN', 'changeme')
SANDBOX = os.getenv('SANDBOX_PATH', 'B:\\CORE')
DB_PASSWORD = os.getenv('DB_PASSWORD', 'ELARiON')
DEFAULT_ROLE = os.getenv('DEFAULT_ROLE', 'guest')
DEFAULT_LLM = os.getenv('DEFAULT_LLM', 'llama3.1:8b')
app = FastAPI()
logger.add(os.path.join(SANDBOX, 'logs', 'autopilot.log'), rotation='10 MB')
executor = Executor(sandbox=SANDBOX)
rbac = RBAC(default_role=DEFAULT_ROLE)
llm = LLMAdapter(default_model=DEFAULT_LLM)
audit = AuditTrail(db_path=os.path.join(SANDBOX, 'autopilot_data', 'autopilot.db'), password=DB_PASSWORD)
asr = ASRManager()
gesture = GestureListener()
security = SecurityControls()

@app.on_event('startup')
async def startup_event():
    logger.info('Autopilot service starting...')
    asyncio.create_task(asyncio.to_thread(gesture.run_loop))
    asyncio.create_task(asr.run_loop())
    logger.info('Listeners started')


def check_token(req_json):
    token = req_json.get('token') or ''
    return token == TOKEN

@app.post('/cmd')
async def cmd_endpoint(request: Request):
    data = await request.json()
    if not check_token(data):
        return JSONResponse(status_code=401, content={'error': 'unauthorized'})
    key_ok, key_reason = security.check_key_version(data)
    if not key_ok:
        return JSONResponse(status_code=401, content={'error': key_reason})
    role = data.get('role', DEFAULT_ROLE)
    action = data.get('action')
    params = data.get('params', {})
    tx_id = str(uuid.uuid4())
    logger.info(f'Received cmd {action} tx={tx_id} role={role}')
    allowed, reason = rbac.check_allowed(role, action, params)
    if not allowed:
        audit.log(tx_id, role, action, params, allowed=False, reason=reason)
        return {'status': 'forbidden', 'reason': reason}
    if rbac.is_critical(action):
        if not data.get('confirm', False):
            return {'status': 'confirm_required', 'tx': tx_id, 'message': 'Action requires confirmation'}
        mfa_ok, mfa_reason = security.check_admin_mfa(role, True, data)
        if not mfa_ok:
            return JSONResponse(status_code=401, content={'error': mfa_reason})
    try:
        result = await executor.execute(action, params)
        audit.log(tx_id, role, action, params, allowed=True, result=result)
        return {'status': 'ok', 'tx': tx_id, 'result': result}
    except Exception as e:
        logger.exception('Executor error')
        audit.log(tx_id, role, action, params, allowed=False, reason=str(e))
        return {'status': 'error', 'error': str(e)}

@app.post('/nl')
async def nl_endpoint(request: Request):
    data = await request.json()
    if not check_token(data):
        return JSONResponse(status_code=401, content={'error': 'unauthorized'})
    key_ok, key_reason = security.check_key_version(data)
    if not key_ok:
        return JSONResponse(status_code=401, content={'error': key_reason})
    text = data.get('text', '')
    parsed = llm.parse_to_command(text)
    return {'parsed': parsed}

@app.post('/admin/change_credentials')
async def change_credentials(request: Request):
    data = await request.json()
    pin = data.get('admin_pin')
    if pin != os.getenv('ADMIN_PIN'):
        return JSONResponse(status_code=401, content={'error': 'unauthorized'})
    key_ok, key_reason = security.check_key_version(data)
    if not key_ok:
        return JSONResponse(status_code=401, content={'error': key_reason})
    mfa_ok, mfa_reason = security.check_admin_mfa('admin', True, data)
    if not mfa_ok:
        return JSONResponse(status_code=401, content={'error': mfa_reason})
    new_token = data.get('new_token')
    new_pin = data.get('new_pin')
    env_path = os.path.join(BASE_DIR, '..', '.env')
    with open(env_path, 'r', encoding='utf-8') as f:
        env = f.read()
    env = env.replace(f"AUTOPILOT_TOKEN={os.getenv('AUTOPILOT_TOKEN')}", f"AUTOPILOT_TOKEN={new_token}")
    env = env.replace(f"ADMIN_PIN={os.getenv('ADMIN_PIN')}", f"ADMIN_PIN={new_pin}")
    with open(env_path, 'w', encoding='utf-8') as f:
        f.write(env)
    return {'status': 'ok', 'message': 'credentials updated; restart service to apply'}
