# Sequence Diagrams

Sequence diagrams show temporal interactions between participants.

## Participant Types

```
[Object]   — participant rendered as a box
(Actor)    — participant rendered as a stick figure
```

## Message Types

```
[A]message->[B]    — synchronous message (solid arrow, caller waits)
[A]message-->[B]   — return/response message (dashed arrow)
[A]message->>[B]   — asynchronous message (caller continues)
[A]message->[A]    — self-message
```

## Control Flow Fragments

```
{alt condition}
  ...messages...
{else}
  ...messages...
{end}

{loop condition}
  ...messages...
{end}

{opt condition}
  ...messages...
{end}
```

## Notes

```
[note: text]->[A]   — note attached to a participant
```

## Example: Authentication Flow

```
(User)Login->[Auth]
[Auth]validate->[Auth]
[Auth]checkCredentials->[DB]
[DB]result-->[Auth]
{alt valid}
[Auth]token-->(User)
{else}
[Auth]error-->(User)
{end}
```

## Example: Async Processing

```
(User)submitJob->>[Queue]
[Queue]enqueue-->(User)
[Worker]poll->>[Queue]
[Queue]job-->>[Worker]
[Worker]process->>[Worker]
[Worker]complete->[ResultStore]
```

## Tips

- Message labels go between the participant and the arrow: `[A]label->[B]`
- Omit the label entirely for unlabelled messages: `[A]->[B]`
- Self-messages work for internal processing: `[Auth]validate->[Auth]`
- `@direction` has no effect — sequence diagrams always flow top-to-bottom
