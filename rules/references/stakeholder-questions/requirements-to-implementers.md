# Stating a Requirement You Own to the People Implementing It

> Not loaded in context by default. See `rules/stakeholder-questions.md` for behavioral guidance.

## Why the behavior-vs-implementation line runs in this direction too

The behavior is the durable interface; the implementation is downstream of it. Hand implementers a
mechanism — "set up a Heroku pipeline to promote staging to production" — and you have made a
technical choice that may not fit their stack, and coupled the outcome you actually want to one
particular way of getting there.

State the outcome instead: "a change is done when it's live in production and confirmed working." Let
them propose the mechanism that fits. You keep ownership of *what* and *why*; they own *how*. This is
the same split as a good ADR, where Context and Decision are yours and the implementation detail is
negotiable.

## Land it in their vocabulary

This composes with *Match the stakeholder's vocabulary* and with `naming.md`'s *Adopt the domain
expert's term*: when stating the desired behavior, use the words the implementers already use for the
concept, so the requirement arrives in their vocabulary rather than imposing yours.
