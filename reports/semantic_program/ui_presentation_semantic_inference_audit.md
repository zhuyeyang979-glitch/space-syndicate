# UI / Presentation Semantic Inference Audit

Status: complete, analysis-only. This audit changes no production code, tests,
catalogs, rules, balance, RNG, save data, or pre-existing reports.

## Baseline and scope

- `origin/main`: `59756a291f811a064726f59aed27efecc3590c9a`
- audited integration baseline: `bd24b463660e55d83fc63deaab650c64c134be20`
- audit branch: `codex/semantic-program-wave1-ui-presentation-bd24b46`
- direct presentation files: 227
  - `scripts/ui`: 108
  - `scripts/presentation`: 48
  - `scripts/viewmodels`: 28
  - top-level UI/art adapters: 6
  - runtime presentation/snapshot/codex/query boundaries: 37
- upstream authority boundaries inspected: 20
- total unique production files inspected: 247

The direct scope is deterministic: all production `.gd` files under
`scripts/ui`, `scripts/presentation`, and `scripts/viewmodels`; the six
top-level UI/art adapters (`CardUI`, `GameScreen`, `HandLayout`, card art,
monster art, and map view); and runtime filenames matching presentation,
snapshot, viewmodel, codex, viewer/public query/source, selection catalog,
table-card-supply, or standings. The 20 upstream files are the exact catalog,
semantic, owner, diagnostics, inventory, purchase, history, weather, military,
monster, role, product, victory, and settlement providers reached by those
paths.

## Verdict

The repository now contains a sound strict target in `PlayerFaceDTOv1` and
`CardPlayerFaceProjectionService`, but it is not composed into production.
Its production consumer count is zero. The active card path still is:

```text
legacy/v0.6 dictionaries
  -> TablePresentationViewModelQuery or DistrictSupplyViewerQueryPort
  -> CardPresentationRuntimeService / CardViewSnapshot
  -> CardUI / RightInspector / market and track snapshots
```

That active path repeatedly interprets raw `kind`, raw skill fields, prose,
localized labels, and aliases. The same problem exists in narrower forms for
roles, monsters, products, facilities, military units, weather, victory copy,
and balance diagnostics.

This is not a recommendation to delete renderer state machines. Layout,
focus, paging, animation stages, token drawing, typed domain navigation, and
privacy scrubbers remain legitimate. Semantic inference must move before the
render boundary; the renderer should receive stable message references,
presentation tokens, and typed legal actions.

## Deterministic counts

| Metric | Count |
| --- | ---: |
| Grouped findings | 52 |
| `REMOVE` findings | 9 |
| `MOVE` findings | 30 |
| `KEEP` findings | 13 |
| Direct production presentation files | 227 |
| Upstream authority boundary files | 20 |
| Unique audited production files | 247 |
| Core alias-chain evidence lines | 22 |
| Direct raw `skill` read lines in direct scope | 8 |
| Files with direct raw `skill` reads | 4 |
| True card `effect_payload` reads in presentation | 1 |
| Production `PlayerFaceDTOv1` consumers | 0 |
| Localized/color/icon value observed flowing into rule execution | 0 |
| Localized text observed choosing a UI/navigation command route | 3 groups |

The three localized command/navigation groups are market quote action
selection, card-track lane/response/action synthesis, and menu-title routing.
They are behavior bugs even though no color value was found feeding the rule
engine.

## Finding registry

The JSON companion contains every evidence location as an exact `file:line`
entry. The following table lists the controlling evidence for each finding.

