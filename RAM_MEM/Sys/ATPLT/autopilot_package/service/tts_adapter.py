# Copyright (c) 2026-06-07 RADRILONIUMA / TRIANIUMA Kingdom. All rights reserved.
import pyttsx3
from loguru import logger

class TTSAdapter:
    def __init__(self):
        try:
            self.engine = pyttsx3.init()
        except Exception as e:
            logger.error(f"TTS init failed: {e}")
            self.engine = None

    def say(self, text):
        if not self.engine:
            return False
        self.engine.say(text)
        self.engine.runAndWait()
        return True
