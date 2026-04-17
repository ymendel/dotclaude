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

# Skip binary files
if file "$FILE_PATH" | grep -qiE 'binary|image|executable|archive|compressed|media'; then
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
