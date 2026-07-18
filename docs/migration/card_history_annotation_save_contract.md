# Card-History Private Annotation Save Contract

`CardHistoryPrivateAnnotationService` remains the only runtime owner for
viewer-scoped card-history annotations and role usage. It is not a registry
owner and does not expose `to_save_data` or `apply_save_data`; the session
adapter uses subordinate checkpoint APIs.

Checkpoint schema version 1 persists only:

- `annotations_by_viewer`
- `role_usage_by_viewer`
- `revision`

Durable annotation fields are note text, private tags, suspected player
indices, private confidence, excluded player indices, and subscription state.
Derived public evidence text, reveal verification, public revision, subscription
fingerprints, notification count, and formatted UI text are rebuilt from the
restored `CardHistoryPublicQueryPort` after validation.

Restore is silent: it does not emit notifications, increment revision, spend a
role charge, or create any reward, penalty, GDP, payout, or public broadcast.
Viewer indices are checked against the restored world-session player count.
Subscriptions are limited to two per viewer; residual catalog usage is limited
to two and public exclusion usage to three.

Structural annotation preflight validates shape, viewer bounds, role-usage
limits, and the data-only contract without consulting mutable live history.
Before any owner is applied, `V06SaveOwnerRegistry` cross-validates every
annotation reference against the normalized `card_resolution_history` section
from the same envelope. An evicted or otherwise missing ID rejects the whole
transaction; it is never silently dropped.

`card_resolution_history` is the authoritative transactional section at
registry position 15 and is restored before the composite `session` section at
position 19. Annotation apply may therefore defensively verify the restored
live history while rebuilding subscription fingerprints silently. Full-run
resume remains false because seven other registry sections are unsupported.
