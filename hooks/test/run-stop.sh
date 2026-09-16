#!/usr/bin/env bash
# Checks over context-usage-notice.sh, the Stop hook that reports context fullness:
#
#   ./hooks/test/run-stop.sh
#
# ADR 0008 puts it in Tier 1 because it "fires automatically, reports nothing when it works". Most
# of its paths are deliberate silence — below a band, already fired, cache stale, cache malformed —
# and silence is also what a completely broken hook produces. So every quiet case here is paired
# with a case proving the same fixture speaks when it should, which is the only way a silent pass
# differs from a silent failure.
#
# ONE SUITE PER PAYLOAD SHAPE, per the ADR: this is Stop-shaped, carrying a `session_id` and no
# `tool_input`, so it cannot share hooks/test/run-checks.sh's command-string harness.
#
# Isolation is a temp HOME. The subject reads $HOME/.claude/.context-usage/<session_id> and writes
# the band state beside it, so pointing HOME at a fixture keeps the real cache untouched and makes
# every percentage known in advance rather than whatever this session happens to be at.
#
# Timestamps are computed per case rather than fixed, because the staleness check is relative to
# `date +%s` at run time. CACHE_MAX_AGE is 1800 in the subject; the cases use offsets either side.
#
# The subject's header carried a TODO saying the malformed-cache and stale-cache paths had never
# been exercised. They are exercised here.
#
# No framework, no `set -e` (a failing case must report, not abort), non-zero exit at the end.

if ! command -v jq &>/dev/null; then
    echo "run-stop: jq is required — the subject exits 0 without it, so every case would" >&2
    echo "report a pass it never earned." >&2
    exit 1
fi

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBJECT="$(cd "$TEST_DIR/.." && pwd)/context-usage-notice.sh"

if [ ! -x "$SUBJECT" ]; then
    echo "run-stop: $SUBJECT is missing or not executable." >&2
    exit 1
fi

. "$(cd "$TEST_DIR/../.." && pwd)/test/_harness.sh"

WORK_DIR="$(mktemp -d)"
cleanup() { [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"; }
trap cleanup EXIT

SESSION="fixture-session"

# fresh — an empty cache directory under a temp HOME.
fresh() {
    FAKE_HOME="$WORK_DIR/home"
    rm -rf "$FAKE_HOME"
    mkdir -p "$FAKE_HOME/.claude/.context-usage"
}

# cache <pct> <tokens> <size> <age-seconds> — write a well-formed cache aged as told.
cache() {
    printf 'CONTEXT_PCT=%s\nCONTEXT_TOKENS=%s\nCONTEXT_SIZE=%s\nTIMESTAMP=%s\n' \
        "$1" "$2" "$3" "$(( $(date +%s) - $4 ))" \
        > "$FAKE_HOME/.claude/.context-usage/$SESSION"
}

# cache_raw <contents> — write the cache file verbatim, for malformed and partial shapes.
cache_raw() {
    printf '%s' "$1" > "$FAKE_HOME/.claude/.context-usage/$SESSION"
}

# bands <contents> — seed the already-fired band state.
bands() {
    printf '%s' "$1" > "$FAKE_HOME/.claude/.context-usage/$SESSION.bands"
}

# run [session-id] — feed a Stop payload. Output in $OUT, status in $STATUS.
run() {
    OUT=$(jq -n --arg s "${1-$SESSION}" '{session_id: $s}' | HOME="$FAKE_HOME" "$SUBJECT" 2>&1)
    STATUS=$?
}

# run_payload <jq-program> — an arbitrary payload, for the shapes with no usable session_id.
run_payload() {
    OUT=$(jq -n "$1" | HOME="$FAKE_HOME" "$SUBJECT" 2>&1)
    STATUS=$?
}

# spoke <label> — the hook emitted something.
spoke() {
    if [ -n "$OUT" ]; then
        report true "$1"
    else
        report false "$1" 'expected a notice, got no output'
    fi
}

# silent <label> — the hook emitted nothing.
silent() {
    if [ -z "$OUT" ]; then
        report true "$1"
    else
        report false "$1" "expected silence, got: $OUT"
    fi
}

# band_state — the recorded highest-fired band, or <none>.
band_state() {
    if [ -f "$FAKE_HOME/.claude/.context-usage/$SESSION.bands" ]; then
        cat "$FAKE_HOME/.claude/.context-usage/$SESSION.bands"
    else
        printf '<none>'
    fi
}

# --- Band crossing, and the silence either side of it -----------------------

fresh
cache 59 118000 200000 10
run
silent 'below the lowest band, nothing is reported'
expect_eq "$(band_state)" '<none>' 'no band state is written when nothing fires'

fresh
cache 60 120000 200000 10
run
spoke 'at exactly the lowest band, a notice is emitted'
expect_eq "$(band_state)" 60 'the fired band is recorded'

# The pairing that makes the silence above meaningful: same fixture shape, one percentage apart.
fresh
cache 61 122000 200000 10
run
spoke 'above a band, a notice is emitted'

# --- Repeat suppression -----------------------------------------------------

fresh
cache 65 130000 200000 10
run
spoke 'the first crossing of a band speaks'
run
silent 'the same band does not fire twice'

fresh
cache 75 150000 200000 10
bands 70
run
silent 'a band at or below the recorded one stays quiet'

fresh
cache 75 150000 200000 10
bands 60
run
spoke 'a higher band still fires after a lower one was recorded'
expect_eq "$(band_state)" 70 'the newly crossed band replaces the recorded one'

# A drop in percentage after a high band fired must not re-open the lower bands.
fresh
cache 65 130000 200000 10
bands 80
run
silent 'a drop below the recorded band does not re-fire'
expect_eq "$(band_state)" 80 'a quiet run leaves the recorded band alone'

# --- The jump case, which is why only the highest band fires ----------------

fresh
cache 85 170000 200000 10
run
spoke 'a jump past several bands emits'
expect_eq "$(band_state)" 80 'a jump records only the highest crossed band, not the first'
case "$OUT" in
    *85*) report true 'the notice reports the actual percentage, not the band' ;;
    *) report false 'the notice reports the actual percentage, not the band' "output was: $OUT" ;;
