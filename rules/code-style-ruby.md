---
paths:
  - "**/*.rb"
  - "**/*.rake"
  - "**/*.erb"
  - "**/Gemfile"
  - "**/Rakefile"
---

# Code Style — Ruby & Rails

## Ruby

- Prefer instance-oriented design over class methods.
- No metaprogramming — it's a last resort. Repetition, even many times over, is better than meta magic. Write the code out explicitly.
- Method name prefixes suggest extracting a sub-object.
- Never use numbered block arguments (`_1`, `_2`, …) in blocks. Always use explicit named arguments (e.g. `|item|`, `|node|`, `|x|`). Prefer a meaningful name to a single-character one.
- Use Symbol#to_proc where appropriate — single-argument blocks where only a single method is called on the argument. e.g. use `words.map(&:upcase)` rather than `words.map { |word| word.upcase }`
- If a gem exists that does it well and isn't abandoned, use it over reinventing the wheel — especially for nuanced domains (I18n, email, URLs, slugs, protocols, specs, etc).
- Keep non-trivial defaults out of method signatures — put them in the method body instead. Keyword defaults are evaluated once at parse/load time, so a default like `client: ApiClient.new` creates a single shared instance rather than a fresh one per call. Even for simple values, a body default keeps logic visible and easy to change.

### Aesthetics

- Use prepositions (e.g. `.for`, `.of`, `.from`) for expressive class method entry points that delegate to `.new`. Unless it is _incredibly_ clear what the argument(s) would be, name the method for clarity. Heavily prefer a clear method name to using kwargs.
- Prefer guard clauses and early returns over nested `if`/`else`/`elsif` when it improves readability.
- Prefer kwargs over positional args (exceptions: single arg, or leading positional + kwargs).
- Prefer symbol keys in hashes; convert at serialization boundaries.
- Alphabetize attrs, kwargs, case branches, etc. when order doesn't matter.

## Rails

- Principle of least power: prefer HTML over CSS, CSS over JS, backend over frontend.
- `app/` is for business domain. `lib/` is for generic, non-business-specific code that could theoretically be upstreamed or extracted to a gem.

### Gemfile

- Gems used in all environments go above the group blocks; gems scoped to specific environments go inside the appropriate `group` block — never use the `groups:` kwarg.
- Always specify version constraints with the `~>` operator when adding a gem.

### Commits

- Keep database changes (migrations, schema) in a separate commit from model/code changes. Without this separation, a single commit conflates schema and logic, making bisect and rollback harder.

### Rake Tasks

- Rake task arguments use bracket syntax, not space-separated: `task[arg]` not `task arg`.
  When passing args via `bin/rails`, this means e.g. `bin/rails tailwindcss:watch[always]`.

### Runners and Scripts

- Before writing a Rails runner (or any script) that references multiple ActiveRecord models, confirm each one actually exists where assumed — list `app/models/` or grep for the constant. A model name that sounds right ("SyntheticRun", "Objective") may live in a gem under a namespace, may be an external service's concept with no local table at all, or may simply not exist. Guessing leads to `NameError`s mid-script and a wasted round-trip; a 1-second check up front avoids it. This is especially important in projects that pull domain models from engines or gems — the convention "models live in `app/models/`" is not universal.

