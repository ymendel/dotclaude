#!/usr/bin/env bash
# Checks over context-usage.sh, the on-demand context reading:
#
#   ./scripts/test/run-context-usage.sh
#
# ADR 0008 puts it in Tier 2 for "picking among per-session caches and reporting staleness — more
# branching than its 82 lines suggest". That is the whole risk: the script always prints a plausible
# sentence, so picking the wrong reading looks exactly like picking the right one. The figure it
# prints gets quoted, and `honesty.md` leans on this script as the way to re-query a number rather
# than restate a stale one — a reading silently taken from another project would defeat the rule it
# exists to serve.
#
# ISOLATION IS A TEMP HOME PLUS A CONTROLLED WORKING DIRECTORY. The subject reads
# $HOME/.claude/.context-usage and compares each reading's recorded CWD against $PWD, so both sides
# of that match have to be fixtures or the cases would depend on where the suite happens to run.
#
# ORDERING IS BY mtime, via `ls -t`, so the cases that turn on "most recent" set mtimes explicitly
# with `touch -t` rather than relying on creation order — writing two files in sequence can land
# them in the same second, which makes the ordering arbitrary and the case flaky.
#
# No framework, no `set -e` (a failing case must report, not abort), non-zero exit at the end.

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBJECT="$(cd "$TEST_DIR/.." && pwd)/context-usage.sh"

if [ ! -x "$SUBJECT" ]; then
    echo "run-context-usage: $SUBJECT is missing or not executable." >&2
    exit 1
fi

. "$(cd "$TEST_DIR/../.." && pwd)/test/_harness.sh"

WORK_DIR="$(mktemp -d)"
cleanup() { [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"; }
trap cleanup EXIT

# fresh — a temp HOME with an empty cache dir, and a working directory to run from.
fresh() {
    FAKE_HOME="$WORK_DIR/home"
    HERE="$WORK_DIR/project"
    rm -rf "$FAKE_HOME" "$HERE"
    mkdir -p "$FAKE_HOME/.claude/.context-usage" "$HERE"
}

# no_cache_dir — a HOME with no cache directory at all.
no_cache_dir() {
    FAKE_HOME="$WORK_DIR/home"
    HERE="$WORK_DIR/project"
    rm -rf "$FAKE_HOME" "$HERE"
    mkdir -p "$FAKE_HOME/.claude" "$HERE"
}

# reading <session> <cwd> <pct> <tokens> <size> <age-seconds> [mtime]
# Writes one statusline reading. The optional mtime is a `touch -t` stamp, used where the case turns
# on which reading is newest.
reading() {
    printf 'CWD=%s\nCONTEXT_PCT=%s\nCONTEXT_TOKENS=%s\nCONTEXT_SIZE=%s\nTIMESTAMP=%s\n' \
        "$2" "$3" "$4" "$5" "$(( $(date +%s) - $6 ))" \
        > "$FAKE_HOME/.claude/.context-usage/$1"
    [ -n "${7:-}" ] && touch -t "$7" "$FAKE_HOME/.claude/.context-usage/$1"
    return 0
}

# reading_raw <session> <contents> — a cache file written verbatim, for malformed shapes.
reading_raw() {
    printf '%s' "$2" > "$FAKE_HOME/.claude/.context-usage/$1"
}

# bands_file <session> — the hook's state file, which must never be read as a reading.
bands_file() {
    printf '70\n' > "$FAKE_HOME/.claude/.context-usage/$1.bands"
}

# run — invoke the subject from the fixture working directory.
run() {
    OUT=$(cd "$HERE" && HOME="$FAKE_HOME" "$SUBJECT" 2>&1)
    STATUS=$?
}

saw() {
    case "$OUT" in
        *"$1"*) report true "$2" ;;
        *) report false "$2" "output lacked '$1': $OUT" ;;
    esac
}

did_not_see() {
    case "$OUT" in
        *"$1"*) report false "$2" "output unexpectedly contained '$1'" ;;
        *) report true "$2" ;;
    esac
}

# --- Nothing to report ------------------------------------------------------

no_cache_dir
run
saw 'No reading available' 'a missing cache directory reports no reading'
expect_eq "$STATUS" 0 'a missing cache directory still exits 0'

fresh
run
saw 'No reading available' 'an empty cache directory reports no reading'

# The .bands files are the Stop hook's state, not readings. Treating one as a reading would produce
# a malformed-cache complaint about a file that is doing exactly what it should.
fresh
bands_file some-session
run
saw 'No reading available' 'a directory holding only band state reports no reading'
did_not_see 'malformed' 'band state is skipped rather than called malformed'

