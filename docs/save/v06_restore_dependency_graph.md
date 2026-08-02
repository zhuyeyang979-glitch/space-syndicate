# v0.6 restore dependency graph

The machine-readable design mirror is
[`v06_restore_dependency_graph.json`](v06_restore_dependency_graph.json). The
production registry's executable order remains the closed
`V06SaveOwnerRegistry.RESTORE_DAG_NODE_ORDER` constant. A contract test requires
the JSON order and every edge to match that production constant, so either side
drifting fails visibly; production does not load documentation as runtime
state. Node-tree order and frame waits are not restore dependencies.

| Phase | Work | Mutation allowed |
| ---: | --- | --- |
| 0 | Decode and validate the envelope and 19 wrappers | no |
| 1 | Pure owner and cross-section preflight; ruleset attestation | no |
| 2 | Capture 19 owner checkpoints plus foundation, clock, RNG, loop, capability, log and presentation checkpoints | no |
| 3 | Enter the restore barrier (`loading`, loop/AI/input/card/time/presentation stopped) | barrier only |
| 4 | Apply session identity, roster, world geometry, clock and player foundation | yes |
| 5 | Apply authoritative domain owners in topological order | yes |
| 6 | Rebuild routes and validate commodity-belt/ruleset attestations | derived cache only |
| 7 | Apply private history annotations and final session tail | yes |
| 8 | Reissue capabilities, rebind ports/caches, and request one full presentation refresh | bindings/derived only |
| 9 | Validate invariants and release the barrier | barrier only |

Deterministic order:

```text
ruleset
→ session_foundation
→ region_infrastructure
→ region_supply
→ commodity_flow
→ player_mana
→ card_inventory
→ player_organization
→ monsters
→ military
→ weather
→ card_resolution_queue
→ card_resolution_execution
→ card_resolution_history
→ ai
→ bankruptcy_neutral_estate
→ victory_control
→ routes
→ commodity_belt_visibility
→ session_tail
```

The order is one legal deterministic topological order, not a claim that every
adjacent pair has an edge. The JSON edge list is the machine-readable design
contract and must remain a valid topological subset of the production order.

## Queued facility bundle

A queued v0.6 facility action stays inside the same 19-owner envelope. Before
`card_resolution_queue` applies, its card instance and escrow must match the
`session` foundation, its nonzero cost reservation must match `player_mana`,
and its target revision and slot generation must match
`region_infrastructure`. The DAG therefore includes
`region_infrastructure -> card_resolution_queue`,
`player_mana -> card_resolution_queue`, and the existing
`card_inventory -> card_resolution_queue` edge.

Execution and history remain downstream owners:
`card_resolution_queue -> card_resolution_execution ->
card_resolution_history`. Cross-section preflight nevertheless inspects their
detached normalized candidates and requires no execution collision and no
history entry for a still-queued facility. This is a validation relationship,
not a reverse apply edge, so it introduces no dependency cycle. The queue
stores `submitted_at_world_time` as a nearest-integer millisecond and
resolution reconstructs the same authoritative timestamp from that value.

On failure, touched nodes are rolled back in the exact reverse of the actual
apply order. Session foundation, clock/RNG, capability generation and the
pre-load lifecycle state are then restored before the barrier is released.
