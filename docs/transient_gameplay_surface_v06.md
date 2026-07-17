# Transient Gameplay Surface v0.6

## Goal

区域牌架、牌序竞价、下注和其他决策只在玩家主动请求或真实玩法时机出现。
主桌不长期为这些系统预留大块空间。

`OverlayLayer` only owns presentation, z-order, focus capture/restore and visual cleanup.
It never owns quotes, cards, bids, wagers, cash, timers, backlog, inventory or decision queues.

## Surface classes

### Player-opened dismissible surfaces

- 区域牌架
- 商品路线选择
- 图鉴
- 经济详情
- 区域详情

These surfaces:

- open only from an explicit player action;
- do not pause the world;
- may be closed by Back, Esc, controller cancel or a visible close action;
- restore the opener focus, or the first legal control in the restored parent;
- do not occupy layout while closed.

### Timing-triggered decision surfaces

- 怪兽战斗下注
- 牌序竞价
- 反制响应
- 合同回应
- 满手牌处理
- 怪兽目标选择
- 玩家目标选择

These surfaces exist only while their authoritative owner reports a live decision or phase.
They close automatically when the owner resolves, cancels or expires the decision.

## Region rack lifecycle

The region rack is closed on a new run.

Valid open actions are:

- double-click a region;
- click “查看牌架”;
- use the mapped keyboard/controller action while a region is selected.

Single-click only selects a region. Opening, closing, hover, scroll and reopen never refresh
the rack and never consume gameplay RNG.

### Quote lifecycle

Public preview does not create a quote. The first explicit purchase intent for a listing
requests the existing authoritative quote owner to lock:

- listing and source region;
- public eligibility facts;
- final price;
- supply revision;
- expiry at 5 seconds of `world_effective` time.

Closing the rack does not pause or extend the quote. Reopening shows remaining time when the
same quote is valid; otherwise the player must request a new quote.

Purchase success closes the rack by default. A local “连续浏览” preference may keep it open,
but cannot modify supply, quote time or transaction ownership.

## Card-order bid lifecycle

The full player-facing label is “牌序竞价”.

- The full bid surface exists only during Card Resolution phase `public_bid`.
- It is absent during `planning`, `lock`, `resolve` and `idle`.
- When it closes, the top card track keeps only a compact phase/result chip.
- Card Resolution remains the phase/timer owner.
- Existing bid/escrow/cash owners remain authoritative.
- Overlay does not keep a parallel bid amount or countdown.

## Forced-decision arbitration

`ForcedDecisionRuntimeScheduler` selects the one actionable decision surface. Owners still
own their decision state, clock and settlement.

Target priority:

| Priority | Scheduler group | Decisions | Presentation/blocking summary |
| ---: | --- | --- | --- |
| 1 | `monster_wager` | 怪兽战斗下注 | Public mandatory overlay; 15 seconds; freezes global world time; all complete may end early |
| 2 | `counter_response` | 反制响应 | Viewer-scoped overlay; blocks the incoming resolution according to the existing owner |
| 3 | `contract_response` | 合同回应 | Target-player private overlay; timer/continuation remain Contract owner facts |
| 4 | `other_choice` | 满手牌处理、怪兽目标选择、玩家目标选择 | Assigned-player private overlay; same-priority order is oldest `opened_sequence`, then stable decision ID |
| 5 | `public_bid` | 牌序竞价 | Lowest presentation priority; present only while Card Resolution is in `public_bid` |

The scheduler owns only priority, stable same-priority ordering, viewer-safe active metadata
and blocking projection. It never settles a wager, bid, counter, contract, discard or target.

When a higher decision preempts a lower surface:

- only the scheduler-selected surface is actionable;
- the hidden owner's timer behavior follows that owner's existing clock contract;
- no UI timer is invented;
- non-current players receive a short, privacy-safe hint;
- resolving the active decision reveals the next legal surface.

## Back and pause

Back handling order for gameplay surfaces:

1. Close the top dismissible detail/tooltip/player-opened overlay.
2. If a forced decision is active, consume Back without closing it and do not open pause.
3. If `public_bid` is the active scheduled surface, follow its owner-approved cancel/ready action;
   Back cannot silently opt out of a mandatory choice.
4. Close fullscreen map or other parent surface.
5. Only when no blocking/temporary surface remains may Back open pause.

Pointer, keyboard and controller use the same action route.

## Focus and cleanup

Opening a surface records:

```text
surface_id
surface_kind
focus_restore_path
opened_by_action_id
context_revision
```

On close:

- release focus capture;
- restore the opener if it exists and is focusable;
- otherwise focus the first enabled control in the restored parent;
- clear presentation snapshot and private action bindings;
- set the surface non-visible and non-layout-participating;
- leave no transparent input blocker or focusable child.

No temporary presentation node is allowed to keep a business timer running.

## 1280×720 layout contract

At `1280×720`:

- one transient surface fits without hiding its primary action;
- no two actionable modals overlap;
- the central planet remains recognizable behind dismissible surfaces;
- monster wager/public bid/contract/full-hand/target surfaces share one stable modal area;
- region rack may use a drawer or modal layout, but when closed reserves zero width;
- closed surfaces have zero layout and input footprint.

## Privacy

- Public wager/bid facts remain public only where current rules allow.
- A contract responder, discard choice or target choice is visible only to its authorized player.
- Other players see a short “另一名玩家正在决定” style hint, not the private options.
- Presentation snapshots exclude exact opponent cash, hands, private targets, owner truth,
  AI plans/scores and transaction fingerprints.
- Overlay never derives visibility from the presence of a field; it consumes an owner-filtered
  public or viewer-private snapshot.

## Save and resume

Gameplay owners save decision state, remaining authoritative time, revisions and exact-once
lineage in their existing save sections. Overlay open/closed state and focus paths are not
gameplay truth.

After load:

- scheduler recomputes the active decision from restored owner facts;
- the correct surface opens if a live decision exists;
- expired or resolved surfaces remain closed;
- quotes use restored `world_effective` expiry;
- no decision, quote, bid or purchase is replayed by presentation restoration.

## Player-facing terms

Use:

- 区域牌架
- 牌序竞价
- 怪兽战斗下注
- 反制响应
- 合同回应
- 选择弃牌
- 选择怪兽目标
- 选择玩家目标
- 查看商路
- 隐藏商路

Do not show owner/controller/world bridge, snapshot, raw state enum, internal priority group
or transaction lineage to players.

## Acceptance

`transient_gameplay_windows_v06_test.gd`, layout and full smoke must prove:

- rack closed by default;
- single-click does not open it;
- explicit open works for pointer, keyboard and controller;
- public preview creates no quote;
- explicit intent creates a 5-second quote;
- full bid surface exists only in `public_bid`;
- wager exists only during monster battle wager timing;
- counter/contract/full-hand/target surfaces exist only for real decisions;
- scheduler exposes at most one actionable surface;
- forced Back cannot open pause;
- every resolved/closed surface releases focus and layout;
- `1280×720` has no modal stacking or obscured primary action.
