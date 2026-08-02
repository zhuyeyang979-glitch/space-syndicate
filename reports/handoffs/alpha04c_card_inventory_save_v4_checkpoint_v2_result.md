# Card Inventory Save v4 / Checkpoint v2 Result

Status: `BLOCKED_REPLAY_SCENARIO_IDENTITY_ATTESTATION`

The authorized Card Inventory repair is complete and its focused gates are green. Persistent Save moved from v3 to v4, the composite runtime checkpoint moved from v1 to v2, Product Market floats use `f64_bits_hex_v1`, and District Purchase player-index maps use `nonnegative_decimal_string_v1`. The Save Envelope remains unchanged and the Registry still owns exactly 19 sections.

## Characterization

- Persistent Save v3 contained 2,137 leaves and 456 non-closed float leaves.
- Runtime checkpoint v1 contained 2,343 leaves and 503 non-closed leaves: 502 floats and one integer Dictionary key.
- No Object, Node, Resource, Callable, or RID was found.
- The District `pending_payload.opened_at` float was attested as presentation-only and excluded from authoritative wire state. No authoritative field was dropped.

## Repair Proof

- F64 codec: 42/42, including signed zero, subnormal, finite extremes, JSON roundtrip, and non-finite rejection.
- Canonical player-index map: 29/29, including leading-zero, sign, range, and numeric-collision rejection.
- Child contracts: Commodity 8/8, Product Market 14/14, District Purchase 9/9.
- Composite Save/checkpoint: 26/26; fault rollback: 3/3.
- Production Registry transaction: 59/59; V6 retained replay: 53/53.
- Capture mutation, RNG, world-time, public-log, private-feedback, and presentation deltas are all zero.
- V3 fails closed with `card_inventory_v3_closed_wire_upgrade_requires_backup`; apply count remains zero and the source file is preserved.

## Replay Outcome

Exactly one nonconsuming replay was launched at `2f473d0227efd1921dcf872eefeed853b1802762`. It failed before Card Inventory capture with `diagnostic_identity_ruleset_id_mismatch`: the task-created replay tool queried `../RulesetSaveAttestationOwner` from the session node instead of its direct child. The QA path was corrected and statically revalidated, but the replay was not rerun.

The retained V7 evidence tree, ledger, and failure phase hashes are unchanged. Diagnostic delta, quota claims, full-owner audits, fixed-slot writes, and Process A count are all zero. V7 remains 7/19 and no V8 authorization exists.

## Scope Deviation

An attempted check-only command placed `--check-only` after the script separator, starting a partial smoke process. It was terminated by the command timeout, did not complete a full Smoke, wrote no smoke Save file, and all task-owned Godot processes were stopped. A later engine-level `--check-only` completed successfully. This deviation prevents a GREEN claim.

PR #77 must remain unchanged, Draft, and not mergeable until a separately authorized replay proves the corrected QA path.
