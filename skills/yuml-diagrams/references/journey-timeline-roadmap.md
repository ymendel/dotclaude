# Journey, Timeline, and Roadmap Diagrams

## Journey Flow Diagrams

Customer journey maps using activity diagram syntax with emotion annotations.

### Syntax

```
(Phase Name)                    — journey phase/section header
[:emotion: Action text]         — step with emotion
[:emotion: "Quote text"]        — speech bubble with emotion
[Action text]                   — step without emotion
->                              — flow arrow (optional)
```

### Emotions

`:elated:` `:happy:` `:relieved:` `:neutral:` `:uncertain:` `:frustrated:` `:angry:`

### Example: Purchase journey

```
(Discover)->
[:happy: Finds product online]->
[:happy: "This looks promising"]->
(Evaluate)->
[:neutral: Reads reviews]->
[:uncertain: "Is it worth the price?"]->
(Purchase)->
[:frustrated: Complex checkout form]->
[:elated: Order confirmed]
```

### Tips

- `->` connectors are optional — omit for a cleaner look when all steps flow sequentially
- Mix speech bubbles (quotes) and action labels freely within a phase
- Layout is always top-to-bottom; `@direction` has no effect

---

## Timeline Diagrams

Project milestones with major and minor events.

### Syntax

```
(Title|Subtitle|Details)   — major milestone (3-part)
(Title|Subtitle)           — major milestone (2-part)
(Title)                    — major milestone (title only)
[Event text]               — minor milestone
->                         — flow arrow (optional)
```

### Example: Product launch timeline

```
(Q1|Research|Interviewed 50 users)->
[Team assembled]->
(Q2|Beta launch)->
[First paying customer]->
(Q3|Public release|v1.0 shipped)->
[Press coverage]->
(Q4|Growth)
```

---

## Roadmap Diagrams

Feature cards organised across planning horizons.

### Syntax

```
(Horizon Name)             — column/horizon header
[Card Title|Description]   — feature card with description
[Card Title]               — card without description
[Card{bg:color}]           — coloured card
```

### Example: Product roadmap

```
(Now)
[Search improvements|Full-text search]
[Bug fixes|Top 10 issues]
(Next)
[Mobile app|iOS and Android]
[API v2|REST and GraphQL]
(Future)
[AI features{bg:green}]
[Enterprise SSO]
```

### Tips

- Horizon names are arbitrary — "Now / Next / Future", "Q1 / Q2 / Q3", "Short / Medium / Long" all work
- `{bg:color}` on a card draws the eye; use sparingly
- Cards under a horizon don't need separators — each `[...]` is a card
