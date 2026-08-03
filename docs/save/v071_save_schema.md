# V0.7.1 Detached Save Contract

```text
SAVE_SCHEMA_ID=space_syndicate.v071.semantic_save.v1
RULESET_ID=v0.7.1
BALANCE_PROFILE_ID=V071_CANDIDATE_A_FAST
PRODUCTION_RUNTIME_CONNECTED=false
```

The V0.7.1 envelope is a detached highest-target contract. It persists the
approved balance profile ID and fingerprint in the envelope and in every
affected domain state. Missing fields, a wrong profile fingerprint, or an old
section version fail closed; no locale, UI, or player-count path may choose a
different profile.

The unified-track section saves completed-batch count, independent lead and
color cursors, track scroll sequence, item level, and replacement eligibility.
The personal DBG section saves the five-card minimum rule version, local queue
lock/current batch, and each commodity's `available_from_batch_id`. Asset and
batch sections save the invalid-target policy and the per-color refresh cap.

Direct V0.7-to-V0.7.1 and V0.6-to-V0.7.1 resume are both forbidden. V0.6 saves
still require backup. Every section and RNG row is preflighted before one
detached atomic commit; this document authorizes no production migration.
