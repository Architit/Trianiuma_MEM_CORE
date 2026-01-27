# service/asr_manager.py
import asyncio
from loguru import logger

class ASRManager:
    def __init__(self):
        self.active = False

    async def run_loop(self):
        logger.info('ASR manager started (skeleton). Listening disabled by default.')
        while True:
            await asyncio.sleep(1)
