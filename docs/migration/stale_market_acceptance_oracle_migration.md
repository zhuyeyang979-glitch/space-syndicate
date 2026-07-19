# Stale Market Acceptance Oracle Migration

## Scope

This test-only migration updates `v06_market_acceptance_contract_test.gd` after the onboarding fixture retirement and regional-rack terminology cutover. Production code, scenes, the rulebook, quick reference, Main, Setup, and gameplay routing are unchanged.

## Classification

- Five active source files must exist and remain free of 31 retired implementation fragments.
- `res://tests/human_first_table_playability_v06_test.gd` is expected to be physically absent. It was deleted with the obsolete onboarding campaign and is not restored.
- The rulebook must contain the current clause: `打开区域牌架、浏览挂牌或保持牌架窗口可见都不暂停`.
- The rulebook must not contain the complete retired clause: `打开普通牌市场、浏览挂牌或保持市场界面可见都不暂停`.
- Generic uses of `普通牌市场` remain valid where they describe supply, fairness, Codex labels, summon feedback, or role passives; this migration does not ban those words.

The reference scan found seven active matches across tests, scripts, and tools: one deleted-fixture path reference, one exact retired sentence, and five additional generic wording references. The first two were the stale oracle defects addressed here. Historical documentation still contains an obsolete runnable command in `docs/human_first_table_playability_gate_v06.md`; that is separate documentation debt.

## Authority Review

No market-rule authority conflict was found. The current rulebook, quick reference, and runtime owners agree on regional racks, a 120-second solar rotation, five-second quotes, monster-pressure pricing, and true-pause clock behavior. All market math and timing assertions remain intact, and the gate retains at least 83 checks.

## Negative Guarantees

- Production changes: 0
- Scene changes: 0
- Restored deleted fixtures: 0
- Restored Main wrappers: 0
- Gameplay-routing changes: 0
