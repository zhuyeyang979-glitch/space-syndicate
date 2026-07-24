# AI Runtime Ownership Contract

## Current Boundary

`AiRuntimeController` is the only runtime owner for AI state, personality policy, candidate generation, scoring, ranking, tie-breaks, fallback order, turn plans, response plans, learning records, and AI save/load data.

`AiRuntimeWorldBridge` is physically deleted. `main.gd` and
`GameRuntimeCoordinator` expose no arbitrary AI method-name or `callv` gateway.
The production scene composes explicit query/command ports and binds concrete
domain events directly to `AiRuntimeController`.

ProductMarket cycle completion and Monster wager opening are typed events. The
market event preserves the existing business-action then reward-finalization
order. The wager event carries the stable wager ID plus settlement revision;
each AI response carries a deterministic command ID and expected revision to
the existing Monster owner. Neither event contains an actor-private snapshot,
method name, Node, Callable, save payload, or Main fallback.

## Policy Source

The runtime policy source is `res://resources/ai/ai_policy_profile_v1.tres`. Its `runtime_owner_script` is `res://scripts/runtime/ai_runtime_controller.gd` and `runtime_cutover_enabled` is `true`.

The existing AI-only anonymous business action remains an active internal
economic policy. Its `price_pump` action costs exactly 90 cash units (9000
cents). That cost belongs to the policy Resource, not `main.gd`, UI copy or a
request-supplied value. The value, trigger chance, per-cycle cap, candidate
ordering, market effect and RNG order are frozen by the typed-cash cutover.
Committed monster-wager cash is unavailable to this ordinary operating cost.
Every typed cash request binds a SHA-256 fingerprint of the cost term. A
decision-only QA policy may change trigger chance without changing cash
authority, while any cost drift is rejected before cash mutation and rolls the
reversible market/RNG participant back.

There is no `main.gd` AI constant or personality-catalog fallback. Resource load or validation failure leaves the controller unconfigured and reports an explicit error.

## Preserved Behavior

The migrated functions retain their current v0.6 call order. This includes card play and purchase candidates, auction/counter decisions, automatic conditional-order evaluation, intel, monster wagers, military, weather, city/product/route/monster strategy, online learning, and public audit reports.

World legality and mutation remain with their existing owners. The controller
uses narrow typed ports and concrete owner APIs; it does not duplicate card,
economy, city, route, monster, military, weather, contract, queue, or execution
rules.

## City Inference Typed-Port Boundary

AI city ownership inference is the first production consumer migrated from the
generic bridge to the foundation ports. `AiRegionKnowledgeQueryPort` returns
detached actor-scoped public region facts plus only that actor's private city
inference. The composition root issues one opaque capability per AI seat and
reissues it after roster replacement, session change, or restore.
`AiCityInferenceCommandPort` authorizes the same actor-bound capability plus a
stable, revision-bound, exact-once command before delegating the mutation to
`WorldSessionState`.

The region projection exposes warehouse count, units, and product names only
when the city belongs to the requesting actor. Public and rival city rows omit
all warehouse fields, along with warehouse owner, bucket and source identifiers,
transaction lineage, debt, liability, expiry, rival cash, rival hand, hidden
city owner, and rival inference. A city owner appears only for the actor's own
city, that actor's own guess, or a previously authorized reveal.

The query and command ports consume no RNG and do not own save data. Guess,
confidence, and reason remain in `WorldSessionState` and continue through the
existing session envelope v2. The generic bridge city-guess mutation and Main's
city-inference constants are deleted with no fallback. Other AI domains remain
on the generic bridge until their own atomic cutovers; this section is not a
claim that the parent P0 is complete.

## Actor Economy Typed-Port Boundary

`AiActorEconomyQueryPort` combines four existing authorities without storing a
second copy: exact signed cash from `WorldSessionState`, wager-reserved and
available cash from `MonsterWagerCashCommitmentQueryPort`, actor-owned city
economy facts from `WorldSessionState`, and actor-owned futures from
`ProductMarketRuntimeController`. The composition root issues one opaque token
per current AI seat and no token to human seats.

Spending decisions use available cash after unresolved wager commitments;
learning observations use the exact signed total. Public futures remove owner,
position, source-card, margin, warehouse-identity, and settlement-internal
fields. Existing anonymous warehouse product/count/unit clues stay public, but
they never include hidden owner truth or private bucket/source lineage.

The port is a detached pure-data query with zero mutation, RNG, log, save dirty,
or Main dependency. It adds no owner or save section. Broad ProductMarket,
CommodityFlow, route, and district consumers remain pending their dedicated
typed-port boundaries.

The AI controller has no whole-player collection property or indexed player
read/write. Counts and public seat facts come from `AiActorStatePort`; private
progress counters come from `AiActorEconomyQueryPort`; own-hand capacity comes
from `AiCardHandQueryPort`. Runtime compatibility defaults are authored in the
deterministic new-session plan before `WorldSessionState` applies the roster,
not patched into live players by AI.

## Market And Route Public Query Boundary

`AiMarketPublicQueryPort` consumes only the complete 46-entry public market
projection. It fail-closes instead of calling `ensure_catalog()`, so AI reads
cannot generate prices, mutate market state, or advance RNG. Product entries
use a strict allowlist and anonymous futures omit actor, source-card, margin,
warehouse-identity, and settlement-internal fields.

`AiRoutePublicQueryPort` consumes only the Route owner's cached public
projection. Public route rows carry stable route and region IDs, mode tags,
distance, transfer count, bottleneck, and efficiency. Facility IDs, capacity
resource IDs, rent recipients, expected rents, and topology fingerprints stay
inside the owner. Querying does not refresh topology or consume weather RNG.

