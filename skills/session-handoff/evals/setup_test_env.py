#!/usr/bin/env python3
"""
Set up a test environment for evaluating the session-handoff skill.

Creates a mock project with:
- Git repository with commit history
- Sample source files
- Sample handoffs (fresh and stale)

Usage:
    python setup_test_env.py [--path /tmp/handoff-test]
    python setup_test_env.py --clean  # Remove test environment
"""

from __future__ import annotations

import sys

if sys.version_info < (3, 9):
    sys.exit(
        f"requires Python 3.9+ (running {sys.version_info.major}.{sys.version_info.minor})"
    )

import argparse
import shutil
import subprocess
from datetime import datetime, timedelta
from pathlib import Path


DEFAULT_TEST_PATH = "/tmp/handoff-eval-project"


def run_cmd(cmd: list[str], cwd: str = None) -> tuple[bool, str]:
    """Run a command and return (success, stderr)."""
    try:
        result = subprocess.run(
            cmd, cwd=cwd, capture_output=True, check=True, text=True
        )
        return True, result.stderr.strip()
    except subprocess.CalledProcessError as e:
        return False, (e.stderr or "").strip() or f"exit {e.returncode}"
    except FileNotFoundError as e:
        return False, str(e)


def run_or_die(cmd: list[str], cwd: str = None) -> None:
    """Run a command, abort with an actionable error on failure."""
    ok, stderr = run_cmd(cmd, cwd=cwd)
    if not ok:
        sys.exit(f"error: `{' '.join(cmd)}` failed: {stderr}")


def _is_safe_rmtree_path(path: Path) -> bool:
    """Sanity-check that path looks like a disposable test location.

    Accepts:
    - any path whose name contains "test"
    - any path under /tmp (or /private/tmp, the macOS symlink target)
    - any path under /var/folders (or /private/var/folders)

    Rejects everything else, including /var/log and similar. The user
    can pass --force to override for unusual setups.

    Uses `absolute()` rather than `resolve()` so users see the safety
    decision applied to the path they typed; symlinks are not followed
    here because shutil.rmtree refuses to follow them by default.
    """
    try:
        abs_path = path.absolute()
    except OSError:
        return False
    if "test" in abs_path.name.lower():
        return True
    parts = abs_path.parts
    safe_prefixes = (
        ("/", "tmp"),
        ("/", "private", "tmp"),
        ("/", "var", "folders"),
        ("/", "private", "var", "folders"),
    )
    return any(
        len(parts) >= len(prefix) and parts[: len(prefix)] == prefix
        for prefix in safe_prefixes
    )


def create_test_project(base_path: str, force: bool = False):
    """Create a mock project structure."""
    path = Path(base_path)

    # Clean if exists — but guard against destroying non-test paths
    if path.exists():
        if not (force or _is_safe_rmtree_path(path)):
            sys.exit(
                f"error: refusing to rmtree {path} — path does not look like a test "
                f"location. Pass --force to override, or pick a path under /tmp or "
                f"one containing 'test' in its name."
            )
        shutil.rmtree(path)

    # Create directories
    (path / "src").mkdir(parents=True)
    (path / "tests").mkdir()
    (path / "config").mkdir()

    # Create sample files
    (path / "README.md").write_text("""# Test Project

A sample project for testing the session-handoff skill.

## Features
- User authentication
- API endpoints
- Database integration
""")

    (path / "src" / "index.js").write_text("""// Main entry point
const express = require('express');
const app = express();

app.get('/', (req, res) => {
    res.send('Hello World');
});

module.exports = app;
""")

    (path / "src" / "auth.js").write_text("""// Authentication module
const jwt = require('jsonwebtoken');

function validateToken(token) {
    // TODO: Implement token validation
    return true;
}

function generateToken(user) {
    return jwt.sign({ id: user.id }, process.env.JWT_SECRET);
}

module.exports = { validateToken, generateToken };
""")

    (path / "src" / "database.js").write_text("""// Database connection
const mongoose = require('mongoose');

async function connect() {
    await mongoose.connect(process.env.DATABASE_URL);
}

module.exports = { connect };
""")

    (path / "tests" / "auth.test.js").write_text("""// Auth tests
describe('Authentication', () => {
    test('validates tokens', () => {
        expect(true).toBe(true);
    });
});
""")

    (path / "config" / "default.json").write_text("""{
    "port": 3000,
    "database": {
        "host": "localhost",
        "name": "testdb"
    }
}
""")

    (path / "package.json").write_text("""{
    "name": "test-project",
    "version": "1.0.0",
    "main": "src/index.js",
    "scripts": {
        "start": "node src/index.js",
        "test": "jest"
    }
}
""")

    print(f"Created project structure at {path}")
    return path


