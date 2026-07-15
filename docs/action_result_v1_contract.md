# ActionResult v1 public contract

ActionResult v1 is a presentation contract for one live UI action: `card_group_ready` in the `card_resolution` family. The Card Resolution controller remains the rule and readiness-state owner; `ActionResultPresentationService` only maps a validated outcome code to fixed public copy.

Every public result contains `success`, `failure_code`, `title`, `explanation`, `consequence`, `suggested_action`, `focus_target`, `relevant_cost`, `relevant_requirement`, and `affected_entity_ids`, plus the fixed v1 action identity and status. The first adopter recognizes `group_ready_committed`, `player_unavailable`, `queued_entry_missing`, `group_window_closed`, `already_ready`, and `ready_rejected`.

The contract rejects unknown fields, malformed action identity, Objects/Callables, and recursively private keys or sentinel values. It never publishes a player index, exact cash, hand/discard/slot state, owner truth, AI plan or score, authorization payload, or private receipt. The only affected entity identifier currently allowed is a public `resolution:<non-negative integer>` id.

The retired `bid_set_*` buttons were a stale UI path after priority-bid authority had already been removed from the queue owner. This cutover does not recreate bidding rules or escrow; it removes Main's dead dispatch/helpers and adopts the real group-ready transaction. Restoring a true priority bid would require a separate authoritative owner and rule acceptance phase.
