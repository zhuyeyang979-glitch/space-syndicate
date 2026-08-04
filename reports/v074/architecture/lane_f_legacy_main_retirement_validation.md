# Lane F Legacy Main Retirement Validation

Lane F physically removed `scripts/main.gd` and `scripts/main.gd.uid` through the Role C Godot MCP endpoint on port 9026. Production `main.tscn` already used a separate application bootstrap, so no production replacement or compatibility facade was added.

## Result

- Physical Main lines after: **0**
- Production dependency closure: **79 files**
- Production legacy references: **0**
- V0.7.4 active-test dependencies: **0**
- Dynamic production Main lookups: **0**
- Compatibility wrappers/replacement monoliths: **0**
- Pure algorithms copied or extracted: **0**

No extraction was needed: the production V0.7.3 composition was already independent of the monolith, and the V0.7.4 map/facility implementations are reserved to other lanes.

## Reference Classification

| Classification | Files | Occurrences | Executable V0.7.4 dependency |
| --- | ---: | ---: | ---: |
| duplicate historical evidence | 252 | 1983 | 0 |
| frozen V0.6 reliability/source oracle | 151 | 628 | 0 |
| obsolete | 4 | 13 | 0 |
| V0.7.3 negative/historical tests | 15 | 20 | 0 |
| V0.7.4 negative ratchet | 2 | 5 | 0 |
| production reachable | 0 | 0 | 0 |
| pure algorithm candidate | 0 | 0 | 0 |

The two remaining direct legacy loads are obsolete V0.6 fixtures:

- `tests/card_resolution_controller_consolidation_test.gd:78`
- `tests/helpers/card_resolution_main_test_harness.gd:14`

They are not production reachable or part of V0.7.4 active acceptance. They were classified instead of triggering broad deletion of otherwise useful historical tests.

The obsolete executable tools `check_main_gd_budget.py` and `build_main_gd_call_graph.py` were deleted because their sole subject no longer exists.

## Ratchets

`v074_legacy_main_retirement_test.gd` passes **8/8** and proves physical absence, zero production references, zero V0.7.4 active dependencies, and zero compatibility wrappers.

`v074_bootstrap_architecture_ratchet_test.gd` targets the reserved future path `res://scripts/v074_runtime/v074_application_bootstrap.gd`. The file is supplied by commit `03960728`, not this isolated Lane F base, so the local run reports one expected integration dependency. Read-only inspection of that exact commit records 53 lines and zero domain-rule, gameplay-mutation, Save-owner, or RNG-owner tokens.

## MCP

- Changed scripts validated: **3/3**
- `res://scenes/main.tscn` loaded: **1/1**
- Lane F script errors: **0**
- Task-introduced project errors: **0**

The full scan checked 586 scripts and found one unchanged legacy Bench file with two type-inference diagnostics at `district_supply_surface_query_cutover_bench.gd:113/147`. They are baseline diagnostics outside Lane F ownership.

The editor-generated third-party `.import` changes and unrelated untracked `.uid` files remain unstaged.
