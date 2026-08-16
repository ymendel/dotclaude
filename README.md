# dotclaude

Yossef Mendelssohn's [Claude Code](https://claude.ai/code) config.

## Consideration

This is personal config, and it's going to reflect my preferences, workflows, and the way I think about things. I'm not against others using any of it, but I'd encourage you to treat it as inspiration rather than installation.

## What's Here

- **CLAUDE.md** — the top-level instructions Claude always has in context: communication style, behavior, &c.
- **[rules/](rules/README.md)** — more detailed rules, also always loaded: code style, development workflow, honesty, ADRs, self-improvement, RTK
- **[skills/](skills/README.md)** — invokable skills that extend Claude's capabilities for specific tasks
- **[agents/](agents/README.md)** — custom subagent configurations
- **settings.json** — Claude Code settings
- **hooks/** — the `PreToolUse` guards and command rewrites registered in `settings.json`, with checks over them in `hooks/test/` (`./hooks/test/run-checks.sh`)
- **[scripts/](scripts/README.md)** — tooling for maintaining skills across this repo and a separate team skills repo
- **[docs/adr/](docs/adr/)** — architecture decision records

## Prerequisites

- **[Claude Code](https://claude.ai/code)** — obviously
- **[RTK](https://github.com/rtk-ai/rtk)** — the hooks and rules assume RTK is installed. Without it, the rewrite hook degrades gracefully (commands pass through unchanged), but you'll lose the token savings it provides and the RTK rules won't apply meaningfully.
- **[jq](https://jqlang.github.io/jq/)** — required by the hooks. Without it they exit silently and their guards and rewrites are quietly skipped.
- **[gh](https://cli.github.com/)** — used in development workflow rules and expected for GitHub interactions.
- **[Python 3](https://www.python.org/)** — runs the session-handoff scripts, and the `python`→`python3` rewrite hook targets it. Without it, handoff creation and loading fail and the rewrite hook no-ops.
- **[uv](https://github.com/astral-sh/uv)** — runs the skill-architecture skill's validator and scaffolding scripts (`uv run …`). Needed only when authoring or validating skills — the allowlist and `uv-run-guard.sh` hook assume it for that path.
- **[trafilatura](https://github.com/adbar/trafilatura)** — extracts a web page's main content as markdown, the first choice for reading a page under the searching rules (`uv tool install trafilatura`). Without it those fetches fall back to `curl` for raw HTML or WebFetch for a summary, both of which still work — you lose a compact verbatim option, not a capability.

To verify these are on your `PATH`, run `./scripts/check-prerequisites.sh` — it warns on anything missing and never fails.

## Installation

There's a Makefile to make this simple. Just clone and go.

    $ git clone https://github.com/ymendel/dotclaude.git
    $ cd dotclaude
    $ make

See [the Makefile](Makefile) for the specific steps. In short, it symlinks the repo to `~/.claude`.

## Appreciation

- [softaworks/agent-toolkit](https://github.com/softaworks/agent-toolkit) — several agents and skills adapted from here, including session-handoff
- [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) — source for many of the agents
- [terrylica/cc-skills](https://github.com/terrylica/cc-skills) — ascii-diagram-validator and skill-architecture skills
- [supabase/agent-skills](https://github.com/supabase/agent-skills) — supabase-postgres-best-practices skill
- [mattpocock/skills](https://github.com/mattpocock/skills) — tdd and knowledge-grill skills
- [alkofu/ai-tpk](https://github.com/alkofu/ai-tpk) — commit-message-guide skill
- Flagrant — adr, adr-refine, purposeful-commits, and rails-test-discipline skills
- [Chris Arcand — Purposeful Commits](https://chrisarcand.com/purposeful-commits/) — the method the purposeful-commits skill is built on
- [fredrik-hansen](https://github.com/fredrik-hansen/fredrik-hansen/blob/main/HONESTY_RULES.md) — the honesty rules started here
- Strunk & White's *The Elements of Style* — the writing skill is built around it

## License

[MIT](LICENSE). Skills adapted from upstream projects carry an `ATTRIBUTION.md` preserving the upstream notice. See each skill's directory.
