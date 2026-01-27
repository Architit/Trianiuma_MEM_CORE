# service/executor.py
import os
import subprocess
import time
import pyautogui
from send2trash import send2trash

class Executor:
    def __init__(self, sandbox: str):
        self.sandbox = sandbox
        pyautogui.FAILSAFE = True

    async def execute(self, action: str, params: dict):
        if action == 'click':
            x = params.get('x'); y = params.get('y'); button = params.get('button','left')
            duration = float(params.get('duration', 0))
            if x is None or y is None:
                raise ValueError('missing x/y')
            pyautogui.click(x, y, button=button, duration=duration)
            return {'action':'click','x':x,'y':y}
        if action == 'type':
            text = params.get('text','')
            interval = float(params.get('interval', 0.02))
            pyautogui.write(text, interval=interval)
            return {'action':'type','text':text}
        if action == 'open':
            target = params.get('target')
            if not target: raise ValueError('missing target')
            if os.name == 'nt': os.startfile(target)
            else: subprocess.Popen([target])
            return {'action':'open','target':target}
        if action == 'screenshot':
            path = params.get('path', os.path.join(self.sandbox, f'screenshot_{int(time.time())}.png'))
            img = pyautogui.screenshot(); img.save(path)
            return {'action':'screenshot','path':path}
        if action == 'delete':
            path = params.get('path')
            if not path: raise ValueError('missing path')
            send2trash(path)
            return {'action':'delete','path':path}
        if action == 'run':
            cmd = params.get('cmd')
            if not cmd: raise ValueError('missing cmd')
            p = subprocess.Popen(cmd, shell=True)
            return {'action':'run','pid':p.pid}
        raise ValueError(f'unknown action {action}')
