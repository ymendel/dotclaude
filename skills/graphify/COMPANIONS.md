# Companion Infrastructure

What `graphify` depends on beyond the skill directory itself. The skill works once invoked, but the *automatic* part — surfacing a reminder when a project has a knowledge graph so the model knows to consult it before searching raw files — lives in hooks and a rule the skill cannot carry.

## Why this file exists

A skill packages as a self-contained directory and can be installed in many ways — a personal config repo, a plugin, a marketplace install. But anything that integrates with the host — rules loaded passively each session, `settings.json` hooks, permission allowlist entries — lives *outside* the skill directory and doesn't ship with the package. This file is the manual half: when you install `graphify` into a new environment, this is what to set up alongside it.

## 1. External CLI

The `graphify` CLI is a separate tool that must be installed. The skill orchestrates its outputs (the `graphify-out/` directory) but does not ship the tool itself. See SKILL.md for install pointers.

## 2. Host config: `SessionStart` and `PreToolUse` hooks

`graphify`'s value depends on the model being *reminded* that a knowledge graph exists when a project has one — without that, the skill is only invoked when the user remembers to ask. Two hooks in `settings.json` provide the reminder.

### `SessionStart` hook (plain-text reminder at session start)

```jsonc
"SessionStart": [
  {
    "matcher": "startup|resume|clear|compact",
    "hooks": [
      {
        "type": "command",
        "command": "[ -f graphify-out/graph.json ] && echo 'graphify: This project has a graphify knowledge graph. Read graphify-out/GRAPH_REPORT.md before answering codebase questions and prefer graphify-out/wiki/index.md (if present) over raw files. Run `graphify update .` after modifying code.' || true"
      }
    ]
  }
]
```

### `PreToolUse` hook (context injection before exploratory tool use)

```jsonc
"PreToolUse": [
  {
    "matcher": "Read|Glob|Grep|Task",
    "hooks": [
      {
        "type": "command",
        "command": "[ -f graphify-out/graph.json ] && echo '{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"additionalContext\":\"graphify: Knowledge graph exists. Read graphify-out/GRAPH_REPORT.md for god nodes and community structure before searching raw files.\"}}' || true"
      }
    ]
  }
]
```

The `PreToolUse` hook runs on the tool calls most likely to ignore the graph (file reads, globs, greps, sub-agents). The JSON shape uses `hookSpecificOutput.additionalContext` because plain-text stdout from a `PreToolUse` hook is not injected as model-visible context — `SessionStart` and `UserPromptSubmit` can echo plain text, `PreToolUse` cannot. If you already have hooks under either matcher, merge the new commands in rather than replacing.

Without these hooks, `graphify` becomes invocation-only: useful when the user remembers, invisible otherwise.

## 3. Companion rule (passively loaded each session)

The hooks tell the model *that* a graph exists. The rule below tells the model *what to do* with that knowledge across the rest of the session — prefer the graph as the primary entry point for codebase exploration, navigate the wiki when present, keep the graph current after edits.

### Sample wording

Paste this into your own rule file (e.g. `~/.claude/rules/graphify.md`), or into a `CLAUDE.md`, and edit to taste.

> graphify builds a knowledge graph of a codebase, written to `graphify-out/`. When a project has one, use it as the primary entry point for codebase exploration instead of raw file searching.
>
> **Detection.** A project has graphify if `graphify-out/graph.json` exists at its root. The `PreToolUse` and `SessionStart` hooks in `settings.json` surface a reminder when this is the case — the rules below apply only in those projects.
>
> **Usage.**
> - Before answering architecture or codebase questions, read `graphify-out/GRAPH_REPORT.md` for god nodes and community structure.
> - If `graphify-out/wiki/index.md` exists, navigate it instead of reading raw files.
> - After modifying code in a graphify-enabled session, run `graphify update .` to keep the graph current (AST-only, no API cost).

Without this rule, the model defaults to raw-file searching even after the hooks have reminded it that a graph exists, which defeats the point of having generated one.

## Adopting these in a new environment

Rough order:

1. Install the `graphify` CLI per SKILL.md.
2. Merge the `SessionStart` and `PreToolUse` entries above into your `settings.json` `hooks` section. If you already have hooks under those matchers, add the new commands alongside — don't replace.
3. Paste the rule wording into your rule file or `CLAUDE.md`.

None of these are required for the skill itself to function on demand; they make the surrounding workflow automatic instead of invocation-only.
