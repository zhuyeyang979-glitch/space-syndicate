# P2 Alpha 0.1 Content Curation Handoff

## Delivered

- A real Godot resource at `res://resources/content/alpha01/alpha01_content_manifest.tres`.
- A deterministic validator and public identity-only snapshot.
- A production-wiring Bench scene at
  `res://resources/content/alpha01/Alpha01ContentManifestBench.tscn`.
- A focused headless test at `res://tests/alpha01_content_manifest_test.gd`.
- A field-level role-consumer gate at
  `res://tests/alpha01_selected_role_consumer_test.gd`.
- Complete inventory, dependency/consumer audit, privacy audit, and owner integration request.

The curation contains 8 public roles, **40 player card identities**, 160 existing I-IV
rank records, 8 monsters, and all 46 products. The 160 records are not described or consumed
as 160 independent draw cards.

The selected role set now uses source index 9 `幽幕播报社` instead of source index 8
`星图审计庭`. This is curation only: the original Chinese identity and catalog index are
preserved, and no source role definition changed. A strict field-level audit proves all 18
selected passive-field occurrences have known non-Main gameplay consumers; a negative fixture
proves the two unsupported `星图审计庭` fields cannot pass by relying on Main or presentation.

## Scope and boundary

Only task-owned paths were changed:

- `resources/content/alpha01/**`
- `docs/content/alpha01/**`
- `tests/alpha01_content_manifest_test.gd`
- `tests/alpha01_selected_role_consumer_test.gd`

No Main, `GameRuntimeCoordinator`, `GameScreen`, economy owner, card-execution owner,
rule value, card definition, role definition, monster definition, product definition, or art
asset was modified.

## Activation state

The whitelist resource is ready, but production activation remains pending the request in
`integration_request.json`. The current runtime correctly limits draw records to rank I, so
there is no 160-record random-pool defect. It still reads the full catalog universes rather
than the Alpha selection.

## Validation evidence

- Godot version: `4.7.stable.official.5b4e0cb0f`
- Focused manifest test: **PASS**, 23 checks, 0 failures.
- Selected-role consumer test: **PASS**, 14 checks, 0 failures, including the
  repinned-unsupported-role negative fixture.
- Role catalog regression: **PASS**, 113 checks, 0 failures.
- Card-history public annotation regression: **PASS**, 37 checks, 0 failures.
- Intel query/command cutover regression: **PASS**, 82 checks, 0 failures.
- Selection SHA-256: `e1754e42641e0cc6bd3175326f6fea2b8a62802bf4068d340e11862132b6fb54`
- Selected owner/target coverage: **160/160 rank records**.
- Retired identifier hits: **0** across cards, roles, monsters, and products.
- Hidden-information forbidden-key hits: **0**.
- Consumer evidence paths missing: **0**.
- Selected role passive consumer coverage: **18/18 field occurrences** across 11 fields.
- Unsupported selected role fields: **0**.

The focused test emits three inherited invalid-UID warnings from
`product_industry_catalog_v05.tres`; Godot resolves each through its existing text path.
They do not change the source resource, validation result, or dependency hash.

## Known inherited review debt

One hundred selected rank records carry explicit source review flags (48 facility, 44 unit,
8 direct hand-interaction). They have active owner/target routes and are included without
changing their values. The cut must not be interpreted as a balance sign-off for those flags.

## Final runtime record

- Scene: `res://resources/content/alpha01/Alpha01ContentManifestBench.tscn`
- MCP result: **PASS**; the real resource reported 40 card identities, 160 rank records,
  8 roles, 8 monsters, 46 products, selection fingerprint
  `e1754e42641e0cc6bd3175326f6fea2b8a62802bf4068d340e11862132b6fb54`, and `errors=[]`.
- MCP debug: **0 script/runtime errors**.
- Stop result: **Godot project stopped**, `finalErrors=[]`; the MCP lease was released.
- Focused test: **PASS**, 23 checks, 0 failures.
- General `smoke_test.gd --check-only`: **PASS** (exit 0).
- UI text guard: **PASS**.
- Visual contract guard: **PASS**.
- v0.6 mechanic authority checker: **PASS**, 0 retired production identifiers.
- Local commit: recorded after commit creation.