AI market scoring no longer receives ProductMarket's private runtime snapshot,
and route scoring no longer receives raw route candidates. The existing typed
market mutation transaction and all other domain owners are unchanged. These
Ports add no state or save section.

## Actor-Scoped Region Consumer Boundary

AI production code has no whole `players` or `districts` collection access.
District count, public rows, actor-scoped city facts, active-region iteration,
and city inference all come from the existing typed ports. A rival city owner
is never inferred from hidden world truth: the projection returns the actor's
own inference or an unknown sentinel.

Public city route evidence is intentionally narrower than the Route owner's
row: count and active/disrupted product names only. Raw route dictionaries and
their facility, owner, rent, capacity-resource, and topology fields remain
inside their owners. Per-city warehouse count, units, and products are
actor-private and appear only for the owning AI seat. Market-level anonymous
aggregates do not authorize access to a rival city's warehouse facts.

Removing the previously exposed rival warehouse inputs is a documented
`PRIVACY_CORRECTION`. Policy weights, personality data, and RNG use remain
unchanged; only scores or ordering that previously depended on those forbidden
inputs may differ.

## Actor-Private State Typed-Port Boundary

`AiRuntimeController` remains the semantic owner of the six personality
definitions, AI learning memory, candidate behavior, and checkpoint meaning.
`WorldSessionState` remains the sole owner of the player records that contain
`ai_profile` and `ai_memory`. `AiActorStatePort` is a stateless capability gate
between them; it must never become a second player or AI-state owner.

The public actor query contains only public seat, role, and elimination facts.
The private AI query requires the exact opaque capability and returns only the
requested actor's profile and memory plus public context. It excludes cash,
hand/slots/discard, action cooldown, city inference, rival AI state, Nodes,
Objects, Callables, and mutable world collections. Queries are detached,
read-only, and consume no RNG.

Profile/memory mutation uses compare-and-swap. Its revision binds actor index,
restore epoch, profile, and memory; stale or pre-restore writes fail closed.
The exact patch allowlist is `ai_profile` plus `ai_memory`, and nonfinite or
retired-contract payloads are rejected. Strategy and route-plan consumers must
re-read the actor snapshot after nested memory updates before their final CAS.

AI checkpoint capture/apply uses a preflighted batch. Every row is authorized,
validated, and revision-checked before one replacement players array is
assigned. A typed capture receipt distinguishes zero AI from capture failure,
and apply requires the saved actor-index set to equal the current AI roster.
`AiRuntimeController` retains its existing timer and `player_states` save
shape, and timer fields change only after the actor batch succeeds. Its
new-session rollback checkpoint contains only controller-local timers and
receipts; `WorldSessionState` restores profile and memory at the world rollback
stage. No
Registry section or schema is added. The existing formal `ai` section remains
unsupported until its own Save Owner task, so this boundary does not establish
full-run resume.

AI business cost mutation must use `AiBusinessCostCashPort`, the existing
`MonsterWagerCashCommitmentQueryPort`, and `PlayerCashMutationPort`. The market
effect must use `ProductMarketRuntimeController`'s synchronous
prepare/commit/finalization-seal/rollback/finalize lifecycle. No business-cost path may call Main
or write `WorldSessionState.players` directly.

## Actor-Scoped Card Eligibility Boundary

`AiCardEligibilityQueryPort` is the only AI-facing entry for card eligibility,
requirement status, and best-share targeting. It owns no card or world state and
delegates legality to the existing `CardPlayEligibilityRuntimeService` using
the shared typed fact provider. Wager-reserved cash remains authoritative and
AI queries use `PlayerManaRuntimeController.availability_snapshot_read_only()`
so an inspection cannot create Mana state.

The composition root issues one opaque token per current AI seat. Roster or
GameSession identity replacement reissues every token; old, forged, rival, and
human tokens fail before facts are collected. The stable session binding omits
save operation sequence and pause/outcome state, so save bookkeeping cannot
invalidate a live actor accidentally.

AI target context is explicit. `-1` means no region and never falls back to the
human table selection. The response is a detached receipt and never contains
raw players, districts, queue rows, share tables, owner truth, or mutable
runtime objects. This boundary adds no Save Registry section.

Best-share parity is `share basis points`, then public region GDP/min, then the
earliest district index. It must not be replaced with the historical bridge's
share-only tie break.

## RNG Contract

The controller receives the scene-owned `RunRngService` through explicit scene
composition. It never constructs a second RNG. Migrated function bodies
therefore consume the same generator in the same decision order. Save version
1 continues to persist the world RNG state in its existing envelope.

## Privacy Contract

AI plans, opponent-hand knowledge, hidden owners, private targets, private discards, and learning samples may exist in controller-private state or save data. They must not appear in public debug snapshots, UI snapshots, QA manifests, reports, or typed domain events.

`debug_snapshot(-1)` exposes only controller readiness, policy identity, timer state, AI count, receipt count, shared-RNG status, and aggregate typed-event counters. Domain events and public receipts omit AI plans, scores, private cash, hidden owners, and decision samples.

## Deletion Gate

The hard cutover is invalid if `main.gd` again defines any non-adapter `_ai_*`, `_auto_ai_*`, `_update_ai_decisions`, `_record_ai_decision`, or `_finalize_ai_*` function, or restores an AI policy constant/catalog copy.

Focused QA is the expanded `AiPolicyResourceBench` gate. The legacy all-in-one `smoke_test.gd` is not a reason to restore deleted AI methods; its known field-monster stall is tracked separately.
