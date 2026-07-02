# Heavy Strategy Depth Gate v1

任务目标：把《太空辛迪加》的怪物、角色、卡牌、商品、价格和平衡，从“功能复杂原型”推进到“可验证策略深度的重型桌游原型”。

参考方向是 Gaia Project / Terraforming Mars 级别的非对称路线、引擎构筑、地图经济、反制关系和长期规划；不复制它们的规则、素材、文本或 IP。

核心原则：

- 不做普通 TCG 克隆。
- 保留本项目核心：匿名牌、怪兽压力、城市 GDP、商品路线、合约、竞价、推理、PVE AI。
- 不把隐藏信息暴露给玩家。
- 不靠长说明制造复杂度。
- 所有深度必须有字段、矩阵、模拟、报告和测试。

## 总分门槛

Heavy Strategy Depth Score / 100：

| 分项 | 分值 | 最低线 |
| --- | ---: | ---: |
| 怪物生态与地图压力 | 20 | 16 |
| 角色卡非对称策略 | 15 | 12 |
| 卡牌路线与反制网络 | 25 | 20 |
| 商品/供需/路线经济 | 20 | 16 |
| 自动平衡与模拟稳定性 | 20 | 16 |

通过条件：

- 总分 >= 84。
- 任一分项低于最低线直接 fail。
- 至少 8 条可解释战略路线。
- 任一主策略路线至少 2 个公开反制方式和 1 个隐性推理风险。
- 每局前 10 分钟至少出现 3 次有意义分叉：建城、买牌、怪兽方向、商品/路线、匿名牌或竞价。
- 所有卡牌效果字段化，AI 能读取 effect fields。
- 玩家 UI 不允许暴露隐藏信息，AI 内部评分不能进玩家 UI。

## 怪物策略矩阵

每个怪物家族必须字段化：

- `monster_id`
- `rank`
- `movement_ecology`
- `preferred_products`
- `hated_products`
- `preferred_terrain`
- `threat_role`
- `autonomy_profile`
- `owner_skill_profile`
- `public_clue_profile`
- `counterplay_tags`

硬指标：

- 至少 12 个怪物家族。
- 每个家族 rank I-IV。
- 至少 6 种 `movement_ecology`。
- 至少 6 种 `threat_role`。
- 每个怪物至少偏好 2 个商品或地形因素。
- 每个怪物至少 2 个反制方式。
- 任意两个怪物家族 strategic profile 相似度不得超过 70%。
- 500 局 AI 模拟中，每个怪物家族至少在 8% 的局里成为最高威胁之一。

## 角色非对称矩阵

每个角色必须字段化：

- `role_id`
- `public_identity`
- `opening_hook`
- `midgame_engine`
- `endgame_pressure`
- `primary_archetype`
- `secondary_archetype`
- `matching_products`
- `map_preference`
- `monster_preference`
- `card_route_preference`
- `weakness`
- `counterplay`
- `private_information_boundary`
- `ai_plan_tags`

硬指标：

- 24 个角色覆盖至少 8 类战略路线。
- 每类路线至少 2 个角色。
- 每个角色必须有开局优势、中局引擎、终局方向、公开弱点、至少两个可反制公开信号。
- 任意两个角色相似度不得超过 65%。
- 500 局 AI 自博弈中，角色胜率不超过平均 ±12pp。
- 角色不能直接泄露怪兽、城市或匿名牌真实归属。

## 卡牌路线与反制网络

每张卡必须字段化：

- `card_id`
- `family_id`
- `rank`
- `card_type`
- `route_tags`
- `required_product`
- `required_city_flow`
- `target_type`
- `effect_fields`
- `public_resolution_fields`
- `private_resolution_fields`
- `counterplay_tags`
- `telegraph_tags`
- `price_tier`
- `suggested_price`
- `actual_price`
- `complexity_score`
- `power_score`
- `tempo_score`
- `engine_score`
- `disruption_score`
- `counter_score`
- `scenario_tags`
- `ai_play_tags`

硬指标：

- 至少 12 条卡牌路线，每条至少 10 张卡，且至少覆盖 3 个类型。
- 90% 卡牌 `actual_price` 在 `suggested_price ±15%`。
- 超出 ±15% 的卡必须写入 `docs/card_balance_exceptions.md`。
- 每张 terminal pressure 卡至少 2 个 `counterplay_tags`。
- 每张强匿名干扰卡至少 1 个公开 `telegraph_tags`。
- 任一卡牌路线模拟胜率不超过平均 +12pp。
- Rank I-IV 必须体现入口、效率/持续、路线核心、强终局压力的梯度。

## 商品/供需/路线经济图

每个商品必须字段化：

- `product_id`
- `category`
- `terrain_sources`
- `demand_categories`
- `base_supply`
- `base_demand`
- `volatility`
- `transport_dependency`
- `monster_attraction_tags`
- `weather_sensitivity`
- `contract_tags`
- `card_route_tags`
- `counter_products`
- `substitute_products`
- `complement_products`
- `futures_risk_level`

硬指标：

- 至少 24 个商品。
- 至少 6 个商品大类：食物/生物、能源、矿物/材料、科技/数据、奢侈/文化、海洋/运输。
- 每个商品至少 2 种需求来源、1 种路线依赖、1 种怪兽或天气关联、1 组替代品或互补品、至少 6 张相关卡。
- 每个地图至少生成 4 个商品集群、2 条跨区域供需路线、1 个高价值冲突商品、1 个低价值稳定商品。
- 价格变化必须来自 `supply`、`demand`、`route_damage`、`contract_pressure`、`monster_pressure`、`weather_modifier`，不允许任意改价。

## 模拟与失败门槛

模拟规模：

- quick check：50 局。
- standard balance：500 局。
- deep balance：3000 局。

必须输出：

- `role_winrate`
- `role_pick_rate`
- `monster_threat_share`
- `product_profit_share`
- `card_play_rate`
- `card_purchase_rate`
- `route_archetype_winrate`
- `average_game_length`
- `time_to_first_city`
- `time_to_first_card_purchase`
- `time_to_first_anonymous_card`
- `final_countdown_trigger_time`
- `hidden_info_leak_count`
- `dominant_strategy_count`
- `dead_card_count`
- `dead_product_count`
- `dead_monster_count`

直接 fail：

- `hidden_info_leak_count > 0`
- `dead_card_count > 10%`
- `dead_product_count > 15%`
- `dead_monster_count > 20%`
- 任一角色胜率 > 平均 +12pp
- 任一商品路线胜率 > 平均 +12pp
- 任一卡牌路线胜率 > 平均 +12pp
- 平均游戏时长偏离目标区间超过 35%
- 前 5 分钟玩家没有可解释主行动
- 终局倒计时前没有至少 3 次经济/怪兽/匿名牌互动

## 下一轮建议分支

建议分支：`codex/heavy-strategy-depth-gate-v1`

第一阶段优先交付：

1. `docs/strategy_depth_spec.md`
2. `data/strategy/strategy_archetypes.json`
3. `data/strategy/monster_strategy_matrix.json`
4. `data/strategy/role_archetype_matrix.json`
5. `data/strategy/card_route_matrix.json`
6. `data/strategy/product_ecosystem_graph.json`
7. `scripts/strategy/strategy_depth_analyzer.gd`
8. `tests/strategy/heavy_strategy_scorecard_test.gd`
9. `reports/strategy/heavy_strategy_scorecard.md`

关键提醒：重策深度不是内容数量，而是可验证的多路线、长期引擎、反制网络和统计平衡。
