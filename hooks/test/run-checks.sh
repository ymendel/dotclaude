#!/usr/bin/env bash
# Checks over the PreToolUse Bash guards. Run it after touching one of them, and
# after bumping anything they parse:
#
#   ./hooks/test/run-checks.sh
#
# Every payload lives in this file rather than in a Bash command, because
# function-definition-guard.sh and reflexive-cd-guard.sh both match their own
# trigger text: assembling these cases inline would block the test run itself.
# That is also the escape both guards' messages recommend — put the script in a
# file and run the file.
#
# Fixtures are derived or created here, never hardcoded to one machine: the
# project root comes from this file's location, and the added-dir and
# stranded-cwd roots are temp directories made and removed by the run. One case
# is conditional on the ~/.claude symlink and reports SKIP without it.
#
# No framework, no `set -e` (a failing case must report, not abort), non-zero
# exit at the end.

if ! command -v jq &>/dev/null; then
    echo "run-checks: jq is required. Every guard passes through without it, so" >&2
    echo "each check would report a pass it never earned. Bailing instead." >&2
    exit 1
fi

GUARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJ="$(cd "$GUARD_DIR/.." && pwd)"
SUBDIR="$PROJ/skills"

# The guard reads CLAUDE_PROJECT_DIR to decide what the project root is.
export CLAUDE_PROJECT_DIR="$PROJ"

# An added working dir and a stranded cwd, both outside every guarded root.
ADDED="$(mktemp -d)"
OUTSIDE="$(mktemp -d)"
mkdir -p "$ADDED/nested"
cleanup() {
    [ -n "$ADDED" ] && rm -rf "$ADDED"
    [ -n "$OUTSIDE" ] && rm -rf "$OUTSIDE"
}
trap cleanup EXIT

# `~/.claude` is a symlink to this repo in the documented install, which is what
# makes the physical-path check testable — a path that reaches a guarded root by
# another name. Skip the case where that install is absent rather than fail it.
ALIAS_ROOT="$(cd "$HOME/.claude" 2>/dev/null && pwd -P)"
if [ "$ALIAS_ROOT" = "$(cd "$PROJ" && pwd -P)" ]; then
    HAVE_ALIAS=true
else
    HAVE_ALIAS=false
fi

pass=0
fail=0
skip=0

# check <guard-script> <label> <expected-exit> <command-string>
check() {
    local guard="$1" label="$2" want="$3" cmd="$4"
    local got
    printf '%s' "{\"tool_input\":{\"command\":$(printf '%s' "$cmd" | jq -Rs .)}}" \
        | "$GUARD_DIR/$guard" >/dev/null 2>&1
    got=$?
    if [ "$got" = "$want" ]; then
        printf 'PASS  %-46s exit=%s\n' "$label" "$got"
        pass=$((pass + 1))
    else
        printf 'FAIL  %-46s want=%s got=%s\n' "$label" "$want" "$got"
        fail=$((fail + 1))
    fi
}

# check_at <guard-script> <label> <expected-exit> <cwd> <command-string>
# Same as check, but carries the cwd the guard reads to tell a redundant cd from
# a recovery out of a drifted shell.
check_at() {
    local guard="$1" label="$2" want="$3" cwd="$4" cmd="$5"
    local got
    jq -n --arg c "$cmd" --arg w "$cwd" '{tool_input:{command:$c}, cwd:$w}' \
        | "$GUARD_DIR/$guard" >/dev/null 2>&1
    got=$?
    if [ "$got" = "$want" ]; then
        printf 'PASS  %-46s exit=%s\n' "$label" "$got"
        pass=$((pass + 1))
    else
        printf 'FAIL  %-46s want=%s got=%s\n' "$label" "$want" "$got"
        fail=$((fail + 1))
    fi
}

# says <guard-script> <label> <expected-stderr-substring> <cwd> <command-string>
# A guard's message is its contract: exit 2 is 2 whether the explanation is true
# or false, so a correct block with a wrong reason passes every exit-code case.
says() {
    local guard="$1" label="$2" want="$3" cwd="$4" cmd="$5"
    local out
    out=$(jq -n --arg c "$cmd" --arg w "$cwd" '{tool_input:{command:$c}, cwd:$w}' \
        | "$GUARD_DIR/$guard" 2>&1 >/dev/null)
    if [[ "$out" == *"$want"* ]]; then
        printf 'PASS  %-46s msg\n' "$label"
        pass=$((pass + 1))
    else
        printf 'FAIL  %-46s msg lacked %s\n' "$label" "$want"
        fail=$((fail + 1))
    fi
}

