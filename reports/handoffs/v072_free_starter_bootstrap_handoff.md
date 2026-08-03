# V0.7.2 free-Starter bootstrap handoff

STATUS=GREEN_WITH_RETAINED_BALANCE_RISKS

V0.7.2 is the frozen highest target constitution. It remains fully detached from the
production V0.6 runtime. Docs PR #84 merged as `76ffcbf1df5c122955e620b7b4a4339e3dd9a2cb`;
the historical V0.7 and V0.7.1 constitution files were not changed.

## Bootstrap contract

The six-color asset Owner exists at genesis with all six balances and remainders set to zero,
so the player projection reads `0/6`; there is no absent or uninitialized third state. Each
player receives exactly one factory and one market Starter for each color. The twelve stable
definitions are:

- `starter.facility.factory.life.rank_1`
- `starter.facility.market.life.rank_1`
- `starter.facility.factory.energy.rank_1`
- `starter.facility.market.energy.rank_1`
- `starter.facility.factory.industry.rank_1`
- `starter.facility.market.industry.rank_1`
- `starter.facility.factory.technology.rank_1`
- `starter.facility.market.technology.rank_1`
- `starter.facility.factory.commerce.rank_1`
- `starter.facility.market.commerce.rank_1`
- `starter.facility.factory.shipping.rank_1`
- `starter.facility.market.shipping.rank_1`

The zero cost is definition-owned through `starter_zero_asset`, so discard, reshuffle, Save,
and Restore cannot erase it. The unified track accepts only standard L1 definitions, whose
matching-color primary asset cost is one. Starter plus matching standard L1 is an explicit
merge into standard L2 at cost two; both sources are consumed and the free privilege is not
inherited. Track Starter spawns and post-genesis Starter creation are both zero.

## Detached contracts

Core, AI, Player, Save, RNG, and Canonical Adapter contracts target `v0.7.2`. The Save schema
persists stable definition, instance, origin, cost-profile, level, merge-family, and balance
profile identity. V0.7.1 and V0.6 direct resume both fail closed. RNG adds no stream and keeps
the existing `starter_deck_shuffle` authority. AI receives owned-card legal targets only through
a revision- and fingerprint-bound detached target-authority input; rival and stale inputs fail
closed. The Player Adapter alone maps `starter_badge=true` to `card.badge.starter`, keeping Core
and Save presentation-key agnostic.

The atomic manifest exposes all sixteen V0.7.1 and V0.7.2 readiness gates. All ten domains keep
`dual_write_allowed=false`. Production connection, V0.6 mutation, and dual-write counts are zero.
PR #80 and PR #82 remain Draft and may not merge while PR #77 is incomplete.

## Simulation result

The deterministic matrix reran three profiles at 3, 4, 6, and 8 players with 500 seeds per
configuration: 6,000 matches total. Report fingerprint:
`14b33e5ec35fcca01adcb6e5f7041b1767e1aa5400611fece8fa66718ea5654d`.
The report file SHA-256 is
`9bad085a3da2ec1407022c2798b3579c7b00618a7b9de22b81a9f46613344601`.

| Approved-profile metric | Result | Target | Verdict |
| --- | ---: | ---: | --- |
| Opening affordable Starter cards | 5 | 5 | pass |
| First facility median / P95 batch | 1 / 1 | <=1 / <=2 | pass |
| First nonzero asset refresh median / P95 batch | 2 / 2 | <=2 / <=3 | pass |
| First standard L1 play median batch | 5 | <=4 | **fail** |
| Starter action share at batch 10 | 0.634132 | <0.70 | pass, human risk retained |
| Standard-card zero-asset block rate | 0.042070 | <0.15 | pass |
| Asset overflow rate | 0.003288 | <0.20 | pass |
| Victory-pending tail P95 | 150s | <=240s | pass |
| Sunlit chain throughput ratio | 2.0 | 1.8-2.2 | pass |

The approved profile therefore retains
`FIRST_STANDARD_L1_PLAY_MEDIAN_BATCH` and `STANDARD_CARD_ASSET_ECONOMY_TOO_SLOW` as failed
balance targets. V0.7.2 still solves opening deadlock: the opening five are all affordable,
the first real facility appears in batch one, and the first nonzero asset refresh appears in
batch two. This does not prove that permanently free cards leave enough strategic room for paid
cards. `HUMAN_FUN_PROVEN=false` and `HUMAN_TEST_REQUIRED=true` remain mandatory.

## Verification

Focused gates passed: Card Registry `101/101`, Unified Track `632/632`, DBG `325/325`,
Asset/Batch `285/285`, Solar/Victory `190/190`, Save/RNG/AI/Player Adapters
`41/41`, `41/41`, `47/47`, `48/48`, Atomic Manifest `393/393`, Adapter aggregate
`24/24`, V0.7.2 three-wing aggregate `32/32`, Review `136/136`, and Simulator `438/438`.
The native OpenGL Review scene exited zero and its `1600x960` capture had no clipping or overlap.
The final `smoke_test.gd --check-only` run exited zero with no script errors or residual process.
No full Smoke or third Formal FullRun was performed. No Godot MCP endpoint was started for this
detached lane; the real Review scene was exercised by the isolated native runner instead.
