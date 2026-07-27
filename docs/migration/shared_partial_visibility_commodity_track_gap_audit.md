# Shared Partial-Visibility Commodity Track Gap Audit

Baseline: `b5763bbfb96994aa55ab36ae4335db332d9818a8`

Verdict:

```text
CORE_AUDIT_VERDICT=V0_7_CONSTITUTION_RECORDED_PRODUCTION_RULE_AUTHORITY_INCOMPLETE
REPOSITORY_APPLICATION_VERSION=NOT_DECLARED
CURRENT_RUNTIME_RULE_VERSION=v0.6
TARGET_RULE_VERSION=V0.7
FORMAL_PRODUCTION_CUTOVER_SAFE=false
SAFE_NEXT_STAGE=SHARED_COMMODITY_TRACK_RULE_DECISION_FREEZE
FULL_RULE_CUTOVER=false
FULL_V0_7_CUTOVER=false
```

## Current authority and mutation path

The current belt truth is `CardFlowTransactionServiceV06._belt`, wrapped by
`CommodityCardInventoryRuntimeController`. Player hand truth remains
`WorldSessionState.players[*].slots` through
`CardPlayerStateProductionAdapterV06` CAS transactions.

```text
TopCommoditySushiTrack
→ GameScreen
→ CommoditySushiTrackApplicationFlowController
→ CommoditySushiTrackRuntimeService.claim
→ CommodityCardInventoryRuntimeController
→ CardFlowTransactionServiceV06
→ CardPlayerStateProductionAdapterV06
→ WorldSessionState.players[*].slots
```

This claim path does not pass through `RuntimeCommandPipeline`. It must be
removed during the future production cutover, not duplicated beside a new
command path.

`ProductMarketRuntimeController` remains the price/futures owner and uses its
existing 30-60 second cadence. It must not be renamed into the new 180-second
generation-supply cycle. `CommodityFlowRuntimeController` supplies real GDP
facts, while `VictoryControlRuntimeController` remains the only final-outcome
owner.

## Conflict matrix

| Domain | Current v0.6 | Approved direction | Migration consequence |
| --- | --- | --- | --- |
| Visibility | empty allowlist exposes the sorted concrete belt | only actor-local concrete segment | fail-closed projection and privacy tests |
| Track | 12 static Rank-I items; claim deletes | one moving global sequence with position/stock/refill | new single owner after topology decision |
| Inventory | commodities share the ordinary five-card hand | separate five ordinary + five commodity | atomic migration of existing owner and Save |
| Upgrade | same-family same-rank; full-hand auto merge; 10/20/40/80 | linear L1 consumption and 1/2/3/4 units | replace policy, receipts, rates and stale tests together |
| Cycle | no stance cycle; price market uses unrelated 30-60 seconds | continuous 180-second world-effective cycle | separate narrow owner under RuntimeSimulationStep |
| Distribution | no six-color generation authority | GDP baseline + temporary intervention = 10,000bp | typed GDP aggregate and fixed-point normalization |
| Lead | none | fixed hidden order and forward/reverse macro rounds | one RunRngService lineage and private projection |
| End gate | Victory may finalize after audit | pending until complete macro-round revalidation | typed boundary attestation into existing Victory owner |
| AI | no sushi stance/claim/linear-merge semantics | actor observation and shared intents | remove old decision assumptions during cutover |
| Player UI | stationary cards over moving decoration; one hand capacity | local window, ratios, timer, stance, split capacity | passive projection first, atomic UI cutover later |

The machine-readable audit records current/future owner, Save, privacy,
determinism, phase, and old-path removal for every row.

### V0.7 constitutional conflict audit

