#!/usr/bin/env bash
# Checks over local-allow.sh, which lists promotion candidates and prunes project settings.local.json:
#
#   ./scripts/test/run-local-allow.sh
#
# ADR 0008 puts it in Tier 2: human-run, but `prune --apply` rewrites gitignored files in other
# repos where only its own backup can restore them. The two failures that matter are a wrong
# removal — an entry pruned as "covered" that user settings do not cover, which comes back as a
# prompt nobody can explain — and a candidate list that misses or miscounts, which steers a
# promotion decision. The first version of the prune marked every MCP entry covered through a jq
# `index` slip; the MCP cases below are there for that.
#
# Every run points SEARCH_ROOT, USER_SETTINGS, BACKUP_DIR and HOME at a temp tree.
#
# No framework, no `set -e` (a failing case must report, not abort), non-zero exit at the end.

if ! command -v jq &>/dev/null; then
    echo "run-local-allow: jq is required by the subject." >&2
    exit 1
fi

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBJECT="$(cd "$TEST_DIR/.." && pwd)/local-allow.sh"

if [ ! -x "$SUBJECT" ]; then
    echo "run-local-allow: $SUBJECT is missing or not executable." >&2
    exit 1
fi

. "$(cd "$TEST_DIR/../.." && pwd)/test/_harness.sh"

WORK_DIR="$(mktemp -d)"
cleanup() { [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"; }
trap cleanup EXIT

ROOT="$WORK_DIR/dev"
FAKE_HOME="$WORK_DIR/home"
USER_FILE="$FAKE_HOME/.claude/settings.json"
BACKUPS="$FAKE_HOME/.claude/.local-allow-backups"

# fresh — empty search root, user settings with a known allow list.
fresh() {
    rm -rf "$ROOT" "$FAKE_HOME"
    mkdir -p "$ROOT" "$FAKE_HOME/.claude"
    jq -n '{permissions: {allow: ["Bash(gh:*)", "Bash(git grep:*)", "Bash(heroku help*)",
        "WebFetch(domain:*.github.io)", "Skill(*)", "WebSearch", "mcp__linear__get_issue"]}}' > "$USER_FILE"
}

# project <name> <entry>... — a project whose settings.local.json allows exactly those entries.
project() {
    local name=$1
    shift
    mkdir -p "$ROOT/$name/.claude"
    jq -n '{permissions: {allow: $ARGS.positional}}' --args "$@" > "$ROOT/$name/.claude/settings.local.json"
}

# run <args>... — run the subject against the fixtures. OUT is stdout, ERR stderr, STATUS the exit.
run() {
    OUT=$(SEARCH_ROOT="$ROOT" USER_SETTINGS="$USER_FILE" BACKUP_DIR="$BACKUPS" HOME="$FAKE_HOME" \
        "$SUBJECT" "$@" 2>"$WORK_DIR/err.txt")
    STATUS=$?
    ERR=$(cat "$WORK_DIR/err.txt")
}

# says <text> <label> / lacks <text> <label> — assert on stdout.
says() {
    case "$OUT" in
        *"$1"*) report true "$2" ;;
        *) report false "$2" "output did not contain '$1'" ;;
    esac
}
lacks() {
    case "$OUT" in
        *"$1"*) report false "$2" "output contained '$1'" ;;
        *) report true "$2" ;;
    esac
}

# allow_of <name> — the project's allow list, one entry per line.
allow_of() { jq -r '.permissions.allow[]' "$ROOT/$1/.claude/settings.local.json"; }

# --- Arguments ---------------------------------------------------------------------

fresh
run
expect_eq "$STATUS" 2 'no mode exits 2'
run --help
expect_eq "$STATUS" 0 '--help exits 0'
run candidates --apply
expect_eq "$STATUS" 2 '--apply with candidates exits 2'
run prune --sideways
expect_eq "$STATUS" 2 'an unknown argument exits 2'
MIN_PROJECTS=zero run candidates
expect_eq "$STATUS" 2 'a non-numeric MIN_PROJECTS exits 2'
rm "$USER_FILE"
run candidates
expect_eq "$STATUS" 2 'missing user settings exits 2'

