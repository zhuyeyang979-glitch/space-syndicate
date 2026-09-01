# Alpha 0.7 Living Planet - Human Candidate 2 short retest 001

This append-only record preserves the second human short playability retest at
candidate `3bf9e9b2468e4a279af47cd3be36d0660abcfe91`.

## Classification

```text
STATUS=PRE_GOLDEN_PRODUCT_USABILITY_BLOCKED
HUMAN_EXECUTED_OBSERVED=true
HUMAN_CONFIRMED=false
HUMAN_GREEN=false
STEP13_STATUS=PENDING
```

The run was performed on the real `res://scenes/main.tscn` with one human and
three AI seats. No agent input and no fixture/state injection were used.

## Nine-item result

| Item | Result | Evidence |
|---|---|---|
| 1. Normal New Game | Partial | It enters normally, but the human reports a long wait and no loading/progress feedback. |
| 2. No vertical drag/scroll | Pass | No main-table splitter or vertical table scrolling was required. |
| 3. Tutorial steps 1-2 | Pass | Tutorial can be completed or skipped. |
| 4. Coach Step 3 stability | Pass | Pointer entry no longer moves the callout and Next is usable. |
| 5. Shared-track acquisition | Fail | The hand is already full at five cards; the shared track does not expose a human-completable normal scroll/acquisition path. |
| 6. Legal hand-card play | Fail | The player cannot drag/play a card. The right-side summary exists, but the central public batch arrangement/hover presentation is missing. |
| 7. Human/AI action feedback | Partial | The right-side summary is visible and basically correct, but the central public action/card order is not visually legible. |
| 8. 1x/2x/4x pacing | Pass | All three controls work; 2x is suitable. |
| 9. Normal exit | Pass | Normal exit completed and the scoped Godot process count returned to zero. |

## Preserved verbatim human feedback

> 关于在窗口中完成的九项短测的结果：我一项一项说明，1。可以正常进入new game, 但是进入时间很长，是不是应该做一个loading条，或者看看有没有办法能够缩短进入游戏的时间，二现在确实不需要上下拖动或分隔主桌滚动。3教程可以顺利跳过或完成。4成功。5，没法正常拿牌，因为没法正常出牌，手牌是5张满的，然后寿司轨道似乎也没有正常滚动。6没法打出，因为现在玩家行动在右侧有一个小框，汇总是对的，但是因为游戏的结算规则是30秒内所有玩家打出牌进入一个排列，它需要有一个动画，就是玩家的牌在这个游戏画面的中央形成一个排列。然后它像一个Hoover一样，玩家可以在这30秒内随时查看。现在就没有这个动画，所以看不出谁打了什么牌，然后视觉上很不直观，然后我也没法正常拖拽卡牌，然后打出这一点，还没做到6，没法打出7能看到8，正常，9，正常，但是8和9不重要

## Runtime evidence

External observation session: `v076-alpha07-1787540860-db7006b993`.

The session ended cleanly, but its telemetry reports zero submitted actions,
zero normal-track purchases, one zero-action batch, and no final settlement.
Those facts are consistent with the human-reported inability to complete card
acquisition and play. The telemetry's `human_executed=false` field is retained
as-is; this record separately records the observed human interaction and does
not promote it to a Human Green claim.

Previous Candidate 1 blocker evidence and all Stage 1-4/STEP09/11/12 evidence
remain unchanged. The next work is a narrow repair of startup feedback,
shared-track acquisition/replenishment, and central public action/card-play
presentation before another human retest. STEP13-15 remain pending.
