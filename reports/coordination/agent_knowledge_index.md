# Shared Agent Knowledge Index

Updated: 2026-07-14  
Owner: coordination thread only

This index contains reviewed lessons for future tasks. Source handoffs remain authoritative for detail.

## Runtime ownership

- A runtime domain has one business-state owner. Adapters may hold locks, reservations, CAS metadata, journals, and routing associations, but not a second copy of hands, cash, assets, commodities, facilities, units, or ownership truth.
- `CardPlayerStateProductionAdapterV06` is the sole v0.6 Card Flow production state port. Do not reintroduce `CommodityCardInventoryWorldBridge` or a parallel CardInventory v0.6 mutation entry.
- A new effect domain consumes the existing Card Flow transaction path; it does not instantiate another `CardFlowTransactionServiceV06`.

Sources: `agent_a_ss06_06_handoff.md`, `agent_b_core_economy_handoff.md`.

## Transaction lifecycle

- The required order is prepare -> authoritative effect commit -> player-state commit -> owner finalize.
- If player-state commit fails after an effect commit, compensation is successful only when the authoritative owner explicitly returns `rolled_back=true`.
- A false or missing rollback result is `compensation_failed`; never write `rolled_back=true` optimistically.
- Finalize closes the rollback window. Finalize and rollback route through the transaction-to-effect binding captured at prepare time, not an effect kind self-reported by a receipt.
- Readiness is capability-based and tested. Missing atomic rollback/finalize must fail closed before player resources commit.

Sources: `agent_b_core_economy_handoff.md`, `agent_a_ss06_06_handoff.md`.

## Commodity candidates and capacity

- Candidate enumeration uses current active production factories x legal matching market routes. Recent sale receipts supply player/product weighting, not the candidate universe.
- Allocation binds candidate ID, snapshot revision/fingerprint, endpoints, route, modes, distance, owner, product, and GDP weight.
- Validate both per-candidate capacity and aggregate shared-resource capacity, including pending batch occupancy.
- A candidate shown as available must be committable under the same authoritative route semantics, including local/direct routes.

Source: `agent_a_ss06_06_handoff.md`.

## Testing and evidence

- Focused tests prove only their named contract. A reference owner success path does not prove a production owner is connected.
- Preserve frozen baselines, but treat an assertion as stale when a downstream fix intentionally closes the gap it expected. Record the difference instead of restoring the defect.
- Current frozen evidence: Agent B core economy 438/438; combined SS06-06 focused chain 620/620; commodity inventory Bench 49/49.
- B's former `commodity_finalize_gap_reported_honestly` Bench expectation became stale after SS06-06 closed that gap; the shared tree may show 26/27 for that frozen Bench without indicating a regression.

Sources: `agent_a_ss06_06_handoff.md`, `agent_b_core_economy_handoff.md`.

## Shared Godot process discipline

- Multiple headless runs against one project can contend on import/cache locks and produce no useful output.
- Stagger focused suites, identify the owning thread before stopping anything, and leave the visible editor running unless its owner explicitly closes it.
- Runtime evidence should record scene, checks/failures, debug errors, stop finalErrors, and whether default `user://` was avoided.

Source: SS06-06/SS06-07 coordination observations.

## Hidden-information boundary

- Player-facing/public receipts must recursively exclude true/hidden owner fields, opponent exact cash, hands, discards, private route plans, AI scores, pressure buckets, and learning metadata.
- Machine fields and dev diagnostics may retain bindings and reason codes only outside player-facing UI.
- A privacy test scans nested dictionaries/arrays; checking only top-level keys is insufficient.

Sources: `AGENTS.md`, current SS06-07/SS06-08 contracts.

## Anonymous interaction and response windows

- Prepare-time `transaction_id -> effect_kind + route_domain + binding` is the only routing authority for commit, rollback, and finalize. Never trust a later receipt to choose its own owner.
- A counter response window and the incoming effect are separate lifecycles: resolve the window first, then decide whether the direct-player effect may commit.
- Phase negate applies only to field-tagged direct-player interaction and one response layer. Economy, autonomous monsters, weather, and ordinary map effects must reject it with zero side effects.
- Even when no eligible responder holds a counter, the state machine emits a replayable `no_eligible_responder` result instead of silently skipping the window.
- Response IDs prevent duplicate responses; transaction IDs prevent duplicate business mutations. Their journals are not interchangeable.
- Open windows must round-trip through save/load, while unresolved effect associations must block checkpoints. A top-level-only privacy filter is insufficient; sanitize and independently scan nested dictionaries and arrays.
- Existing Contract, Intel, and HandInteraction owners are not v0.6 production-ready merely because they expose plan/commit or public snapshots. They still need bound revision, rollback, finalize, exact-once, checkpoint, save/load, and privacy-safe capability evidence.

Evidence: SS06-08 focused tests 61/61, Godot 4.7 MCP Bench 8/8, public leaks 0, debug/stop errors empty. Source: `agent_c_ss06_08_handoff.md`.

## Monster and military card transaction adapters

- Unit-card bindings extend the outer Card Flow transaction/target/payload hashes with an immutable unit-intent fingerprint containing action kind and authoritative unit revision. UI selection state is not an acceptable substitute for the hashed target.
- A legacy bool mutation API is not an atomic capability. Real Monster/Military owners remain fail-closed until they expose revisioned prepare, commit, rollback, finalize, exact-once, checkpoint, save/load, and privacy-safe snapshots.
- A failed finalize keeps the authoritative committed receipt and blocks checkpoints, but must remain retryable. Only an explicit owner `finalized=true` closes the association.
- Reference owners are positive controls for the protocol, not proof that real rosters are connected. Production readiness requires both declared capabilities and actual methods.
- Unit public receipts use an explicit allowlist plus recursive sanitization, then an independent recursive leak scanner. Nested owner, cash, hand, AI, and raw fields are forbidden.
- The formal v0.6 catalog currently contains deploy/upgrade monster and military families; lure, bound monster skills, and reusable military commands require stable profiles before production routing. Legacy Chinese names or dynamic resources must not be treated as confirmed v0.6 entries.

Evidence: SS06-07 focused tests 187/187, Godot 4.7 MCP Bench 54/54, public leaks 0, debug/stop errors empty. Source: `agent_b_ss06_07_handoff.md`.

## Active lessons pending validation

- SS06-09: RegionInfrastructure must preflight every rollback binding and build next state on copies before one atomic swap. It remains pending until its handoff and focused evidence pass.
- SS06-11 candidate: Monster summon/upgrade should be the first real unit owner slice to gain an atomic lifecycle; autonomous movement/combat algorithms must remain unchanged and outside card transaction rollback.
- SS06-10 candidate: Contract offer/response state must gain its own atomic lifecycle before the interaction router can leave fail-closed production status. Contract state finalization is distinct from later economic side-effect settlement.
