# Fetching a Page — Evidence and Checks

> Not loaded in context by default. See `rules/searching.md` for behavioral guidance.

Supporting material for the trafilatura / curl / WebFetch choice: what was measured, how to check
for silently dropped content, and why delegated fetches can't follow the same ordering.

## What trafilatura drops, measured

Extraction quality varies by site, and the variation is silent — nothing errors, and the output
reads as the whole page.

| Page | Fenced code blocks kept |
|---|---|
| MDN, `Array.prototype.flatMap` | 18 |
| readthedocs, trafilatura's own CLI docs | 18 |
| `code.claude.com/docs/en/permissions` (Mintlify) | 0 |

The third is not an artifact of the page having no code. Its raw HTML holds six `<pre>` elements,
and parsing each one's text and searching for it in the output finds it in **none** of
`--markdown`, `--xml`, or `--html`. `--recall`, which trades precision for coverage, doesn't
recover them either. So the extractor discards block code on that site, and no output format or
flag routes around it.

Prose extraction on that same page was intact and compact: 623 KB of HTML in, 35 KB of markdown
out.

The practical consequence lives in `searching.md` — pick the tool by what the fetch is *for*, and
go straight to curl when the payload is the code. What follows is the fallback for when that
wasn't clear up front.

## The count check

Comparing block-code counts costs one extra fetch but no context, because the raw HTML is reduced
to an integer before it is ever read:

```
rtk proxy curl -sL "$URL" | grep -c '<pre'
```

Compare that against the fence count in the trafilatura output. A mismatch means fall back to curl
for the real content.

Its limits, which matter as much as the recipe:

- It catches **block code only**. A dropped table, image, or prose section produces no discrepancy.
- There is no general completeness check short of diffing against the raw HTML — which costs
  exactly what trafilatura was meant to save, so it is not a routine step.
- A page whose code is rendered client-side has no `<pre>` in the raw HTML either, so the check
  reports agreement while both tools are equally blind. That is the JavaScript caveat, not an
  extraction problem.

## Why delegated fetches differ

trafilatura runs through Bash, so a sub-agent can only use it if it has the Bash tool and is told
to. Neither holds by default:

| Agent | Bash? | Practical fetch path |
|---|---|---|
| `search-specialist` | no | WebFetch / WebSearch only |
| `data-researcher` | no | WebFetch / WebSearch only |
| `Explore` | yes | capable, but won't reach for it unless the prompt says so |

`agents.md` covers the general rule that a sub-agent inherits none of these rules and needs its
constraints passed in the prompt. This is one of the cases where the constraint is worth passing —
or worth accepting WebFetch's summary and not treating the result as verbatim.