def init_git_repo(path: Path):
    """Initialize git repo with commit history. Aborts on any git failure.

    Forces the initial branch to `main` (git 2.28+) so the fixture
    matches the hardcoded `Branch: main` lines in the sample handoffs,
    regardless of the user's `init.defaultBranch` setting.
    """
    cwd = str(path)
    run_or_die(["git", "init", "-b", "main"], cwd=cwd)
    run_or_die(["git", "config", "user.email", "test@example.com"], cwd=cwd)
    run_or_die(["git", "config", "user.name", "Test User"], cwd=cwd)
    run_or_die(["git", "add", "."], cwd=cwd)
    run_or_die(["git", "commit", "-m", "Initial commit: project setup"], cwd=cwd)

    commits = [
        ("src/auth.js", "// Added validation logic\n", "Add token validation"),
        ("src/database.js", "// Added connection pooling\n", "Implement connection pooling"),
        ("tests/auth.test.js", "// More tests\n", "Add authentication tests"),
        ("src/index.js", "// Added middleware\n", "Add auth middleware"),
        ("README.md", "\n## API Docs\n", "Update documentation"),
    ]

    for file, content, message in commits:
        file_path = path / file
        with open(file_path, "a") as f:
            f.write(content)
        run_or_die(["git", "add", file], cwd=cwd)
        run_or_die(["git", "commit", "-m", message], cwd=cwd)

    print(f"Initialized git repo with {len(commits) + 1} commits")


