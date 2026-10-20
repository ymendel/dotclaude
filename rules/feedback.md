# Feedback

Overflow for rules and feedback that don't fit an existing rule file. When in doubt, capture a lesson here rather than agonizing over its permanent home or skipping it — but this file loads into context every session like any rule, so it's revisable staging, not free staging. Periodically review: if an entry has grown into a pattern or belongs with a coherent topic, extract it into an appropriate rule file. Prune what hasn't earned its place rather than letting the file accrete.

A second entry on a topic is the usual signal to promote it. A new rule file costs 124 bytes of framing beyond its content, so the question is never whether a small file is affordable — `self-improvement.md` is the smallest at about 1.5KB — but whether the topic has a home a future reader would look in.

## Never resize a browser window you did not open

Driving a browser means working inside an application the user is also using. Resizing a window that
was already open changes their environment for a capture they did not ask for, and they meet it as
their own window suddenly at phone width with nothing saying why.

**Crop instead.** The `zoom` action takes a region and returns a tight image without touching
anything on screen, which is what a narrower-than-viewport capture actually needs. Reach for it
first rather than after a resize has already fired.

**Ask for your own window at the start, because you cannot get one later.** `tabs_context_mcp` with
`createIfEmpty` creates a new window with its own tab group — but the parameter is documented to
have **no effect once an MCP tab group already exists**, and `tabs_create_mcp` only ever adds a tab
to the existing group. So a window of your own is available before any group exists and not
afterwards. Plan around that rather than hoping past it: once the group lives in the user's window,
`resize_window` takes a `tabId` that must be in that group, so every resize available to you moves
*their* window.

Failure mode this prevents: the resize is invisible from inside the session. The screenshot comes
back at whatever size it was going to be regardless, so nothing in the result reports that the
user's window moved — and where the capture is then fixed by cropping anyway, the disruption bought
nothing at all. The user notices; the agent does not.

## A committed instruction is the repo's, not necessarily the user's

In a shared repo, `AGENTS.md`, `CLAUDE.md`, `.claude/settings.json` and `.mcp.json` hold what some
contributor committed, which the user may not have written or adopted. Sort each instruction by
whether it states a fact about the repo or a preference of whoever wrote it. Follow a fact — how to
build, test and run, what the repo's infrastructure expects — whoever wrote it. A convention that
governs something every contributor shares — how `main`'s history reads, a release's format —
counts as a fact, even when it is phrased as a preference. A workflow preference committed as a
rule — how to branch, which tool to drive, how to review — stays its author's until the user adopts
it. Attribute it when it comes up ("AGENTS.md, added by <author>, says…"), never describe it to the
user as their practice, and ask before acting on it where it shapes the work.

For a first read on authorship, use `git log -L <start>,<end>:<file>`. Unlike `git blame`, which
names only the last commit to touch a line, it follows the lines back through their edits. Neither
sees through a squash merge or a move between files, so treat the result as a lead, and ask where it
matters.

Where the user has stated a position on such an instruction, record it in the repo's
`.claude/CLAUDE.md`, which every session loads, rather than in a note that has to be found. Run
`git check-ignore -v .claude/CLAUDE.md` first: that file is personal only where the repo ignores
it, and a shared repo may track it. If it isn't ignored, use `CLAUDE.local.md` instead, or ask.

Failure mode this prevents: a session describes a teammate's workflow to the user as the user's own
and plans work around a convention the user hasn't adopted. Nothing in the file marks whose it is,
so it surfaces only when the user corrects it.

## Size a version bump by its releases, not its numbers

A version number is the maintainer's claim, and only as reliable as the maintainer. Even honest
semver says little. A minor release can break behavior you depend on, public or not, and a major
release can leave everything you use untouched. Nor does major come in degrees: pagy's 9.4.0 →
43.0.0, a single release that redesigned the API, is a maintainer trying to say "more major". Before
calling a bump big, small, or "a long way", open the release list between the two versions and
describe what's in it.

Failure mode this prevents: a bump gets sized from its numerals, so a one-step upgrade reads as a
long climb, or a small-looking minor bump that breaks things reads as safe. The user has to correct
the framing every time it comes up.