esac

fresh
cache 95 190000 200000 10
run
expect_eq "$(band_state)" 90 'a jump to the top records the highest band of all'

# --- What the notice says ---------------------------------------------------

fresh
cache 60 120000 200000 10
run
event=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.hookEventName // empty' 2>/dev/null)
expect_eq "$event" 'Stop' 'the output is JSON naming the Stop event'
text=$(printf '%s' "$OUT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
expect_eq "$text" 'Context usage: 60% (120K of 200K tokens).' 'the notice states percentage and token counts'

# --- Cache shapes that must produce silence rather than a malformed notice --
#
# The subject's header named these as never exercised. Each one is a way to end up printing a
# notice built from an empty string, which would read as a real reading of zero.

fresh
run
silent 'no cache file at all is silent'

fresh
cache_raw 'CONTEXT_PCT=abc
CONTEXT_TOKENS=120000
CONTEXT_SIZE=200000
TIMESTAMP=1'
run
silent 'a non-numeric percentage is silent'

# A field that is absent rather than malformed is NOT caught. The guard concatenates the four values
# and rejects the result if it is empty or holds a non-digit — but an absent field contributes an
# empty string, so `60` + `120000` + `` + `<stamp>` is still all digits and passes. The notice is
# then built with an empty size and prints "of 0K tokens".
#
# Asserted as current behaviour, with a fresh timestamp so the staleness check cannot mask it. An
# earlier version of this case used TIMESTAMP=1 and passed for that reason instead, which is exactly
# the false green this suite exists to avoid.
fresh
cache_raw "CONTEXT_PCT=60
CONTEXT_TOKENS=120000
TIMESTAMP=$(date +%s)"
run
spoke 'KNOWN GAP: a cache with an absent field is reported rather than rejected'
case "$OUT" in
    *'of 0K tokens'*) report true 'KNOWN GAP: the absent field prints as zero' ;;
    *) report false 'KNOWN GAP: the absent field prints as zero' "output was: $OUT" ;;
esac

# A field present but non-numeric IS caught, which is the half the guard does cover.
fresh
cache_raw "CONTEXT_PCT=60
CONTEXT_TOKENS=120000
CONTEXT_SIZE=not-a-number
TIMESTAMP=$(date +%s)"
run
silent 'a cache with a non-numeric field is silent'

fresh
cache_raw ''
run
silent 'an empty cache file is silent'

fresh
cache_raw 'nothing resembling the expected format'
run
silent 'a cache in the wrong format entirely is silent'

# Proving the four silences above are the guard and not a broken fixture path: the same directory,
# one well-formed cache, speaks.
fresh
cache 60 120000 200000 10
run
spoke 'a well-formed cache in the same fixture speaks'

# --- Staleness --------------------------------------------------------------

fresh
cache 90 180000 200000 1801
run
silent 'a cache older than the max age is silent even well above a band'

fresh
cache 90 180000 200000 1799
run
spoke 'a cache just inside the max age still reports'

# --- Payload shapes ---------------------------------------------------------

fresh
cache 60 120000 200000 10
run_payload '{}'
silent 'a payload with no session_id is silent'

fresh
cache 60 120000 200000 10
run ''
silent 'an empty session_id is silent'

fresh
cache 60 120000 200000 10
run 'some-other-session'
silent 'a session_id with no cache of its own is silent'

# --- A malformed band file must not suppress a real notice ------------------
#
# The recovery path reads a corrupt band file as 0 rather than bailing. Getting this wrong is the
# worst failure available to the hook: it would go permanently silent for that session, and silence
# is its normal state, so nothing would ever surface it.

fresh
cache 75 150000 200000 10
bands 'not a number'
run
spoke 'a corrupt band file does not silence the hook'
expect_eq "$(band_state)" 70 'a corrupt band file is replaced with a real band'

fresh
cache 75 150000 200000 10
bands ''
run
spoke 'an empty band file does not silence the hook'

summary || exit 1
