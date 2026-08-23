# V0.7.6 Owner reuse map

schema_version: space_syndicate.v076.owner_reuse_map.v1

registry_id: V076_OWNER_REUSE_MAP

This map enforces one Owner per domain at candidate head
`174cbded0df3ef57fa7861276987f8e3a6e6f785`. Consumers may adapt data or
contracts, but they may not inherit authority by association.

| Domain | Unique Owner | Reused source | Disposition | Consumer boundary |
|---|---|---|---|---|
| Tick, execution order, Authority Sequence, Domain RNG, snapshot, outbox, replay | `V076DeterministicKernel` | Stage 1 plus Stage 3 Kernel V2 delta | `ADOPT_AS_OWNER` | No PR64 semantic registry, PR79 core, or adapter may create a parallel Kernel/RNG/tick loop. |
| Shared spherical partition authority | `V076SharedHalfEdgePartitionV1` | Stage 2 | `ADOPT_AS_OWNER` | V074 float geometry is presentation-only after exact mapping parity. |
| Responsive globe interaction presentation | `V076SharedHalfEdgePartitionBench` | PR #88 source `558cc110...`, head `82334b9b...`, merge `05c24150...` | `ADAPT_AS_CONSUMER` | Typed targeting/hit/rotate/zoom/collision/no-mutation patterns and tests only. V073 six-region float Voronoi is retired as authority; no controller copy and no Stage 2 replacement. |
| Stage 2 reducer ABI | `V076PartitionReducerV1` | Stage 2 reducer adapted at Stage 3 | `ADAPT_AS_CONSUMER` | Generator, topology, validator, and codec remain unchanged; sentinel is `90/90`. |
| Monster L1 geodesic movement | `V076MonsterL1ReducerV1` | Stage 3 isolated Owner extended by STEP09 production cutover | `ADOPT_AS_OWNER` | The same Owner now handles the production autonomy root batch and remains the only physical route/crossing/trample ledger. It owns no asset quantity, card catalog, target planning, facility HP, presentation, or second topology. |
| Current gameplay card definitions | `CardRuntimeCatalogService` | V04 root resource | `ADOPT_AS_OWNER` | Ten packs organize data only and are not Owners. |
| V06 semantic card source | `CardRuntimeCatalogV06Resource` | V06 resource + JSON | `ADOPT_AS_OWNER` | Semantic source does not replace V04 gameplay execution. |
| Semantic transform/cache | `CardSemanticCatalogService` | PR #62 compiler/schema | `ADOPT_AS_OWNER` | Deterministic transform only; not an executor. |
| Passive AI/PlayerFace projection | Existing PR #63 descendants | PR #63 | `ADAPT_AS_CONSUMER` | Viewer/privacy patterns only; no production AI or gameplay authority. |
| Private Direct Action input | `V076PrivateDirectActionInputOwnerV1` | PR #65 authorization pattern + V076 Kernel/half-edge + current catalog/assets/military + V075 mission, typed-damage, and source-bound private-skill paths | `ADOPT_AS_OWNER` | Owns only the authorized envelope, own-hand or source-bound revalidation boundary, exact-once submission/settlement ledger, source-collision rejection, and one common Kernel intake-root submission path for `MILITARY` and `MONSTER_SKILL`. It consumes sealed typed intents through existing sinks and owns no damage/HP, tick, Authority Sequence, RNG, skill state, military unit state, asset quantity, topology, presentation, or card catalog. |
| Military Profile authoring | `V076MilitaryUnitProfileAuthority` | V06 source identity/cost + twelve frozen V075 combat Profiles + V075 mission contract | `ADOPT_AS_OWNER` | One data authority owns 28 explicit Profiles: twelve inherited combat bindings, twenty-eight new speeds, and sixteen complete reversible V076 playtest Profiles. `V076MilitaryUnitProfileCatalogV1` is its read-only Adapter, not a card catalog. |
| Military card Crosswalk | `V076PrivateDirectActionInputOwnerV1` (unchanged) | `CardRuntimeCatalogV06Resource` + `V076MilitaryUnitProfileAuthority` + V075 mission contract | `ADAPT_AS_CONSUMER` | `V076MilitaryCardCrosswalkV1` is one read-only Adapter: 28 identities close, 28 exact-map, and 0 remain `REAUTHOR_REQUIRED`. It owns no source definition, numeric authoring, input ledger, movement, unit state, asset quantity, or presentation. |
| Military physical ETA | `V076MilitaryPhysicalEtaOwnerV1` | Profile-authored speed + canonical `V076SharedHalfEdgePartitionV1` geodesic distance through the existing integer metric adapter | `ADOPT_AS_OWNER` | Owns only integer distance plus speed to ETA ticks and a canonical receipt. It owns no tick, replay, map/topology/path, unit state, asset quantity, card catalog, authorization, attack, or presentation. |
| Military mission lifecycle phase ledger | `V076PrivateDirectActionInputOwnerV1` through registered `V076PrivateDirectActionReducerV1` | V076 Kernel derived-command ABI + Profile Authority + Physical ETA + V075 locked mission/withdrawal contracts | `ADAPT_AS_CONSUMER` | Records `ARRIVED`, `EXECUTED_ONCE`, and `WITHDRAWAL_READY` under the existing private-input Owner. Kernel alone assigns ticks/sequences and derives execute/withdraw commands; Profile owns combat values; existing unit/asset Owners alone settle quantity. No second lifecycle Owner or per-tick position state exists. |
| Current V075 facility combat settlement | `V075RuntimeOwner` | Existing V075 Facility bridge, processed ledger, witness ledger, fizzle journal, and presentation receipts | `ADAPT_AS_CONSUMER` | One narrow V076 entry consumes sealed facility intents. The existing Owner alone mutates facility damage/revision and records exact-once/fizzle evidence; no second facility damage Owner or ledger exists. |
| Current V075 source-bound monster private skill settlement | `V075RuntimeOwner` through existing `V075CombatRuntimeOwner` / `V075MonsterPrivateSkillCore` | Existing source/generation validation, owner-private skill zone, reservation, safe-boundary, effect, cooldown/Fizzle, privacy, and public-aftermath contracts | `ADAPT_AS_CONSUMER` | V076 only carries an authorized opaque bundle through the common Kernel intake root and consumes it in root Authority Sequence order. V075 remains the sole skill/asset/damage/safe-boundary authority; source-bound skills never enter `own_hand`, public batch, or sushi track. |
| Production Monster autonomy target and consequence consumption | Physical movement: `V076MonsterL1ReducerV1`; target plan and terminal consequence: existing `V075RuntimeOwner` lineage | Existing V075 autonomy target/detection plan + V076 Kernel/half-edge metric + existing V075 source/facility/presentation journals | `ADAPT_AS_CONSUMER` | V075 strips its historical production movement/trample receipt before settlement. One Kernel root batch drives V076 physical movement; the existing V075 Owner then consumes one terminal destination/trample result for source projection, facility HP, and presentation. No V075 production movement write, second route/trample/asset ledger, dual write, fallback, or presentation Owner remains reachable. |
| Current monster damage mutation | `MonsterRuntimeController` behind `RuntimeCommandPipeline` and `MilitaryMonsterDamageCommandSink` | Existing `SimulationMutationAuthority` path | `ADAPT_AS_CONSUMER` | Sealed monster intents dispatch only inside the active simulation step. The private-input Owner and reducer never mutate monster HP; replay/duplicate submission cannot damage twice. |
| Current V075 production six-color asset quantity | `V075RuntimeOwner` through existing `V07AssetBatchCore` state | Existing V07 balances, reservations, revision, and receipt journal | `ADAPT_AS_CONSUMER` | The production bridge settles the typed private-Direct-Action reservation in the same state after withdrawal and publishes one final existing player projection. The real GameScreen AssetRail consumes that projection; neither the Input Owner nor presentation owns or copies asset quantity. |
| Production military consequence presentation | Existing `V075RuntimeOwner` Presentation Owner | Closed terminal envelope from registered `V076PrivateDirectActionInputOwnerV1` + existing V075 public combat allowlist | `ADAPT_AS_CONSUMER` | The Input Owner builds one fingerprinted terminal envelope only after exact-once withdrawal. Existing V075 journals publish one assault and one withdrawal with canonical route SHA, integer distance, and ETA, then emit the existing player projection. Private card-instance identity is absent; replay is duplicate and adds no projection, presentation, or gameplay mutation. |
| Production AI action and viewer privacy | Existing `V075RuntimeOwner` through `V075CombatAIAdapter` and `V075CombatProjectionAdapter` | Existing V075 submission phase, actor-scoped AI observation, natural acquisition, legal action selection, queue/lock, public allowlists, viewer projections, and GameScreen consumption | `ADAPT_AS_CONSUMER` | STEP12 adds proof only. One AI naturally acquires, queues, and locks legal actions without hand/cash/target/result injection. It receives its own private facts plus detached public facts; local-human and rival-AI projections, public history/facts, and GameScreen expose no rival hand, queued plan, exact cash, or private binding. No second AI, policy, projection, privacy, cash, RNG, gameplay, or presentation Owner exists; PR63 remains passive patterns only. |
| Production Victory qualification and final audit readiness | Existing `V075RuntimeOwner` reusing `V07SolarVictoryCore` | Existing production qualification, audit-boundary revalidation, FinalSettlement, public-log, GameScreen presentation, terminal replay, and combat-quiescence paths | `ADAPT_AS_CONSUMER` | STEP13 adds readiness proof only. Real `main.tscn` progresses naturally from public new-game intent to one authoritative qualification/audit/settlement path without card, asset, or target injection. No second Victory, audit, settlement, winner, presentation, telemetry, RNG, tick, asset, card, target, or gameplay Owner exists; V06 `VictoryControlRuntimeController` remains production-unreachable. STEP13 human execution, confirmation, and observer attestation remain pending. |
| Current V075 production military card lifecycle | `V075RuntimeOwner` through the existing player DBG hand/discard state | Existing V075 authored card, hand-membership, and card-play lifecycle | `ADAPT_AS_CONSUMER` | The card instance is claimed while in flight, remains physically routed by ETA, and is consumed exactly once only after `WITHDRAWAL_READY`. The Direct Action Owner owns no card catalog or asset/unit quantity. `GUARD`, `PROTECT`, teleport, retarget, and persistent commands remain forbidden. |
| Production composition wiring | Existing Owners: `V076DeterministicKernel`, `V076SharedHalfEdgePartitionV1`, `V076MonsterL1ReducerV1`, `V076MilitaryPhysicalEtaOwnerV1`, `V076PrivateDirectActionInputOwnerV1`, and `V075RuntimeOwner` | Existing `V075RuntimeComposition`, `V075ApplicationFlow`, real `V075SampleGameScreen`, and one stateless `V076V075ProductionAdapterV1` | `ADAPT_AS_CONSUMER` | `scenes/main.tscn` reaches the existing V075 composition and one instance of each V076 Owner. STEP13-readiness candidate `174cbded` changes only its proof test, revalidates STEP09/11/12 at the exact candidate, and proves the unchanged `V075RuntimeOwner -> V07SolarVictoryCore -> FinalSettlement/GameScreen` path is ready for a future human run. No `GameRuntimeCoordinator`, V06 Victory controller, second asset/presentation/military/monster/map/Victory Owner, public-batch fallback, or dual write is connected. |
| Codex/PlayerFace presentation | `CardCodexPublicSourceService` | PR #66 current descendant | `ADOPT_AS_OWNER` | DTO/presentation aliases cannot become rules. |
| V07 track/DBG/assets/solar concepts | Their current domain descendants, behind V076 reducers | PR #79 | `ADAPT_AS_CONSUMER` | Requires V076 ABI/replay/RNG proof; no new public batch or second asset Owner. |
| Pure semantic adversarial patterns | V076 focused tests | PR #64 | `REUSE_AS_TEST` | Metadata registry stays non-executing. |
| Canonical adapter patterns | V076 adapter tests | PR #80 | `REUSE_AS_TEST` | No PR80 Save/RNG connection; V076 remains new-game-only. |
| Historical uninterrupted card batch | None | PR #70 closed/unmerged head | `RETIRED` | Never revive, rebuild, or whole-branch merge. |
| V075 combat source lineage | Existing `V075RuntimeOwner` PR #90 product lineage | PR #90 exact base | `ADAPT_AS_CONSUMER` | The same active V075 Owner is reused for production hand, asset, facility/monster damage, card lifecycle, privacy, Victory qualification/audit, FinalSettlement, and presentation. It is not superseded, copied, or dual-written; the V076 adapter is stateless and STEP13 adds proof only. |
| Human Golden observation evidence | `V073PlaytestTelemetryService` | Existing PR #87 instrumentation + existing V075 bootstrap + economy/combat/military Profile identities | `ADOPT_AS_OWNER` | The existing telemetry service is extended in place as the sole observation-package Owner. `V076Alpha07HumanGoldenCandidateProfile` and `V075ApplicationBootstrap` are stateless Adapters. The Owner writes only local observation artifacts and permanently reports `human_executed=false`, `human_confirmed=false`, `production_green=false`, and `human_green=false` until an independent human attestation exists. It owns no gameplay, Save, RNG, Tick, presentation, or balance values. |
| Full-run settlement acceptance | Unassigned future V076 end-to-end test Owner | PR #68 | `REUSE_AS_TEST` | Current Owner count is 0; V06 result is an oracle pattern, not V076 evidence. |
| PR90 release Probe Tooling | External sealed Tooling source | `70ccb5c0...` | `REFERENCE_ONLY` | Zero `tools/pr90*` files exist here; no copy, rewrite, replay, or Owner migration. |
| Future V077 Save/resume recovery | Unassigned pending new authorized implementation | Alpha 0.4-C representative `744b5418...` | `REFERENCE_ONLY_BLOCKED_UNVERIFIED` | `FORMAL_FULL_RUN=false`; official eligibility blocked. V076 is new-game-only with zero Save schema/delete/overwrite/migration changes; do not import coordinator/registry/barrier/flow or mix attempts. Tests may be reused only for V077. |

