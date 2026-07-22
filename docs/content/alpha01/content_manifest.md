# Alpha 0.1 Playable Content Cut

Status: **runtime activated for the Alpha 0.1 playable cut**.

The authoritative resource is `res://resources/content/alpha01/alpha01_content_manifest.tres`.
It exposes exactly **40 player card identities** through `acquisition_card_ids()`.
Every acquisition identity is the rank-I record of one family. The **160 ranked records**
returned by `ranked_card_ids()` are the existing I-IV upgrade gradients for those 40
identities; they are dependency and execution records, not 160 independent draw cards.

No card, role, monster, product, rule value, art asset, or effect kind was added or changed.

## Runtime activation

The curated Resource is the sole gameplay runtime authority. Its
`runtime_selection_snapshot()` method supplies the typed selection directly from the same
role/card/monster identity fields. `res://docs/playtest/alpha_0_1/content_manifest.json` is
derived parity-locked audit evidence only; runtime code never reads `res://docs/`, which the
Windows export preset excludes.

The production call chain is:

1. `NewGameSetupDraftService` and `NewGameSetupViewerQueryPort` expose the eight selected
   source-stable roles, eight starter monsters, and the single depth-I map option.
2. `SessionStartPlanBuilder` resolves a formal 3-8 player plan from those identities and
   places exactly the 28 selected non-commodity rank-I IDs in `card_pool`.
3. `GameRuntimeCoordinator` preflights the plan against the same selection, configures the
   regional supply, and seeds the commodity owner from the plan gameplay seed.
4. `CommodityCardInventoryRuntimeController` deterministically orders all and only the 12
   selected commodity rank-I IDs. Same seed means same order; a different seed can vary it.

No runtime consumer expands the acquisition universe through `ranked_card_ids()`. The 160
rank records remain upgrade/execution dependencies, and public selection/supply projections
do not expose future bags, private hands, cash, ownership, routes, or AI reasoning.

## Cut summary

| Content | Selected | Source universe | Alpha contract |
|---|---:|---:|---|
| Public roles | 8 | 24 | Named source identities; source indices preserved |
| Player card identities | 40 | 87 families | Rank-I acquisition IDs only |
| Card rank records | 160 | 348 records | Existing I-IV gradients for the 40 identities |
| Monsters | 8 | 8 | Complete source roster |
| Products | 46 | 46 | Complete source catalog |

Card identity mix: 12 commodities, 12 facilities, 3 interactions, 2 supply/demand,
3 military, and 8 monsters. The cut excludes all five organization families because
their source catalog still names `organization_runtime_owner_pending`.

## Roles (8)

The index is the authoritative 24-role catalog index, not a new Alpha-local identity.

| Source index | Public role | Why it belongs in the first learning set |
|---:|---|---|
| 0 | 环港走私议会 | Visible starting-cash and product purchase identity |
| 1 | 深海菌毯使团 | Product-linked cashflow identity |
| 2 | 重力矿联董事会 | Industrial product-linked cashflow identity |
| 3 | 离子军购局 | Monster-upgrade economy identity |
| 9 | 幽幕播报社 | Public-evidence residual catalog with a typed private-intel consumer |
| 16 | 黑潮风险基金 | Public market-volatility identity |
| 21 | 孪星兽栏同盟 | Monster-control-limit identity |
| 22 | 蜂巢防务议会 | Military-control-limit identity |

The manifest stores role names only. Passive text and values remain in the scene-owned
`RoleCatalogRuntimeService`; save identity remains the original Chinese name plus source
index. Every mechanical passive field on the eight selected roles is additionally checked
against a narrow allowlist of non-Main gameplay consumers. Presentation, Codex, diagnostics,
tests, and the role catalog itself cannot satisfy that gate.

## Card identities (40)

Only the listed `.rank_1` IDs belong in acquisition/draw inputs. `.rank_2` through
`.rank_4` remain the existing same-family upgrade gradient.

### Commodity identities (12)

Two recognizable products per industry keep all six industries teachable.

| Family ID | Player name | Industry |
|---|---|---|
| `commodity.blue_tide_algae` | 蓝潮藻 | shipping |
| `commodity.deep_sea_fungal_mat` | 深海菌毯 | life |
| `commodity.dream_fragrance` | 梦境香氛 | commerce |
| `commodity.gravity_ceramic` | 重力陶瓷 | industry |
| `commodity.living_chip` | 活体芯片 | technology |
| `commodity.photosynthetic_gel` | 光合凝胶 | life |
| `commodity.ring_crystal_battery` | 环晶电池 | energy |
| `commodity.solar_scale` | 太阳鳞片 | energy |
| `commodity.star_whale_canning` | 星鲸罐头 | shipping |
| `commodity.storm_pearl` | 风暴珍珠 | commerce |
| `commodity.titanium_shell_clam` | 钛壳贝 | industry |
| `commodity.trajectory_ink` | 轨迹墨水 | technology |