| ID | Class | Domain | Finding | Controlling evidence |
| --- | --- | --- | --- | --- |
| UISEM-001 | REMOVE | card | Core card adapters accept the 22-line cost/effect/type/rank alias chain. | `scripts/CardUI.gd:67`, `scripts/viewmodels/card_view_snapshot.gd:19`, `scripts/ui/right_inspector.gd:197` |
| UISEM-002 | REMOVE | card | Card Codex detail normalizes a second alias family into the legacy face shape. | `scripts/viewmodels/card_codex_detail_snapshot.gd:37`, `scripts/viewmodels/card_codex_detail_snapshot.gd:44` |
| UISEM-003 | REMOVE | card | Hand identity falls back to localized name, cost, type, rank, and array index. | `scripts/ui/hand_rack.gd:130`, `scripts/ui/hand_rack.gd:135` |
| UISEM-004 | MOVE | card | Table presentation merges legacy catalog, raw private cards, and a facility-only v0.6 adapter. | `scripts/presentation/table_presentation_viewmodel_query.gd:224`, `scripts/presentation/table_presentation_viewmodel_query.gd:632` |
| UISEM-005 | MOVE | card | Card presentation enriches raw skills and derives route, type, color, use case, facts, duration, and copy. | `scripts/runtime/card_presentation_runtime_service.gd:29`, `scripts/runtime/card_presentation_runtime_service.gd:451`, `scripts/runtime/card_presentation_runtime_service.gd:577` |
| UISEM-006 | MOVE | card | Resolution presentation dispatches animation, clue, radius, and style by raw kind. | `scripts/runtime/card_presentation_runtime_service.gd:267`, `scripts/runtime/card_presentation_runtime_service.gd:739`, `scripts/runtime/card_presentation_runtime_service.gd:838` |
| UISEM-007 | MOVE | card | `CardUI` synthesizes semantic chips and use cases from aliases and localized substrings. | `scripts/CardUI.gd:546`, `scripts/CardUI.gd:612`, `scripts/CardUI.gd:724` |
| UISEM-008 | MOVE | card | Right Inspector reinterprets timing, target, effects, visibility, keywords, and use case. | `scripts/ui/right_inspector.gd:193`, `scripts/ui/right_inspector.gd:261`, `scripts/ui/right_inspector.gd:287` |
| UISEM-009 | REMOVE | card | Card Codex resolves identity and rank from localized names and name suffixes. | `scripts/runtime/card_codex_public_source_service.gd:105`, `scripts/runtime/card_codex_public_source_service.gd:115` |
| UISEM-010 | MOVE | card | Card Codex projects player prose and raw machine target fields rather than `CardSemanticSpec`. | `scripts/runtime/card_codex_public_source_service.gd:195`, `scripts/runtime/card_codex_public_source_service.gd:212`, `scripts/runtime/card_codex_public_source_service.gd:243` |
| UISEM-011 | MOVE | card | Card Codex snapshot derives tactical timing, combos, and privacy hints from route labels and kind. | `scripts/runtime/card_codex_public_snapshot_service.gd:220`, `scripts/runtime/card_codex_public_snapshot_service.gd:232` |
| UISEM-012 | KEEP | card | `PlayerFaceDTOv1` is strict, versioned, pure-data, fingerprinted, and separates acquisition/activation cost. | `scripts/presentation/player_face_dto_v1.gd:161`, `scripts/presentation/player_face_dto_v1.gd:172` |
| UISEM-013 | MOVE | card | The strict player-face projector is an unwired migration bridge with zero production consumers. | `scripts/runtime/card_player_face_projection_service.gd:91`, `scripts/runtime/card_player_face_projection_service.gd:270` |
| UISEM-014 | MOVE | card | District supply merges legacy/public definitions and infers target/persistence/card facts. | `scripts/presentation/district_supply_viewer_query_port.gd:173`, `scripts/presentation/district_supply_viewer_query_port.gd:205`, `scripts/presentation/district_supply_viewer_query_port.gd:428` |
| UISEM-015 | MOVE | card/action | District supply computes purchase legality from quote, cash, hand, inventory, and catalog state inside presentation. | `scripts/presentation/district_supply_viewer_query_port.gd:244`, `scripts/presentation/district_supply_viewer_query_port.gd:278`, `scripts/presentation/district_supply_viewer_query_port.gd:300` |
| UISEM-016 | REMOVE | card/action | Market snapshot chooses command IDs from localized state labels. | `scripts/runtime/district_supply_snapshot_service.gd:457`, `scripts/runtime/district_supply_snapshot_service.gd:465` |
| UISEM-017 | MOVE | card | Market snapshot reconstructs play gates, targets, and persistence from flattened fields. | `scripts/runtime/district_supply_snapshot_service.gd:473`, `scripts/runtime/district_supply_snapshot_service.gd:597`, `scripts/runtime/district_supply_snapshot_service.gd:608` |
| UISEM-018 | KEEP | card/privacy | Public market downgrade and recursive private-field checks are valuable defense in depth. | `scripts/presentation/district_supply_viewer_query_port.gd:71`, `scripts/presentation/district_supply_viewer_query_port.gd:231`, `scripts/runtime/district_supply_snapshot_service.gd:676` |
| UISEM-019 | REMOVE | card/history | `PublicTrackSnapshot` is a second alias normalizer and infers owner/state/kind/accent. | `scripts/viewmodels/public_track_snapshot.gd:34`, `scripts/viewmodels/public_track_snapshot.gd:78`, `scripts/viewmodels/public_track_snapshot.gd:108` |
| UISEM-020 | MOVE | card/history | Card history query reads raw skill and independently formats category and target. | `scripts/presentation/card_history_public_query_port.gd:74`, `scripts/presentation/card_history_public_query_port.gd:98`, `scripts/presentation/card_history_public_query_port.gd:103` |
| UISEM-021 | REMOVE | card/history | Card resolution UI derives lanes and response visibility from Chinese state/phase text. | `scripts/ui/card_resolution_track.gd:143`, `scripts/ui/card_resolution_track.gd:531`, `scripts/ui/card_resolution_track.gd:627` |
| UISEM-022 | REMOVE | card/action | Game screen synthesizes track actions and fails open when drag legality fields are absent. | `scripts/ui/game_screen.gd:1521`, `scripts/ui/game_screen.gd:2066` |
| UISEM-023 | KEEP | privacy | Track and game-screen scrub guards remain useful after typed projection. | `scripts/ui/card_resolution_track.gd:393`, `scripts/ui/card_resolution_track.gd:489`, `scripts/ui/game_screen.gd:1568` |
| UISEM-024 | KEEP | renderer | Dedicated card/Codex/market controls are layout renderers when given prepared DTO fields. | `scripts/ui/card_codex_detail.gd:32`, `scripts/ui/card_codex_browser.gd:33`, `scripts/ui/district_supply_market_card.gd:34` |
| UISEM-025 | MOVE | art | Card art chooses frames, motifs, sprites, and military silhouettes from kind/name/tags/text. | `scripts/card_art_view.gd:257`, `scripts/card_art_view.gd:413`, `scripts/card_art_view.gd:933`, `scripts/card_art_view.gd:1156` |
| UISEM-026 | KEEP | renderer | Token-driven drawing and layout can remain once the token is authoritative. | `scripts/card_art_view.gd:506`, `scripts/card_art_view.gd:763`, `scripts/monster_art_view.gd:156` |
| UISEM-027 | MOVE | theme | Category/industry label, icon, glyph, and color maps are duplicated across four surfaces. | `scripts/runtime/card_codex_public_source_service.gd:7`, `scripts/runtime/card_presentation_runtime_service.gd:426`, `scripts/ui/table/top_commodity_sushi_track_item.gd:114`, `scripts/ui/district_info_panel.gd:4` |
| UISEM-028 | MOVE | product/theme | Map route color is inferred from legacy or Chinese product labels. | `scripts/ui/planet_map_view.gd:1374` |
| UISEM-029 | MOVE | action/theme | Action Dock derives accent from action-ID substrings, including localized text. | `scripts/ui/action_dock.gd:235` |
| UISEM-030 | REMOVE | navigation | Menu routing and shell state depend on localized page titles. | `scripts/runtime/menu_lifecycle_application_flow_controller.gd:167`, `scripts/runtime/menu_lifecycle_application_flow_controller.gd:343` |
| UISEM-031 | MOVE | role | Role Codex passes flat passive fields, then derives strategy routes, privacy, and opening advice. | `scripts/runtime/role_codex_public_source_adapter.gd:4`, `scripts/runtime/codex_public_snapshot_service.gd:212` |
| UISEM-032 | MOVE | role | Compendium assembles a legacy card face directly from role prose. | `scripts/presentation/compendium_readonly_query_port.gd:74`, `scripts/presentation/compendium_readonly_query_port.gd:87` |
| UISEM-033 | MOVE | role/art | Role portrait lookup is keyed by localized role name rather than stable role ID. | `scripts/presentation/role_portrait_catalog.gd:36`, `scripts/presentation/role_portrait_catalog.gd:49` |
| UISEM-034 | MOVE | setup/privacy | Setup snapshot carries the true AI starter-monster name beyond the privacy crop, although the current renderer hides it. | `scripts/runtime/new_game_setup_viewer_query_port.gd:83`, `scripts/runtime/new_game_setup_viewer_query_port.gd:85`, `scripts/runtime/new_game_setup_viewer_query_port.gd:117` |
| UISEM-035 | KEEP | role/renderer | Role identity board renders supplied cards, chips, KPIs, and route cards without rule mutation. | `scripts/ui/role_codex_identity_board.gd:18`, `scripts/ui/role_codex_identity_board.gd:46` |
| UISEM-036 | MOVE | monster | Monster Codex uses catalog index IDs and localized monster names for art/card joins. | `scripts/runtime/monster_codex_public_source_service.gd:93`, `scripts/runtime/monster_codex_public_source_service.gd:184` |
| UISEM-037 | MOVE | monster | Monster snapshot interprets raw ecology/action dictionaries into player-facing mechanics. | `scripts/runtime/monster_codex_public_snapshot_service.gd:13`, `scripts/runtime/monster_codex_public_snapshot_service.gd:89`, `scripts/runtime/monster_codex_public_snapshot_service.gd:139` |
| UISEM-038 | KEEP | monster/renderer | Bestiary and monster-art controls are renderers when supplied a public profile token. | `scripts/ui/bestiary_detail.gd:23`, `scripts/monster_art_view.gd:74` |
| UISEM-039 | MOVE | product/card | Product Codex recursively scans raw card `effect_payload` to infer related products. | `scripts/runtime/product_codex_public_source_service.gd:287`, `scripts/runtime/product_codex_public_source_service.gd:297`, `scripts/runtime/product_codex_public_source_service.gd:308` |
| UISEM-040 | MOVE | product | Product Codex mixes static profile, live market state, monster names, strategy copy, and UI styling. | `scripts/runtime/product_codex_public_source_service.gd:49`, `scripts/runtime/product_codex_public_source_service.gd:236`, `scripts/runtime/product_codex_public_snapshot_service.gd:23` |
| UISEM-041 | KEEP | product/compatibility | Localized product IDs are current cross-owner authority and must remain until a versioned save/RNG-safe migration. | `scripts/runtime/product_market_runtime_controller.gd:80`, `scripts/runtime/product_codex_public_source_service.gd:132` |
| UISEM-042 | MOVE | facility | Facility labels and summaries are reconstructed in UI/Codex from industry/type/owner/rank fields. | `scripts/ui/district_info_panel.gd:4`, `scripts/ui/district_info_panel.gd:57`, `scripts/runtime/codex_public_snapshot_service.gd:191` |
| UISEM-043 | KEEP | product/facility renderer | Product and region detail controls are prepared-data renderers. | `scripts/ui/product_codex_detail.gd:21`, `scripts/ui/region_codex_detail.gd:17` |
| UISEM-044 | MOVE | military | Military owner contains display label/glyph/motif/color maps and table map query calls them directly. | `scripts/runtime/military_runtime_controller.gd:182`, `scripts/runtime/military_runtime_controller.gd:193`, `scripts/presentation/table_public_map_query.gd:156` |
| UISEM-045 | MOVE | weather | Weather presentation duplicates definition-ID effect rows, icon keys, patterns, and raw effect-field interpretation. | `scripts/runtime/weather_presentation_runtime_service.gd:55`, `scripts/runtime/weather_presentation_runtime_service.gd:157`, `scripts/runtime/weather_presentation_runtime_service.gd:216` |
| UISEM-046 | MOVE | weather | Weather view models, telemetry, and two UI controls duplicate static IDs and phase/icon labels. | `scripts/viewmodels/weather_forecast_view_model.gd:10`, `scripts/ui/weather/weather_telemetry_buffer.gd:26`, `scripts/ui/weather/weather_forecast_strip.gd:294`, `scripts/ui/weather/weather_map_overlay.gd:202` |
| UISEM-047 | KEEP | weather/renderer | Forecast/overlay state validation and pattern drawing are legitimate renderer state. | `scripts/viewmodels/weather_forecast_view_model.gd:186`, `scripts/ui/weather/weather_map_overlay.gd:115`, `scripts/ui/weather/weather_forecast_strip.gd:55` |
| UISEM-048 | MOVE | victory | Standings presentation embeds rule prose and state labels instead of consuming `VictorySemanticSpec` message refs. | `scripts/runtime/standings_public_snapshot_service.gd:51`, `scripts/runtime/standings_public_snapshot_service.gd:73`, `scripts/runtime/standings_public_snapshot_service.gd:211` |
| UISEM-049 | KEEP | victory/privacy | Victory outcome receipt, ranking order, and dual cash-disclosure checks remain authoritative; UI does not recalculate winners. | `scripts/runtime/final_settlement_public_snapshot_service.gd:47`, `scripts/runtime/final_settlement_public_snapshot_service.gd:139`, `scripts/runtime/standings_public_snapshot_service.gd:181` |
| UISEM-050 | MOVE | diagnostics | Balance diagnostics independently read raw skills, infer routes/targets/ranks, and score card fields. | `scripts/runtime/gameplay_balance_diagnostics_runtime_service.gd:65`, `scripts/runtime/gameplay_balance_diagnostics_runtime_service.gd:112`, `scripts/balance/runtime_balance_model.gd:625`, `scripts/balance/runtime_balance_model.gd:1010` |
| UISEM-051 | KEEP | diagnostics/renderer | Developer balance panel and presentation target render prepared diagnostic snapshots. | `scripts/ui/developer_balance_panel.gd:9`, `scripts/presentation/developer_balance_presentation_target.gd:20` |
| UISEM-052 | KEEP | compendium/navigation | Stable domain-ID dispatch, layout selection, and pure-data rejection are legitimate state/navigation logic. | `scripts/presentation/compendium_readonly_query_port.gd:40`, `scripts/ui/codex_compendium_surface.gd:55` |

