# Space Syndicate Developer Manual

最后更新：2026-07-03
适用仓库：`zhuyeyang979-glitch/space-syndicate`
当前主线：Godot 4.x 实时 PVE roguelike 隐藏信息数字桌游原型。

## 1. 项目一句话

《太空辛迪加》不是普通 TCG，也不是纯动作怪兽游戏。它是一个重型桌游数字化原型：玩家在同一颗星球上匿名打牌、建城、争夺商品/商路、诱导自动怪兽、部署军队、竞价、猜归属，最终按现金排名。

目标阶段：让真人玩家可以和 2–7 个 AI 完整打一局，并能在不读长说明的情况下理解前 10 分钟的主要动作。

## 2. 当前核心规则意图

- 3–8 席 PVE run。
- 人类玩家对抗 AI seats。
- 玩家公开选择外星人角色；角色公开，不应绑定初始怪兽来泄露归属。
- 游戏开始时玩家选择一张 I 级怪兽牌作为首召怪兽。
- 怪兽不是持续玩家控制单位；怪兽按概率和生态自动行动。
- 玩家通过怪兽卡、诱导卡、升级和绑定技能影响怪兽。
- 玩家最多同时操控一只怪兽和一个军队；特殊角色可以提高上限。
- 军队是可控战斗力量，通过可回收指令牌执行前进、防守、摧毁、攻击怪兽等简单命令。
- 城市产生 GDP；目标是最后现金最多。
- 达到现金目标后进入终局倒计时；倒计时结束按现金排名。
- 玩家现金、手牌、弃牌、AI 私有计划是隐藏信息。
- 打出的卡牌公开展示，但打牌者默认未知，玩家通过线索猜测。
- 卡牌购买只在怪兽所在区域或相邻区域可买；打开购买窗口时检查资格。
- 买牌花现金；打牌通常检查商品流动条件，不直接消耗商品。
- 重复获得同名牌会自动升级到更高 rank；rank 用罗马数字显示。

## 3. 隐藏信息边界

玩家 UI 绝对不要显示：

- 对手真实现金。
- 对手真实手牌数量/手牌内容。
- 对手弃牌选择。
- AI 内部评分。
- AI route plan / pressure bucket / learning bonus。
- `true_owner` / `hidden_owner` / `owner_truth`。
- 未公开的城市、卡牌、怪兽真实归属。

允许存在的位置：

- internal metadata。
- test-only audit report。
- dev-only balance panel。
- save/debug structures，前提是不注入玩家-facing snapshot。

任何新 UI 或 viewmodel 都要先想一句话：玩家是通过公开线索推理，还是系统直接把答案告诉他？如果是后者，通常是错误。

## 4. 文件分层

| 层 | 目录/文件 | 原则 |
|---|---|---|
| 运行主控 | `scripts/main.gd` | 仍然很大，但新增系统不要继续塞大块公式。只保留 glue/thin wrapper。 |
| Balance 模型 | `scripts/balance/*.gd` | 局长、现金目标、移动、击退、天气、价格、统计函数。开发/测试用。 |
| Campaign | `scripts/campaign/*.gd`、`data/campaign/*.json` | 战役定义、进度、保存、奖励/复盘。 |
| Scenario | `scripts/scenario/*.gd`、`data/scenarios/*.json` | 可试玩剧本/运行夹具/visual events。 |
| ViewModel | `scripts/viewmodels/*.gd` | 把运行数据转成玩家 UI 可读数据；禁止泄露隐藏字段。 |
| UI Scenes | `scenes/ui/*.tscn` | Control + Container + Theme；不要用 Node2D/Sprite2D 搭主 UI。 |
| Tests | `tests/*.gd` | headless 可跑；涉及 UI 文本、隐私、截图、运行路径、balance。 |
| Docs | `docs/*.md` | 规则、设计、开发手册、战役设置、环境平衡。 |

## 5. Balance 脚本边界

### 5.1 `runtime_balance_model.gd`

运行期平衡 hub。它把卡牌、商品、怪兽、AI 路线、系统约束汇总成 dev-only 报告。

常用函数：

- `runtime_balance_audit_report(snapshot)`
- `statistics_hub_report(snapshot, sample_only)`
- `developer_greybox_snapshot(snapshot, enabled)`
- `card_price_for_skill(skill, district_multiplier)`
- `skill_balance_feature_vector(...)`
- `product_price_model(...)`
- `product_flow_speed_model(...)`
- `global_environment_refresh_model(...)`

### 5.2 `movement_balance_model.gd`

负责星球/区域/移动：

- `region_count_range_for_depth(depth)`
- `planet_size_for_depth(depth)`
- `region_size_model(depth, region_count)`
- `monster_movement_speed_model(actor, terrain_multiplier, action_speed_mps, region_radius_m, target_region_exit_seconds)`
- `military_movement_speed_model(unit, terrain_multiplier, command_speed_mps, region_radius_m)`

硬指标：

- 深度 I：6–9 区域；深度 VI：40–54 区域。
- 平均区域面积目标：65,000–140,000 m²。
- 普通怪兽约 10 秒离开一个区域。
- 飞行怪兽可约 10x 普通速度，但不造成普通移动践踏。
- 海洋/水栖怪兽可约 5–8x 普通速度。
- 军队接近普通移动尺度；空军/舰船有区分但不过度跨屏。

### 5.3 `combat_balance_model.gd`

负责怪兽攻击和击退：

- `monster_knockback_distance_model(action, actor, region_radius_m)`
- `monster_knockback_speed_model(action, actor, region_radius_m, duration_seconds)`
- `monster_attack_model(action, actor)`

硬指标：

