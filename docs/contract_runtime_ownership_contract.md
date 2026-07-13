# Contract Runtime Ownership Contract

## Sprint 51 status

Sprint 51 completed the single-owner hard cutover. `ContractRuntimeController`
now owns selected endpoints, product context, pending offers, visible-time
response lifecycle, response transactions, sanitized receipts, privacy snapshots,
and v1 save data. `ContractRuntimeWorldBridge` is deliberately non-owning: it
collects pure world facts and applies Controller-authored accept, reject, or
timeout transactions to the existing world-rule owners.

The real-main gate is now:

- `res://scenes/tools/ContractRuntimeCharacterizationBench.tscn`
- 47/47 historical runtime behaviors revalidated and aligned
- 15/15 hard-cutover ownership cases passed
- 62/62 total passed
- Deleted legacy owner: 37 functions, three state variables, and four response
  constants were removed from `main.gd`; no fallback wrapper family remains

Production `main.gd` after the cutover is 24,323 non-empty lines, 1,379 functions,
145 top-level variables, and 228 constants with SHA-256
`3191405C4F34A002A658AB179020E01BEBDE67B1148EF1DCE3AF9F70DBBDB201`.

## Sprint 50 historical baseline

Sprint 50 recorded the pre-cutover behavior at 25,039 non-empty lines, 1,415
functions, 148 top-level variables, and 232 constants with SHA-256
`214AEB804860D2DFFB8833EFF0BC0A4098B355178C07FB8E8BD1D80E6221777F`.
It observed 47/47 cases and aligned 44/47, surfacing the four v0.4 decisions
locked below. This baseline is retained only as evidence, not as a runtime owner.

## Real contract catalog

The gate uses the production I-level cards and verifies that ranks I-IV exist:

| Family | Runtime I asset | Product mode | Characterized purpose |
| --- | --- | --- | --- |
| Regional supply-demand | `区域供需合约1` | selected | One selected product and standard accept/decline effects |
| Automatic matching | `自动撮合合约1` | auto | Fill from source products and target demands |
| Ring-crystal battery supply | `环晶电池专供1` | fixed | Authored product list takes precedence |
| Bilateral hedge | `双边对冲合约1` | multi | Multiple products are limited by the rank goal |
| Punitive refusal | `惩罚性拒签条款1` | selected | Decline cash, regional, and route-damage terms |

## Pending offer state

The Controller's `pending_contract_offers` save field is an array of deep-copied
card-resolution entries.
An offer retains the queue entry fields and adds or normalizes these fields:

- `contract_offer_id`: resolution id, queued order fallback, or a new resolution sequence.
- `resolution_id` / `queued_order`: link back to resolution history.
- `skill`: deep-copied real contract card data.
- `contract_source_district` / `contract_target_district`.
- `contract_products`: selected, automatic, fixed, or multi-product result.
- `contract_target_owner`: current runtime response authority.
- `contract_response`: `pending`, `accepted`, `rejected`, or `timeout`.
- `contract_decision_timer`: ruleset bridge `contract_window_seconds`, currently 5.0.
- `contract_decision_started_time`: `game_time` when the offer is appended.
- `contract_response_player` / `contract_response_time`: added on an explicit response.
- result fields copied to resolution history: `contract_accept_summary`,
  `contract_decline_summary`, `contract_result_clue`, `aftermath_clue`,
  `aftermath_style`, and `resolved_time`.

Missing save data defaults to an empty offer array. Current save data preserves
the complete array, including a partially elapsed timer. Restored expired offers
remain data-compatible and are consumed by the normal timeout tick; Sprint 51
must preserve this behavior unless a migration is explicitly versioned.

## Creation and continuation order

Observed order for an area-trade contract is:

1. Eligibility and queue owners validate normal card submission.
2. Card Resolution Execution releases the active entry before effect dispatch.
3. The contract effect derives source, target, product context, and response authority.
4. `ContractRuntimeController.open_offer()` deep-copies the resolution entry.
5. The offer receives its id, `pending` response, five-second timer, and start time.
6. The independent offer is appended; the released entry receives matching summary fields.
7. Resolution history can continue without retaining the contract as the active card.

Duplicate creation with the same offer/resolution id is idempotent. Invalid or
destroyed endpoints reject before cash, product, demand, route, or player state
changes. Offer creation itself mutates only pending/log/history state.

## Product selection order

The current runtime chooses products in this order:

1. Authored `contract_products` on the card.
2. The selected trade product when mode permits it.
3. Active source-city products.
4. Source-district products.
5. Active target-city demands.
6. Target-district demands.
7. Product catalog fallback.

The goal is derived from the larger of authored product/demand additions, with a
minimum of one. `selected` mode is capped to one product; other modes may fill to
the goal. Sprint 51 must migrate this selection order without moving the pure
arithmetic already owned by `CardEconomyProductRouteFormulaRuntimeService`.

## Response and transaction order

Explicit accept and reject use `ContractRuntimeController.respond_to_offer()`:

1. Locate the offer by `contract_offer_id` or resolution id.
2. Verify the responding player against the stored response authority.
3. Remove the offer before settlement, preventing duplicate responses.
4. Set response, response player, and response time.
5. Plan a stable transaction and route it once through the non-owning WorldBridge.
6. Store a sanitized result in resolution history.
7. Emit existing log/UI refresh behavior.

Timeout removes the offer, sets `timeout`, records response time, and routes
through that same settlement entry. Duplicate and expired responses return false
without cash, city, product, route, history, or event mutation.

Accept currently commits in this observed order:

