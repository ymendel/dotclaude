#!/usr/bin/env bash
# Checks over notify-permission-context.sh, the PermissionRequest hook that records what a pending
# prompt is for. Run it after touching that script:
#
#   ./hooks/test/run-permission-request-context.sh
#
# A second suite on the PermissionRequest shape, beside run-permission-request.sh. ADR 0008's
# one-suite-per-shape line was written when no shape had two hooks; what the shape was standing in
# for is the helper set, and these two share none of it. That one answers with a decision object and
# is read from stdout; this one decides nothing and is read from a file it leaves behind.
#
# BOTH HALVES ARE ASSERTED, and the silent half is the one that matters: a PermissionRequest hook
# that emits anything Claude Code reads as a decision would start approving or denying prompts, and
# in a session that cannot prompt — a background subagent — a malformed answer denies the call
# outright. So every case checks stdout is empty, not only that the record is right.
#
# Fixtures are invented sessions and paths, never this machine's. The context directory is pointed
# at a temp tree by CLAUDE_PERMISSION_CONTEXT_DIR so a run never writes to the real one.
#
# No framework, no `set -e` (a failing case must report, not abort), non-zero exit at the end.

if ! command -v jq &>/dev/null; then
    echo "run-permission-request-context: jq is required. The hook abstains without it, so every" >&2
    echo "case would record a pass it never earned. Bailing instead." >&2
    exit 1
fi

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$(cd "$TEST_DIR/.." && pwd)/notify-permission-context.sh"

if [ ! -x "$HOOK" ]; then
    echo "run-permission-request-context: $HOOK is missing or not executable." >&2
    exit 1
fi

