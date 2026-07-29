# Alpha 0.4-B current RightInspector responsibility inventory

Status: `AUDIT_COMPLETE_PRODUCTION_MIGRATION_NOT_STARTED`

Baseline: `origin/main` at `eef2465fcf61111b888581e1f6d209a5665c9407`
(`tree 20deb979920c72145b24e5a81a098e9fa0642cb4`). Measurements below use
tracked files from that tree only.

This is a current-production ownership inventory, not a deletion claim. The
fixed production `RightInspector` still owns all ten historical responsibility
rows. Alpha 0.4-A retired three narrower submission subpaths, but it did not
finish the typed presentation migration needed to remove any whole row.

## BEFORE hard counts

| Metric | Baseline value |
| --- | ---: |
| Historical responsibility rows | 10 |
| Fully retired rows | 0 |
| Partially retired rows | 2 |
| Alpha 0.4-A retired subpaths | 3 |
| `right_inspector.gd` lines | 502 |
| Production scene instances | 1 |
| Fixed inspector width | 292 px |
| `GameScreen` wrapper minimum width | 304 px |
| `game_screen.gd` matching lines | 49 |
| `right_inspector` symbol occurrences | 60 |
| Production dynamic `.call(...)` sites | 11 |
| `has_method(...)` guards | 11 |
| Signal connection lines | 2 |
| Snapshot top-level fields | 7 |
| Baseline test files referencing the inspector | 22 |
| Baseline test matching lines | 94 |

The seven generic snapshot fields are `title`, `why`, `district`,
`requirements`, `actions`, `logs`, and `deep_links`.

The eleven production dynamic calls in `GameScreen` are:

| Method | Count | Baseline lines |
| --- | ---: | --- |
| `set_context` | 6 | 184, 1262, 1571, 1582, 1789, 2066 |
| `show_public_player` | 1 | 608 |
| `show_public_commodity` | 3 | 984, 1102, 1159 |
| `show_card` | 1 | 1534 |

The two live outbound signals are
`action_requested(action_id: String)` and
`application_intent_requested(intent: IntelApplicationIntent)`. The first is
still a generic string dispatch surface. The second is typed, but is still
physically owned by the inspector.

## Alpha 0.4-A retirement boundary

Three subpaths are already retired and must not be reintroduced:

1. `RightInspector` card-play offers and dispatch. `GameScreen` filters
   `ACTION_CARD_PLAY` offers before `set_context`, dock detail is forced to
   `actions=[]` and `actionable=false`, and `PlayerCardDock` owns production
   card-play submission.
2. `RightInspector` commodity-claim action/button dispatch.
   `show_public_commodity` now projects `actions=[]`; the direct commodity card
   path owns `CommoditySushiTrackClaimRequest`.
3. Legacy `HandRack` card submission. `PlayerCardDock` owns production
   selection, hover, offer, target selection and submission. This is adjacent
   to the inspector inventory and therefore does not create an eleventh row.

The first subpath makes `action_dispatch` partially retired. The second makes
`public_commodity_detail_claim` partially retired. Read-only hand-card detail,
commodity detail/feedback, and all other non-card inspector responsibilities
remain live.

## Current responsibility-to-target map

