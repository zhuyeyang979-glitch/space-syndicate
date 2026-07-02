# Campaign Runtime Path v2 验收目标

本轮只做真实运行路径，不继续堆菜单外壳、不改规则公式、不改 MapView/BidBoard/CardTrack/VisualEventLayer 主逻辑。

硬性验收：

1. `tutorial_campaign.json` 的 10 个 chapter 都必须通过 `scenario_id` 加载到对应 scenario 和 runtime fixture。
2. `first_table`、`monster_pressure`、`public_track_intro`、`bid_practice` 的 fixture 必须导出 `visual_events`，并可被 `ScenarioLabShowcaseAdapter` 标准化。
3. `CampaignBriefing` 的“开始本关”必须进入 `scenes/main.tscn` 中真实 `RuntimeGameScreen`，不是停在菜单、静态 demo 或 showcase。
4. 主桌必须显示当前 campaign/scenario objective，并且只有一个主 CTA；点击 CTA 只能定位/提示，不能伪造完成。
5. 只有真实 `success_conditions` 完成后，才能进入 `CampaignRewardPanel`。
6. `CampaignRewardPanel` 后必须能进入 `MatchRecapPanel`。
7. `MatchRecapPanel` 数据必须包含关键行动、学到什么、下次建议。
8. `campaign_progress.save` 必须保存已完成和已解锁关卡。
9. 玩家 UI 不得显示对手现金、对手手牌、AI 私有计划、`true_owner`、`hidden_owner`、`owner_truth`。
10. 需要输出四张真实 runtime 截图：
    - `campaign_first_table_runtime_1600x960.png`
    - `campaign_monster_pressure_runtime_1600x960.png`
    - `campaign_public_track_runtime_1600x960.png`
    - `campaign_bid_practice_runtime_1600x960.png`

对应自动验收入口：

- `tests/campaign_runtime_path_v2_test.gd`
- `tests/campaign_runtime_flow_test.gd`
- `tests/campaign_privacy_test.gd`
- `tests/campaign_snapshot_capture.gd`
