#!/usr/bin/env bash
# Checks over the PreToolUse Bash guards. Run it after touching one of them, and
# after bumping anything they parse:
#
#   ./hooks/test/run-checks.sh
#
# Every payload lives in this file rather than in a Bash command, because
# shell-machinery-guard.sh and reflexive-cd-guard.sh both match their own
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

smg() { check shell-machinery-guard.sh "$@"; }
smg_says() { says shell-machinery-guard.sh "$@"; }
rcd() { check_at reflexive-cd-guard.sh "$@"; }
rcd_says() { says reflexive-cd-guard.sh "$@"; }

echo "== shell-machinery-guard: blocks a definition (exit 2)"
smg "leading posix definition"        2 'for_each() { :; }; git status'
smg "definition after a semicolon"    2 'git status; noop() { :; }'
smg "definition after &&"             2 'rtk ls && helper() { :; }'
smg "keyword form, no parens"         2 'function greet { echo hi; }'
smg "keyword form, with parens"       2 'function greet() { echo hi; }'
smg "shadowing a builtin"             2 'cd() { return 1; }; grep -r foo .'
smg "spaces around the parens"        2 'tidy ()  { :; }; ls'
smg "unclosed brace"                  2 'noop() {'

echo
echo "== shell-machinery-guard: leaves ordinary commands alone (exit 0)"
smg "ordinary command"                0 'git status'
smg "reverting subshell"              0 '(cd /tmp && ls)'
smg "command substitution"            0 'echo "$(git rev-parse HEAD)"'
smg "mention without a brace"         0 "rtk grep 'parse_row()' ."
smg "mention in a commit message"     0 'git commit -m "document the foo() helper"'
smg "awk block, no parens"            0 "awk '{print \$1}' data.txt"
smg "find -exec braces"               0 'find . -name "*.sh" -exec ls {} \;'
smg "brace expansion"                 0 'mkdir -p src/{lib,test}'
smg "empty command"                   0 ''

echo
echo "== shell-machinery-guard: an opening quote is not a separator (exit 0)"
# The guard fires on the single character before the definition, and a quote is
# not in that set — so a definition sitting immediately after an *opening* quote
# passes. That tracks the permission gate this hook exists to keep quiet: bash
# does not parse these as definitions either, so none of them reports
# `function_definition` in the first place. Read it as a rule about the
# preceding character rather than as an exemption for quoted strings — the
# section below is the same quoting with a separator ahead of the definition,
# and it blocks.
smg "single-quoted definition"        0 "echo 'demo_fn() { :; }'"
smg "double-quoted definition"        0 'echo "demo_fn() { :; }"'
smg "definition inside bash -c"       0 "bash -c 'f() { :; }; f'"
smg "grep pattern with a brace"       0 "rtk grep 'parse_row() {' src/"

echo
echo "== shell-machinery-guard: documented over-blocks (exit 2)"
# The three shapes the hook's header enumerates as knowingly over-blocked: a
# separator ahead of a quoted definition, and a heredoc body line that begins
# one (a newline counts as whitespace). The gate would have stayed quiet for
# each, so these are false positives accepted deliberately rather than behaviour
# worth preserving — if the matching ever becomes quote-aware, all three flip to
# exit 0 and these expectations are what should change.
smg "separator inside bash -c"        2 "bash -c 'echo hi; f() { :; }; f'"
smg "separator inside a grep pattern" 2 "rtk grep 'x; parse_row() {' src/"
smg "heredoc body line"               2 'rtk read /dev/stdin <<EOF
helper() { :; }
EOF'

echo
echo "== shell-machinery-guard: motiveless assignments (exit 2)"
# The second shape the guard covers. A trailing separator is what makes it
# scaffolding rather than a prefix assignment, so every case here carries one.
smg "leading assignment, semicolon"   2 'for_check=""; rtk wc -l file'
smg "leading assignment, &&"          2 'REF=origin/main && rtk git show $REF'
smg "assignment after a command"      2 'rtk ls; TMP=/tmp; ls $TMP'
smg "assignment after a pipe"         2 'rtk ls | COUNT=1; echo done'
smg "unquoted value"                  2 'REF=origin/main; rtk git show HEAD'
smg "quoted value with a space"       2 'MSG="a b"; echo done'
smg "underscore-led name"             2 '_tmp=1; ls'

