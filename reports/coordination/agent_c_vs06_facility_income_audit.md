# VS06-C4 Rank-I 设施收入断链审计

状态：只读审计完成；未修改生产、测试、目录数据或验收台，未运行 Godot。

## 结论

`facility.factory.commerce.rank_1` 的事务按当前 v0.6 owner 边界只负责建设产能设施，Stage 4 的成功结果是正确的；收入断链发生在“设施建成”之后、`CommodityFlow` 永久商品安装之前。当前首次建城流程用通用 facility 卡替代了规则中的“陆地区域固定城市发展牌”，但没有把区域权威 `product_id` 安装到新工厂，也没有保证匹配的市场需求端。因此这不是 CommodityFlow 公式失效，也不是 RegionInfrastructure finalize 丢失，而是生产 cutover 的复合接线缺失。

证据链：

1. catalog payload 只有 `facility_type=factory`、`industry=commerce`、rank 与 `production_capacity_units_per_minute=40`，没有 `product_id` 或 commodity install intent。
2. `CoreEconomicCardRuntimeAdapterV06` 将 `build_upgrade_or_repair_facility` 只路由到 `FacilityCardEffectAdapterV06`；只有 `install_commodity_rate` 才进入 commodity adapter。
3. facility adapter/RegionInfrastructure 只 prepare/apply/finalize 设施行；receipt 中的 `commodity_flow_refresh` 只是刷新提示，不能凭空推导商品。
4. CommodityFlow 的 flow plan 只遍历永久 `_installations`，不会把裸 factory capacity 当作生产源；没有 installation 就没有 source claim、sale receipt、GDP 或现金流水。
5. 即便补上生产 installation，仍须有同商品的有效 market demand installation（或同 owner 的权威一次性需求）、合法路线与正容量，才会成交。

## 唯一 owner 与最小正确 API

- 设施真相继续由 `RegionInfrastructureRuntimeController` 拥有。
- 永久商品生产/需求安装、流量分配、成交、GDP 与现金 ledger 的唯一 owner 必须是 `CommodityFlowRuntimeController`。
- 永久安装应复用现有 `install_commodity(request)`、`rollback_commodity_installation(transaction_id)`、`finalize_commodity_installation(receipt)`；现金只能由 sale receipt 经 `CommodityFlowWorldBridge.apply_sale_receipt_batch` 入账。
- `prepare_card_effect_batch/commit_card_effect_batch/...` 是一次性 supply/demand batch，不是永久工厂安装 API；可继续用于目录定义的一次性效果，但不得拿它冒充固定城市发展牌的永久生产源。

若一张固定城市发展牌按规则同时表示“建厂并绑定本地商品”，最小实现应由现有 CardFlow 外层事务协调一个字段驱动的复合 effect：先绑定区域权威 `product_id` 与两套 owner revision，建设设施后用 receipt 的 canonical facility id 调用永久安装；任一后续步骤失败须逆序 rollback，玩家状态 commit 后再 finalize 两个 owner。不得按卡名推导商品，不得新建经济 owner，也不得直接加钱。

## 修复归属与最小文件面

建议由 Agent A（facility/production cutover owner）主修，并由现有 Core/CardFlow owner 复核事务边界。Agent B 的 units/monster 与 Agent C 的 acceptance 不应承担生产修复。

最小候选文件：

- `scripts/cards/v06/production/core_economic_card_runtime_adapter_v06.gd`
- `scripts/cards/v06/effects/facility_card_effect_adapter_v06.gd`，或同目录新增一个明确的复合 effect adapter
- `scripts/runtime/game_runtime_coordinator.gd` 或现有 world bridge，仅用于提供权威 region-local `product_id`/需求事实
- `tests/core_economy_production_integration_v06_test.gd`
- `tests/facility_card_production_unlock_v06_test.gd`

只有在缺少只读事实接口时，才可窄改 `commodity_flow_world_bridge.gd`；不应修改 CommodityFlow 的分配、售价、GDP、租金或现金公式。

本修复绝不能触碰：`PlayerMana`、catalog 数值/设施梯度、`main.gd`、UI、AI、Monster、旧 `CityDevelopment`/`DistrictPurchaseSettlement`/project slots，亦不得让 RegionInfrastructure 保存商品安装或直接结算现金。验收台不得合成收入来掩盖断链。

## 精确闭环 oracle

使用确定性短 fixture，而非等待 120 秒：

1. 前置：一个 active rank-I factory；同商品的 active rank-I production installation（10 units/min）绑定该 factory；一个 active 同色 market 与 matching demand installation（10 units/min）；同区、相邻直连或合法 route；设施完整度 100%，容量 40，商品价格为正。
2. source：安装快照必须含 canonical `product_id`、`direction=production`、新 factory id、region id、owner、rank/base rate；需求行同样绑定 market。裸 facility snapshot 不算生产证据。
3. 时间：按 1 秒固定 tick，前 5 tick sale receipt delta 必须为 0；第 6 tick 累积达到 1,000 milliunits，必须精确新增 1 条 sale receipt。若第 6 秒仍为 0，接线或前置事实不完整。
4. flow：该商品 metrics 必须同时有 production/demand 正值、`pair_count >= 1`、allocated milliunits 正值；route/capacity 为正。
5. receipt：唯一新 receipt 必须引用预期 commodity、production/demand installation、`source_factory_id`、market、route，`units=1`、`gdp_value>0`，重放不得新增第二条。
6. GDP：market region 的 GDP snapshot 必须含该 receipt id 且 `region_gdp_per_minute_cents>0`；仅一条 receipt 且窗口为 30 秒时，期望每分钟 GDP 为 `2 * receipt.gdp_value`。
7. 现金/ledger：玩家现金增量必须精确等于归属该玩家的 `owner_net_cash` 加其应收 facility rent；每个 receipt 只能产生一组对应 `commodity_sale`/`facility_rent` ledger 行，transaction id 为 receipt id。
8. `card_effect_candidates_snapshot` 依赖已有 production installation 与近期 GDP，不能作为首次生产的 bootstrap；首笔成交后可要求候选含相同 source factory/market/route 且余量为正，作为后验佐证。

持续 120 秒、双方均为 10 units/min 时全量 ledger 应累计 20 次成交；recent receipt/GDP 窗口只保留最近 30 秒，不能拿其行数断言全程 20 次。

## 最小修复判定

可复用现有 CommodityFlow 永久 install/rollback/finalize 与 sale batch 入账链；不能复用一次性 card batch 来替代永久安装。闭环只有在上述 source、匹配 demand、sale receipt、GDP 与 receipt 驱动现金全部同时成立且 exact-once 时才算完成。
