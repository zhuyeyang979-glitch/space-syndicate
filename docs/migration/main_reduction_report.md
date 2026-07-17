# Main composition root reduction report

Status: `MAIN_COMPOSITION_ROOT_REDUCTION_GREEN`

## Scope

This atomic reduction removes only four unreferenced legacy helpers from
`scripts/main.gd`. No gameplay owner, phase order, clock formula, save schema,
RNG source or command path was changed.

Deleted helpers:

- `_pay_skill_play_cost`
- `_product_market_price_label`
- `_role_can_use_monster_card_as_counter`
- `_skill_uses_current_product`

Static repository search found no production, scene, test or tool caller for
any of these methods. Existing card payment, product presentation, role
counter capability and product filtering paths already use their typed owners
or other active helpers.

## Main metrics

| Metric | Before reduction | After reduction | Delta |
|---|---:|---:|---:|
| Physical lines | 13,159 | 13,116 | -43 |
| Nonblank lines | 11,414 | 11,379 | -35 |
| Methods | 819 | 815 | -4 |
| Top-level variables | 66 | 66 | 0 |
| Constants | 110 | 110 | 0 |
| Top-level preloads | 15 | 15 | 0 |
| External caller files | 102 | 102 | 0 |
| External caller occurrences | 1,591 | 1,591 | 0 |

The caller budget remains unchanged and the Main budget is monotonic. The
reduction deliberately did not remove compatibility `_get/_set`; many old QA
fixtures still use those dynamic surfaces and they require a dedicated typed
port cutover rather than an untested deletion.

## Composition boundary after reduction

```text
main.tscn / Main shell
  -> GameRuntimeCoordinator (composition and typed wiring only)
    -> RuntimeLoop (唯一 _process)
      -> RuntimeSimulationStep (唯一 simulation step)
        -> SimulationMutationAuthority
        -> RuntimeCommandPipeline
          -> typed command sinks
            -> domain owners
```

The reduction test verifies that Main does not contain a frame owner,
`SimulationMutationAuthority`, `RuntimeCommandPipeline`, autonomous monster
mutation or a second coordinator entry point. It also verifies that the
formal application scene has exactly one coordinator and one RuntimeLoop.

## Remaining risks

1. Main still contains large presentation/menu, new-game, save, topology and
   legacy dynamic property surfaces; these require separate atomic cutovers.
2. `GameRuntimeCoordinator` remains large and must not absorb domain logic or
   become a replacement God Object.
3. Existing `RuntimeWorldPorts.lifecycle`, retired fixtures and old smoke
   harnesses remain explicitly excluded historical debt.
4. External Main caller count cannot fall until the corresponding typed
   presentation, setup and save owners are migrated; this reduction therefore
   proves safety without claiming final Main deletion.

## Evidence

- `tests/composition_root_reduction_test.gd` — PASS 12/12
- `tests/main_gd_architecture_gate_test.gd` — PASS 80 checks
- `tests/main_runtime_composition_test.gd` — PASS
- `tools/architecture/check_main_gd_budget.py --json` — `ok: true`
