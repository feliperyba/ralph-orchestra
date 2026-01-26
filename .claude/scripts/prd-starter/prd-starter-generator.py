#!/usr/bin/env python3
"""
PRD Starter Generator - Cross-platform agent generation for Ralph Orchestra.

This is a thin wrapper for backward compatibility. The actual implementation
has been split into separate modules in the same directory.

Usage:
  python prd-starter-generator.py --action generate --state prd-starter-state.json
  python prd-starter-generator.py --action validate --config agent-config.json
  python prd-starter-generator.py --action reset
"""

from __future__ import annotations

import sys
import io
from pathlib import Path

# Set UTF-8 encoding for Windows console
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

# Add script directory to path for imports
script_dir = Path(__file__).parent.resolve()
if str(script_dir) not in sys.path:
    sys.path.insert(0, str(script_dir))

if __name__ == "__main__":
    from cli import main
    sys.exit(main())
