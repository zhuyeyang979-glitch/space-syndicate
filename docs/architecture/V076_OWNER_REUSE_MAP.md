# V0.7.6 Owner reuse map

schema_version: space_syndicate.v076.owner_reuse_map.v1

registry_id: V076_OWNER_REUSE_MAP

This map enforces one Owner per domain at candidate head
`2a365d465f199481da7fa1ef8f734e7525a136f5`. Consumers may adapt data or
contracts, but they may not inherit authority by association.

| Domain | Unique Owner | Reused source | Disposition | Consumer boundary |
|---|---|---|---|---|
| Tick, execution order, Authority Sequence, Domain RNG, snapshot, outbox, replay | `V076DeterministicKernel` | Stage 1 plus Stage 3 Kernel V2 delta | `ADOPT_AS_OWNER` | No PR64 semantic registry, PR79 core, or adapter may create a parallel Kernel/RNG/tick loop. |
| Shared spherical partition authority | `V076SharedHalfEdgePartitionV1` | Stage 2 | `ADOPT_AS_OWNER` | V074 float geometry is presentation-only after exact mapping parity. |
| Responsive globe interaction presentation | `V076SharedHalfEdgePartitionBench` | PR #88 source `558cc110...`, head `82334b9b...`, merge `05c24150...` | `ADAPT_AS_CONSUMER` | Typed targeting/hit/rotate/zoom/collision/no-mutation patterns and tests only. V073 six-region float Voronoi is retired as authority; no controller copy and no Stage 2 replacement. |
| Stage 2 reducer ABI | `V076PartitionReducerV1` | Stage 2 reducer adapted at Stage 3 | `ADAPT_AS_CONSUMER` | Generator, topology, validator, and codec remain unchanged; sentinel is `90/90`. |
| Monster L1 geodesic movement | `V076MonsterL1ReducerV1` | Stage 3 | `ADOPT_AS_OWNER` | Isolated only; no production cutover or asset-ledger dual write. |
| Current gameplay card definitions | `CardRuntimeCatalogService` | V04 root resource | `ADOPT_AS_OWNER` | Ten packs organize data only and are not Owners. |
| V06 semantic card source | `CardRuntimeCatalogV06Resource` | V06 resource + JSON | `ADOPT_AS_OWNER` | Semantic source does not replace V04 gameplay execution. |
| Semantic transform/cache | `CardSemanticCatalogService` | PR #62 compiler/schema | `ADOPT_AS_OWNER` | Deterministic transform only; not an executor. |
| Passive AI/PlayerFace projection | Existing PR #63 descendants | PR #63 | `ADAPT_AS_CONSUMER` | Viewer/privacy patterns only; no production AI or gameplay authority. |
| Private Direct Action input | `V076PrivateDirectActionInputOwnerV1` | PR #65 authorization pattern + V076 Kernel/half-edge + current catalog/assets/military + V075 mission core | `ADOPT_AS_OWNER` | Owns only the authorized envelope, own-hand revalidation, exact-once submission ledger, source-collision rejection, and Kernel root-command submission. It owns no tick, Authority Sequence, RNG, military unit state, asset quantity, topology, presentation, or card catalog. |
| Current six-color asset quantity | `PlayerManaRuntimeController` | Current production descendant | `ADAPT_AS_CONSUMER` | Stage 4 may use reservation/settlement APIs only; it may not copy balances or create an asset ledger. |
| Current military unit state | `MilitaryRuntimeController` | Current production descendant + V075 mission-core contract | `ADAPT_AS_CONSUMER` | Stage 4 delegates `ASSAULT_REGION` or `ASSAULT_MONSTER` once, follows a physical geodesic ETA, then withdraws. `GUARD`, `PROTECT`, teleport, retarget, and persistent commands are forbidden. |
| Codex/PlayerFace presentation | `CardCodexPublicSourceService` | PR #66 current descendant | `ADOPT_AS_OWNER` | DTO/presentation aliases cannot become rules. |
| V07 track/DBG/assets/solar concepts | Their current domain descendants, behind V076 reducers | PR #79 | `ADAPT_AS_CONSUMER` | Requires V076 ABI/replay/RNG proof; no new public batch or second asset Owner. |
| Pure semantic adversarial patterns | V076 focused tests | PR #64 | `REUSE_AS_TEST` | Metadata registry stays non-executing. |
| Canonical adapter patterns | V076 adapter tests | PR #80 | `REUSE_AS_TEST` | No PR80 Save/RNG connection; V076 remains new-game-only. |
| Historical uninterrupted card batch | None | PR #70 closed/unmerged head | `RETIRED` | Never revive, rebuild, or whole-branch merge. |
| V075 combat candidate | Existing PR #90 product lineage | PR #90 exact base | `REFERENCE_ONLY` | V076 does not supersede or dual-write production composition. |
| Human playtest instrumentation | Unassigned future observation-only Owner | PR #87 | `REFERENCE_ONLY` | Current Owner count is 0; patterns do not establish a V076 human pass. |
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

The 32 monster cards and 28 military cards retain `UNVERIFIED` exact V076
mapping. Neither historical capability coverage nor Stage 3 isolated movement
certifies those individual card records.
