# 区域天气系统 v1 验收报告

> 日期：2026-07-15
> 分支：`codex/a-v06-local-integration`
> 阶段候选：`codex/a-v06-local-integration`（最终发布 SHA 见本阶段 `main` 提交）
> 引擎：Godot 4.7 stable，`C:\Users\zhuye\AppData\Local\Programs\Godot\4.7\Godot_v4.7-stable_win64.exe`
> Runner：`tools/invoke_godot_test.ps1`，阻塞等待真实 ExitCode，并隔离日志与进程清理

## 结论

区域天气 v1 已形成可运行的最小闭环：六种天气全部由资源定义，使用唯一 `world_effective_us` 时钟完成预报、生效、线性消退和结束；经济、路线、怪兽、军事/情报、区域伤害与三处公共 UI 消费同一结构化效果和解释。存档继续使用现有 19-owner envelope 中的 `weather` section，没有增加第二时钟或第 20 个存档 owner。

Focused 天气门禁全部通过。完整 `layout_scene_smoke_test.gd` 当前为 52 条红灯；Monster Codex 三条陈旧 oracle 已退出失败列表，最早脚本问题是 `military_runtime_characterization_bench.gd` 的类型推断失败，随后还有已退役 Coordinator API 与真实 1280x720 越界问题。完整 `smoke_test.gd` 在 240 秒门槛超时回收；它已通过 Monster Codex 公开 I/IV 概率门，随后首个业务失败是角色图鉴，首个脚本错误是调用已删除的 Main `_capture_run_state`。两次 runner 均确认本工作树残留运行进程为 0，因此二者都不能报告为通过。Godot 引擎级 `--check-only` 独立通过。

## 实现边界

- `WeatherDefinition` 与 `resources/weather/*.tres`：六种天气的身份、时长、标签、倍率、提示和安全上限。
- `WeatherRuntimeState`、`WeatherSystem`、`WeatherRuntimeController`：事件状态、区域选择、队列、并发上限和唯一存档 owner。
- `WeatherEffectResolver`：强度、抵抗、利用倍率和各通道安全边界的纯计算。
- `WeatherRuntimeWorldBridge`：共享 RNG、公开区域活动与权威非致命区域伤害请求；不拥有规则或状态。
- `WeatherForecastViewModel`、`WeatherPresentationRuntimeService`、`WeatherMapOverlay`、`WeatherForecastStrip`：纯公开数据到地图、区域详情和经济解释的展示链。
- `WeatherTelemetryRuntimeService`：仅本机内存统计，无网络、无存档 API、无玩家身份或私密状态。
- `main.gd` 只推进 Coordinator、转发公开快照和匿名行为类别；天气定义、生命周期、倍率、存档与 UI 构造均不在 Main 中。

## 生命周期与调度

- 新局前 90 秒不生成自然天气。
- 自然预报间隔 90 至 150 个 world-effective 秒。
- 预报 30 至 60 秒，生效 45 至 90 秒，最后 10 秒线性消退。
- 同时最多两个未结束事件；v1 每个事件影响一个区域；同一区域冲突进入等待队列。
- 区域选择优先考虑公开城市、路线、活怪兽和交易活动，并惩罚最近连续命中的区域。
- 真暂停冻结唯一世界时钟；市场等非模态界面不冻结天气。
- 结算倒计时开始后不再生成新预报，已有事件自然结束。
- `source_type` 已支持 `natural`、`monster`、`card`，v1 自动生成仅启用 `natural`。

## 六种天气的确定性平衡样本

以下数据来自生产 `WeatherEffectResolver` 的 18 个确定性验收样本，每种天气三个样本。它们是规则贡献，不是玩家实现金额；完整逐区域明细见 [weather_v1_balance_report.md](weather_v1_balance_report.md)。

| 天气 | 平均预报/生效/消退 | 主要可利用收益 | 主要风险 | 怪兽决策证据 |
| --- | --- | --- | --- | --- |
| 离子风暴 | 30/45/10 秒 | 价格增长贡献平均 `+20%`，空运效率平均 `+18%` | 飞行风险；电磁怪兽加速 | 标签不匹配样本 `0/3` |
| 引力潮 | 45/75/10 秒 | 击退/轨道通道增强 | 路线效率平均 `-22.92%`，海运/重型陆地受限 | 标签不匹配样本 `0/3` |
| 孢子季 | 40/70/10 秒 | 生物、药品、食品生产与需求 | 污染路线效率平均 `-7.33%` | 标签匹配评分受影响 `3/3` |
| 晶尘暴 | 35/55/10 秒 | 晶体生产 | 远程减益；三样本合计 2 点非致命区域磨损 | 标签不匹配样本 `0/3` |
| 极寒期 | 60/90/10 秒 | 食品和能源需求机会 | 路线效率平均 `-27.50%`，陆地移动/维持压力 | 标签不匹配样本 `0/3` |
| 太阳耀斑 | 30/45/10 秒 | 价格增长贡献平均 `+24.58%` | 电子生产与情报持续时间/范围减益 | 标签匹配评分受影响 `3/3` |

所有样本均受以下硬上限保护：路线有效效率不低于 40%，怪兽速度增益不超过 30%，军事/情报减益不超过 30%，正向经济天气贡献限制在基线通道的 10% 至 30%。晶尘暴伤害只能经区域伤害 owner 提交，单事件封顶且至少保留 1 点区域生命。

## 玩家干预与可解释性

