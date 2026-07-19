# Main Intel application-flow inventory

Status: `MIGRATED`

## Production ownership

| Concern | Production owner | Boundary |
| --- | --- | --- |
| Plain Intel open | `ApplicationFlowPort` | `submit_action("intel")` emits only `intel_requested` |
| Focused Intel open | `ApplicationFlowPort` | validated `IntelApplicationIntent` emits only `intel_application_intent_requested` |
| Open/query/apply | `IntelApplicationFlowController` | one query and one board apply per accepted open |
| Authorized read model | `IntelDossierViewerQueryPort` | local viewer authorization plus detached pure data |
| City inference state | `WorldSessionState` | typed set/clear/confidence/reason APIs |
| Card annotations | `CardHistoryPrivateAnnotationService` | narrow typed adapter methods; save schema unchanged |
| Public region evidence | `RegionCodexPublicSourceService` | audited public source only |
| Public deep links | `CompendiumNavigationPort` | typed region/product/monster/card requests |

## Scene wiring

`MenuOverlay` and `GameScreen` send focused intents to
`ApplicationFlowPort.submit_intel_application_intent`. The port's dedicated
typed signal is the only scene connection to
`IntelApplicationFlowController.open_application_intent`. Direct UI-to-
controller connections and generic `action_requested` Intel dispatch are zero.

## Deliberate exclusions

- City reveal and contract-trace role buttons remain unavailable because no
  durable production command owner exists for those actions.
- Manual confidence accepts only 1-3. Confidence 100 is written solely by the
  authorized `WorldSessionState.apply_authorized_city_reveal` path.
- Retired card-owner guess economy is not restored.
- This migration does not move setup/new-game, save ownership, AI policy, or
  final-settlement authority.

## Retained formulas

Main's `_player_intel_stats` settlement formula and its summary chain remain as
an explicit compatibility hold. No production FinalSettlement consumer was
found; `FinalSettlementPublicSnapshotService` still reports that it does not
calculate Intel cash, so settlement parity is not green. AI candidate scoring
and ordering now live with their real consumer in `AiRuntimeController`, while
the typed world bridge delegates only the owner mutation to `WorldSessionState`;
this extraction changes neither strategy nor values.
