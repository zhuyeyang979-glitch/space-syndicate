# Alpha 0.1 Selected Role Consumer Curation Report

## Decision

`星图审计庭` is replaced in the Alpha 0.1 selection by `幽幕播报社`.

This is a data-only selection change. The authoritative role catalog, gameplay rules,
runtime owners, save schema, target types, windows, and effects are unchanged.

Selection fingerprint changed from
`34fa4921fc017a84ff3117ef5040973a5d27c70ad4181b19888d3799e66d4a2e` to
`e1754e42641e0cc6bd3175326f6fea2b8a62802bf4068d340e11862132b6fb54`.

## Why the replacement is required

The previous role exposes two mechanical fields:

- `intel_city_reveal_charges`: no non-Main gameplay consumer exists.
- `city_guess_reward_bonus`: its remaining gameplay read is in legacy `scripts/main.gd`.

Catalog display, Codex formatting, balance diagnostics, test fixtures, and Main are not
accepted as evidence that a passive works in the current scene-owned runtime. Reintroducing
that role into a copy of the manifest fails validation even after the copy's deterministic
selection fingerprint is recomputed.

`幽幕播报社` is source index 9 and retains its Chinese-name save identity. Its single
mechanical field, `card_history_residual_catalog_charges`, is consumed by
`IntelPrivateCommandPort` through `use_residual_frame_catalog`, which delegates to the
private annotation owner using public evidence only.

## Curated source order

| Source index | Role |
|---:|---|
| 0 | 环港走私议会 |
| 1 | 深海菌毯使团 |
| 2 | 重力矿联董事会 |
| 3 | 离子军购局 |
| 9 | 幽幕播报社 |
| 16 | 黑潮风险基金 |
| 21 | 孪星兽栏同盟 |
| 22 | 蜂巢防务议会 |

## Hard gate

For every selected public role definition, all keys other than the five identity fields
(`name`, `species`, `trait`, `passive`, `flavor`) are treated as mechanical passives.
Each one must resolve to an explicit evidence record containing:

1. a source below `res://scripts/runtime/`;
2. a named gameplay API;
3. the exact role field token;
4. additional mutation/settlement/command tokens proving that the file is not merely a view;
5. no Main, presentation, Codex, diagnostics, tools, tests, or catalog-only path.

The resulting Alpha selection covers 18 role/field occurrences across 11 unique fields.
The consumer evidence is developer validation data only and is absent from the public
selection snapshot.

## Rule authority

- `RULE_AUTHORITY_GATE=GREEN`
- `CONTENT_CLASS=DATA_ONLY_CONTENT`
- `NEW_GAMEPLAY_MECHANIC_COUNT=0`
- `NEW_EFFECT_KIND_COUNT=0`
- `NEW_TARGET_KIND_COUNT=0`
- `NEW_SAVE_FIELD_COUNT=0`
- `NEW_WINDOW_COUNT=0`

## Focused validation

- Alpha manifest: 23/23 PASS.
- Selected role consumer gate: 14/14 PASS.
- Role catalog regression: 113/113 PASS.
- Card-history public annotation: 37/37 PASS.
- Intel query/command cutover: 82/82 PASS.
- v0.6 mechanic authority gate: PASS, zero retired production identifiers.
- Godot 4.7 MCP `Alpha01ContentManifestBench`: PASS, `errors=[]`, clean stop with
  `finalErrors=[]`.
- `git diff --check`: PASS.
