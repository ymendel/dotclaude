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
