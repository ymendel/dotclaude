#!/usr/bin/env bash
# Ensure files written or edited by Claude end with a trailing newline.
# Skips binary files (images, compiled artifacts, etc.)

if ! command -v jq &>/dev/null; then
  exit 0
fi

INPUT=$(cat)
FILE_PATH=$(jq -r '.tool_input.file_path // empty' <<<"$INPUT")

if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Skip binary files. `grep -I` treats a binary file as non-matching, so this asks whether there is
# any text here rather than trying to recognize every description `file` can emit — which is a list
# that cannot be completed. The previous pattern matched six words and missed SQLite ("SQLite 3.x
# database"), where appending a byte is the corrupting kind. Matching on `data` instead would have
# caught that and broken JSON, which `file` calls "JSON data".
#
# It also fails in the safe direction. Misjudging text as binary skips a newline, which is
# recoverable; misjudging binary as text appends to a file that is not lines, which is not.
if ! grep -qI . "$FILE_PATH"; then
  exit 0
fi

# If file is non-empty and last character is not a newline, add one.
# The shell strips trailing newlines from command substitution, so a non-empty
# result from tail -c1 means the file does not end with a newline.
if [ -s "$FILE_PATH" ]; then
  last_char=$(tail -c1 "$FILE_PATH")
  if [ -n "$last_char" ]; then
    printf '\n' >> "$FILE_PATH"
  fi
fi

exit 0
