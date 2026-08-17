# Presentation canonical field authority matrix

`PresentationCanonicalPayloadV2` contains only fields that alter the audience-visible combat meaning. Its 48-field allowlist is byte-for-byte set-equal to the Runtime public combat projector. Every included field has an explicit string, integer, Boolean, ordered string-array or ordered pure-JSON-array type; wrong types fail closed before identity is built. Dictionary insertion order never affects the fingerprint.

Identity semantics such as source lineage, sequence, kind, ordinal, audience, ruleset and session remain explicit top-level V2 fields and participate in semantic validation. They are not hidden inside arbitrary raw payloads.

`observer_correlation_id` is separately classified observer metadata. It correlates a V2 cue with the existing public telemetry receipt but is not a Presentation identity input, canonical audience-payload fingerprint input, audience key, or gameplay authority. A separate `observer_correlation_fingerprint` seals that transport metadata, while the local surface explicitly excludes both observer fields from its semantic exact-once fingerprint. The ID defaults to the public `source_receipt_id` and never carries private payload content.

Local time, frame counters, animation state, UI focus, window state, playback preferences, Node paths, Object IDs and temporary paths are forbidden from the canonical fingerprint. Private skill definitions, private costs, cooldown details, future targets, hidden plans and RNG state are rejected at the public projection boundary rather than merely omitted after publication.

The machine-readable matrix classifies 48 included public fields, 10 explicitly excluded ephemeral fields, 9 identity-semantic fields and 2 observer-only fields outside the payload. JSON number restoration is explicit through `normalize_serialized_receipt`; no caller relies on implicit numeric conversion. No discovered field is unclassified.

`PRESENTATION_CANONICAL_FIELD_UNCLASSIFIED_COUNT=0`

`PRESENTATION_EPHEMERAL_FIELD_IN_FINGERPRINT_COUNT=0`

`PRESENTATION_SEMANTIC_FIELD_OMISSION_COUNT=0`
