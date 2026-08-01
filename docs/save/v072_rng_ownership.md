# V0.7.2 RNG Ownership

V0.7.2 retains exactly seven logical RNG streams. The free-Starter cost rule and Starter/standard merge add no stream and draw no random value.

The personal DBG remains authoritative for `starter_deck_shuffle` and `normal_deck_reshuffle_by_player`. The Unified Track remains authoritative for its four supply streams and `initial_hidden_lead_order`.

The canonical RNG adapter is a strict ledger projection, not a second RNG owner. It cannot seed, draw, advance, or restore independently. Restore accepts only rows byte-equal to embedded owner state and advances zero draws.