- 普通近战击退约 0.85 × 区域半径。
- 击退发生在约 0.5 秒。
- 光线、投掷、冲锋、爆炸可以更远，但必须通过 profile 明确。

### 5.4 `environment_balance_model.gd`

负责天气和全局经济波动：

- `market_refresh_interval_seconds(depth, volatility_level)`
- `weather_forecast_window_seconds(depth, volatility_level)`
- `weather_duration_seconds(weather_state, depth)`
- `weather_zone_count_model(depth, region_count)`
- `weather_state_effect_model(weather_state, terrain, product_category)`
- `economic_volatility_model(...)`
- `global_environment_refresh_model(...)`

硬指标：

- 市场刷新 30–60 秒。
- 天气提前预报 60–180 秒。
- 天气影响 1–5 个区域。
- 价格波动来自供需、断路、怪兽、天气、合约压力，不直接任意改价。
- 新闻不被动触发；新闻类事件由玩家卡牌制造。

## 6. 卡牌数据原则

新卡不要只写描述文字。必须尽量字段化：

- `kind`
- `cost`
- `tags`
- `route_tags`
- `play_product`
- `play_flow_required`
- `target_player_required`
- `target_monster_required`
- `cash`
- `production_delta`
- `transport_delta`
- `consumption_delta`
- `market_demand_pressure`
- `market_supply_pressure`
- `route_damage`
- `repair_routes`
- `product_bet_*`
- `gdp_bet_*`
- `weather_*`
- `military_*`
- `hp`
- `fixed_skill_count`

AI 和 balance 统计应优先读字段，不靠卡名写特殊逻辑。

## 7. 卡面和 UI 原则

项目是桌游数字化，信息必须像桌面组件，而不是 debug 面板。

主桌优先展示：

- 中央星球。
- 手牌。
- 顶部共通时间轴/牌轨/事件轨。
- 当前可操作提示。
- 现金和终局条状倒计时。

复杂内容收进：

- 规则附录。
- 经济总览。
- 图鉴。
- 情报档案。
- 开发者灰盒。

卡牌文本：

- 玩家卡面只写关键效果，不写开发历史。
- 允许使用关键词和图标。
- 详情页再解释完整字段。
- hover 放大手牌，低分辨率也要看清。

## 8. 战役与剧本

战役设置详见 `docs/campaign_chapter_settings.md`。

原则：

- 不要堆菜单外壳；章节必须接到真实 runtime。
- 每个 chapter 的 `scenario_id` 必须能加载 fixture。
- CampaignCoach 只显示一个当前目标和一个主 CTA。
- 完成后进入 RewardPanel，再进入 MatchRecapPanel。
- 复盘解释关键行动、学到什么、下次建议。

## 9. 天气/经济/环境

全局环境详见 `docs/global_environment_balance.md`。

原则：

- 天气是公开预报，不是突然惩罚。
- 商品价格变化来自可解释 driver。
- 全球刷新周期可以存在，但 GDP/运输/投资窗口按秒运行。
- 玩家-facing UI 只显示短状态和图标；长解释进入规则附录/经济总览。

## 10. 开发者灰盒

开发者灰盒只在 dev 模式使用。当前入口：

- `scenes/ui/DeveloperBalancePanel.tscn`
- `scripts/ui/developer_balance_panel.gd`
- `SPACE_SYNDICATE_DEV_BALANCE=1`

不要把 dev-only 报告接进玩家主 UI。

## 11. 推荐测试命令

PowerShell：

```powershell
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/runtime_balance_report_test.gd
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/ui_text_smoke_test.gd
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/visual_snapshot.gd
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/layout_scene_smoke_test.gd
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/smoke_test.gd --check-only
& "..\tools\godot-4.6.2\Godot_v4.6.2-stable_win64_console.exe" --headless --path . --script res://tests/smoke_test.gd
```

有 UI/布局相关改动时，还应跑截图测试，并尽量在二号屏做有头测试，避免占用主屏。

## 12. Git 工作流

当前用户要求：每轮任务结束后，把最新改动上传 GitHub 并推到 `main`。

建议流程：

```powershell
git status --short --branch
git diff --check
git add <files>
git commit -m "<clear message>"
git push origin main
git rev-parse HEAD
git ls-remote origin refs/heads/main
```

提交前必须删除临时测试文件，例如 `tests/_tmp_*.gd`。

## 13. 常见坑

1. 不要把 `main.gd` 继续塞成所有系统的容器。新平衡公式优先拆到 `scripts/balance`。
2. 不要让玩家 UI 显示 AI 内部决策。
3. 不要把规则历史写给玩家看；玩家只需要当前规则。
4. 不要把天气/新闻做成无预告随机惩罚。
5. 不要让怪兽/军队瞬移跨区；移动和击退都应线性演出。
6. 不要因为平衡而把角色、怪兽、商品路线做成同质化。
7. 不要依赖长文本制造深度；深度来自字段、路线、反制、长期收益和统计平衡。
8. 不要恢复旧 main 的 3x3、守护者 D6、直接长期控制怪兽、被动世界事件、手动结算、旧充能模型。

## 14. 下一步优先级建议

1. 把 `main.gd` 中更多统计、AI policy、campaign glue 持续拆小，但每次小步验证。
2. 把商品生态、卡牌路线、怪兽生态接到自动模拟报告。
3. 把开发者灰盒扩展成 balance dashboard：局长、现金目标、价格波动、怪兽威胁、卡牌使用率。
4. 做 50/500 局 AI 自博弈统计，找 dead card / dead product / dead monster。
5. 把图鉴和卡面继续从开发说明书改成 TCG/电子桌游式视觉结构。
