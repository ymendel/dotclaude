# Charts and Stories

## Chart Diagrams

Types: `bar` (horizontal), `column` (vertical), `line` (time series), `pie` (proportions), `chart` (auto-picked).

### Syntax

```
@heading Title          — optional title
@caption Subtitle       — optional caption
Label: value            — data entry
Label: 100              — number
Label: |||||            — tally marks (count = number of pipe characters)
Label: 72%              — percentage
Label{!}: value         — accent/highlight (draws attention)
Label{bg:wheat}: value  — custom background tint
// comment
```

Charts ignore `@direction` — orientation is fixed per type.

### Bar — horizontal bars

Best for tally counts, survey responses, votes.

```
@heading Fruit bowl census
Apples: |||||
Pears: |||||||
Bananas: |||
Plums: ||||||||||
```

### Column — vertical bars

Best for category comparisons (quarters, months, products).

```
@heading Quarterly revenue
Q1: 100
Q2: 120
Q3: 140{!}
Q4: 160
```

### Line — time series

Best for trends. Labels are typically dates or sequential periods.

```
@heading Monthly active users
2025-01: 120
2025-02: 135
2025-03: 128
2025-04: 142
2025-05: 155
2025-06: 170
```

### Pie — proportions

Best for parts-of-a-whole. Percentages should sum to ~100; raw numbers are normalised automatically.

```
@heading Sprint status
Done: 72%
In progress: 18%
Blocked: 10%
```

### Chart — auto-picked type

Renderer picks the best fit: dated labels → line, percentages → pie, short numeric labels → column, tally marks → bar.

```
Q1: 100
Q2: 120
Q3: 140
Q4: 160
```

### Chart guidelines

- Pick a specific type when intent is clear; use `chart` only when ambiguous
- Tally marks suit small whole-number counts (≤ ~12); use numbers for larger values
- Use `{!}` on a single most-important bar or slice to draw attention

---

## Story Format

Stories combine markdown prose with embedded yUML diagrams in a slide-like document.

### Syntax

````
@style blueprint          — global style (applies to all diagrams)
@direction LR             — global direction

# Slide Title             — starts a section

Prose text in **markdown**.

```yuml class              — diagram block; type follows "yuml"
@heading Diagram Title
[A]->[B]
```

---                       — slide separator

# Next Slide
...
````

Global `@style` and `@direction` directives apply across all embedded diagrams. Per-diagram `@heading` and `@caption` still work inside each block.

### Story guidelines

- Start with a high-level overview, then progressively reveal detail
- Each slide: one heading, 1–2 sentences of prose, one diagram
- Use different diagram types to show different perspectives — class for structure, sequence for behaviour, journey for UX, c4 for systems
- Keep individual diagrams focused: 3–7 elements, not comprehensive maps
- Use `@heading` on diagrams to label what aspect they show
