# V0.7.1 Detached RNG Ownership

The V0.7.1 canonical RNG adapter is a parity ledger, not a second RNG owner. It
accepts only unified-track state version 4 and personal-DBG state version 2,
requires the exact seven logical streams, and compares each row with the
embedded owner state before restore.

The adapter has no seed, draw, or advance API. A wrong balance-profile
fingerprint fails before RNG restore. This contract remains detached and adds
no V0.6 draw point or production connection.
