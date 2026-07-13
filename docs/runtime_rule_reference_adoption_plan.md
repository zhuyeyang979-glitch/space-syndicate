# Runtime Rule Reference Adoption Plan

Status: reference set accepted, implementation not started
Recorded: 2026-07-14

## 1. Decision

The economy, card-rule, AI, and monster references are useful as conformance models and offline analysis tools. They are not replacement engines.

Space Syndicate already has one authoritative runtime owner for each relevant domain:

- `GdpFormulaRuntimeController` for city GDP arithmetic;
- `EconomyCashflowRuntimeController` for payout cadence and remainder conservation;
- `ProductMarketRuntimeController` for market and futures state;
- `CityTradeNetworkRuntimeController` for routes, flow, disruption, and refresh order;
- `CardPlayEligibilityRuntimeService`, Queue, and Execution for card legality and lifecycle;
- `AiRuntimeController` for AI decisions;
- `MonsterRuntimeController` for monster state, movement, combat, wager, and save data.

Adding Project Alice, Unknown Horizons, OpenVic, CSBCGF, boardgame.io, OpenSpiel, Forge, OpenXcom, or Cataclysm as a second runtime would reverse completed hard cutovers and make `main.gd` ownership ambiguous again.

## 2. Current Rule Boundary

### Economy

The current v0.4 GDP formula is a game-economy profile, not a national-accounts simulator. It builds production, demand/route, transit, contract, and bonus income, then subtracts competition, route, damage, control, and military pressure before applying an active-city floor.

This formula is Inspector-backed and already drives first-mission pacing. A value-added model is a strong diagnostic for detecting double counting, but changing the production formula is a rules and balance decision. It cannot happen as an unversioned refactor.

### Cards

The current architecture already matches several strong CSBCGF principles:

- Eligibility produces stable legal/illegal results and reasons.
- Queue owns authorization, grouping, bids, and atomic submission.
- Execution owns the resolution lifecycle.
- Effect-family services own bounded mutations.
- Public/private snapshots are separated from runtime state.

The remaining opportunity is to prove execution-time revalidation and simultaneous-effect semantics across all real effect families, not to add a new action queue.

### Monster And AI

`MonsterRuntimeController` owns monsters as single logical entities and delegates world damage through a narrow world adapter. `AiRuntimeController` selects intents but does not own world mutation. This is already the correct basis for large creatures: presentation may be large or multipart, but pathfinding and rules keep one logical actor.

The desired economic consequence chain is:

```text
monster intent
-> monster action resolution
-> district / city / route / warehouse damage receipt
-> CityTradeNetwork and ProductMarket refresh
-> next GDP calculation
-> EconomyCashflow payout
```

Directly subtracting GDP inside a monster action would bypass domain ownership and is forbidden unless the rule explicitly defines a temporary GDP-pressure effect owned by the appropriate controller.

## 3. Reference Application Matrix

### Economy

| Reference | Apply | Do not apply |
| --- | --- | --- |
| Project Alice | Module boundaries for goods, production, population, and update passes; stress-test ideas for a large economy. | GPL code, original-game assets, or its full macroeconomic scope. |
| Unknown Horizons | A comprehensible supply-demand-consumption-tax loop and readable settlement progression. | GPL implementation or city-builder assumptions that conflict with card-authored urbanization. |
| FreeOrion | Universe/empire/combat/script separation and planet-level resource allocation. | GPL code, art, UI identity, or turn structure. |
| OpenVic-Simulation | Deterministic simulation objects and daily/monthly update organization. | A second clock, population engine, or runtime state model. |
| BEA value-added approach | Offline double-count audit: output minus intermediate inputs. | Silent replacement of `gdp_formula_v04`. |

### Cards And AI Evaluation

