# service/main.py (ПАТЧ: Принудительное чтение токена)
import os
import sys
import json
import uuid
import time
import asyncio
import threading 
from fastapi import FastAPI, Request, WebSocket, BackgroundTasks
from fastapi.responses import JSONResponse
from dotenv import load_dotenv, find_dotenv 
from loguru import logger
from service.executor import Executor
from service.rbac import RBAC
from service.llm_adapter import LLMAdapter
from service.asr_manager import ASRManager
from service.gesture_mouse import GestureListener
from service.audit import AuditTrail

# Путь настройки: ожидает, что этот файл запущен из installPath/service
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
dotenv_path = os.path.join(BASE_DIR, ".env")
load_dotenv(dotenv_path) 

TOKEN = os.getenv("AUTOPILOT_TOKEN", "changeme") 

# --- ПАТЧ: ПРИНУДИТЕЛЬНОЕ ЧТЕНИЕ, ЕСЛИ НЕ ЗАГРУЖЕН ТОКЕН ---
if TOKEN == "changeme":
    try:
        with open(dotenv_path, 'r', encoding='utf-8') as f:
            for line in f:
                if line.startswith("AUTOPILOT_TOKEN="):
                    TOKEN = line.strip().split("=", 1)[1]
                    logger.warning("Token loaded forcefully from .env file.")
                    break
    except Exception as e:
        logger.error(f"Failed to load token forcefully: {e}")
# -------------------------------------------------------------

SANDBOX = os.getenv("SANDBOX_PATH", "B:\\CORE")
DB_PASSWORD = os.getenv("DB_PASSWORD", "ELARiON")
DEFAULT_ROLE = os.getenv("DEFAULT_ROLE", "guest")
DEFAULT_LLM = os.getenv("DEFAULT_LLM", "llama3.1:8b")

app = FastAPI()
logger.add(os.path.join(SANDBOX, "logs", "autopilot.log"), rotation="10 MB")

executor = Executor(sandbox=SANDBOX)
rbac = RBAC(default_role=DEFAULT_ROLE)
llm = LLMAdapter(default_model=DEFAULT_LLM)
audit = AuditTrail(db_path=os.path.join(SANDBOX, "autopilot_data", "autopilot.db"), password=DB_PASSWORD)
asr = ASRManager()
gesture = GestureListener(save_path=os.path.join(SANDBOX, "gestures")) 

# Background tasks start
@app.on_event("startup")
async def startup_event():
    logger.info("Autopilot service starting...")
    logger.info(f"Loaded TOKEN: {TOKEN}") 
    
    threading.Thread(target=gesture.run_loop, daemon=True).start()
    asyncio.create_task(asr.run_loop())
    
    logger.info("Listeners started")
    logger.info("Application startup complete.") 
    
def check_token(req_json):
    token = req_json.get("token") or ""
    return token == TOKEN

@app.post("/cmd")
async def cmd_endpoint(request: Request):
    data = await request.json()
    if not check_token(data):
        return JSONResponse(status_code=401, content={"error": "unauthorized"})
    role = data.get("role", DEFAULT_ROLE)
    action = data.get("action")
    params = data.get("params", {})
    tx_id = str(uuid.uuid4())
    logger.info(f"Received cmd {action} tx={tx_id} role={role}")
    # ... (остальной код)
    # ...

@app.post("/nl")
async def nl_endpoint(request: Request):
    data = await request.json()
    if not check_token(data):
        return JSONResponse(status_code=401, content={"error": "unauthorized"})
    # ... (остальной код)
    # ...

@app.post("/admin/change_credentials")
async def change_credentials(request: Request):
    data = await request.json()
    # ... (остальной код)
    # ...
