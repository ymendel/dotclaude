# Canvas Diagrams

Canvases are structured 2D thinking grids — SWOT analyses, Strategy Choice Cascades, retros, OKRs, post-mortems, or any custom framework.

## Required Metadata

```
@type canvas          — required; tells the renderer to use the canvas layout
@cols N               — top-level grid width (default: 1 / template default / heuristic)
```

## DSL Structure

```
# Region Title            — top-level region (renders as a box or group)
## Sub Region             — sub-region nested under the most recent #
> Custom help text        — blockquote overrides canonical help text
Prose body…               — body lines
- bullet                  — bullet item (also works with `* `)

# Region {cols: 2}        — sub-grid width inside this group
# Region {span: 2}        — width weight within its row (default 1)
# Region {bg: cream}      — fill this cell
# Region {!}              — accent: tint title and body
```

Decorators chain with `;`: `{cols: 2; bg: cream; !}`

A `#` section with at least one `##` child renders as a group of sub-boxes; without children it renders as a single box.

Forced line breaks: `\n` inside any title, help text, or prose paragraph.

## Auto-Detected Templates

When section names match a known framework, the renderer applies canonical help text, inserts missing sections as dashed placeholders, and hints the layout shape.

### SWOT Analysis — 2×2 quadrant

Canonical sections: `Strengths`, `Weaknesses`, `Opportunities`, `Threats`

```
@type canvas

# Strengths
Deep ML expertise; existing customer base of 200 SMBs.

# Weaknesses
- Limited marketing budget
- Single-region presence

# Opportunities
Enterprise demand for privacy-first tools is accelerating.

# Threats
Big-tech entrants with bundled offerings.
```

### Strategy Choice Cascade — vertical stack

Canonical sections and sub-sections:

```
Aspiration / Winning Aspiration
Where to Play
  Geography
  Customer / Customer Segments
  Channels
  Offering / Products
How to Win
Capabilities / Must-Have Capabilities
Management Systems / Systems
```

```
@type canvas

# Aspiration
Launch a successful startup that helps people build face-to-face networks
without compromising privacy.

# Where to Play
## Geography
Initially focus on saturating specific events in a single town, then global.
## Customer
Anyone doing networking — hobbyist artists to business folks.
## Channels
Organic makes most sense.
## Offering
Privacy-first way of sharing always-up-to-date contact details at events.

# How to Win
???

# Capabilities
- Privacy-by-design contact format
- Event partnerships

# Management Systems
- KPI: subscription revenue to £30K ARR
- KPI: k-factor for card shares
```

## Custom Canvas (No Template)

Use `>` blockquotes for help text on non-template sections:

```
@type canvas
@cols 2

# What worked
> Highlights from this sprint
- Shipped onboarding redesign
- Cut p95 latency by 40%

# What didn't
> Rough edges
- Demo broke in staging twice
- Search relevance regression

# Surprises
- 3 enterprise leads from a tweet

# Next sprint
- Re-run onboarding A/B
- Latency budgets per service
```

## Guidelines

- Use canonical section names when the framework matches — you get help text and layout for free
- Use `>` blockquote only for non-template sections or to override canonical framing
- `{bg}` draws the eye — limit to one or two cells maximum
- `{!}` marks the single most important region
- Leave a region empty (heading + optional `>` help) when the user is mid-thinking — the dashed placeholder invites filling in
