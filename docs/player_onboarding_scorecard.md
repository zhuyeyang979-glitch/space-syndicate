# Player Onboarding Scorecard

评分范围：0-5。低于 4 的项必须进入下一轮修复计划。

| 项目 | 当前分 | 证据 | 下一步 |
| --- | ---: | --- | --- |
| 主菜单清晰度 | 4 | 已有星球赌桌大厅；本轮新增新手战役入口 | 继续压缩辅助入口 |
| 新手战役入口 | 4 | CampaignMenu/ProgressMap | 增加更强视觉路径 |
| 关卡目标清晰度 | 4 | CampaignBriefing + Coach | 为每关补更多真实动作定位 |
| 一步一目标 | 4 | ScenarioCoach 单主 CTA；首局 CTA 现在会自动落到推荐区域；买牌 CTA 会自动寻找合法牌架，并把星球旋转到目标区 | 卡住状态需要更多自动定位 |
| 错误反馈 | 4 | Scenario 阶段已要求 `stuck_hint` / `focus_target`；Coach 求助会显示短卡住提示；运行桌面现在有独立 `FocusGuideLayer` 光框；普通首局 `FirstRunCoach` 也会输出桌面焦点；首局 CTA 缺选区时会自动选推荐区，买牌选错区时会恢复到合法牌架并同步星球视角 | 下一轮把连续失败直接转成自动打开对应页面/抽屉 |
| 成功反馈 | 4 | RewardPanel + action log | 增加声音/动效 |
| 奖励动机 | 4 | 解锁、徽章、推荐角色 | 后续接更多图鉴解锁 |
| 复盘质量 | 4 | MatchRecapPanel + key logs | 后续增加更多经济解释 |
| 继续游玩动机 | 4 | 推荐继续/下一关 | 增加毕业挑战后循环 |
| 多分辨率 | 4 | layout/campaign screenshot tests | 手柄焦点仍需人工测 |
| 键盘/手柄可用性 | 4 | `tests/campaign_focus_navigation_test.gd` verifies CampaignMenu、Briefing、Reward、Recap、ProgressMap default focus, stable dynamic button names, and keyboard/gamepad reachable action buttons. | 下一轮补运行牌桌内手牌/牌轨/地图的完整焦点顺序 |
| 隐藏信息安全 | 5 | scenario/campaign privacy tests | 持续维护禁词护栏 |

## 当前最低分修复计划

1. 运行牌桌焦点：补手牌、牌轨、地图、牌架抽屉之间的完整键盘/手柄焦点顺序。
2. 自动定位：首局 CTA 已支持推荐区域兜底、买牌合法牌架恢复和星球视角聚焦；下一步处理连续失败后自动打开对应区域/牌架/详情。
3. 焦点高亮后续：让连续失败自动闪烁目标控件，并在必要时自动打开对应区域/牌架/详情。
