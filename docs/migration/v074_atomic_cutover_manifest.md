# V0.7.4 Atomic Cutover Manifest

This manifest owns the production transition from the fixed V0.7.3 sample map
to the V0.7.4 authoritative roguelike planet. It does not reopen V0.6 or the
Alpha 0.4-C reliability track.

The cutover is atomic across twelve domains:

1. map genesis;
2. region registry;
3. terrain registry;
4. facility type registry;
5. facility slot registry;
6. warehouse runtime;
7. warehouse card catalog;
8. warehouse AI projection;
9. warehouse player projection;
10. solar geometry;
11. planet presentation;
12. map target selection.

Every domain must finish with one connected owner, its V0.7.3 temporary path
disconnected, an explicit RNG declaration, and an explicit rollback boundary.
No domain may finish in a partial, dual-write, legacy-fallback, or mixed-ruleset
state.

The V0.7.4 sample remains New Game only. The manifest therefore declares no new
Save owner and does not permit V0.6 save application or write-through.

The JSON companion is intentionally initialized as `planned`. Integration may
change a domain to `connected` only after its production wiring and focused
MCP evidence both pass at the same commit.
