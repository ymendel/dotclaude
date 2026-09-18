"""pytest mirror of __init__.py's module loading.

Duplicated rather than shared, matching skills/session-handoff/tests, whose
`__init__.py` and `conftest.py` repeat the same `sys.path` lines. The two entry
points are loaded by different runners in different ways, and a shared helper
would need importing — which is the problem this file exists to work around.

Read `__init__.py` for why these scripts cannot simply be imported. Note pytest
is not installed on this machine, so this path has never actually been exercised;
`run-tests.sh` runs the suites under stdlib unittest.
"""

import importlib.util
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent

ALIASES = {
    "rules_sections": "rules-sections.py",
    "session_meta_report": "session-meta-report.py",
}

for alias, filename in ALIASES.items():
    if alias in sys.modules:
        continue
    spec = importlib.util.spec_from_file_location(alias, SCRIPTS / filename)
    module = importlib.util.module_from_spec(spec)
    sys.modules[alias] = module
    spec.loader.exec_module(module)
