# v0.6 Mechanic Status Registry

This registry is a machine-readable index into the authoritative v0.6 rules. It
does not define gameplay independently of the rulebook and runtime directive.

| Mechanic | Status | Meaning / boundary |
| --- | --- | --- |
| `card_counter_response` | ACTIVE | Section 8: one formal response layer for counterable direct-player interaction cards. It is never a contract response. |
| `monster_wager_response` | ACTIVE | Section 9: the formal 15-second forced decision for monster-battle wagers. |
| `card_target_choice` | ACTIVE | Section 7.4: forced target selection exists for monster and player targets. Region/product selection remains ordinary planning context, not a forced-response owner. |
| `forced_decision` | ACTIVE | Other temporary decisions explicitly required by active v0.6 rules. |
| `ai_runtime_world_interaction` | ACTIVE | AI policy remains owned by `AiRuntimeController`; it may consume only active-rule public facts or explicitly actor-scoped private facts, while legality and mutation remain with existing domain owners. |
| `ai_public_player_facts_typed_port_migration` | MIGRATION_ONLY | Replaces generic Main access with a session-bound public seat/role/elimination projection through the existing `AiActorStatePort`; adds no gameplay or save state. |
| `ai_actor_economy_facts_typed_port_migration` | MIGRATION_ONLY | Gives each active AI only its capability-guarded total/available cash, cooldown, and existing training counters; authority remains in WorldSession, Monster wager, and GameSession owners with no save change. |
| `ai_business_action_cash_cost` | ACTIVE | AI-only anonymous market pressure costs 90 cash units through `AiBusinessCostCashPort`; committed monster-wager cash is unavailable and exact rival cash remains private. |
| `conditional_order_auto_settlement` | ACTIVE | Section 8: `GlobalSupplyDemandRuntimeServiceV06` plans the effect, CardResolution carries its exact-once lineage, and `CommodityFlowRuntimeController` applies the atomic sink. No responder exists. |
| `legacy_project_contract` | RETIRED | v0.5 project-to-project contract state. |
| `contract_response` | RETIRED | Dedicated accept/reject/timeout response lifecycle. |
| `contract_accept` | RETIRED | Target-player acceptance action. |
| `contract_reject` | RETIRED | Target-player rejection action. |
| `contract_timeout` | RETIRED | Dedicated response timeout. |
| `contract_penalty` | RETIRED | Refusal/timeout penalty. |
| `contract_signature` | RETIRED | Target-player signature state. |
| `area_trade_contract` | RETIRED | Legacy card family; retired without replacement. |
| `legacy_contract_trace_intel_card` | RETIRED | `密约回溯1/2` depended on retired contract-party truth; both cards and `intel_contract_trace` are retired without replacement. |
| `contract_offer_v06` | RETIRED | The anonymous interaction schema and router have no generic contract domain. |
| `target_player_contract_consent` | RETIRED | Player consent for an order/supply card. |
| `legacy_contract_save_reader` | MIGRATION_ONLY | Legacy payloads are inspected and rejected before apply; they are never ignored into a live session and create no runtime state. |
| `legacy_contract_card_alias` | MIGRATION_ONLY | Reserved index entry only; there is no active alias because the retired family has no approved replacement. |

The corresponding JSON is authoritative for automated checks. Any new mechanic
must be registered with a rule source and owner before production implementation.
