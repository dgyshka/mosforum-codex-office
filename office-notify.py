#!/usr/bin/env python3
"""Local sound only; never store or send notification content."""
import json
import subprocess
import sys

def sound_for(event):
    if event.get('type') == 'agent-turn-complete':
        return '/System/Library/Sounds/Glass.aiff'
    return None

if __name__ == '__main__':
    try:
        sound = sound_for(json.loads(sys.argv[1]))
        if sound:
            subprocess.run(['/usr/bin/afplay', sound], check=False)
    except (ValueError, IndexError, OSError):
        pass
