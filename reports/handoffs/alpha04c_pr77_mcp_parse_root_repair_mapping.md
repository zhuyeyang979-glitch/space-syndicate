# Alpha 0.4-C PR77 MCP parse-root repair mapping

This mapping is derived from the retained B0 and P0 no-active-MCP logs. It
freezes ten parse diagnostics onto five authorized root files. The five failed
script loads are consequences of those parse failures and are not independent
root causes.

| Diagnostic | Root | File | Original line | Repair class |
| --- | --- | --- | ---: | --- |
| S01 | R01 | `scripts/tools/district_supply_surface_query_cutover_bench.gd` | 113 | Explicit dynamic Dictionary result |
| S02 | R01 | `scripts/tools/district_supply_surface_query_cutover_bench.gd` | 147 | Explicit dynamic Dictionary result |
| S03 | R02 | `tests/card_resolution_stable_target_envelope_test.gd` | 197 | Dependency signature alignment |
| S04 | R02 | `tests/card_resolution_stable_target_envelope_test.gd` | 199 | Dependency signature alignment |
| S05 | R02 | `tests/card_resolution_stable_target_envelope_test.gd` | 200 | Dependency signature alignment |
| S06 | R03 | `tests/district_supply_surface_query_cutover_test.gd` | 223 | Explicit dynamic Dictionary result |
| S07 | R03 | `tests/district_supply_surface_query_cutover_test.gd` | 232 | Explicit dynamic Dictionary result |
| S08 | R03 | `tests/district_supply_surface_query_cutover_test.gd` | 235 | Explicit dynamic Dictionary result |
| S09 | R04 | `tests/human_normal_table_playability_v06_test.gd` | 137 | Explicit typed dynamic result |
| S10 | R05 | `tests/player_facing_privacy_boundary_test.gd` | 215 | Explicit typed dynamic result |

Consequential load mapping: F01 to R01, F02 to R02, F03 to R03, F04 to R04,
and F05 to R05.

The B0 origin/main log also contains two parse diagnostics and one failed load
from `tests/ai_v06_facility_bootstrap_policy_test.gd`. That main-only baseline
test references the already removed `ai_v06_economy_action_port.gd`; PR77
already replaces the old test with the facility action spine contract. It is
recorded separately and is outside this five-file repair authorization.

No HDR file, 3D texture, renderer, or last-imported resource is attributed as
the native crash root cause before the post-parse fresh-cache rescan.
