"""Path setup for session-handoff tests.

Adds the skill's `scripts/` and `evals/` directories to sys.path so
tests can `import create_handoff`, `import _common`, `import
setup_test_env`, etc. without restructuring the scripts as a Python
package.

Imported automatically by `unittest discover` when run on this
directory. The sibling `conftest.py` mirrors this for pytest.
"""

import sys
from pathlib import Path

SKILL_ROOT = Path(__file__).resolve().parent.parent
for sub in ("scripts", "evals"):
    p = str(SKILL_ROOT / sub)
    if p not in sys.path:
        sys.path.insert(0, p)
