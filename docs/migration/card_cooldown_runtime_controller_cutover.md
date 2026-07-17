# Card cooldown runtime owner cutover

`CardCooldownRuntimeController` is the unique scene-owned mutator for player action cooldowns and persistent-card `cooldown_left` / `lock_left` fields. The authoritative values remain inside `WorldSessionState.players`; the controller adds no parallel state and no save schema.

Production world-delta path:

`Main frame ordering (temporary) -> GameRuntimeCoordinator.advance_card_cooldowns() -> CardCooldownRuntimeController -> WorldSessionState`

Main no longer owns `_update_realtime_cooldowns()` and no longer directly arms action cooldowns. Persistent-card arming is bound to player, slot and optional `runtime_instance_id`, so a stale queued card cannot arm a replacement card that occupies the same slot.

## Timing semantics

- cooldowns use world delta, not real delta;
- global forced-decision block and ordinary pause freeze because the caller does not advance the owner;
- card-resolution progress blocking does not freeze cooldowns, preserving the characterized frame order;
- eliminated players still advance deterministically;
- values are linear and clamp at zero;
- military cooldowns remain owned by the military runtime and are outside this controller.

The focused test verifies fragmentation equivalence, identity-bound arming, clamps, null slots, eliminated seats, existing save ownership, privacy and the unique production instance.
