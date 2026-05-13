"""Shared test setup: put scripts/ and evals/ on sys.path.

Tests can then `import create_handoff`, `import setup_test_env`, etc.
Imported by `unittest discover` automatically when tests run from the
session-handoff/tests directory; pytest will also pick it up.
"""

import sys
from pathlib import Path

SKILL_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SKILL_ROOT / "scripts"))
sys.path.insert(0, str(SKILL_ROOT / "evals"))
