# Copyright (c) 2026-06-07 RADRILONIUMA / TRIANIUMA Kingdom. All rights reserved.
# service/executor.py (ФИНАЛЬНЫЙ РАБОЧИЙ КОД С POWERHSHELL-ЗАПУСКОМ)
import os
import sys
import time
import asyncio
import pyautogui
import subprocess
from send2trash import send2trash
from loguru import logger
import pyperclip

class Executor:
    def __init__(self, sandbox: str):
        self.sandbox = sandbox
        pyautogui.FAILSAFE = True

    async def execute(self, action: str, params: dict):
        # ... (click, move, type, hotkey, screenshot, delete, run - код не изменен)
        
        if action == "open":
            target = params.get("target")
            if not target: raise ValueError("missing target")
            
            if os.name == "nt": # Windows
                # --- ФИНАЛЬНЫЙ ОБХОД: Запуск через PowerShell ---
                try:
                    cmd = f'powershell.exe -Command "Start-Process \'{target}\'"'
                    subprocess.Popen(cmd, shell=True)
                except Exception as e:
                    logger.error(f"PowerShell start failed for {target}: {e}")
                    # Резервный вариант (Win+R) на случай, если PowerShell недоступен
                    pyautogui.hotkey('win', 'r')
                    time.sleep(0.5)
                    pyautogui.write(target)
                    pyautogui.press('enter')
                
                return {"action":"open","target":target, "status":"powershell_executed"}
            
            else: # macOS/Linux (оставляем старую логику)
                opener = "open" if sys.platform == "darwin" else "xdg-open"
                subprocess.Popen([opener, target])
                return {"action":"open","target":target, "status":"subprocess_executed"}
        
        # ... (остальной код - click, type, etc. - не изменен)
        
        else:
            raise ValueError(f"unknown action {action}")