WORK_DIR="$(mktemp -d)"
cleanup() { [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"; }
trap cleanup EXIT

. "$(cd "$TEST_DIR/../.." && pwd)/test/_harness.sh"

CONTEXT_DIR="$WORK_DIR/context"

# run <payload> — feeds the hook, leaving its stdout in $STDOUT and its suggestions line in
# $SUGGESTIONS_LOG.
#
# BOTH env vars must be set on every invocation. CLAUDE_PERMISSION_SUGGESTIONS_LOG defaults to the
# real log in $HOME, so a run that forgot it would append this suite's invented fixtures to the file
# the MCP-title question is meant to be answered from — poisoning the data rather than losing it,
# which is the worse failure of the two.
run() {
    STDOUT="$WORK_DIR/stdout.txt"
    SUGGESTIONS_LOG="$WORK_DIR/suggestions.jsonl"
    rm -rf "$CONTEXT_DIR"
    : > "$STDOUT"
    : > "$SUGGESTIONS_LOG"
    printf '%s' "$1" \
        | CLAUDE_PERMISSION_CONTEXT_DIR="$CONTEXT_DIR" \
          CLAUDE_PERMISSION_SUGGESTIONS_LOG="$SUGGESTIONS_LOG" \
          bash "$HOOK" > "$STDOUT"
}

# payload <session> <tool> <tool_input-json>
payload() {
    jq -nc --arg session "$1" --arg tool "$2" --argjson input "$3" \
        '{hook_event_name: "PermissionRequest", session_id: $session,
          tool_name: $tool, tool_input: $input}'
}

# descriptor <session> — the record's text, with the epoch field dropped.
descriptor() {
    [ -f "$CONTEXT_DIR/$1" ] || { printf '<no record>'; return; }
    cut -d' ' -f2- < "$CONTEXT_DIR/$1"
}

silent() { [ ! -s "$STDOUT" ]; }

# records <label> <session> <tool> <input-json> <want> — one descriptor assertion plus the silence
# assertion that has to hold on every path.
records() {
    run "$(payload "$2" "$3" "$4")"
    expect_eq "$(descriptor "$2")" "$5" "$1"
    silent \
        && report true "$1 — writes nothing to stdout" \
        || report false "$1 — writes nothing to stdout" "stdout: $(cat "$STDOUT")"
}

# --- The descriptors -----------------------------------------------------------

records "AskUserQuestion names the first question's header" \
    s1 AskUserQuestion '{"questions":[{"header":"Auth method","question":"Which one?"}]}' \
    "asks: Auth method"

records "AskUserQuestion falls back to the question when the header is absent" \
    s2 AskUserQuestion '{"questions":[{"question":"Which database?"}]}' \
    "asks: Which database?"

records "Bash names the command" \
    s3 Bash '{"command":"bin/rails db:migrate"}' \
    "runs: bin/rails db:migrate"

records "Write names the last two path segments, not the whole path" \
    s4 Write '{"file_path":"/Users/alice/dev/shipping-tracker/config/routes.rb"}' \
    "writes: config/routes.rb"

records "Write without a path says so rather than recording an empty descriptor" \
    s25 Write '{}' \
    "writes a file"

# NotebookEdit carries notebook_path where Edit and Write carry file_path, so a hook reading only
# file_path records a pathless write without saying so.
records "NotebookEdit reads notebook_path" \
    s5 NotebookEdit '{"notebook_path":"/Users/alice/dev/analysis/orders.ipynb"}' \
    "writes: analysis/orders.ipynb"

records "ExitPlanMode is named without reading its input" \
    s6 ExitPlanMode '{}' \
    "wants to leave plan mode"

# Read names two segments where Write names one. A basename alone repeats across a repo's
# directories, and the parent is usually the word that tells two `index.ts` apart.
records "Read names the last two path segments" \
    s19 Read '{"file_path":"/Users/alice/dev/shipping-tracker/app/models/shipment.rb"}' \
    "reads: models/shipment.rb"

records "Read degrades to the basename when there is no parent segment" \
    s20 Read '{"file_path":"Gemfile"}' \
    "reads: Gemfile"

# A root-level path has a parent that is the empty string, which would render a leading slash.
records "Read at the filesystem root does not emit a leading slash" \
    s21 Read '{"file_path":"/Gemfile"}' \
    "reads: Gemfile"

records "Read without a path says so rather than recording an empty descriptor" \
    s22 Read '{}' \
    "reads a file"

# The scheme distinguishes no URL from another and costs eight of the eighty characters, which the
# cap takes off the path — the half that says what is being fetched.
records "WebFetch names the URL without its scheme" \
    s23 WebFetch '{"url":"https://example.com/docs/hooks","prompt":"what does it say?"}' \
    "fetches: example.com/docs/hooks"

records "WebSearch names the query" \
    s24 WebSearch '{"query":"claude code permission request hook"}' \
    "searches: claude code permission request hook"

# An unlisted tool still beats the generic label, so it falls through to its own name rather than
# being dropped. ListAgents carries no path, URL, or query, so it is a tool no future arm would have
# anything to name — which is what makes it a stable stand-in here.
records "an unlisted tool falls through to its own name" \
    s7 ListAgents '{}' \
    "ListAgents"

# MCP tools arrive as `mcp__<server>__<tool>`, which is readable but not written for a human. The
# docs gloss them the way this renders them: "Memory server's create entities tool".
records "an MCP tool is split into server and tool" \
    s12 mcp__honeycomb__get_dataset '{"environment_slug":"production"}' \
    "calls: honeycomb get dataset"

# The split is on the double underscore, because a plugin-sourced server carries single underscores
# inside its own segment — this name is the docs' own example. Splitting on `_` would hand the tool
# half `my-plugin_db__query`. The server's own underscores then become spaces like any other, so the
# name stops being liftable as an identifier; a notification body is not where that is done.
# `plugin_` itself comes off for the same reason `claude_ai_` does, being provenance rather than
# identity. What remains is `<plugin> <server>`, both kept here because they differ.
records "a plugin-sourced server is split at the double underscore, then spaced" \
    s13 mcp__plugin_my-plugin_db__query '{}' \
    "calls: my-plugin db query"

# A plugin serving a server of its own name doubles it. Collapsed, or every Figma call reads
# "figma figma get metadata".
records "a plugin serving its own name is not doubled" \
    s17 mcp__plugin_figma_figma__get_metadata '{}' \
    "calls: figma get metadata"

# Only an exact repeat collapses. A shared prefix is two different names and both stay, or the
# descriptor would start dropping words that carry meaning.
records "a server half that merely shares a prefix keeps both names" \
    s18 mcp__plugin_fig_figma__get_metadata '{}' \
    "calls: fig figma get metadata"

# Every claude.ai-hosted connector carries this prefix, so it distinguishes none of them.
records "a claude.ai connector loses its prefix" \
    s15 mcp__claude_ai_Figma__get_design_context '{}' \
    "calls: Figma get design context"

# The prefix comes off before the split, so a multi-word connector name is spaced like any other.
records "a multi-word connector name is spaced" \
    s16 mcp__claude_ai_Google_Calendar__list_events '{}' \
    "calls: Google Calendar list events"

# A name with no second `__` is not the documented shape; render what there is rather than
# splitting the server against itself.
records "an mcp name with no tool half does not double its server" \
    s14 mcp__honeycomb '{}' \
    "calls: honeycomb"

# --- Shape of the record -------------------------------------------------------

# A newline in the payload would make the reader, which reads one line, see a second record.
records "a newline in the command is cut at the first line" \
    s8 Bash '{"command":"first line\nsecond line"}' \
    "runs: first line"

run "$(payload s9 Bash "$(jq -nc --arg c "$(printf 'x%.0s' {1..300})" '{command:$c}')")"
[ "$(descriptor s9 | wc -c)" -le 81 ] \
    && report true "a long command is capped" \
    || report false "a long command is capped" "got $(descriptor s9 | wc -c) bytes"

run "$(payload s10 Bash '{"command":"rtk git status"}')"
[[ "$(head -c 20 "$CONTEXT_DIR/s10")" =~ ^[0-9]+\  ]] \
    && report true "the record opens with an epoch the reader can compare" \
    || report false "the record opens with an epoch the reader can compare" \
        "got: $(head -c 20 "$CONTEXT_DIR/s10")"

# --- Abstaining ----------------------------------------------------------------

# Each of these must leave no record AND no stdout. The second half is why they are worth having:
# an abstain that printed an empty decision object would be a decision.
abstains() {
    run "$2"
    [ -z "$(ls -A "$CONTEXT_DIR" 2>/dev/null)" ] \
        && report true "$1" \
        || report false "$1" "wrote: $(ls -A "$CONTEXT_DIR")"
    silent \
        && report true "$1 — writes nothing to stdout" \
        || report false "$1 — writes nothing to stdout" "stdout: $(cat "$STDOUT")"
}

abstains "a payload with no session_id records nothing" \
    "$(jq -nc '{hook_event_name:"PermissionRequest", tool_name:"Bash", tool_input:{command:"ls"}}')"

abstains "a payload with no tool_name records nothing" \
    "$(jq -nc '{hook_event_name:"PermissionRequest", session_id:"s11", tool_input:{}}')"

abstains "unparseable input records nothing" "not json at all"

abstains "empty input records nothing" ""

# The session id becomes a filename, so a traversal in it must not place the record elsewhere.
abstains "a session id containing a slash records nothing" \
    "$(payload "../escaped" Bash '{"command":"ls"}')"

# --- The suggestions log -------------------------------------------------------

# This log records what each prompt was for and what the dialog offered to save. It is separate
# from the descriptor record above: that one is per-session and consumed, this one is append-only
# and nothing deletes it.

run "$(jq -nc '{hook_event_name:"PermissionRequest", session_id:"s15", tool_name:"Bash",
                tool_input:{command:"ls"},
                permission_suggestions:[{type:"addRules", rules:[{toolName:"Bash"}]}]}')"
