# Decision Log

This file is the active decision index for implementation work. It is intentionally
short: rule wording belongs in `tabletop_rulebook_v06.md`, architecture detail belongs
in `ARCHITECTURE.md`, and historical migration evidence remains historical.

## Authority order

When sources disagree, use this order:

1. `docs/tabletop_rulebook_v06.md` for current game rules.
2. `docs/rules_v06_runtime_directive.md` for runtime ownership and cutover constraints.
3. `AGENTS.md` for repository workflow, privacy, and product boundaries.
4. Current focused production contracts and owner tests.
5. `README.md` active-v0.6 introduction.

Historical v0.4/v0.5 inventories, retired characterization benches, and old smoke/layout
assertions cannot override those sources. Never restore a deleted Main wrapper or a
second state owner to satisfy a historical test.

## Active v0.6 decisions

### D-001: Starter monster summon is voluntary

Each player selects and holds a starter monster card, but may summon it at any legal
time. Skipping summon does not block facilities, the economy, or normal-card purchases.
See rulebook section 9.

### D-002: Normal cards use the public sunlight market

Normal-card listings are globally visible and retain a public source region. A listing
is buyable only while that source region is on the authoritative sunlight hemisphere.
Camera drag, zoom, focus, and projection are local presentation state and never affect
sunlight or price. A quote locks eligibility and price for five `world_effective`
seconds. See rulebook sections 2.4 and 7.1.

### D-003: Living monsters raise a listing's public price

For base price `B`, let `same` be living monsters in the source region and `adjacent`
be living monsters in directly adjacent regions. Use
`q2 = min(10, 2 + 2 * same + adjacent)` and `ceil(B * q2 / 2)`. Ownership is irrelevant,
down or expired monsters do not count, all buyers see the same public result, and the
multiplier is capped at 5.0. See rulebook section 7.1.

### D-004: Buying and playing have separate costs

Buying a normal card pays the locked cash quote and puts the card in hand. Playing it
does not pay that cash price again; it consumes the card's declared asset requirement.
The five-card limit and target legality are checked by current owners. Retired private
discard rescue behavior must not be restored. See rulebook sections 5.1, 7.1, and 7.2.

### D-005: Bankruptcy requires negative cash

Bankruptcy is evaluated after an atomic settlement and occurs only when exact cash is
below zero. Zero cash remains solvent but cannot fund cash-requiring purchases. See
rulebook section 10.

### D-006: Victory is a control and Top-K GDP audit

Victory is not a simple cash target. A contender must satisfy the current region-control
and Top-K commodity-GDP qualification, hold it through the public audit, and pass the
final recheck. See rulebook sections 4 and 12.

### D-007: Public projections are viewer-invariant

Codex, map, market, standings, settlement, and public-track surfaces consume explicit
public projections. They must not depend on exact private cash, hand/discard contents,
hidden ownership, private city guesses, AI plans/scores, RNG tickets, or raw monster
target weights. Authorization tokens may bind a player privately; public fingerprints
must describe public facts only.

### D-008: Weather v1 is closed to new content during quality work

Weather v1 contains exactly the six definitions in `weather_system_v1_spec.md`. Current
quality work may fix integration, explanation, persistence, pacing, or presentation, but
must not add weather types or a second weather owner. The unique world clock remains
the source for weather timing.

## Quality milestone decisions

### Q-001: A passing focused test is not a playable-match claim

The frozen baseline is `docs/game_quality_baseline.md`. Completion requires real
full-match, save/resume, final-countdown, settlement, 1280x720, privacy, and headed
visual evidence. `smoke_test.gd --check-only` is only a parse/load gate.

### Q-002: Full regression failures are classified, not ignored

Every full layout/smoke failure must be classified as production, stale contract,
layout, rule clarity, feedback, AI, pacing/balance, or infrastructure. A stale oracle is
replaced with point-for-point current-owner evidence; it is never hidden with an ignore
list.

### Q-003: Main continues shrinking without wrapper farms

New quality services own coherent data or presentation responsibilities and are composed
by scenes/Coordinator. Main coordinates. A migration must remove old executable entry
points, add zero-reference and privacy gates, and avoid one-function forwarding layers,
duplicate state, or compatibility fallbacks.

## Updating this log

Add an entry only for a settled decision that changes implementation direction or
resolves an ambiguity. Link to the authoritative rule/spec/test. Do not use this file as
a development diary; uncertain proposals belong in a design note until decided.
