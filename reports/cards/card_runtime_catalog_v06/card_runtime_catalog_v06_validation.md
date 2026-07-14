# 《太空辛迪加》v0.6 卡牌目录与基础流程验证

日期：2026-07-14

## 结论

当前已经把所有已有正式名称的卡牌落实为可索引、可购买/领取、可合成、可预检打出的 v0.6 数据：82 个卡牌家族，共 328 张 I–IV 级卡牌。目录构建、玩家文本隔离和独立卡牌流程均通过 Godot 4.7 验证。

这不等于 328 张牌的全部效果已经接入生产主场景。商品、设施、怪兽、军队、供需和玩家互动仍需逐类接入各自的权威运行时所有者；未接入效果会在扣牌和扣资产前被拒绝。

## 目录范围

| 类别 | 家族 | I–IV 卡牌 | 效果仍需确认 |
|---|---:|---:|---:|
| 商品牌 | 46 | 184 | 0 |
| 公共设施牌 | 16 | 64 | 64 |
| 供需牌 | 2 | 8 | 0 |
| 怪兽牌 | 8 | 32 | 32 |
| 军队牌 | 7 | 28 | 28 |
| 玩家互动牌 | 3 | 12 | 8 |
| 合计 | 82 | 328 | 132 |

生成文件：`data/cards/card_runtime_catalog_v06.json`

SHA-256：`2D219FC5D309889BCDD61F008936A51F058F4092A2A24BBA04239B62A9D153A6`

连续两次通过真实 Godot MCP 运行构建器，文件哈希保持一致。

## 已落实的基础流程

- 五张普通手牌上限。
- 未满手时，同名同级牌作为两张独立牌进入手牌，不强制合成。
- 满手时，取得同名同级 I–III 牌会自动完成一次合成；IV 级不能继续合成。
- 玩家可主动选择两张同名同级牌合成。
- 满手且没有合法同名合成时拒绝拿牌，不弃牌、不卖牌、不丢牌。
- 商品履带领取和商品牌打出均不支付现金或资产。
- 动态市场购买先检查手牌，再扣一次现金；成功后要求立即刷新。
- 打出前检查目标、效果所有者和资产；未接入效果不会消耗卡牌。
- 玩家提示始终提供“为什么不能做”和“下一步怎么做”。
- 通用资产不是第七个池；它由六色资产任意组合支付。
- 权威牌源使用 item ID 和 revision；同一履带牌或市场牌只能有一个成功领取者。
- 成功购买、现金扣款和市场立即刷新在同一事务中完成；相同 transaction ID 重放不会重复扣款或刷新。
- 打出使用效果 `prepare/commit` 两阶段协议；效果提交失败时恢复卡牌、六色资产和玩家 revision。
- 效果收据绑定玩家、卡牌实例、效果类型、目标、payload 和事务 intent，错配收据不能消费卡牌。
- 商品安装与设施建造/升级/修复 adapters 已接到真实 `CommodityFlowRuntimeController` 和 `RegionInfrastructureRuntimeController`；不合法槽位、他人设施、错色商品和过期 region revision 均在消费前拒绝。

## 玩家术语与字段边界

- 玩家统一看到“资产”“六色资产”“通用资产”。
- v0.6 卡牌机器字段使用 `asset_cost`、`assets`、`asset_debit`。
- 玩家卡牌文本中的旧术语泄漏数为 0。
- `card_id`、`family_id`、`reason_code`、资源路径、许可、哈希、raw error 和实现状态不会进入玩家文本。
- 生产规则/存档中尚存的旧 `mana` 键是待版本化迁移的内部兼容面，不得显示给玩家。

## Godot 验证

- Godot：`4.7.stable.official.5b4e0cb0f`
- 项目：`space-syndicate-sync`
- `card_runtime_catalog_v06_test.gd`：PASS，1363 项，0 失败。
- `card_flow_policy_v06_test.gd`：PASS，37 项，0 失败。
- `card_flow_transaction_service_v06_test.gd`：PASS，56 项，0 失败；服务不再私存 `_players`，只通过可注入状态端口读写玩家状态。
- `card_core_effect_adapters_v06_test.gd`：PASS，34 项，0 失败。
- `card_player_state_port_v06_test.gd`：PASS，65 项，0 失败；覆盖双玩家预留/CAS、偷牌实例移动、竞争锁、深拷贝、提交/中止与幂等重放。
- `ui_text_smoke_test.gd`：PASS。
- `asset_terminology_v06_test.gd`：PASS，661 项，0 失败；覆盖 328 张牌机器字段/玩家文本、Skin Lab、玩家规则书和右侧检查器。
- `card_global_supply_demand_v06_test.gd`：PASS，122 项，0 失败；覆盖 8 张供需等级牌、GDP 权益聚合、整数分配、容量再分配、多式联运、原子 sink、回滚与重放。
- `card_illustration_layer_test.gd`：PASS；六张代表牌、v02 伪字形修复图、路径回退与共享插画层均通过。
- `CardRuntimeCatalogV06Builder.tscn`：328 张、82 家族、132 张待效果复核，`errors=[]`。
- `CardFlowV06Bench.tscn`：满手合成、满手拒绝、履带领取、市场购买、未接入效果拒绝、效果成功后消费、六色支付通用资产均为 `code=OK`。
- `CardFlowTransactionV06Bench.tscn`：履带单一赢家、市场原子刷新、事务幂等重放、效果失败回滚与六色资产均为 `code=OK`。
- `CardCoreEffectAdaptersV06Bench.tscn`：真实设施控制器与商品流控制器集成，13 项全部通过。
- `CardGlobalSupplyDemandV06Bench.tscn`：权益 planner 与 fake atomic batch sink 10 项全部通过；明确输出 `production_batch_sink=BLOCKED`。
- 所有 MCP 停止结果均为 `finalErrors=[]`。

范围说明：目标 v0.6 场景与本批测试没有错误。全项目 editor class scan 另行发现 `military_runtime_characterization_bench.gd` 约第 612 行之后存在并发工作区的类型推断错误；该文件不属于本批所有权，未被修改，也不计为本批新增错误。

## 尚未解除的发布阻塞

1. 六色商品家族当前为 `11 / 10 / 6 / 4 / 9 / 6`。若每色统一为 11 个，还需命名并接入 20 个商品家族，即 80 张等级牌；最终目标为 102 家族、408 张牌。
2. 生产主场景仍由另一工作流迁移运行时所有权。本批没有覆盖 `main.gd`、GameRuntimeCoordinator、商品流、区域设施、AI、存档或结算 owner。
3. `CardPlayerStatePortV06` reference 实现已经通过 65 项测试，事务服务也已彻底移除私有 `_players/_player_reservations` 并改为只经可注入端口读写。生产环境仍需由当前运行时 owner 提供真实 port adapter，禁止把 reference memory port 当作第二份生产状态。
4. 132 张牌的租金、修复、怪兽/军队动作数值和两种玩家互动效果仍是待确认或临时数值。
5. 供需牌的权益算法和两阶段 adapter 已完成，但现有 CommodityFlow 缺少同时支持一次性订单、一次性供货和 rollback 的原子 batch API；在真实 sink 接入前，adapter 会失败闭合并退回牌与资产。
