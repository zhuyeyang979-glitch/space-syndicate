# Alpha 0.7 Living Planet — Human Candidate 1 blocker

Candidate `04cc8f94de909b2467bef29d74ad83a153d65955` reached the real `res://scenes/main.tscn` with one local human and three AI seats. The human run did not complete because the production UI and interaction flow were not accessible enough to play. This is a product usability blocker, not user error.

## Verbatim human evidence

1. 主画面仍是上下分屏。
2. 需要上下拖拽／移动才能访问界面。
3. 无法正常取得卡牌。
4. 无法正常打出卡牌。
5. 无法看清谁正在执行什么动作。
6. 游戏强制等待过长。
7. 教学第三步窗口在鼠标接近时跳走。
8. “下一步”按钮因此无法点击。
9. 当前版本无法正常完成真人游戏。

## Classification

```text
HUMAN_CANDIDATE_1_STATUS=BLOCKED_BY_UI_AND_INTERACTION_FLOW
READY_FOR_HUMAN_GOLDEN_RUN=false
HUMAN_EXECUTED=true
HUMAN_RUN_COMPLETED=false
HUMAN_FEEDBACK_CAPTURED=true
PRODUCT_USABILITY_BLOCKER_COUNT=9
HUMAN_ACCESSIBLE_PATH_GREEN=false
```

STEP09, STEP11, and STEP12 production evidence and STEP13 automated readiness evidence remain intact. They prove automated production paths; they did not prove that a human could access card acquisition, card play, public action feedback, pacing, or Coach navigation.

## Candidate identity and closeout

- Preflight: `D:/SpaceSyndicateTestRuns/v076/human-golden-run-001/preflight.json`, SHA-256 `bc7d88ec3c14061a14cd26b70ddd04a144a4580e586dbe674163b0afa8c3bb1a`.
- Launch receipt: `D:/SpaceSyndicateTestRuns/v076/human-golden-run-001/launch_receipt.json`, SHA-256 `6d4fd86d06b0e50c364967d836ef86969256c11ed360ebf60ba98893ccd7f7d4`.
- Expected `user://playtests/v076_alpha07` export was absent after the interrupted run. No local telemetry `build_sha` is claimed; exact candidate identity comes from the external preflight and launch receipt.
- Godot `4.7.stable.official.5b4e0cb0f` reported no hard runtime error, only disclosed pre-existing GDScript warnings.
- Candidate process count after MCP stop: `0`.
- Protected listener count on ports 7576/7586 after stop: `0`.
- Agent UI action count and state injection count: `0`.

The next real-human run must use Human Candidate 2 and restart at STEP01. Golden Human Green remains `0` until that full human retest is executed and confirmed.
