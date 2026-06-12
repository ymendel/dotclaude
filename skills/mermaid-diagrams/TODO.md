# mermaid-diagrams TODO

Ideas worth picking back up on later.

## Semantic-JSON linter on top of `merman-cli parse --pretty`

**Current behavior:** `scripts/validate_mermaid.py` validates that a diagram parses, then renders an ASCII preview so a human (or Claude reading the tool result) can eyeball whether the shape matches intent. That catches the "parses fine, but the arrow goes the wrong way" failure mode by visual inspection — not automatically.

**Gap:** the rendered ASCII is a *visual* check, dependent on someone (Claude or the user) noticing the discrepancy. Some semantic mistakes are crisp enough to flag mechanically:

- **Orphan node references** — an edge points at a node that was never declared.
- **Dangling edges** — an edge whose other end resolves to a node with no other connections (often a typo of an existing node's id).
- **Sequence-diagram participants that never receive a message** — declared but only ever sender, or vice versa. May be intentional, but worth surfacing.
- **Class-diagram relationships using mismatched arrow syntax** — a composition (`*--`) where an association (`-->`) was meant, or vice versa. Hard to catch by eye in dense diagrams.

**Possible shapes:**

1. **Inline lint in `validate_mermaid.py`** — after parse success, run `merman-cli parse <path> --pretty`, load the semantic JSON, walk for the smells above, print warnings alongside the ASCII preview. Single script, single invocation.
2. **Separate `lint_mermaid.py` script** — keeps validate's job small (syntax + visual preview) and treats linting as an opt-in second pass. More flexible if the lint logic grows.

(1) is the lower-friction default; (2) becomes attractive only if the linter grows enough to warrant its own surface.

**Trigger to revisit:** when a parse-success-but-semantically-wrong diagram actually ships and the ASCII review didn't catch it. That instance shows which smell would have helped, and the lint logic can target it specifically rather than speculatively covering every category above.

**Not yet worth doing because:** no concrete case has bitten. The ASCII preview is the cheaper, broader lever for now — semantic linting is a sharpening pass, valuable but speculative until a real miss shows where to aim.
