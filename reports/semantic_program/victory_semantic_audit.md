# Victory Semantic Audit

## Scope And Baseline

- Audit kind: read-only Victory domain audit.
- Worktree baseline: `bd24b463660e55d83fc63deaab650c64c134be20`.
- Observed `origin/main`: `59756a291f811a064726f59aed27efecc3590c9a`.
- Production code, tests, catalogs, rules, balance, RNG, save, and existing reports changed: **no**.
- Owned outputs: this report and `victory_semantic_audit.json` only.
- Line references and deterministic counts are frozen against the worktree baseline above.

## Executive Result

`VictoryControlRuntimeController` is the single live Victory owner and its core v0.6 state machine is sound. Preserve the existing four states, dynamic Top-K rule, independent 10-second qualification, sticky 120-second audit, post-settlement endpoint fence, exact three-key comparison, co-victory behavior, zero-RNG contract, and save section.

The semantic cutover is blocked by one product-authority conflict and four engineering boundary defects:

1. The rulebook requires broad public asset disclosure during audit, while the runtime contract and tests enforce cash-only disclosure. A product/rules authority must choose the canonical policy.
2. The internal outcome receipt contains every finalist's exact cash but labels itself `public` and is exposed through coordinator and AI paths.
3. the Victory owner and presentation receipt disagree on canonical region row field names, silently dropping progress facts.
4. outcome IDs are session-local sequence IDs while final-settlement log deduplication persists across sessions, allowing a later session's log to be suppressed.
5. Victory and GameSession save the same outcome independently, but restore preflight does not compare those receipts.

There are no localized victory-name rule branches and no RNG calls in the Victory owner or WorldBridge. The principal migration is therefore semantic ownership and projection, not a replacement rules engine.

## Current Authority Map

| Concern | Current authority | Disposition |
| --- | --- | --- |
| Static v0.6 Victory parameters | `SpaceSyndicateRulesetProfileV06` plus `clock_domain_registry_v06.tres` | Compile into `VictorySemanticSpec`; preserve exact values. |
| Live Victory state | `VictoryControlRuntimeController` | Keep as sole owner and existing state machine. |
| World facts | Domain owners, gathered by `VictoryControlWorldBridge` | Keep bridge non-owning; replace raw aliases with typed query ports. |
| Session lifecycle | `GameSessionRuntimeController` | Keep as the only owner of `finished`. |
| Public cash authorization | `VictoryControlRuntimeController` sticky audit roster | Keep unless the rules authority explicitly changes the privacy policy. |
| Public Victory projection | Victory public snapshot, then `VictoryPresentationStateChangeReceipt` | Move to one versioned DTO schema and fix field drift. |
| AI Victory features | `AiRuntimeController` directly interprets Victory dictionaries | Move facts to an authorized AI projection; keep strategic scoring AI-owned. |
| Final settlement | public source adapter, snapshot service, and composition | Consume a typed player projection; do not infer rules or privacy from raw keys/text. |
| Save | one `victory_control` section plus one `session` section | Preserve envelope/section order; add cross-section receipt validation. |
| Replay/exact-once identity | `victory.v06.<sequence>` and in-memory dedupe sets | Add session-scoped stable identity and a typed replay outcome record. |

## Preserved Rule Contract

The proposed semantic program must preserve these exact behaviors:

- region control requires at least 3000 basis points and a unique highest commodity-GDP contributor;
- `A` is the count of surviving, non-ruined regions;
- `K = max(1, ceil(A * 4000 / 10000))` when `A > 0`;
- required Top-K GDP is `K * 36 GDP/min`;
- GDP/control facts use the existing 30-second observation window;
- when `A == 0`, ordinary victory is paused rather than granted;
- each eligible player qualifies independently for 10 world-effective seconds;
- the first qualifier opens a sticky 120-world-effective-second audit;
- later qualifiers may join after their own 10-second window;
- roster membership remains sticky, but endpoint eligibility is re-evaluated;
- endpoint settlement requires `post_world_settlement` facts;
- comparison order is exact Top-K GDP cents, controlled-region count, exact cash cents;
- an exact three-stage tie is co-victory;
- last-survivor and explicitly authorized irreversible-planet-destruction outcomes remain available;
- the domain consumes no RNG;
- GameSession is finished only after Victory has produced a valid receipt.

