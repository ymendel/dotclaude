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
- **[scripts/](scripts/README.md)** — tooling for maintaining skills across this repo and a separate team skills repo
- **[docs/adr/](docs/adr/)** — architecture decision records

## Prerequisites

- **[Claude Code](https://claude.ai/code)** — obviously
- **[RTK](https://github.com/rtk-ai/rtk)** — the hooks and rules assume RTK is installed. Without it, the rewrite hook degrades gracefully (commands pass through unchanged), but you'll lose the token savings it provides and the RTK rules won't apply meaningfully.
- **[jq](https://jqlang.github.io/jq/)** — required by the hooks. Both hooks exit silently without it.
- **[gh](https://cli.github.com/)** — used in development workflow rules and expected for GitHub interactions.

## Installation

There's a Makefile to make this simple. Just clone and go.

    $ git clone https://github.com/ymendel/dotclaude.git
    $ cd dotclaude
    $ make

See [the Makefile](Makefile) for the specific steps. In short, it symlinks the repo to `~/.claude`.

## Appreciation

- [softaworks/agent-toolkit](https://github.com/softaworks/agent-toolkit) — several agents and skills adapted from here
- [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) — source for many of the agents
- [terrylica/cc-skills](https://github.com/terrylica/cc-skills) — ascii-diagram-validator and skill-architecture skills
- [robzolkos/skill-rails-upgrade](https://github.com/robzolkos/skill-rails-upgrade) — rails-upgrade skill
- [supabase/agent-skills](https://github.com/supabase/agent-skills) — supabase-postgres-best-practices skill
- [mattpocock/skills](https://github.com/mattpocock/skills) — tdd skill
- [fredrik-hansen](https://github.com/fredrik-hansen/fredrik-hansen/blob/main/HONESTY_RULES.md) — the honesty rules started here
- Strunk & White's *The Elements of Style* — the writing skill is built around it