## Future DTO boundaries

There must not be one whole-game mega DTO. Each domain gets one unique
viewer-scoped player projection. All share a small envelope:

```text
schema_version
domain_id
viewer_scope_id
authorization_revision
definition_revision
runtime_revision (when dynamic)
identity
message_refs
presentation_token_ids
legal_actions (only from an action authority)
```

| Domain | Unique future boundary | Static input | Dynamic input | Consumers |
| --- | --- | --- | --- | --- |
| Card | `PlayerCardFaceDTO` (evolve `PlayerFaceDTOv1`) | `CardSemanticSpec` | authorized instance state and typed action candidates | hand, market, detail, Codex, public track |
| Role | `PlayerRoleCardDTO` | `RoleSemanticSpec` | public selected-role state only | setup, seat, Role Codex, portrait lookup |
| Monster | `MonsterCodexDTO` plus `MonsterTokenDTO` | `MonsterSemanticSpec` + `MonsterBehaviorSpec` | public roster state only | Bestiary, map tokens, wager/target UI |
| Product | `ProductCodexDTO` plus `ProductMarketRowDTO` | `ProductSemanticSpec` | public market/weather/route aggregates | Product Codex, economy, map, market |
| Facility | `FacilityPublicDTO` | `FacilitySemanticSpec` | public owner/rank/health/build state | region detail, market preview, map |
| Military | `MilitaryUnitPublicDTO` | `MilitaryUnitSemanticSpec` | public unit position/health/action state | map, card detail, combat presentation |
| Weather | `WeatherForecastDTO` | `WeatherSemanticSpec` | public weather event phase/timing | forecast strip, overlay, region/economy detail |
| Victory | `VictoryProgressDTO` and `FinalSettlementDTO` | `VictorySemanticSpec` | authoritative public/private victory receipts | standings and final settlement |
| Card history | `CardResolutionPublicPresentationDTO` | card semantic identity refs | sanitized public resolution receipt | track, inspector, Intel deep link |
| Diagnostics | `SemanticDiagnosticProjection` | all domain SemanticSpecs | explicitly authorized aggregate telemetry | developer balance tools only |

