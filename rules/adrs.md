# ADRs

## General

- Prefer ADRs to any sort of internal or proprietary "plan mode".
- Unless already existing in the project in a different location, ADRs live in a `docs/adr/` directory

## Motivation and Writing Style

The reason for ADRs is to keep a record of the motivation behind certain decisions. Without ADRs, it may be clear that certain decisions were made during the life of the project, but the rationale or consequences behind those decisions are almost certain lost.

Write the ADR as if it is a conversation with a future developer. This requires good writing style, with full sentences organized into paragraphs. Bullets are acceptable only for visual style — or when explicitly called for, such as for the pros/cons or consequences — not as an excuse for writing sentence fragments.

## Immutability (or close enough)

- Once an ADR has been adopted, it is not to be changed materially.
- If a later ADR changes or reverses an earlier decision, the earlier ADR's status will be updated with reference to the later ADR. Examples:
    - **Status**: Deprecated (see ADR 23)
    - **Status**: Superseded (see ADR 13)
    - **Status**: Accepted — broadcast mechanism superseded by ADR 0021
- Especially if an ADR has been only partially superseded, more references to the later ADR can be made in the body.
- Never make any changes other than these status updates and reference additions.
