# V0.7.5 Dynamic Map Distance Scale Audit

## Outcome

The current distance inputs do not match the V0.7.4 dynamic globe scale.

- `MAP_GENESIS_RECEIPTS_ACCEPTED=120/120`
- `MOVEMENT_BUDGET_180_TO_400_MATCH=false`
- `TRAMPLE_DISTANCE_STEP_80_MATCH=false`
- `RECOMMENDED_MOVEMENT_BUDGET_TUNABLE_RANGE=2000000_TO_3000000`
- `RECOMMENDED_TRAMPLE_STEP_TUNABLE_RANGE=200000_TO_300000`
- `BALANCE_DEFAULT_CHANGE_COUNT=0`

The smallest of 6,491 sampled adjacent edges is `531,250 milli_arc`.
Movement budgets `180` and `400` therefore cover no adjacent edge and cannot
move a monster out of its starting region under the current whole-edge budget
rule. The current trample step of `80` yields between `3,320` and `21,076`
steps for one aggregated region segment, with a median of `5,902`; that scale
causes the cap to dominate rather than preserving useful distance bands.

This is an audit recommendation only. Constitution, Balance Defaults, Godot
Core, scenes, resources, and tests were not changed.

## Real Map Method

The audit ran at source commit
`fb5414557da2a2131defb43528c08df9f4f6df5c` and called the production
`V074MapGenesisCore.generate(MapGenesisRequestV1.build(...))` path. Every
accepted receipt was converted through
`V075MonsterAutonomyCore.topology_snapshot_from_map_receipt`.

Inputs read from each real receipt were only:

- `region_ids`
- `adjacency_graph`
- `region_centers_unit_sphere`

The topology adapter derives each adjacency edge as the quantized great-circle
angle between unit-sphere region centers, using `1,000,000` integer
`milli_arc` units per radian. Paths use deterministic sorted-adjacency BFS;
path distance is the integer sum of its edges. No camera, screen pixel,
polygon vertex, or microcell-count input participates in the result, and path
distance is not accumulated as a float.

Every undirected adjacency edge was sampled once. Every unordered region pair
whose sorted-BFS shortest path had exactly two or three hops was sampled.
Movement-receipt region segments were reproduced by splitting each edge
between its endpoint regions with integer division, then aggregating repeated
regions once per path.

Player count is retained as requested scenario metadata. V0.7.4
`MapGenesisRequestV1` has no player-count field; seed, region count, geography
complexity, and the `BALANCED` land/ocean profile determine the generated map.

## Sample Matrix

Each configuration used the same 24 deterministic seeds, for 120 receipts in
total. All 120 receipts and all 120 topology snapshots were accepted.

| Players | Regions | Complexity | Maps | Edge samples | 2-hop samples | 3-hop samples | Region segments |
| ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 3 | 8 | Simple | 24 | 426 | 246 | 0 | 738 |
| 4 | 16 | Standard | 24 | 984 | 1,341 | 555 | 6,243 |
| 4 | 24 | Complex | 24 | 1,571 | 2,450 | 2,079 | 15,666 |
| 6 | 24 | Standard | 24 | 1,551 | 2,428 | 2,077 | 15,592 |
| 8 | 30 | Complex | 24 | 1,959 | 3,380 | 3,401 | 23,744 |
| **Total** | | | **120** | **6,491** | **9,845** | **8,112** | **61,983** |

The sampled 8-region Simple graphs had diameter at most two, so they contained
no exactly-three-hop shortest path. This is observed topology, not a failed or
omitted sample.

Seeds:

`900626424, 900731153, 900835882, 900940611, 901045340, 901150069, 901254798, 901359527, 901464256, 901568985, 901673714, 901778443, 901883172, 901987901, 902092630, 902197359, 902302088, 902406817, 902511546, 902616275, 902721004, 902825733, 902930462, 903035191`

## Distance Distributions

Values below are integer `milli_arc`. Percentiles use nearest-rank ceiling.

