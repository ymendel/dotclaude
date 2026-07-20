# Serialization Vocabulary — Full Model

> Not loaded in context by default. See `rules/naming.md` for the resident directive and failure mode.

For describing transformations between a runtime object and its persisted or wire form, prefer **serialize / deserialize**. Reserve **encode / decode** for cases that are honestly about transforming between representations without committing to a runtime-vs-storage direction.

## The readability-gradient collision

The intuitive mental model — "encode" goes from something readable to something not, "decode" reverses it — holds for several common cases (UTF-8 string → bytes, plain text → Morse code) but breaks down for two important ones:

- **Base64-style encodings** (Base32, Crockford, Base58, &c.) where the encoded form is *more* portable than the binary "original." Encoding a binary ULID into ASCII makes it transmittable through text channels — the readable form is the encoded form.
- **JSON encoding** where the encoded form is text, arguably more readable than the in-memory object graph.

The honest framing: encode/decode is about transformation between representations, with the encoded form serving some purpose (transmission, storage, safety, deduplication). Which form is "more readable" depends on context.

## Why serialize/deserialize is cleaner

Directionality is unambiguous — serialize always means *runtime object → persistable form*, regardless of which form ends up more or less readable. Marshal serializes to binary, JSON serializes to text — both are serialization. The "is the output readable?" question doesn't enter into the word choice, so there's no implicit readability gradient to violate.

## When to reach for which

- **serialize / deserialize**: runtime object ↔ persisted form, wire format, storage column, anything where the directionality is "in-memory ↔ saved." This is the default.
- **encode / decode**: transformations that aren't about runtime-vs-storage. Base64 (binary ↔ text-safe), URL encoding, character encoding (string ↔ bytes). When in doubt, ask whether "in-memory ↔ saved" describes the transformation. If yes, serialize/deserialize. If no, encode/decode is probably right.
- **dump / load**: Ruby's `Marshal` and `YAML` interface convention. Use when matching their idioms specifically, but serialize/deserialize is cleaner in prose.
- **hydrate / dehydrate**: avoid in writing. Frontend-framework jargon (React SSR, GraphQL caches) that survives on familiarity. Same bucket as corporate-policy jargon per `writing.md`.
- **inflate / deflate**: avoid. Collides with compression (zlib uses these for compress/decompress). The `writing.md` "Avoid words that collide with terms of art" rule fires.

## Failure mode this prevents

Without a default, every new context produces a fresh small decision and the codebase drifts toward "whichever term the model reaches for first." That drift breaks the single-name-per-concept discipline at the vocabulary level — the same operation gets called "encoding" in one place, "inflating" in another, "hydrating" in a third, none of them wrong but none of them the same.
