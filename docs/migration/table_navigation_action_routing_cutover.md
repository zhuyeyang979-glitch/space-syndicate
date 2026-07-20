# Table Navigation Action Routing Cutover

Date: 2026-07-20

Status: focused production cutover complete; the wider `presentation_action_routing`
domain remains pending.

## Scope

This atomic slice moves four read-only navigation actions out of the legacy
application root:

- open the selected region detail;
- open the card browser;
- open the Compendium hub;
- open a public card-track detail.

`GameScreen` now converts only those allow-listed action IDs into a detached
`TableNavigationActionIntent`. The production scene sends the typed intent to
the scene-owned `TableNavigationActionRouter`. The router consumes the existing
`TableSelectionState`, `CompendiumNavigationPort`, and `ApplicationFlowPort`.

The router does not own navigation history, table selection, gameplay state,
cash, cards, visibility policy, or UI layout. Other presentation and gameplay
actions remain on their existing path for later atomic cutovers.

## Authority and privacy boundary

- The selected region comes from the authoritative scene-owned
  `TableSelectionState`.
- Compendium requests continue through `CompendiumNavigationPort` validation.
- The Compendium hub continues through `ApplicationFlowPort`.
- Arbitrary source-surface strings never enter the public navigation context;
  the router emits the allow-listed public origin `game`.
- Intents contain no player cash, hand, hidden owner, anonymous actor, or AI
  metadata.
- Replayed request IDs and request-ID collisions fail closed before target
  application.

## Deleted legacy path

The legacy root no longer switches on `codex_region`, `codex_cards`, `inspect`,
or `track_open_*`. No fallback calls the legacy root when typed routing fails.
This removes 15 physical and 15 nonblank lines from `scripts/main.gd` without
adding a field, method, preload, or caller.

## Evidence

- `res://tests/table_navigation_action_router_test.gd`
- `res://scenes/tools/TableNavigationActionRouterBench.tscn`
- `res://tests/main_gd_architecture_gate_test.gd`
- Godot 4.7 production-scene and Bench runtime checks

The wider `presentation_action_routing` ledger item remains pending because
menus, purchases, forced decisions, wagers, and gameplay commands are outside
this read-only navigation slice.