Visual colors, glyphs, icons, and illustrations are token IDs in the DTO.
Localization resolves stable message references after the viewer projection.
No renderer receives raw skills, `effect_payload`, hidden owner truth, or
mutable catalog dictionaries.

## Atomic cutover and deprecation sequence

1. Freeze the shared presentation envelope, stable message-reference format,
   and one theme-token catalog. Keep the current strict `PlayerFaceDTOv1` as
   the card starting point.
2. Establish typed semantic authority before UI migration: Role, Monster,
   Product, Facility, Military, Weather, and Victory specs must expose stable
   IDs and player-facing projection inputs. Do not parse prose to fill gaps.
3. Establish typed dynamic action sources. Purchase quote/receive eligibility,
   card play eligibility, track actions, and drag/drop actions must arrive as
   exact action candidates. Missing candidates fail closed.
4. Add each new projector beside the existing producer. Dual output is allowed
   only in tests/golden comparison; production chooses exactly one producer.
5. Cut static public consumers first: Card Codex, Role Codex, Bestiary,
   Product Codex, Region/Facility detail, Weather definitions, and Victory rule
   copy. These have the smallest viewer-state surface.
6. Cut dynamic public consumers next: public card track, map units, weather
   events, standings, and final settlement. Preserve existing scrubbers until
   typed privacy sentinel tests pass.
