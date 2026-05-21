# session-handoff TODO

Ideas worth picking back up on later.

## Surface more than the newest handoff at session start

**Current behavior:** The `SessionStart` hook surfaces the most recent handoff within the last 7 days (or `None`). Only one handoff is mentioned, regardless of how many others are recent.

**Risk:** With the `--branches-from` relationship in place, parallel threads can coexist. If thread A is declined and a `--branches-from` handoff for thread B is created, thread A's most recent handoff falls off the hook's radar as soon as B's is newer. A reader who only sees B at session start has no signal that A even existed.

**Possible shapes** (in order of friction):

1. **Count suffix.** Keep surfacing the newest, but append a count: "There's a recent handoff: `<slug>` (2 others in last 7 days). Resume?" — cheap, no extra UI, signals that richer history exists without forcing a list.
2. **Newest per thread.** Walk the chain links and surface the newest handoff *per distinct thread root*. Requires the hook (or a helper script) to parse `Continues from` / `Branches from` to identify threads.
3. **Full list-and-pick.** Surface all recent handoffs and let the user pick. Higher friction at session start; only worth it if multi-thread cases bite often.

**Trigger to revisit:** when an orphaned-thread case actually happens — a handoff was lost because it aged out of the 7-day window while attention was on another thread — and that loss mattered. That's the moment to know which shape would have helped.

**Not yet worth doing because:** no concrete case has bitten. Designing for hypothetical multi-thread scenarios risks shipping more machinery than the problem deserves.