| Reference | Apply | Do not apply |
| --- | --- | --- |
| CSBCGF | Action-only mutation, execution-time legality recheck, event boundaries, reaction queue, simultaneous groups. | A second card state, deck, hand, queue, target, or trigger engine. |
| boardgame.io | State/view separation, action permissions, logs, replay fixtures, deterministic move tests. | Its turn loop or networking layer as a replacement for the realtime 30/25/5 window. |
| OpenSpiel | Offline imperfect-information and simultaneous-action balance experiments using sanitized snapshots. | Godot runtime dependency, live authority, or access to hidden information unavailable to a player. |
| Forge | Taxonomy for complex triggers, replacement effects, continuous effects, priority, and AI edge cases. | GPL code, MTG content, names, rules text, or card data. |

### Monster Combat

| Reference | Apply | Do not apply |
| --- | --- | --- |
| Godot Roguelike Example | Godot component organization, data-driven actions/status/resistance, behavior-tree inspection tools. | Turn-based conversion, copied art, or another AI owner. |
| OpenXcom | Target score factors, armor/facing, morale/panic, and tactical consequence readability. | GPL code, original assets, or a grid tactics layer. |
| Cataclysm: DDA | Rich monster data vocabulary and the warning against multi-tile pathfinding complexity. | Multi-cell monster rule bodies, copied data, or share-alike content without an explicit licensing decision. |

## 4. Value-Added Diagnostic Contract

The first economy experiment must be tool-only and pure data. It may compute:

```text
facility_value_added = gross_output_value - intermediate_input_value
planet_value_added = sum(facility_value_added) + product_taxes - subsidies
tax_revenue = planet_value_added * effective_tax_rate * collection_efficiency
real_growth = current_real_value_added / prior_real_value_added - 1
```

The diagnostic report must compare, for the same fixed world snapshot:

- current v0.4 GDP by city and product project;
- diagnostic gross output;
- intermediate inputs;
- diagnostic value added;
- potential double-count amount;
- current player payout;
- hypothetical payout if the alternative formula were adopted;
- time to first positive income and target-cash pacing.

No diagnostic value enters live cash, market, AI, scenario progress, save data, or UI snapshots.

## 5. Card Action Atomicity Contract

Future conformance work should require:

1. A queued action carries its authorization context and revision.
2. Execution obtains fresh world facts immediately before mutation.
3. Eligibility or the owning effect service revalidates all required facts.
4. A failed revalidation produces no cost, target mutation, ledger event, reaction, or public clue.
5. A successful action commits once and emits one receipt.
6. Simultaneous effects capture all participants before applying removals or defeat cleanup.
7. Reactions run only after the action or simultaneous group has committed.
8. Public logs contain only information available under the current privacy contract.

These checks should extend the existing Queue, Eligibility, and Execution gates. A new generic `ActionEngine` is explicitly forbidden.

## 6. Monster Consequence Contract

For each real monster action family, the audit must record:

- selected target and public telegraph;
- movement receipt;
- district/city/route/warehouse damage receipt;
- market and network refresh count/order;
- GDP before the action;
- GDP after the next authoritative refresh;
- cashflow before/after the next cadence tick;
- public clue and private owner boundary;
- exact-once mutation and save behavior.

Monster archetype labels such as predatory, destructive, and parasitic may be added as data-driven AI policy tags only after mapping them to existing original monsters and actions. They must not replace the current roster or introduce copied creature identities.

Suggested tendencies:

- predatory: public population/city density pressure;
- destructive: high-output city, industrial project, or high-value facility pressure;
- parasitic: route, energy, warehouse, and logistics-node pressure.

The AI still selects an intent from legal candidates; the relevant world controller performs the mutation.

## 7. Retirement Opportunities

### Eligible After Call-Graph Proof