## Static Semantic Definition Versus Live State

### `VictorySemanticSpec` Static Fields

Suggested identity: `victory.standard.dynamic_top_k`, schema version `1`.

Static semantic definition may contain:

- `schema_version`, `semantic_id`, `ruleset_id`, and deterministic `spec_fingerprint`;
- `region_control_threshold_bp = 3000`;
- `dynamic_coverage_bp = 4000`;
- `gdp_per_required_region_per_minute = 36`;
- `gdp_observation_window_seconds = 30`;
- qualification/audit timer policy IDs, resolving to 10 and 120 world-effective seconds;
- clock pause and save-remaining policies;
- sticky roster and late-join policy IDs;
- endpoint checkpoint requirement;
- comparison metric IDs and exact-tie policy;
- special-outcome declarations;
- visibility, randomness, and save-compatibility policy IDs;
- allowlisted condition and operation IDs.

It must not contain:

- current surviving-region count or current K;
- current GDP threshold, region controller, or candidate rows;
- player eligibility or qualification elapsed values;
- audit roster, audit remaining time, or pause reasons;
- exact cash, hands, assets, AI memory, or UI state;
- outcome sequence, outcome receipt, session lifecycle, Node, Object, Callable, or mutable owner references.

### Live Audit State

The following remain owned by `VictoryControlRuntimeController` and never become static spec data:

- current state: `idle`, `qualification`, `audit`, or `resolved`;
- per-player qualification elapsed map;
- sticky audit roster and remaining audit time;
- last world-derived candidates, player-private assets, dynamic rule, pause reasons, and settlement checkpoint;
- outcome sequence and immutable internal outcome receipt;
- advance/revision counters and fresh-world-fact cache state.

`A`, `K`, the current GDP threshold, region control, and finalist ranking are derived live from typed world facts. They are deterministic execution results, not authored catalog rows.

## Proposed Stable IDs

### Conditions

1. `victory.region.is_surviving`
2. `victory.region.gdp_positive`
3. `victory.region.share_meets_control_threshold`
4. `victory.region.unique_highest_contributor`
5. `victory.world.has_surviving_regions`
6. `victory.player.not_eliminated`
7. `victory.player.controls_required_region_count`
8. `victory.player.top_k_gdp_meets_threshold`
9. `victory.player.qualifies_continuously`
10. `victory.audit.endpoint_reached`
11. `victory.audit.post_world_settlement_checkpoint`
12. `victory.audit.finalist_still_eligible`
13. `victory.special.last_survivor`
14. `victory.special.irreversible_planet_destruction_allowed`

### Operations

1. `victory.evaluate_region_control`
2. `victory.derive_dynamic_top_k_threshold`
3. `victory.evaluate_player_eligibility`
4. `victory.advance_qualification`
5. `victory.open_public_audit`
6. `victory.join_public_audit`
7. `victory.advance_public_audit`
8. `victory.resolve_public_audit`
9. `victory.resolve_last_survivor`
10. `victory.resolve_irreversible_planet_destruction`
11. `victory.authorize_public_audit_cash`
12. `victory.emit_outcome_receipt`

### Handler Ownership

- `OperationHandlerRegistry` registers stable IDs and owns no Victory state.
- Region control, threshold derivation, eligibility, qualification, audit, and receipt handlers remain Victory-domain handlers owned or orchestrated by `VictoryControlRuntimeController`.
- `VictoryControlWorldBridge` becomes a typed fact assembler over domain query ports; it does not register mutation handlers.
- `GameSessionRuntimeController` consumes a typed committed Victory outcome and remains the lifecycle owner.
- presentation and AI projection services consume immutable semantic/results data and never dispatch Victory mutations.
- unknown condition, operation, visibility policy, timer policy, comparator, or special-outcome ID fails closed during semantic compilation.

