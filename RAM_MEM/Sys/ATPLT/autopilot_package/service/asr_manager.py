# Copyright (c) 2026-06-07 RADRILONIUMA / TRIANIUMA Kingdom. All rights reserved.
import asyncio
from loguru import logger
from service.tts_adapter import TTSAdapter 
import queue
import time

class ASRManager:
    def __init__(self):
        self.active = False
        self.queue = queue.Queue()
        # self.tts = TTSAdapter() # --- ПАТЧ: Отключаем инициализацию TTS на старте ---

    async def run_loop(self):
        logger.info("ASR manager started (skeleton). Listening disabled by default.")
        
        # --- Удаляем блокирующий вызов say() ---
        
        while True:
            await asyncio.sleep(1)