### Facility identities (12)

One factory and one market for each industry establish the smallest symmetrical economy
teaching skeleton.

| Family ID | Player name |
|---|---|
| `facility.factory.commerce` | 商贸工厂 |
| `facility.factory.energy` | 能源工厂 |
| `facility.factory.industry` | 工业工厂 |
| `facility.factory.life` | 生命工厂 |
| `facility.factory.shipping` | 航运工厂 |
| `facility.factory.technology` | 科技工厂 |
| `facility.market.commerce` | 商贸市场 |
| `facility.market.energy` | 能源市场 |
| `facility.market.industry` | 工业市场 |
| `facility.market.life` | 生命市场 |
| `facility.market.shipping` | 航运市场 |
| `facility.market.technology` | 科技市场 |

### Interaction, global supply/demand, and military identities (8)

| Family ID | Player name | Learning purpose |
|---|---|---|
| `interaction.phase_veto` | 相位否决 | One-layer direct-interaction counter |
| `interaction.shadow_warehouse_traction` | 影仓牵引 | Bounded opponent-hand interaction |
| `interaction.starlink_dismantle` | 星链拆解 | Bounded opponent-hand disruption |
| `supply_demand.near_land_supply` | 近地供货潮 | Automatic global supply settlement |
| `supply_demand.remote_sea_order` | 远洋采购令 | Automatic global order settlement |
| `unit.military.air_superiority_fighter` | 制空战斗机 | Mobile military identity |
| `unit.military.planetary_defense_force` | 行星防卫军 | Defensive military identity |
| `unit.military.submarine_fleet` | 潜航舰队 | Ocean military identity |

### Monster card identities (8)

| Family ID | Player name |
|---|---|
| `unit.monster.blue_edge_knight` | 蓝锋骑士 |
| `unit.monster.flame_ring_proto_star` | 焰环幼星 |
| `unit.monster.meteor_sentinel` | 流星哨兵 |
| `unit.monster.mirror_hunter` | 镜像猎兵 |
| `unit.monster.oasis_repairer` | 绿洲修复体 |
| `unit.monster.prism_blade_colossus` | 棱刃重甲 |
| `unit.monster.sand_armor_rover` | 砂铠陆行兽 |
| `unit.monster.spore_tide_emperor` | 孢雾海皇 |

## Monster roster (8)

The complete authoritative roster remains available, in source order:

1. 孢雾海皇
2. 砂铠陆行兽
3. 流星哨兵
4. 棱刃重甲
5. 绿洲修复体
6. 焰环幼星
7. 蓝锋骑士
8. 镜像猎兵

Every roster identity has the matching monster card family in the cut.

## Product catalog (46)

All products remain available so the economy, role hooks, weather tags, and product
Codex do not acquire an artificial Alpha-only product schema.

| Industry | Products |
|---|---|
| life (11) | 星露莓, 月壤葡萄, 孢子丝绸, 光合凝胶, 轨道盆栽, 寒冠冰糖, 深海菌毯, 晨昏奶酪, 北极薄荷, 星尘面包, 梦游蘑菇 |
| energy (10) | 磁核榴莲, 彗尾柑, 环晶电池, 太阳鳞片, 海底黑油, 反物质茶, 静电蜂蜜, 等离子米, 火山番茄, 潮汐电浆 |
| industry (6) | 重力陶瓷, 虹膜矿粉, 引力棉, 钛壳贝, 陨铁酱料, 暗礁珊瑚 |
| technology (4) | 活体芯片, 极光盐, 轨迹墨水, 离岸水晶 |
| commerce (9) | 量子蜜瓜, 脉冲咖啡, 真空可可, 离子香料, 梦境香氛, 零点饮料, 云母玩具, 风暴珍珠, 赤道香草 |
| shipping (6) | 星鲸罐头, 星鳍鱼群, 蓝潮藻, 巨藻纤维, 夜航香蕉, 卫星坚果 |

## Deterministic identity contract

- `acquisition_card_ids()` is exactly 40 unique `.rank_1` IDs.
- `ranked_card_ids()` is exactly 160 unique records: ranks 1-4 for each selected family.
- Family IDs are stored in lexical order; roles, monsters, and products preserve source order.
- The public selection snapshot contains identities and counts only.
- The selection fingerprint is `e1754e42641e0cc6bd3175326f6fea2b8a62802bf4068d340e11862132b6fb54`.
- Source and rules-registry hashes are locked in the resource so dependency drift fails closed.
