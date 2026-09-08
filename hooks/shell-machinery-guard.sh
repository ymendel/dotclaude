#!/usr/bin/env bash
# shell-machinery-guard.sh — PreToolUse (Bash) guard.
#
# Named for the rule it enforces: tool-and-shell-safety.md's "Don't add shell
# machinery the task didn't ask for". It blocks two of the shapes that section
# enumerates — a function definition, and a motiveless assignment before a
# separator — and the two have different justifications, set out in their own
# blocks below. Read them separately; the second does not inherit the first's.
#
# FIRST SHAPE: a shell function definition. Not because defining a function is
# wrong in general, but because every observed instance has been scaffolding
# the task did not ask for, and the scaffolding is what stops the run:
#   - A guard defining `cd() { return 1; }` to enforce the no-reflexive-cd rule
#     on itself. Handled with a better message by reflexive-cd-guard.sh, which
#     runs first; this hook catches it only if that one is removed.
#   - A stray `for_each() { :; };` or `noop() { :; };` in front of an ordinary
#     read-only command, defining something nothing calls and enforcing nothing.
#
# Either way the permission gate reports `function_definition` — a parser node
# no allow rule can grant — so a read-only `grep` or `git config` stops for
# approval, and the prompt reads as a gap in the allow list rather than as a
# self-inflicted one. See tool-and-shell-safety.md, "Don't add shell machinery
# the task didn't ask for".
#
# The rule naming this failure is complete and was bypassed four times across
# two sessions, so this is the next rung per ADR 0004's rule-vs-hook split.
#
# What it matches is decided by the single character before the definition, and
# nothing else: it fires at the start of the command or after a separator —
# whitespace, `;`, `&`, `|`, `(`. A quote is not in that set, so a definition
# sitting immediately after an opening quote passes: `rtk grep 'parse_row() {'`,
# `bash -c 'f() { :; }; f'`. Those are the right answer rather than a gap,
# because they track the gate this hook exists to keep quiet — bash does not
# parse quoted text as a function definition either, so neither command reports
# `function_definition` in the first place.
#
# Read that as a rule about the preceding character, not as an exemption for
# quoted strings. It is only the *opening* quote that saves those two. Put any
# separator ahead of the definition inside the same string and this fires:
#
#   bash -c 'echo hi; f() { :; }; f'      → blocked
#   rtk grep 'x; parse_row() {' src/      → blocked
#
# Both are over-blocks by this hook's own standard, since the gate would have
# stayed quiet for each. So it over-blocks two shapes, not one — those, and a
# heredoc body whose line begins a definition, since a newline counts as
# whitespace.
#
# All three are settings.md's deny-substring trade-off taken knowingly. Closing
# them means tracking shell quoting in a bash regex, which is code-style's
# parse-with-a-parser rule inverted, and buys little against how rarely a
# grep pattern or a `bash -c` one-liner carries a separator before a brace. The
# escape is the one the file rules already require — write the script with the
# Write tool and run the file, which keeps the definition out of the command
# string. This hook's own tests run that way.
#
# Block mechanism is exit code 2 — the only hook signal that beats a matching
# allow rule.
#
# ---------------------------------------------------------------------------
# SECOND SHAPE: a motiveless variable assignment before a separator.
# `for_check=""; rtk tail -c 1 file | rtk wc -l` — assigned once, referenced by
# nothing, enforcing nothing.
#
# Read the two shapes as one family: the slots bash permits at the start of a
# statement while staying inert. A function definition, an assignment followed
# by a separator, and a command that does nothing are three of them, and all
# three were observed in a single day. That the family is bounded rather than
# open-ended is what makes gating worth doing instead of a treadmill — but the
# third slot cannot be gated, for the reason the rule gives.
#
# ITS JUSTIFICATION IS NOT THE FUNCTION FORM'S, AND IS WEAKER. Everything
# above turns on the permission gate reporting `function_definition`, so a
# read-only command stops for approval. That does not transfer. A plain
# assignment is not among the parser nodes the gate refuses (see settings.md),
# and the changelog records assignments as auto-approved except for one
# arithmetic-to-integer-variable case fixed in 2.1.252 — ahead of the version
# installed here. So this shape costs no prompt at all. What it costs is what
# the rule says: the reflex recurs within a session, and because it has no
# motive there is nothing to notice yourself talking into. That is a real cost
# and a thinner case than the function form's, on one observation rather than
# four. Deliberate, not an oversight.
#
# What it matches, and why the preceding set is narrower than above:
# start-of-string or one of `;&|(`, optionally followed by whitespace — NOT
# bare whitespace, which the function form does accept. Whitespace would block
# `export FOO=bar; cmd` and `env FOO=bar cmd`, both legitimate.
#
# A separator terminating the value is required, and it is the whole safety
# margin. `FOO=bar cmd` is a *prefix* assignment, which scopes the variable to
# that one command and is ordinary shell. `FOO=bar; cmd` is the scaffolding.
#
# Passing the prefix form is not an endorsement of it. Observed live: a
# `FOO=bar rtk ls dir/ | rtk head -3` clears this guard and then trips a
# permission prompt anyway, because an allow rule is anchored on the command
# name and the assignment makes the string stop starting with `rtk` (see
# settings.md on Bash pattern matching). So the form is legitimate syntax with
# a real cost here, and blocking it would still be wrong — that is the
# allowlist's business, not this guard's.
#
# The separator has to end the value rather than merely appear later in the
# command. An unanchored version of this check blocked
# `FOO=bar rtk ls dir/ | rtk head -3` — a prefix assignment whose pipe has
# nothing to do with it — and the case was caught by running the guard live
# rather than by the suite, whose prefix-assignment cases all happened to lack
# a downstream separator. The regression is covered now.
#
# Knowingly over-blocked, on the same quote-unaware trade-off as above: an
# assignment reached after a separator *inside* a quoted argument
# (`rtk grep 'x; y=1;' src/`), and a subshell assignment (`(FOO=1; cmd)`) —
# which trips the gate's `subshell` node regardless. The escape is the one the
# file rules already require: write the script to a file and run the file.

