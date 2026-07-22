# AI business cost cash call graph

## Rule authority gate

- `MECHANIC_ID=ai_business_action_cash_cost`
- `MECHANIC_STATUS=ACTIVE`
- `AUTHORITATIVE_RULE_FILES=docs/ai_runtime_ownership_contract.md; docs/ai_business_action_transaction_boundary_v06.md; docs/development/current_task_graph.json; docs/rules/v06_mechanic_status_registry.json`
- `AUTHORITATIVE_RULE_SECTIONS=Policy Source; Scope and authority; P0-AI-BUSINESS-COST-TYPED-CASH-CUTOVER`
- `CURRENT_COST_VALUE=90 units / 9000 cents`
- `CURRENT_COST_UNIT=cash_units at legacy call; cash_cents at canonical owner`
- `CURRENT_ACTION_MEANING=AI-only anonymous price-pump operating action`
- `NEW_OWNER_JUSTIFIED=true`
- `NEW_UI_WINDOW_JUSTIFIED=false`
- `NEW_SAVE_STATE_JUSTIFIED=false`
- `UNKNOWN_CONSUMER_COUNT=0`

This cutover migrates an existing internal AI operating cost. It does not add a
player action, response window, contract, score rule or market formula.

## Current production path

```text
ProductMarketRuntimeController.market_tick
  -> ProductMarketRuntimeWorldBridge -> Main._on_product_market_cycle_completed
  -> Main._ai_runtime_call("_auto_rival_business_actions")
  -> AiRuntimeController._auto_rival_business_actions
  -> AiRuntimeController._rival_business_candidates_for_player
  -> AiRuntimeController._pick_rival_business_action
  -> AiRuntimeController._apply_rival_business_action
  -> AiRuntimeWorldBridge.call_world("_apply_rival_business_action")
  -> Main._apply_rival_business_action
  -> Main._apply_rival_price_pump
  -> Main._pay_rival_business_cost
  -> direct WorldSessionState.players[player_index] replacement
  -> ProductMarketRuntimeController.apply_external_pressure
  -> public city clue / visual callout / viewer feedback
```

## Current semantics and defects

- Cost is taken before the market effect and is never compensated if the
  effect fails.
- The legacy write updates whole-unit `cash`, spend counter, economic ledger
  and cash history, but bypasses canonical cents authorization.
- It does not atomically validate or update `cash_cents`.
- It can spend cash already committed to an unresolved monster wager.
- It has no request identity, session/cycle/step binding or exact-once gate.
- Human-seat exclusion is only an upstream AI-candidate convention.
- The call normally occurs inside the authoritative market phase simulation
  step, but Main performs no mutation-authority validation.
- Current `route_sabotage` candidates fail closed at the existing action
  dispatch. The cutover keeps that behavior; route ownership is out of scope.

## Target path

```text
AiRuntimeController decision
  -> AiBusinessCostCashPort private request context
  -> ProductMarketRuntimeController.prepare_ai_business_market_pressure
  -> ProductMarketRuntimeController.commit_ai_business_market_pressure
  -> ProductMarketRuntimeController.seal_ai_business_market_pressure_finalization
  -> AiBusinessCostCashPort.submit(opaque capability, typed request)
  -> MonsterWagerCashCommitmentQueryPort.authorize_debit_cents
  -> PlayerCashMutationPort.commit_ai_business_action_cost
  -> SimulationMutationAuthority + WorldSessionState cash owner
  -> cash failure: ProductMarketRuntimeController.rollback_ai_business_market_pressure
  -> cash success: ProductMarketRuntimeController.finalize_ai_business_market_pressure
  -> typed WorldSessionState public-region clue + typed public log receipt
  -> ProductMarket tick / session-finish / save maintenance drains only a missing public destination after an injected transient outage
```

The whole participant sequence is synchronous. There is no Main callback,
deferred work, second cash owner, second commitment owner or new save section.

## Legacy symbols to delete

- `Main._pay_rival_business_cost`
- `Main._apply_rival_price_pump`
- `Main._apply_rival_business_action`
- `Main.RIVAL_BUSINESS_ACTION_COST`
- `Main.RIVAL_BUSINESS_ACTION_CHANCE_PERCENT`
- `Main.RIVAL_BUSINESS_ACTION_MAX_PER_CYCLE`
- `Main.RIVAL_BUSINESS_PRICE_DELTA_MIN/MAX`
- the business chance, per-cycle cap and cost fields in
  `Main._ai_runtime_world_constant_snapshot`
- `AiRuntimeController`'s dynamic Main action call
- `Main._set_city_public_clue` if it has no remaining production consumer
