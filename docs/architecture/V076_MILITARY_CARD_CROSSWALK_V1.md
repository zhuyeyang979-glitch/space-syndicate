# V0.7.6 Military Card Crosswalk V1

`V076MilitaryCardCrosswalkV1` is one read-only `ADAPTER`. It does not replace or copy the existing card catalog. The unique source-card identity, family, rank, asset color, and asset cost remain owned by `CardRuntimeCatalogV06Resource`; each Crosswalk record stores only a canonical machine-record fingerprint and validation-only expected cost binding.

The adapter maps the sealed 28-card military set into the Stage 4 private Direct Action vocabulary. It owns no Tick, Authority Sequence, RNG, replay, unit state, asset quantity, map topology, presentation, card text, or card definitions. Speed is owned by `V076MilitaryUnitProfileAuthority`; integer distance-plus-speed to ETA and its receipt are owned by `V076MilitaryPhysicalEtaOwnerV1`. Accepted input still goes through `V076PrivateDirectActionInputOwnerV1` with the PR #65 membership/replay/collision pattern.

## Current result

| Result | Count | Meaning |
| --- | ---: | --- |
| Source records | 28 | Dynamically selected from `data/cards/card_runtime_catalog_v06.json` |
| Source families | 7 | Every family has ranks I-IV |
| Crosswalk records | 28 | One record per source identity; no duplicate or unknown identity |
| `EXACT_MAPPED` | 28 | All seven families and ranks I-IV bind to one explicit Profile |
| `REAUTHOR_REQUIRED` | 0 | The sixteen former gaps are closed by authorized reversible V0.7.6 playtest authoring |

The historical 16-gap snapshot remains in `reports/card_certification/v076_military_authoring_gap_report.json`. Older persistent-unit, terrain, cooldown, and protection-era semantics stay reference-only; none was silently converted. The new authority explicitly records assault missions, targets, speed, combat values, costs, and arrive-execute-once-withdraw lifecycle.

## Active mapping contract

Every exact record binds both `ASSAULT_REGION` and `ASSAULT_MONSTER`, target kinds `REGION` and `MONSTER`, positive catalog-owned asset cost, an explicit combat Profile, and `ARRIVE_EXECUTE_ONCE_WITHDRAW`. The twelve prior Profiles retain frozen V0.7.5 combat values; twenty-eight speeds and sixteen complete Profiles are new V0.7.6 playtest authority. It also declares actor-private authorized input, public-outcome-only projection, exact-once card-instance binding, stale own-hand revalidation, and source-collision rejection.

There is no public batch entry, shared sushi-track resolution, card-text disclosure, name inference, text parsing, or mission fallback. `main.tscn` and production composition are unchanged. This is Stage 4 isolated mapping evidence only; production and human green remain false.