if ! command -v jq &>/dev/null; then
  # Consistent with the other Bash hooks: without jq we cannot parse the input,
  # so pass through.
  exit 0
fi

INPUT=$(cat)
CMD=$(jq -r '.tool_input.command // empty' <<<"$INPUT")
[ -z "$CMD" ] && exit 0

# A function name as bash will realistically see one. Bash permits far more, but
# every observed slip has been identifier-shaped, and widening the class buys
# false positives rather than coverage.
name='[a-zA-Z_][a-zA-Z0-9_-]*'

# Two syntaxes, both requiring the opening brace so a bare mention of `foo()`
# does not trip. Matched after a start-of-string or a separator, so a definition
# following `;` or `&&` is caught as readily as a leading one.
posix_form="(^|[[:space:]\;\&\|\(])${name}[[:space:]]*\(\)[[:space:]]*\{"
keyword_form="(^|[[:space:]\;\&\|\(])function[[:space:]]+${name}([[:space:]]*\(\))?[[:space:]]*\{"

# A motiveless assignment: `name=value` reached from the start of the command or
# from a separator, and followed by one. The preceding set deliberately excludes
# bare whitespace so `export FOO=bar; cmd` and `env FOO=bar cmd` pass, and the
# trailing separator is what distinguishes scaffolding from a prefix assignment.
# The value has to be terminated BY the separator, not merely followed by one
# somewhere downstream: `FOO=bar cmd | x` is a prefix assignment whose pipe is
# nothing to do with the assignment, and an unanchored trailing separator
# matches it. Hence the value alternatives — a double-quoted string, a
# single-quoted string, or a run of characters that are neither whitespace nor a
# separator — then optional whitespace, then the separator.
# The bare alternative must exclude quote characters, or the regex backtracks
# into a quoted value — matching `"a` in `FOO="a; b" cmd` and then reaching the
# separator inside the quotes, which is the prefix form and legitimate.
assign_value="(\"[^\"]*\"|'[^']*'|[^[:space:]\;\&\|\"']*)"
assign_form="(^|[\;\&\|\(][[:space:]]*)${name}=${assign_value}[[:space:]]*[\;\&\|]"

if [[ "$CMD" =~ $assign_form ]]; then
  echo "shell-machinery-guard: blocked. This command opens with a variable assignment followed by a separator — \`FOO=bar; cmd\` rather than the prefix form \`FOO=bar cmd\`, which scopes the variable to one command and is fine. Every observed instance has been scaffolding the task did not ask for: a name assigned once, referenced by nothing, in front of the command doing the work. Unlike a shell function this costs no permission prompt, so nothing else will surface it — which is the reason for the block rather than an argument against it. Write the command without it, and write the ref or path out literally however long it is; a programmatically issued command saves no keystrokes. If a value genuinely has to be computed and reused, write the script to a file with the Write tool and run the file. See tool-and-shell-safety.md, \"Don't add shell machinery the task didn't ask for\"." >&2
  exit 2
fi

if [[ "$CMD" =~ $posix_form ]] || [[ "$CMD" =~ $keyword_form ]]; then
  echo "shell-machinery-guard: blocked. This command defines a shell function. The permission gate reads the statement type, not the intent, and reports \`function_definition\` — a parser node no allow rule can grant — so the command stops for approval even when its actual work is read-only. Every observed instance has been scaffolding the task did not ask for: a stray \`for_each() { :; };\` in front of an ordinary command, or a shadow of a builtin meant to enforce a rule on yourself. Write the command without it; nothing usually breaks. If a function is genuinely needed, write the script to a file with the Write tool and run the file, which keeps the definition out of the command string. See tool-and-shell-safety.md, \"Don't add shell machinery the task didn't ask for\"." >&2
  exit 2
fi

exit 0
