# V0.7 Three-Wing Semantic Architecture

## Status And Authority

This document describes a pure-data reference architecture for the frozen V0.7
target. The machine-readable authority is
[`v07_game_constitution.json`](../../rules/v07_game_constitution.json); the
human-readable companion is
[`v07_game_constitution.md`](../../rules/v07_game_constitution.md). If this
document conflicts with either authority, the frozen constitution wins.

Current production remains V0.6. This reference kernel is not connected to
production, does not dual-write state, and does not complete a V0.7 runtime
cutover. The constitutional cutover rule remains:

- `runtime_cutover_now=false`
- `v06_and_v07_dual_write=false`
- `atomic_owner_cutover_required=true`

The exact five-domain and six-contract registry is
[`v07_three_wing_domain_registry.json`](../v07_three_wing_domain_registry.json).
`GLOBAL_THREE_LAYER_COMPLETE` and `V07_PRODUCTION_CUTOVER_COMPLETE` both remain
false.

## Shared Contract Flow

Every domain uses one authoritative Core fact source:

```text
IntentV1 -> CoreAuthorityV1 -> AuthoritativeReceiptV1
                    |-> AiObservationV1
                    |-> PlayerProjectionV1
                    `-> SaveStateV1
```

- `CoreAuthorityV1` is the only mutation authority.
- `AiObservationV1` and `PlayerProjectionV1` derive from the same authoritative
  Core state and revision. A projection fingerprint covers that surface's
  allowlisted facts, so AI and Player fingerprints may differ when their
  privacy allowlists differ. Neither projection contains rule logic or can
  mutate Core.
- `IntentV1` is a revision-bound request, not authority.
- `AuthoritativeReceiptV1` is the exact committed outcome and idempotency fact,
  not a second command path.
- Each domain-local `SaveStateV1` persists enough authority state for its pure
  reference capture/restore/recapture roundtrip. It is not a second live
  authority and is never projected directly to AI or players.

All Core implementations are detached `RefCounted` or static pure-data code.
Their runtime authority ports are narrow transient `RefCounted` object bindings;
port and capability objects are excluded from SaveState and every projection.
The Cores contain no Node, scene, UI, Main, V0.6 Save Owner, or production
runtime dependency.

## Unified Card Track And Cycles

Contracts: `v07.unified_track.core_authority.v1`,
`v07.unified_track.ai_observation.v1`,
`v07.unified_track.player_projection.v1`, `v07.unified_track.intent.v1`,
`v07.unified_track.authoritative_receipt.v1`, and
`v07.unified_track.save_state.v1`.

`CoreAuthorityV1` owns the single mixed normal/commodity track, exclusive local
segments, six-color cycle, player stances, supply bags, frozen hidden-lead
order, and macro-round cursor. The reference implementation is
[`v07_unified_card_track_core.gd`](../../../scripts/v07_semantic/v07_unified_card_track_core.gd).

AI and Player consume the same public cycle facts plus the viewer's local
segment and pending stance. Only `PlayerProjectionV1` receives the private
`self_lead_notice` and nonnumeric notice token; `AiObservationV1` never receives
either field. Both exclude rival segments, future track and bag order, hidden
lead identity/order, raw influence weights, RNG state, and authority routing
fields.

Intents cover visible-card acquisition, legal color stance, and authoritative
cycle/track progression. Receipts expose committed public results without
supply order or hidden-lead data. Every accepted transition appends a closed
revision-lineage row containing the parent lineage hash, Intent fingerprint,
state-payload fingerprint, and new lineage hash. SaveState `state_version=2`
persists exact match identity, track, bags and bag cycles, projection revisions,
cycle/stances, lead order/cursor, processed-request authorization evidence,
revision lineage, and RNG cursors.

Visible commodity claims and normal-card purchases use the transient
`v07.unified_track.acquisition_authority_port.v1` with `cash`,
`personal_discard`, and `commodity_slot` participants. The port owns the pure
composite receipt journal. Save capture and restore are allowed only when Core
and port are quiescent: active, prepared, track-committed, externally
half-committed, or rollback-recovery transactions make capture fail closed.
Neither participant object identity nor the port object is persistent data.

RNG ownership is split across
`unified_track_type_draw`, `unified_track_color_draw`,
`unified_track_normal_card_draw`, `unified_track_commodity_draw`, and
`initial_hidden_lead_order`. Projection, hover, animation, Save capture, and
restore draw none of them.

## Personal DBG And Merge

Contracts: `v07.personal_dbg.core_authority.v1`,
`v07.personal_dbg.ai_observation.v1`,
`v07.personal_dbg.player_projection.v1`, `v07.personal_dbg.intent.v1`,
`v07.personal_dbg.authoritative_receipt.v1`, and
`v07.personal_dbg.save_state.v1`.

`CoreAuthorityV1` owns each player's ordered draw pile, hand, committed escrow,
discard, optional merge lineage, commodity inventory, bound-source lifecycle,
normal and commodity instance allocators, Intent/receipt journal, and two RNG
cursors. The reference implementation is
[`v07_dbg_deck_core.gd`](../../../scripts/v07_semantic/v07_dbg_deck_core.gd).

AI and Player receive the same owner-authorized hand, discard, capacity, and
legal-choice facts. A non-owner fails closed. Neither wing receives another
player's zones, any draw-pile order, shuffle state, receipt journal, or future
shuffle result.

Intents cover play, accepted purchase, commodity-slot acceptance, optional
normal/commodity merge, batch completion, and hand maintenance. A commodity
claim is prepared as the acquisition port's `commodity_slot` participant before
the Track commit and is finalized only against the authoritative Track receipt.
The binding accepts only the exact Unified Core script, pins explicit Track
`match_instance_id` plus its seed/roster lineage fingerprint, and forbids live
replacement by another object or lineage. Receipts identify the accepted
transition without raw card zones or owner-private payloads. Save persists every
ordered personal zone, both allocator cursors, merge/claim lineage, the bound
Track match/lineage, receipt journal, and RNG state. Restore clears the transient
Track authority and every in-flight reservation/commit cache; callers must
rebind a matching Track lineage before another claim.

`starter_deck_shuffle` and per-player
`normal_deck_reshuffle_by_player` are separate authoritative streams. Their
seeds, cursors, and resulting private order never enter AI or Player
projections.

## Six-Color Assets And Reservations

Contracts: `v07.six_color_assets.core_authority.v1`,
`v07.six_color_assets.ai_observation.v1`,
`v07.six_color_assets.player_projection.v1`,
`v07.six_color_assets.intent.v1`,
`v07.six_color_assets.authoritative_receipt.v1`, and
`v07.six_color_assets.save_state.v1`.

`CoreAuthorityV1` owns six independent capped balances, fixed-point remainders,
the frozen GDP cycle snapshot, full-queue affordability, and per-action
reservations. Assets and batches share one `ruleset_id="v0.7"` authority state
and one implementation file while remaining separate logical contract domains:
[`v07_asset_batch_core.gd`](../../../scripts/v07_semantic/v07_asset_batch_core.gd).

AI and Player receive the same viewer's exact assets, remainders, reservations,
and projected refresh. They never receive a rival's exact assets, remainders,
private reservations, or frozen GDP snapshot.

Intents reserve a complete local queue atomically, then finalize or refund each
action and apply the post-batch refresh. Window decisions use a validated
`v07.time.authoritative_attestation.v1` looked up through a transient authority
port; caller time is not trusted, and the monotonic
`window.time_observation_watermark_ms` is persistent authority state. Receipts
expose only the actor-authorized outcome and asset delta. Save persists balances,
remainders, GDP snapshot, reservation bindings/journal, refresh revision, and a
full shared authority copy that includes `intent_receipt_ledger`.

This domain consumes zero RNG. Future refresh cannot fund a current saved
reservation.

## Card Batch And Anonymous Resolution

Contracts: `v07.card_batch.core_authority.v1`,
`v07.card_batch.ai_observation.v1`,
`v07.card_batch.player_projection.v1`, `v07.card_batch.intent.v1`,
`v07.card_batch.authoritative_receipt.v1`, and
`v07.card_batch.save_state.v1`.

`CoreAuthorityV1` owns the 30-second one-shot window, at-most-five local active
actions, prebound targets, immutable local order, private owner bindings,
anonymous global queue, and hidden-lead layered resolution cursor. It shares
the pure implementation file linked in the asset domain, without merging the
two logical authorities.

AI and Player receive the same viewer's local queue and the same anonymous
public queue. They never receive rival source/target details, private owner
bindings, hidden lead order, authority queue records, or owner-specific timing,
audio, or animation clues.

Intents append/prebind, order, and lock local actions before resolution. During
resolution, no new gameplay or Counter intent is accepted. Receipts expose the
anonymous action outcome without owner identity. Save persists local queues,
prebound targets, reservations, private owner map, anonymous queue, layered
cursor, resolution journal, processed Intent identities, and the closed
`intent_receipt_ledger` binding each accepted Intent fingerprint to its receipt
and shared lineage.

The Asset and Batch SaveState surfaces are a transactionally paired contract.
Both carry identical `shared_batch_id`, `shared_lineage_fingerprint`, and
`shared_authority_state`. `restore_domain_save_state` validates one section but
never applies it; only `restore_domain_save_pair` may apply after both sections
preflight and match exactly. A lone or mismatched section fails closed.

Queue ordering is deterministic and consumes zero RNG.

## Solar Facility And Macro Victory

Contracts: `v07.solar_victory.core_authority.v1`,
`v07.solar_victory.ai_observation.v1`,
`v07.solar_victory.player_projection.v1`,
`v07.solar_victory.intent.v1`,
`v07.solar_victory.authoritative_receipt.v1`, and
`v07.solar_victory.save_state.v1`.

`CoreAuthorityV1` owns match/genesis lineage, solar phase/source revision, the
`2.0` sunlit and `1.0`
dark facility work-rate multipliers, pending Victory qualification, complete
macro-round boundary state, FinalSettlement identity, and exact-once receipt
ledger. The reference implementation is
[`v07_solar_victory_core.gd`](../../../scripts/v07_semantic/v07_solar_victory_core.gd).

The authority publishes two explicit, closed, authority-only state contracts:

- `V07SolarFacilityEfficiencyState` projects the solar source revision, phase,
  multiplier, four allowed facility work-rate channels, and the complete
  constitutional non-effect list.
- `V07MacroRoundVictoryGateState` projects pending qualification, all six
  boundary requirements, FinalSettlement identity/count, processed Intents,
  and the exact-once receipt ledger.

Both carry the same Core revision and fingerprint. They are detached snapshots,
not additional authorities, and neither contract is exposed wholesale through
AI or Player projections.

AI and Player receive the same public solar phase/multiplier, pending flag,
macro-round index, and settlement status. They do not receive the pending
condition identity, trigger Intent, receipt ledger, or hidden lead facts.

Intents set Core solar state, submit inherited Victory qualification, and
revalidate at the complete macro-round boundary. Qualification and boundary
proofs are accepted only through a transient external `RefCounted` lookup port
whose canonical authority/source IDs, issuer instance, opaque capability object,
and exact current source revision all agree. Pending state persists logical
issuer/source identity and proof revision, never the port or capability object.
Failed revalidation clears pending state; successful revalidation commits
FinalSettlement exactly once. Every committed receipt contains the exact Intent
payload, predecessor receipt fingerprint, source/result state fingerprints,
proof issuer/source identity, and a sealed receipt fingerprint, forming a
deterministic chain that coordinated outcome resealing cannot replace. Save
section version 3 persists the complete authority state and receipt chain. All
integer fields are recursively tagged on the wire and must decode to true
integer values; floats and malformed or noncanonical tags fail closed. The
FinalSettlement rollback barrier remains irreversible.

This domain consumes zero RNG. Solar affects declared facility work-rate
channels only; card supply, track distribution, and card price remain unchanged.

## Save, Restore, And RNG

All five domain-local `SaveStateV1` surfaces are executable pure-reference
contracts. Unified, DBG, and Solar capture/restore/recapture exact local state
with zero RNG advance. Asset and Batch capture separate projections of one
shared authority; each section provides preflight only, and their executable
roundtrip uses paired domain restore. None is a production adapter.

The future atomic-cutover persistence contracts are:

- [`v07_save_schema.json`](../../save/v07_save_schema.json): five closed Save
  sections, privacy-at-rest classes, tagged Int64 fields, and cross-section
  invariants.
- [`v07_restore_dependency_graph.json`](../../save/v07_restore_dependency_graph.json):
  all-preflight-before-apply, checkpoint, reverse rollback, and one atomic
  detached commit.
- [`v07_rng_ownership.json`](../../save/v07_rng_ownership.json): seven dedicated
  stream owners, exact seed/cursor fields, and zero-draw observation/restore
  rules.

`v07_save_schema.json` is the canonical envelope contract for a future atomic
V0.7 owner cutover. No adapter currently combines the five local SaveState
surfaces into that envelope, and no production Save/Continue path consumes it.
The implemented local and paired roundtrips therefore prove domain contract fidelity, not
canonical-envelope integration or production restore readiness.

V0.6 saves cannot load directly as V0.7. Restore advances no RNG, world time,
AI action, player action, public log, economic reward, or gameplay receipt.
Private Save fields never become Player or AI projections.

## Zero Production Connection

The reference architecture has no connection to:

- `scripts/main.gd` or `scenes/main.tscn`
- `GameRuntimeCoordinator`
- `V06SaveOwnerRegistry` or any V0.6 Save Owner
- V0.6 RuntimeLoop, AI policy, Player Card Dock, or production action routing
- production Node/scene composition or any old/new dual-write path

`V07_PRODUCTION_RUNTIME_CONNECTION_COUNT=0` and
`CANONICAL_ENVELOPE_ADAPTER_STATUS=NOT_IMPLEMENTED`. Production remains V0.6
until a future task revalidates this reference kernel against then-current
`main`, implements the canonical adapter, and performs one atomic owner
cutover.

The executable contract gate is
[`v07_three_wing_contract_aggregate_test.gd`](../../../tests/v07_semantic/v07_three_wing_contract_aggregate_test.gd).
It loads all five logical Core domains, calls all six contract surfaces through
their declared domain entrypoints, compares exact IDs and fields with the
registry, proves local Save roundtrips and zero RNG advance, parses all four
JSON contracts, checks privacy deny-lists, and rejects Main/V0.6 production
dependencies.
