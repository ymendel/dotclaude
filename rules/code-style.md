# Code Style

## General

- Always include a trailing newline at the end of the file.
- Simple is better than clever.
- Prefer `if/else` over ternary operators. The ternary has a readable longhand; use it. Without this rule, conditional logic gets buried in expressions and is harder to read at a glance.
- Parse files with parser libraries, not regex.
- Always use latest versions of languages, frameworks, and dependencies. Check upstream for actual latest — don't guess from memory.
- Use intention-revealing names, not keystroke-saving abbreviations in code names (e.g., `destination` not `dest`, `config` not `cfg`).
- Use generators over manual file creation (`bundle gem`, `rails new`, `rails generate`, `npm init`, etc.).
- Many decisions are recorded and enforced by linting rules. Always defer to those.
- When in doubt, consistency is key. It's usually much better to match existing examples in the codebase than to do what is nominally correct. If the existing pattern has problems, that is a consideration for separate cleanup or refactoring.

