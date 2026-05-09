# C4 Architecture Diagrams

A single `c4` diagram type covers Context, Container, Component, and System Landscape views — they use the same notation.

## Element Syntax

```
[Name|Type|Description]   — element with type and description
[Name|Type]               — element with type, no description
[Name]                    — untyped element
```

### Recognised Element Types (case-insensitive)

| Category | Accepted aliases |
|----------|-----------------|
| `Person` | User, Actor, Role, Customer, Admin |
| `System` | Software System, Platform |
| `Container` | Application, Web App, Service, Microservice, API, Database, Queue, Message Bus, Worker, Function |
| `Component` | Module, Package, Library, Subsystem |
| `External` | External System, External Service, Third Party, Vendor, SaaS |

## Edges

```
[A]->[B]                  — solid arrow
[A]-.->[B]                — dashed arrow (any `.` in the dash run → dashed)
[A]-Uses->[B]             — middle label (solid)
[A]-Sends mail via-.->[B] — middle label (dashed)
[A]<->[B]                 — bidirectional
[A]->[B] : Uses           — colon label (alternative syntax)
```

## Boundaries

Group elements inside a dashed frame:

```
{System Name
[Web App|Container|Browser UI]
[API|Container|REST endpoints]
[DB|Container|Data store :database:]
}
```

## Decorator Shortcodes

Add a strip visual to the card (cylinder, browser chrome, etc.) by embedding a shortcode in the description:

`:database:` `:browser:` `:mobile:` `:queue:` `:folder:` `:document:` `:console:`

## Metadata

```
@heading My Architecture
@caption System Context view
@legend true
@direction LR
```

## Example: System Context

```
@heading Banking System Context
@legend true
[Customer|Person|A user of the bank]
[Banking System|System|Core system for accounts and payments]
[Email Service|External|Third-party transactional email]
[Customer]-Uses->[Banking System]
[Banking System]-Sends mail via-.->[Email Service]
```

## Example: Container View with Boundary

```
@heading Banking System — Container View
{Banking System
[Web App|Container|Browser UI :browser:]
[API|Container|REST endpoints]
[DB|Container|PostgreSQL :database:]
}
[Customer|Person]-Uses->[Web App]
[Web App]->[API]
[API]->[DB]
[API]-Sends notifications via-.->[Email Service|External]
```

## Tips

- The three-pipe format `[Name|Type|Description]` is required for the renderer to apply the correct card style
- Wrong pipe count is one of the most common mistakes — double-check `[Name|Type|Desc]` vs `[Name|attrs|methods]` (class diagrams)
- Use `@legend true` to render a legend explaining element types
- Boundaries must be balanced: every `{Name` needs a closing `}`
