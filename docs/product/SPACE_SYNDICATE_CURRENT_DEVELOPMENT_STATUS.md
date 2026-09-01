# Current Development Status

GENERATED_FROM=SPACE_SYNDICATE_PRODUCT_CONTINUITY_REGISTRY.json


The current V0.7.6 candidate is not Human Green. Golden STEP13, STEP14, and STEP15 remain pending. Commercial Presentation M1 is BLOCKED_REUSE_GATE_GOVERNANCE; the next consolidated human playtest remains deferred.

## Active work

| ID | Status | Priority | Next task | Dependencies |
| --- | --- | --- | --- | --- |
| work.v076.human_candidate_4_short_retest | BLOCKED_HUMAN | P0 | defer the consolidated human retest until Commercial Presentation M1 and the Reuse gate are green; Human Green remains false | product.public_arrangement, product.general_hand |
| work.v076.drag_pointer_retest | IN_PROGRESS | P0 | run focused real-pointer gate after headed session is released | product.public_arrangement |
| work.v076.step13_to_15 | PLANNED_NEXT | P0 | do not start before HUMAN_GREEN | work.v076.human_candidate_4_short_retest |
| work.v076.full_tail_handoff | BLOCKED_PRODUCT | P1 | repair authority on fresh authorized head; keep separate from UI candidate |  |
| work.v076.card_certification | PLANNED_NEXT | P1 | certify families incrementally without changing catalog Owner | product.card_catalog |
| work.v076.monster_mapping | PLANNED_NEXT | P1 | create exact mapping evidence on new authorized head | product.v076.monster_geodesic_move |
| work.v076.observatory_enhancement | PLANNED_NEXT | P2 | schedule after current Golden boundary | product.combat_observatory |
| work.v076.release_tag | PLANNED_NEXT | P0 | remain draft until all release requirements pass | work.v076.step13_to_15, work.v076.card_certification |
| V076-WORK-FACILITY-MAP-VISUAL | IN_PROGRESS | HUMAN_RETEST_BLOCKER | retain the committed automated proof and defer headed facility-marker confirmation until Commercial Presentation M1 and the Reuse gate are green | product.facilities, product.planet_map |
| V076-WORK-HAND-POST-QUEUE-STABILITY | IN_PROGRESS | HUMAN_RETEST_BLOCKER | retain the committed automated proof and defer headed hand drag/click confirmation until Commercial Presentation M1 and the Reuse gate are green | product.general_hand, product.commodity_hand, product.public_arrangement |
| V076-WORK-AUTHORITATIVE-CLOCK-LIVENESS | IN_PROGRESS | HUMAN_RETEST_BLOCKER | retain the committed automated proof and defer headed countdown/expiry confirmation until Commercial Presentation M1 and the Reuse gate are green | product.application.new_game_setup |
| V076-WORK-SUBMISSION-COUNTDOWN-BAR | IN_PROGRESS | HUMAN_RETEST_BLOCKER | retain the committed automated proof and defer headed countdown visibility confirmation until Commercial Presentation M1 and the Reuse gate are green | product.application.new_game_setup |
| V076-WORK-RESOLUTION-THEATER | IN_PROGRESS | HUMAN_RETEST_BLOCKER | deferred until Commercial Presentation M1 and the Reuse gate are green; afterward, repair the resolution drawer visibility and focused card animation on the current candidate before the next short retest | product.public_arrangement, product.action_feed, product.planet_map |
| V076-WORK-FACILITY-TYPE-MODELS | IN_PROGRESS | HUMAN_RETEST_BLOCKER | restore distinct committed facility visuals without introducing a second facility owner | product.facilities, product.planet_map |
| V076-WORK-HAND-CONTROL-OVERLAP | IN_PROGRESS | HUMAN_RETEST_BLOCKER | deferred until Commercial Presentation M1 and the Reuse gate are green; afterward, repair hand control lifetime and stale overlap before the next short retest | product.general_hand, product.commodity_hand, product.public_arrangement |
| V076-WORK-POST-RESOLUTION-LOOP | IN_PROGRESS | HUMAN_RETEST_BLOCKER | deferred until Commercial Presentation M1 and the Reuse gate are green; afterward, repair the post-resolution loop before the next short retest | product.shared_sushi_track, product.action_feed, product.application.new_game_setup |
| V076-WORK-FIXED-30S-ACTION-WINDOW | IN_PROGRESS | HUMAN_RETEST_BLOCKER | deferred until Commercial Presentation M1 and the Reuse gate are green; afterward, repair the fixed 30-second action window presentation before the next short retest | product.application.new_game_setup, product.shared_sushi_track |
| V076-WORK-SUSHI-AUTHORITATIVE-HANDOFF | IN_PROGRESS | HUMAN_RETEST_BLOCKER | deferred until Commercial Presentation M1 and the Reuse gate are green; afterward, await the next headed human retest; keep the single Shared Sushi Track Owner and HUMAN_GREEN=false | product.shared_sushi_track, product.action_feed |
| V076-WORK-SECOND-COMMODITY-ACQUISITION | IN_PROGRESS | HUMAN_RETEST_BLOCKER | confirm the second legal opportunity and exact-once claim in the headed human retest | product.commodity_hand, product.shared_sushi_track, work.v076.post_resolution_loop |
| V076-WORK-DUAL-HAND-CONTINUITY | IN_PROGRESS | HUMAN_RETEST_BLOCKER | deferred until Commercial Presentation M1 and the Reuse gate are green; afterward, confirm both hand rows remain visible and usable in headed production UI | product.general_hand, product.commodity_hand, V076-WORK-HAND-POST-QUEUE-STABILITY, V076-WORK-HAND-CONTROL-OVERLAP |
| V076-WORK-POST-CARD-CLOCK-LIVENESS | IN_PROGRESS | HUMAN_RETEST_BLOCKER | deferred until Commercial Presentation M1 and the Reuse gate are green; afterward, confirm the read-only countdown behavior in headed production UI | V076-WORK-AUTHORITATIVE-CLOCK-LIVENESS, V076-WORK-FIXED-30S-ACTION-WINDOW |
| V076-WORK-FACILITY-MAP-PERSISTENCE | IN_PROGRESS | HUMAN_RETEST_BLOCKER | confirm the committed facility model persists visibly in the headed next action window | product.facilities, product.planet_map, V076-WORK-FACILITY-MAP-VISUAL, V076-WORK-FACILITY-TYPE-MODELS |
| V076-WORK-REAL-SECOND-COMMODITY-ACQUIRE | IN_PROGRESS | HUMAN_RETEST_BLOCKER | deferred until Commercial Presentation M1 and the Reuse gate are green; afterward, capture the real second commodity pointer acquisition in the Candidate 5 headed short retest | product.commodity_hand, product.shared_sushi_track, V076-WORK-SECOND-COMMODITY-ACQUISITION, V076-WORK-SCREEN-SPACE-SUSHI-HANDOFF |
| V076-WORK-RESOLUTION-SIDECAR | IN_PROGRESS | HUMAN_RETEST_BLOCKER | deferred until Commercial Presentation M1 and the Reuse gate are green; afterward, confirm sidecar auto-open, focused-card containment, zero planet-center occlusion, and auto-close in the Candidate 5 headed short retest | product.public_arrangement, product.action_feed, product.planet_map, V076-WORK-RESOLUTION-THEATER |
| V076-WORK-CARD-TO-MAP-EFFECT-LINK | IN_PROGRESS | HUMAN_RETEST_BLOCKER | deferred until Commercial Presentation M1 and the Reuse gate are green; afterward, capture the focused card, target-region link, and authority-receipt parity in the Candidate 5 headed short retest | product.public_arrangement, product.planet_map, product.facilities, V076-WORK-RESOLUTION-SIDECAR, V076-WORK-FACILITY-MAP-VISUAL |
| V076-WORK-HUMAN-VISIBLE-FACILITY-MODELS | IN_PROGRESS | HUMAN_RETEST_BLOCKER | deferred until Commercial Presentation M1 and the Reuse gate are green; afterward, capture one committed facility model appearing and persisting on both map surfaces in the Candidate 5 headed short retest | product.facilities, product.planet_map, V076-WORK-FACILITY-TYPE-MODELS, V076-WORK-FACILITY-MAP-PERSISTENCE |
| V076-WORK-SCREEN-SPACE-SUSHI-HANDOFF | IN_PROGRESS | HUMAN_RETEST_BLOCKER | deferred until Commercial Presentation M1 and the Reuse gate are green; afterward, capture before, middle, and after screen rects for three authoritative handoffs in the Candidate 5 headed short retest | product.shared_sushi_track, product.action_feed, V076-WORK-SUSHI-AUTHORITATIVE-HANDOFF |
| V076-WORK-FIXED-30S-VISIBLE-COUNTDOWN | IN_PROGRESS | HUMAN_RETEST_BLOCKER | defer headed Candidate 5 capture until Commercial Presentation Milestone 1 is green; preserve the screen-space evidence gap | product.application.new_game_setup, V076-WORK-FIXED-30S-ACTION-WINDOW, V076-WORK-SUBMISSION-COUNTDOWN-BAR |
| SPACE-SYNDICATE-WORK-COMMERCIAL-PRESENTATION-M1 | BLOCKED_EXTERNAL | P0 | obtain an explicit governance decision for an exact transition-bound historical metadata correction, or authorize a history rewrite; keep PR #93 Draft/red and do not resume human playtest meanwhile | product.card_catalog, product.combat_observatory, product.facilities, product.shared_sushi_track, product.application.main_menu |


## Release requirements
- `Space Syndicate Version Continuity Gate`
- `V076 Reuse and Point-Inertia Gate`
- `HUMAN_GREEN=true with observer attestation`
- `STEP13 Victory Qualification pass`
- `STEP14 FinalSettlement exactly once`
- `STEP15 feedback and clean stop`
- `no silent active capability loss`
- `no silent production surface loss`
- `no asset removal without disposition`