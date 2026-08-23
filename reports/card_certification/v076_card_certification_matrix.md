# V0.7.6 card certification matrix

This matrix is bound to the focused Profile/Crosswalk/ETA/lifecycle/typed-sink
implementation at `d1675d8027cf4e4d790f0d91f5e407d4cf68c8a7`.
`CHANGE_CLASS=CROSS_DOMAIN_INTEGRATION`; the scoped Crosswalk and inherited
sentinels ran, while unrelated full-catalog production certification did not.

## What is actually inherited

- The V0.6 semantic source contains 348 stable card IDs in 87 complete I-IV
  families. Its JSON SHA-256 is
  `b59b73489d23578558d4a7688a03f50a3ef4d776cf528cd9eafd0e1d2a0fcb40`.
- PR #62 established deterministic compile readiness: 256 active and 92
  projection-only definitions. "Active" here is compiler readiness, not a
  production execution or human-play claim.
- PR #63 established passive AI/PlayerFace projection and privacy boundaries.
- PR #65 established capability-bound source membership and replay/collision
  rejection patterns.
- PR #90 supplies V0.7.5 group-level combat capability lineage. It does not
  establish one-to-one V0.7.6 mapping for every card.

## Category posture

| Category | Cards / families | Semantic posture | Runtime evidence inherited | V0.7.6 exact mapping | Per-card production pass |
|---|---:|---|---|---|---|
| Commodity | 184 / 46 | Active compile readiness | Isolated real-owner adapter evidence | `UNVERIFIED` | Not claimed |
| Facility | 64 / 16 | Active compile readiness | Isolated real-owner adapter evidence | `UNVERIFIED` | Not claimed |
| Supply/demand | 8 / 2 | Active compile readiness | Isolated owner/batch test evidence | `UNVERIFIED` | Not claimed |
| Interaction/counter | 12 / 3 | Projection-only | No inherited execution certification | `UNVERIFIED` | Not claimed |
| Monster | 32 / 8 | Projection-only | V0.7.5 group capability evidence only | `UNVERIFIED` — exact directional-move mappings verified: 0 | Not claimed |
| Military | 28 / 7 | Projection-only | V0.7.6 Stage 4 isolated Profile/Crosswalk/ETA/arrive-execute-withdraw plus existing typed facility/monster sinks | `ISOLATED_GREEN_28_OF_28` — 0 `REAUTHOR_REQUIRED` | Not claimed |
| Organization | 20 / 5 | Projection-only | Owner metadata remains pending | `UNVERIFIED` | Not claimed |

The three active cohorts total 256; the four projection-only cohorts total 92.
All 348 catalog rows still carry `catalog_ready_runtime_wiring_pending`. Effect
review remains pending for 104 rows: 64 facility rent profiles, 32 monster unit
profiles, and 8 legacy interaction effects. The 28 military Profile reviews are
closed only at the isolated authoring/mapping layer.

Stage 3's isolated Monster L1 route proves deterministic movement and replay,
but it is not a card route and certifies none of the 32 monster catalog rows.
The military Crosswalk closes all 28 source identities and fingerprints. The
three frozen V0.7.5 active families retain twelve inherited combat Profiles;
all 28 speeds and the sixteen Profiles for four former-gap families are explicit
reversible V0.7.6 playtest authority. No legacy protection, terrain, cooldown,
or persistent-unit value was guessed into an assault rule. Physical ETA is
isolated green with 1,000 seeds, 2,000 replays, 0 mismatch, and 0 teleport. The
registered lifecycle reducer is `29/29`; the same STEP10 Bench is `41/41` and
records two arrival roots, four Kernel-derived continuations, two
Profile-authored one-shot attacks, facility/monster receipts `1/1`, monster HP
`20 -> 17`, and zero replay/order/direct-reducer/duplicate damage mismatch.
Facility damage reuses `V075RuntimeOwner`; monster damage reuses the existing
active-step mutation pipeline. This still does not certify production
composition, `main.tscn`, or human play.

## Monotonic certification axes

Each category now carries the same 12 machine fields:
`CATALOG_VALID`, `SEMANTIC_COMPILED`, `TARGET_QUERY_GREEN`, `PLAN_GREEN`,
`COMMIT_GREEN`, `RECEIPT_GREEN`, `PLAYER_PROJECTION_GREEN`,
`AI_PROJECTION_GREEN`, `PRIVACY_GREEN`, `EXACT_ONCE_GREEN`, `REPLAY_GREEN`,
and `ALPHA07_CERTIFIED`. A field may move only from `false` to `true`, or from
`true` to `REGRESSED_WITH_EVIDENCE` with bound failure evidence. The schema
does not certify any new card in this task: Alpha 0.7 certified remains zero,
because production composition and human play were not performed.

`PRODUCTION_CARD_CERTIFICATION_COMPLETE=false`

`PER_CARD_PRODUCTION_PASS_CLAIM_COUNT=0`

`HUMAN_PLAY_CERTIFIED_CARD_CLAIM_COUNT=0`
