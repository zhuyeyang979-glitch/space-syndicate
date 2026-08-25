# Candidate 3 focused card-table flow evidence

This is an append-only record. The earlier `candidate_3_card_table_flow.json`
and the Candidate 2 blocker evidence remain unchanged.

```text
STATUS=PASS
PASSED=400/400
PRODUCTION_MAIN_SCENE_USED=true
FIXTURE_CARD_INJECTION_COUNT=0
FIXTURE_PUBLIC_BATCH_INJECTION_COUNT=0
FIXTURE_TRACK_PHASE_INJECTION_COUNT=0
FIXTURE_AI_ACTION_INJECTION_COUNT=0
```

The focused run used the real `res://scenes/main.tscn` production path with one
human and three AI seats. It observed three AI public-card receipts, fifteen
public arrangement entries, fifteen seat-to-arrangement animations, fifteen
formation animations, 100% card-face coverage, zero transition failures, and
no presentation gameplay or RNG mutation. The public drawer remained an
overlay (`COLLAPSIBLE_OVERLAY_POPOUT`), default-collapsed, map-visible, and
layout-neutral.

The probe exercised every rendered public face through the real hover callback
and passed its 100% hover-capability assertion with zero layout reflow. A later
diagnostic snapshot was taken after three authoritative track handoffs; those
handoffs intentionally rebuild the transient hovered-id set, so that later
snapshot's `arrangement_card_hover_coverage_percent=0.0` is a timing snapshot,
not a failed focused assertion.

The editor parse and direct runtime-owner check both exited zero. Godot MCP's
headed session remains open for the human retest and reports only pre-existing
GDScript reload warnings, with no hard runtime error.

Human Green, full production Green, and STEP13-15 remain unclaimed.
