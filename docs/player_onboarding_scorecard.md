# Player Onboarding Scorecard

评分范围：0-5。低于 4 的项必须进入下一轮修复计划。

| 项目 | 当前分 | 证据 | 下一步 |
| --- | ---: | --- | --- |
| 主菜单清晰度 | 4 | 已有星球赌桌大厅；本轮新增新手战役入口 | 继续压缩辅助入口 |
| 新手战役入口 | 4 | CampaignMenu/ProgressMap | 增加更强视觉路径 |
| 关卡目标清晰度 | 4 | CampaignBriefing + Coach；剧本“定位”现在会真实打开牌轨/牌架/经济/情报等目标 | 为后续关卡补更多目标专属动效 |
| 一步一目标 | 4 | ScenarioCoach 单主 CTA；首局 CTA 现在会自动落到推荐区域；买牌 CTA 会自动寻找合法牌架，并把星球旋转到目标区 | 卡住状态需要更多自动定位 |
| 错误反馈 | 4 | Scenario 阶段已要求 `stuck_hint` / `focus_target`；Coach 求助会显示短卡住提示；卡住态主按钮会切成真实“定位下一步”；运行桌面现在有独立 `FocusGuideLayer` 光框；剧本“定位”会打开真实目标；普通首局 `FirstRunCoach` 也会输出桌面焦点；首局 CTA 缺选区时会自动选推荐区，买牌选错区时会恢复到合法牌架并同步星球视角 | 下一轮让连续失败自动闪烁并推荐最短操作 |
| 成功反馈 | 4 | RewardPanel + action log | 增加声音/动效 |
| 奖励动机 | 4 | 解锁、徽章、推荐角色 | 后续接更多图鉴解锁 |
| 复盘质量 | 4 | MatchRecapPanel + key logs | 后续增加更多经济解释 |
| 继续游玩动机 | 4 | 推荐继续/下一关 | 增加毕业挑战后循环 |
| 多分辨率 | 4 | layout/campaign screenshot tests | 手柄焦点仍需人工测 |
| 键盘/手柄可用性 | 4 | `tests/campaign_focus_navigation_test.gd` verifies CampaignMenu、Briefing、Reward、Recap、ProgressMap default focus；`tests/runtime_table_focus_order_test.gd` verifies RuntimeGameScreen 的顶部状态、牌轨、星球地图、右侧详情、手牌、当前行动、竞价焦点顺序，牌轨槽位可用 `ui_accept` 选择，手牌卡可用 `ui_accept` 选择/二次确认出牌。 | 下一轮补逐区域/牌架卡的键盘确认动作 |
| 隐藏信息安全 | 5 | scenario/campaign privacy tests | 持续维护禁词护栏 |

## 当前最低分修复计划

1. 运行牌桌细焦点：分区焦点链已覆盖顶部、牌轨、星球、详情、手牌、行动、竞价；牌轨和手牌已经支持确认键；下一步补逐区域/牌架卡的键盘确认动作。
2. 自动定位：首局 CTA 已支持推荐区域兜底、买牌合法牌架恢复和星球视角聚焦；剧本“定位”已能打开牌轨/牌架/经济/情报等真实目标；卡住态主按钮会直接执行定位；下一步处理连续失败后的闪烁节奏和最短操作推荐。
3. 焦点高亮后续：让连续失败自动闪烁目标控件，并在必要时自动打开对应区域/牌架/详情。
