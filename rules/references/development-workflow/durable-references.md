# Durable References — Stable Identity vs. Volatile Locator

> Not loaded in context by default. See `rules/development-workflow.md` for behavioral guidance.

Which form to use when referencing something from an artifact that has readers off your machine — a
PR description, ADR, issue, commit message, handoff, or shared skill content.

| Referencing | Use | Not |
|---|---|---|
| a project file | a tracked path, checked with `git ls-files <path>` | anything under `.claude/`, which the user's `~/.gitignore` hides globally even in repos whose own `.gitignore` doesn't list it |
| a commit | the subject line, or branch-plus-position ("the tip of `ym/graphify`") | a bare SHA, unless the commit is on `main` or otherwise merged — rebase, amend, and squash-on-merge all rewrite it |
| an ADR | the number, "ADR 0005" — plus `[ADR 0005](docs/adr/0005-….md)` inside the repo, where a click-through is wanted and a relative path resolves | the bare file path, whose descriptive slug rots on rename; and on a GitHub surface the blob URL, which is longer than the number and answers nothing the number didn't |
| a GitHub issue or PR | the full URL, bare, which GitHub auto-shortens to the right form in context | a hand-built cross-repo `owner/repo#NN`, inert text everywhere else — a same-repo `#NN` typed by hand is fine; and `[text](url)` on a GitHub surface, which suppresses both the short form and the backlink on the target |

Where the volatile locator is genuinely useful, pair it with the stable one: a SHA quoted alongside
its subject line still resolves by meaning after the hash is gone.

## Paste it bare on a GitHub surface

GitHub autolinks a bare URL and renders it in its own short form — `owner/repo#NN` for a pull request
or issue, `owner/repo@sha` for a commit, shortened further for a same-repo reference and correct
about which repo it points at either way. Wrapping it in `[text](url)` throws all of that away: the
label is a second copy of the reference, free to say `#30` where the URL says `#35`, and the markup
suppresses GitHub's backlink on the target.

The corollary covers what GitHub does *not* autolink. An ADR, a doc, or a file has no short form to
gain, and the only link available on a GitHub surface is a blob URL — longer than `ADR 0015`, and
answering nothing the number didn't. So name those there rather than linking them. Inside the repo,
where a relative path resolves and the reader can click through, the link is worth having.

## Naming an unreachable file is fine. Linking it is not.

A file the reader can't open — private, gitignored, in a companion repo — is often still worth
naming, and a code-span mention (`` `parked-ideas.md` ``) carries the information without promising a
destination. A markdown link makes that promise and breaks it, and the reader learns nothing except
that the document is wrong. So mention freely, and link only what `git ls-files` confirms.