## Three Projections

### Rules Projection

`VictorySemanticSpec + VictoryWorldFacts -> VictoryRuleExecutionPlan`

The plan carries typed current facts, derived A/K/threshold, candidate eligibility, timer intent, endpoint checkpoint status, comparison inputs, and expected owner revision. It invokes the existing state machine and must not own state or consume RNG.

### Player Projection

Suggested DTOs:

- `VictoryPublicProgressDTO`: state, current rule, public candidates, public timers, pause state, and roster;
- `VictoryAuditEntryDTO`: player identity, Top-K GDP, controlled-region count, and policy-authorized cash only;
- `VictoryOutcomePublicDTO`: winners, reason localization token, comparison labels, public rankings, and audit evidence;
- `VictoryViewerPrivateDTO`: the viewer's own candidate and explicitly authorized own assets.

The DTO, not Main/Standings/final settlement, decides field names and visibility. Localization maps stable token IDs to text.

### AI Projection

Suggested `AiVictoryObservation` fields:

- viewer/actor identity and authorization scope;
- public state, timers, current A/K/threshold, roster, and public ranking facts;
- own exact candidate facts and own private cash through the existing player-private authority;
- public audited cash only for authorized roster seats;
- derived gaps and `victory_progress` features;
- uncertainty markers when a comparator value is hidden.

AI strategy and personality continue to score these features. AI must not call the Victory owner directly, rebuild the canonical comparator, or receive the internal receipt. `AiOutcomeVector.victory_progress` may consume a privacy-safe typed final outcome; fixed AI values do not belong in `VictorySemanticSpec`.

## Save And Replay Contract

- Preserve the existing 19-section envelope, fixed section order, `victory_control` section, controller save schema 2, and GameSession save shape.
- Preserve fail-closed, whole-payload validation and fresh-world-fact rebinding after restore.
- Add a cross-section preflight dependency requiring the Victory and Session outcome receipts to be both empty or canonically identical when Session is `finished`.
- Do not save derived candidates, private asset caches, dynamic rule caches, or presentation data.
- Future new outcomes need a session-scoped identity, for example `victory.v06.<session_identity_hash>.<sequence>`. Existing saved IDs require a compatibility read path, not rewriting an old save.
- A typed replay event should carry session identity, ruleset ID, Victory spec fingerprint, operation ID, outcome ID, comparison inputs/result, and public/private visibility partitions. It must not create a second rules engine.
- The current replay test proves in-process reapplication idempotence only; it does not establish durable cross-session identity.

## Exact Findings

