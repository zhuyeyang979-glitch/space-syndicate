# Player Onboarding Scorecard

评分范围：0-5。低于 4 的项必须进入下一轮修复计划。

| 项目 | 当前分 | 证据 | 下一步 |
| --- | ---: | --- | --- |
| 主菜单清晰度 | 4 | 已有星球赌桌大厅；本轮新增新手战役入口 | 继续压缩辅助入口 |
| 新手战役入口 | 4 | CampaignMenu/ProgressMap；CampaignMenu 新增“开桌→练四步→完整局”三步路径轨 | 真人复验是否能直接理解从战役进入试玩 |
| 关卡目标清晰度 | 4 | CampaignBriefing 三张摘要卡 + Coach；剧本“定位”现在会真实打开牌轨/牌架/经济/情报等目标；强卡住态会显示最短操作 | 真人复验摘要卡是否足够支撑直接开始 |
| 一步一目标 | 4 | ScenarioCoach 单主 CTA；首局 CTA 现在会自动落到推荐区域；买牌 CTA 会自动寻找合法牌架，并把星球旋转到目标区；星球旁试玩罗盘显示已完成/当前/待办和下一步短句，并已覆盖点区→首召→建城→买牌→出牌→牌轨→经济→路线；重复卡住仍只保留一个“定位下一步”主 CTA | 真人复验首局 10 分钟 |
| 错误反馈 | 4 | Scenario 阶段已要求 `stuck_hint` / `focus_target`；Coach 求助会显示短卡住提示；连续求助会进入强卡住态，FocusGuide 脉冲目标并显示“最短：……”；卡住态主按钮会切成真实“定位下一步”；运行桌面现在有独立 `FocusGuideLayer` 光框；剧本“定位”会打开真实目标；普通首局 `FirstRunCoach` 也会输出桌面焦点；首局 CTA 缺选区时会自动选推荐区，买牌选错区时会恢复到合法牌架并同步星球视角 | 真人观察哪些目标还需要专属动效 |
| 成功反馈 | 4 | RewardPanel 四张结算摘要卡 + action log | 增加声音/动效 |
| 奖励动机 | 4 | 解锁、徽章、推荐角色；RewardPanel 把表现/目标/解锁/下一步做成短卡 | 后续接更多图鉴解锁 |
| 复盘质量 | 4 | MatchRecapPanel 四张复盘摘要卡 + 四张经济解释卡 + key logs | 后续观察真人是否能说出“钱从哪里来” |
| 继续游玩动机 | 4 | 推荐继续/下一关 | 增加毕业挑战后循环 |
| 多分辨率 | 4 | layout/campaign screenshot tests | 手柄焦点仍需人工测 |
| 键盘/手柄可用性 | 4 | `tests/campaign_focus_navigation_test.gd` verifies CampaignMenu、Briefing、Reward、Recap、ProgressMap default focus；`tests/runtime_table_focus_order_test.gd` verifies RuntimeGameScreen 的顶部状态、牌轨、星球地图、右侧详情、手牌、当前行动、竞价焦点顺序，牌轨槽位可用 `ui_accept` 选择，手牌卡可用 `ui_accept` 选择/二次确认出牌，区域牌架卡可用 `ui_accept` 预览并尝试购买；`tests/map_view_focus_rotation_test.gd` verifies 星球地图焦点下方向键可切换区域、同步旋转到目标区域，并用确认键打开牌架。 | 下一轮做真人手柄型号复验和连续失败高亮 |
| 隐藏信息安全 | 5 | scenario/campaign privacy tests | 持续维护禁词护栏 |

## 当前最低分修复计划

1. 运行牌桌细焦点：分区焦点链已覆盖顶部、牌轨、星球、详情、手牌、行动、竞价；牌轨、手牌和区域牌架卡已经支持确认键；星球地图焦点下方向键会切区并旋转到目标区域，确认键可打开牌架；星球旁试玩罗盘已改为覆盖路线选择的状态化芯片；下一步做真人手柄型号复验。
2. 自动定位：首局 CTA 已支持推荐区域兜底、买牌合法牌架恢复和星球视角聚焦；剧本“定位”已能打开牌轨/牌架/经济/情报等真实目标；连续卡住时主按钮会直接执行定位，目标光框会脉冲并显示最短操作；下一步真人观察是否还需要更强目标专属动效。
3. 战役入口与完成反馈：CampaignMenu 已加入三步路径轨，CampaignBriefing 已加入目标/能做/收获三张摘要卡，RewardPanel 已加入表现/目标/解锁/下一步四张结算卡，MatchRecapPanel 已加入关键行动/学到/下次建议/回看四张复盘卡，并新增现金、城市/GDP、投入、风险抓手四张经济解释卡；下一步真人复验是否能说出“钱从哪里来、下局先抓什么”。
