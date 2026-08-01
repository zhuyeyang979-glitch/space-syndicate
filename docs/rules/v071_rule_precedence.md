# V0.7.1 Rule Authority

```text
HIGHEST_TARGET_RULE_AUTHORITY=V0.7.1_COMPLETE_CONSTITUTION
CURRENT_PLAYER_RUNTIME_RULE_AUTHORITY=V0.6_RULEBOOK
FULL_V0_7_1_RUNTIME_CUTOVER=false
```

Use the latest explicit user decision first, then the V0.7.1 JSON and Markdown
constitution, then the immutable V0.7 JSON and Markdown baseline. The V0.6
rulebook remains authoritative only for the currently executing production
runtime. Older documents, tests, and code cannot veto a newer target rule.

The docs-only V0.7.1 freeze does not connect Core, adapters, Save, RNG, AI,
Player projection, scenes, or production. Production can change only through an
explicit atomic-cutover task after PR #77 is complete.