| Responsibility | Source owner and current projection | Current scene target / signal | Privacy scope | Target surface and typed schema | Parity test | Deletion gate | Final status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `table_context_assembly` | `TablePresentationViewModelQuery` -> `GameTableViewModelRuntimeService._compose_right_inspector` -> `TableSnapshot.right_inspector` / seven generic fields | Whole fixed `RightInspector`; no dedicated assembly signal | Public context plus only the authorized viewer's private hand context | Typed contextual router using proposed `ContextualTableShellSnapshotV1` and existing per-domain snapshots; never a generic forwarding inspector | Card-presentation runtime, table-presentation parity, runtime composition and layout smoke; selected-hand/selected-track/fallback precedence must match | Remove `TableSnapshot.right_inspector`, `_compose_right_inspector`, `_hand_inspector` and `_track_inspector` only after all ten typed targets exist | `not_migrated` |
| `region_summary` | `_selected_district_source` -> `right_inspector.district.{title,summary,detail,full_detail,chips}` | `DistrictInfoPanel`; related actions currently leave through generic inspector routing | Viewer-safe public region/rack facts | `RegionSupplyPopup` + district drawer using `DistrictViewSnapshot`, typed district-supply query ports, and `RegionContextSnapshotV1` only if needed | Table-presentation parity, district-supply query/live-refresh and layout coverage; add mouse/keyboard/refresh field parity | New target owns every current district field; no district `set_context` or inspector fallback remains | `not_migrated` |
| `action_reason_requirements` | `_district_requirement_chips`, `_action_entries` -> `why`, `requirements`, action disabled state/tooltip | `InspectorReasonPanel` + `CurrentActionPanel`; generic action signal or typed Intel intent | Viewer-authorized legality/cost; rival-private availability and capabilities forbidden | `CompactCurrentActionSurface` / `ActionContextChipRow` using proposed `ActionContextSnapshotV1` plus `ActionDockSnapshot` / `GameActionOfferV1` | Table-presentation parity, semantic protocol and layout; cover valid/stale/unauthorized disabled-reason parity | Typed context and offer share viewer/session/revision; no generic inspector reads | `not_migrated` |
| `action_dispatch` | `_action_entries`, `_district_actions` -> `right_inspector.actions` -> inspector `ActionDock` -> `GameScreen` | `CurrentActionPanel`; `action_requested(String)` + `application_intent_requested(IntelApplicationIntent)` | Viewer-authorized offers/intents; tokens and private legality cannot cross viewers | `PlayerMainActionDock` and contextual owners using `ActionDockSnapshot`, `GameActionOfferV1`, `GameActionIntentV1`, `DistrictSupplyActionIntent`, `TableNavigationActionIntent`, `IntelApplicationIntent` | Alpha 0.4-A dock invariants/cutover, semantic protocol, navigation router and layout; one typed owner/dispatch per remaining action | Inspector signal connections are zero; `_game_action_entry` and `_action_label_for_id` have no inspector fallback; no card-play or claim duplicate | `partially_retired_not_migrated` |
| `event_feedback` | `recent_public_log_messages(6)` -> `right_inspector.logs` -> `_set_event_log` | `EventLogPanel/EventLogLabel`; input-only | Public event text only; private receipts/hidden card/rival state forbidden | `TypedToastSurface` + public event history using proposed `PublicEventFeedbackSnapshotV1` | Layout/UI snapshot coverage plus explicit latest/empty/order/stale/public-only tests | Typed public source owns latest toast and ordered history; all inspector log readers are zero | `not_migrated` |
| `deep_navigation_intel` | `fallback_deep_links`, `_hand_inspector`, `_track_inspector` -> `right_inspector.deep_links` | `InspectorDeepLinkRow`; generic string action or typed `IntelApplicationIntent` | Public navigation plus viewer-authorized Intel context | Destination-owned context buttons using `TableNavigationActionIntent`, `IntelApplicationIntent`, and `ContextualNavigationSnapshotV1` only if labels need projection | Navigation router, Intel cutover, card runtime and public-track selection; one typed route with stale/authorization checks | No generic dictionary-id buttons or inspector navigation signals/references remain | `not_migrated` |
| `hand_card_detail` | `_hand_card_sources` / `_hand_inspector`, then `_show_dock_card_details` -> read-only `show_card` | Full inspector stack; card actions intentionally suppressed | Authorized viewer's private hand only | `PlayerCardDock` hover/focus preview + `ContextDetailPopup` using `PlayerCardDockProjectionV1`, `CardCodexDetailSnapshot`, and `CardContextDetailSnapshotV1` only if private detail is not covered | Dock invariants/cutover, dock projection and card runtime; mouse/keyboard/full-detail/privacy parity with zero actions | All fields have one typed preview/detail owner; `show_card` and hand-derived `set_context` are zero; dock remains sole submitter | `not_migrated` |
| `public_track_detail` | `_card_track_source`, `_track_inspector`, `_track_entry_inspector_context` -> generic inspector context | Full inspector stack; typed selection receipt plus generic action and Intel paths | Sanitized public track facts only | Transient track-detail popup/focus ribbon using `PublicTrackSnapshot`, proposed `PublicTrackDetailSnapshotV1`, `TableSelectionIntent/Receipt`, Intel and navigation intents | Public-track focus/selection and real-interaction tests, focus order and layout; cover hover/refresh/stale/zero-gameplay/privacy | Delete track context/restore/sync functions; no track `set_context`; remove `right_inspector` source-surface allowlist entries after producer migration | `not_migrated` |
| `public_commodity_detail_claim` | Commodity focus/result paths -> ad hoc public item + viewer `action_result` -> `show_public_commodity(actions=[])` | Full inspector stack; input-only after Alpha 0.4-A | Public item facts plus authorized viewer's claim feedback | Commodity context near dock/track using `CommoditySushiTrackItemSnapshot`, `CommoditySushiTrackSnapshot`, `CommoditySushiTrackClaimRequest`, and proposed `CommodityContextDetailSnapshotV1` with typed viewer receipt | Dock invariants, direct claim, public-track interaction and commodity runtime; focus/refresh/stale/privacy/feedback parity with zero actions | Replace all three calls; typed viewer-bound result; inspector never regains claim action; tests retarget new surface | `partially_retired_not_migrated` |
| `public_player_inspection` | `PlayerSeatPublicSourceService` / `PublicPlayerSeatSnapshot` -> `_public_player_descriptor` -> `show_public_player` | Full inspector stack in `context_kind=public_player`; selection itself uses typed intent/receipt | Public identity/status only; rival cash, hand, plans and capabilities forbidden | Single-side roster + `PlayerInspectionPopup` using `PublicPlayerSeatSnapshot`, `TableSelectionIntent/Receipt`, and `PublicPlayerInspectionSnapshotV1` only if the popup needs a distinct contract | Actor-authority split, seat production, runtime composition and focus order; cover mouse/keyboard/controller/stale/privacy | `show_public_player`, metadata and focus-order references are zero; all inputs share typed selection; explicit no-cash/no-hand proof | `not_migrated` |