| ID | Class | Evidence | Finding and disposition |
| --- | --- | --- | --- |
| VIC-001 | KEEP | `scripts/runtime/victory_control_runtime_controller.gd:437-465`; `scenes/runtime/GameRuntimeCoordinator.tscn:328-332`; `scenes/runtime/V06SaveOwnerRegistry.tscn:162-170` | One live owner and one save binding. Preserve; do not add another Victory owner. |
| VIC-002 | KEEP | `scripts/rules/space_syndicate_ruleset_profile_v06.gd:18-24` | Six authoritative v0.6 Victory parameters have exact stable values. Compile, do not rebalance. |
| VIC-003 | KEEP | `resources/rules/clock_domain_registry_v06.tres:6-26` | Qualification and audit use world-effective clocks, pause in all four required cases, and restore remaining time. |
| VIC-004 | KEEP | `scripts/runtime/victory_control_runtime_controller.gd:85-132` | Region control uses exact GDP cents, 3000bp, and unique-highest semantics; tie/zero GDP yields no controller. |
| VIC-005 | KEEP | `scripts/runtime/victory_control_runtime_controller.gd:144-166` | Dynamic A/K and `K * 36` threshold are deterministic and pause at A=0. |
| VIC-006 | KEEP | `scripts/runtime/victory_control_runtime_controller.gd:169-257` | Candidate evaluation selects the highest K controlled regions and gates with exact cents and region count. |
| VIC-007 | KEEP | `scripts/runtime/victory_control_runtime_controller.gd:468-507` | Qualification is independent per player; the first qualifier opens audit and later qualifiers can join. |
| VIC-008 | KEEP | `scripts/runtime/victory_control_runtime_controller.gd:516-526`; `scripts/runtime/victory_control_runtime_controller.gd:640-643` | Audit roster is stable/unique; no-finalist completion returns directly to idle with no cooldown. |
| VIC-009 | KEEP | `scripts/runtime/victory_control_runtime_controller.gd:508-515`; `scripts/runtime/runtime_resolution_phase_coordinator.gd:33-39`; `scripts/runtime/runtime_state_commit_coordinator.gd:17-22`; `scripts/runtime/runtime_simulation_step.gd:103-112` | Endpoint waits for post-settlement facts; commodity flow finalizes before Victory and the lifecycle fence stops the frame after finish. |
| VIC-010 | KEEP | `scripts/runtime/victory_control_runtime_controller.gd:14-14`; `scripts/runtime/victory_control_runtime_controller.gd:527-533`; `scripts/runtime/victory_control_runtime_controller.gd:620-637` | Canonical order is exact Top-K GDP cents, controlled-region count, exact cash cents; exact tie yields co-victory. |
| VIC-011 | KEEP | `scripts/runtime/victory_control_runtime_controller.gd:281-304`; `docs/victory_control_runtime_contract.md:92-94` | Preserve last-survivor and explicitly allowed irreversible-planet-destruction semantics behind typed operation IDs. |
| VIC-012 | KEEP | `scripts/runtime/victory_control_runtime_controller.gd:306-360`; `scripts/runtime/victory_control_runtime_controller.gd:770-871`; `docs/victory_control_runtime_contract.md:72-82` | Current runtime public projection is cash-only and roster-authorized; viewer-private assets remain under `own_economic_assets`. |
| VIC-013 | KEEP | `scripts/runtime/victory_control_runtime_controller.gd:368-434`; `scripts/runtime/victory_control_runtime_controller.gd:874-938` | Save schema 2 validates before one state swap and clears world-derived caches after restore. |
| VIC-014 | KEEP | `scripts/runtime/victory_control_world_bridge.gd:46-126`; `scripts/runtime/victory_control_runtime_controller.gd:941-952`; `scripts/runtime/runtime_victory_port.gd:37-44` | Bridge is non-owning and payloads are pure data; core Victory has zero RNG API references; GameSession remains finish-state owner. |
| VIC-015 | MOVE | `docs/tabletop_rulebook_v06.md:141-148`; `docs/victory_control_runtime_contract.md:72-82` | Product authority conflict: rulebook exposes broad assets while runtime exposes exact cash only. Resolve before freezing `VictorySemanticVisibilityPolicy`. |
| VIC-016 | MOVE | `scripts/runtime/victory_control_runtime_controller.gd:548-571` | Internal rankings retain every player's exact cash but the receipt says `visibility_scope="public"`. Mark internal/controller-private and expose only typed projections. |
| VIC-017 | MOVE | `scripts/runtime/victory_control_runtime_controller.gd:364-365`; `scripts/runtime/victory_control_runtime_controller.gd:672-679`; `scripts/runtime/game_runtime_coordinator.gd:1177-1180`; `scripts/main.gd:2006-2012` | Internal and public outcome channels are mixed. Route the internal receipt only to typed commit/learning sinks; Main must consume public DTOs. |
| VIC-018 | MOVE | `scripts/runtime/runtime_victory_port.gd:37-44`; `scripts/runtime/game_runtime_coordinator.gd:1790-1805`; `scripts/runtime/ai_runtime_controller.gd:5071-5115` | AI receives the internal receipt, including exact cash. Replace with an authorized final AI outcome projection. |
| VIC-019 | MOVE | `scripts/runtime/victory_control_runtime_controller.gd:186-228`; `scripts/runtime/victory_control_runtime_controller.gd:789-801`; `scripts/presentation/victory_presentation_state_change_receipt.gd:16-24`; `scripts/presentation/victory_presentation_state_change_receipt.gd:155-175` | Owner emits `region_control_rows`/`commodity_gdp_share_basis_points`; presentation expects `region_shares`/`share_basis_points`, dropping canonical facts. Freeze one DTO schema. |
| VIC-020 | MOVE | `scripts/runtime/victory_control_runtime_controller.gd:828-866` | Public projection coerces integer `schema_version` to String. Preserve typed version identity in the projection compiler. |
| VIC-021 | MOVE | `scripts/main.gd:1937-1985` | Main directly interprets Victory state/timers and can recompute the dynamic rule through controller/world callbacks. Move all of this to PlayerProjection/query DTOs. |
| VIC-022 | MOVE | `scripts/main.gd:2015-2028` | Main owns localized rule/state copy and says audit exposes economic assets, contradicting cash-only runtime policy. Use stable localization tokens from PlayerProjection. |
| VIC-023 | MOVE | `scripts/runtime/standings_public_snapshot_service.gd:51-78`; `scripts/runtime/standings_public_snapshot_service.gd:95-112` | Standings hardcodes 30%, 10/120 seconds, comparator order, and rule prose. Project labels and values from semantic DTOs. |
| VIC-024 | MOVE | `scripts/runtime/ai_runtime_controller.gd:1296-1345` | AI calls public/private Victory owner APIs and reads raw candidate/rule/timer fields. Move to an authorized `AiVictoryObservation`. |
| VIC-025 | MOVE | `scripts/runtime/ai_runtime_controller.gd:1347-1373` | AI rebuilds canonical ranking and treats absent hidden cash as zero. Projection must provide visible order/uncertainty without inventing comparator values. |
| VIC-026 | MOVE | `scripts/runtime/ai_runtime_controller.gd:924-934`; `scripts/runtime/ai_runtime_controller.gd:3754-3792`; `scripts/runtime/ai_runtime_controller.gd:4177-4285` | AI duplicates state/timer/gap interpretation. Move facts and normalized gaps to AI projection; keep contextual strategy scoring in AI. |
| VIC-027 | MOVE | `scripts/runtime/victory_control_world_bridge.gd:77-100`; `scripts/runtime/victory_control_world_bridge.gd:133-146` | Bridge reads cash fallback aliases and card identity/family/name aliases from raw player dictionaries. Replace with typed cash and hand query ports. |
| VIC-028 | MOVE | `scripts/runtime/victory_control_world_bridge.gd:149-231` | Bridge parses facility, installation, inventory, and color-GDP owner shapes itself. Each source owner should project an audit facts DTO. |
| VIC-029 | MOVE | `scripts/runtime/victory_control_world_bridge.gd:234-300` | Bridge parses military UID/district and financial product/district aliases. Replace with typed owner projections without creating a world owner. |
| VIC-030 | MOVE | `scripts/runtime/victory_control_runtime_controller.gd:281-304`; `scripts/runtime/game_runtime_coordinator.gd:1073-1081`; `scripts/runtime/bankruptcy_neutral_estate_world_bridge.gd:122-127` | Special outcomes dispatch on caller-provided reason strings. Use allowlisted stable operation IDs and typed requests. |
| VIC-031 | MOVE | `scripts/runtime/runtime_victory_port.gd:37-44`; `scripts/runtime/game_runtime_coordinator.gd:1790-1805` | Normal and special outcomes have duplicated Session/AI/presentation commit glue. Route both through one exact-once typed commit sink. |
| VIC-032 | MOVE | `scripts/runtime/victory_control_runtime_controller.gd:368-379`; `scripts/runtime/game_session_runtime_controller.gd:197-210`; `scripts/runtime/v06_save_owner_registry.gd:356-389` | Victory and Session persist the same outcome, but cross-section preflight never validates equality. Add a dependency check without changing envelope shape. |
| VIC-033 | MOVE | `scripts/runtime/victory_control_runtime_controller.gd:63-69`; `scripts/runtime/victory_control_runtime_controller.gd:537-571`; `scripts/runtime/final_settlement_runtime_composition.gd:25-28`; `scripts/runtime/final_settlement_runtime_composition.gd:207-227`; `tests/main_victory_public_privacy_v06_test.gd:123-131` | Outcome ID resets to `victory.v06.1` each session while final-log dedupe persists and current replay coverage is only in-process. Add session-scoped identity and durable replay record. |
| VIC-034 | MOVE | `scripts/runtime/final_settlement_public_source_adapter.gd:18-57`; `scripts/runtime/final_settlement_public_source_adapter.gd:136-149`; `scripts/runtime/final_settlement_public_source_adapter.gd:175-207`; `scripts/runtime/final_settlement_public_snapshot_service.gd:177-201` | Final settlement maps raw aliases, reason codes, and comparator keys itself. Consume a typed `VictoryOutcomePublicDTO` and localization tokens. |
| VIC-035 | MOVE | `scripts/runtime/final_settlement_public_snapshot_service.gd:312-387` | Final privacy uses recursive key/text regex sanitization. Keep it fail-closed during migration, then replace inference with construction from allowlisted typed DTOs. |
| VIC-036 | REMOVE | `scripts/runtime/victory_control_runtime_controller.gd:188-194`; `scripts/runtime/victory_control_runtime_controller.gd:248-250`; `scripts/runtime/victory_control_runtime_controller.gd:548-552`; `scripts/runtime/victory_control_runtime_controller.gd:795-797`; `scripts/runtime/victory_control_runtime_controller.gd:838-840` | `top_n_gdp_per_minute` is emitted beside canonical `top_k_gdp_per_minute`. Remove after all consumers cut to the canonical DTO in one compatibility sunset. |
| VIC-037 | REMOVE | `scripts/runtime/standings_public_snapshot_service.gd:211-221`; `scripts/runtime/standings_public_query_port.gd:125-135` | Presentation still recognizes removed `cooldown` state and field. Delete after fixture migration; do not restore runtime cooldown. |
| VIC-038 | REMOVE | `scripts/runtime/standings_public_snapshot_service.gd:26-39` | Debug metadata still declares `victory_control_public_presentation_v05`. Remove/replace with the semantic projection version. |
| VIC-039 | REMOVE | `data/balance/runtime_balance_targets.json:21-31`; `scripts/balance/runtime_balance_parameters_resource.gd:30-40`; `scripts/balance/runtime_balance_parameters_resource.gd:184-188`; `scripts/balance/runtime_balance_model.gd:122-126`; `scripts/balance/runtime_balance_model.gd:428-456`; `scripts/balance/runtime_balance_model.gd:772-784` | Legacy depth-based cash-victory diagnostics contradict v0.6 Victory. Remove from active diagnostics without changing current economic numbers or runtime rules. |

