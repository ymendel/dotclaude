#!/usr/bin/env bash
# Checks over ensure-trailing-newline.sh, the PostToolUse hook that appends a missing newline:
#
#   ./hooks/test/run-post-tool-use.sh
#
# ADR 0008 puts it in Tier 1 because it "mutates files without being invoked". Nothing asks for it
# and nothing reports when it runs, so both directions are silent: a newline it fails to add looks
# like a file that already had one, and a byte it appends to something it should have left alone is
# discovered by whatever reads that file next.
#
# Fixtures are real files in a temp directory, because the subject's whole job is a side effect on
# disk — there is no output to assert on. Every case reads the file back rather than trusting exit
# status, which is 0 on every path including the ones that deliberately do nothing.
#
# One case documents a gap rather than a guarantee: `file` reports some binary content as plain
# `data`, which the skip pattern does not match. That is asserted as current behaviour so a future
# fix fails here loudly instead of silently improving. See the section for the detail.
#
# No framework, no `set -e` (a failing case must report, not abort), non-zero exit at the end.

if ! command -v jq &>/dev/null; then
    echo "run-post-tool-use: jq is required — the subject exits 0 without it, so every case" >&2
    echo "would report a pass it never earned." >&2
    exit 1
fi

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBJECT="$(cd "$TEST_DIR/.." && pwd)/ensure-trailing-newline.sh"

if [ ! -x "$SUBJECT" ]; then
    echo "run-post-tool-use: $SUBJECT is missing or not executable." >&2
    exit 1
fi

. "$(cd "$TEST_DIR/../.." && pwd)/test/_harness.sh"

WORK_DIR="$(mktemp -d)"
cleanup() { [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"; }
trap cleanup EXIT

# write_raw <name> <printf-format> — create a fixture with exact bytes, no implicit newline.
write_raw() {
    TARGET="$WORK_DIR/$1"
    # shellcheck disable=SC2059 — the format is supplied by the caller on purpose.
    printf "$2" > "$TARGET"
}

# run_on <path> — feed the hook a PostToolUse payload naming that path.
run_on() {
    jq -n --arg p "$1" '{tool_input: {file_path: $p}}' | "$SUBJECT" > "$WORK_DIR/out.txt" 2>&1
    STATUS=$?
}

# run_payload <jq-program> — feed an arbitrary payload, for the shapes with no usable file_path.
run_payload() {
    jq -n "$1" | "$SUBJECT" > "$WORK_DIR/out.txt" 2>&1
    STATUS=$?
}

# bytes_of <path> — the file's size, which is how "was a byte appended" is decided.
bytes_of() { wc -c < "$1" | tr -d ' '; }

# ends_with_newline <path>
ends_with_newline() {
    [ -s "$1" ] || return 1
    [ -z "$(tail -c1 "$1")" ]
}

# --- The happy path, both directions ----------------------------------------

write_raw missing.txt 'no trailing newline'
run_on "$TARGET"
if ends_with_newline "$TARGET"; then
    report true 'a file with no trailing newline gains one'
else
    report false 'a file with no trailing newline gains one' "last byte is still not a newline"
fi
expect_eq "$(bytes_of "$TARGET")" 20 'exactly one byte is appended'

write_raw present.txt 'already terminated\n'
run_on "$TARGET"
expect_eq "$(bytes_of "$TARGET")" 19 'a file already ending in a newline is left alone'

# Repeated runs must converge rather than stacking newlines — this hook fires on every write, so a
# file Claude edits ten times would otherwise gain ten blank lines.
write_raw repeat.txt 'content'
run_on "$TARGET"
run_on "$TARGET"
run_on "$TARGET"
expect_eq "$(bytes_of "$TARGET")" 8 'running three times appends exactly one newline in total'

# Trailing blank lines are the author's, not a missing terminator. The last byte is already a
# newline, so nothing is owed.
write_raw blanks.txt 'content\n\n\n'
run_on "$TARGET"
expect_eq "$(bytes_of "$TARGET")" 10 'existing blank lines are not collapsed or added to'

# A file whose last character is whitespace but not a newline still wants one.
write_raw spaced.txt 'content '
run_on "$TARGET"
expect_eq "$(bytes_of "$TARGET")" 9 'a trailing space is not mistaken for a terminator'

# Interior newlines say nothing about the final byte.
write_raw multiline.txt 'one\ntwo\nthree'
run_on "$TARGET"
expect_eq "$(bytes_of "$TARGET")" 14 'a multi-line file is judged by its last byte only'

# --- Files it must not touch ------------------------------------------------

# An empty file is not missing a terminator, it has no content to terminate. Appending here would
# turn a deliberately empty file — an index, a placeholder — into a one-line file.
write_raw empty.txt ''
run_on "$TARGET"
expect_eq "$(bytes_of "$TARGET")" 0 'an empty file is left empty'

write_raw image.png '\211PNG\r\n\032\n\000\000\000\015IHDR'
run_on "$TARGET"
expect_eq "$(bytes_of "$TARGET")" 16 'a PNG is skipped rather than corrupted'

# --- Payload shapes that name no usable file --------------------------------

run_payload '{tool_input: {}}'
exited=$STATUS
expect_eq "$exited" 0 'a payload with no file_path exits 0'

run_payload '{}'
expect_eq "$STATUS" 0 'a payload with no tool_input exits 0'

run_on "$WORK_DIR/does-not-exist.txt"
expect_eq "$STATUS" 0 'a file_path that does not exist exits 0'
if [ -e "$WORK_DIR/does-not-exist.txt" ]; then
    report false 'a missing file is not created' 'the hook created the file'
else
    report true 'a missing file is not created'
fi

mkdir -p "$WORK_DIR/a-directory"
run_on "$WORK_DIR/a-directory"
expect_eq "$STATUS" 0 'a directory as file_path exits 0'

# The hook is a PostToolUse side effect, so a non-zero exit would surface as a hook error on a write
# that actually succeeded. Every path above returned 0; this states it as the contract.
write_raw contract.txt 'text'
run_on "$TARGET"
expect_eq "$STATUS" 0 'the ordinary append path also exits 0'

# --- A known gap, asserted so a fix is loud ---------------------------------
#
# The skip matches `file` output against binary|image|executable|archive|compressed|media. Content
# that `file` cannot classify is reported as plain `data`, which matches none of those — so a file
# of raw bytes is treated as text and gains a trailing newline. Measured: a file of four NUL-ish
# bytes plus ASCII reports as `data` here.
#
# This asserts what the hook DOES, not what it should do. The fixture is 10 bytes and comes back as
# 11: the newline is appended to content that is not text. If the pattern gains `data` or the check
# moves to something like `grep -qI`, this case fails and that is the intended signal — the header
# claims it "skips binary files", and today that claim holds only for content `file` recognises.

write_raw opaque.bin '\000\001\002\003binary'
run_on "$TARGET"
expect_eq "$(bytes_of "$TARGET")" 11 'KNOWN GAP: unrecognised binary content is treated as text'

summary || exit 1
