# ADR 0004: Rule vs. Hook — Enforcement Split for Config Constraints

**Date:** 2026-05-27
**Status:** Proposed

## Context

This `dotclaude` repo is the author's Claude Code configuration. A large
share of it is *constraints on the model's behavior*: roughly a dozen rule
files plus `CLAUDE.md`, all loaded passively into context every session,
telling the model what to do and what never to do. The set grows over time —
each correction or lesson tends to add another rule or another bullet.

Passively-loaded prose has a known failure mode: it does not reliably fire
during fast-moving generation. The rule is in context, but at the moment of
producing output the model defaults to the unconstrained action and relies on
the user to catch the slip. These are *application* failures, not
*missing-rule* failures — the rule exists and still isn't applied. A concrete
instance prompted this ADR: the model wrote a fabricated person's name into an
`Author:` attribution field of a document, despite a standing rule in
`CLAUDE.md` forbidding guessing at names and proper nouns (and the spirit of
`honesty.md`, which forbids manufacturing confidence). Nothing was missing;
the rule simply didn't fire at the keystroke that mattered.

The config already enforces *some* constraints by a different mechanism that
doesn't depend on the model remembering anything. The `settings.json` deny
list blocks `git push`, `git reset --hard`, `git checkout .`, `gh pr merge`,
and similar high-stakes commands outright. PreToolUse hooks rewrite Bash
commands (RTK prefixing, Python invocation). A PostToolUse hook enforces the
trailing-newline rule on every write. These fire regardless of the model's
attention state — a deny entry blocks a matching command whether or not the
model "remembered" the rule behind it.

That difference forces a question every time a new constraint is added: does
it go in prose, or behind a gate? With no explicit policy, the path of least
resistance is always prose — adding a bullet to a rule file is one Edit, while
adding a gate means editing `settings.json` or writing a hook script. So
mechanically-enforceable constraints drift into prose by inertia, where they
are subject to the same application-failure as everything else, *and* they add
to the passive load that makes every other rule fire less reliably.

The realization behind this decision is that more prose cannot fix
prose-not-firing. A meta-rule that says "pay attention to your rules" fails in
exactly the moments the object-rules fail — it is the same kind of artifact,
read by the same attention, at the same time. The lever that actually changes
behavior is moving the constraint to a mechanism that doesn't run on the
model's attention at all.

### Options

**1. Split by checkability: gate the mechanical, keep prose for judgment
(chosen).** A constraint that a script can recognize without judgment is
enforced by a gate (deny entry or hook). A constraint that requires judgment a
script cannot perform stays in prose, backed by the author's review.

- *Pros:* Mechanical constraints become reliable — the gate fires when the
  model's attention doesn't. Each new constraint has a clear home, decided by
  one test rather than by which edit is easier. Shifting the enforcement
  burden of mechanical rules onto gates relieves the model of having to *act*
  on them mid-generation, which is expected to help the judgment-based rules
  that remain in prose (the benefit is unverified — see Consequences).
- *Cons:* The classification is not binary; some constraints sit between
  "clean deny glob" and "unenforceable" and need a parsing hook (see the
  `git add` example). Gates are less discoverable than a rule file. Coarse
  deny globs can false-positive, and a too-broad gate is worse than none.

**2. Keep everything in prose (the inertial default).** Every constraint is a
rule; enforcement is the model applying it.

- *Pros:* One uniform place to look. Adding a constraint is always one Edit.
  Every rule is discoverable by reading `rules/`.
- *Cons:* This is the status quo whose failure prompted the ADR. Mechanical
  constraints that *could* be enforced deterministically instead inherit the
  application-failure mode, and they swell the passive load that degrades
  firing across the board. Rejected because it leaves reliability on the table
  for the exact class of constraint where reliability is achievable for free.

**3. Try to gate everything, including judgment (a general verification
gate).** Add a broad checkpoint — e.g. a hook that intervenes before a
response completes, forcing the model to re-verify its claims first.

