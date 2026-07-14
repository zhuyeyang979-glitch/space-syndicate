# v0.6 卡牌效果生产接线图

日期：2026-07-14

## 总结

九种效果中，商品安装与公共设施已有成熟度较高的生产 owner；一次性供需、怪兽、军队、玩家互动和反制仍需新的 v0.6 事务 API。任何 adapter 接入前，必须先让生产手牌、现金和六色资产通过单一 `CardPlayerStatePortV06` 提供 revision/CAS，不能把 Bench 内存玩家状态变成第二份真相。

| `effect_kind` | 候选 owner/API | 当前缺口 |
|---|---|---|
| `install_commodity_rate` | `CommodityFlowRuntimeController.install_commodity()` | 缺纯预检和回滚；需从设施推导生产/需求方向；actor ID 需安全映射到 player index |
| `build_upgrade_or_repair_facility` | `RegionInfrastructureRuntimeController.apply_facility_action()` | 缺纯预检和回滚；仓库目标必须选择产业颜色；租金仍待平衡 |
| `global_order_budget` | 尚无正式 owner | 需一次性需求注入、全图筛选、GDP 份额分配和批量原子提交 |
| `global_supply_spawn` | 可复用 `CommodityFlowRuntimeController.inject_one_shot_supply()` | 只有单商品/单区域原语，缺全局筛选和批量分配 owner |
| `deploy_or_upgrade_monster` | `MonsterRuntimeController` | 私有旧接口，无事务/revision；升级会刷新完整时间，违反“只增加 60 秒” |
| `deploy_or_upgrade_military` | `MilitaryRuntimeController` | 旧版全局选区和刷新逻辑；无稳定族 ID、事务、正式区域伤害梯度 |
| `player_hand_disrupt` | `PlayerHandInteractionRuntimeService` | v0.4 手牌；需同时锁定发起者与目标玩家，并进入反制窗口 |
| `player_hand_steal` | 同上 | 需卡牌实例级双玩家 CAS；目标满手的合法合成也必须处于同一事务 |
| `card_counter` | 结算队列/控制器/执行服务 | 尚无单一 owner；异步响应窗口不能被当作同步效果成功 |

## 可直接复用的能力

- 商品流和区域设施已有 `transaction_id` 幂等回执。
- 区域设施和路线已有稳定快照与 revision/拓扑指纹。
- 当前内部名为 `PlayerManaRuntimeController` 的控制器已经提供资产预留、提交、消费和释放生命周期；玩家界面必须只显示“资产”。

## 不能直接复用为 v0.6 权威状态的部分

- 旧 `CardInventoryRuntimeService` 仍使用 v0.4 结构与满手处理。
- 玩家互动和购买结算没有统一的多玩家 revision/CAS。
- 现金仍在生产玩家状态/bridge 中分散持有。
- 怪兽与军队缺少 transaction journal 和公开 v0.6 部署/升级接口。

## 接线顺序

1. 建立并接入唯一 `CardPlayerStatePortV06`。
2. 接通商品安装和设施建造/升级/修复。
3. 新建全局供需 owner。
4. 为怪兽、军队增加事务化公开 API。
5. 把玩家互动迁移为多玩家 CAS。
6. 最后统一异步反制窗口与结算队列。

当前 `main.gd`、GameRuntimeCoordinator、商品流、卡牌结算、资产控制器和卡牌可用性服务均有并发修改；本批只在 `scripts/cards/v06/`、独立测试和报告中推进，不覆盖这些 owner。