# --- candidates ----------------------------------------------------------------------

fresh
project alpha "Bash(git *)" "Bash(heroku releases:*)" "Bash(only-here)"
project beta  "Bash(git *)" "Bash(heroku releases:*)"
run candidates
expect_eq "$STATUS" 0 'candidates exits 0'
says 'Bash(git *)' 'an uncovered entry in two projects is listed'
says 'alpha, beta' 'the listing names the projects it was found in'
lacks 'only-here' 'an entry in one project is not listed'
if grep -q '2  broad   Bash(git \*)' <<<"$OUT"; then
    report true 'a whole-command grant is labeled broad'
else
    report false 'a whole-command grant is labeled broad' "output: $OUT"
fi
if grep -q '2  narrow  Bash(heroku releases:\*)' <<<"$OUT"; then
    report true 'a subcommand grant is labeled narrow'
else
    report false 'a subcommand grant is labeled narrow' "output: $OUT"
fi

MIN_PROJECTS=1 run candidates
says 'only-here' 'MIN_PROJECTS=1 lists single-project entries'

fresh
project alpha "Bash(gh pr *)" "Bash(rtk proxy:*)"
project beta  "Bash(gh pr *)" "Bash(rtk proxy:*)"
run candidates
lacks 'gh pr' 'an entry user settings already cover is not a candidate'
says 'rtk proxy' 'an uncovered broad entry is a candidate'

fresh
project alpha "Bash(rtk smart *)"
project beta  "Bash(rtk smart *)"
run candidates
if grep -q '2  narrow  Bash(rtk smart \*)' <<<"$OUT"; then
    report true "an rtk subcommand with no command of its own name is labeled narrow"
else
    report false "an rtk subcommand with no command of its own name is labeled narrow" "output: $OUT"
fi

fresh
project alpha "Bash(bash .claude/scratch/probe.sh)" "Bash(done)"
project beta  "Bash(bash .claude/scratch/probe.sh)" "Bash(done)"
run candidates
says 'No candidates' 'one-offs and dead entries are never candidates'

# A backup folder holds settings.local.json copies; counting them would double every project.
fresh
project alpha "Bash(git *)"
mkdir -p "$ROOT/elsewhere/.local-allow-backups/old/alpha/.claude"
cp "$ROOT/alpha/.claude/settings.local.json" "$ROOT/elsewhere/.local-allow-backups/old/alpha/.claude/"
run candidates
says 'No candidates' 'a backup copy under a .local-allow-backups folder is not counted as a project'

fresh
project alpha "Bash(git *)"
project beta  "Bash(git *)"
mkdir -p "$ROOT/broken/.claude"
printf '{ not json' > "$ROOT/broken/.claude/settings.local.json"
run candidates
says 'Bash(git *)' 'a malformed file does not stop the others being read'
case "$ERR" in
    *"broken"*) report true 'the malformed file is named in a warning' ;;
    *) report false 'the malformed file is named in a warning' "stderr: $ERR" ;;
esac

# --- prune: what counts as covered ------------------------------------------------------

fresh
project alpha \
    "Bash(gh:*)" "Bash(gh pr *)" "Bash(git grep *)" "Bash(heroku help:*)" \
    "Bash(git grepper)" "Bash(heroku releases:*)" \
    "WebFetch(domain:ddnexus.github.io)" "WebFetch(domain:example.com)" \
    "Skill(adr)" "WebSearch" \
    "mcp__linear__get_issue" "mcp__linear__save_issue" "mcp__figma__get_metadata"