- `weather_resistance` 默认 `0`，仅缩小天气相对 identity `1.0` 的正负 delta。
- `weather_exploitation_multiplier` 默认 `1`，只放大正向 delta，不放大负面影响。
- 地图层显示区域图标、阶段和倒计时，层级位于区域/城市之下且不遮挡路线、怪兽与选区。
- 区域详情显示当前或即将到来的天气、阶段、剩余时间、最多三项主要效果、利用提示和反制提示。
- 经济和路线解释保留同一公开 `event_id`、天气名称和贡献行，玩家能追溯生产、需求、价格增长或有效运输变化。
- 新预报使用非阻塞提示，可跳转区域，不暂停游戏也不要求关闭模态窗口。
- 已有天气控制与航线预报卡通过明确 action/tag 接口接入；本轮没有新增卡牌家族。

## 遥测边界

本地遥测记录天气数量、定义、命中区域、价格增长贡献、路线效率贡献、预报后的路线/买牌/建城/出牌行为类别、怪兽目标评分是否受天气影响、实际区域伤害，以及由已提交公开 CommodityFlow receipt 得出的匿名保守经济估值。

遥测不保存玩家索引、真实 owner、精确现金、手牌/弃牌、卡牌身份、私密怪兽目标/权重、AI 计划、镜头、存档 payload，也没有网络上传路径。确定性报告不伪造真人响应或成交，因此响应计数为 0、实现金额为 `N/A`。

## 自动化验收

| 门禁 | 结果 |
| --- | --- |
| Weather v1 core | PASS `278/278` |
| 商品分类标签 | PASS `292/292` |
| 经济集成 | PASS `107/107` |
| 路线集成 | PASS `45/45` |
| 怪兽集成与 AI 评分 | PASS `86/86` |
| 军事/情报集成 | PASS `37/37` |
| 区域非致命伤害 | PASS `77/77` |
| 遥测 service | PASS `90/90` |
| 生产遥测接线 | PASS `13/13` |
| 天气存档/隐私 | PASS `50/50` |
| 展示 runtime service | PASS `10/10` |
| 展示 ViewModel | PASS |
| 展示隐私 | PASS |
| 展示场景集成 | PASS `14/14` |
| 天气卡牌/AI action | PASS `49/49` |
| 真实 `main.tscn` Weather Characterization | PASS `53/53` |
| 平衡报告生成 | PASS，18 samples / 6 definitions |
| RuntimeCardCatalogResourceBench | PASS `80/80` |
| RuntimeCardAuthoringWorkflowBench | PASS `36/36` |
| v0.6 catalog gate | PASS `2894/2894` |
| `smoke_test.gd --check-only` | PASS |
| `ui_text_smoke_test.gd` | PASS |
| `visual_snapshot.gd` | PASS |
| `main_runtime_composition_test.gd` | PASS |
| 完整 `layout_scene_smoke_test.gd` | FAIL，52 条；Monster Codex 陈旧项已清零，仍含 Military bench 解析、旧 API 与真实 1280 越界 |
| 完整 `smoke_test.gd` | TIMEOUT `240s`；公开 Monster I/IV 概率门已过，首个业务失败为角色图鉴，首个脚本错误为退役 `_capture_run_state` |

## 视觉证据

仓库内可移植证据：

- [三分辨率真实主桌最小生产验收](../reports/ui/production_acceptance/e_minimal_production_acceptance.md)
- [forecast / active / fading / 双区域 active 生命周期验收](../reports/ui/production_acceptance/e_weather_lifecycle/e_weather_lifecycle_acceptance.md)
- [修正后的双区域 active 主桌](../reports/ui/production_acceptance/e_weather_lifecycle/e_weather_dual_active_table_1600x960.png)

三种分辨率的机器标识、QA 存档残留和 console error 门均通过。生命周期 capture 进一步要求完整主桌连续稳定 8 个 post-draw 帧并再等待 3 帧，随后检查 TopBar、左右栏、PlayerBoard、HandRack、BidBoard 的 scene-tree 矩形和真实 PNG 像素覆盖；修正后的双天气截图相对 forecast/active 的最低覆盖比约为 `0.98`，高于 `0.85` 门槛。城市 marker 因现有测试驱动 API 已退役而仍为精确红灯，不能把静态层级证据冒充实际城市像素证据。人工检查同时确认地图标签、路线节点、天气卡和怪兽 token 仍明显拥挤。

## 最终产品问题

- 玩家能否在天气到来前理解将发生什么？能。预报公开区域、时长、三项主效果、利用和反制提示。
- 玩家能否利用或规避天气？能。正负效果混合存在，路线/市场/部署可提前调整，并提供 resistance/exploitation 接口。
- 玩家能否解释商品和路线为什么变化？能。经济与路线 owner 输出同一事件的结构化贡献，而不是直接覆盖最终值。
- 天气是否改变决策而不只是随机惩罚？是。六种天气均同时提供机会与风险，怪兽和商品标签会改变不同席位的相对收益。
- 天气结束后是否恢复正常？focused economy、route、monster、military/intel 与 lifecycle 门禁均验证结束后回到 identity；无永久 modifier。

## 未关闭风险

1. 完整布局套件仍有 52 条红灯。Military characterization 的解析/API 漂移与历史 v0.4/v0.5 oracle 应按 owner 分块处理；TopBar、PlayerBoard、HandRack 和 MainActionDock 的 1280x720 越界是可见产品问题，不能通过删除断言处理。
2. 完整 monolithic smoke 在 240 秒后回收。角色图鉴是当前首个业务失败，多个区块仍调用退役 `_capture_run_state` 等 Main wrapper；应迁移到现役 owner fixture，不得恢复兼容农场。
3. 真实主桌仍有地图标签、路线节点、天气卡和怪兽 token 重叠，1280 密度与经济文本墙尤其明显；经济页重复打开还存在间歇滚动位置复用。
4. 当前平衡报告是确定性 resolver 样本，不是长期真人试玩统计。真实平均收益、路线收入和行为反应必须由后续本地 playtest telemetry 累积后再调参。
