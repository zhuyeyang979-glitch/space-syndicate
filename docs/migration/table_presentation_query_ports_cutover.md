# Table Presentation Query Ports Cutover

Status: `TABLE_PRESENTATION_QUERY_PORTS_CUTOVER_GREEN`

Date: 2026-07-17

## Boundary

This cutover supplies the visibility-safe query boundary required before the Table Presentation Source/Target Cutover. It does not create a `RuntimeLoop`, a refresh source owner, a refresh target port, or a second presentation cadence.

Production composition now contains exactly one `TablePresentationQueryPorts` under `GameRuntimeCoordinator`. The composition owns only presentation queries and public presentation history:

- `LocalViewerAuthorization` authorizes exactly one local human viewer and fails closed when the viewer is absent or ambiguous.
- `WorldSessionPresentationQuery` produces an allowlisted public world projection and a viewer-equals-subject private projection.
- `TableActionPresentationQuery` combines viewer-authorized forced decisions, purchase state, target choice state, and public/private card-track queries.
- `TablePublicMapQuery` converts owner truth into `own`, `guessed`, or `unknown`, exposes only public unit fields, and displays only actual commodity flows.
- `PublicLogPresentationOwner` accepts typed `PublicLogReceipt` values, stores each receipt exactly once, and rejects any value outside the public-field allowlist, including cash, hand, discard, AI-plan, and owner-truth fields.
- `VictoryPresentationReceiptService` converts public Victory state changes and outcomes into typed, visibility-safe receipts.

## Production cutover

The following Main-owned paths were retired:

- `log_lines` storage;
- `_on_victory_outcome_applied`;
- `_city_markers_for_selected_player`;
- `_trade_route_markers_for_selected_product`;
- `_auto_monster_markers` and `_auto_monster_color`.

`VictoryControlWorldBridge.apply_outcome_receipt` was deleted. The bridge remains a private fact capture bridge for the authoritative Victory owner; it no longer calls Main for presentation.

Main's temporary `_log`, `_can_view_player_private_hand`, and `_local_human_player_index` methods now delegate to typed coordinator APIs and own no state or authorization policy. They are scheduled for physical deletion during the Source/Target consumer migration.

The production map refresh consumes `TablePublicMapProjection`; it no longer assembles owner-sensitive city, unit, or route marker dictionaries in Main.

## Visibility contract

Public projections omit opponent cash, hand, hand count, discard, owner truth, anonymous-card truth, AI plans, learning metadata, decision samples, and stable private identifiers.

Private projections require both:

1. an unambiguous local viewer authorization; and
2. `viewer_index == subject_index`.

If either condition fails, the projection is empty and unauthorized.

## Exact-once contract

`PublicLogPresentationOwner` keys each public event by `receipt_id`. Duplicate receipts are rejected without appending a second entry. Victory outcome receipts are similarly deduplicated before final-settlement presentation.

## Validation

- `table_presentation_query_ports_cutover_test.gd`: PASS 28/28
- `TablePresentationQueryPortsBench.tscn` through Godot 4.7 MCP: PASS 10/10
- `main_gd_architecture_gate_test.gd`: PASS 52 checks
- `final_settlement_runtime_composition_v06_test.gd`: PASS 7/7
- `main_victory_public_privacy_v06_test.gd`: PASS 21/21
- `main_runtime_composition_test.gd`: PASS
- `ui_text_smoke_test.gd`: PASS
- `smoke_test.gd --check-only`: PASS
- production `main.tscn` Godot 4.7 load: no parse or runtime errors

The complete smoke suite exceeded the five-minute bounded run without producing a result and was terminated by the owner process boundary. No claim of a full-smoke pass is made.

## Main budget

After the cutover:

- physical lines: 14,116
- nonblank lines: 12,280
- methods: 856
- top-level variables: 76
- constants: 110
- top-level preloads: 15
- external Main caller files: 102
- external Main caller occurrences: 1,598

The architecture budget is green and every Main metric touched by this change is monotonic.

## Next boundary

Re-run `TABLE_PRESENTATION_SOURCE_TARGET_CUTOVER`. It may now consume the typed public/private/map/log/Victory query ports without copying Main's world access into a replacement monolith.