expect_eq "$(jq -c '.permission_suggestions' < "$SUGGESTIONS_LOG")" \
    '[{"type":"addRules","rules":[{"toolName":"Bash"}]}]' \
    "a request carrying suggestions logs them verbatim"

# Absence is logged as null rather than skipped. A missing line would leave a later reader unable to
# tell "that tool never prompted" from "it prompted and carried nothing", which is the distinction
# the log is for.
run "$(payload s16 Bash '{"command":"ls"}')"
expect_eq "$(jq -c '.permission_suggestions' < "$SUGGESTIONS_LOG")" "null" \
    "a request carrying no suggestions logs null, not nothing"

expect_eq "$(jq -r '.tool_name' < "$SUGGESTIONS_LOG")" "Bash" \
    "the logged line carries the tool name"

# One line per request, so the file stays readable with `jq -c` per line rather than as one document.
run "$(payload s17 Bash '{"command":"ls"}')"
expect_eq "$(wc -l < "$SUGGESTIONS_LOG" | tr -d ' ')" "1" \
    "one request writes exactly one line"

# The silence invariant has to survive the new write. An observer that started printing would begin
# deciding prompts, and in a session that cannot prompt a malformed answer denies the call.
silent \
    && report true "logging suggestions writes nothing to stdout" \
    || report false "logging suggestions writes nothing to stdout" "stdout: $(cat "$STDOUT")"

