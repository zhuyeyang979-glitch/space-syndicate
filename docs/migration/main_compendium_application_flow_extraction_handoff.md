# Main Compendium application-flow extraction handoff

Status: `MAIN_COMPENDIUM_READ_ONLY_NAVIGATION_EXTRACTION_GREEN`

The read-only Compendium is now fully scene-composed and does not call Main for
internal navigation, queries, rendering or returns. Main translates only
external gameplay/Intel intents into typed public navigation requests.

## Main budget

| Metric | Task baseline | After cutover |
| --- | ---: | ---: |
| Physical lines | 12,505 | 11,405 |
| Nonblank lines | not separately supplied | 9,886 |
| Methods | 788 | 716 |
| Constants | not separately supplied | 104 |
| Preloads | not separately supplied | 10 |
| Fields | not separately supplied | 66 |

The reduction is structural, not formatting compression. `PLAYER_ROLE_CATALOG`
and the old Compendium method cluster are absent.

## Scene ownership

- `CompendiumNavigationPort.tscn`: typed input boundary, no state owner.
- `CompendiumApplicationFlowController.tscn`: exact-once orchestration, no Main.
- `CompendiumReadOnlyQueryPort.tscn`: pure-data public page composition.
- `CodexNavigationRuntimeController`: sole navigation state and return-stack owner.
- `MenuOverlay/CodexCompendiumSurface`: page shell and static renderer.

## Next boundary

`INTEL_QUERY_COMMAND_SPLIT_CUTOVER`. Intel still owns viewer-private guesses and
uses the transitional generic application action for its page. Do not move that
mutation into the read-only Compendium flow.
