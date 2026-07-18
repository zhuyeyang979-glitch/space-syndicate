# Compendium v0.6 semantics review

Status: `GREEN`

The public Compendium now reads the v0.6 public catalog and owner projections.
It does not initialize gameplay state while being opened.

## Card pages

- Commodity cards are free to acquire and free to play.
- Non-commodity cards pay cash on purchase and assets on play.
- Conditions and targets come from the current public catalog/eligibility data.
- Retired city/project shares, project GDP, accept/decline contracts, route HP,
  route damage/repair, retired direct cash/GDP/region damage and legacy fees are
  excluded from player-facing pages.

## Region pages

Region pages describe shared region HP/integrity, ruins, public facilities and
facility owners, production, demand, throughput, public aggregate GDP, weather,
public monster pressure and public card sources. They do not describe a single
city owner or an abstract damageable route.

## Other domains

Role pages consume the strict public role projection. Monster pages exclude
hidden ownership, selected targets, RNG and internal weights. Product pages use
a read-only public projection and expose no private warehouse/futures position.
Session completion does not broaden any page's visibility.

Evidence: `res://tests/compendium_v06_public_semantics_test.gd` and the focused
Card, Monster, Product, Region and Role public-source tests.
