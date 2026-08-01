# V0.7.1 Detached Restore Graph

All envelope, profile, section, and RNG checks complete before any apply. The
adapter captures a checkpoint, applies nodes in dependency order, rolls back in
reverse order on failure, and exposes one detached atomic commit only after the
entire graph succeeds.

The approved profile fingerprint is checked before RNG restore. This graph
does not migrate V0.7 or V0.6 saves and has no production connection.