skipped() {
    printf 'SKIP  %-46s %s\n' "$1" "$2"
    skip=$((skip + 1))
}

fdg() { check function-definition-guard.sh "$@"; }
rcd() { check_at reflexive-cd-guard.sh "$@"; }
rcd_says() { says reflexive-cd-guard.sh "$@"; }

echo "== function-definition-guard: blocks a definition (exit 2)"
fdg "leading posix definition"        2 'for_each() { :; }; git status'
fdg "definition after a semicolon"    2 'git status; noop() { :; }'
fdg "definition after &&"             2 'rtk ls && helper() { :; }'
fdg "keyword form, no parens"         2 'function greet { echo hi; }'
fdg "keyword form, with parens"       2 'function greet() { echo hi; }'
fdg "shadowing a builtin"             2 'cd() { return 1; }; grep -r foo .'
fdg "spaces around the parens"        2 'tidy ()  { :; }; ls'
fdg "unclosed brace"                  2 'noop() {'

echo
echo "== function-definition-guard: leaves ordinary commands alone (exit 0)"
fdg "ordinary command"                0 'git status'
fdg "reverting subshell"              0 '(cd /tmp && ls)'
fdg "command substitution"            0 'echo "$(git rev-parse HEAD)"'
fdg "mention without a brace"         0 "rtk grep 'parse_row()' ."
fdg "mention in a commit message"     0 'git commit -m "document the foo() helper"'
fdg "awk block, no parens"            0 "awk '{print \$1}' data.txt"
fdg "find -exec braces"               0 'find . -name "*.sh" -exec ls {} \;'
fdg "brace expansion"                 0 'mkdir -p src/{lib,test}'
fdg "empty command"                   0 ''

echo
echo "== function-definition-guard: an opening quote is not a separator (exit 0)"
# The guard fires on the single character before the definition, and a quote is
# not in that set — so a definition sitting immediately after an *opening* quote
# passes. That tracks the permission gate this hook exists to keep quiet: bash
# does not parse these as definitions either, so none of them reports
# `function_definition` in the first place. Read it as a rule about the
# preceding character rather than as an exemption for quoted strings — the
# section below is the same quoting with a separator ahead of the definition,
# and it blocks.
fdg "single-quoted definition"        0 "echo 'demo_fn() { :; }'"
fdg "double-quoted definition"        0 'echo "demo_fn() { :; }"'
fdg "definition inside bash -c"       0 "bash -c 'f() { :; }; f'"
fdg "grep pattern with a brace"       0 "rtk grep 'parse_row() {' src/"

echo
echo "== function-definition-guard: documented over-blocks (exit 2)"
# The three shapes the hook's header enumerates as knowingly over-blocked: a
# separator ahead of a quoted definition, and a heredoc body line that begins
# one (a newline counts as whitespace). The gate would have stayed quiet for
# each, so these are false positives accepted deliberately rather than behaviour
# worth preserving — if the matching ever becomes quote-aware, all three flip to
# exit 0 and these expectations are what should change.
fdg "separator inside bash -c"        2 "bash -c 'echo hi; f() { :; }; f'"
fdg "separator inside a grep pattern" 2 "rtk grep 'x; parse_row() {' src/"
fdg "heredoc body line"               2 'rtk read /dev/stdin <<EOF
helper() { :; }
EOF'

echo
echo "== reflexive-cd-guard: redundant and misdirecting targets (exit 2)"
rcd "absolute subdir"                 2 "$PROJ" "cd $SUBDIR && ls"
rcd "relative subdir"                 2 "$PROJ" "cd skills && ls"
rcd "cd . at the root"                2 "$PROJ" "cd ."
rcd "cd to the project root"          2 "$PROJ" "cd $PROJ"
rcd "cd . while drifted in a subdir"  2 "$SUBDIR" "cd ."
rcd "literal project-root env var"    2 "$PROJ" 'cd $CLAUDE_PROJECT_DIR && ls'
rcd "git-root idiom, quoted"          2 "$PROJ" 'cd "$(git rev-parse --show-toplevel)"'
rcd "git-root idiom, quoted + chained" 2 "$PROJ" 'cd "$(git rev-parse --show-toplevel)" && rtk git status'
rcd "git-root idiom, unquoted"        2 "$PROJ" 'cd $(git rev-parse --show-toplevel)'
rcd "git-root idiom, backticks"       2 "$PROJ" 'cd `git rev-parse --show-toplevel`'
if [ "$HAVE_ALIAS" = true ]; then
    rcd "symlink-alias subdir"        2 "$PROJ" "cd $HOME/.claude/skills && rtk grep x ."
    rcd "symlink-alias project root"  2 "$PROJ" "cd ~/.claude && ls"