## Card source identities

- Gameplay root: `resources/cards/runtime/card_runtime_catalog_v04.tres`, SHA-256
  `a468dd4231906904f521232e4c58ee8882c4fa834f958c43438eeaf3338136a6`,
  230 definitions / 113 families.
- Semantic resource: `resources/cards/runtime/card_runtime_catalog_v06.tres`,
  SHA-256
  `5872ffc01a91860d697deb4fe23765c80feb5697e085b2873dd0872136fb04e8`.
- Semantic JSON: `data/cards/card_runtime_catalog_v06.json`, SHA-256
  `b59b73489d23578558d4a7688a03f50a3ef4d776cf528cd9eafd0e1d2a0fcb40`,
  348 cards / 87 families.

The 32 monster cards retain `UNVERIFIED` exact V076 mapping. Military mapping
is now `ISOLATED_GREEN_28_OF_28`: all 28 source identities, fingerprints,
Profiles, speed bindings, missions, costs, and lifecycle declarations close.
This does not certify production-green behavior or human play.

Stage 4 production-cutover evidence is bound to implementation tree
`ef76a8132a39fdbfdedf3965e2f358f4f1dc76a1`: the private Direct Action,
Profile, and ETA domains each have one Owner; the registered reducer adds one
three-phase ledger and two Kernel-derived continuations per mission. Sealed
facility and monster intents settle through their existing unique mutation
paths without supersession or a second Kernel/topology/catalog/asset/military/
damage Owner. The production gate exercises both legal missions `55/55` through
the cut-over V075 composition with exact asset/card settlement and withdrawal.
The cutover receipt binds `scenes/main.tscn` SHA-256 `1eaaf3b5...`; scripted
fixture evidence still leaves production green and human green false.

