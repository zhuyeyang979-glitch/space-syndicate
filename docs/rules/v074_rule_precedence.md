# V0.7.4 Rule Precedence

```text
PRECEDENCE_ID=space_syndicate.v074.rule_precedence.v1
HIGHEST_RULE_AUTHORITY=V0.7.4_COMPLETE_CONSTITUTION
TARGET_PRODUCTION_RUNTIME_RULESET=v0.7.4
DUAL_WRITE_ALLOWED=false
LEGACY_FALLBACK_ALLOWED=false
```

Conflicts are resolved in this order:

1. The user's latest explicit decision.
2. `docs/rules/v074_game_constitution.json`.
3. `docs/rules/v074_game_constitution.md`.
4. `docs/rules/v074_amendment_from_v073.json`.
5. `docs/rules/v074_amendment_from_v073.md`.
6. V0.7.3 constitution and defaults for domains not amended by V0.7.4.
7. V0.7.2, V0.7.1, and V0.7 historical constitutions.
8. Older rulebooks, reports, tests, and code behavior.

V0.7.4 exclusively owns map genesis, dynamic region identity, terrain,
facility-type and slot registries, warehouse runtime structure, geometric
solar facts, dynamic map projections, planet presentation, map targeting, and
legacy Main retirement. A fixed-six test, alpha-zeta fixture,
factory/market-only array, index-based sun shortcut, or old Main reference
cannot override those decisions.

The V0.7.3 rules remain authoritative for all inherited domains. In
particular, V0.7.4 keeps fixed hidden round-robin resolution, prebound targets,
full asset reservation, contention Fizzle, zero-asset Starters, unified track,
DBG, privacy, Victory, and FinalSettlement unless this constitution explicitly
states otherwise.

The integration cutover must connect all amended owners at once. Before that
merge, this Lane A implementation is detached and cannot dual-write production
state. After the atomic gate, production identifies as V0.7.4 and no V0.7.3
fixed-map fallback remains.