else
    skipped "symlink-alias subdir" "~/.claude does not resolve to this repo"
    skipped "symlink-alias project root" "~/.claude does not resolve to this repo"
fi

echo
echo "== reflexive-cd-guard: leaves legitimate movement alone (exit 0)"
rcd "reverting subshell"              0 "$PROJ" "(cd skills && ls)"
rcd "cd out of the project"           0 "$PROJ" "cd .. && ls"
rcd "cd outside the project"          0 "$PROJ" "cd $OUTSIDE && ls"
rcd "cd -"                            0 "$PROJ" "cd - && ls"
rcd "runtime expansion target"        0 "$PROJ" 'cd $FOO && ls'
rcd "nonexistent subdir"              0 "$PROJ" "cd no-such-subdir-xyz && ls"
rcd "non-cd command"                  0 "$PROJ" "ls -la"
rcd "legit substitution target"       0 "$PROJ" 'cd "$(mktemp -d)"'

echo
echo "== reflexive-cd-guard: additional working dirs (exit 2 unless noted)"
# Two sources feed the guard, and the PreToolUse payload carries neither:
# CLAUDE_ADDED_DIRS (colon-separated, exported by whatever launcher passes
# --add-dir) and settings.json's additionalDirectories.
export CLAUDE_ADDED_DIRS="$ADDED"
rcd "cd into an added dir"            2 "$PROJ" "cd $ADDED && git status"
rcd "cd into a subdir of an added dir" 2 "$PROJ" "cd $ADDED/nested && ls"
rcd "outside project and added dir"   0 "$PROJ" "cd $OUTSIDE && ls"
rcd "subshell revert into added dir"  0 "$PROJ" "(cd $ADDED && git status)"
unset CLAUDE_ADDED_DIRS
rcd "added dir, but the var is unset" 0 "$PROJ" "cd $ADDED && git status"

echo
echo "== reflexive-cd-guard: recovery from a drifted shell"
# A cd to the project root is a REFLEX only when the shell is already there.
# From a drifted cwd it is the way back, and blocking it would trap the drift
# the guard exists to warn about. Nothing else relaxes.
rcd "stranded in subdir: cd root"     0 "$SUBDIR" "cd $PROJ && ls"
rcd "stranded outside: cd root"       0 "$OUTSIDE" "cd $PROJ && ls"
rcd "stranded outside: cd env-var root" 0 "$OUTSIDE" 'cd $CLAUDE_PROJECT_DIR && ls'
rcd "stranded in subdir: git-root idiom" 0 "$SUBDIR" 'cd $(git rev-parse --show-toplevel)'
rcd "stranded outside: cd ."          2 "$OUTSIDE" "cd ."
rcd "stranded outside: cd its own cwd" 2 "$OUTSIDE" "cd $OUTSIDE && ls"
rcd "stranded in subdir: cd a sibling subdir" 2 "$SUBDIR" "cd $PROJ/docs && ls"
export CLAUDE_ADDED_DIRS="$ADDED"
rcd "stranded outside: cd added dir"  2 "$OUTSIDE" "cd $ADDED && ls"
unset CLAUDE_ADDED_DIRS

echo
echo "== reflexive-cd-guard: shadowing cd is not a cd (exit 2)"
rcd "function shadow"                 2 "$PROJ" 'cd() { return 1; }; grep -rn foo .'
rcd "alias shadow"                    2 "$PROJ" 'alias cd=true; ls'

echo
echo "== reflexive-cd-guard: the message has to match the situation"
rcd_says "at root: cd . says project root" "already the project root" "$PROJ" "cd ."
rcd_says "stranded: cd . says no-op"       "no-op"                    "$OUTSIDE" "cd ."
rcd_says "stranded: says cwd is not root"  "NOT the project root"     "$OUTSIDE" "cd ."
rcd_says "stranded: names the way back"    "$PROJ"                    "$OUTSIDE" "cd ."
rcd_says "at root: git-root message"       "git root"                 "$PROJ" 'cd $(git rev-parse --show-toplevel)'

echo
if [ "$skip" -gt 0 ]; then
    echo "$pass passed, $fail failed, $skip skipped"
else
    echo "$pass passed, $fail failed"
fi
[ "$fail" -eq 0 ]
