# graphify

graphify builds a knowledge graph of a codebase, written to `graphify-out/`. When a project has one, use it as the primary entry point for codebase exploration instead of raw file searching.

## Detection

A project has graphify if `graphify-out/graph.json` exists at its root. The `PreToolUse` and `SessionStart` hooks in `settings.json` surface a reminder when this is the case — the rules below apply only in those projects.

## Usage

- Before answering architecture or codebase questions, read `graphify-out/GRAPH_REPORT.md` for god nodes and community structure.
- If `graphify-out/wiki/index.md` exists, navigate it instead of reading raw files.
- After modifying code in a graphify-enabled session, run `graphify update .` to keep the graph current (AST-only, no API cost).
