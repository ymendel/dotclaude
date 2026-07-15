---
name: naming-analyzer
description: "Suggest better names for variables, methods, classes, and modules across Ruby/Rails, JavaScript, and Python. Use when names feel vague or misleading, when asked to rename something, or when auditing naming consistency."
---

# Naming Analyzer

## When Invoked

Analyze the provided code or name(s) for:
- Vague or unclear names
- Abbreviations that obscure meaning
- Names that don't match behavior (especially side-effect traps)
- Inconsistent conventions within the codebase
- Language/framework convention violations

## Before Suggesting a Rename

Ask before proposing any name change:
- **Does it predict behavior?** A reader who hasn't seen the implementation should be able to guess what the method does.
- **Does it reflect all side effects?** A method named `load_user` that also updates a session is lying.
- **Does it survive at the call site?** Read the name in context: `user.active?` reads naturally; `user.is_active?` does not.
- **Is consistency the better call?** If surrounding code uses a pattern consistently, a style correction may not be worth the churn — note it separately from violations.

## Ruby & Rails

Ruby has distinct conventions that differ from other languages — apply these when working in `.rb` files.

### Method naming

- Predicates use `?` suffix: `valid?`, `persisted?`, `admin?`, `empty?`
- Never use `is_`, `has_`, `can_` prefixes for predicates — those are JS/Python patterns
- Mutating or exception-raising variants use `!` suffix: `save!`, `update!`, `destroy!`
- Readers: just the noun — `name`, `email`, not `get_name`
- Writers: `name=` — never `set_name`
- Class method entry points that **construct an instance** (delegate to `.new`) use prepositions like `.for`, `.from`, `.of` when the argument is unambiguous in context. When the argument isn't self-evident, prefer a clearly-named method over a preposition with kwargs — a clear method name does more work than kwargs that disambiguate after the fact.

  ```ruby
  # GOOD — preposition with unambiguous args, construction semantics
  Money.from(cents)
  Schedule.from(start_date)
  Invoice.for(user)              # builds an invoice for this user

  # WHEN AMBIGUOUS — use a clear method name, not kwargs to disambiguate
  Invoice.draft_for(user)        # action + relation, both clear
  Invoice.for(user, kind: :draft) # avoid: kwargs rescuing a too-vague entry point

  # Retrieval is a different category — use finders, not prepositions
  Invoice.find_by(user: user)
  ```

  Find-or-build operations sit comfortably under this convention if the caller treats the source as opaque (e.g., `Cart.for(user)` whether it finds or builds). When find-vs-build is part of the contract the caller relies on, name it explicitly: `Cart.find_for(user)`, `Cart.build_for(user)`, `Cart.find_or_build_for(user)`.

### Rails naming

| Concept | Convention | Example |
|---|---|---|
| Model | Singular PascalCase | `BlogPost` |
| Table | Plural snake_case | `blog_posts` |
| Controller | Plural + Controller | `BlogPostsController` |
| Mailer | Singular + Mailer | `UserMailer` |
| Job | Verb + Job | `SendWelcomeEmailJob` |
| Concern | Adjective/capability | `Searchable`, `Taggable` |
| Scope | Adjective or past participle | `active`, `published`, `for_user` |
| Service object | NounVerber (preferred) | `InvoiceCreator`, `WelcomeEmailSender` |
| Namespace | Domain noun | `Admin`, `Api`, `Internal` |

**Service object naming**: `NounVerber` (`InvoiceCreator`) is the more common Rails idiom — `-er`/`-or` doer suffixes like `Updater`, `Broadcaster`, `Presenter`, `Notifier`, `Hydrator`. `VerbNoun` (`CreateInvoice`) is also defensible, especially with a callable-class invocation style. Either works; flag inconsistency within a project.

**Module namespacing**: `Admin::UsersController` is preferred over `AdminUsersController` — the double-colon signals a domain boundary, not just a prefix. Namespace names should be domain nouns (`Admin`, `Api`, `Public`, `Internal`), not organizational catch-alls (`Helpers`, `Concerns`).

### Variable and instance variable naming

- Local variables: just the noun — `user`, `account`, `invoice`
- Instance variables: use scope-revealing names when multiple related objects coexist — `@current_user`, `@invited_user`, `@target_user`; use the plain noun when only one instance of that type exists in context — `@user`, `@account`
- In controllers and mailers, `@` variables are shared with templates — names should read naturally in view context too
- Unused block args: use `_` when the arg is irrelevant, `_varname` when naming the type aids readability:

```ruby
# _ when irrelevant
[1, 2, 3].each_with_index { |_, i| puts i }

# _varname when the type clarifies intent
users.each_with_object([]) { |_user, memo| memo << memo.size }
```

### Anti-patterns (Ruby-specific)

- `is_active` — wrong; use `active?`
- `get_user` — wrong; use `user` or `find_user`
- `set_name` — wrong; use `name=`
- `UserHelper`, `Utils`, `Helpers`, `Manager` as catch-alls — "Helper" signals an extraction opportunity; name for what it actually does (`Formattable`, `Searchable`)

## General Conventions

### JavaScript/TypeScript
- Variables/functions: `camelCase`, classes: `PascalCase`, constants: `UPPER_SNAKE_CASE`
- Booleans: `is`, `has`, `can`, `should` prefixes — `isActive`, `hasPermission`

### Python
- Variables/functions: `snake_case`, classes: `PascalCase`
- Booleans: `is_`, `has_`, `can_` prefixes

## Common Issues to Flag

**Side-effect traps** — the most important category:
```ruby
# Bad: implies read-only, but mutates
def get_user(id)
  user = User.find(id)
  user.update!(last_login_at: Time.current)
  user
end

# Good
def find_and_touch_user(id)
```

**Vague names** — always flag: `data`, `info`, `result`, `temp`, `val`, `x`, `obj`

**Abbreviations** — flag unless well-established (`id`, `url`, `api`, `html`, `json`, `db`):
- Bad: `usr`, `cfg`, `src`, `dest`, `btn`, `err`

**Magic numbers** — flag unnamed numeric literals except 0, 1, -1:
```ruby
# Bad
raise if attempts > 5

# Good
MAX_RETRY_ATTEMPTS = 5
raise if attempts > MAX_RETRY_ATTEMPTS
```

## Decision Tree

```
Is it a Ruby predicate (returns true/false)?
├─ Yes → Use ? suffix (active?, valid?, admin?)
└─ No → Is it a mutating/raising Ruby method?
    ├─ Yes → Consider ! suffix (save!, destroy!)
    └─ No → Is it a boolean in JS/Python?
        ├─ Yes → Use is/has/can prefix (isActive, hasError)
        └─ No → Is it a function/method?
            ├─ Yes → Verb phrase — does the name reflect ALL side effects?
            └─ No → Is it a class?
                ├─ Yes → Singular noun, PascalCase
                └─ No → Descriptive noun, language-appropriate case
```

## Report Format

```
## Naming Issues

### [file:line] `current_name` → `suggested_name`
**Issue**: [what's wrong]
**Reason**: [why the suggestion is better]
**Severity**: Critical / Major / Minor
```

Group by severity. Flag side-effect traps as Critical.

## Attribution

Adapted from the `naming-analyzer` skill in [softaworks/agent-toolkit](https://github.com/softaworks/agent-toolkit) (MIT). Full notice: [ATTRIBUTION.md](./ATTRIBUTION.md).
