#!/usr/bin/env bash
# Checks over notify-session-attention.sh, the Notification hook. Run it after touching that
# script:
#
#   ./hooks/test/run-notification.sh
#
# A second harness rather than cases inside run-checks.sh, which passes command strings to the
# PreToolUse guards. This hook reads a session JSON payload and writes two side effects, so nothing
# about that harness's shape fits.
#
# Both side effects are asserted. The log is read back from a scratch file, pointed there by
# CLAUDE_NOTIFY_LOG so a run never appends to the real one. The notification is captured by an
# `osascript` stub placed ahead of the real binary on PATH, which records its arguments instead of
# displaying anything — without it the delivery half is unobservable, since a notification appearing
# leaves no trace a script can read.
#
# What this cannot check: that macOS actually renders what osascript was asked to render, or the
# alert style it renders with. Those are System Settings' business and a human's eyes.
#
# Fixtures are derived or created here, never hardcoded to one machine: the hook comes from this
# file's location, and the log and stub live in temp directories removed by the run.
#
# No framework, no `set -e` (a failing case must report, not abort), non-zero exit at the end.

if ! command -v jq &>/dev/null; then
    echo "run-notification: jq is required. The hook passes through without it, so every" >&2
    echo "check would report a pass it never earned. Bailing instead." >&2
    exit 1
fi

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$(cd "$TEST_DIR/.." && pwd)/notify-session-attention.sh"

if [ ! -x "$HOOK" ]; then
    echo "run-notification: $HOOK is missing or not executable." >&2
    exit 1
fi

STUB_DIR="$(mktemp -d)"
WORK_DIR="$(mktemp -d)"
cleanup() {
    [ -n "$STUB_DIR" ] && rm -rf "$STUB_DIR"
    [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# Stands in for the real osascript. Records the whole argument vector so a check can assert on the
# title and body the hook asked for.
cat > "$STUB_DIR/osascript" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$OSASCRIPT_CALLS"
STUB
chmod +x "$STUB_DIR/osascript"

. "$(cd "$TEST_DIR/../.." && pwd)/test/_harness.sh"

# run <payload> — feeds the hook, leaving the log in $LOG, the osascript calls in $CALLS, and the
# hook's JSON output in $STDOUT. Capturing stdout also keeps a test run from ringing the real bell.
run() {
    LOG="$WORK_DIR/log.jsonl"
    CALLS="$WORK_DIR/calls.txt"
    STDOUT="$WORK_DIR/stdout.json"
    : > "$LOG"
    : > "$CALLS"
    : > "$STDOUT"
    printf '%s' "$1" \
        | PATH="$STUB_DIR:$PATH" OSASCRIPT_CALLS="$CALLS" CLAUDE_NOTIFY_LOG="$LOG" \
          CLAUDE_PERMISSION_CONTEXT_DIR="$CONTEXT_DIR" bash "$HOOK" \
        > "$STDOUT"
}

# The half notify-permission-context.sh writes. Pointed at the temp tree so a run never reads or
# deletes a real session's record — the hook consumes what it reads, so an unscoped run would
# destroy the context of whatever session is waiting on a prompt right now.
CONTEXT_DIR="$WORK_DIR/context"

# context <session> <age-in-seconds> <descriptor> — plant a record as if the other hook wrote it.
context() {
    mkdir -p "$CONTEXT_DIR"
    printf '%s %s\n' "$(( $(date -u +%s) - $2 ))" "$3" > "$CONTEXT_DIR/$1"
}

payload() {
    jq -n --arg type "$1" --arg cwd "$2" \
        '{session_id: "check", cwd: $cwd, hook_event_name: "Notification",
          message: "synthetic", notification_type: $type}'
}

notified() { [ -s "$CALLS" ]; }
logged_lines() { grep -c '' "$LOG"; }

# The hook writes nothing to stdout. It briefly emitted `terminalSequence` there to mark the
# terminal tab — a bell, then OSC 0, then OSC 2 — and none of the three moves Zed's tab label, so
# all of it came back out. This guards against it creeping back in: stdout is a hook's decision
# channel, and writing to it is never incidental.
printed() { [ -s "$STDOUT" ]; }

# A permission prompt notifies, labelled by the working directory's basename.
run "$(payload permission_prompt /Users/alice/dev/shipping-tracker)"
if notified && grep -q 'shipping-tracker' "$CALLS" && grep -q 'needs a response' "$CALLS"; then
    report true "permission_prompt notifies, titled by project"
else
    report false "permission_prompt notifies, titled by project" "captured: $(cat "$CALLS")"
fi
# The type covers AskUserQuestion and ExitPlanMode as well as a permission gate, and nothing in the
# payload separates them — so a label claiming permission is wrong for a share of the traffic. This
# asserts the absence because that is the whole defect: the old label read correctly on every
# payload a test could construct, since the payload is identical either way.
grep -qi 'permission' "$CALLS" \
    && report false "permission_prompt label does not claim permission" "captured: $(cat "$CALLS")" \
    || report true "permission_prompt label does not claim permission"
[ "$(logged_lines)" = 1 ] \
    && report true "permission_prompt is logged" \
    || report false "permission_prompt is logged" "expected 1 line, got $(logged_lines)"
printed \
    && report false "permission_prompt writes nothing to stdout" "stdout: $(cat "$STDOUT")" \
    || report true "permission_prompt writes nothing to stdout"

# Idle is the dominant type and says only that a session finished. Logged, never shown.
run "$(payload idle_prompt /Users/alice/dev/shipping-tracker)"
notified \
    && report false "idle_prompt is silent" "captured: $(cat "$CALLS")" \
    || report true "idle_prompt is silent"
[ "$(logged_lines)" = 1 ] \
    && report true "idle_prompt is still logged" \
    || report false "idle_prompt is still logged" "expected 1 line, got $(logged_lines)"
printed \
    && report false "idle_prompt writes nothing to stdout" "stdout: $(cat "$STDOUT")" \
    || report true "idle_prompt writes nothing to stdout"

# An unrecognised type is surfaced rather than dropped, and names itself so it is not mistaken for
# a permission prompt. The elicitation, agent and quota families have never fired here.
run "$(payload elicitation_url_dialog /Users/alice/dev/billing-api)"
if notified && grep -q 'billing-api' "$CALLS" && grep -q 'elicitation_url_dialog' "$CALLS"; then
    report true "unknown type notifies, naming the type"
else
    report false "unknown type notifies, naming the type" "captured: $(cat "$CALLS")"
fi
printed \
    && report false "unknown type writes nothing to stdout" "stdout: $(cat "$STDOUT")" \
    || report true "unknown type writes nothing to stdout"

# A payload that cannot be parsed is recorded as-is rather than discarded — there is nothing to
# route on, so it must not notify.
run 'this is not json'
grep -q '^UNPARSED ' "$LOG" \
    && report true "malformed input is logged as UNPARSED" \
    || report false "malformed input is logged as UNPARSED" "log holds: $(cat "$LOG")"
notified \
    && report false "malformed input does not notify" "captured: $(cat "$CALLS")" \
    || report true "malformed input does not notify"

# Empty stdin is not an event.
run ''
[ "$(logged_lines)" = 0 ] \
    && report true "empty input logs nothing" \
    || report false "empty input logs nothing" "log holds: $(cat "$LOG")"

# Without a cwd there is no label worth showing, so the event is recorded and nothing is displayed.
run "$(jq -n '{session_id: "check", hook_event_name: "Notification",
               notification_type: "permission_prompt"}')"
