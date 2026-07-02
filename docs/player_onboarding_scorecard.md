# Player Onboarding Scorecard

评分范围：0-5。低于 4 的项必须进入下一轮修复计划。

| 项目 | 当前分 | 证据 | 下一步 |
| --- | ---: | --- | --- |
| 主菜单清晰度 | 4 | 已有星球赌桌大厅；本轮新增新手战役入口 | 继续压缩辅助入口 |
| 新手战役入口 | 4 | CampaignMenu/ProgressMap | 增加更强视觉路径 |
| 关卡目标清晰度 | 4 | CampaignBriefing + Coach | 为每关补更多真实动作定位 |
| 一步一目标 | 4 | ScenarioCoach 单主 CTA | 卡住状态需要更多自动定位 |
| 错误反馈 | 3 | 已有 failure_hints 数据 | 下一轮接真实失败计数 |
| 成功反馈 | 4 | RewardPanel + action log | 增加声音/动效 |
| 奖励动机 | 4 | 解锁、徽章、推荐角色 | 后续接更多图鉴解锁 |
| 复盘质量 | 4 | MatchRecapPanel + key logs | 后续增加更多经济解释 |
| 继续游玩动机 | 4 | 推荐继续/下一关 | 增加毕业挑战后循环 |
| 多分辨率 | 4 | layout/campaign screenshot tests | 手柄焦点仍需人工测 |
| 键盘/手柄可用性 | 3 | Button focus mode | 下一轮补完整焦点顺序测试 |
| 隐藏信息安全 | 5 | scenario/campaign privacy tests | 持续维护禁词护栏 |

## 当前最低分修复计划

1. 错误反馈：把失败操作和卡住 20 秒接入真实统计。
2. 键盘/手柄：为 Campaign 场景增加更明确的 focus neighbor。
3. 自动定位：连续失败后打开对应区域/牌架/详情。
