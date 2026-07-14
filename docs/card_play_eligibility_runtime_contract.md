# Card Play Eligibility Runtime Contract

## Authority

`CardPlayEligibilityRuntimeService` is the only owner of card-play legality, GDP-share requirements, v0.5 industry-requirement evaluation, cash-cost eligibility, target traits, target readiness, and stable rejection precedence. It consumes pure facts from `CardPlayEligibilityWorldBridge` and returns pure data.

`CardPresentationRuntimeService` maps `reason_code` and `reason_args` to player-facing labels, details, accents, and disabled reasons. It does not decide legality.

`CardResolutionRuntimeController` owns the active 8/6/2 card-window clock and ready state. `CardResolutionQueueRuntimeService` owns the current v0.5 tutorial/standard 1/2 group limits, fixed priority bids, cumulative capacity reservations, queue placement, and submission transaction. `CardResolutionExecutionRuntimeService` remains the lifecycle owner. None of these services duplicates eligibility rules.

## Result Envelope

Every evaluation returns `allowed`, `actionable`, `reason_code`, `reason_args`, `requirement_status`, `cash_cost`, `target_status`, `target_kind`, `target_required`, `target_ready`, and `queue_preflight`. Inputs and outputs contain only Dictionary, Array, String, Number, Bool, and null.

Stable rejection precedence preserves the existing player experience: invalid/eliminated player, game or pending-decision blocks, cooldown/lock state, starter summon placement, response-window legality, target availability, contract/city/military requirements, GDP share, cash, bid reserve, then target selection readiness.

## World Bridge

The bridge reads player cash/cooldown, district and GDP-share facts, forced-decision state, counter-window context, contract validation, city-development validation, military presence/cooldown/deployment, target counts, and Queue metadata. It does not decide, rank, mutate, format, or retain private state.

## Runtime Adapters

`main.gd` keeps only narrow adapters for collecting facts, requesting evaluation, forwarding a presentation-safe rejection log, and routing successful existing actions/signals. AI, Coach/UI, Queue submission, and Execution revalidation consume the same service result.

## Deleted Legacy Ownership

Sprint 43 deletes `_hand_card_play_state`, `_can_play_skill_now`, all `_skill_play_requirement_*` formulas, target/counter trait helpers, target-required helpers, and the old requirement audit. It also removes call-graph-closed card/balance/UI helpers left without producers after earlier cutovers. No compatibility wrapper or fallback legality owner remains.

## Privacy

Eligibility results never include hidden owner, private target, private discard, opponent hand, or AI private-plan data. Public presentation receives only stable reason and requirement/target summaries.