| ID | CURRENT_BEHAVIOR | V0_7_REQUIRED_BEHAVIOR | AFFECTED_MODULES | MIGRATION_RISK | CUTOVER_PLAN | TEST_COVERAGE |
| --- | --- | --- | --- | --- | --- | --- |
| full-track visibility | current belt snapshot can expose every sorted item; empty visibility allowlist is broad | owner-bound viewer receives only its local segment, fail closed | `CommoditySushiTrackRuntimeService`, snapshot/viewmodel, `TopCommoditySushiTrack` | critical privacy leak | replace snapshot at the same atomic track-owner cutover | hostile nested/local-segment reference tests green; production gate absent |
| mixed five-card hand | commodity and normal cards share `WorldSessionState.players[*].slots` and one five-card policy | `normal_card_count<=5` and `commodity_slot_count<=5` are independent | `CardPlayerStateProductionAdapterV06`, `CardFlowTransactionServiceV06`, inventory controller, UI, Save | high data migration and exact-once risk | migrate the existing owner once; no second hand or dual write | reference 5+0/0+5/5+5/independent sixth-card tests green; production false |
| AI complete-track access | no V0.7 AI observation port exists; current full-belt service shape is not an acceptable AI boundary | owner-bound allowlisted `CommodityMarketObservation` only | `AiRuntimeController`, future observation source, commodity service | critical hidden-information risk | introduce typed query after core owner; delete any raw belt/core reads | reference cross-seat and nested-secret attacks green; production false |
| AI lead answer | current runtime has no hidden-lead mechanic | AI sees only `self_is_current_lead`, never another lead or fixed order | AI observation/policy, future cycle owner | critical cheating/side-channel risk | core-owned private boolean, no public identity | reference hidden aliases stripped; production false |
| UI supply calculation | no V0.7 six-color stance supply UI exists | UI consumes core-provided basis points/trend and never totals votes | player projection, GameScreen/track target | high divergence risk | add passive typed projection, then switch target with core | reference player projection test green; production false |
| equal-rank merge | same-family same-rank merge permits `L2+L2`/`L3+L3` paths and full-hand auto merge | only `L1+L1`, `L2+L1`, `L3+L1`; manual choice; one resulting commodity slot | `CardFlowPolicyV06`, transaction service, catalog/UI text | high inventory/rate/save risk | replace policy/receipts/rates/tests together | reference linear/rejection/slot-release tests green; production false |
| mid-round ending | Victory can finalize after its current qualification/audit without commodity macro-round attestation | mark pending and revalidate only at complete macro-round boundary | `VictoryControlRuntimeController`, future boundary port, Save | critical terminal exact-once risk | extend the existing Victory owner; no parallel ending | pure end-gate reducer green; production false |
| lead reshuffle | hidden lead order does not exist | one fixed hidden order for the whole session | future track/cycle owner, RunRngService, Save | high deterministic identity risk | derive once from RunRngService and persist | 3-8 fixed-seed vectors green; production false |
| reverse macro round | macro rounds do not exist | exact forward/reverse alternation, each roster seat once | future cycle owner, Save, AI/player projections | high ordering and elimination risk | freeze roster edge cases, then add one cursor | 3-8 forward/reverse/forward vectors green; roster edge gate open |
| old mutation entry | claim flows directly from application flow to inventory transaction, outside `RuntimeCommandPipeline` | claim/stance/merge intent enters the single command authority | application flow, commodity service, command pipeline/sinks | critical dual-mutation risk | add new path and delete old direct claim in one commit | negative production-wiring test green; production migration absent |
| multiple commodity authorities | belt, inventory, price market, GDP, and Victory are separate domains but no V0.7 aggregate owner exists | one track/cycle owner; existing inventory/price/GDP/Victory owners remain narrow | coordinator composition and typed ports | critical God-object or dual-write risk | compose narrow ports; never mirror price, inventory, GDP, or Victory | production reference count remains zero; composition gate pending |
| mixed Save array | current Save/player state stores commodities in mixed player slots; new track/cycle/order fields have no schema | separate versioned normal/commodity state plus track/cycle/order/end gate | Save registry, player adapter, future owner, Victory | critical restore/rollback risk | version-pair migration and exact restore; no dual write | reference pure payload round-trip green; production Save false |
| stale tests | existing v0.6 tests still assert mixed hand, complete belt and same-rank behavior | V0.7 tests assert independent pools/local visibility/linear merge; v0.6 tests become historical at cutover | commodity inventory/track tests and smoke fixtures | medium false-regression/compatibility risk | replace only at owning-domain cutover; never restore old wrappers | new reference tests green; legacy suite intentionally unchanged |

## Existing reusable foundations

- stable six-color IDs;
- twelve Alpha Rank-I commodity families, two per color;
- one belt Dictionary with stable item IDs, revision checks, exact-once
  transactions, and a single-winner concurrent claim;
- one `RunRngService`;
- six-color Sale Receipt/GDP facts;
- I-IV catalog assets, facility installation and destruction lifecycle;
- one Victory owner.

## Production blockers

The following change state topology and cannot be guessed by an implementation
agent:

1. track length, viewer window length/overlap, motion speed/model and direction;
2. spawn/refill frequency, finite stock, expiry/circulation and simultaneous
   claim tie-break;
3. first-cycle/missing-stance deterministic default;
4. eliminated/disconnected/restored seat roster policy;
5. same-product versus same-color merge identity;
6. mapping linear units to today's 10/20/40/80 installation rates;
7. full commodity inventory reject/discard/replace behavior (manual merge is the
   approved V0.7 target unless a later explicit rule changes it);
8. irreversible special outcomes through the macro-round gate;
9. production Save migration and restore order.

GDP smoothing, floor/ceiling, intervention cap and player-count scaling are
explicit `OPEN_BALANCE_PARAMETER`, not hidden hardcoded answers.

## Safe result of this phase

This change adds only docs, tests, test-support pure semantics, and a tools
Bench. It does not edit or compose production runtime, UI, AI, Save, Victory,
RuntimeLoop, RuntimeSimulationStep, or Main. Therefore the old v0.6 runtime
remains the only production authority and no dual write exists.
