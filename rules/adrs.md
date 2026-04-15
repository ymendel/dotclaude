# ADRs

## General

- Prefer ADRs to any sort of internal or proprietary "plan mode".

## Immutability (or close enough)

- Once an ADR has been adopted, it is not to be changed materially.
- If a later ADR changes or reverses an earlier decision, the earlier ADR's status will be updated with reference to the later ADR. Examples:
    - **Status**: Deprecated (see ADR 23)
    - **Status**: Superseded (see ADR 13)
    - **Status**: Accepted — broadcast mechanism superseded by ADR 0021
- Especially if an ADR has been only partially superseded, more references to the later ADR can be made in the body.
- Never make any changes other than these status updates and reference additions.
