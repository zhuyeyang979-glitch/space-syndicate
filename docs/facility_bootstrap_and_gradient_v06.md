# Facility Bootstrap and Gradient v0.6

## Decision

Rank-I public facilities are the bootstrap into the city economy. A player still pays the rank-I market acquisition price, but playing the card requires no colored or generic asset. This removes the `0 GDP -> 0 asset -> no first facility` deadlock without granting starter assets, adding a tutorial waiver, or changing `PlayerMana` ownership.

## Authoritative cost ladder

| Rank | Purchase cash | Play asset total |
| --- | ---: | ---: |
| I | 4 | 0 |
| II | 7 | 2 |
| III | 11 | 4 |
| IV | 16 | 7 |

The ladder applies to all 16 facility families. Factory and market costs use their six-color `industry_id`; road, seaport, spaceport, and orbital warehouse costs use `generic`. All unrelated asset keys remain zero.

Player-facing rank-I cost text is `现金 4；打出免费`. It states the acquisition price and does not imply that any asset is required. Ranks II-IV retain the explicit colored or generic asset amount.

## Strength gradient

Every family also retains a strictly increasing strength ladder:

- Shared HP contribution: `100, 200, 300, 400`.
- Factory production and market demand capacity: `40, 80, 140, 220` units/minute.
- Road, port, and spaceport throughput: `50, 100, 175, 275` units/minute; speed multiplier `1.00, 1.20, 1.45, 1.75`.
- Warehouse storage: `200, 400, 700, 1100`; inbound and outbound throughput `50, 100, 175, 275` units/minute.

The catalog remains field-driven: `family_id`, `rank`, `industry_id`, `facility_kind`, and effect-capacity fields define behavior. No card-name match or gameplay waiver is introduced.

## Unchanged boundaries

- All 184 commodity cards remain free to acquire and play.
- Supply/demand, unit, interaction, GDP, commodity-flow, pricing, route, and facility-effect formulas are unchanged.
- No initial assets are granted and no `PlayerMana`, CardFlow, Coordinator, main scene, infrastructure, monster, or UI owner is changed.
- Atomicity, exact-once, rollback/finalize, and privacy gates remain unchanged. Tests that need a nonzero asset debit use a rank-II facility rather than restoring a rank-I fee.

## Source and validation

`card_runtime_catalog_v06_builder.gd` is the source of truth and generates `card_runtime_catalog_v06.json`. The catalog test exhaustively checks the exact 16 families and all 64 facility ranks for purchase cash, asset total/type, player text, facility color/type, and strictly increasing capacity. It separately reasserts the commodity-free invariant.