[ "$(logged_lines)" = 1 ] \
    && report true "payload without cwd is logged" \
    || report false "payload without cwd is logged" "expected 1 line, got $(logged_lines)"
notified \
    && report false "payload without cwd does not notify" "captured: $(cat "$CALLS")" \
    || report true "payload without cwd does not notify"

# --- Reading what the PermissionRequest half left ------------------------------

# The pair's whole point: a fresh record names the prompt instead of the generic label.
context check 2 "asks: Auth method"
run "$(payload permission_prompt /Users/alice/dev/shipping-tracker)"
grep -q 'asks: Auth method' "$CALLS" \
    && report true "a fresh record names the prompt" \
    || report false "a fresh record names the prompt" "captured: $(cat "$CALLS")"

# Consumed, not just read. Leaving it would let the next prompt in this session — the sandboxed
# network request that writes no record — inherit a descriptor belonging to something else.
[ -f "$CONTEXT_DIR/check" ] \
    && report false "the record is consumed" "still present" \
    || report true "the record is consumed"

# Older than the window: the notification fires about six seconds after the request, so a record
# this old belongs to a prompt that was answered before it could fire.
context check 600 "runs: bin/rails db:migrate"
run "$(payload permission_prompt /Users/alice/dev/shipping-tracker)"
grep -q 'needs a response' "$CALLS" \
    && report true "a stale record falls back to the generic label" \
    || report false "a stale record falls back to the generic label" "captured: $(cat "$CALLS")"
[ -f "$CONTEXT_DIR/check" ] \
    && report false "a stale record is cleared too" "still present" \
    || report true "a stale record is cleared too"

# A record whose first field is not an epoch is not one of ours, and must not be read as a
# descriptor with the age check silently passing on a comparison against nothing.
mkdir -p "$CONTEXT_DIR"
printf 'garbage runs: something\n' > "$CONTEXT_DIR/check"
run "$(payload permission_prompt /Users/alice/dev/shipping-tracker)"
grep -q 'needs a response' "$CALLS" \
    && report true "a record with no epoch falls back to the generic label" \
    || report false "a record with no epoch falls back to the generic label" "captured: $(cat "$CALLS")"

# No record at all is the sandboxed-network case, which PermissionRequest never sees.
rm -rf "$CONTEXT_DIR"
run "$(payload permission_prompt /Users/alice/dev/shipping-tracker)"
grep -q 'needs a response' "$CALLS" \
    && report true "no record falls back to the generic label" \
    || report false "no record falls back to the generic label" "captured: $(cat "$CALLS")"

# An idle_prompt stays silent whatever is sitting in the context directory, and leaves the record
# for the permission prompt it belongs to.
context check 2 "asks: Auth method"
run "$(payload idle_prompt /Users/alice/dev/shipping-tracker)"
notified \
    && report false "idle_prompt ignores a record" "captured: $(cat "$CALLS")" \
    || report true "idle_prompt ignores a record"
[ -f "$CONTEXT_DIR/check" ] \
    && report true "idle_prompt leaves the record alone" \
    || report false "idle_prompt leaves the record alone" "record was consumed"
rm -rf "$CONTEXT_DIR"

summary || exit 1
