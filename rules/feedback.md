# Feedback

Overflow for rules and feedback that don't fit an existing rule file. When in doubt, capture a lesson here rather than agonizing over its permanent home or skipping it — but this file loads into context every session like any rule, so it's revisable staging, not free staging. Periodically review: if an entry has grown into a pattern or belongs with a coherent topic, extract it into an appropriate rule file. Prune what hasn't earned its place rather than letting the file accrete.

A second entry on a topic is the usual signal to promote it. A new rule file costs 124 bytes of framing beyond its content, so the question is never whether a small file is affordable — `self-improvement.md` is the smallest at about 1.5KB — but whether the topic has a home a future reader would look in.

## Never resize a browser window you did not open

Driving a browser means working inside an application the user is also using. Resizing a window that
was already open changes their environment for a capture they did not ask for, and they meet it as
their own window suddenly at phone width with nothing saying why.

**Crop instead.** The `zoom` action takes a region and returns a tight image without touching
anything on screen, which is what a narrower-than-viewport capture actually needs. Reach for it
first rather than after a resize has already fired.

**Ask for your own window at the start, because you cannot get one later.** `tabs_context_mcp` with
`createIfEmpty` creates a new window with its own tab group — but the parameter is documented to
have **no effect once an MCP tab group already exists**, and `tabs_create_mcp` only ever adds a tab
to the existing group. So a window of your own is available before any group exists and not
afterwards. Plan around that rather than hoping past it: once the group lives in the user's window,
`resize_window` takes a `tabId` that must be in that group, so every resize available to you moves
*their* window.

Failure mode this prevents: the resize is invisible from inside the session. The screenshot comes
back at whatever size it was going to be regardless, so nothing in the result reports that the
user's window moved — and where the capture is then fixed by cropping anyway, the disruption bought
nothing at all. The user notices; the agent does not.
