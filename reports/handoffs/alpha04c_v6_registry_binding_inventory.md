# Alpha 0.4-C V6 Registry Binding Inventory

## Scope

This is a read-only reconstruction of the production V0.6 Save Owner Registry as
executed by V6 at `7f2d7a31a0f0ffbd662526ad26122ea66fa59a56`. The immutable V6
quota ledger and evidence chain were located and hash-checked. This inventory task ran
no replay, diagnostic, quota operation, Owner Capture, Process A, or Save write.

## Result

- Production binding count: **19**
- Explicit Owner checkpoint methods: **8**
- Registry-managed checkpoints with omitted `checkpoint_method`: **11**
- Owner-internal transaction checkpoints: **0**
- Owners without checkpoint or rollback semantics: **0**
- V6 ledger: **2546 bytes**, SHA-256
  `fe843a4a924a12af5553afcb38a579f68a59acdeab0a4c5e5efb006c31e25c60`
- Inventory fingerprint:
  `89b13b27d934eeeb49151b6833ea055f1ee19cdd2e523b4b2e5c1a55a1016c0c`

V6 correctly passed Launch Context and scenario identity. It stopped before Owner Audit,
at zero attempted captures, because the diagnostic treated every nonempty
`checkpoint_method` as mandatory. The first rejected row was index 1,
`region_infrastructure/public_facility_region`.

## Production Semantics

The production contract does not require every binding to name a separate checkpoint
method. At V6 code HEAD:

1. `_registry_analysis()` requires capture, apply, and rollback methods for every
   transactional Owner. It checks a checkpoint method only when the binding declares one.
2. `_capture_owner_checkpoint_detailed()` calls an explicit checkpoint method when
   present. Otherwise it captures the Owner's pure `to_save_data` Dictionary and
   duplicates that state as the rollback checkpoint.
3. All 19 checkpoints are captured before any Owner apply.
4. On failure, `_rollback_sections()` invokes each declared rollback method in reverse
   actual restore order.
5. It recaptures each restored Owner and requires encoded equality with the pre-apply
   checkpoint. `_verify_checkpoints_exact()` then checks all 19 Owners for residual
   mismatch.

The 11 omitted rows therefore use `registry_managed_checkpoint`, not an implicit
no-checkpoint mode. Their declared `rollback_method` is `apply_save_data`, which accepts
the complete previously captured Owner state. The retained production transaction gate
proved pure preflight **19/19** and fault rollback **19/19**, including exact reverse order
and zero partial restore state.

## V6 Evidence

| Artifact | Retained | SHA-256 |
| --- | --- | --- |
| Quota ledger raw bytes | yes | `fe843a4a924a12af5553afcb38a579f68a59acdeab0a4c5e5efb006c31e25c60` |
| Authorization contract at V6 HEAD | yes | `260bfe9dca8cc9a65277c1ae23ad2040cf986749dbfb75e3227b0936dad22f97` |
| Launch attestation | yes | `074ff66b43fb77b7cd2b5e48d5aa29225fe75c69ddc1a4207033ccbdd43e847a` |
| Child result | yes | `0cb96dd36d3b612ea6fb64c0501063c34f3144e7e445c81deec345fa7a55ee15` |
| Child completion | yes | `6d0c95ad44d90a0ad6f080a88da0dab86da81c6ace32eb35dc0d0bc6d1bca7a4` |
| Owner Capture audit | yes | `8cd6248c6c4eead7f228ef90163aad7e63058ec78b0c210efe6413a86c2e5d49` |
| Parent exit | yes | `2c37461e53f62babb1cd419aeff0cf13be74cfa9bb8b20070348cfaa6464972c` |

Host paths, process IDs, and nonce values remain only in the immutable source artifacts
and are not repeated here.

## All Bindings

Indices are zero-based, matching the diagnostic's contract index.

