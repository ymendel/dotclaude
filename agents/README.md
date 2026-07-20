# Agents

Specialized subagents invoked via the `Agent` tool (or directly by Claude when delegating). Each one exists because it brings something specific — a constrained toolset, a particular model choice, a domain focus, or a behavioral constraint that would be awkward to bake into a general prompt.

## How they're used

Claude delegates to these when a task fits the agent's scope. You can also invoke them directly by name. Agents run with their own context. They don't inherit the current conversation.

---

## Code quality

**`code-reviewer`** (opus) — Comprehensive review: correctness, security, best practices. Opus because review quality compounds — a weaker model misses subtle issues.

**`refactoring-specialist`** — Behavior-preserving transformation of poorly structured or duplicated code. The constraint "preserve all existing behavior" is load-bearing.

**`debugger`** — Root cause diagnosis and bug fixes. Broad toolset so it can chase a bug wherever it leads.

## Architecture & design

**`architect-reviewer`** (opus) — Evaluates system design decisions, architectural patterns, and technology choices at the macro level. Opus for the same reason as code-reviewer: the cost of a shallow architecture review is high.

**`api-designer`** — REST/GraphQL endpoint design, OpenAPI specs, authentication patterns, versioning strategies. Distinct from just "write an API" — this is about the design decisions.

**`graphql-architect`** (opus) — Federation, distributed schemas, query performance across microservices. Specialized enough that it earns its own agent rather than folding into api-designer.

## Infrastructure & reliability

**`devops-engineer`** — Infrastructure automation, CI/CD, containerization, and deployment workflows. The operational side of shipping.

**`sre-engineer`** — SLOs, error budgets, fault-tolerant system design, incident response. Reliability engineering as a discipline, not just ops tasks.

**`performance-engineer`** — Identifying and eliminating bottlenecks across application, database, and infrastructure layers. Cross-cutting by nature.

## Data & databases

**`database-administrator`** — High-availability architectures, replication, disaster recovery, production database operations. The infrastructure and ops angle.

**`postgres-pro`** — PostgreSQL-specific: query optimization, configuration tuning, advanced features. The depth angle.

## Security

**`security-auditor`** (opus, read-only) — Systematic vulnerability analysis, compliance gap identification, evidence-based findings. Read-only tools are intentional — this agent assesses, it doesn't change things.

**`security-engineer`** (opus) — Implementing security controls, zero-trust architecture, threat modeling, shifting security left. The implementation counterpart to security-auditor.

## Testing & quality

**`qa-expert`** — Test strategy, quality metrics, planning across the full development cycle. Broader than writing tests.

**`test-automator`** — Building and integrating automated test frameworks and CI/CD test pipelines. The execution side.

## Documentation & communication

**`technical-writer`** (haiku) — API references, user guides, SDK docs, getting-started content. Haiku is appropriate here — documentation is about clarity, not reasoning depth.

## Research & discovery

**`codebase-pattern-finder`** — Finds existing implementations, usage examples, and patterns in a codebase. Critically: documentarian only. It shows what exists without evaluating, critiquing, or recommending. That constraint is the whole point.

**`data-researcher`** — Discovers, collects, and validates data from multiple sources. Read-only toolset reinforces the "gather, don't modify" purpose.

**`search-specialist`** — Targeted information retrieval across sources when precision matters more than synthesis.

## Domain-specific

**`rails-expert`** — Rails-idiomatic patterns, Hotwire, background jobs, Rails 7/8 version-awareness. Earns its place because Rails has strong conventions that generalist models often miss or work against.

**`payment-integration`** (opus) — PCI compliance, fraud prevention, secure transaction processing. Opus because the cost of getting this wrong is not abstract.

**`legacy-modernizer`** — Incremental migration strategies for systems that can't be rewritten wholesale. The "maintain business continuity" constraint shapes everything about how this works.

**`git-workflow-manager`** (haiku) — Branching strategy design and merge management. Narrow, but "design a Git workflow for this team" is a real ask that benefits from focused guidance.

## Diagrams

**`mermaid-diagram-specialist`** — Creates Mermaid diagrams (flowcharts, sequence, ERD, C4, state, &c.) and delegates to the `mermaid-diagrams` skill for syntax reference.
