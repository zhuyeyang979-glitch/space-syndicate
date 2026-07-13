# Space Syndicate Ruleset v0.4 Runtime Cutover

`res://resources/rules/space_syndicate_ruleset_v04.tres` is the Inspector-editable source of truth for stable v0.4 timing, card-group, forced-decision priority, and capability parameters.

`res://scenes/runtime/RulesetRuntimeBridge.tscn` is the production runtime boundary. UI snapshots and QA output use only dictionaries, arrays, strings, numbers, and booleans; the profile Resource never crosses that boundary.

## Sprint 1 cutover

- Shared card window timing is configured from the profile: 30 seconds total, 25 seconds organize, 5 seconds lock.
- Counter and contract response timing are read from the same profile.
- Monster wager timing is 20 seconds by default with a 30-second maximum.
- Final countdown timing is 75 seconds.
- The default card group remains 0-3 cards, with an explicit maximum capability of 4.

The existing card effects, auction settlement, monster combat, economy, AI, action ids, signals, save version, privacy boundaries, Balance source, and AI Policy source are unchanged.

## Deliberately not cut over

- Direct city build remains a legacy mismatch until product-project city development is proven end to end.
- The district purchase window lacks one authoritative 12-second owner.
- Forced decisions still use separate handlers and need one priority scheduler.
- The private plan slot is not implemented.
- The legacy End Turn compatibility surface remains.

These paths are registered in `RulesetV04ConformanceRegistry`. They should be replaced as complete, separately tested blocks instead of being polished further in place.

## Recommended next sprint

City Development Runtime Cutover has the highest immediate rules impact because v0.4 explicitly disallows direct city building and requires a product project. Forced Decision Scheduler should follow, using the profile priority without changing any existing temporary-decision action ids.
