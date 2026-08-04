# V0.7.3 to V0.7.4 Amendment

V0.7.4 keeps V0.7.3's card batch, DBG, unified track, asset, fixed hidden
round-robin, contention Fizzle, victory, privacy, and new-game-only sample rules.
It replaces only the map, facility registry, warehouse, solar-map projection,
map targeting, and legacy Main architecture domains.

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

All twelve amended production domains cut over together. No fixed-six,
factory/market-only, static-disc, or legacy Main fallback remains after the
integration gate passes.
