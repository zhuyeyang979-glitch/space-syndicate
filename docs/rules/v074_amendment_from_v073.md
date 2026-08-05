# V0.7.3 to V0.7.4 Amendment

V0.7.4 keeps V0.7.3's card batch, DBG, unified track, asset, fixed hidden
round-robin, contention Fizzle, victory, privacy, and new-game-only sample rules.
It replaces the map, facility registry, warehouse, solar-map projection, map
targeting, local unified-track capacity/timing, asset-pool presentation, and
legacy Main architecture domains.

The fixed six-region alpha-zeta world was a sample fixture. V0.7.4 accepts an
independent region count and geography complexity, generates one authoritative
closed spherical microcell partition, classifies regions as land or ocean, and
derives sunlight geometrically. Presentation consumes that receipt instead of
inventing geography.

The complete facility registry is now `factory`, `market`, and `warehouse`.
Starter types remain only `factory` and `market`. Warehouse is a standard card,
so each region receives 18 potential facility slots rather than 12.

Warehouse supports the inherited facility action modes and contention policy.
It publishes capacity and solar-adjusted ingress/egress throughput while hiding
stock detail and private logistics. This amendment does not invent terrain
bonuses or an unsupported stock economy.

The local segment of the shared sushi track now exposes ten physical positions
and starts with ten unique real cards. The 6000/4000 normal-to-commodity supply
ratio, segment privacy, exact-once claims, and replacement lock are unchanged.
Buying or claiming a card does not immediately draw or slide in a successor.
It leaves a noninteractive vacancy at that shared path position; all surviving
cards keep their positions until natural shared scrolling moves the path. The
vacancy is filled only after it reaches the shared tail and a natural head draw
restores full capacity. Slow track movement remains presentation-only.

The local asset pool replaces primary `2/6`-style fractions with exactly six
symbol positions per color. Available, reserved, empty, and projected-refresh
states share those positions. This is a projection-only change: caps, balances,
reservation timing, GDP refresh, overflow, costs, privacy, Save, AI observation,
and RNG remain unchanged.

All amended production domains cut over together. No fixed-six,
factory/market-only, static-disc, or legacy Main fallback remains after the
integration gate passes.
