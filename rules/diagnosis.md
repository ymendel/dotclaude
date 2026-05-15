# Diagnosis

## Diagnose before retrying

When a command fails **or gives unexpected output**, diagnose why before trying again. Retrying the same command (or minor variants) without understanding is a loop, not debugging. This applies equally to unexpected output — if a command succeeds but the output isn't what was expected, reason about why rather than issuing variations hoping for different results.

Specific case: `fatal: bad revision '<file>'` in git means git is interpreting a path as a tree-ish. Fix: use `--` to separate revisions from paths (`git diff HEAD -- <file>`).

Specific case: when RTK's diff output doesn't show a change that's known to exist, RTK filtered it (e.g., a single-line change inside a long string). Do not retry diff variants — switch to `git diff --cached` to check the index, or read the file directly. Retrying `git diff` with different flags will not produce different output through the same filter.

## Don't route around the user's configuration

Reaching for `/bin/ls`, `/usr/bin/grep`, or similar absolute paths to sidestep aliases or shell configuration is a smell. The user's shell setup is intentional; bypassing it produces output that doesn't reflect their environment, may evade allowlists (since the allowlist matches the literal command string), and signals that something else is off. If a command isn't behaving as expected, diagnose why — don't route around the user's configuration.

## Verify state at the layer that produces the behavior

When changing a configuration value, verify the layer that *produces* the runtime behavior reflects the change — not only the layer that *stores* it. Many systems keep the same state in two places: a durable backing store (a DB row, a config file) and a runtime cache, in-memory schedule, or pre-boot snapshot that mediates actual behavior. Updating the backing store is often necessary but not sufficient.

The failure mode: confirming the stored value "looks right" feels like verification but is a false-positive when the runtime layer hasn't re-read. The symptom shows up as "I changed X but nothing happened" — and re-changing X won't fix it. Check both the storage layer and the runtime side before concluding the change took effect or that the system is misbehaving.

Common cases where this trap shows up:

- Job schedulers with in-memory cron tables (Solid Queue dynamic recurring tasks, Sidekiq Cron, etc.) — the DB row updates without the running scheduler noticing.
- Caches (`Rails.cache`, Redis, fragment caches) — a record updates while a cached projection of it stays stale.
- ENV vars / platform config vars — most platforms apply changes on process or dyno restart, not immediately to running processes.
- Feature flag stores or configuration that snapshots at boot rather than re-reading at runtime.
