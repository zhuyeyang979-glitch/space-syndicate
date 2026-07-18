# World Session Save Cutover Handoff

Status: implementation complete on the local task branch; final bounded
delivery gates and remote integration are tracked separately.

## Completed Boundary

- One transactional `session` section remains at registry position 19.
- The authoritative transactional `card_resolution_history` section remains at
  position 15 and restores before the session composite.
- `SessionEnvelopeSaveOwner` composes the three existing state owners.
- WorldSession city guesses, confidence, reasons, role identity, time, districts,
  and geometry round-trip through an encodable DTO.
- Private card annotations, subscriptions, and bounded role usage round-trip
  without notification or charge duplication.
- Fault injection proves reverse rollback across all child boundaries.
- Active v1 sessions fail closed instead of creating a partial world.
- Formal v3 load is envelope -> registry -> high-level receipt; Main no longer
  applies domain state.

## Deliberately Unfinished

- Full-run resume is false.
- Unsupported sections remain: `ruleset`, `routes`,
  `commodity_belt_visibility`, `card_inventory`, `military`,
  `card_resolution_queue`, and `ai`.
- Public card-history restoration is owned by the transactional history
  section. Registry cross-section preflight validates annotation references
  against the captured normalized history before any live owner apply.
- Intel query/command split remains pending; this task only supplies its
  required save authority boundary.
- Setup and save/load overall remain pending in the Main cutover ledger.

## Next Boundary

Recreate the Intel task from the eventual merged main and rerun its preflight.
It may now rely on WorldSessionState city-guess data and private annotation role
usage having a transactional session-envelope contract. It must not introduce
an Intel save owner or a second WorldSession owner.
