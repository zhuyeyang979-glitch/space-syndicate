# V0.7.5 Presentation receipt identity authority matrix

Post-patch verification is complete on base Head `16ba8532b53cc598a422060039aaee49c862057b` plus the audited working-tree repair. Before the repair, one explicit cue-ID assignment concealed two effective identity origins: the staged Presentation event and the public application wrapper reused one Authority receipt ID and entered one mixed signal stream.

The repaired path has one `V075PresentationReceiptIdentityV2` builder, no Presentation-owned sequence cursor, one dedicated Presentation bus and a Consumer that validates rather than invents identity. `source_authority_sequence` is copied explicitly from the public-action resolution cursor, private-skill operation receipt revision, combat-owner revision or facility-bridge revision. Missing source ID, lowercase SHA-256 fingerprint or Authority sequence fails closed. The application wrapper remains on `resolution_presented` for application and telemetry observers; it cannot enter the Presentation Consumer.

| Layer | Current authority | Target authority |
| --- | --- | --- |
| Authority receipt | Public Action Batch owns the source receipt ID and source fingerprint | Unchanged |
| Mapper/program | Runtime staged event reuses source ID as final ID | Runtime passes source ID, validated source fingerprint, explicit upstream Authority sequence, kind, ordinal and public payload to the V2 builder |
| Application wrapper | Second producer enters the same mixed bus | Remains application/telemetry only |
| Receipt ID | Consumer copies legacy `combat_receipt_id` | V2 builder alone derives global Presentation ID |
| Audience | Implicit public | Explicit Model A `PUBLIC`, with hashed audience key |
| Ordinal | Missing | Explicit stable integer within the source program |
| Fingerprint | Consumer hashes the entire raw receipt | V2 builder hashes the audience-visible semantic envelope |
| Bus | `resolution_presented` carries unrelated schemas | Dedicated `combat_presentation_receipt_ready` carries only V2 |
| Consumer | Parses and invents identity from raw input | Validates V2 and preserves same/same idempotence plus same/different fail-closed |
| Surface | Independent downstream cue exact-once protection | Unchanged and not a receipt-identity writer |

`observer_correlation_id` is an observer-only compatibility hint. It lets cue telemetry correlate with the already-existing legacy public receipt, defaults to `source_receipt_id`, and carries only a public stable receipt identifier. It is not a Presentation ID input, not a canonical audience-payload fingerprint input, not gameplay authority, and not an audience key. Its own deterministic integrity field seals transport mutation, and the local surface excludes both observer fields from semantic cue identity.

Target ID tuple:

```text
domain=presentation_receipt_v2
ruleset_id
session_id
source_receipt_id
source_authority_sequence
presentation_kind
presentation_ordinal
audience_scope
audience_key_fingerprint
schema_version
payload_schema_version
```

The payload fingerprint is deliberately not an ID input. If content changes under the same identity, the Consumer must still report a collision.

`PRESENTATION_IDENTITY_SCOPE_MODEL=MODEL_A`

`PRESENTATION_RECEIPT_ID_WRITER_COUNT=1`

`PRESENTATION_FINGERPRINT_WRITER_COUNT=1`

`PRESENTATION_ORDINAL_WRITER_COUNT=1`

`PRESENTATION_SEQUENCE_CURSOR_WRITER_COUNT=0`

`PRESENTATION_IMPLICIT_SOURCE_LINEAGE_FALLBACK_COUNT=0`

`PRESENTATION_MIXED_BUS_CONSUMER_CONNECTION_COUNT=0`

`PRESENTATION_LEGACY_RAW_ID_CONSUMER_COUNT=0`

`PRESENTATION_IDENTITY_UNKNOWN_WRITER_COUNT=0`
