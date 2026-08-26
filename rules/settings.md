---
paths: ["**/settings.json", "**/settings.local.json"]
---

# settings.json

Gotchas and conventions for Claude Code's `settings.json`, in three groups: how a rule matches and why a command prompts, how to choose and organize entries, and hook mechanics.

## Permission Glob Patterns

Per the [official docs](https://code.claude.com/docs/en/permissions), `Read` and `Edit` permission rules follow gitignore semantics with four pattern anchors:

| Pattern            | Meaning                                | Example                          | Matches                        |
| :----------------- | :------------------------------------- | :------------------------------- | :----------------------------- |
| `//path`           | **Absolute** path from filesystem root | `Read(//Users/alice/secrets/**)` | `/Users/alice/secrets/**`      |
| `~/path`           | Path from **home** directory           | `Read(~/Documents/*.pdf)`        | `/Users/alice/Documents/*.pdf` |
| `/path`            | Path **relative to project root**      | `Edit(/src/**/*.ts)`             | `<project root>/src/**/*.ts`   |
| `path` or `./path` | Path **relative to current directory** | `Read(*.env)`                    | `<cwd>/*.env`                  |

Two pattern-shape gotchas the docs flag explicitly:

- **`/Users/alice/file` is NOT absolute** — it's project-root-relative. Use `//Users/alice/file` for absolute paths.
- **`*` matches a single directory. `**` matches recursively.** `Edit(~/.claude/*)` does not match subdirectory files. Use `Edit(~/.claude/**)`. Failure mode: subdirectory edits prompt unexpectedly because the rule that looks correct doesn't actually match.

### Symlinks: rules check both paths

A path reached through a symlink is checked twice, against the link and against its target. An **allow** rule applies only when *both* match — so a rule naming one side silently prompts every time, with no signal that the symlink is why. A **deny** rule applies when *either* matches.

This bites constantly here, because `~/.claude` is a symlink to the dotclaude repo and the two paths share no top-level segment: no rule anchored on `.claude/` or on `dotclaude/` covers both, and pairing two rules does not compose.

**So address these files by their canonical path** — `dotclaude/rules/settings.md`, never `~/.claude/rules/settings.md`. The repo is the working directory, so the real path carries no link and the double-check never runs. This holds for the private tree too: an edit reached as `<private-root>/notes/…` goes through clean where the same edit through `~/.claude/notes/…` asks, even though that repo is an added directory rather than the primary one. No allow rule is involved on either side, which is why none of the entries that look like they should help ever did.

The link form is the one always to hand — the environment block lists `~/.claude` as a working directory and this config refers to itself that way throughout — so the prompts read as a property of editing the config rather than as a consequence of how the path was written. That reading is what makes the habit durable, and it is wrong.

`rules/references/settings/claude-symlink.md` carries the docs quote, the resolution rules for a path under `~/.claude` (including the lossy `projects/` directory encoding), and why the broad single-pattern allow rule it used to recommend is not needed. Load it before resolving a `~/.claude/…` path to its real location.

## How Bash Command Patterns Match — `:*`, ` *`, and Word Boundaries

Bash allow/deny rules match against the literal **command string** (not the Read/Edit gitignore path semantics above). Three facts that aren't obvious — the first two per the [permissions docs](https://code.claude.com/docs/en/permissions), the third contradicting them:

- **`:*` is exactly equivalent to a trailing ` *`, and both match end-of-string.** `Bash(ls:*)` and `Bash(ls *)` each match bare `ls` *and* `ls -la` — the trailing wildcard does **not** require an argument after the prefix. The space matters: `Bash(ls *)` enforces a word boundary (so it won't match `lsof`), while `Bash(ls*)` without the space does match `lsof`.
- **Matching is literal, so short and long flag forms are distinct.** `-h` ≠ `--help`, and `Bash(unzip -l:*)` covers `unzip -l` but not `unzip --list`. Whichever form an entry names is the only one it grants. A reason to prefer long-form flags at the gate — see code-style's long-form-flags rule.
- **A leading `*` fires in a deny rule but not in an allow rule.** The docs say a wildcard "can appear at any position in the command, including at the beginning" and offer `Bash(* install)`. That holds for deny — `Bash(*sed -i*)` blocks a `grep` whose *pattern* merely contains the substring — but an allow rule is skipped unless anchored on the command name, the same way the docs say an unanchored allow glob in the *tool-name* position is skipped. So anchor every allow rule, and note that a cross-command exemption (one entry granting `--help` for everything) is not expressible: write per-command entries or accept the prompt. Testing this needs a *write-capable* probe, because the built-in read-only set below never prompts and its documented membership is partial ("These include …") — a clean `sort --help` proves nothing. Failure mode: a leading-`*` allow entry reads as a working grant, never fires, and a prompt on a command it appears to cover gets misdiagnosed as a pattern-shape subtlety.

## How Claude Code Matches Compound Commands

Claude Code splits a compound Bash command on `|`, `&&`, and `;` and evaluates **each segment independently** against the permission rules. Every segment must be individually allowed, or the command prompts. There is no whole-string match for a pipeline — `echo '{}' | jq .` runs only because *both* `echo:*` and `jq:*` are allowed. A rule matching the literal `echo '{}' | jq .` would never fire.

RTK adds a wrinkle, doing its own segment-aware check before Claude Code sees the command — and it treats shapes differently:

- **Pipe with a leading command RTK recognizes** — it rewrites the head (leaving the tail bare) and checks *every* segment against the allow rules: exit 0 (auto-allow) only when all match, otherwise exit 3 (prompt). `gh pr list | grep open` → exit 0. `git show HEAD --stat | sort` → exit 3, because `sort` has no allow rule.
- **Command substitution (`$(...)`, backticks), an `xargs` or loop body, or a pipe/chain whose commands RTK doesn't recognize** — `rtk rewrite` returns exit 1 (passthrough), and Claude Code's own flow then runs on the bare command, splitting it the same per-segment way. So `gh pr create --body "$(…)"` and `which echo && echo done` are decided by Claude Code, not RTK.

Either path needs every segment individually allowed. The rewrite gaps are tracked upstream in rtk-ai/rtk (#1252, #2425, #1347, #1560).

Implication for the allow list: a `Bash(rtk X:*)` rule does **not** cover `X` used inside a compound command — only the standalone, rewritten `rtk X …` form. To auto-allow a safe command in compound usage (pipes, substitutions, heredoc-bodied `gh` calls), add a **bare** `Bash(X:*)` rule alongside the `rtk X:*` one. Do this only for commands safe in every form — `grep` (read-only) and `gh` (destructive subcommands fenced by deny rules). Do **not** blanket-allow a command with destructive flags (`find -delete`, `find -exec`) without pairing the allow with deny carve-outs.

Failure mode this prevents: assuming `rtk gh:*` (or `rtk find:*`, `rtk grep:*`) covers those tools everywhere, then being surprised by a prompt on a PR-created-with-a-heredoc-body or a `find | grep` pipeline — because a segment lacks an allow rule (RTK demotes the pipe to a prompt, or Claude Code's per-segment check fails on a passthrough command).

## Shell Expansion Makes a Command Non-Allowlistable

Claude Code matches a command against the allow rules *statically*, before the shell expands anything. When the command contains expansion it can't resolve ahead of time — a bare `$VAR` (which the parser labels `simple_expansion`), `${VAR}`, or `$(...)`/backtick substitution — the evaluator can't safely match it against an allow rule, so it prompts. That prompt offers only **Yes / No**: there is no "don't ask again" option, because Claude Code won't persist an allow rule for a command whose real content is computed at runtime. The absence of the "don't ask again" line is the tell that expansion, not a missing allow entry, is the cause.

So: when a command will face the permission gate, prefer an expansion-free form. Running two checks as two plain commands carries no expansion. Folding them into a `for … do … $(…) … done` loop does — and the loop is the convenient reach that trips the guard. Split it into plain commands when the task is just a status check or a small comparison. (This is also why command substitution shows up under "How Claude Code Matches Compound Commands" above: RTK passes it through, then Claude Code's own per-segment evaluation hits the same wall.)

**The loop trips the gate on its own account, not only through what it contains.** An observed prompt gave its reason as `Contains for_statement` — a check on the statement type, which fires whether or not the body carries an expansion. Stripping the expansion out of a loop therefore does not make the loop allowlistable. The message is generated from a fixed set of tree-sitter node types: `command_substitution`, `process_substitution`, `expansion`, `simple_expansion`, `brace_expression`, `subshell`, `compound_statement`, `for_statement`, `while_statement`, `until_statement`, `if_statement`, `case_statement`, `function_definition`, `test_command`, `ansi_c_string`, `translated_string`, `herestring_redirect`, `heredoc_redirect`. So `simple_expansion` names one of those eighteen, none of them grantable, and the answer is always a differently-written command rather than an entry. Note how far past loops that reaches — an `if` or `case`, a `( … )` subshell, a `{a,b}` brace expansion, a `$'…'` string, and a `[ … ]` test, so an allow entry naming a bracket test can never fire. `tool-and-shell-safety.md`'s batching rule carries the practical form, and `notes/claude-code-quirks.md` the read this list came from, which is version-specific.

Failure mode this prevents: reaching for a bash loop with command substitution on a task discrete commands handle, hitting an un-suppressible prompt, and assuming the permission *config* is at fault — when the cause is the command that got written, whether the expansion inside it or the loop housing it.

**The Bash sandbox does not fix this.** Even in its auto-allow mode, deny and ask rules are still enforced, and enforcing them requires resolving the command string — exactly what an unresolvable expansion prevents — so an expansion-bearing command still prompts whether the sandbox is enabled or not. The sandbox was evaluated and dropped rather than adopted. The only lever that changes the prompt is auto mode (the permission classifier), which trades the deterministic, audited allowlist for a probabilistic per-command classifier — declined for that reason. Treat expansion prompts as unavoidable and write expansion-free commands (split the loop into discrete commands) rather than reaching for a config fix that doesn't exist.

## What `bypassPermissions` Actually Skips

`--dangerously-skip-permissions` is equivalent to `--permission-mode bypassPermissions`, and the name oversells what it turns off. Per the [permission-modes docs](https://code.claude.com/docs/en/permission-modes), these controls "apply in every mode, including `bypassPermissions`":

- deny rules and explicit ask rules, on every tool
- the org `ask` setting on connector tools
- the `requiresUserInteraction` marker

So a deny entry keeps working under the flag. `Bash(*git push*)` still blocks a push, which is what makes the no-autonomous-push rule structural rather than a matter of the model remembering it. What the mode *does* newly permit is writes to protected paths, which the same docs say "are never auto-approved except in `bypassPermissions` mode."

Read the surviving guarantee as exactly the deny list's enumeration, though, which is narrower than "destructive commands are blocked." The list names `rm -rf`, the `find` delete and exec flags, in-place `sed`, `git push`, hard reset, and the force-checkout family. It does not name plain `rm <file>`, `mv`, `chmod -R`, `truncate`, a redirect over an existing file, or a piped-to-shell download. Under the flag every one of those runs unprompted.

Reach for `acceptEdits` before the flag when the goal is just to stop approving routine filesystem work. It auto-approves `mkdir`, `touch`, `rm`, `rmdir`, `mv`, `cp`, and `sed` on paths inside the working directory or `additionalDirectories`, and the documented process wrappers it sees through are `timeout`, `nice`, and `nohup` — so an `rtk`-prefixed form is outside that set even when the bare command is inside it.

Failure mode this prevents: reasoning about the flag's area of effect from its name. Guessing too broad is what happened here, and it argues *for* the flag's guardrails in a way that collapses the moment anyone checks — while guessing too narrow invites turning it on believing the deny list covers more than it enumerates.

## Deny Patterns Match the Command String, Not the Invocation

Deny rules (`Bash(*git push*)`, `Bash(*rm -rf*)`, `Bash(*find* -delete*)`) match the literal command **string**, with no understanding of what the command does. Any command whose text *contains* the denied substring is blocked — even when it performs no such action. The recurring bite: a `git commit -m '…'` whose message describes the denied pattern, an `echo` or `grep` that mentions it, or a command documenting the deny rules themselves.

This is the safe failure direction for a deny: over-blocking costs a reword, under-blocking could run the destructive command. So the patterns stay broad rather than trying to anchor on the command name, which glob can't cleanly express anyway.

Workarounds when a legitimate command is caught:

- **Reword** so the denied substring doesn't appear — e.g. "the delete and exec flags" instead of the literal flag names.
- **Pass the text via a file.** Write the message to a path and `git commit -F <file>` — the command string is then just `git commit -F <file>`, with the triggering text confined to the file. Deny rules don't read file contents.

Failure mode this prevents: treating an unexpected denial as a broken deny rule or a tooling bug, and retrying variants, when the real cause is the command's *text* tripping a substring deny.

## Paths With Spaces

When constructing shell commands that reference paths containing spaces (e.g. `~/Library/Application Support/`), use `$HOME` with proper quoting instead of backslash-escaping. Claude Code's permission system triggers a separate confirmation dialog for any command containing backslash-escaped whitespace, regardless of allow-list rules.

```bash
# ❌ Triggers backslash-escaped whitespace warning
rtk read "$(ls -t ~/Library/Application\ Support/rtk/tee/*.log | head -1)"

# ✅ No warning — $HOME + quoted path
rtk read "$(ls -t "$HOME/Library/Application Support/rtk/tee/"*.log | head -1)"
```

## Project vs. Global Settings — Match Scope to Use

When adding a permission, choose the file by **scope of use**, not by which settings file happens to be open:

- **`~/.claude/settings.json`** (global) — for tools used across projects: skills, common scripts, shared CLI tools (`gh`, `heroku`, `jq`). The fact that the tool happens to live in one repo today doesn't change this if it's invoked from many.
- **`<project>/.claude/settings.json`** (project, committed) — for permissions other contributors should inherit (the project's build tooling, its CI invocations).
- **`<project>/.claude/settings.local.json`** (project, local-only) — for permissions only this user needs in this project (one-off experimentation, personal CLI shortcuts).

Failure mode: dropping skill-related permissions into a project's `.claude/settings.local.json` because that file already exists. The permission only kicks in when working inside *that* project, not when the same skill is used elsewhere — so the prompts return as soon as the skill is invoked in another repo. Default to global for anything skill-related or cross-cutting.

For paths in skill-related permissions, leading `**` lets a single global rule cover any project: `Write(**/.claude/handoffs/*.md)` matches a handoffs directory in every project the skill is used from.

### A Bash grant for a project's own script has to live in project settings

Read and Edit rules can be anchored to a project (`/path` is project-relative). Bash rules cannot — they match the literal command string, so the `./` in `Bash(./scripts/report.sh:*)` is two characters, not a path. A grant that *reads* as repo-specific fires wherever that string is typed, and a second repo with a same-named script — `check-prerequisites.sh`, `usage-report.sh` — gets its own script run unprompted. Since the pattern can't carry the scope, the file has to: a repo's own script tooling belongs in that repo's committed `.claude/settings.json`.

**The exception is a binstub for a shared standard tool** — `bin/rubocop`, `bin/rspec`. That path sits inside a repo, but the thing being granted is the tool, invoked from every project that uses it, which the global bullet above places at user level alongside `gh` and `jq`. What makes a same-named-script collision dangerous is that the name guarantees nothing about behavior — another repo's `report.sh` could do anything. A binstub for a known tool inverts that: the collision is the point, since every `bin/rubocop` is rubocop. Check it against area of effect below rather than treating the path as decisive — a bespoke script granted globally gains reach it did not have, while a linter's reach is the working tree it is run in either way. Decide per binstub, not per directory: `bin/rails` reaches `db:drop` and a console running arbitrary code, and `bin/ci` runs everything, so neither inherits rubocop's answer.

Two mechanics from the [settings docs](https://code.claude.com/docs/en/settings) decide how the three files interact. **Permission rules merge across scopes rather than override**, so an overlapping pattern in two files is additive and revoking a grant means deleting every copy. And **project allow rules require the workspace-trust step where local ones don't** — a `settings.local.json` grant applies immediately "because this file is yours rather than the repository's", so moving one into `.claude/settings.json` puts it behind trust, which is the right direction for a repo other people clone.

Failure mode this prevents: a grant written for one repo's script applies in every repo, and the surprise arrives as *another project's* script running with no prompt.

## Match a Grant's Breadth to the Command's Area of Effect

Scope picks the *file* an entry lives in. Breadth picks how much of the command the *pattern* covers, and the question that decides it is not "is this command destructive" but **how far does a wrong invocation reach, and is it recoverable where it lands**. A command that writes is not automatically worth a prompt; a command that writes somewhere the current repo's history cannot reach usually is.

Worked cases on either side of that line:

- **A linter binstub — grant it whole.** `Bash(bin/rubocop:*)` covers `--autocorrect-all`, which rewrites files. But they are files in the repo being worked in: they show up in `git status`, they diff, and a checkout undoes them. The area of effect is the working tree already being watched, and it does not grow when the grant does — which is what makes the user-level home safe here (see the binstub exception above).
- **`Bash(./scripts/sync-skill.sh *--dry-run)` — anchored on the safe flag.** A real `--to-theirs` run overwrites a whole skill directory in *another* repo, deletions included, so the write lands where this repo's history is no help and where nobody is watching `git status`. The dry runs are worth granting; each real one is worth seeing.

The general test: name where a wrong invocation lands, and who can undo it. Inside the current working tree and git-tracked → grant the command whole. Another repo, a remote, a gitignored or untracked path, someone else's inbox → anchor on the safe subcommand or flag and accept the prompt on the rest.

Anchoring has a mechanical cost worth knowing before you reach for it. A pattern like `Bash(./scripts/sync-skill.sh *--dry-run)` matches on the string's *tail*, so the flag has to come last on every invocation or the grant silently misses and the command prompts anyway. Where a command has no single safe flag to anchor on — a linter whose read-only shape is the absence of a flag rather than the presence of one — anchoring is not expressible, and the choice collapses to grant-whole or prompt-always.

This composes with the scope section above rather than substituting for it: a broad pattern in the right file is still broad, and a narrow one in the user-level file still fires in every repo that happens to type the same string.

Failure mode this prevents: breadth gets decided by how destructive the command *sounds*. A linter that edits files reads as risky and gets anchored into uselessness, while a script named like ordinary project tooling reads as routine and gets granted whole — even though the second one is the one that writes outside the repo. The prompts then accumulate on the command that never needed them, and the standing grant sits on the one that did.

## Skill-Script Permissions — Frontmatter `allowed-tools` vs. settings.json

A skill's script can be auto-allowed two ways, and they differ in *scope*:

- **`settings.json` allow rule** — always in effect, no matter who invokes the script.
- **Skill frontmatter `allowed-tools`** — in effect *only while that skill is active*. Per the [docs](https://code.claude.com/docs/en/skills), it "grants permission for the listed tools while the skill is active, so Claude can use them without prompting you for approval. It does not restrict which tools are available."

Do not invert this. `allowed-tools` *pre-approves* — it is not "the only tools this skill may use." Every tool stays callable — listed ones just skip the prompt while the skill runs. The field that *restricts* is `disallowed-tools`, which removes tools from the pool while the skill is active.

Choosing the home:

- **Invoked only via explicit skill use** — frontmatter is cleaner, and it's portable: `allowed-tools` travels with the skill to other machines, repos, or plugins. A `settings.json` entry stays on this machine.
- **Invoked directly, outside skill activation** — `settings.json`, because frontmatter won't cover it. Common cases: running `list_handoffs.py` on a "what handoffs exist" request, or `validate_mermaid.py` mid-doc-work — the skill isn't loaded that turn, so a frontmatter-only permission would prompt.
- **Distributing a skill** — additive, not either/or: declare `allowed-tools` so the skill works standalone on a fresh machine, and keep the `settings.json` entry for local direct-invocation. Redundant allow is harmless — both just permit.

Two more considerations:

- **Project skills need trust first.** For a skill checked into a project's `.claude/skills/`, `allowed-tools` takes effect only after the workspace-trust dialog is accepted — "a skill can grant itself broad tool access." User-level skills under `~/.claude` aren't gated this way.
- **Audit visibility.** `settings.json` keeps every auto-allow in one file. Frontmatter co-locates the permission with its skill but scatters the overall picture.

Failure mode this prevents: moving a skill-script permission to frontmatter-only, on the assumption that "the skill covers it," silently reintroduces prompts for every direct or proactive invocation that happens when the skill isn't active — exactly the invocations that motivated the `settings.json` entry in the first place.

## The Offered Save Rule Is Not the Entry to Write

The "Yes, and don't ask again for: …" option writes a rule generated from the command at hand, and it runs broader than the entry the situation calls for. Two observed shapes:

- **Broader in pattern** — a `trafilatura --URL` fetch offered `trafilatura *`, which also grants `--crawl` and `--explore`, flags that walk whole sites. The right entry was `Bash(trafilatura --URL:*)`.
- **Wrong in scope, and bundled** — a compound command offered one grant covering both its halves, scoped to the project it ran in, for a version check belonging in the global file.

Read the offer as a signal that an entry is missing, not as the entry: take plain "Yes", then write the rule by hand where its scope belongs. The offer is still worth reading, since it shows the string the gate actually matched — what `rule-maintenance.md` says to build from.

Failure mode this prevents: the offer is the path of least resistance at exactly the moment the goal is to get on with the work, so it is accepted unread — granting more than intended, in the wrong file, and indistinguishable afterward from a considered entry.

## Organizing the allow list

Claude Code ignores the order of `allow` entries — the layout exists only for human scanning. Keep it so a reader can find an entry and knows where a new one goes:

- **Group by tool**, in the order the tool name sorts: `Bash` → `Edit` → `Read` → `Skill` → `WebFetch`. Separate the tool groups with a blank line.
- **Within `Bash`**, keep two groups: the general commands (alphabetical), then the skill-script runners (`python3 …/scripts/…`, `uv run …/scripts/…`) as a separate trailing group.
- **Within `Edit` / `Read`**: alphabetical.
- **Within `WebFetch`**: group by ecosystem or vendor — all Anthropic/Claude together, all GitHub together, all Ruby together, &c. Which ecosystem a domain serves is a **judgment call**. Order *within* a group is mechanical — a **reversed-label sort** (compare domains right-to-left: TLD, then registrable name, then subdomain), so `github.com` sorts before `docs.github.com`, and a `.com` domain before a `.org` one. Do **not** blank-line-separate the WebFetch sub-groups — they're contiguous runs inside the one `WebFetch` block.

The split is deliberate: only *group assignment* needs a human, everything else is reproducible. Cross-group order (which ecosystem leads) is curated too — append a new group where it reads well rather than re-sorting the existing ones.

**Blank-line separators are cosmetic.** JSON has no comments, so a blank line is the only visual separator available — but any reformatter (prettier, `jq` piped to file, editor format-on-save) strips blank lines inside an array. Never rely on them structurally — they are a reading aid a format pass will silently erase.

Failure mode this prevents: without recording the convention, the next reorg "helpfully" collapses the whole array into one mechanical sort, destroying the ecosystem grouping — scattering `rubydoc.info` away from `rubygems.org` and `*.github.io` away from `github.com`, the exact adjacencies the layout was built to create.

## Path Fields vs. Hook Commands

Path fields (e.g. `additionalDirectories`) support `~/` tilde expansion but **not** `$HOME` variable expansion. Use `~/.claude`, not `$HOME/.claude`.

Hook `command` strings are executed by bash, so `$HOME` works fine there.

## Hook Output Semantics Vary By Hook Type

**Do not assume stdout from one hook type behaves like another.** Each hook type has its own output mechanism, and a hook that emits the wrong shape of output will silently do nothing useful — the failure mode is invisible.

- **`SessionStart`, `UserPromptSubmit`**: stdout is injected as a system reminder the model sees. Plain-text echo works.
- **`PreToolUse`, `PostToolUse`**: support JSON output with `hookSpecificOutput.additionalContext` to inject context for the model.
- **`PreCompact`**: JSON output only. Supports `decision` (block / not block) and `systemMessage` (user-facing). **Cannot inject context for the model to react to.** If the goal is to prompt the model to take action before compaction, PreCompact is the wrong tool — by hook semantics, the only intervention available is blocking compaction outright. (Storybloq's PreCompact hook works only because their MCP server has the model writing structured state to `.story/` *throughout* the session. The hook just snapshots already-written state. Without an incremental-write substrate, a DIY PreCompact hook can't replicate this.)

**Verify hook output semantics from the official docs (https://code.claude.com/docs/en/hooks) before designing a hook that depends on the model seeing the output.** Don't generalize from one hook type to another.

## PreToolUse Hooks Block an Allowlisted Command Only via Exit Code 2

A `PreToolUse` hook can force a command to be blocked even when a `permissions.allow` rule would auto-approve it — but **only by exiting with code 2** (a "blocking hook"). A JSON `hookSpecificOutput.permissionDecision: "deny"` does **not** override a matching allow rule: per the [docs](https://code.claude.com/docs/en/permissions), hook decisions don't bypass permission rules, so a matching `allow` wins against a hook's JSON `deny`. Exit code 2 is the exception — it stops the tool call *before* permission rules are evaluated, so it beats `allow`.

PreToolUse hooks do run on every tool call, allowlisted ones included — an allow match doesn't skip the hook. So the hook always gets its say. The only question is which blocking mechanism it uses, and only exit 2 is authoritative over an allow rule.

The live case: `hooks/uv-run-guard.sh` guards the deliberately-broad `Bash(uv run *skills/skill-architecture/scripts/*.py*)` allow entry. The glob's leading `*` can't exclude a `uv run` option *before* the script path (`--with`, `--index-url`, `--python`, …) that would fetch and execute arbitrary code. The hook detects that dangerous shape and `exit 2`s with a stderr message. The safe bare-`uv run <script>` shape falls through to the allow rule. Returning JSON `deny` there would silently fail — the allow rule would still auto-approve.

Failure mode this prevents: writing a guard hook that returns `permissionDecision: "deny"`, watching it correctly block a command that *isn't* allowlisted, and assuming it also blocks the allowlisted one — when the allow rule quietly wins and the dangerous command runs with no prompt. Exit 2 is the mechanism that beats an allow rule. The JSON `deny` field does not. (The docs are explicit on exit-2 precedence but read as ambiguous on JSON-`deny`-vs-`allow`, which is itself the reason to reach for exit 2.)
