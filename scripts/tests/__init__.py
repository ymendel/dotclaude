"""Module loading for the scripts/ suites.

WHY THIS IS NOT THE session-handoff PATTERN. That package puts its `scripts/`
directory on `sys.path` and lets each test `import create_handoff`. Nothing
arranged in `sys.path` can reach these, because they are named with hyphens —
`rules-sections.py` is not a valid module name and no import statement can spell
it. Renaming them is the other available fix and is the wrong one: they are
invoked by name from their own docstrings, from `hooks/commit-ratchet-guard.sh`'s
TIERED array, and from the command line.

So each is loaded by file path and registered under an underscored alias, which
the test modules then import normally.

`exec_module` runs the module body, so a script whose `main()` is called at import
time would execute on every test run. `rules-sections.py` gained an
`if __name__ == "__main__":` guard for exactly this;
`session-meta-report.py` already had one. A script added here without one will
scan the filesystem during discovery rather than failing visibly, so check for the
guard before adding an alias.

Imported automatically by `unittest discover` — which is why `run-tests.sh` passes
`--top-level-directory` as this package's PARENT. Pointed at this directory
instead, the modules become top-level, this file never runs, and every test fails
to import. The sibling `conftest.py` mirrors it for pytest.
"""

import importlib.util
import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent

ALIASES = {
    "compare_settings_json": "compare-settings-json.py",
    "rules_sections": "rules-sections.py",
    "session_meta_report": "session-meta-report.py",
}


def load(alias, filename):
    """Register scripts/<filename> in sys.modules under <alias>."""
    if alias in sys.modules:
        return sys.modules[alias]
    path = SCRIPTS / filename
    spec = importlib.util.spec_from_file_location(alias, path)
    if spec is None or spec.loader is None:
        raise ImportError(f"cannot load {path} as {alias}")
    module = importlib.util.module_from_spec(spec)
    # Registered before exec so a module importing itself by alias resolves rather
    # than loading a second copy.
    sys.modules[alias] = module
    spec.loader.exec_module(module)
    return module


for _alias, _filename in ALIASES.items():
    load(_alias, _filename)
