# Command pipeline boundary audit

Status at audit time: `RUNTIME_COORDINATION_PHASE_DECOMPOSITION_GREEN`.

This audit freezes the production action boundaries before the command-pipeline
hardening change. It does not claim that every historical input path has been
migrated. The atomic cutover selected for this change is the already
authoritative card-resolution transition batch because it is frame ordered,
has stable command identity, has persisted exact-once lineage, and already
mutates through typed domain owners.

## Classification

| Action family | Current owner/path | Classification | This cutover |
|---|---|---|---|
| Card-resolution transitions | `CardResolutionRuntimeController -> CardResolutionFrameDriver -> CardResolutionTransitionSink` | already command-driven | migrate behind the explicit scene-owned command pipeline |
| Card play submission | `CardPlaySubmissionRuntimeController` | direct mutation path | unchanged; immediate accept/reject semantics are relied upon by target selection, AI and role-counter rollback |
| Region-supply purchase | `RegionSupplyRuntimeController` / purchase settlement owners | direct transaction path | unchanged |
| Facility purchase/install | card inventory, facility adapter and infrastructure owner | direct transaction path | unchanged |
| Monster deploy/upgrade | monster owner plus atomic side-effect ports | direct transaction path | unchanged |
| Contract offer/response | contract owner | direct transaction path | unchanged |
| Wager choice/settlement | monster wager owner | direct mutation path | unchanged |
| Military player commands | card effect router -> military owner | direct mutation path | unchanged |
| Weather, AI, monster, military autonomous ticks | explicit runtime phases and typed ports | phase-driven, not input commands | unchanged |
| Commodity flow, product market, victory | resolution/state-commit phases and typed ports | phase-driven, not input commands | unchanged |
| Table/map/developer refresh | presentation source/target composition | presentation-only | intentionally excluded |
| Visual cues and public logs | presentation owners | presentation-only | intentionally excluded |

## Go decision

The transition family is safe to migrate without changing gameplay timing:

- commands are authored and consumed inside the existing command phase;
- their producer order is contiguous and deterministic;
- each command already has a stable id, revision, order index and domain
  fingerprint;
- the transition sink and domain services remain the mutation owners;
- exact-once replay lineage remains in `CardResolutionRuntimeController` and
  its existing save owner;
- no caller-visible synchronous receipt changes.

The other direct intent paths are deliberately not wrapped in a fake generic
bus. In particular, card submission cannot be deferred without first replacing
its immediate rollback and target-selection contracts. Those paths are future
small, domain-specific cutovers.

## Baseline metrics

- Explicit command families in production: 1 (card-resolution transitions)
- Command families entering an explicit scene-owned pipeline: 0
- Direct/transactional player-intent families recorded above: 7
- Phase-driven autonomous families recorded above: 3
- Presentation-only families recorded above: 2
- Global command/event buses: 0
- Command autoloads: 0
