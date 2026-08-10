# GitHub Issue-Closing Keywords — Matching Behavior and the Pre-Merge Check

> Not loaded in context by default. See `rules/development-workflow.md` for behavioral guidance.

## What GitHub actually matches

A close fires on `<keyword> #NN` anywhere in the PR description, in any of three verb families, each
in every tense: `close` / `closes` / `closed`, `fix` / `fixes` / `fixed`, `resolve` / `resolves` /
`resolved`. Case does not matter, and the `#` may be omitted in some contexts.

Two consequences that catch people out:

- **A keyword is needed before *each* reference.** `Closes #1, #2` closes #1 only. #2 is left open,
  which is why the footer takes one reference per line.
- **Explanatory prose counts.** "The follow-up PR that resolves #40 is separate" closes #40 when
  *this* PR merges. Nothing about the sentence's meaning is consulted — only the pattern.

## The check before finalizing

```bash
grep -iE '(close[sd]?|fix(es|ed)?|resolve[sd]?) #?[0-9]+' <body-file>
```

Every hit should be in the footer block and intended. For an issue the PR should *not* close, use a
non-keyword verb — `addresses #NN`, `part of #NN`, `see #NN` — or keep the keyword clear of the
number.
