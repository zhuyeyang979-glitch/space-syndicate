# Compendium read-only navigation audit

Status: `MAIN_COMPENDIUM_READ_ONLY_NAVIGATION_EXTRACTION_GREEN`

## Production path

```text
ApplicationFlowPort.compendium_requested
  -> CompendiumApplicationFlowController
  -> CompendiumNavigationPort(CodexOpenRequest)
  -> CodexNavigationRuntimeController
  -> CompendiumReadOnlyQueryPort
  -> MenuOverlay.present_codex_page
  -> CodexCompendiumSurface.set_page
```

`CodexNavigationRuntimeController` remains the sole owner of domain, view,
stable item identity, page/filter/index, return target and the monster-to-card
return stack. The port and flow controller own counters only.

## Typed boundary

Allowed domains: compendium, role, card, monster, product, region.
Allowed views: hub, browser, preview, detail.
Allowed return targets: main, compendium, intel, economy, standings, game.

Requests contain only stable IDs, optional indexes, card filter, signed page
delta, return target, revision and an allowlisted public context. Object, Node,
Callable, unknown context keys, invalid filters, invalid IDs and duplicate
revisions fail closed.

## Read-only and exact-once contract

Each accepted request produces one navigation transition, one query and one
page application. Navigation does not change WorldSession, world-effective
time, RNG, market, commodity flow, routes, region infrastructure, weather,
monster, victory, cash/GDP, table selection, public log, command pipeline or
save state. Region browsing does not move the camera or table selection.

## Return behavior

- compendium returns to the hub;
- economy/standings use dedicated ApplicationFlowPort actions;
- intel uses its transitional generic application action;
- game closes the menu;
- main emits the current main-menu intent;
- monster-to-card deep links restore the exact prior monster detail location.

Evidence: `res://tests/compendium_readonly_navigation_cutover_test.gd` and the
Codex Navigation, Scene Hard Cutover, Atlas and Public Snapshot benches.
