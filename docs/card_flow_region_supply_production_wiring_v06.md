# CardFlow 区域牌架生产接线 v0.6

## 边界

- `RegionSupplyRuntimeController` 仍是区域牌位、牌袋、游戏 RNG、补位事务与刷新序号的唯一 owner。
- `CommodityCardInventoryRuntimeController` 与其既有 `CardFlowTransactionServiceV06` 仍是购买、现金、手牌、回滚、终态重试与公开回执的唯一事务 owner。
- `GameRuntimeCoordinator` 只负责：
  - 把生产场景中唯一的 `RegionSupplyRuntimeController` 作为非 owning source port 注入 CardFlow；
  - 将玩家提交的绑定字段原样转发给 `purchase_region_supply_card`。
- Coordinator 不规划、提交、回滚或完成购买，不保存牌架、牌袋、现金、手牌或 RNG。

## 生产 facade

`GameRuntimeCoordinator.purchase_region_supply_card(request)` 接受：

- `actor_id`
- `region_id`
- `slot_index`
- `item_id`
- `card_id`
- `player_revision`
- `supply_revision`
- `transaction_id`
- `quote_request`

它只做字段提取、深拷贝 `quote_request`、调用 Inventory 的同名 API，并深拷贝返回结果。缺少生产 Inventory 时 fail closed。

## 过渡状态

`commit_district_purchase_with_region_supply` 暂时保留，仅供仍未切换的 `main.gd` 路径使用。本接线不扩大该旧 bridge；后续 main 切换到通用 facade 后应退休它。

## 验收

- 生产 `GameRuntimeCoordinator.tscn` 中只有一个 RegionSupply owner。
- configure、reset、再次 configure 后 source port 均 ready。
- 正确绑定通过 Coordinator facade 完成真实购买和单槽补位。
- 错误 `item_id`/quote 绑定不改变玩家或牌架。
- 重放 exact-once，外部修改返回副本不污染终态记录。
- 公开回执不包含对手现金、牌袋、报价指纹、actor 或具体购买卡。
- Godot MCP Bench：
  - `res://scenes/tools/CardFlowRegionSupplyProductionWiringV06Bench.tscn`
