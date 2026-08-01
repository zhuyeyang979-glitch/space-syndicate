# V0.7.2 Rule Authority

```text
HIGHEST_TARGET_RULE_AUTHORITY=V0.7.2_COMPLETE_CONSTITUTION
CURRENT_PLAYER_RUNTIME_RULE_AUTHORITY=V0.6_RULEBOOK
FULL_V0_7_2_RUNTIME_CUTOVER=false
```

Use the latest explicit user decision first, then the V0.7.2 JSON and Markdown
constitution, then the immutable V0.7.1 JSON and Markdown constitution, then
the immutable V0.7 baseline. The V0.6 rulebook remains authoritative only for
the currently executing production runtime. Older documents, tests, and code
cannot veto a newer target rule.

V0.7.2 inherits the complete V0.7.1 freeze by exact SHA-256 and supersedes only
the explicitly listed Starter-bootstrap rules. The docs-only V0.7.2 freeze does
not connect Core, adapters, Save, RNG, AI, Player projection, scenes, or
production. Production can change only through an explicit atomic-cutover task
after PR #77 is complete.
