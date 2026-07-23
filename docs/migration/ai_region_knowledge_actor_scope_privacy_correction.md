# AI Region Knowledge Actor-Scope Privacy Correction

## Boundary

This follow-up fixes two foundation-port defects without creating another Port,
state owner, or save section:

1. one shared `AiRegionKnowledgeCapability` previously authorized every AI
   actor index;
2. actor region snapshots exposed per-city warehouse count, units, and product
   names for rival cities.

The parent `P0-AI-WORLD-TYPED-PORTS-CUTOVER` remains active.

## Capability Contract

`GameRuntimeCoordinator` now issues one opaque token per current AI seat and
binds the same actor-indexed map to `AiRegionKnowledgeQueryPort`,
`AiCityInferenceCommandPort`, and `AiRuntimeController`. Authorization requires
the exact token identity for the requested actor.

Roster replacement, World restore, and GameSession identity changes reissue the
map. Old, forged, rival, and human tokens fail closed. Rebinding also clears the
existing bounded city-command journal, preserving its session-scoped
exact-once behavior without adding persistent AI state.

## Privacy Correction

Public and rival city rows omit:

- `warehouse_stockpile_count`;
- `warehouse_stockpile_units`;
- `warehouse_stockpile_products`.

Those fields remain available only on a city owned by the requesting actor.
Public routes, products, demands, clues, and GDP retain their prior projection.
The three warehouse policy weights remain `34`, `8`, and `10`; they now consume
only authorized own-city facts.

The representative rival-city priority changes from `84` to `54`. This is the
documented `PRIVACY_CORRECTION` allowed by the parent contract, not a policy or
personality adjustment.

## Evidence

- focused region/city typed-port test: 57/57 PASS;
- cross-actor query and command: rejected;
- stale roster, restore, and session tokens: rejected;
- own warehouse projection: retained;
- rival and public warehouse projection: absent;
- actor-state, card-eligibility, Setup transaction, session envelope, Main
  composition, and Main architecture regressions: PASS;
- Godot MCP GDScript scan: 206 files, 0 errors;
- new Save Registry sections: 0.

Full-run resume and the parent P0 completion claim remain false.