## Deterministic Inventory

- Findings: 39 (`KEEP=14`, `MOVE=21`, `REMOVE=4`).
- Product/cutover blockers: 5 (one authority decision, four engineering boundaries).
- Victory controller: 952 physical lines, 49 methods, 17 fields, 12 constants.
- Victory WorldBridge methods: 20.
- Production Victory owner scene instances: 1.
- Victory save bindings: 1.
- Runtime states: 4.
- Timer policy IDs: 2.
- Comparator metric IDs: 3.
- Outcome reason IDs: 3.
- Static v0.6 Victory parameters: 6.
- Production source/scene/resource/data files matching the frozen Victory token scan: 47.
- Core Victory/WorldBridge RNG API references: 0.
- Core localized-name rule branch references: 0.
- Public receipt schema type coercions: 1.
- Victory/Session cross-section outcome equality checks: 0.
- Session identity components in outcome ID: 0.
- Final-settlement composition reset methods: 0.
- In the declared 12-file compatibility scan, `top_n_gdp` appears on 69 lines and `top_k_gdp` on 53 lines.

The 12-file compatibility scope is: Victory owner, AI owner, Standings query/service, three final-settlement files, Victory presentation receipt, table presentation viewmodel, full-run quality snapshot/driver, and Main.

## Blockers And Risks