- *Pros:* Would, in principle, catch the fabrication class that prose misses.
- *Cons:* A gate cannot perform the judgment that the judgment-class requires
  — the check *is* the judgment that failed. A coarse "did you verify?"
  checkpoint fires on every write, including the large majority with no
  fabrication risk; it becomes noise, gets dismissed, and self-defeats. A
  narrow gate targeting one slot shape (e.g. a person-name token in an
  `Author:` field) is tractable, but building bespoke gate infrastructure for
  a single observed failure is premature. Rejected as the general policy;
  revisit a narrow gate only if a specific failure shape recurs.

## Decision

Classify each behavioral constraint by a single test — **could a script
recognize a violation without judgment?** — and place it accordingly:

- **Yes, by command string** → a `settings.json` deny entry. Example: the
  existing `Bash(*git push*)` deny.
- **Yes, but needs richer inspection of the command or its arguments/paths**
  → a PreToolUse hook that parses the invocation (per the parse-don't-regex
  rule), not a deny glob.
- **Yes, by the content written to a file** → a PostToolUse hook on
  `Write|Edit`. Example: the existing trailing-newline hook.
- **No — recognizing a violation requires judgment** (is this name real? was
  this number measured? is this refactor corrective? is this framing
  accurate?) → a prose rule, enforced by the author's review.

The gate is the enforcement mechanism; a prose rule, where kept alongside a
gate, is documentation of intent — the discoverable "why." The policy does not
mandate deleting prose when a gate is added. For high-stakes constraints,
keeping both is defense in depth (the deny list already pairs prose and gate
for `git push`). The attention benefit survives keeping the prose, because the
benefit is about removing the *enforcement* burden from the model's attention,
not about removing tokens from context.

**Before building a gate, confirm the constraint isn't already enforced.** A
mechanical classification means a gate *can* exist, not that one *should* be
built. If the platform or surrounding tooling already enforces the boundary, a
new gate duplicates it for zero added protection — the "worse than none" case
from the Consequences: it adds complexity, and where it diverges from the
existing enforcement it tends to do so by being wrong. Learned concretely: a
home-directory read-guard built for the parsing-hook branch turned out
redundant with Claude Code's own working-directory boundary, which already
prompts for out-of-project reads through `Read`/`Glob`/`Grep`; its only
divergence from the platform would have been to override an explicit
`--add-dir` grant — i.e. to second-guess access the user had just authorized.
The check is cheap and goes before the build, not after.

The judgment class is, by construction, not gated. This is a deliberate
non-solution, not a gap to be filled later: fabricated names, places, model
identifiers, file paths, and numbers presented as measurements are unbounded
in shape, and no deterministic check recognizes "this plausible-looking detail
has no source." That class falls to the author's review — which is consistent
with the ownership stance in `CLAUDE.md`: it is the author's name on the
output, so the author has to know and care. Recording this here means no
future reader goes looking for a gate on the fabrication class expecting one to
exist.

### Worked example: `git add`

The rule "never use `git add -A` or `git add .`"
(`rules/development-workflow.md`) shows that "mechanically checkable" is a
gradient, not a binary:

- **`git add -A` / `git add --all`** are clean deny globs. `Bash(*git add -A*)`
  and `Bash(*git add --all*)` match the literal substring, including the
  RTK-rewritten `rtk git add -A` form, exactly as the existing `*git push*`
  entry already does. No false positives in normal use — the substring can
  match the string inside a quoted argument (a commit message, an `echo`), but
  that is rare.
