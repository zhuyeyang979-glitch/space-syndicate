# V0.7.3 Rule Precedence

```text
PRECEDENCE_ID=space_syndicate.v073.rule_precedence.v1
HIGHEST_TARGET_RULE_AUTHORITY=V0.7.3_COMPLETE_CONSTITUTION
CURRENT_PLAYER_RUNTIME_RULE_AUTHORITY=V0.6_RULEBOOK
TARGET_RULES_DO_NOT_PRETEND_TO_BE_RUNTIME=true
```

When target rules conflict, use this order:

1. The user's latest explicit rule decision.
2. `v073_game_constitution.json`.
3. `v073_game_constitution.md`.
4. `v072_game_constitution.json`.
5. `v072_game_constitution.md`.
6. `v071_game_constitution.json`.
7. `v071_game_constitution.md`.
8. `v07_game_constitution.json`.
9. `v07_game_constitution.md`.
10. The V0.6 rulebook for current-production behavior only.
11. Older documents, tests, and code behavior.

The V0.7.3 JSON is the closed machine-readable target authority. Its Markdown
companion explains the same five amendment rules. V0.7.2 remains the complete
inherited source for everything V0.7.3 does not explicitly supersede.

This precedence update does not modify production. V0.6 remains the only
current player runtime, and V0.7.3 remains detached until an explicit atomic
cutover switches all affected domains together. Mixed V0.6 automatic facility
interpretation and V0.7.3 explicit modes are forbidden.

The approved order decision is final for this version: no initiative auction,
cash bid, secondary order Owner, bid Save state, bid UI, or bid AI policy may
modify batch resolution. The one order source is
`frozen_hidden_lead_order_at_batch_lock`, consumed by fixed hidden round-robin
layering.

```text
CURRENT_PRODUCTION_RUNTIME_RULESET=V0.6
HIGHEST_TARGET_RULESET=V0.7.3
FULL_V0_7_3_RUNTIME_CUTOVER=false
V073_PRODUCTION_CONNECTION_COUNT=0
V073_V06_MUTATION_COUNT=0
V073_DUAL_WRITE_COUNT=0
```