| ID | Severity | Blocker |
| --- | --- | --- |
| VBL-001 | blocker/product | Choose broad audit disclosure from the rulebook or cash-only disclosure from the runtime contract/tests. No semantic visibility spec is authoritative until resolved. |
| VBL-002 | blocker/privacy | Internal receipts containing exact cash must stop claiming public visibility and stop flowing through untyped consumer APIs. |
| VBL-003 | blocker/projection | Canonical region progress fields are dropped by the current presentation allowlist mismatch. |
| VBL-004 | blocker/identity | Session-local outcome IDs can collide in persistent final-settlement dedupe and are insufficient for durable replay identity. |
| VBL-005 | blocker/save | Restore does not prove Victory and Session agree on the terminal receipt. |

Secondary risks are the large `top_n` compatibility surface, AI ranking with hidden cash treated as zero, regex-based privacy sanitization, and legacy cash-victory diagnostics. None requires changing balance, RNG order, or the existing state machine.

## Recommended Cutover Order

1. Resolve VBL-001 and freeze `VictorySemanticSpec`, visibility policy, condition IDs, operation IDs, and DTO schemas.
2. Add typed Victory world facts and fix the public projection field mismatch without changing live behavior.
3. Separate internal outcome receipt, public outcome DTO, and AI final-outcome projection.
4. Cut Main, Standings, AI, and final settlement to the typed projections.
5. Add session-scoped outcome/replay identity and Victory/Session save dependency validation.
6. Remove `top_n`, cooldown/v05 presentation residue, and legacy cash-victory diagnostics in an atomic compatibility cleanup.

