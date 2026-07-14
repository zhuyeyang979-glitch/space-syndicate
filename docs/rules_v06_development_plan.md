# 《太空辛迪加》v0.6 运行时开发计划

> 状态：SS06-05 已完成六色资产、8/6/2 卡窗与动态胜利切换，下一步 SS06-06，2026-07-14。
> 玩家行为语义：`docs/tabletop_rulebook_v06.md`。
> 运行时边界：`docs/rules_v06_runtime_directive.md`。
> v0.5 证据：`docs/rules_v05_development_plan.md`，只读历史基线。

## 1. 方向结论

v0.6 不是在 v0.5 项目经济上继续加规则，而是更换经济世界模型：

- 五项目位、项目份额和项目归属 GDP 替换为唯一公共设施、永久商品安装量和商品成交回执。
- 产业容量档位替换为玩家自己的六色法力池；Queue 不再预留产业容量。
- 区域/设施分散生命替换为由设施等级贡献推导出的区域共享生命池。
- 固定胜利深度替换为存续区域覆盖率和每个所需区域的 GDP 基准。
- 旧项目合约、抽象路线生命、财务危机售牌和非单位直接伤害退出未来设计。

现有 Queue、Execution、Card Inventory、Monster、Military、Presentation 和 Victory Controller 的单一所有权边界继续保留，但它们必须改为消费 v0.6 的 typed snapshot 或 receipt。不得建立 v0.5/v0.6 运行时 selector、双 owner 或自动 fallback。

## 2. 立即停止的旧路线

以下未开始工作不再执行：

- SS05-06 项目到项目的 exact-product 合约。
- SS05-07 项目控制竞猜和建立在项目身份上的跟踪。
- SS05-09 项目墓碑驱动的区域生命周期。
- SS05-10 财务危机倒计时和紧急售牌。
- 继续扩展产业容量档位、项目份额或固定胜利深度的卡牌与 UI。

SS05-05 的 64/64、Queue 56/56、Runtime Track 14/14 和 FirstMission 37/37 保留为迁移证据。它们证明旧领域的真实行为，不构成 v0.6 产品要求。

## 3. 原子迁移顺序

| 工单 | 内容 | 必须删除的旧所有权 | 主要退出门 |
| --- | --- | --- | --- |
| SS06-00 | 可恢复 pre-v0.6 基线、v0.6 Profile、controller/save 版本握手、Region Infrastructure characterization | 无；只冻结与刻画 | clean clone、哈希、Profile/characterization gate |
| SS06-01 | Public Facility + Region Shared HP Hard Cutover | 五项目位 mutation、city/area/facility 独立 HP writer、项目墓碑生命周期 | 建造/升级/修复、共享伤害、废墟/复兴、mixed-owner 证据 |
| SS06-02 | Installed Commodity + Continuous Economy + Sale Receipt | 一次性项目生产/需求、项目 GDP、并行现金/GDP 写入 | 固定点流量、瓶颈、公平分配、租金、单一成交回执守恒 |
| SS06-03 | Multimodal Route + Warehouse Cutover | 路线牌所有权、抽象 route HP/damage、单模式假设 | 路径合法性、tag set、最短距离、重寻路、回压与溢出 |
| SS06-04 | Six Mana + Card Cost + Card Window Alignment | IndustryCapacityRuntimeService、WorldBridge、Queue 容量预留、项目产业要求 | 六色恢复、商品免费打出、非商品法力支付、8/6/2、每人最多 3 张 |
| SS06-05 | Dynamic Victory And Audit Ordering | 固定深度表、项目归属胜利输入 | ceil 覆盖率、动态摧毁/复兴、同刻事件顺序、审计隐私 |
| SS06-06 | Commodity Inventory And Persistent Installation | 非商品式商品购买、默认同族自动升级 | 履带免费领取、手动合成、满手例外、永久安装 exact-once |
| SS06-07 | Viewer-Scoped Commodity Belt | 全轨公开或仅视觉模糊的实现 | GDP 档位、同分、全零、颜色级删减、stale claim、AI 同视野 |
| SS06-08 | Monster/Military Shared-HP And Wager Alignment | 非单位伤害、怪兽时长刷新、旧抽象区域/路线伤害 | 唯一伤害 owner、目标压力、延时、整场赌局、公共池守恒 |
| SS06-09 | Bankruptcy, Neutral Estate, Save, AI And Player Text | 财务危机售牌、旧 save envelope、v0.5 文案 fallback | 即时破产、中立租金入池、新局存档、AI parity、typed localized text |
| SS06-10 | First Playable v0.6 Content And Balance | 仅删除已被新内容替代的 fixture | 3/4/8 人、2-7 AI、固定种子长局、真人试玩入口 |

