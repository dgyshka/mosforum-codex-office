#!/usr/bin/env python3
"""Local Windows sound. No notification content is saved or transmitted."""
import json
import sys

def is_completion(event):
    return event.get('type') == 'agent-turn-complete'

if __name__ == '__main__':
    try:
        if is_completion(json.loads(sys.argv[1])):
            import winsound
            winsound.PlaySound('SystemAsterisk', winsound.SND_ALIAS)
    except (ValueError, IndexError, RuntimeError, ImportError):
        pass
