# V0.7.5 Lane D Handoff

Status: **GREEN**

Lane D implements the owner-private instant monster skill contract and detached combat checkpoint contract. It does not wire production runtime, UI, main scene, catalog, constitution, or any hot integration file.

## Ownership

- Branch: `codex/v075-lane-d-private-skills-bd0af5c`
- Base: `bd0af5c99c5267cdbe7d66c01034f80db4d704fd`
- MCP: Role B, logical Lane D, `127.0.0.1:7574`, Godot 4.7-stable
- Production cutover domains: private instant skill authority contract and detached checkpoint contract only
- Hot-file conflicts: none

## Delivered Contract

`V075MonsterPrivateSkillCore` is a pure-data authority core with `private_instant_serial` execution. Requests receive an authority sequence and are ordered by sequence, stable player ID, then request ID. A request with no atomic transaction becomes eligible immediately after its asset reservation receipt. A request received during a public Receipt is blocked until that Receipt completes, and the core prevents a new public Receipt from starting before the due private request is drained. Atomic and private-resolution reentry are rejected.

The core never owns or mutates asset balances. It reads only the acting owner's `own_available_assets` projection, emits `V075MonsterSkillAssetReservationRequestV1`, accepts the Asset Owner's typed receipt, and later emits an exact-once commit or full-release settlement intent. Preaccept rejection is free. An accepted fizzle releases the full reservation, starts no cooldown, and still consumes the source's one skill use for that batch.

Successful use enters authored batch cooldown. Batch advancement decrements cooldown exactly once and restores READY at zero. Downed sources show DISABLED while preserving the READY/COOLDOWN resume state. Recovery restores that state. Destroyed, withdrawn, or replaced sources revoke all skills and disappear from the owner dock. Upgrades preserve existing cooldown counters and unlock new skills as READY; the L4 definition contract requires an ultimate.

## Privacy

Owner projection is reconstructed from a private whitelist and includes only that viewer's skill definitions, costs, target contracts, cooldowns, states, and pending target request. Public projection is independently rebuilt from a public whitelist and contains only source summary, unlocked count, per-batch use count, and resolved public aftermath.

Public projection contains no skill definition IDs, card list, costs, cooldown detail, request ID, target request, reservation ID, execution intent, or authority sequence. The final MCP bench reports both public skill-card disclosure and future-target disclosure as zero.

## Exact Once And Checkpoint

Request IDs, reservation receipts, and effect receipts are fingerprint-bound. Exact replay returns the prior receipt without a second asset request, commit, release, public result, cooldown transition, or batch-use mutation. Reusing an ID with another fingerprint is rejected.

`V075CombatCheckpointV1` supports detached `CombatCheckpointV1`, `MonsterSourceCheckpointV1`, `MonsterSkillCheckpointV1`, and `MilitaryMissionCheckpointV1` envelopes. Capture is a deep pure-data copy, bound to lineage, revision, and the receipt fingerprint prefix. Rollback restores the exact request queue and ledgers, rejects future/cross-lineage checkpoints, and never writes a production Save slot. The main coordinator must place component rollback under its full combat transaction fence.

## Integration Order

1. The single `V075CombatRuntimeOwner` owns one core state.
2. It calls `submit_request` with the acting owner's local asset projection.
3. It sends the returned reservation request to the Asset Owner, then calls `apply_asset_reservation_receipt`.
4. If no transaction is inflight, it calls `take_next_ready_request` immediately. Otherwise it completes the current Receipt first and drains the request before opening another Receipt.
5. It resolves the target/effect through combat and facility typed ports and passes the resulting effect receipt to `resolve_current`.
6. It sends the returned commit/release settlement intent to the Asset Owner exactly once.
7. It routes owner projection only to the matching owner and public projection to all public/rival views.
8. It calls `advance_batch` once at the authoritative batch boundary.

## Validation

- MCP script validation: 12/12 changed GDScripts (3 implementation/bench plus 9 tests)
- Focused tests: 9/9, 66/66 assertions
- Real MCP scene: `res://scenes/tools/v075/V075MonsterPrivateSkillBench.tscn`
- Runtime bench: 28/28, failures 0
- Execution mode: `private_instant_serial`
- Public skill-card disclosure: 0
- Direct asset writes: 0
- Fizzle cooldown starts: 0
- Checkpoint pure data: true
- Final MCP error log: 0
- Play Mode stopped cleanly; Role B editor stopped cleanly; port 7574 closed

The first isolated editor import surfaced unrelated parent diagnostics and reopened an old `@tool` bench that called `quit()`. No Lane D file existed at that point. The final dedicated Lane D scene is non-tool, passed cleanly, and reported zero Lane D/runtime errors.
