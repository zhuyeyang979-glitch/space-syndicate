# Card Resolution History Save-Owner Cutover

Date: 2026-07-18

## Decision

`CardResolutionHistoryRuntimeService` remains the single resolved-card history state owner.
The v0.6 registry now binds its own `card_resolution_history` section between
`card_resolution_execution` and `ai`; `session` remains the final apply owner.

The fixed registry boundary is now 19 sections: 12 transactional and 7 unsupported.
`FULL_RUN_RESUME_CLAIM=false` remains mandatory.

## Save contract

The history section has state version 1 and exactly five owner-state fields:

- `schema`
- `history_limit`
- `history`
- `appended_resolution_ids`
- `revision`

`preflight_save_data()` and `apply_save_data()` share the same pure normalization path.
The contract rejects malformed types, non-data values, invalid limits or revisions,
duplicate resolution IDs, noncanonical lineage, lineage/history mismatch, and recursive
private owner or AI fields. Retired card-owner fields are removed during normalization and
are never restored.

The history codec boundary is intentionally stricter than the generic handshake encoder:
dictionary keys must be `String`, `StringName` values are rejected, floats must be finite,
and accepted normalized state must round-trip through the real
`RulesetSaveHandshakeService` codec. Recursive `cash`, `hand`, `discard`, `private_hand`,
and `slot_index` payload is rejected during candidate preflight and stripped during live
append.

`player_index` is deliberately different: authoritative raw history retains it because
contract-party memory and tableau accounting still consume that internal gameplay fact.
It is not a public field. `public_history_snapshot()`, `CardHistoryPublicQueryPort`, and
append receipts expose no authoritative actor or player index.

The saved lineage is the sorted set of retained history resolution IDs. Execution retains
its separate exactly-once transaction lineage and does not contain history content.

## Restore dependency

`CardHistoryRestoreDependencyContract` is stateless. It derives the stable
`card-history:<resolution_id>` IDs and a deterministic fingerprint from candidate history
data, then validates annotation checkpoint references against that candidate. When an
annotation checkpoint supplies the optional `history_fingerprint`, it must be the canonical
64-character lowercase SHA-256 for the same normalized candidate history; malformed or
mismatched values fail closed without returning annotation payload. The field remains
optional for checkpoints that predate this dependency guard. The contract never queries a
live owner, UI node, or Main, and owns no history copy.

## Compatibility

The handshake top-level envelope schema is unchanged. Because the required manifest now
contains 19 sections, an old 18-section v3 envelope fails closed with a manifest or section
count mismatch. No data is guessed or synthesized.

Seven sections remain unsupported: `ruleset`, `routes`, `commodity_belt_visibility`,
`card_inventory`, `military`, `card_resolution_queue`, and `ai`. Full-run resume is not
claimed by this cutover.

## Evidence

- `tests/card_resolution_history_save_owner_test.gd`
- `tests/card_resolution_history_runtime_service_test.gd`
- `tests/v06_save_owner_registry_test.gd`
- `tests/v06_save_envelope_runtime_test.gd`
- `tests/game_session_save_characterization_test.gd`
- `scenes/tools/CardResolutionHistoryRuntimeServiceBench.tscn`
