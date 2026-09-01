# Alpha 0.7 Living Planet — Candidate 2 repair validation 001

This append-only entry validates the narrow repair delta after
`short_retest_001`. It does not replace the original human blocker record and
does not promote automated readiness to a human pass.

```text
STATUS=GREEN_AFTER_REPAIR_AUTOMATED_ONLY
READY_FOR_REAL_HUMAN_RETEST=true
HUMAN_EXECUTED=false
HUMAN_GREEN=false
FULL_PRODUCT_PRODUCTION_GREEN=false
STEP13_STATUS=PENDING
```

Candidate subject: `46b33bba77b356b100ab68bc7c3676d503049a2c` with an
uncommitted task-owned working-tree delta. The real production scene remains
`res://scenes/main.tscn`, configured as one human plus three AI seats with no
fixture-state injection.

Automated gates:

- New-game loading feedback: `19/19 PASS`.
- Central public action arrangement: `8/8 PASS`.
- Central entries now stagger in with a short fade/scale formation animation;
  this remains presentation-only and preserves the authority-owned order.
- Human playability readiness: `182/182 PASS` on the production main scene.
- Pacing determinism: `11/11 PASS`; golden observation readiness: `35/35 PASS`.
- UI text, visual contract, and `git diff --check`: PASS.

The real production drag audit observed `drag_started=1`, `central_drop=1`,
`card_queue_submission=1`, `manual_drag_drop=1`, and `rejection=0`. The payload
was revalidated against the current private hand and then routed through the
existing legal `card.queue` path. The central arrangement remains a
presentation target: it owns no tick, RNG, hand, queue, asset, map, or card
catalog state.

The latest automated first-playable marker measured 3209 ms. The authoritative
synchronous initialization is intentionally unchanged; a three-stage loading
overlay now shows progress and records presentation-only latency. A human must
still decide whether the remaining wait feels acceptable.

Godot MCP ran the real scene under `4.7.stable.official.5b4e0cb0f`; no hard
product/runtime-owner errors were reported. The headed run later emitted one
WASAPI output-device invalidation from the local audio environment; it is
classified as an environment/runner issue and does not touch the UI or
gameplay authority. The headed window is left open for the next real human
short retest. Existing script warnings remain disclosed and are not new
Candidate 2 product failures.

The next action is the nine-item human check, especially: visible loading
feedback, normal-card acquisition with a five-card hand, central 30-second
public arrangement/hover, and dragging one legal hand card into that center.
Only after the human confirms those observations may STEP13–STEP15 proceed.
