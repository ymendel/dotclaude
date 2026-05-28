# Feedback

Overflow for rules and feedback that don't fit an existing rule file. When in doubt, capture a lesson here rather than agonizing over its permanent home or skipping it — but this file loads into context every session like any rule, so it's revisable staging, not free staging. Periodically review: if an entry has grown into a pattern or belongs with a coherent topic, extract it into an appropriate rule file; prune what hasn't earned its place rather than letting the file accrete.

## Disambiguate global vs. project scope before editing

When the user refers to "the rule," "the skill," "settings.json," "the hook," or a similar artifact that exists in both global (`~/.claude/...`) and project-local (`.claude/...`, `CLAUDE.md`) forms, ask which scope is meant before editing — unless the surrounding context makes it unambiguous (e.g., the user just opened the global file, or just named a project-only artifact).

**Why:** Ambiguity here has consistently produced edit-and-revert cycles where Claude guessed the wrong scope. The user shouldn't have to talk like a robot ("the global naming-analyzer skill") to keep Claude from guessing — one disambiguating question is cheaper than a wrong edit.

**How to apply:** A one-line question is enough: "Global `~/.claude/settings.json` or project `.claude/settings.json`?" Do not begin editing or searching until the scope is settled. When the context truly is unambiguous, proceed without asking — over-asking is its own friction.

## Show templates in full; don't compress them

When reviewing or designing a skill, "don't restate what Claude already knows" (the standard knowledge-delta rubric) applies to *concepts and procedures*, not to *templates and reference artifacts*. A template is the artifact the model is supposed to produce — showing it in full is what makes the output reliable. Compressing it to "you know the standard shape, right?" risks drift in exactly the parts that matter (heading capitalization, status vocabulary, section ordering, project-specific overlays like a required prefix or label).

**Why:** Misapplied this on 2026-05-21 when reviewing the `adr` skill via `skill-judge`. Suggested cutting the Nygard template restatement as "Activation, Claude knows this" — but the template was the *artifact*, and the project-specific Consequences-valence prescription was baked into it inline. Cutting it would have undone work just done to make that prescription concrete. User caught it.

**How to apply:** When skill-judge or any similar review flags a section as "Claude already knows this," ask whether the section is a *template/example to copy* or *guidance to internalize*. If template/example, the right action is keep-and-tighten (drop redundant examples, keep the canonical one), not compress-to-pointer. If guidance, the standard compression rule applies.

## Don't let a recent instance inflate a frequency estimate

When estimating how often something happens, separate the base rate from the salience of a recent occurrence. A single vivid instance — especially one that just happened in the current conversation — pulls the estimate upward and makes "rare" feel "frequent." The danger compounds when a recommendation then rides on the inflated estimate.

**Why:** On 2026-05-27, after a newly-added `*git add -A*` deny rule false-positived on its own commit message, I claimed the false-positive "isn't rare in this repo" and recommended dropping the rule. The real base rate is near-zero outside meta-sessions about git tooling; the lone occurrence had just happened and inflated the estimate. The user pressed ("how often would you *think*...?") and the estimate collapsed to "negligible" — the recommendation had been built on salience, not frequency.

**How to apply:** When asked "how often does X happen," or when about to recommend an action whose value depends on a frequency, deliberately discount the just-happened instance and ask: outside the context that made X salient right now, when does X actually occur? Label the result as an estimate, and if a single recent event is the main evidence, say so. This is distinct from honesty.md's "don't present estimates as measurements" — there the estimate is unlabeled; here it was labeled loosely but the estimate itself was biased by recency.

## Grep for the broken invariant when implementing a flip

When the work is a constraint relaxation, invariant flip, or "one X per Y → many X per Y" semantic change, the issue's enumerated sites are a starting point, not the full list. Identify the literal *code shape* the old invariant produced — almost always a recurring query pattern, predicate, or lookup — and grep the codebase for that shape *before* declaring the implementation complete. Audit each hit against the new semantics.

**Why:** On 2026-05-28, during a Rails invariant relaxation (one-X-per-Y → many-X-per-Y) on a private project, the issue enumerated four resolution sites. Two more surfaced mid-implementation when a parallel-suite test flaked and pointed at a stats query. A seventh surfaced only during browser verification: a builder query was filtering out any Y that already had an X, hiding rows from a picker the moment they joined any group — defeating the relaxation's value proposition on the first interaction. All three missed sites had the same shape: a query encoding the old uniqueness assumption via either a `left_outer_joins ... where id: nil` filter or a subquery routing through the old single-FK column. A pre-PR grep for either pattern would have caught all three.

**How to apply:** When the work is framed as "flip", "relax", "rescope", "drop the unique index on X", or "one → many": before saying "all sites covered," write down the literal code patterns the old invariant produced — a `where(child_table: { id: nil })` join, a `find_by(parent_col:)` lookup that lacks the new discriminator, a SQL subquery routing through the old single-FK column. Grep the codebase for each pattern. Compare the grep results against the issue's enumerated sites. The diff is what's missing. The cost of the grep is a few minutes; the cost of a post-verification miss is a round-trip and an extra commit, and it compounds across each miss in the same PR.

The sweep applies equally to files you've already touched in the PR. A small targeted edit (e.g., a couple of attribute adds to a simulation file) doesn't audit the rest of that file. In the same work, the simulation surfaced a *fourth* missed site — discovered only when looking for a way to seed test data — in a file I'd already edited. The file-level grep doesn't care whether you've already opened the file; it cares whether the pattern lives somewhere it shouldn't.
