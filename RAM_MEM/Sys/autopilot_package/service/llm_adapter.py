# service/llm_adapter.py
import subprocess
import json
import shutil
from loguru import logger

class LLMAdapter:
    def __init__(self, default_model='llama3.1:8b', ollama_cli='ollama'):
        self.model = default_model
        self.ollama = ollama_cli if shutil.which(ollama_cli) else None

    def _call_ollama_cli(self, model: str, prompt: str, timeout=15):
        cmd = ['ollama','run',model,'--json','--prompt',prompt]
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
            if r.returncode != 0:
                logger.error('ollama CLI error: ' + r.stderr)
                return None
            return r.stdout
        except Exception as e:
            logger.error(f'ollama call failed: {e}')
            return None

    def parse_to_command(self, text: str):
        prompt = "Convert the user instruction into a JSON with keys: action, params, criticality. Input: '" + text + "'"
        if self.ollama:
            out = self._call_ollama_cli(self.model, prompt)
            if out:
                try:
                    return json.loads(out)
                except Exception:
                    return {'raw': out}
        text_l = text.lower()
        if text_l.startswith('open '):
            target = text[5:].strip()
            return {'action':'open','params':{'target':target},'criticality':'low'}
        if 'delete' in text_l or 'remove' in text_l:
            return {'action':'delete','params':{'path':text},'criticality':'high'}
        return {'action':'run','params':{'cmd':text},'criticality':'medium'}
