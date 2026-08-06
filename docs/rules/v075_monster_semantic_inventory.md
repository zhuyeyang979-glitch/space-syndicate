# V0.7.5 Monster Semantic Inventory

This inventory reads V0.6 monster code and content only as migration evidence.
It does not authorize `MonsterRuntimeController` in V0.7.5 production.

## Source Summary

The legacy catalog contains eight stable families, 32 four-rank monster cards,
48 behavior actions, eight body-art profiles, localized `resource_focus`, large
market-skill lists, real-time action timers, weighted district targeting,
wagers, and one monolithic runtime Controller.

Useful material exists, but the old runtime mixes stable and localized identity,
public and private action paths, wall-clock movement, planar/district indexing,
combat state, presentation, wagering, and compatibility behavior. V0.7.5 keeps
only stable IDs, selected authoring, pure formulas, and licensed presentation
assets.

## Active Families

| Stable family | Legacy name | Preferred color | Movement | Disposition |
|---|---|---|---|---|
| `spore_tide_emperor` | 孢雾海皇 | life | ground trample | adapt |
| `meteor_sentinel` | 流星哨兵 | energy | flying, no trample | adapt |
| `sand_armor_rover` | 砂铠陆行兽 | industry | ground trample | adapt |
| `blue_edge_knight` | 蓝锋骑士 | technology | ground trample | adapt |
| `prism_blade_colossus` | 棱刃重甲 | commerce | ground trample | adapt |
| `mirror_hunter` | 镜像猎兵 | shipping | teleport, no trample | adapt |

`oasis_repairer` and `flame_ring_proto_star` are deferred, not deleted. Their
authoring remains available for a later catalog version, while the first
candidate stays at six families and avoids adding repair and threshold
self-damage semantics.

Preferred color is autonomy-only. Card color and card action cost continue to
come from the existing unified-track color supply as `track_primary_color` and
`primary_asset_cost`. The visible contrast case is `mirror_hunter`: it prefers
shipping facilities but its card remains technology-colored and pays technology
assets.

The six active families reuse the integrated commercial model keys
`model.monster.life`, `.energy`, `.industry`, `.technology`, `.commerce`, and
`.shipping`. Existing body sprites remain provenance/fallback evidence. Model
or sprite color never determines preferred color.

## Retain Or Adapt

- Retain stable family/card IDs, four ranks, normal DBG identity, public HP and
  armor concepts, exact-once command principles, strict projection allowlists,
  and pure armor/damage ordering.
- Adapt rank-I HP/armor into explicit I-IV balance profiles. Adapt selected
  legacy actions into exactly 24 stable private skill definitions.
- Adapt bound monster techniques into an owner-private instant zone. They
  remain source-bound, but are not public queue or five-action members.
- Adapt movement into frozen dynamic-adjacency plans and stable region receipts.
  Planar per-frame authority is not retained.
- Adapt down/recovery/destroyed behavior into explicit `active`, `downed`,
  `destroyed`, and `withdrawn` states.

## Presentation Only

Localized names, subtitles, glyphs, motifs, body sprites, commercial models,
attack effects, trails, smoke, and audio are presentation data. They consume
catalog IDs and committed receipts. They cannot select family, target, path,
damage, preferred color, or RNG.

## Deferred

Legacy weather/terrain modifiers, `resource_focus` economy coupling, neutral
monsters, two inactive families, unselected actions, and production Save
migration are deferred. V0.7.5 has no land/ocean combat modifier and remains
new-game-only.

## Retired Or Conflicting

The following cannot enter V0.7.5 production:

- monster wager, Public Bid, auction timer, and interactive Counter window;
- real-time wall-clock movement and action timers;
- fixed-six, alpha-zeta, district-array, screen-distance, or pixel targeting;
- localized-name behavior dispatch and silent family fallback;
- same-family cross-owner upgrade and timed presence extension;
- generic public/market skill lists and public monster skill cards;
- arrival-only district damage as a substitute for per-region trample;
- `MonsterRuntimeController` as a production node or fallback.

The Controller may be read while extracting a pure formula or comparing old
authoring. A V0.7.5 production instance, callback bridge, copied monolith, or
Save owner connection is forbidden.
