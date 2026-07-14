# Tomorrow human playtest checklist

Status: acceptance skeleton installed; coordinator owns final Godot 4.7 MCP and headed execution.

## Safety preflight

- Use the QA run-save override under `user://space_syndicate_design_qa/test_runs/`; never select or overwrite the production save slot.
- Detect displays at runtime. Run headed evidence on a non-primary display only; if unavailable, report the blocker and do not occupy display 1.
- Target 1600×960. If display 2 is smaller, use the Bench's 1600×960 SubViewport and label the evidence as scaled.

## Play path

1. Open the real menu and start a three-seat run with one human and two AI seats.
   - The root lobby itself must expose a `new_run` action and open `NewGameSetupPage`.
   - With no active run, closing the menu must keep a usable menu visible; an empty table is a failure.
   - AI setup cards must not reveal an exact starter-monster/card identity before play.
2. Select a legal region and play the human starter-monster card through the normal hand action.
   - Require one finalized v0.6 monster lifecycle receipt and one authoritative roster increment; a legacy summon alone is insufficient.
3. Confirm one authoritative human city/facility and observe a real CommodityFlow income receipt.
4. Open the landed/adjacent regional supply, inspect its visible cards, and buy exactly one legal card.
   - The production card catalog and the opened rack must contain at least one rank-I `public_facility`.
   - Switching the rack to an AI seat must not reveal that AI's exact cash, hand count, or hand contents.
5. Play one legal core-economic card through production dispatch; confirm one commit and no duplicate effect on replay/settling frames.
   - After setup, `CoreEconomicCardRuntimeAdapterV06.debug_snapshot().configured` must be true.
   - `CardPlayerStateProductionAdapterV06.actor_player_indices()` must contain the human and both AI seats.
   - Require one committed+finalized CardFlow journal row, one player revision increment, and one facility increment.
6. Confirm both AI seats exist and at least one AI performs first summon, city/facility construction, and another public action without deadlock.
7. Observe the real 10-second victory qualification and 120-second public audit; do not invoke a final-menu shortcut.
8. Confirm settlement/recap opens once from the authoritative victory receipt.
9. Inspect all visible labels, buttons, tooltips, logs, public snapshots, and recap for rival cash/hand/discard, hidden owner truth, and AI-private route/plan leakage.
10. Save and load only the QA path, then confirm the default production save hash is unchanged.

## Evidence to capture

- One 1600×960 screenshot on display 2 after final settlement, with the display mode noted as native or scaled.
- Bench summary line, manifest path, debug errors, stop `finalErrors`, QA save path, and default-save pre/post hash.
- A PASS/FAIL row for every step above; failures must name the blocking owner/API.
- Treat `main_scene_unavailable`, missing v0.6 finalized receipts, absent CoreEconomic actor bindings, no Sale Receipt, or a non-empty privacy leak list as real FAIL—not skipped or pending.
