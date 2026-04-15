# dotclaude

Yossef Mendelssohn's [Claude Code](https://claude.ai/code) config.

## Consideration

This is personal config, and it's going to reflect my preferences, workflows, and the way I think about things. I'm not against others using any of it, but I'd encourage you to treat it as inspiration rather than installation.

## What's Here

- **CLAUDE.md** — the top-level instructions Claude always has in context: communication style, behavior, &c.
- **rules/** — more detailed rules, also always loaded: code style, development workflow, honesty, ADRs, self-improvement
- **skills/** — invokable skills that extend Claude's capabilities for specific tasks
- **agents/** — custom subagent configurations
- **settings.json** — Claude Code settings

## Installation

There's a Makefile to make this simple. Just clone and go.

    $ git clone https://github.com/ymendel/dotclaude.git
    $ cd dotclaude
    $ make

See [the Makefile](Makefile) for the specific steps. In short, it symlinks the repo to `~/.claude`.

## Appreciation

- [softaworks/agent-toolkit](https://github.com/softaworks/agent-toolkit) — several subagents and skills adapted from here
- [fredrik-hansen](https://github.com/fredrik-hansen/fredrik-hansen/blob/main/HONESTY_RULES.md) — the honesty rules started here
- Strunk & White's *The Elements of Style* — the writing skill is built around it
