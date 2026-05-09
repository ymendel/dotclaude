---
name: yuml-diagrams
description: "yUML text-to-diagram DSL. Use when asked to visualize, diagram, or document systems using yUML — class, sequence, activity, use case, state, C4, journey, timeline, roadmap, canvas (SWOT, strategy), and chart diagrams."
---

# yUML Diagramming

yUML generates diagrams from a concise text DSL. Embed in Markdown via URL:

```
https://app.yuml.me/diagram/v1/{type}/{style}/{dsl}.svg
```

Types: `class`, `sequence`, `activity`, `usecase`, `state`, `c4`, `journey`, `timeline`, `roadmap`, `canvas`, `bar`, `column`, `line`, `pie`, `chart`

Styles: `clean`, `plain`, `boring`, `sketch`, `scruffy`, `napkin`, `midnight`, `blueprint`

Canonical DSL spec: https://app.yuml.me/dsl/v1/spec.txt

## Metadata Directives

Work in any diagram type, anywhere in the DSL:

```
@heading Title          — diagram title
@caption Subtitle       — subtitle/description
@legend true            — enable legend display
@direction LR           — layout: LR/RIGHT or TB/TD/DOWN (default TB)
@style sketch           — visual theme
@type canvas            — required for canvas diagrams
```

`@direction` has no effect on sequence, journey, timeline, roadmap, or chart types — their layout is intrinsic. Use cases default to LR; all others default to TB.

Forced line breaks: a literal `\n` creates a guaranteed break in headings, captions, class labels, notes, and canvas content.

## Diagram Type Selection

| Type | Use for |
|------|---------|
| `class` | Domain models, OOP design, entity relationships |
| `sequence` | API flows, auth flows, system interactions |
| `activity` | Workflows, algorithms, business processes |
| `usecase` | System functionality, actors, requirements |
| `state` | State machines, lifecycle states |
| `c4` | System architecture — context, container, component |
| `journey` | Customer journey maps with emotions |
| `timeline` | Project milestones and phases |
| `roadmap` | Feature planning across horizons |
| `canvas` | Strategy frameworks (SWOT, Strategy Choice Cascade, retros, OKRs) |
| `bar`/`column`/`line`/`pie` | Data visualisation |

### Ambiguous cases

Before picking a type, ask:
- Am I showing *what something is* (→ `class`) or *who owns and deploys it* (→ `c4`)?
- Is my subject *performing steps in a process* (→ `activity`) or *moving through lifecycle states* (→ `state`)?
- Does the *emotional arc* matter (→ `journey`) or the *chronology* (→ `timeline`)?

## Load the Reference Before Generating

Load the relevant reference file before writing any diagram DSL:

| Diagram type | Load |
|---|---|
| `class` | `references/class-diagrams.md` |
| `sequence` | `references/sequence-diagrams.md` |
| `activity`, `usecase`, `state` | `references/activity-use-case-state.md` |
| `c4` | `references/c4-diagrams.md` |
| `journey`, `timeline`, `roadmap` | `references/journey-timeline-roadmap.md` |
| `canvas` | `references/canvas-diagrams.md` |
| `bar`, `column`, `line`, `pie`, `chart`, story format | `references/charts-and-stories.md` |

Do not load reference files for diagram types not being used.

## Quick Start Examples

### Class Diagram

```
[Customer|name;email]-orders>*[Order|date;total]
[Order]->*[LineItem|qty;price]
[LineItem]->[Product|name;sku;price]
[Animal]^[Duck|beakColor|swim();quack()]
[Repo|<<interface>>]^-.-[UserRepo]
```

### Sequence Diagram

```
(User)Login->[Auth]
[Auth]checkCredentials->[DB]
[DB]result-->[Auth]
{alt valid}
[Auth]token-->(User)
{else}
[Auth]error-->(User)
{end}
```

### C4 Diagram

```
@heading Banking System Context
@legend true
[Customer|Person|A user of the bank]
[Banking System|System|Core system for accounts and payments]
[Email Service|External|Transactional email :database:]
[Customer]-Uses->[Banking System]
[Banking System]-Sends mail via-.->[Email Service]
```

## Never Do

- **NEVER leave an unclosed `]`, `)`, or `{`** — the parser fails silently and renders nothing; always check the last element of each line
- **NEVER use a class arrow in a sequence diagram (or vice versa)** — each type has its own arrow set; cross-type arrows produce no output or a malformed render
- **NEVER get the pipe count wrong** — `[Name|Type|Desc]` (C4) vs. `[Name|attrs|methods]` (class) both use three sections but mean different things; one extra pipe shifts the renderer's interpretation of every section
- **NEVER quote names that don't need it** — the grammar is liberal about bare names; unnecessary quotes can break parsing
- **NEVER set `@direction` on sequence, journey, timeline, roadmap, or chart types** — those types have intrinsic layout; the directive is silently ignored and signals a misunderstanding of the type

## When the Diagram Renders Wrong

- **Renders nothing** → unclosed bracket or paren on the last element; check every `[`, `(`, and `{` has a match
- **Boundary missing or malformed** (C4) → unbalanced `{ }` — every `{Name` needs a closing `}`
- **Wrong shape or relationship** → arrow type mismatch; verify the arrow set for the diagram type in the reference file
- **Card sections misread** (C4 or class) → pipe count off; count pipes in `[Name|...|...]` carefully
- **Embed URL broken** → DSL must be URL-encoded when inlined in the URL path; spaces become `%20`, `>` becomes `%3E`, etc. — use the POST API or a URL encoder for complex DSL
