#!/usr/bin/env bash
# Checks over rules-floor.sh, the always-loaded rule set's size report:
#
#   ./scripts/test/run-rules-floor.sh
#
# ADR 0008 puts it in Tier 2 because it "derives figures that land in durable artifacts, and it
# writes a baseline". Both matter here. The figures get quoted into commit messages and trimming-pass
# write-ups, where a wrong total is indistinguishable from a right one — nobody re-adds the column.
# And `--record` is the one path that writes, so a bug there corrupts the reference every later run
# is measured against.
#
# WHAT IS ACTUALLY BEING TESTED is the definition of "always-loaded", which the subject implements
# as three filters: a `rules/*.md` glob, settings.json's claudeMdExcludes, and a `paths:` frontmatter
# check limited to the first ten lines. A file wrongly included inflates every future delta; a file
# wrongly excluded hides growth. Neither shows up in the output, which reports a plausible number
# either way.
#
# ISOLATION IS A FIXTURE GIT REPO. The subject opens with `cd "$(git rev-parse --show-toplevel)"`,
# so running it with the working directory inside a throwaway repo points every path — rules/,
# settings.json, the baseline — at fixtures whose sizes are known in advance. Sizes are written as
# exact byte counts rather than prose, so the expected totals are arithmetic rather than
# measurements of whatever the fixture text happened to be.
#
# No framework, no `set -e` (a failing case must report, not abort), non-zero exit at the end.

if ! command -v jq &>/dev/null; then
    echo "run-rules-floor: jq is required — the subject reports and exits 0 without it, so every" >&2
    echo "case would report a pass it never earned." >&2
    exit 1
fi

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUBJECT="$(cd "$TEST_DIR/.." && pwd)/rules-floor.sh"

if [ ! -x "$SUBJECT" ]; then
    echo "run-rules-floor: $SUBJECT is missing or not executable." >&2
    exit 1
fi

. "$(cd "$TEST_DIR/../.." && pwd)/test/_harness.sh"

WORK_DIR="$(mktemp -d)"
cleanup() { [ -n "$WORK_DIR" ] && rm -rf "$WORK_DIR"; }
trap cleanup EXIT

# fresh [excludes-json] — a new fixture repo with an empty rules/ and the given claudeMdExcludes.
fresh() {
    FIX="$WORK_DIR/repo"
    rm -rf "$FIX"
    mkdir -p "$FIX/rules" "$FIX/scripts"
    git -C "$FIX" init --quiet
    printf '{"claudeMdExcludes": %s}\n' "${1:-[]}" > "$FIX/settings.json"
}

# rule <name> <bytes> — a rules/<name> of exactly that many bytes, with no frontmatter.
rule() {
    printf '%*s' "$2" '' > "$FIX/rules/$1"
}

# rule_with <name> <content> — a rules file whose exact text matters (frontmatter cases).
rule_with() {
    printf '%s' "$2" > "$FIX/rules/$1"
}

# private_rule <name> <bytes> — same, under rules/private/.
private_rule() {
    mkdir -p "$FIX/rules/private"
    printf '%*s' "$2" '' > "$FIX/rules/private/$1"
}

# run [args...] — invoke the subject from inside the fixture repo.
run() {
    OUT=$(cd "$FIX" && "$SUBJECT" "$@" 2>&1)
    STATUS=$?
}

# owned_total — the byte figure on the "Always-loaded (this repo)" line.
owned_total() {
    printf '%s' "$OUT" | grep 'Always-loaded (this repo)' | while read -r _ _ _ _ bytes _; do
        printf '%s' "$bytes"
    done
}

# listed <name> — whether a rules file appears as a row in the report.
listed() {
    printf '%s' "$OUT" | grep -q "rules/$1$"
}

saw() {
    case "$OUT" in
        *"$1"*) report true "$2" ;;
        *) report false "$2" "output lacked '$1': $OUT" ;;
    esac
}

did_not_see() {
    case "$OUT" in
        *"$1"*) report false "$2" "output unexpectedly contained '$1'" ;;
        *) report true "$2" ;;
    esac
}

# --- The total is the sum of the included files -----------------------------

fresh
rule alpha.md 300
rule beta.md 100
run
expect_eq "$(owned_total)" 400 'the total is the sum of the included files'
expect_eq "$STATUS" 0 'a report run exits 0'

# Percentages are derived from that total, and are what a trimming pass reads to pick a target.
saw '75%' 'the larger file reports its share'
saw '25%' 'the smaller file reports its share'

# Descending by size, so the first row is where a trimming pass starts. Equal-looking output with
# the order reversed would send the pass at the wrong file.
fresh
rule small.md 100
rule large.md 900
rule middle.md 500
run
order=$(printf '%s' "$OUT" | grep -o 'rules/[a-z]*\.md' | tr '\n' ' ')
expect_eq "$order" 'rules/large.md rules/middle.md rules/small.md ' 'rows are ordered by size, descending'

