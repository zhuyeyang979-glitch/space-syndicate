# First Table Public Rack Recommendation v0.6

## Active boundary

`FirstTableAuthoredRuntimeService` is a read-only teaching service. It may
recommend a card only from the current public RegionSupply rack snapshot. It
does not own RegionSupply, CardFlow, purchases, quotes, inventory, facilities,
monsters, randomization, or UI navigation.

The active input is recursively pure data with:

- `visibility_scope = public`;
- the current `cards` array;
- a public region identity and public revision when available;
- only public card-face fields such as card identity, label, rank, kind,
  public teaching tags, target summary, and rule facts.

The service rejects snapshots containing cash, hands, purchase windows, private
owners or targets, AI plans or scores, shuffle-bag state, RNG state, draw
cursors, future cards, or other non-public RegionSupply internals.

## Recommendation rule

The service evaluates only cards that are already visible in the supplied
snapshot. Explicit public tutorial tags and lower rank may improve teaching
clarity. Otherwise equal candidates preserve their current rack order with a
stable card-id tie-break.

Facility category is not a priority rule. A market may be recommended before a
factory, a factory may be recommended before a market, or neither may be
present. The service never invents a missing pair or assumes that one category
must unlock the other.

The recommendation is a presentation hint. It never:

- reserves a slot;
- injects or replaces a card;
- refreshes the rack;
- advances its revision;
- reads the next card or shuffle bag;
- creates a quote or purchase;
- mutates any caller-owned dictionary or array.

When no suitable public listing exists, the exact generic action hint is
`浏览当前牌架`. The player can inspect the current cards or wait for normal
gameplay purchases and single-slot refills. Teaching does not force a refresh.

## Retired assumptions

The active `first_table` scenario and service no longer carry:

- a fixed city-development or facility guarantee;
- a fixed source district;
- a named follow-up card or follow-up injection;
- featured-card, preferred-product, or starter-monster lists;
- a fixed monster slot;
- factory-before-market or market-before-factory ordering.

Legacy fixture keys are ignored if an old definition is supplied. Compatibility
catalog input is also ignored because a global catalog is not the current
randomized rack. Methods such as `market_listing_plan()` and `supply_plan()`
return inert, read-only recommendation envelopes and cannot mutate
RegionSupply.

Map seed, phase ids, success signals, pacing milestones, and gameplay formulas
remain unchanged.

## Composition requirement

The production world adapter supplies the current public RegionSupply rack
snapshot to `compose_runtime_content()`. It must not substitute a catalog-wide
card list, a private purchase snapshot, a fabricated guarantee listing, or a
future bag preview.

The returned content exposes the first current-rack recommendation, an optional
second recommendation from another current slot, generic fallback guidance,
the public rack revision, and existing sanitized public world observations.
Actual visible monster pressure may be described; the service never chooses a
starter monster.

## Verification

- `tests/first_table_authored_runtime_service_test.gd` validates public-only
  input, category-neutral current-rack selection, generic fallback, privacy,
  immutability, inert compatibility APIs, and unchanged pacing signals.
- `scenes/tools/FirstTableAuthoredRuntimeCutoverBench.tscn` provides the
  inspectable Godot 4.7 MCP characterization bench.
