# Bash Compatibility for Skills

Claude Code's Bash tool runs through zsh by default on macOS, so bash-specific syntax in a skill's bash blocks can fail at runtime. Either avoid the bash-isms below, or invoke bash explicitly (`/usr/bin/env bash`) when you genuinely need them.

## Syntax that fails under zsh

| Pattern                              | Error in zsh             |
| ------------------------------------ | ------------------------ |
| `declare -A`                         | bad substitution         |
| `VAR=$(cmd) other-cmd`               | parse error near '('     |
| `[[ $x =~ regex ]]` + `BASH_REMATCH` | undefined variable       |
| `\!=` (escaped)                      | condition expected       |
| `grep -oP`                           | invalid option (no PCRE) |

## Prohibited patterns and fixes

| Pattern            | Why                        | Fix                          |
| ------------------ | -------------------------- | ---------------------------- |
| `declare -A NAME`  | Bash 4+ only, fails in zsh | Use parallel indexed arrays  |
| `grep -oP`         | Perl regex not portable    | Use `grep -oE` + awk         |
| `$'\n'`            | ANSI-C quoting             | Use literal newlines         |
| `\!=` in `[[ ]]`   | Unnecessary escape         | Use `!=` directly            |

### Parallel indexed arrays (replacing `declare -A`)

```bash
# WRONG: associative array (bash 4+ only)
declare -A ACCOUNTS
ACCOUNTS["alice"]="ssh-key"
ACCOUNTS["bob"]="gh-cli"

# CORRECT: parallel indexed arrays
ACCOUNT_NAMES=()
ACCOUNT_SOURCES=()

add_account() {
  local name="$1" source="$2"
  for idx in "${!ACCOUNT_NAMES[@]}"; do
    if [[ "${ACCOUNT_NAMES[$idx]}" == "$name" ]]; then
      ACCOUNT_SOURCES[$idx]+="$source "
      return
    fi
  done
  ACCOUNT_NAMES+=("$name")
  ACCOUNT_SOURCES+=("$source ")
}

add_account "alice" "ssh-key"
add_account "bob" "gh-cli"
```

### Portable regex (replacing `grep -P`)

```bash
# WRONG: Perl regex (not available on all systems)
account=$(grep -oP '(?<=GH_ACCOUNT=")[^"]+' .mise.toml)

# CORRECT: extended regex + sed
account=$(grep -E 'GH_ACCOUNT\s*=' .mise.toml | sed 's/.*=\s*"\([^"]*\)".*/\1/')
```

### Running bash-specific syntax when you need it

When a block genuinely needs bash features, invoke bash explicitly rather than relying on the login shell:

```bash
/usr/bin/env bash << 'EOF'
declare -A MAP
MAP["key"]="value"
echo "${MAP[key]}"
EOF
```

The quoted heredoc delimiter (`'EOF'`) keeps the outer shell from expanding anything inside.
