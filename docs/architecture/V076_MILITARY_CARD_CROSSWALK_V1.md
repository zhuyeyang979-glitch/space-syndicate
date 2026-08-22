# V0.7.6 Military Card Crosswalk V1

`V076MilitaryCardCrosswalkV1` is one read-only `ADAPTER`. It does not replace or copy the existing card catalog. The unique source-card identity, family, rank, asset color, and asset cost remain owned by `CardRuntimeCatalogV06Resource`; each Crosswalk record stores only a canonical machine-record fingerprint and validation-only expected cost binding.

The adapter maps the sealed 28-card military set into the Stage 4 private Direct Action vocabulary. It owns no Tick, Authority Sequence, RNG, replay, unit state, asset quantity, map topology, presentation, card text, or card definitions. Physical speed remains delegated to the next unique Physical ETA owner registration, and accepted input still goes through `V076PrivateDirectActionInputOwnerV1` with the PR #65 membership/replay/collision pattern.

## Current result

| Result | Count | Meaning |
| --- | ---: | --- |
| Source records | 28 | Dynamically selected from `data/cards/card_runtime_catalog_v06.json` |
| Source families | 7 | Every family has ranks I-IV |
| Crosswalk records | 28 | One record per source identity; no duplicate or unknown identity |
| `EXACT_MAPPED` | 12 | Planetary Defense Force, Air Superiority Fighter, and Submarine Fleet have frozen V0.7.5 active definitions and rank profiles |
| `REAUTHOR_REQUIRED` | 16 | Orbital Bomber, Heavy Tank, Missile Emplacement, and Star Ocean Battleship are deferred by the frozen V0.7.5 catalog |

The 16 gap records deliberately expose no allowed mission or target. Older authored resources contain persistent-unit, terrain, cooldown, and protection-era semantics; those values are reference-only and are not silently converted into Alpha 0.7 assault behavior. The exact missing field set is recorded in `reports/card_certification/v076_military_authoring_gap_report.json`.

## Active mapping contract

Every exact record binds both `ASSAULT_REGION` and `ASSAULT_MONSTER`, target kinds `REGION` and `MONSTER`, positive catalog-owned asset cost, a frozen V0.7.5 damage profile, and `ARRIVE_EXECUTE_ONCE_WITHDRAW`. It also declares actor-private authorized input, public-outcome-only projection, exact-once card-instance binding, stale own-hand revalidation, and source-collision rejection.

There is no public batch entry, shared sushi-track resolution, card-text disclosure, name inference, text parsing, or mission fallback. `main.tscn` and production composition are unchanged. This is Stage 4 isolated mapping evidence only; production and human green remain false.