# An MCP payload is the case the log was added for, so assert it survives the round trip rather than
# trusting that it looks like the others.
run "$(jq -nc '{hook_event_name:"PermissionRequest", session_id:"s18",
                tool_name:"mcp__honeycomb__get_dataset", tool_input:{environment_slug:"production"},
                permission_suggestions:[{type:"addRules",
                                         rules:[{toolName:"mcp__honeycomb__get_dataset"}]}]}')"
expect_eq "$(jq -r '.tool_name' < "$SUGGESTIONS_LOG")" "mcp__honeycomb__get_dataset" \
    "an MCP request logs its full tool name"

# Which project prompted, and what for. The cwd names the project without a transcript lookup.
run "$(jq -nc '{hook_event_name:"PermissionRequest", session_id:"s19", cwd:"/work/shipping-tracker",
                tool_name:"Bash",
                tool_input:{command:"git merge-tree --write-tree main feature",
                            description:"Preview the merge"}}')"
expect_eq "$(jq -r '.cwd' < "$SUGGESTIONS_LOG")" "/work/shipping-tracker" \
    "the logged line carries the cwd"
expect_eq "$(jq -r '.command' < "$SUGGESTIONS_LOG")" "git merge-tree --write-tree main feature" \
    "a Bash request logs its command"
expect_eq "$(jq -r '.description' < "$SUGGESTIONS_LOG")" "Preview the merge" \
    "a Bash request logs its description"

# An inline script spans lines. Kept on one so the record stays one JSON line a reader can scan.
run "$(payload s20 Bash '{"command":"ruby -e \"\n  puts 1\n  puts 2\""}')"
expect_eq "$(jq -r '.command' < "$SUGGESTIONS_LOG")" 'ruby -e " ⏎   puts 1 ⏎   puts 2"' \
    "a multi-line command is logged on one line"

# Capped, because the transcript holds the full text and the log only has to identify it.
run "$(payload s21 Bash "$(jq -nc '{command: ("echo " + ("x" * 300))}')")"
expect_eq "$(jq -r '.command | length' < "$SUGGESTIONS_LOG")" "200" \
    "a long command is capped at 200 characters"
expect_eq "$(jq -r '.command | .[-1:]' < "$SUGGESTIONS_LOG")" "…" \
    "a capped command ends in an ellipsis"

run "$(payload s22 Edit '{"file_path":"/work/shipping-tracker/app.rb"}')"
expect_eq "$(jq -c '.command' < "$SUGGESTIONS_LOG")" "null" \
    "a non-Bash request logs a null command"

# Unparseable input must not append a line either — the log is fed from a jq filter over the payload,
# so a parse failure there would otherwise write a malformed record the reader cannot skip past.
run "not json at all"
expect_eq "$(wc -c < "$SUGGESTIONS_LOG" | tr -d ' ')" "0" \
    "unparseable input logs nothing"

summary