# --- Exclusion by claudeMdExcludes ------------------------------------------

fresh '["rules/README.md"]'
rule alpha.md 300
rule README.md 700
run
expect_eq "$(owned_total)" 300 'an excluded file is left out of the total'
if listed 'README.md'; then
    report false 'an excluded file is not listed as a row' 'README.md appeared'
else
    report true 'an excluded file is not listed as a row'
fi

# The glob rewriting is the fiddly half: repo-relative paths mean a leading `**/` has to collapse to
# a `*` that can match empty, or the pattern demands a parent directory that is not there.
fresh '["**/README.md"]'
rule alpha.md 300
rule README.md 700
run
expect_eq "$(owned_total)" 300 'a leading **/ pattern still excludes a top-level file'

fresh '["rules/*.md"]'
rule alpha.md 300
rule beta.md 100
run
did_not_see 'Always-loaded (this repo)' 'excluding everything reports no owned section at all'

fresh '[]'
rule alpha.md 300
run
expect_eq "$(owned_total)" 300 'an empty exclude list excludes nothing'

# --- Exclusion by `paths:` frontmatter, and its ten-line boundary -----------

fresh
rule alpha.md 300
rule_with scoped.md '---
paths:
  - "**/*.rb"
---

Body text.
'
run
expect_eq "$(owned_total)" 300 'a file with paths: frontmatter is not always-loaded'

# The check reads only the first ten lines. A `paths:` below that is not frontmatter — it is prose
# that happens to start with the word, and excluding it would silently drop a real rule file.
fresh
rule alpha.md 300
rule_with late.md 'one
two
three
four
five
six
seven
eight
nine
ten
paths: this is prose, not frontmatter
'
run
if listed 'late.md'; then
    report true 'a paths: line below the tenth is not treated as frontmatter'
else
    report false 'a paths: line below the tenth is not treated as frontmatter' 'late.md was excluded'
fi

# Exactly on the boundary: the tenth line still counts as frontmatter.
fresh
rule alpha.md 300
rule_with edge.md 'one
two
three
four
five
six
seven
eight
nine
paths: on the tenth line
'
run
if listed 'edge.md'; then
    report false 'a paths: line on the tenth is treated as frontmatter' 'edge.md was included'
else
    report true 'a paths: line on the tenth is treated as frontmatter'
fi

# --- What is not a rule file ------------------------------------------------

fresh
rule alpha.md 300
printf '%*s' 500 '' > "$FIX/rules/notes.txt"
run
expect_eq "$(owned_total)" 300 'a non-markdown file in rules/ is not counted'

fresh
rule alpha.md 300
mkdir -p "$FIX/rules/references/topic"
printf '%*s' 900 '' > "$FIX/rules/references/topic/deep.md"
run
expect_eq "$(owned_total)" 300 'a nested reference file is not counted as always-loaded'

# --- The private companion section ------------------------------------------

fresh
rule alpha.md 300
run
did_not_see 'private companion' 'the private section is omitted when there is none'

fresh
rule alpha.md 300
private_rule secret.md 200
run
saw 'private companion' 'the private section appears when rules/private has content'
expect_eq "$(owned_total)" 300 'the private total is reported apart from the owned total'

# --- The baseline, which is the one thing this script writes ----------------

fresh
rule alpha.md 400
run
saw 'No baseline yet' 'with no baseline, the report says so'
did_not_see 'delta' 'with no baseline, no delta is claimed'

fresh
rule alpha.md 400
run --record
saw 'Baseline recorded' '--record confirms what it wrote'
expect_eq "$STATUS" 0 '--record exits 0'
if [ -f "$FIX/scripts/rules-floor.baseline" ]; then
    report true '--record creates the baseline file'
else
    report false '--record creates the baseline file' 'no baseline file'
fi
expect_eq "$(grep '^total=' "$FIX/scripts/rules-floor.baseline" | cut -d= -f2)" 400 \
    'the recorded baseline holds the owned total'
did_not_see 'No baseline yet' '--record does not also report a missing baseline'

# Recording then reporting with nothing changed must show no movement — a non-zero delta here
# would mean the two paths disagree about what they measure.
run
saw 'delta +0' 'an unchanged tree reports a zero delta'

# Growth is the signal the script exists for.
rule beta.md 100
run
saw 'delta +100' 'added bytes report as positive growth'

# And a trimming pass has to read as negative, which is the case anyone actually checks.
rm "$FIX/rules/beta.md"
rule alpha.md 300
run
saw 'delta -100' 'removed bytes report as negative growth'

# The private section must not leak into the owned figure the baseline tracks.
private_rule secret.md 5000
run
saw 'delta -100' 'private rules do not move the owned delta'

summary || exit 1