每个 Hard Cutover 必须在同一原子提交中完成新 owner、调用方、存档/回执、测试和旧写路径删除。Characterization 可以先行，但不得把第二套 mutation engine 留在生产场景中。

## 4. SS06-00 的精确范围

下一步只做基础和行为刻画，不提前迁移经济：

1. 为当前 SS05-05 集成状态建立可恢复 commit、clean-clone 证据和不可变 baseline tag；名称必须说明它是 pre-v0.6 集成基线，不能冒充完整 v0.5 发布版。
2. 新增 Inspector 可编辑的 v0.6 Ruleset Profile，至少收录设施生命贡献、40% 动态覆盖率、36 GDP/min 每区基准、8/6/2 卡窗、标准三张、30 秒 GDP/法力观察窗、六色法力上限和商品履带刷新参数。
3. 新增 Region Infrastructure characterization registry/bench，只读取真实 main/GameRuntimeCoordinator，刻画现有 city/project/HP writer、伤害调用图、建造/升级/修复、存档键和删除候选。
4. 冻结 v0.6 Region、Facility、Installation、Route、SaleReceipt、Mana 与 BeltVisibility 的纯数据 schema；不在本轮接管 mutation。
5. 新增 save handshake，明确 v0.6 必须新开局，旧 v0.4/v0.5 存档只能识别和备份，不能推断设施产权或续打。
6. 保持生产 Ruleset bridge、Card Catalog 和 save owner 不切换；`main.gd` 不新增新规则算法。

## 5. 保留与删除策略

继续使用：

- `CardResolutionQueueRuntimeService` 的承诺、排序和原子入队边界。
- `CardResolutionExecutionRuntimeService` 的窄生命周期边界。
- `CardInventoryRuntimeService` 的普通手牌和合成 mutation 所有权。
- `MonsterRuntimeController`、`MilitaryRuntimeController` 的单位生命周期所有权。
- `VictoryControlRuntimeController` 的资格、审计和 outcome receipt 所有权。
- Presentation/ViewModel 的 typed public/private snapshot 边界。

按领域切换后删除：

- CityTrade 的项目槽、份额、generation/tombstone 和项目 GDP owner。
- Industry Capacity Service/Bridge 及 Queue reservation/save/debug 字段。
- 固定 victory depth table 与拒绝动态覆盖率的 validator。
- 旧合约响应和项目间 agreement state。
- 抽象 route HP、普通牌直接生命伤害和财务危机售牌。

历史 Bench 可以保留为手动迁移证据，但在对应 owner 删除后必须退出当前 conformance 聚合，不得迫使生产代码保留 wrapper 或 fallback。

## 6. 跨领域硬门

- 只有 Monster/Military 可以提交共享生命伤害请求。
- `max_hp` 只从设施列表推导，不能作为独立可写状态保存。
- 一单位最终成交只生成一个 sale receipt；现金、租金、GDP 和法力都消费同一 receipt。
- 先按 viewer 删除不可见字段，再生成文字、tooltip、无障碍名称或 AI 输入。
- 同时间戳严格执行：锁定 intent -> 建造/修复 -> 单位攻击 -> 共享 HP/生命周期 -> 路线重建 -> 连续流量 -> 成交 -> 破产 -> 履带视野 -> 胜利。
- 3、4、8 人和 2-7 AI 必须进入发布门；UI 截图不能代替规则证据。

## 7. 下一步

SS06-00 至 SS06-05 已完成：v0.6 Profile/save-v3 握手、公共设施与共享生命、固定点连续商品流、唯一 Sale Receipt、多式路线、六色仓库、背压、六色资产支付、8/6/2 卡窗和动态胜利均已有单一运行时 owner。`PlayerManaRuntimeController` 以成交回执恢复六色资产并提供 exact-once reserve/consume/release；Queue 只消费支付授权。`VictoryControlRuntimeController` 以当前存续区域数动态计算 `K=ceil(A*40%)` 与 `K*36 GDP/min`，并在攻击、流量、破产结算后的同帧检查点完成审计。SS06-04 聚焦门为 32/32，SS06-05 Victory 门为 54/54，Godot 场景可加载且无新增 parse/runtime error。

下一步进入 **SS06-06 Commodity Inventory And Persistent Installation**。继续保留 `CardInventoryRuntimeService` 的普通手牌/合成 ownership，并把商品履带免费领取、满手同名商品自动合成一次、商品永久安装、设施摧毁时安装量移除和 exact-once 安装 receipt 接到现有 `CommodityFlowRuntimeController` / Region Infrastructure 边界。不得复制另一位 agent 正在开发的 v0.6 Card Flow 或 CardUI；开始前先审计其最新提交和公开 API，再只迁移仍由旧 runtime 持有的商品库存与安装 ownership。