# --- A reading for this directory -------------------------------------------

fresh
reading sess-a "$HERE" 42 84000 200000 10
run
saw 'Context usage: 42%' 'the percentage is reported'
saw '84K of 200K tokens' 'token counts are reported in thousands'
# The age is computed at run time, so asserting an exact number races the clock — a second between
# writing the fixture and reading it turns 10 into 11. Assert the shape instead.
if printf '%s' "$OUT" | grep -qE 'recorded [0-9]+s ago'; then
    report true 'the age of the reading is reported'
else
    report false 'the age of the reading is reported' "output was: $OUT"
fi
expect_eq "$STATUS" 0 'a normal report exits 0'
did_not_see 'Note:' 'a single matching reading needs no note'
did_not_see 'treat it as a floor' 'a fresh reading carries no staleness warning'

# --- Picking among several --------------------------------------------------

# Two sessions in this directory is the case the header calls the soft spot: they cannot be told
# apart, so the script says so rather than choosing silently.
fresh
reading sess-a "$HERE" 30 60000 200000 10 202601010900
reading sess-b "$HERE" 70 140000 200000 10 202601011000
run
saw 'Context usage: 70%' 'the most recently written reading wins'
saw '2 sessions have run in this directory' 'the ambiguity is reported rather than hidden'

# Reversing the mtimes must reverse the answer. Without this, "newest wins" would pass on a script
# that simply took whichever file the directory listed first.
fresh
reading sess-a "$HERE" 30 60000 200000 10 202601011000
reading sess-b "$HERE" 70 140000 200000 10 202601010900
run
saw 'Context usage: 30%' 'the ordering follows mtime, not the filename'

# --- Falling back to another directory --------------------------------------

fresh
reading sess-elsewhere "$WORK_DIR/other-project" 55 110000 200000 10
run
saw 'Context usage: 55%' 'with no local reading, a reading from elsewhere is shown'
saw "Note: no reading for $HERE" 'the fallback says the reading is not for this directory'
saw "$WORK_DIR/other-project" 'the fallback names where the reading came from'

# A local reading must win over a newer foreign one — otherwise the note above would be the common
# case and the figure would routinely describe another project.
fresh
reading sess-local "$HERE" 33 66000 200000 10 202601010900
reading sess-foreign "$WORK_DIR/other-project" 88 176000 200000 10 202601011000
run
saw 'Context usage: 33%' 'a local reading is preferred over a newer foreign one'
did_not_see 'no reading for' 'a local match reports no fallback note'

# --- Malformed readings -----------------------------------------------------

fresh
reading_raw sess-a "CWD=$HERE
CONTEXT_PCT=abc
CONTEXT_TOKENS=84000
CONTEXT_SIZE=200000
TIMESTAMP=1"
run
saw 'malformed' 'a non-numeric percentage is reported as malformed'
saw 'sess-a' 'the malformed report names the file to delete'
expect_eq "$STATUS" 0 'a malformed reading still exits 0'

# A field that is ABSENT is not caught, unlike one that is present and non-numeric. The guard
# concatenates the four values and rejects only an empty or non-digit result, so an absent field
# contributes nothing and `42` + `` + `` + `<stamp>` stays all digits. The reading is then printed
# with zeroes. hooks/context-usage-notice.sh carries the identical guard and the identical gap.
#
# Asserted as current behaviour so closing it fails here loudly. The zeroes are the tell a reader
# would notice; the script does not flag it.
fresh
reading_raw sess-a "CWD=$HERE
CONTEXT_PCT=42
TIMESTAMP=$(date +%s)"
run
saw '0K of 0K tokens' 'KNOWN GAP: absent fields print as zero rather than being rejected'
did_not_see 'malformed' 'KNOWN GAP: absent fields are not reported as malformed'

# An empty cache file records no CWD, so it matches no directory and the fallback picks it up as the
# newest reading anywhere — at which point every field is empty, the concatenation is empty, and the
# guard does fire. So the empty file reports malformed rather than no-reading.
fresh
reading_raw sess-a ''
run
saw 'malformed' 'an empty cache file is reported as malformed by the fallback path'

# --- Staleness --------------------------------------------------------------
#
# The figure only grows within a session, so an old reading under-reports. The warning is what stops
# a stale number being quoted as current — the exact misuse honesty.md's attribution rule covers.

fresh
reading sess-a "$HERE" 42 84000 200000 301
run
saw 'treat it as a floor' 'a reading over five minutes old is flagged as a floor'

fresh
reading sess-a "$HERE" 42 84000 200000 299
run
did_not_see 'treat it as a floor' 'a reading just under five minutes old is not flagged'

summary || exit 1
