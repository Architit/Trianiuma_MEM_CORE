# Copyright (c) 2026-06-07 RADRILONIUMA / TRIANIUMA Kingdom. All rights reserved.
# service/gesture_mouse.py
import os
import time
import json
from pynput import mouse
from loguru import logger

class GestureListener:
    def __init__(self, save_path='B:\CORE\gestures'):
        self.save_path = save_path
        os.makedirs(self.save_path, exist_ok=True)

    def _save_sample(self, name, points):
        ts = int(time.time()*1000)
        fname = os.path.join(self.save_path, f"{name}_{ts}.json")
        with open(fname, 'w', encoding='utf-8') as f:
            json.dump({'name':name,'points':points}, f)
        logger.info(f'Saved gesture sample {fname}')

    def on_move(self, x, y):
        pass

    def on_click(self, x, y, button, pressed):
        pass

    def run_loop(self):
        with mouse.Listener(on_move=self.on_move, on_click=self.on_click) as m:
            m.join()
