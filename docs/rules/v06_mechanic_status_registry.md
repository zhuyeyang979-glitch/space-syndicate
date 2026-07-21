# v0.6 Mechanic Status Registry

This registry is a machine-readable index into the authoritative v0.6 rules. It
does not define gameplay independently of the rulebook and runtime directive.

| Mechanic | Status | Meaning / boundary |
| --- | --- | --- |
| `card_counter_response` | ACTIVE | One formal response layer for counterable interaction cards. It is never a contract response. |
| `monster_wager_response` | ACTIVE | The formal forced decision for monster-battle wagers. |
| `card_target_choice` | ACTIVE | Legal monster, player, region, or product target selection for a played card. |
| `forced_decision` | ACTIVE | Other temporary decisions explicitly required by active v0.6 rules. |
| `conditional_order_auto_settlement` | ACTIVE | Conditional order and supply cards are validated and settled automatically by the card execution and economy owners. No target player signs them. |
| `legacy_project_contract` | RETIRED | v0.5 project-to-project contract state. |
| `contract_response` | RETIRED | Dedicated accept/reject/timeout response lifecycle. |
| `contract_accept` | RETIRED | Target-player acceptance action. |
| `contract_reject` | RETIRED | Target-player rejection action. |
| `contract_timeout` | RETIRED | Dedicated response timeout. |
| `contract_penalty` | RETIRED | Refusal/timeout penalty. |
| `contract_signature` | RETIRED | Target-player signature state. |
| `area_trade_contract` | RETIRED | Legacy card family; retired without replacement. |
| `contract_offer_v06` | RETIRED | The anonymous interaction schema and router have no generic contract domain. |
| `target_player_contract_consent` | RETIRED | Player consent for an order/supply card. |
| `legacy_contract_save_reader` | MIGRATION_ONLY | Fail-closed recognition of unknown legacy payload keys; it creates no runtime state. |
| `legacy_contract_card_alias` | MIGRATION_ONLY | Reserved index entry only; there is no active alias because the retired family has no approved replacement. |

The corresponding JSON is authoritative for automated checks. Any new mechanic
must be registered with a rule source and owner before production implementation.
