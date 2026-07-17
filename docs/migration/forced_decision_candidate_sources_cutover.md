# ForcedDecisionCandidateSources cutover

Status: complete prerequisite for the authoritative RuntimeLoop cutover.

The production `GameRuntimeCoordinator` now composes exactly one
`ForcedDecisionCandidateSources` and one `CardTargetChoiceRuntimeController`.
The candidate source is a pure, typed projection into
`ForcedDecisionRuntimeScheduler`; it owns no wager, contract, purchase,
target, card, cash, timer, or priority state.

Authoritative sources are:

- `MonsterRuntimeController` for active monster wagers;
- `CardResolutionRuntimeController` plus the queue public snapshot for the
  counter-response window;
- `ContractRuntimeController` for contract responses;
- `DistrictPurchaseRuntimeController` for private full-hand discard choices;
- `CardTargetChoiceRuntimeController` for monster/player target bindings.

`scripts/main.gd` no longer synthesizes candidate dictionaries and no longer
owns the pending discard or target-choice fields. Existing player-facing
presentation methods consume viewer-scoped snapshots from these owners until
the later presentation-action-routing cutover.

Privacy gates:

- the aggregate debug snapshot exposes only count, kinds, and fingerprint;
- discard candidates contain no card, quote, price, hand, or discard option;
- target candidates contain no card, slot, or target options;
- counter candidates use the public resolution id and expose no actor;
- Scheduler remains the only visibility and priority arbiter.

Evidence:

- `res://tests/forced_decision_candidate_sources_cutover_test.gd`: 28/28;
- `res://scenes/tools/ForcedDecisionCandidateSourcesBench.tscn`: 7/7 via
  Godot 4.7 MCP;
- `res://tests/main_gd_architecture_gate_test.gd`: 43/43;
- `res://tests/main_runtime_composition_test.gd`: pass;
- `res://tests/ui_text_smoke_test.gd`: pass;
- `res://tests/smoke_test.gd --check-only`: pass.

The next prerequisite is the card-resolution frame-driving boundary. Its
transition sinks must be scene-owned before the driver can become active; no
driver may call Main or run beside Main's current path.
