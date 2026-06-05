# Workaround for Claude Code preflight ENOSPC false-positives on macOS
# x86_64 APFS (Bun statfs alignment bug). Sourced via BASH_ENV.
# See: https://github.com/anthropics/claude-code/issues/63877#issuecomment-4627467164

trap '[ $? -ne 0 ] && printf "\n"' EXIT