| Index | Section | Owner | State | Checkpoint strategy | Checkpoint source | Rollback method | Dependencies | Fingerprint |
| ---: | --- | --- | ---: | --- | --- | --- | --- | --- |
| 0 | `ruleset` | `ruleset_runtime` | 1 | explicit | `capture_runtime_checkpoint` | `restore_runtime_checkpoint` | none | `0addb595777a` |
| 1 | `region_infrastructure` | `public_facility_region` | 1 | registry-managed | `to_save_data` | `apply_save_data` | session_foundation | `33ba1e6b7b37` |
| 2 | `region_supply` | `region_supply` | 1 | registry-managed | `to_save_data` | `apply_save_data` | session_foundation, region_infrastructure | `eda3bae39263` |
| 3 | `commodity_flow` | `commodity_flow` | 2 | registry-managed | `to_save_data` | `apply_save_data` | session_foundation, region_infrastructure | `1c6cb265483f` |
| 4 | `routes` | `route_network` | 2 | explicit | `capture_runtime_checkpoint` | `restore_runtime_checkpoint` | region_infrastructure, weather | `29138361726a` |
| 5 | `player_mana` | `player_mana` | 1 | registry-managed | `to_save_data` | `apply_save_data` | session_foundation | `ce6803b5e474` |
| 6 | `commodity_belt_visibility` | `commodity_belt_visibility` | 1 | explicit | `capture_runtime_checkpoint` | `restore_runtime_checkpoint` | card_inventory | `65b02be0a647` |
| 7 | `card_inventory` | `card_inventory` | 3 | explicit | `capture_runtime_checkpoint` | `restore_runtime_checkpoint` | session_foundation, region_supply, player_mana | `fcb5872d3427` |
| 8 | `player_organization` | `player_organization` | 1 | registry-managed | `to_save_data` | `apply_save_data` | session_foundation | `06e88ef5d855` |
| 9 | `monsters` | `monster_runtime` | 1 | registry-managed | `to_save_data` | `apply_save_data` | session_foundation, region_infrastructure, card_inventory | `c4e11e23fad6` |
| 10 | `military` | `military_runtime` | 2 | explicit | `capture_runtime_checkpoint` | `restore_runtime_checkpoint` | session_foundation, region_infrastructure, card_inventory, monsters | `7737b48e2df5` |
| 11 | `weather` | `weather_runtime` | 1 | registry-managed | `to_save_data` | `apply_save_data` | session_foundation, region_infrastructure | `e73dcc5e5fe9` |
| 12 | `card_resolution_queue` | `card_resolution_queue` | 2 | explicit | `capture_runtime_checkpoint` | `restore_runtime_checkpoint` | session_foundation, region_infrastructure, player_mana, card_inventory; cross: card_resolution_execution, card_resolution_history | `a9740dc2879f` |
| 13 | `card_resolution_execution` | `card_resolution_execution` | 1 | registry-managed | `to_save_data` | `apply_save_data` | card_resolution_queue, card_inventory, player_mana, commodity_flow | `1259b22dbf11` |
| 14 | `card_resolution_history` | `card_resolution_history` | 1 | registry-managed | `to_save_data` | `apply_save_data` | card_resolution_execution | `cf3739aa11b1` |
| 15 | `ai` | `ai_runtime` | 2 | explicit | `capture_runtime_checkpoint` | `restore_runtime_checkpoint` | session_foundation, card_inventory, card_resolution_history | `01d53f3cf3f3` |
| 16 | `bankruptcy_neutral_estate` | `bankruptcy_neutral_estate` | 1 | registry-managed | `to_save_data` | `apply_save_data` | session_foundation, region_infrastructure, card_inventory, commodity_flow, player_mana, monsters, military | `3516f081d06c` |
| 17 | `victory_control` | `victory_control` | 1 | registry-managed | `to_save_data` | `apply_save_data` | session_foundation, region_infrastructure, commodity_flow, bankruptcy_neutral_estate | `522164d5bf4c` |
| 18 | `session` | `game_session` | 3 | explicit | `capture_runtime_checkpoint` | `restore_runtime_checkpoint` | ruleset; tail after: card_resolution_history, ai, victory_control, routes, commodity_belt_visibility | `d49e642f93f8` |

