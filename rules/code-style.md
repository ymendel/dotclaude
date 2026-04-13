# Code Style

## General

- Always include a trailing newline at the end of the file.
- Simple is better than clever.
- Parse files with parser libraries, not regex.
- Always use latest versions of languages, frameworks, and dependencies. Check upstream for actual latest — don't guess from memory.
- Use intention-revealing names, not keystroke-saving abbreviations in code names (e.g., `destination` not `dest`, `config` not `cfg`).
- Use generators over manual file creation (`bundle gem`, `rails new`, `rails generate`, `npm init`, etc.).
- Many decisions are recorded and enforced by linting rules. Always defer to those.

## Ruby

- Prefer instance-oriented design over class methods.
- No metaprogramming — it's a last resort. Repetition, even many times over, is better than meta magic. Write the code out explicitly.
- Method name prefixes suggest extracting a sub-object.
- Never use numbered block arguments (`_1`, `_2`, …) in blocks. Always use explicit named arguments (e.g. `|item|`, `|node|`, `|x|`). Prefer a meaningful name to a single-character one.
- Use Symbol#to_proc where appropriate — single-argument blocks where only a single method is called on the argument. e.g. use `words.map(&:upcase)` rather than `words.map { |word| word.upcase }`
- If a gem exists that does it well and isn't abandoned, use it over reinventing the wheel — especially for nuanced domains (I18n, email, URLs, slugs, protocols, specs, etc).

### Aesthetics

- Use prepositions (e.g. `.for`, `.of`, `.from`) for expressive class method entry points that delegate to `.new`. Unless it is _incredibly_ clear what the argument(s) would be, name the method for clarity. Heavily prefer a clear method name to using kwargs.
- Prefer guard clauses and early returns over nested `if`/`else`/`elsif` when it improves readability.
- Prefer kwargs over positional args (exceptions: single arg, or leading positional + kwargs).
- Prefer symbol keys in hashes; convert at serialization boundaries.
- Alphabetize attrs, kwargs, case branches, etc. when order doesn't matter.

## Rails

- Principle of least power: prefer HTML over CSS, CSS over JS, backend over frontend.
- `app/` is for business domain. `lib/` is for generic, non-business-specific code that could theoretically be upstreamed or extracted to a gem.

### Testing

- Avoid fixtures at all costs. Use factories instead, with factory_bot_rails. (exception: interacting with very specific data, like files and network-call responses. vcr is a good choice for the latter.)
