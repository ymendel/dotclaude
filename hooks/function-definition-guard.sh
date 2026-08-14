#!/usr/bin/env bash
# function-definition-guard.sh — PreToolUse (Bash) guard.
#
# Blocks a shell function definition in a Bash command. Not because defining a
# function is wrong in general, but because every observed instance has been
# scaffolding the task did not ask for, and the scaffolding is what stops the
# run:
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

if [[ "$CMD" =~ $posix_form ]] || [[ "$CMD" =~ $keyword_form ]]; then
  echo "function-definition-guard: blocked. This command defines a shell function. The permission gate reads the statement type, not the intent, and reports \`function_definition\` — a parser node no allow rule can grant — so the command stops for approval even when its actual work is read-only. Every observed instance has been scaffolding the task did not ask for: a stray \`for_each() { :; };\` in front of an ordinary command, or a shadow of a builtin meant to enforce a rule on yourself. Write the command without it; nothing usually breaks. If a function is genuinely needed, write the script to a file with the Write tool and run the file, which keeps the definition out of the command string. See tool-and-shell-safety.md, \"Don't add shell machinery the task didn't ask for\"." >&2
  exit 2
fi

exit 0