Stage 5 isolated evidence extends the same STEP10 Owner and reducer with one
common `submission_tick + 1` intake root for military and source-bound monster
skill actions. The V076 Kernel assigns the only cross-kind Authority Sequence;
V075 consumes skill bundles through its existing revalidation, reservation,
safe-boundary, exact-once, privacy, and public-aftermath contracts. The mixed
action focus test preserves A/B reverse-submit replay parity, duplicate and
collision rejection, hidden-info count 0, public-batch count 0, and sushi-track
count 0 over a 1,000-seed canonical probe matrix. No second channel, queue,
skill Owner, asset Owner, damage sink, Bench, or production composition is
introduced. This ordering proof remains inherited by the cut-over composition;
production and human green remain false.

Alpha 0.7 Human Golden observation readiness reuses the single production-
reachable `V073PlaytestTelemetryService` instead of creating another telemetry
or evidence Owner. One immutable profile Adapter fingerprints the existing
economy, V075 combat, and V076 military authorities; the existing V075
bootstrap configures it exactly once and fails closed on invalid identity.
Readiness passes `35/35`, V075 composition remains `111/111`, and the real
`main.tscn` MCP run stops cleanly. The generated package is observation-only
and cannot self-assert a human pass.

STEP09 binds implementation tree `330a83b9...`: production composition passes
`74/74`, the V075 production movement writer count is zero, one V076 Monster
Owner receives one Kernel root batch, physical crossing and trample reach the
existing facility/presentation consumers once, replay adds no second effect,
and production asset quantity writes remain zero. Monster L1 remains `47/47`
and the 1,000-seed/2,000-replay sentinel has zero mismatch. This is STEP09
`PRODUCTION_GREEN` only; full-product production green, human execution,
observer attestation, STEP12+, per-card certification, and full-world reproof
remain false or pending.

STEP11 binds implementation `1488399c` / tree `cd55e424` and the cumulative
asset-consequence receipt, which retains the immutable STEP09 receipt SHA-256
`22038a6a...`. Production composition passes `86/86` with the real V075
GameScreen. Region and monster missions each debit the existing asset Owner once,
emit one final projection consumed by AssetRail, and publish one assault plus one
withdrawal through the existing V075 Presentation Owner. The visible consequence
contains canonical route SHA, integer distance, and ETA but no private card
instance. Consequence replay adds no projection or presentation; presentation
gameplay mutation, new asset/presentation Owner, public batch, sushi track,
task-introduced warning, hard error, UID change, and residual process counts are
zero. This is STEP11 `PRODUCTION_GREEN` only; full-product production green,
human execution, observer attestation, STEP12+, per-card certification, and
full-world reproof remain false or pending.
