#!/usr/bin/env bash
# Checks over the PreToolUse Bash guards. Run it after touching one of them, and
# after bumping anything they parse:
#
#   ./hooks/test/run-checks.sh
#
# Every payload lives in this file rather than in a Bash command, because
# function-definition-guard.sh matches its own trigger text: assembling these
# cases inline would block the test run itself. That is also the escape the
# guard's own message recommends — put the script in a file and run the file.
#
# No framework, no `set -e` (a failing case must report, not abort), non-zero
# exit at the end.

if ! command -v jq &>/dev/null; then
    echo "run-checks: jq is required. Every guard passes through without it, so" >&2
    echo "each check would report a pass it never earned. Bailing instead." >&2
    exit 1
fi

GUARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pass=0
fail=0

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

fdg() { check function-definition-guard.sh "$@"; }

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
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
