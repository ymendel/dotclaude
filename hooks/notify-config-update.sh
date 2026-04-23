#!/usr/bin/env bash
f=$(jq -r '.tool_input.file_path // ""')
[[ "$f" == "$HOME/.claude/"* ]] && printf '{"systemMessage":"Updated ~/.claude: %s"}\n' "${f#$HOME/.claude/}"
exit 0
