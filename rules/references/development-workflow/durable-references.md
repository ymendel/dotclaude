# Durable References — Stable Identity vs. Volatile Locator

> Not loaded in context by default. See `rules/development-workflow.md` for behavioral guidance.

Which form to use when referencing something from an artifact that has readers off your machine — a
PR description, ADR, issue, commit message, handoff, or shared skill content.

| Referencing | Use | Not |
|---|---|---|
| a project file | a tracked path, checked with `git ls-files <path>` | anything under `.claude/`, which the user's `~/.gitignore` hides globally even in repos whose own `.gitignore` doesn't list it |
| a commit | the subject line, or branch-plus-position ("the tip of `ym/graphify`") | a bare SHA, unless the commit is on `main` or otherwise merged — rebase, amend, and squash-on-merge all rewrite it |
| an ADR | the number, "ADR 0005", or `[ADR 0005](docs/adr/0005-….md)` where a click-through is wanted | the bare file path, whose descriptive slug rots on rename |
| a GitHub issue or PR | the full URL, which GitHub auto-shortens to the right form in context | a hand-built cross-repo `owner/repo#NN`, inert text everywhere else — a same-repo `#NN` typed by hand is fine |

Where the volatile locator is genuinely useful, pair it with the stable one: a SHA quoted alongside
its subject line still resolves by meaning after the hash is gone.

## Naming an unreachable file is fine. Linking it is not.

A file the reader can't open — private, gitignored, in a companion repo — is often still worth
naming, and a code-span mention (`` `parked-ideas.md` ``) carries the information without promising a
destination. A markdown link makes that promise and breaks it, and the reader learns nothing except
that the document is wrong. So mention freely, and link only what `git ls-files` confirms.
