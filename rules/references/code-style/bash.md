# Bash on macOS — Which Bash Runs, and Probing for 3.2

> Not loaded in context by default. See `rules/code-style.md` for the directive.

macOS ships bash 3.2, which Apple no longer updates. A current bash comes only from installing one,
here through Homebrew, which puts it first on `PATH`. Read on 2026-08-15:

```
bash        → GNU bash, version 5.3.15(1)-release   (Homebrew, first on PATH)
/bin/bash   → GNU bash, version 3.2.57(1)-release   (Apple, frozen)
```

`#!/usr/bin/env bash` finds the 5.3, and `#!/bin/bash` finds the 3.2. That line is most of the
decision. Write the `env` form and every bash 4+ feature is available. 3.2 comes back only through
a hardcoded `#!/bin/bash`, an explicit `/bin/bash script`, or a machine without Homebrew.

## What 3.2 lacks

Tested under both on 2026-08-15. Each of these works in 5.3 and fails in 3.2:

- namerefs, `local -n` / `declare -n`
- associative arrays, `declare -A`
- `mapfile` / `readarray`
- `shopt -s globstar` (`**`)
- `wait -n`
- case conversion, `${v^^}` / `${v,,}`
- quoted expansion, `${v@Q}`

## Probe by output, never by exit status

3.2 reports a bad substitution on stderr and still exits 0. 5.3 exits 1 for the same class of
error. So the obvious feature detector, running a snippet and checking its status, reports success
on exactly the shell it was meant to catch:

```bash
/bin/bash -c 'set -e; v=abc; echo "${v^^}"' >/dev/null 2>&1; echo $?
# → 0, and "bad substitution" went to the discarded stderr
bash      -c 'set -e; v=abc; echo "${v@Z}"' >/dev/null 2>&1; echo $?
# → 1
```

Compare what the snippet printed instead. A probe can also hide its own failure:
`declare -A m; m[k]=v; echo "${m[k]}"` exits 0 under 3.2 because the trailing `echo` succeeds after
`declare -A` has failed. Put `set -e` first in any such snippet, and still check the output.

The status-based detector is how a verification table once came out claiming 3.2 supported
namerefs, associative arrays and `mapfile` — all three false.
