# Post-Merge PlayerSeat Wiring Analysis

Date: 2026-07-18

## Defect

`PlayerSeatPublicSourceService` was bound to Main and attempted to discover `players` plus role/name/color/status through dynamic Main-style calls. Main did not expose the required `players` property. Separately, the real `TablePresentationViewModelQuery._planet_source` path never injected `public_player_seat_sources`, so the legacy coordinator enrichment did not repair live/full presentation snapshots.

## Repair

The scene-owned service now accepts only `WorldSessionPublicProjection` and the authorized local viewer index. It uses the projection's allowlisted `player_index`, `public_player_name`, assigned `role_name`, and elimination/status facts. It derives the established public seat color by index, emits exactly one local marker, rejects duplicate indices and invalid active roster sizes, and returns zero seats before a session.

`GameRuntimeCoordinator` injects the typed service into `TablePresentationViewModelQuery`. The query adds seats inside the real planet source used by live/full snapshots. The service no longer binds to Main or performs dynamic role lookup. The obsolete coordinator-side table-source enrichment was removed.

The service caches by a public roster signature instead of world time. Repeated presentation frames query the cache without rebuilding the seat source; new-game replacement, load restoration, role/name/status changes, or viewer changes update the signature and rebuild once.

## Privacy

The output allowlist contains only public player index, name, assigned role, color, local marker, public status, and anonymous-safe activity flags. Tests inject cash, hand, discard, hidden owner, real actor, AI plan, and private role intel into authoritative player fixtures; none reaches the seat descriptors. Anonymous activity never highlights a real seat.

## Remaining Main Debt

Main still owns a legacy `PLAYER_COLORS` constant and `_player_color` helper for unrelated legacy surfaces. The seat service carries the matching eight public colors because the allowed public projection does not yet expose a typed player-color identity fact. A future typed public player-identity owner should become the single color authority before Main deletion. No role catalog or Main method was added or copied.

This repair does not alter seat coordinates, Skin style, portraits, setup semantics, save schema, AI, cards, economy, gameplay rules, or Compendium.
