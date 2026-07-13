# GDP Formula Runtime Cutover (v0.4 Historical Evidence)

> This document records the characterized v0.4 formula and its original cutover. SS05-03 replaced the active profile, minimum-city floor, and whole-city allocation path with `docs/structured_project_gdp_v05_contract.md`. Do not use the values below as a v0.5 runtime fallback.

## Rules boundary

Ruleset v0.4 defines city total GDP as the combined output of production, demand, commerce, and contract projects. Project GDP is then distributed by project contribution shares, and destroyed districts stop producing GDP. This cutover moves the existing numeric city-total formula without changing those rules.

The runtime chain is now:

1. The world adapter in `main.gd` reads current public product, route, district, role, contract, and temporary-pressure facts.
2. `GdpFormulaRuntimeController` calculates one pure city GDP breakdown.
3. `CityProductProjectBridge` assigns the city total to active projects and player shares.
4. `EconomyCashflowRuntimeController` converts project GDP/min into per-second payout events with remainder conservation.
5. Existing main adapters apply cash, city remainder, history, and ledger mutations.

## Characterized formula

The Inspector profile at `res://resources/economy/space_syndicate_gdp_formula_v04.tres` owns these runtime values:

| Parameter | Value |
| --- | ---: |
| Production base | 42 |
| Production level step | 12 |
| Production price divisor | 5 |
| Production scale | 0.58 |
| Demand base | 28 |
| Demand price divisor | 8 |
| Demand scale | 0.72 |
| Transit base | 18 |
| Transit price divisor | 20 |
| Competition penalty | 16 |
| Disrupted-route penalty | 55 |
| District-damage penalty | 18 |
| Active-city minimum GDP | 40 |
| Minimum effective flow | 0.25 |

Each line uses the same explicit `round` points as the former implementation. Production and demand lines are rounded individually; transit lines are rounded individually; pressure is summed after gross GDP; the active-city floor applies last. An inactive city returns zero rather than the floor.

## Ownership and privacy

The controller accepts only Dictionary, Array, String, Number, Bool, and null values. It does not retain a world Node or expose owner identity, contribution tables, AI scores, private targets, private discard data, or Resources through snapshots.

The world adapter still computes facts such as market price, production factor, demand/supply ratios, route speed, transit path membership, and whether a timed pressure is active. Moving those facts requires their own district/product/route runtime ownership cutover; hiding calls back into `main.gd` inside this controller is forbidden.

## Verification gate

`GdpFormulaRuntimeCutoverBench` fixes twenty cases covering profile composition, exact parameters, inactive state, additions, production directions, demand directions, transit, pressure, floor, pure data, real-main composition, and legacy-authority removal. Any intentional balance change must update the Resource, the exact characterization cases, and the player-facing design record together.