## Source Fingerprints

| Source | SHA-256 |
| --- | --- |
| `docs/tabletop_rulebook_v06.md` | `ce15c1e13bce6b7d538dcce3f2e8df27d59449183329a464b7fc7908f746ace7` |
| `scripts/rules/space_syndicate_ruleset_profile_v06.gd` | `e555c0bf53ab61c73d3b789acb051b487a749ebc82fa02821e5f8a345ebb4f8a` |
| `resources/rules/space_syndicate_ruleset_v06.tres` | `b87e18d12aa29d7d5ad9b3b0d6d64100ab7c4aeeaa22ac869ce66c081560eae9` |
| `resources/rules/clock_domain_registry_v06.tres` | `cc6d111460f24f07496c62541acf49e42c8f2b73cc22fff105139894b2ddf34a` |
| `scripts/runtime/victory_control_runtime_controller.gd` | `7343c471d6c0bce7ea339c2586c296de9c0376bd7872103f64bb30e0215c67be` |
| `scripts/runtime/victory_control_world_bridge.gd` | `0150daf6ff7232b9dd837d4f574eaf42ced6b29015938b3a45a69693addd9d5b` |
| `scripts/runtime/runtime_victory_port.gd` | `018206053a58f006d4c35c35f2ee9bd06c3f17a97430147b4a09c6eb64532e0e` |
| `scripts/runtime/final_settlement_public_source_adapter.gd` | `c8140e94d65da4509ba8ea37b588df874cb20f9bb080c0e7f25624793ef67b3f` |
| `scripts/runtime/final_settlement_public_snapshot_service.gd` | `8fc2e91f05e39e574059e1a0eebbb48a71faa4ba6ca81d3dca361beece5311b0` |
| `scripts/runtime/ai_runtime_controller.gd` | `c4287cc4616d55cf3457816b4adaa3f0004df78046945be6c83caaff0c8daa13` |
| `scripts/balance/runtime_balance_model.gd` | `15b8eacb05bfb3a8113d17e08de859bb8d19d9c5c9b4f8f697c426954d32eba8` |