- **`git add .`** is deny-glob-clean for the common cases too. Permission
  rules treat `*` as a wildcard at any position, so an *end-anchored*
  `Bash(*git add .)` matches a (sub)command ending in `git add .`: the leading
  `*` absorbs the `rtk ` prefix the rewrite hook prepends, and ending at the
  dot excludes `git add .gitignore` and `git add .claude/...`, exactly as the
  existing `*git checkout .` / `*git restore .` denies work. Claude Code also
  splits compound commands on shell operators (e.g. `&&`, `||`, `;`, `|`,
  newlines) and matches each subcommand independently, so a deny on the
  `git add .` subcommand should fire even when chained
  (`git add . && git commit ...`) rather than the whole string slipping past.
  (The docs spell out per-subcommand matching for *allow* rules; the deny
  consequence follows from deny-first precedence but isn't separately exampled.)
  What a glob cannot do is what the permissions
  docs explicitly warn about: argument-constraining Bash patterns are fragile
  against extra spaces (`git add  .`), equivalent forms (`git add ./`), or the
  dot buried among other pathspecs (`git add src/ .`). Airtight enforcement of
  "never stage everything" needs a PreToolUse hook that parses the command and
  inspects the pathspec list — the docs' own recommended path for
  argument-level constraints.

So a single rule spans the gradient: the flag forms and the bare-dot form are
deny-glob-clean for the standalone case (and, per the splitting above, the
chained case), while *airtight* enforcement against argument-level evasions
needs a parsing hook — and the policy names that gradient rather than
pretending the line is clean. `git add .` also sits at the intersection with
[ADR 0003](0003-allowlist-gitignore.md): the allowlist `.gitignore` already
makes `git add .` partly self-defeating (it silently drops changes in
non-allowlisted paths), which is part of why the rule against it exists.

## Consequences

- **Positive:** Mechanical constraints behind a gate are enforced regardless
  of the model's attention state. A deny entry blocks a matching command
  whether or not the rule behind it "fired" — the failure mode that prompted
  this ADR is removed for the class of constraint that can be gated.

- **Positive:** Each new constraint has a clear home. The checkability test
  answers "rule or hook?" directly, so a new constraint no longer defaults to
  prose just because adding a bullet is the easier edit.

- **Neutral:** The classification is a gradient, not a binary. Some
  constraints (bare-dot `git add`) sit between deny-glob-clean and
  unenforceable and need a parsing hook. The policy names the gradient
  explicitly; applying it still requires a per-constraint judgment about which
  mechanism fits.

- **Neutral:** Whether to *also* keep a prose rule beside a gate is a
  per-constraint call, trading discoverability against passive load. The policy
  sets no blanket answer; high-stakes constraints lean toward keeping both.

- **Neutral:** Gates and prose have different portability. Per
  [ADR 0001](0001-skill-maintenance-via-parallel-repos.md), skills sync to the
  team repo, but `settings.json` deny entries and hook scripts do not travel
  with them. Moving a constraint from prose into a gate makes its enforcement
  personal-only — a teammate who pulls a synced skill gets the documented
  intent but not the gate behind it.

- **Negative:** Deny globs are coarse in two ways. First, the permissions docs
  warn that argument-constraining patterns are fragile: written too broadly
  they false-positive (a naive `*git add .*` also blocks `git add .gitignore`),
  written too narrowly they are evaded (extra spaces, equivalent forms), which
  is why argument-level constraints ultimately want a parsing hook. Second, a
  glob cannot encode a rule's *exceptions*, only its blanket form — the
  `git push` deny blocks unconditionally even though the prose rule grants a
  carve-out for CI/CD-only changes. A too-broad gate is worse than none: it
  blocks legitimate actions and trains the user to route around or disable it.
  Every new gate needs its precision checked, which is real work the prose path
  does not demand.

- **Negative:** Gates are less discoverable than prose. A rule in `rules/` is
  found by reading the directory; a deny entry buried in `settings.json` or a
  hook script is not surfaced the same way. A future reader — or a teammate
  syncing the config — can hit "why did that command get blocked?" with no
  obvious answer. Keeping the paired prose rule mitigates this but reintroduces
  the passive load the gate was meant to relieve.

- **Negative:** The judgment class remains unenforced by construction. The
  policy explicitly accepts that fabricated names, paths, and unmeasured
  numbers can only be caught by the author's review. This is the deliberate
  limit of the approach, recorded so it is not mistaken for an oversight.

## References

- [ADR 0003](0003-allowlist-gitignore.md) — Allowlist-Based `.gitignore`; the
  `git add .` worked example sits at the intersection with that decision
- `settings.json` — the deny list and the existing PreToolUse / PostToolUse
  hooks that already enforce mechanical constraints
- `rules/development-workflow.md` — "Never use `git add -A` or `git add .`",
  the rule the worked example draws from
- `rules/honesty.md` — applies in spirit to the fabricated-name failure that
  prompted this ADR (don't manufacture confidence)
- `CLAUDE.md` — the Gathering Information rule ("Do not guess at URLs, names,
  proper nouns") whose application-failure (a fabricated `Author:` name)
  prompted this ADR, and the ownership stance that the judgment class is the
  author's to check, not a gate's