def create_sample_handoffs(path: Path):
    """Create sample handoff documents for testing."""
    handoffs_dir = path / ".claude" / "handoffs"
    handoffs_dir.mkdir(parents=True)

    # Fresh handoff (today)
    now = datetime.now()
    fresh_name = now.strftime("%Y-%m-%d-%H%M%S") + "-auth-implementation.md"
    fresh_content = f"""# Handoff: Implementing User Authentication

## Session Metadata
- Created: {now.strftime("%Y-%m-%d %H:%M:%S")}
- Project: {path}
- Branch: main
- Session duration: 2 hours

## Handoff Chain

- **Continues from**: None (fresh start)
- **Supersedes**: None

## Current State Summary

Working on implementing JWT-based authentication for the API. Successfully added token generation and basic validation. The middleware integration is partially complete.

## Codebase Understanding

### Architecture Overview

Express.js application with modular structure. Auth logic separated into src/auth.js, database connection in src/database.js.

### Critical Files

| File | Purpose | Relevance |
|------|---------|-----------|
| src/auth.js | Authentication logic | Main file being modified |
| src/index.js | App entry point | Needs middleware integration |

### Key Patterns Discovered

- Using environment variables for secrets (JWT_SECRET, DATABASE_URL)
- Jest for testing

## Work Completed

### Tasks Finished

- [x] Set up JWT token generation
- [x] Create basic validation function
- [ ] Integrate middleware (in progress)

### Files Modified

| File | Changes | Rationale |
|------|---------|-----------|
| src/auth.js | Added validateToken, generateToken | Core auth functionality |

### Decisions Made

| Decision | Options Considered | Rationale |
|----------|-------------------|-----------|
| Use JWT over sessions | JWT, Sessions, OAuth | Stateless, scales better for API |

## Pending Work

### Immediate Next Steps

1. Complete middleware integration in src/index.js
2. Add refresh token logic
3. Write comprehensive tests

### Blockers/Open Questions

- [ ] Need to decide on token expiry time (1h vs 24h)

### Deferred Items

- OAuth integration (future sprint)

## Context for Resuming Agent

### Important Context

The validateToken function in src/auth.js currently returns true always - this is a placeholder that needs real implementation. The JWT_SECRET env var must be set.

### Assumptions Made

- Using HS256 algorithm for JWT
- Tokens should be passed in Authorization header

### Potential Gotchas

- Don't forget to set JWT_SECRET environment variable
- Database connection must be established before auth checks

## Environment State

### Tools/Services Used

- Node.js with Express
- JWT library (jsonwebtoken)

### Active Processes

- None currently running

### Environment Variables

- JWT_SECRET
- DATABASE_URL

## Related Resources

- JWT documentation: https://jwt.io
- Express middleware guide
"""
    (handoffs_dir / fresh_name).write_text(fresh_content, encoding="utf-8")

    # Stale handoff (2 weeks ago)
    old_date = now - timedelta(days=14)
    stale_name = old_date.strftime("%Y-%m-%d-%H%M%S") + "-database-setup.md"
    stale_content = f"""# Handoff: Database Setup

## Session Metadata
- Created: {old_date.strftime("%Y-%m-%d %H:%M:%S")}
- Project: {path}
- Branch: main
- Session duration: 1 hour

## Handoff Chain

- **Continues from**: None (fresh start)
- **Supersedes**: None

## Current State Summary

Set up initial database connection with MongoDB. Basic schema defined but not fully implemented.

## Codebase Understanding

### Architecture Overview

MongoDB database with Mongoose ODM.

### Critical Files

| File | Purpose | Relevance |
|------|---------|-----------|
| src/database.js | DB connection | Main database file |
| src/old-file.js | Legacy code | Was being refactored |

## Pending Work

### Immediate Next Steps

1. Define user schema
2. Add connection pooling
3. Implement error handling

## Context for Resuming Agent

### Important Context

Using MongoDB Atlas for hosting. Connection string in DATABASE_URL.

### Assumptions Made

- MongoDB version 5.x
- Mongoose 7.x

## Environment State

### Environment Variables

- DATABASE_URL
"""
    (handoffs_dir / stale_name).write_text(stale_content, encoding="utf-8")

    # Incomplete handoff (with TODOs) — offset by a minute so the timestamp
    # alone disambiguates from the fresh handoff above, not just the slug.
    incomplete_ts = now + timedelta(minutes=1)
    incomplete_name = incomplete_ts.strftime("%Y-%m-%d-%H%M%S") + "-incomplete-test.md"
    incomplete_content = f"""# Handoff: [TASK_TITLE - replace this]

## Session Metadata
- Created: {incomplete_ts.strftime("%Y-%m-%d %H:%M:%S")}
- Project: {path}
- Branch: main
- Session duration: [estimate how long you worked]

## Current State Summary

[TODO: Write one paragraph describing what was being worked on]

## Codebase Understanding

### Architecture Overview

[TODO: Document key architectural insights]

## Pending Work

### Immediate Next Steps

1. [TODO: Most critical next action]
2. [TODO: Second priority]

## Context for Resuming Agent

### Important Context

[TODO: This is the MOST IMPORTANT section]
"""
    (handoffs_dir / incomplete_name).write_text(incomplete_content, encoding="utf-8")

    print(f"Created 3 sample handoffs:")
    print(f"  - {fresh_name} (fresh)")
    print(f"  - {stale_name} (stale, 14 days old)")
    print(f"  - {incomplete_name} (incomplete, has TODOs)")


def clean_test_env(path: str, force: bool = False):
    """Remove test environment, guarding against non-test paths."""
    target = Path(path)
    if not target.exists():
        print(f"No test environment found at {path}")
        return
    if not (force or _is_safe_rmtree_path(target)):
        sys.exit(
            f"error: refusing to rmtree {target} — path does not look like a test "
            f"location. Pass --force to override."
        )
    shutil.rmtree(target)
    print(f"Cleaned up test environment at {path}")


def main():
    parser = argparse.ArgumentParser(
        description="Set up test environment for session-handoff skill"
    )
    parser.add_argument(
        "--path",
        default=DEFAULT_TEST_PATH,
        help=f"Path for test project (default: {DEFAULT_TEST_PATH})"
    )
    parser.add_argument(
        "--clean",
        action="store_true",
        help="Remove test environment instead of creating"
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Bypass the safety check that restricts rmtree to /tmp or 'test' paths"
    )

    args = parser.parse_args()

    if args.clean:
        clean_test_env(args.path, force=args.force)
    else:
        path = create_test_project(args.path, force=args.force)
        init_git_repo(path)
        create_sample_handoffs(path)
        print(f"\nTest environment ready at: {args.path}")
        print(f"\nTo test, run:")
        print(f"  cd {args.path}")
        print(f"  # Then use Claude Code with the session-handoff skill")


if __name__ == "__main__":
    main()
