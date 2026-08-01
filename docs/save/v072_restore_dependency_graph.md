# V0.7.2 Detached Restore Graph

All ten restore nodes preflight before any apply. The transaction checkpoints each participant, applies in dependency order, rolls back in reverse order on failure, and commits exactly once.

Envelope identity preflight validates the exact V0.7.2 ruleset, balance profile, closed card-definition identity, and prohibition on V0.7.1 or V0.6 direct resume. Starter identity may not be inferred from cost.

The existing RNG, DBG, hidden-lead, Unified Track, Asset, Batch, Solar, and Victory dependencies remain explicit. V0.7.2 adds no production connection and no compatibility writer.
