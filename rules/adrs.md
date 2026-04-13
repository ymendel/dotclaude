# ADRs

## General

- Prefer ADRs to any sort of internal or proprietary "plan mode".
- Unless already existing in the project in a different location, ADRs live in a `docs/adr/` directory

## Motivation and Writing Style

The reason for ADRs is to keep a record of the motivation behind certain decisions. Without ADRs, it may be clear that certain decisions were made during the life of the project, but the rationale or consequences behind those decisions are almost certain lost.

Write the ADR as if it is a conversation with a future developer. This requires good writing style, with full sentences organized into paragraphs. Bullets are acceptable only for visual style — or when explicitly called for, such as for the pros/cons or consequences — not as an excuse for writing sentence fragments.

## Format

- ADRs are Markdown files
- ADRs are numbered, monotonically increasing with no gaps.
- The file name should be `<number(4 digits, 0 padded)>-<title(shortened, snake case)>.md`
- The ADR contains the following information:
    - Title
    - Date
    - Status
    - Context
    - Decision
    - Consequences

### Sections

#### Title

The title is a simple one-line short noun phrase, and appears in the file with the ADR number followed by the title. Examples:

- ADR 1: Deployment on Ruby on Rails 3.0.10
- ADR 9: LDAP for Multitenant Integration

#### Date

The date this ADR was created

#### Status

Status can have one of the following values:

- **Proposed**: project stakeholders have not yet agreed to it
- **Accepted**: agreed

ADRs always start as "Proposed", unless clearly specified otherwise.

#### Context

This section describes the forces at play, including technological, political, social, and project local. These forces are probably in tension, and should be called out as such. The language in this section is value-neutral. It is simply describing facts.

#### Decision

This section describes the response to these forces. It is stated in full sentences, with active voice.

Unless the decision is very clear, with no significant trade-offs to consider, this section should include an "Options" sub-section describing options considered, with pros and cons listed for each. There should be no more than 3 options.

#### Consequences

This section describes the resulting context, after applying the decision. All consequences should be listed here, not just the "positive" ones. A particular decision may have positive, negative, and neutral consequences, but all of them affect the team and project in the future.

All consequences must be clearly marked as positive, negative, or neutral.

## Immutability (or close enough)

- Once an ADR has been adopted, it is not to be changed materially.
- If a later ADR changes or reverses an earlier decision, the earlier ADR's status will be updated with reference to the later ADR. Examples:
    - **Status**: Deprecated (see ADR 23)
    - **Status**: Superseded (see ADR 13)
    - **Status**: Accepted — broadcast mechanism superseded by ADR 0021
- Especially if an ADR has been only partially superseded, more references to the later ADR can be made in the body.
- Never make any changes other than these status updates and reference additions.
