# AI Card Static Traits and Definition Cutover

## Boundary

This atomic boundary removes AI generic Main calls for static card target traits,
definition identity, family/rank formatting, legacy flow affinity, duration
normalization, family-slot lookup, and counted-hand calculation.

Base commit: `a3eb6db2a12b3b08f5336e9c949c3df635c0cdd2`.

It does not migrate stateful card-play eligibility. GDP-share qualification,
cash/Mana authorization, live target availability, and rejection presentation
remain a separate owner-scoped boundary.

## Owner reuse

- Target traits use the existing `CardPlayEligibilityRuntimeService.target_status()`.
- Card existence, family, rank, and definitions use the existing
  `CardRuntimeDefinitionWorldBridge`.
- Legacy turn conversion uses
  `ProductMarketRuntimeController.ECONOMY_LEGACY_TURN_SECONDS`.
- Hand calculations use the actor-private detached hand projection. The local
  counted-hand helper preserves the legacy exemption for persistent monster and
  military bound actions.

No state owner, save section, RNG owner, or UI state was added.

## Removed AI routes

The following generic Main method-name routes are zero in
`AiRuntimeController`:

- `_card_play_target_snapshot`
- `_skill_play_flow_required`
- `_skill_duration_seconds`
- `_canonical_card_supply_name`
- `_card_display_name`
- `_find_highest_family_card_slot`
- `_player_counted_hand_size`

The Main constant snapshot no longer exports
`ECONOMY_LEGACY_TURN_SECONDS` to AI.

The AI-only Main helpers `_skill_play_flow_required`,
`_skill_duration_seconds`, and `_find_highest_family_card_slot` were
physically deleted. Shared human and diagnostic helpers remain.

## Evidence

- Focused static traits/definition test: PASS.
- AI card queue query: PASS.
- AI phase/counter owner: PASS.
- AI private hand query: PASS.
- Card execution typed ports: PASS.
- Stable target envelope: PASS.
- Main runtime composition: PASS.
- Main architecture: PASS.
- Formal `main.tscn` MCP play: PASS, 819 nodes, 120 FPS.
- Query world mutation: 0.
- Query RNG delta: 0.
- `git diff --check`: PASS.

Main is now 6,390 physical lines and 469 methods. AI generic
`_call_world` is 20 invocations across 19 unique method names; the full P0
generic-bridge extinction remains active.