| Configuration | Series | Min | P25 | P50 | P75 | P95 | Max |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 3P / 8R / Simple | edge | 1,075,445 | 1,223,530 | 1,366,334 | 1,498,393 | 1,744,213 | 1,917,261 |
| | 2-hop | 2,295,108 | 2,535,158 | 2,720,862 | 2,847,613 | 3,316,559 | 3,372,255 |
| | 3-hop | n/a | n/a | n/a | n/a | n/a | n/a |
| | region segment | 537,722 | 638,591 | 749,561 | 1,267,579 | 1,587,334 | 1,686,128 |
| 4P / 16R / Standard | edge | 750,458 | 875,550 | 936,717 | 1,075,878 | 1,253,431 | 1,394,980 |
| | 2-hop | 1,567,203 | 1,815,529 | 1,926,892 | 2,124,783 | 2,362,978 | 2,685,923 |
| | 3-hop | 2,420,160 | 2,819,722 | 2,987,597 | 3,099,178 | 3,374,102 | 3,794,123 |
| | region segment | 375,229 | 462,692 | 571,832 | 943,181 | 1,101,880 | 1,342,962 |
| 4P / 24R / Complex | edge | 610,838 | 713,552 | 773,267 | 873,915 | 986,007 | 1,180,821 |
| | 2-hop | 1,271,105 | 1,476,341 | 1,597,589 | 1,709,549 | 1,883,464 | 2,178,264 |
| | 3-hop | 1,949,443 | 2,286,316 | 2,430,982 | 2,579,217 | 2,770,677 | 3,016,034 |
| | region segment | 305,419 | 382,339 | 469,542 | 785,726 | 923,815 | 1,089,132 |
| 6P / 24R / Standard | edge | 588,431 | 713,181 | 772,256 | 864,175 | 975,128 | 1,090,728 |
| | 2-hop | 1,242,917 | 1,474,609 | 1,586,630 | 1,698,732 | 1,868,695 | 2,017,394 |
| | 3-hop | 1,926,284 | 2,275,839 | 2,414,608 | 2,558,312 | 2,752,032 | 2,927,499 |
| | region segment | 294,215 | 381,112 | 465,945 | 778,569 | 910,093 | 1,008,697 |
| 8P / 30R / Complex | edge | 531,250 | 639,177 | 673,768 | 785,850 | 923,374 | 1,033,230 |
| | 2-hop | 1,115,161 | 1,313,476 | 1,435,655 | 1,561,842 | 1,747,085 | 1,938,610 |
| | 3-hop | 1,697,126 | 2,065,246 | 2,199,536 | 2,351,115 | 2,572,727 | 2,869,176 |
| | region segment | 265,625 | 335,277 | 447,292 | 711,634 | 841,741 | 969,305 |
| **Overall** | **edge** | **531,250** | **692,438** | **788,476** | **912,635** | **1,262,034** | **1,917,261** |
| | **2-hop** | **1,115,161** | **1,435,655** | **1,579,344** | **1,751,151** | **2,175,198** | **3,372,255** |
| | **3-hop** | **1,697,126** | **2,178,450** | **2,352,260** | **2,533,888** | **2,894,706** | **3,794,123** |
| | **region segment** | **265,625** | **374,434** | **472,209** | **761,352** | **932,425** | **1,686,128** |

As region count rises, adjacent centers are closer and edge distances generally
fall. Geography complexity does not inject boundary complexity into distance;
only center geodesics and adjacency participate.

## Movement Verdict

`movement_budget_milli_arc=180..400` is off-scale. Both endpoints cover:

- `0 / 6,491` adjacent edges
- `0 / 9,845` exactly-two-hop shortest paths
- `0 / 8,112` exactly-three-hop shortest paths

The Core consumes whole edges. A budget below the first edge leaves the
movement path at its origin, so scaling cannot be repaired by animation or by
waiting for another frame.

Candidate coverage across all samples:

| Budget | Adjacent edge | 2-hop | 3-hop |
| ---: | ---: | ---: | ---: |
| 1,100,000 | 90.31% | 0.00% | 0.00% |
| 1,250,000 | 94.70% | 1.94% | 0.00% |
| 1,600,000 | 99.25% | 53.46% | 0.00% |
| 2,000,000 | 100.00% | 91.66% | 7.61% |
| 2,400,000 | 100.00% | 97.25% | 57.62% |
| 3,000,000 | 100.00% | 99.56% | 96.87% |

Recommended tunable range: `2,000,000..3,000,000 milli_arc`, with
`2,400,000` as the first simulation anchor.

- `2,000,000` is rounded above the sampled maximum adjacent edge of
  `1,917,261`, preventing budget-induced one-edge stalls in this corpus.
- `3,000,000` reaches nearly all sampled two- and three-hop paths. Raising the
  ceiling further should require combat-cadence simulation because it can
  collapse several movement batches into one.

The range is evidence for a future Balance Defaults decision, not a change
made by this audit.

## Trample Verdict

The relevant distribution is the distance aggregated per region in the
Movement Receipt, not full path length. Its overall median is `472,209`, P75
is `761,352`, and P95 is `932,425 milli_arc`.

| Step distance | Min steps | P50 | P75 | P95 | Max | Mean |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 80 | 3,320 | 5,902 | 9,516 | 11,655 | 21,076 | 7,125.07 |
| 200,000 | 1 | 2 | 3 | 4 | 8 | 2.33 |
| 250,000 | 1 | 1 | 3 | 3 | 6 | 1.76 |
| 300,000 | 1 | 1 | 2 | 3 | 5 | 1.51 |

Recommended tunable range: `200,000..300,000 milli_arc`, with `250,000` as
the first simulation anchor. This keeps positive movement at a minimum of one
step while preserving a small, legible distance gradient before the existing
per-region rank cap applies.

The exact production value must be selected together with
`trample_damage_per_step_by_rank` and
`trample_damage_cap_per_region_by_rank` in combat balance simulation. This
audit does not alter any of those values.

## Integrity Declaration

- Real V0.7.4 Map Genesis receipts: `120`
- Accepted topology snapshots: `120`
- Map or topology failures: `0`
- Mock topology samples: `0`
- Fixed six-region samples: `0`
- Camera/pixel/boundary-vertex/microcell distance readers: `0`
- Constitution writes: `0`
- Balance Defaults writes: `0`
- Godot Core writes: `0`
- Test writes: `0`

The committed change is limited to this Markdown report and its JSON peer.
