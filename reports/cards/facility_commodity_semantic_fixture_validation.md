# Facility and Commodity Semantic Fixture Validation

## Change identity

- Base: `a96c34f9d1a9f79fc20c4689b8d2ff82e22c623e`
- Branch: `codex/card-semantic-wave2-g-facility-fixtures-a96c34f`
- Semantic contract: `card_semantic_projection_v1_migration`, schema version `1`
- Source catalog: `space_syndicate.card_runtime_catalog.v06`
- Production code changes: none
- Catalog or balance changes: none
- Owned artifacts:
  - `data/cards/semantic_templates/facility_commodity_family_templates_v1.json`
  - `tests/fixtures/card_semantic_phase1/facility_commodity_golden.json`
  - `reports/cards/facility_commodity_semantic_fixture_validation.md`

## Representative coverage

The fixture uses one coherent life-industry route so the commodity can target
both representative facilities without an invented cross-industry rule.

| Family | Ranks | Acquisition cash | Activation life assets | Rank values copied from v0.6 |
| --- | --- | --- | --- | --- |
| `commodity.star_dew_berry` | I-IV | 0, 0, 0, 0 | 0, 0, 0, 0 | install rate 10, 20, 40, 80 units/minute |
| `facility.factory.life` | I-IV | 4, 7, 11, 16 | 0, 2, 4, 7 | shared HP 100, 200, 300, 400; production capacity 40, 80, 140, 220 |
| `facility.market.life` | I-IV | 4, 7, 11, 16 | 0, 2, 4, 7 | shared HP 100, 200, 300, 400; demand capacity 40, 80, 140, 220 |

All 12 identities satisfy
`card_id == family_id + ".rank_" + rank`, every family contains exactly ranks
`[1, 2, 3, 4]`, and every acquisition/activation value is copied from the
current machine record.

## Projection contract

Each golden projection contains exactly the frozen top-level fields:
`schema_version`, `source_catalog_id`,
`source_definition_fingerprint`, `semantic_fingerprint`, `identity`,
`cost`, `timing`, `target`, `effect_ops`, `response`,
`information_policy`, and `runtime_readiness_id`.

The family templates normalize only closed Phase 1 meanings:

- `install_commodity_rate` becomes `install_rate`. The exact catalog
  `product_id`, industry, rate, valid facility kinds, and persistence are
  preserved. Rulebook section 5.3 supplies the stable direction map:
  factory -> production, market -> demand.
- `build_upgrade_or_repair_facility` exposes three mutually conditional
  semantic capabilities: `build_facility` for an empty slot,
  `upgrade_facility` when the card rank is higher, and `repair_facility`
  when the card rank is the same or lower. The projection does not choose a
  branch without an authoritative legality result.
- Factory capacity is always tagged `production`; market capacity is always
  tagged `demand`. Capacity, HP contribution, repair amount, and card rank
  remain the exact catalog values.

The eight machine-readable proof rows cover commodity installation to both
facility kinds, empty-slot factory and market builds, higher-rank factory and
market upgrades, same-rank repair, and lower-rank repair. They are explicitly
`semantic_branch_only` and require authoritative legality; they are not
receipts or mutation expectations.

## Authority gates

The templates fail closed at the known boundary:

1. Catalog commodity rates and facility HP/capacity values are compatibility
   mirrors of `SpaceSyndicateRulesetProfileV06`. Compilation requires exact
   per-rank parity and rejects the complete projection on mismatch.
2. `effect_payload.product_id` is the exact catalog value `星露莓`, not a
   stable ASCII ID. No alias is invented. A consumer that requires a stable
   ASCII product ID receives `RULE_AUTHORITY_NOT_ESTABLISHED`.
3. Facility `rent_rate_profile` remains
   `pending_first_playtest_table`. Rent semantics are omitted; a consumer
   that requires them receives `RULE_AUTHORITY_NOT_ESTABLISHED`.
4. `owner_established` records the observed commodity/infrastructure owner
   route only. It does not authorize a viewer, establish live legality, select
   a target, consume a card, or execute an effect.
5. Unknown families, ranks, operations, targets, operation policies, source
   mismatches, or source/Ruleset numeric drift reject the complete projection.

## Godot MCP evidence

- Role-local endpoint: Role `Supervisor`, port `8905`
- Godot: `4.7-stable (official)`
- Edited scene inspected: `res://scenes/tools/CardRuntimeCatalogV06Builder.tscn`
- Runtime root: `/root/CardRuntimeCatalogV06Builder`
- Runtime script: `res://scripts/tools/card_runtime_catalog_v06_builder.gd`
- Catalog Resource:
  `res://resources/cards/runtime/card_runtime_catalog_v06.tres`
- Resource source:
  `res://data/cards/card_runtime_catalog_v06.json`
- Builder result: `code=OK`, cards `348`, families `87`,
  effect-review pending `132`, `errors=[]`
- Category counts: commodity 184, facility 64, interaction 12, military 28,
  monster 32, organization 20, supply/demand 8
- Scoped runtime `godot.log`: warning lines `0`, error lines `0`
- Play stop: `is_playing_scene=false`
- Editor stop: `stopped=true`, `port_open=false`, PID `11636`
- Post-run catalog diff: empty

The broad editor baseline scan also reported unrelated pre-existing parser
diagnostics outside this role's ownership. The final builder acceptance is the
isolated play-mode runtime log above. The scan generated exactly 19 unrelated
untracked `.uid` files under existing `scripts/tools` and `tests`; a dry
run verified their paths, tracked source counterparts, and worktree containment
before removing only that set. Final untracked UID count is zero.

## Deterministic validation

| Gate | Result |
| --- | --- |
| PowerShell `ConvertFrom-Json` for both JSON artifacts | PASS |
| Independent catalog/template/golden cross-check | PASS: 3 templates, 12 projections, 8 proofs, 5 fail-closed cases |
| Deterministic template-to-golden rebuild | PASS: 12/12 canonical projections match |
| Source-definition fingerprints | PASS: 12/12 recomputed from canonical machine records |
| Semantic fingerprints | PASS: 12/12 recomputed after omitting only `semantic_fingerprint` |
| Template canonical SHA-256 repeat | `21605799ce57f13e0d1cd3a63162506c237364205c4f168eec50b83e7832f8a1`, repeat match |
| Golden canonical SHA-256 repeat | `4616b4b0248c0bcb1ad2b28aad943e45ebd5268cd4ee88f5448b2250e1ea071e`, repeat match |
| Current catalog file SHA-256 | `b59b73489d23578558d4a7688a03f50a3ef4d776cf528cd9eafd0e1d2a0fcb40` |
| `card_runtime_catalog_v06_test.gd` | PASS: 2,894 checks, 0 failures, 0 script errors |
| `git diff --check` | PASS |
| Catalog diff after MCP builder run | empty |
| Untracked `.uid` count after cleanup | 0 |

## Residual integration risks

- The Phase 1 compiler schema must keep the fixture's conditional facility ops
  as static capabilities. Treating all three as sequential execution would be
  invalid.
- Stable ASCII commodity identity still needs an approved registry before a
  consumer may replace the exact catalog `product_id`.
- Rent remains outside the semantic projection until its pending profile gains
  rule authority.
- Full cross-wave compiler/AI/PlayerFace integration and global regression
  belong to the coordinator; this branch intentionally supplies no runtime
  implementation.