7. Cut viewer-private card consumers atomically: table hand, market quote,
   inspector, hover, and drag/drop. Definition, instance state, and legal
   actions must switch in the same commit.
8. Replace localized/index identity bridges with versioned stable IDs. Product
   IDs require save/RNG parity; role and monster IDs require save/checkpoint
   migration. Do not remove compatibility bridges early.
9. Redirect diagnostics to `SemanticDiagnosticProjection`; then forbid raw
   skill and payload reads outside compiler/handler/migration allowlists.
10. Delete `CardViewSnapshot`, core aliases, text-driven route selection,
    localized art inference, duplicate theme maps, and v0.4/v0.6 presentation
    fallback only after production caller counts reach zero.

## Privacy review

### Blocker-level risk

`NewGameSetupViewerQueryPort` correctly renders an AI starter monster as
anonymous, but its detached seat snapshot still contains the true value in
`monster_label`. Privacy must be cropped before the UI boundary, not merely
ignored by `NewGameSetupSeatCard`.

### Major risks

- District supply imports exact own cash and hand state into a presentation
  query and recomputes actionability. Keep private data in the action owner and
  export only an authorized action candidate/receipt.
- `CardViewSnapshot` and `CardPresentationRuntimeService` have no intrinsic
  viewer scope, so the same flattening adapter can be reused on public and
  private dictionaries.
