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
- Prefer `Data.define` over `Struct.new` for value objects — anything constructed once to carry data, not mutated afterward. `Data` gives immutability (no setters), `#with` for derived copies, and an `ArgumentError` when a member is missing at construction, where `Struct` silently fills it with `nil`. Both accept keyword and positional construction, so the call site is unchanged. Reach for `Struct` only when the object genuinely needs to be mutated in place, or needs Array-like behavior (`to_a`, `[]` indexing) that `Data` doesn't provide. Failure mode: `Struct.new(..., keyword_init: true)` is the older and more common form, so it gets reached for by reflex — shipping a mutable value object whose setters invite downstream drift, and which accepts an incomplete construction without complaint.
- Keep non-trivial defaults out of method signatures — put them in the method body instead. Keyword defaults are evaluated once at parse/load time, so a default like `client: ApiClient.new` creates a single shared instance rather than a fresh one per call. Even for simple values, a body default keeps logic visible and easy to change.

### Aesthetics

- Use prepositions (`.for`, `.of`, `.from`) for class method entry points that construct an instance, when args are unambiguous. Otherwise name the method clearly. Prefer a named method over kwargs that disambiguate. (Examples and edge cases: `naming-analyzer` skill.)
- Prefer guard clauses and early returns over nested `if`/`else`/`elsif` when it improves readability.
- Prefer kwargs over positional args (exceptions: single arg, or leading positional + kwargs).
- Prefer symbol keys in hashes. Convert at serialization boundaries.
- Alphabetize attrs, kwargs, case branches, etc. when order doesn't matter.
- Never indent methods under `private`. Put a blank line after the keyword and keep the private methods at the same indentation as the public ones. Beware the specific trap that produces the other form: `rubocop-rails-omakase` ships `Layout/IndentationConsistency` as `Enabled: false` with `EnforcedStyle: indented_internal_methods` sitting inert on the next line, so the indented style looks mandated by the linter and is not — `rubocop --show-cops Layout/IndentationConsistency` shows the resolved truth. Failure mode: reading a disabled cop's `EnforcedStyle` as a live rule, then writing the indented form to comply with a constraint that does not exist, and defending it as the linter's call.

## Rails

- Principle of least power: prefer HTML over CSS, CSS over JS, backend over frontend.
- `app/` is for business domain. `lib/` is for generic, non-business-specific code that could theoretically be upstreamed or extracted to a gem.

### Gemfile

- Gems used in all environments go above the group blocks. Gems scoped to specific environments go inside the appropriate `group` block — never use the `groups:` kwarg.
- Always specify version constraints with the `~>` operator when adding a gem.

### Commits

- Keep database changes (migrations, schema) in a separate commit from model/code changes. Without this separation, a single commit conflates schema and logic, making bisect and rollback harder.

### Migrations

- When a migration *creates* a table, define its indexes inside the `create_table` block, not as a trailing `add_index` after it. Prefer the `index:` option right on the column definition (`t.string :name, null: false, index: { unique: true }`) so everything about a column — type, null, index — lives in one place. Use `t.index ...` inside the block only when the index spans multiple columns. Reserve a standalone `add_index` for adding an index to a table that already exists in a *later* migration. Rails generators emit the trailing `add_index` form by default, so this means editing generated migrations. The resulting schema is identical either way (`structure.sql` is a `pg_dump`, so index placement in the source doesn't change its output) — this is purely about keeping the migration source readable. Failure mode: shipping the generator's default `create_table` + trailing `add_index` split when the index belongs on the column.
- Never reference application models (`Post.find_each`, `User.update_all`, custom scopes) inside a migration. Migrations get replayed years later — on fresh databases, in CI, on snapshot restores — and inherit whatever the model has become: renamed columns, `default_scope`, callbacks that skip `update_columns`-style writes, removed associations. Use raw SQL via `execute(...)` for data backfills, and drop the matching `Model.reset_column_information` line when you remove the model reference.
- Pass the original column type as the third argument to `remove_column` so the migration is reversible: `remove_column :users, :legacy_id, :integer`. Without the type, `db:rollback` can't reconstruct the column. If the column had an index, split the migration into explicit `up` / `down` rather than relying on `change`, and re-add the index in `down`.
- Same goes for `rename_column` paired with index removal: if `up` drops `index_users_on_email`, `down` must restore it. Otherwise a rollback quietly leaves the schema missing an index that production planners depend on.
- When adding a unique index to a table that may have duplicates (any non-greenfield table), either dedupe in the migration itself or add a pre-check that raises with a clear message and the offending values. Letting `add_index ..., unique: true` blow up mid-deploy with Postgres's default error message is hostile to the next person running the migration:

  ```ruby
  dupes = select_all(<<~SQL).to_a
    SELECT email, COUNT(*) AS count
    FROM users
    GROUP BY email
    HAVING COUNT(*) > 1
  SQL

  if dupes.any?
    raise "User has #{dupes.size} duplicate email values; dedupe before re-running. " \
          "Offending: #{dupes.map { |row| "#{row['email']} (#{row['count']})" }.join(', ')}"
  end
  ```

  Even when production is known to be empty, dev/staging/CI environments restored from snapshots may not be. The pre-check costs nothing and saves a confused debug session.
- When adding a column with semantic constraints (`end_date >= start_date`, `price >= 0`, `status IN (...)`), pair the model validation with a database `CHECK` constraint. The model validation gives users a friendly error. The constraint protects against direct SQL, console writes, and the next backend that talks to the same table.

### Tests

- In Minitest, prefer `refute` and its family (`refute_nil`, `refute_includes`, `refute_equal`, `refute_predicate`, &c.) over the `assert_not`/`assert_not_nil`/`assert_not_includes` aliases for any negative assertion. `refute` is the idiomatic Minitest negative and reads more directly than the `assert_not*` form. Failure mode: reaching for `assert_not` by reflex (Rails generators and much example code emit it) when `refute` is the house preference.

### Rake Tasks

- Rake task arguments use bracket syntax, not space-separated: `task[arg]` not `task arg`.
  When passing args via `bin/rails`, this means e.g. `bin/rails tailwindcss:watch[always]`.

### Runners and Scripts

- Before writing a Rails runner (or any script) that references multiple ActiveRecord models, confirm each one actually exists where assumed — list `app/models/` or grep for the constant. A model name that sounds right ("SyntheticRun", "Objective") may live in a gem under a namespace, may be an external service's concept with no local table at all, or may simply not exist. Guessing leads to `NameError`s mid-script and a wasted round-trip. A 1-second check up front avoids it. This is especially important in projects that pull domain models from engines or gems — the convention "models live in `app/models/`" is not universal.