| Candidate | Replacement | Deletion condition |
| --- | --- | --- |
| Any residual direct card mutation outside Inventory/Queue/Execution/effect-family owners | Existing service receipt path | Real-card characterization proves exact behavior and all callers migrate in the same sprint. |
| Any duplicate execution-time legality formula outside Eligibility/effect owner | Fresh-facts revalidation API | Stable reason/action behavior and atomic failure gates pass. |
| Any monster path that writes derived GDP instead of world damage/pressure facts | World damage receipt followed by network/market/GDP refresh | Before/after consequence parity and exact refresh order pass. |
| Duplicate GDP formatting or calculation branch outside `GdpFormulaRuntimeController` | Controller breakdown plus Presentation/ViewModel | Source scan and runtime gate prove zero callers. |
| Obsolete economy constants duplicated outside Inspector Resources | Existing profile Resource | Resource load failure is explicit and no fallback remains. |
| Reflection wrappers retained only for old tests | Public Controller/Service API | Tests migrate; no production caller remains. |

### Must Remain

- Current domain controllers and service ownership.
- Ruleset v0.4, action IDs, signals, save version, and privacy filters.
- Shared RNG owner and deterministic consumption order.
- Existing first-mission and card-authoring content.
- Third-party attribution and reference notes.

## 8. Development Roadmap

### Sprint Q1: Card Action Revalidation And Simultaneous-Group Characterization

- Extend existing Eligibility/Queue/Execution benches, not a new parallel bench family.
- Use real cards from each effect family.
- Lock queue authorization versus execution authorization, cash/target drift, exact-once receipts, reaction ordering, and simultaneous damage behavior.
- Production behavior stays unchanged during characterization.

### Sprint Q2: Card Atomicity Hard Alignment

- Only for observed gaps, add narrow revalidation/transaction APIs to the current owners.
- Delete duplicate direct mutation and legality branches in the same change.
- Keep Execution narrow; effect formulas remain in their family services.

### Sprint E1: Value-Added GDP Diagnostic Sandbox

- Add a tool-only pure calculation service and report driven by real snapshots.
- Compare v0.4 GDP against value added under fixed first-table, route disruption, warehouse damage, weather, and contract cases.
- Do not switch runtime source.

### Sprint E2: Versioned GDP Design Decision

- Wait for human playtest and balance evidence.
- If v0.4 remains more fun/readable, retain it and keep value added as a diagnostic.
- If value added is adopted, create a new versioned profile and cut over once; delete the old runtime formula branch rather than maintaining two live formulas.

### Sprint M1: Monster Economic Consequence Characterization

- Extend the existing Monster Runtime gate with city, route, warehouse, market, GDP, and cashflow order checks.
- Prove no action directly owns derived GDP.
- Keep one logical monster entity regardless of visual scale.

### Sprint M2: Monster Consequence Hard Alignment

- Move only observed bypasses to the correct world-owner receipt path.
- Delete old direct mutations in the same sprint.
- Add data-driven tendency tags to existing Resource profiles only if they improve current AI explainability.

### Sprint O1: Optional OpenSpiel Offline Adapter

- Export a sanitized, versioned observation/action schema from pure runtime snapshots.
- Use it only for deck/AI evaluation and exploitability experiments.
- Never load OpenSpiel in the shipped Godot runtime and never export hidden truth beyond the modeled observer.

## 9. Recommended Sequence

Before human pacing tests resume, the best implementable work is Q1 followed by M1. Both characterize high-risk transactional boundaries, support future deletion from `main.gd`, and do not require subjective balance tuning.

E1 is valuable after those gates, but E2 must wait for a versioned design decision and playtest evidence. O1 is optional and should come only after the runtime observation/action schema is stable.

## 10. Acceptance Gates

- One owner per economy, card, AI, and monster domain.
- No reference project becomes a runtime dependency without an explicit licensing and ownership decision.
- Queue authorization and execution revalidation are independently tested.
- Failed actions leave no partial mutation or reaction.
- Simultaneous groups resolve from one pre-group state.
- Monster attacks change GDP only through authoritative world consequences and subsequent refresh.
- Value-added results remain diagnostic until a versioned rules cutover.
- Offline AI data is viewer-sanitized and pure.
- Any deleted legacy path has zero source/test references and a real-runtime parity gate.
- Existing FirstMission, composition, layout, privacy, and Godot error gates stay green.
