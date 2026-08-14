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

**That site drops tables as well as code, so treat the Claude docs as curl-only.** A fetch of the
permissions page came back with its prose referring to "the table" that shows approval lifetimes,
and no table anywhere in the output. Prose that *names* its missing figure is the lucky case — it
announced the hole. A dropped table the surrounding prose never mentions leaves nothing behind at
all, which is why the count check below cannot help here. Whenever the fetch is of Anthropic's own
documentation, go straight to `rtk proxy curl -sL`.

Confirmed against a second page, and the loss is worse than the formatting: the skills page's
frontmatter reference renders 71 pipe-table rows under curl and **zero** under trafilatura, and four
strings that appear only inside those cells are absent from the extraction entirely. So the cells are
discarded rather than flattened, and nothing in the output marks where they were. The field names
themselves still appear 11 times, from prose and YAML examples elsewhere on the page — which is the
trap in miniature, since a search for a term the table defines still hits, and hits somewhere that
never carried the definition.

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

trafilatura runs through Bash, so an agent can only use it with the Bash tool — and after the agent
prune, the split is clean enough to state without a table.

Every kept agent that can fetch at all has Bash, and every one of them loads these rules, so nothing
needs passing in the prompt. `codebase-pattern-finder` and `mermaid-diagram-specialist` carry neither
Bash nor WebFetch, which means they cannot fetch by any route — a fetch is not something to delegate
to them, rather than something to work around.

`Explore` is the one case needing a word in the prompt, and for the opposite reason: it has Bash and
does *not* load these rules, so it will reach for WebFetch unless told otherwise. Say so when the
result has to be verbatim, per `agents.md`.

Should an agent ever be added that lacks Bash but carries WebFetch, that is the case where no prompt
helps — widen its `tools:` or accept a summary and don't treat it as verbatim.
