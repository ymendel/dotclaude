# Tailwind — Literal Identifiers and Theming

> Not loaded in context by default. See `rules/code-style.md` for the directives.

Measured against Tailwind v4.3.1. The pruning mechanism is v4's source scanning, so expect it to
hold across v4 and re-check it on v5.

## A Tailwind identifier has to exist as literal text

Tailwind emits a class, or a `@theme` variable, only where its name appears verbatim in a scanned
source. Anything assembled at runtime is invisible to it. That is well known for class names and
applies identically to `@theme` variables, where the assembling code doesn't look like it produces
a Tailwind identifier at all:

```ruby
# Ordinary string building. Tailwind never sees any of these names.
def self.series_color(series)
  "var(--series-color-#{(series - 1) % PALETTE_SIZE + 1})"
end
```

**A declaration does not count as a use of itself.** Six colors declared in `@theme` and referenced
only through that method: the build emitted three and dropped the rest. The three survivors were
the ones whose names happened to appear in test assertions, because the default scan reads the test
directory. So the shipped stylesheet depended on the wording of a test.

**The failure is silent.** A declaration referencing an undefined custom property is invalid at
computed-value time and falls back to the property's initial value. `fill: var(--series-color-4)`
renders black. Nothing raises, and a green suite says nothing unless something asserts on the built
stylesheet.

**Partial survival is what makes it read as a data bug.** An all-or-nothing prune would be obvious
on the first look at the page. Half a palette working looks like an off-by-one.

## Name the values out, don't route around the scan

```ruby
# Each name is spelled out because Tailwind only keeps what it finds as literal text.
SERIES_COLORS = [
  "var(--series-color-1)",
  "var(--series-color-2)",
  # … through the end of the palette
].freeze

def self.series_color(series)
  SERIES_COLORS.fetch((series - 1) % SERIES_COLORS.length)
end
```

The comment matters, because the list reads as something a tidier line would replace, and replacing
it breaks the page without breaking a test. Keep it in application code rather than relying on the
scan to find names in tests.

**A plain `:root` block is the wrong lesson**, and it is the one that suggests itself first, because
it works: unlayered CSS isn't pruned. It trades `@theme`, where v4 wants design tokens, for a
workaround, puts the token outside `@layer theme` where it outranks everything in the cascade, and
leaves the dynamic reference in place for the next token to trip on. Fix the reference, not the
declaration.

**`@source inline()` doesn't reach this case.** It safelists *classes*, and a token outside
Tailwind's recognized namespaces generates no class. `--color-thing-1` in `@theme` generates
`.bg-thing-1`, while `--series-color-1` generates nothing. Renaming the token into `--color-*` to
make it safelistable puts the set back under the scan with a list to keep in step by hand.

## How much of `@theme` to fill in against a real design system

A shared *scale* is not the same as a coincidental *value*. Test whether the agreement holds for
values nobody has looked at yet.

- **Shared scale.** A design on a 4px spacing grid is v4's `--spacing: .25rem` multiplier, so
  `mt-3` is the design's step 3 for every value, present and future. There's nothing to name.
- **Coincidental value.** A design radius of 6px that matches `rounded-md` is two unrelated scales
  touching once. Writing `rounded-md` records a coincidence as a mapping, and when the design moves
  that radius, nobody can tell which `rounded-md`s meant it.

From that:

- **Define a token for whatever the design names, under the design's name.** `@theme` exists to
  replace Tailwind's starter theme with the team's vocabulary.
- **Never translate one name into another.** `rounded-lg` because the pixels match is right today
  and unfalsifiable tomorrow.
- **Don't define what the design doesn't name.** A token nobody designed is a decision you invented
  and now own.
- **Override a namespace wholesale or not at all.** `--radius-sm` silently changes `rounded-sm` for
  everyone who knows Tailwind, and a half-overridden namespace can't be read off the markup.
  `--radius-*: initial` clears the defaults so only the design's values exist, and a habitual
  `rounded-2xl` then emits nothing. That fails quietly, and clearing `--color-*` takes the whole
  default palette with it, so start with namespaces like radius that little depends on.

## Why plain CSS over `@apply` in component CSS

- **Tokens go in `var()`.** `@apply text-label-xs` puts a utility between the rule and the token it
  wraps, one indirection further from the value.
- **`@variant` removes the strongest case for `@apply`.** It applies a Tailwind variant to plain CSS,
  so breakpoints and states no longer need utilities. `@reference` is needed only in Vue or Svelte
  `<style>` blocks and CSS modules.
- **`@apply` earns its place for compound utilities** — `truncate`, `sr-only`, a ring recipe — whose
  expansion would otherwise be copied by hand and drift.
- **Utility churn across majors is a weak argument.** v4's renames were the shadow, drop-shadow,
  blur and backdrop-blur scales, `rounded-sm`/`rounded`, `outline-none` to `outline-hidden`, and
  `ring` to `ring-3`. Nothing in layout.