- `PublicTrackSnapshot` trusts generic `owner_revealed` aliases. Current outer
  scrubbers are helpful, but the future projection must omit owner truth before
  this adapter.

### Preserved protections

- District supply downgrades unauthorized viewers to public browse.
- Codex adapters reject forbidden/private keys and objects.
- Card track and game screen retain recursive key/text scrubbers.
- Standings and final settlement require authoritative audit visibility plus
  the revealed-player set before exposing exact cash.
- Bestiary explicitly omits internal weights, random tickets, and preselected
  targets.

No path was found where a localized color/icon value flows back into rule
execution. Localized text does choose three UI/navigation routes and must still
be removed.

## Compatibility bridges

- Localized product IDs are current authority across market, routes, cards,
  world state, and saves. Keep them until a versioned `ProductSemanticSpec`
  migration proves save and RNG parity.
- Role portrait lookup and role navigation still use localized name/index.
  Keep until stable role ID migration is available.
- Monster Codex uses catalog indexes and localized names for art joins. Keep
  until stable monster family IDs exist in runtime/checkpoint data.
- The card compiler reports `256 active / 92 projection_only`. A player DTO may
  display projection-only cards, but it must not label them executable.
- Current privacy scrubbers remain after typed cutover as defense in depth.

## Blockers

1. `BLOCK-PLAYER-FACE-CONSUMERS`: strict card DTO has zero production consumers.
2. `BLOCK-LEGAL-ACTION-AUTHORITY`: market and drag/drop still synthesize
   actionability in presentation/UI.
3. `BLOCK-ROLE-SEMANTICS`: role passive rule authority is not established for
   all passive families; UI currently interprets flat fields.
4. `BLOCK-MONSTER-IDENTITY`: stable monster family identity is not universal in
   runtime/checkpoint data.
5. `BLOCK-PRODUCT-IDENTITY`: localized product IDs cannot be renamed without a
   versioned save/RNG migration.
6. `BLOCK-FACILITY-CATALOG`: no single immutable FacilitySemanticSpec catalog
   currently feeds region and market presentation.
7. `BLOCK-WEATHER-DUPLICATION`: effect rows and visual identity are duplicated
   across runtime presentation, view models, telemetry, and UI.
8. `BLOCK-PRIVACY-CROP`: true AI starter monster crosses the setup query
   boundary before being hidden by the renderer.
9. `BLOCK-LOCALIZATION-SOURCE`: the new card projector requires an authorized
   message source, but no production composition supplies it yet.

## Required scan gates

After each domain cutover, add or tighten gates so production UI/presentation:

- cannot read `effect_payload` or raw `skill` outside an explicit migration
  allowlist;
- cannot add any cost/effect/type/rank alias fallback;
- cannot parse localized names, labels, tooltip text, or colors to select an
  action, route, target, rule, rank, or handler;
- cannot enumerate private fields before viewer cropping;
- cannot compile semantics per frame or per render;
- cannot render an unknown semantic operation as executable;
- must receive stable message refs and presentation token IDs;
- must receive legal actions from the authoritative action/query owner;
- must preserve renderer-only layout, focus, animation, accessibility, and
  scrub behavior.

## Preservation statement

This audit did not change gameplay, rules, balance, RNG, save/replay shape,
catalogs, tests, production code, existing reports, or runtime composition.
No Godot run was required for a report-only audit.