1. Remove authored source products and target demands.
2. Add source district/city products and target district/city demands.
3. Append public city clues.
4. Apply source production and target transport/consumption deltas.
5. Apply target route-flow boon through the Formula Service result.
6. Grant the target response authority the authored cash reward.
7. Refresh city networks, then product-market prices.
8. Update selected trade product, map pulses, callout, and public log.

Reject and timeout currently commit in this observed order:

1. Pay the refusal penalty, capped by the responder's available cash.
2. Apply target production/transport/consumption deltas.
3. Add route damage and a public city clue.
4. Refresh city networks, then product-market prices.
5. Emit map pulse, callout, and public result log.

The Formula Service remains a pure calculation owner. It does not own pending
offers, response authority, timers, cash, city dictionaries, route mutation,
refresh calls, or event publication.

## Shared ownership boundaries

- `RulesetRuntimeBridge`: supplies the five-second duration only.
- `ForcedDecisionRuntimeScheduler`: owns priority arbitration only.
- `CardResolutionRuntimeController` and Queue Service: own window/queue state, not contracts.
- `CardResolutionExecutionRuntimeService`: owns release/dispatch/continuation, not settlement.
- `CardPlayEligibilityRuntimeService`: owns card-play legality, not offer lifecycle.
- `CardPresentationRuntimeService`: owns display wording, not contract facts.
- `AiRuntimeController`: selects accept or decline; it owns no contract mutation.
- `ContractResponseDecisionPanel`: editable owner-only UI and action ids only.
- `ContractRuntimeController`: sole owner of contract lifecycle, policy, state, timer,
  response planning, privacy snapshots, and save data.
- `ContractRuntimeWorldBridge`: applies world mutations but owns no contract state,
  policy, timer, AI choice, formula, or presentation.
- `main.gd`: narrow world/signal adapter only; it contains no legacy contract engine.

Player and AI responses enter the same production response route. AI receives a
sanitized response context and returns a choice; it does not remove offers or
apply cash, region, product, demand, route, or history changes.

## Public and private information

Public contract result clues may include source/target district labels, products,
accepted/rejected/timeout state, and public effect summaries. They must not expose
the real initiator, real responder, hidden owner, private target, private discard,
opponent hand, or AI private plan.

The target player's private surface may show the actionable offer and exact
accept/decline consequences. The initiator's private ledger may retain traceable
party data only through existing private-intel paths. Intel trace output must use
the sanitized stored result and preserve viewer authorization.

All Bench manifest, report, UI snapshot, save preview, and debug data are limited
to Dictionary, Array, String, Number, Bool, and null. No Callable, Node, Object,
or Resource is allowed.

## Ruleset v0.4 decisions locked in Sprint 51

1. **Project-controller authority**: the target product project's unique
   `controller_player_index` receives the response. Missing authority returns
   `missing_target_product_project`; multiple controllers return
   `ambiguous_target_project_controller` without mutation.
2. **Explicit self-sign permission**: a player controlling both endpoints may sign
   only when the card sets `contract_allow_self_sign=true`.
3. **Visible-time guarantee**: the five-second timer decreases only while that exact
   offer is the visible forced decision. Monster wager and counter preemption suspend
   it, so a hidden contract never loses response time.
4. **Non-blocking continuation**: contract forced candidates publish
   `blocks_card_resolution=false`; ordinary later cards continue while the private
   response remains pending.

## Sprint 51 completed deletion map

Sprint 51 moved the state, endpoint/product context, visible-time lifecycle,
response transaction, save data, sanitized clues, and public/private receipts into
one `ContractRuntimeController` plus a non-owning `ContractRuntimeWorldBridge`.
The following `main.gd` owners were deleted after the 62-case gate passed:

- selection and context: `_valid_contract_source_district`,
  `_valid_contract_target_district`, `_set_selected_contract_source_district`,
  `_set_selected_contract_target_district`, `_area_trade_contract_context`,
  `_area_trade_contract_product_goal`, `_area_trade_contract_products`, and
  `_contract_limited_products`;
- offer lookup and UI source: `_active_contract_response_entry_for_player`,
  `_pending_contract_offer_index_for_id`, `_pending_contract_offer_by_id`,
  `_pending_contract_offers_for_player`, and
  `_runtime_contract_response_decision_snapshot_source`;
- lifecycle and response: `_enqueue_pending_area_trade_contract`,
  `_apply_area_trade_contract`, `_respond_to_pending_contract_for_player`,
  `_update_pending_contract_offers`, and `_store_pending_contract_result`;
- settlement orchestration: `_apply_area_trade_contract_accept`,
  `_apply_area_trade_contract_decline`, `_apply_contract_region_delta`,
  `_grant_contract_cash`, `_pay_contract_penalty`, and
  `_apply_contract_accept_route_flow`;
- presentation/trace helpers that are contract-only: district/pair/product labels,
  accept/decline summaries, result clue, remembered parties, traceable entries,
  party tracing, and contract intel trace dispatch.

The legacy state variables `pending_contract_offers`,
`selected_contract_source_district`, and `selected_contract_target_district`
and their direct v1 save handling also move to the Controller. The response
constants `CONTRACT_RESPONSE_PENDING`, `CONTRACT_RESPONSE_ACCEPTED`,
`CONTRACT_RESPONSE_REJECTED`, and `CONTRACT_RESPONSE_TIMEOUT` move with that
owner and were removed from `main.gd`. Existing action ids, signals, queue/execution ownership,
Formula Service formulas, AI decision ownership, and Overlay presentation remain
outside that Controller. No parallel legacy contract engine or compatibility
wrapper family remains after the hard cutover.
