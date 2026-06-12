#!/usr/bin/env python3
"""
Validate Mermaid diagrams using merman-cli.

For each input (a .mmd file, a .md file with ```mermaid fences, or stdin):
- Parses each block with `merman-cli parse`. Reports errors with location.
- On parse success, renders an ASCII preview via `merman-cli render --format ascii`.
  Inlines previews under ASCII_INLINE_LINE_LIMIT lines; otherwise writes to a
  tempfile and prints a pointer.

Exit 0 if every block parses; 1 if any fail; 2 on environment errors
(merman-cli not installed, bad input path).

TODO: see ../TODO.md for a sketched semantic-JSON linter pass (orphan node
refs, dangling edges, mismatched class-diagram relationship arrows) that
would sit on top of `merman-cli parse --pretty` output.

Usage:
    validate_mermaid.py path/to/diagram.mmd
    validate_mermaid.py docs/architecture.md
    validate_mermaid.py file1.mmd file2.md
    cat diagram.mmd | validate_mermaid.py -
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
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator

ASCII_INLINE_LINE_LIMIT = 60
FENCE_OPEN_PREFIX = "```mermaid"
FENCE_CLOSE = "```"


@dataclass
class Block:
    source: str
    text: str
    origin_line: int


def extract_blocks(path: Path) -> list[Block]:
    """Pull every ```mermaid fence out of a markdown file."""
    blocks: list[Block] = []
    current: list[str] | None = None
    current_start = 0
    block_index = 0
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        stripped = line.lstrip()
        if current is None:
            if stripped.startswith(FENCE_OPEN_PREFIX):
                current = []
                current_start = lineno + 1
        else:
            if stripped.startswith(FENCE_CLOSE):
                block_index += 1
                blocks.append(
                    Block(
                        source=f"{path}:block-{block_index}@L{current_start}",
                        text="\n".join(current),
                        origin_line=current_start,
                    )
                )
                current = None
            else:
                current.append(line)
    if current is not None:
        block_index += 1
        blocks.append(
            Block(
                source=f"{path}:block-{block_index}@L{current_start} (unclosed fence)",
                text="\n".join(current),
                origin_line=current_start,
            )
        )
    return blocks


def blocks_from_input(arg: str) -> Iterator[Block]:
    if arg == "-":
        yield Block(source="<stdin>", text=sys.stdin.read(), origin_line=1)
        return
    p = Path(arg)
    if not p.is_file():
        print(f"error: not a file: {arg}", file=sys.stderr)
        sys.exit(2)
    if p.suffix == ".mmd":
        yield Block(source=str(p), text=p.read_text(encoding="utf-8"), origin_line=1)
    elif p.suffix == ".md":
        yield from extract_blocks(p)
    else:
        print(
            f"error: unsupported extension {p.suffix} (expected .mmd or .md): {arg}",
            file=sys.stderr,
        )
        sys.exit(2)


def run_merman(args: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        ["merman-cli", *args],
        capture_output=True,
        text=True,
    )


def validate_block(block: Block) -> bool:
    """Validate one block. Returns True if parsing succeeded."""
    print(f"\n[{block.source}]")

    with tempfile.NamedTemporaryFile(
        "w", suffix=".mmd", delete=False, encoding="utf-8"
    ) as tmp:
        tmp.write(block.text)
        tmp_path = Path(tmp.name)

    try:
        parse_result = run_merman(["parse", str(tmp_path)])
        if parse_result.returncode != 0:
            print("  PARSE FAILED")
            error_text = (parse_result.stderr or parse_result.stdout).rstrip()
            for line in error_text.splitlines() or ["(no error message returned)"]:
                print(f"    {line}")
            return False

        print("  PARSE OK")

        render_result = run_merman(["render", "--format", "ascii", str(tmp_path)])
        if render_result.returncode != 0:
            # Parse passed; render didn't. Likely a coverage gap in merman's ASCII
            # renderer rather than a problem with the diagram itself. Don't fail.
            print(
                "  ASCII render unavailable (parse OK, render returned non-zero — "
                "likely a coverage gap)"
            )
            for line in (render_result.stderr or "").rstrip().splitlines():
                print(f"    {line}")
            return True

        ascii_lines = render_result.stdout.rstrip("\n").splitlines()
        if len(ascii_lines) <= ASCII_INLINE_LINE_LIMIT:
            print(f"  ASCII ({len(ascii_lines)} lines):")
            for line in ascii_lines:
                print(f"    {line}")
        else:
            preview = tempfile.NamedTemporaryFile(
                "w",
                prefix="merman-preview-",
                suffix=".txt",
                delete=False,
                encoding="utf-8",
            )
            preview.write(render_result.stdout)
            preview.close()
            print(
                f"  ASCII render: {len(ascii_lines)} lines (above {ASCII_INLINE_LINE_LIMIT}-line "
                f"inline cap) — wrote {preview.name}"
            )

        return True
    finally:
        try:
            tmp_path.unlink()
        except OSError:
            pass


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate Mermaid diagrams via merman-cli.",
        epilog="Returns 0 if every block parses, 1 if any fail, 2 on environment errors.",
    )
    parser.add_argument(
        "inputs",
        nargs="+",
        help=".mmd files, .md files (extracts ```mermaid fences), or - for stdin",
    )
    args = parser.parse_args()

    if shutil.which("merman-cli") is None:
        print(
            "error: merman-cli not found on PATH.\n"
            "  Install with `brew install merman-cli` (or `cargo install merman-cli`).",
            file=sys.stderr,
        )
        return 2

    total = 0
    failed = 0
    for arg in args.inputs:
        for block in blocks_from_input(arg):
            total += 1
            if not validate_block(block):
                failed += 1

    print()
    if failed == 0:
        print(f"{total} OK")
        return 0
    print(f"{total - failed} OK, {failed} FAILED")
    return 1


if __name__ == "__main__":
    sys.exit(main())