The full 64-character row fingerprints, source blob hashes, method line locations,
dependency classes, and fingerprint algorithm are in
`alpha04c_v6_registry_binding_inventory.json`.

## Omitted Checkpoint Rows

| Section | Owner | Registry checkpoint source | Registry rollback target |
| --- | --- | --- | --- |
| `region_infrastructure` | `public_facility_region` | `scripts/runtime/region_infrastructure_runtime_controller.gd:1104` | `scripts/runtime/region_infrastructure_runtime_controller.gd:1159` |
| `region_supply` | `region_supply` | `scripts/runtime/region_supply_runtime_controller.gd:438` | `scripts/runtime/region_supply_runtime_controller.gd:472` |
| `commodity_flow` | `commodity_flow` | `scripts/runtime/commodity_flow_runtime_controller.gd:1385` | `scripts/runtime/commodity_flow_runtime_controller.gd:1469` |
| `player_mana` | `player_mana` | `scripts/runtime/player_mana_runtime_controller.gd:541` | `scripts/runtime/player_mana_runtime_controller.gd:569` |
| `player_organization` | `player_organization` | `scripts/runtime/player_organization_runtime_controller.gd:483` | `scripts/runtime/player_organization_runtime_controller.gd:509` |
| `monsters` | `monster_runtime` | `scripts/runtime/monster_runtime_controller.gd:1487` | `scripts/runtime/monster_runtime_controller.gd:1611` |
| `weather` | `weather_runtime` | `scripts/runtime/weather_runtime_controller.gd:587` | `scripts/runtime/weather_runtime_controller.gd:622` |
| `card_resolution_execution` | `card_resolution_execution` | `scripts/runtime/card_resolution_execution_runtime_service.gd:493` | `scripts/runtime/card_resolution_execution_runtime_service.gd:516` |
| `card_resolution_history` | `card_resolution_history` | `scripts/runtime/card_resolution_history_runtime_service.gd:170` | `scripts/runtime/card_resolution_history_runtime_service.gd:186` |
| `bankruptcy_neutral_estate` | `bankruptcy_neutral_estate` | `scripts/runtime/bankruptcy_neutral_estate_runtime_controller.gd:63` | `scripts/runtime/bankruptcy_neutral_estate_runtime_controller.gd:114` |
| `victory_control` | `victory_control` | `scripts/runtime/victory_control_runtime_controller.gd:381` | `scripts/runtime/victory_control_runtime_controller.gd:409` |

Each row above is protected by the same closed strategy:

`to_save_data -> pure Dictionary checkpoint -> reverse-order apply_save_data rollback -> exact recapture equality`

No binding uses `checkpoint_strategy=none` or `unknown`, and no method name was
invented to fill the omitted field.

## Source Closure

The V6 production source identities are:

- Registry scene blob `f840b28656eec7cf9243f2623696aa758749873b`
- Registry script blob `633bd14caa992303ed590cb1b92c969010ea5c5a`
- Binding resource blob `208ece9eb281aa8cef4a01296b6cbea044c5e268`
- Restore DAG blob `11a7c0224cbb957a0188797cfc28de7761aa7886`
- Production transaction test blob `f9594b116798e6f098d0a6171bfd190d84817a00`

The diagnostic's hardcoded nonempty-field requirement was at
`cold_restore_vertical_slice_driver.gd:3235`. Production's optional explicit-method
check was at `v06_save_owner_registry.gd:1747`, and the Registry-managed fallback was
at `v06_save_owner_registry.gd:1165`.

## Safety Boundary

`TARGETED_OWNER_CAPTURE_DIAGNOSTIC_COUNT` remains 6. This inventory did not authorize
or run V7, did not run the nonconsuming replay, did not start Process A, and did not
modify any V6 evidence bytes, production code, or tests.