## Test ownership warning

The baseline has 22 test files and 94 matching lines that mention the physical
inspector. The strongest semantic gates are:

- `alpha04_player_card_dock_invariants_test.gd` and
  `alpha04_player_card_dock_production_cutover_test.gd` for read-only detail,
  zero duplicate card action and no inspector claim action;
- `public_card_track_focus_selection_cutover_test.gd` for one typed selection
  intent and zero gameplay intents;
- `public_track_real_interaction_test.gd` for commodity focus, refresh, stale
  rejection and privacy;
- `selected_player_actor_authority_split_test.gd` for public-only player
  inspection;
- `table_presentation_viewmodel_parity_test.gd` and
  `card_presentation_viewmodel_runtime_test.gd` for generic snapshot assembly;
- `main_runtime_composition_test.gd` and `layout_scene_smoke_test.gd` for the
  current physical node, scene ownership, layout and action routing.

Capture, visual and physical-presence assertions must be retargeted to the new
typed surfaces. They must not simply be deleted to make a zero-reference scan
pass.

## Atomic deletion gate

Production deletion remains blocked until all of the following are true:

1. Every responsibility row has a production typed target with viewer/session/
   revision and privacy parity where applicable.
2. The eleven production dynamic calls and two inspector signal connections
   are zero.
3. `GameScreen`, `TableSnapshot`, `GameTableViewModelRuntimeService`,
   `OverlayLayerSnapshot`, and production scenes no longer depend on the fixed
   inspector or its generic snapshot.
4. No forwarding inspector, dual writer, duplicate action owner, or generic
   string navigation substitute is introduced.
5. All three Alpha 0.4-A retired subpaths remain retired.
6. Layout, focus, interaction, stale-revision, authorization, capture and
   public/private privacy parity pass on the replacement surfaces.

Until that gate is satisfied, `RightInspector` remains a current production
owner and must not be reported as deleted or fully migrated.