echo
echo "== shell-machinery-guard: a prefix assignment is legitimate (exit 0)"
# `FOO=bar cmd` scopes the variable to that one command and carries no
# separator. This is the boundary the whole assignment check rests on: the
# preceding set excludes bare whitespace precisely so these pass.
smg "prefix assignment"               0 'FOO=bar rtk ls'
smg "prefix assignment, two vars"     0 'FOO=bar BAZ=qux rtk ls'
# Regression: an earlier version required only that a separator appear SOMEWHERE
# after the value, which these satisfy with a pipe or an && that has nothing to
# do with the assignment. Caught by running the guard live, not by this suite.
smg "prefix assignment then a pipe"   0 'FOO=bar rtk ls dir/ | rtk head -3'
smg "prefix assignment then &&"       0 'FOO=bar rtk ls && rtk git status'
smg "prefix assignment, quoted value" 0 'FOO="a b" rtk ls | rtk wc -l'
smg "separator inside a quoted value" 0 'FOO="a; b" rtk ls'
smg "export then a separator"         0 'export FOO=bar; rtk ls'
smg "env prefix form"                 0 'env FOO=bar rtk ls'
smg "assignment with nothing after"   0 'FOO=bar'
smg "equals inside a query string"    0 'rtk curl "https://example.test/x?a=1&b=2"'
smg "equals after a semicolon in a URL" 0 'rtk ls; rtk curl "https://example.test/x?a=1"'
# Three parameters is where the URL case actually bit, and the two cases above
# are why it went unnoticed: with two parameters the second has no trailing `&`,
# so the value is never terminated by a separator. From three on, every interior
# parameter is `&name=value&` — an assignment reached from a separator and
# terminated by one. The `&` is a real separator to the matcher and the quotes
# are no escape, so this fired on any multi-parameter curl, wget or gh api call
# until the preceding separator was made to require a following space.
smg "three-parameter query string"    0 'rtk curl "https://example.test/x?a=1&b=2&c=3"'
smg "four-parameter query string"     0 'rtk proxy curl -s --max-time 5 "http://localhost:3000/search?val1=84&val2=60&val3=20&val4=48"'
smg "multi-parameter gh api path"     0 'rtk gh api "repos/o/r/issues?state=open&labels=bug&per_page=5"'
smg "query string then a real pipe"   0 'rtk curl "https://example.test/x?a=1&b=2&c=3" | rtk wc -l'
# Knowingly narrowed by that same change: scaffolding written with no space
# after its separator now passes. Every observed instance has spaced them, and
# buying this case back would cost every multi-parameter URL above.
smg "unspaced mid-command assignment" 0 'rtk ls;TMP=/tmp;ls $TMP'
smg "equals in a commit message"      0 'rtk git commit -m "document the a=b default"'
smg "long flag with a value"          0 'rtk grep --max-len=80 pattern .'
smg "assignment inside a quote"       0 "rtk grep 'x=1' src/"

echo
echo "== shell-machinery-guard: assignment over-blocks (exit 2)"
# The same quote-unaware trade-off the function form takes. Each of these would
# have been fine; the gate stays quiet for all three. If the matching ever
# becomes quote-aware these flip to exit 0 and these expectations are what
# should change.
smg "separator inside a grep pattern" 2 "rtk grep 'x; y=1;' src/"
smg "subshell assignment"             2 '(FOO=1; rtk ls)'

echo
echo "== shell-machinery-guard: the message points at what matched"
# The matcher scans the whole string, so a message asserting the command "opens
# with" an assignment sends the reader to the wrong end of a long command line.
# Quoting the matched fragment is the contract — exit 2 is 2 whether the
# explanation locates the match or invents a position for it.
smg_says "names the matched fragment"  'TMP=/tmp;' "$PROJ" 'rtk ls; TMP=/tmp; ls $TMP'
smg_says "no claim about opening"      'blocked at' "$PROJ" 'for_check=""; rtk wc -l file'

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
echo "== reflexive-cd-guard: a token after the target does not hide it (exit 2)"
# The target is cut at a command separator, which leaves anything between the path
# and that separator glued to it — a redirect above all, and `cd <dir> 2>/dev/null`
# is the shape the rule calls the loud hazard. A target carrying that text resolves
# to nothing, so the physical-path check finds no guarded root and the guard falls
# through to a pass. These are that gap: every one of them is a cd this guard
# already blocks without the trailing token.
rcd "subdir, redirect then semicolon" 2 "$PROJ" "cd $SUBDIR 2>/dev/null; ls"
rcd "subdir, redirect then nothing"   2 "$PROJ" "cd $SUBDIR 2>/dev/null"
rcd "project root, redirect"          2 "$PROJ" "cd $PROJ 2>/dev/null; ls"
rcd "subdir, stdout redirect"         2 "$PROJ" "cd $SUBDIR >/dev/null && ls"
rcd "quoted subdir"                   2 "$PROJ" "cd \"$SUBDIR\" && ls"
rcd "quoted subdir, redirect"         2 "$PROJ" "cd \"$SUBDIR\" 2>/dev/null; ls"

echo
echo "== reflexive-cd-guard: leaves legitimate movement alone (exit 0)"
rcd "outside the project, redirect"   0 "$PROJ" "cd $OUTSIDE 2>/dev/null; ls"
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
rcd "added dir, redirect then semicolon" 2 "$PROJ" "cd $ADDED 2>/dev/null; git status"
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