run prune
expect_eq "$STATUS" 0 'a prune dry run exits 0'
says "covered	Bash(gh:*)" 'an exact duplicate of a user entry is covered'
says "covered	Bash(gh pr *)" 'an entry extending a user prefix is covered'
says "covered	Bash(git grep *)" 'the " *" spelling of a user ":*" entry is covered'
says "covered	Bash(heroku help:*)" 'an entry extending a no-space user wildcard is covered'
lacks "Bash(git grepper)" 'a longer word sharing a prefix is not covered'
lacks "Bash(heroku releases" 'an unrelated entry is not covered'
says "covered	WebFetch(domain:ddnexus.github.io)" 'a subdomain of a user *.domain is covered'
lacks "example.com" 'an unrelated domain is not covered'
says "covered	Skill(adr)" 'any skill is covered by Skill(*)'
says "covered	WebSearch" 'WebSearch is covered when the user list has it'
says "covered	mcp__linear__get_issue" 'an MCP tool in the user list is covered'
lacks "mcp__linear__save_issue" 'an MCP tool missing from the user list is not covered'
lacks "mcp__figma__get_metadata" 'an MCP tool from another server is not covered'

before=$(cat "$ROOT/alpha/.claude/settings.local.json")
expect_eq "$(cat "$ROOT/alpha/.claude/settings.local.json")" "$before" 'a dry run changes nothing'
if [ -e "$BACKUPS" ]; then
    report false 'a dry run writes no backup' 'the backup folder exists'
else
    report true 'a dry run writes no backup'
fi

# --- prune: dead and one-off ------------------------------------------------------------

fresh
project alpha "Bash(git status:*)" "Bash(for f:*)" "Bash(done)" \
    "Bash(bash .claude/scratch/probe.sh)" "Bash(cat $FAKE_HOME/notes.txt)" \
    "Bash(git -C /some/repo log)" "Bash(cat /private/tmp/out.txt)" "Bash(rtk wc README.md)"
run prune
says "dead	Bash(git status:*)" 'git status, which rtk rewrites, is dead'
says "dead	Bash(for f:*)" 'a loop fragment is dead'
says "one-off	Bash(bash .claude/scratch/probe.sh)" 'a scratch script run is a one-off'
says "one-off	Bash(cat $FAKE_HOME/notes.txt)" 'an absolute home path is a one-off'
says "one-off	Bash(git -C /some/repo log)" 'a git -C command is a one-off'
says "one-off	Bash(cat /private/tmp/out.txt)" 'a temp path is a one-off'
lacks "rtk wc README.md" 'an ordinary relative command is kept'

# --- prune --apply ----------------------------------------------------------------------

fresh
project alpha "Bash(gh pr *)" "Bash(heroku releases:*)" "Bash(done)"
jq '. + {enabledPlugins: {"ruby-lsp@official": true}} | .permissions.deny = ["Bash(gh pr *)"]' \
    "$ROOT/alpha/.claude/settings.local.json" > "$WORK_DIR/tmp.json"
mv "$WORK_DIR/tmp.json" "$ROOT/alpha/.claude/settings.local.json"
original=$(cat "$ROOT/alpha/.claude/settings.local.json")
project beta "Bash(heroku releases:*)"
run prune --apply
expect_eq "$STATUS" 0 'prune --apply exits 0'
expect_eq "$(allow_of alpha)" 'Bash(heroku releases:*)' 'apply leaves only the entries that earn their place'
expect_eq "$(jq -r '.enabledPlugins["ruby-lsp@official"]' "$ROOT/alpha/.claude/settings.local.json")" true \
    'apply leaves other keys alone'
expect_eq "$(jq -r '.permissions.deny[0]' "$ROOT/alpha/.claude/settings.local.json")" 'Bash(gh pr *)' \
    'apply leaves the deny list alone'
backup=$(ls -d "$BACKUPS"/*/alpha/.claude/settings.local.json 2>/dev/null)
if [ -n "$backup" ] && [ "$(cat "$backup")" = "$original" ]; then
    report true 'apply backs the file up as it was before the change'
else
    report false 'apply backs the file up as it was before the change' "backup: ${backup:-<none>}"
fi
if ls -d "$BACKUPS"/*/beta 2>/dev/null | grep -q .; then
    report false 'a file with nothing to remove is not backed up' 'beta has a backup'
else
    report true 'a file with nothing to remove is not backed up'
fi
expect_eq "$(allow_of beta)" 'Bash(heroku releases:*)' 'a file with nothing to remove is left as it was'

run prune
says 'Would remove 0 entries' 'a second dry run after apply finds nothing'

summary || exit 1
