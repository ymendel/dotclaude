#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = ["pyyaml"]
# ///
"""validate_skill.py - Validate a skill's structure, frontmatter, and links.

Adapted from Anthropic's skill-creator `quick_validate.py`
(https://github.com/anthropics/skills, Apache License 2.0). This is a modified
version per Apache 2.0 section 4(b). Changes from the original:
  - renamed quick_validate.py -> validate_skill.py (grows into the general
    validator for this skill)
  - added PEP 723 inline dependencies so `uv run` needs no manual setup
  - added a relative-link resolution check over SKILL.md and references/

Usage:
    uv run scripts/validate_skill.py <skill-directory>

Checks:
    - SKILL.md exists and opens with valid, closed YAML frontmatter
    - frontmatter carries only allowed properties, with required name + description
    - name is kebab-case and <= 64 characters
    - description has no angle brackets and is <= 1024 characters
    - every relative markdown link in SKILL.md and references/ resolves to a real file

Exit codes:
    0   skill is valid
    1   validation failed (details on stdout)
    2   invalid arguments
"""

import re
import sys
from pathlib import Path

import yaml

ALLOWED_PROPERTIES = {
    "name",
    "description",
    "license",
    "allowed-tools",
    "metadata",
    "compatibility",
}

# Markdown inline links: [text](target)
LINK_PATTERN = re.compile(r"\[[^\]]*\]\(([^)]+)\)")


def check_frontmatter(skill_md: Path) -> list[str]:
    """Return a list of frontmatter problems (empty when valid)."""
    content = skill_md.read_text()
    if not content.startswith("---"):
        return ["SKILL.md has no YAML frontmatter"]

    match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
    if not match:
        return ["SKILL.md frontmatter is not closed with a --- line"]

    try:
        frontmatter = yaml.safe_load(match.group(1))
    except yaml.YAMLError as error:
        # An unquoted description containing ": " parses as a nested mapping and
        # lands here -- the silent title-only failure this check exists to catch.
        return [f"Invalid YAML in frontmatter: {error}"]

    if not isinstance(frontmatter, dict):
        return ["Frontmatter must be a YAML mapping"]

    problems = []

    unexpected = set(frontmatter) - ALLOWED_PROPERTIES
    if unexpected:
        problems.append(
            f"Unexpected frontmatter key(s): {', '.join(sorted(unexpected))}. "
            f"Allowed: {', '.join(sorted(ALLOWED_PROPERTIES))}"
        )

    name = frontmatter.get("name")
    if not name:
        problems.append("Missing 'name' in frontmatter")
    elif not isinstance(name, str):
        problems.append(f"name must be a string, got {type(name).__name__}")
    else:
        name = name.strip()
        if not re.match(r"^[a-z0-9-]+$", name):
            problems.append(
                f"name '{name}' must be kebab-case (lowercase letters, digits, hyphens)"
            )
        elif name.startswith("-") or name.endswith("-") or "--" in name:
            problems.append(
                f"name '{name}' cannot start/end with a hyphen or contain '--'"
            )
        elif len(name) > 64:
            problems.append(f"name is too long ({len(name)} chars, max 64)")

    description = frontmatter.get("description")
    if not description:
        problems.append("Missing 'description' in frontmatter")
    elif not isinstance(description, str):
        problems.append(
            f"description must be a string, got {type(description).__name__}"
        )
    else:
        description = description.strip()
        if "<" in description or ">" in description:
            problems.append("description cannot contain angle brackets (< or >)")
        if len(description) > 1024:
            problems.append(
                f"description is too long ({len(description)} chars, max 1024)"
            )

    return problems


def check_links(skill_dir: Path) -> list[str]:
    """Return a list of broken relative links across SKILL.md and references/."""
    problems = []
    markdown_files = [skill_dir / "SKILL.md", *sorted(skill_dir.glob("references/**/*.md"))]

    for markdown_file in markdown_files:
        if not markdown_file.exists():
            continue
        in_code_fence = False
        for line_number, line in enumerate(markdown_file.read_text().splitlines(), 1):
            # Skip fenced code blocks -- links inside them are syntax examples,
            # not real links (a skill that documents skill-authoring is full of them).
            if line.lstrip().startswith(("```", "~~~")):
                in_code_fence = not in_code_fence
                continue
            if in_code_fence:
                continue
            for match in LINK_PATTERN.finditer(line):
                target = match.group(1).strip()
                # Drop an optional link title: (path "Title")
                target = target.split()[0] if target else target
                # Drop an anchor fragment: (path#section)
                target = target.split("#", 1)[0]
                if not target:
                    continue
                # External links, pure anchors, and template placeholders are out of scope.
                if target.startswith(("http://", "https://", "mailto:", "#", "{")):
                    continue
                # Repo-absolute paths (/docs/adr/...) can't be resolved without a
                # repo root; portability policy is deliberately not enforced here.
                if target.startswith("/"):
                    continue
                resolved = (markdown_file.parent / target).resolve()
                if not resolved.exists():
                    relative = markdown_file.relative_to(skill_dir)
                    problems.append(
                        f"{relative}:{line_number}: broken relative link -> {target}"
                    )

    return problems


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: validate_skill.py <skill-directory>", file=sys.stderr)
        return 2

    skill_dir = Path(sys.argv[1])
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.exists():
        print(f"SKILL.md not found in {skill_dir}", file=sys.stderr)
        return 1

    problems = check_frontmatter(skill_md) + check_links(skill_dir)

    if problems:
        print(f"{len(problems)} issue(s) found:")
        for problem in problems:
            print(f"  - {problem}")
        return 1

    print("Skill is valid!")
    return 0


if __name__ == "__main__":
    sys.exit(main())
