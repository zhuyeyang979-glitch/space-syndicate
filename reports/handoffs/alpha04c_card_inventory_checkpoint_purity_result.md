# Alpha 0.4-C Card Inventory checkpoint purity result

STATUS=BLOCKED_BY_CARD_INVENTORY_SAVE_SCHEMA_DEFECT

This task stopped at the explicit persistent-Save hard gate. It characterized
the immutable V7 failure, but did not modify a production Owner, create
`CardInventoryRuntimeCheckpointV2`, run a replay, or claim another diagnostic.

## V7 failure path

V7's actual Owner Audit predicate is the private Owner codec in
`v06_save_owner_registry.gd`, not `SemanticWireV1.is_closed_data()`. The V7
codec accepts finite floats and several Godot value types, but accepts only
String or StringName Dictionary keys.

The focused production-child characterization opened a real District Purchase
window and captured the real child runtime checkpoint. It found one V7 codec
violation:

```text
CARD_INVENTORY_CHECKPOINT_LEAF_COUNT=24
CARD_INVENTORY_NON_PURE_LEAF_COUNT_BEFORE=1
FIRST_NON_PURE_CHILD_ID=district_purchase
FIRST_NON_PURE_PATH=$.children.district_purchase.windows_by_player.<non_string_key:int>
FIRST_NON_PURE_VARIANT_TYPE=int
FIRST_NON_PURE_REASON=dictionary_key_not_owner_codec_compatible
NON_PURE_TYPE_COUNTS={"int":1}
```

`DistrictPurchaseRuntimeController` stores live windows in
`_windows_by_player[player_index]`. The integer key is authoritative lookup
structure and is copied into `capture_runtime_checkpoint()`. This explains the
historical V7 failure without guessing at either of the other child domains.

## Persistent Save blocker

The task's stricter target contract permits only String, bool, safe int, Array,
and String-key Dictionary values. A real `CardInventorySaveOwner.to_save_data()`
schema-v3 envelope, using the real Product Market child, does not meet that
contract:

```text
CARD_INVENTORY_SAVE_SCHEMA_VERSION_BEFORE=3
CARD_INVENTORY_SAVE_SCHEMA_VERSION_AFTER=3
STRICT_NON_CLOSED_LEAF_COUNT=2
FIRST_SAVE_DEFECT_CHILD_ID=product_market
FIRST_SAVE_DEFECT_PATH=$.product_market.product_market.<redacted:e85b86c2f8c4>.growth_multiplier
SECOND_SAVE_DEFECT_PATH=$.product_market.market_timer
SAVE_DEFECT_VARIANT_TYPE=float
SAVE_DEFECT_REASON=float_not_closed
```

Both values are authoritative and currently restored as floats. They cannot be
dropped, rounded, or stringified without a versioned, reversible Save contract.
The current V7 codec accepts these finite floats, so this is separate from the
integer-key cause of V7. It nevertheless satisfies the task's section-nine
stop condition: the persistent Save payload itself is not strict closed data.

The Card Inventory Save schema remains version 3. No envelope or section
version changed, no field was discarded, no implicit coercion was added, and
`SemanticWireV1.is_closed_data()` remains untouched. Resolving the blocker
requires a separately authorized Save-schema task.

## Deliberate non-execution

Because the persistent Save gate failed, the runtime checkpoint repair,
three-child restore matrix, fault rollback matrix, capture side-effect matrix,
and V7 single-Owner replay were not run. Their result is `NOT_RUN`, not GREEN.
There is therefore no replay run ID and no claim that the non-pure leaf count
after repair is zero.

V7 remains immutable at 7/19. Its 107 files and 271,918 bytes were not changed;
the quota ledger remains
`607f1a15d875321a368ab071b35693857d7acf32063b4ed5578fa4f4aea9f826`.
No V8 authorization was created. Process A, Official Attempt 2, Process B, and
Process C were not started. No Save file was written.

The task did not modify V0.7.3, PR #80, PR #82, `scripts/main.gd`, production
`main.tscn` wiring, gameplay values, AI policy, RNG ownership, or RNG draw
points. It did not run a third Formal or a full Smoke.

## Focused checks

- V7 failure-path characterization: `7/7 PASS`
- persistent Card Inventory Save v3 characterization: `11/11 PASS`
- dynamic string-key path redaction: covered by the V7 characterization
- Godot engine `--check-only`: `PASS`
- `git diff --check`: `PASS`

NEXT_TASK=`ALPHA_0_4_C_ATTESTED_CARD_INVENTORY_SAVE_SCHEMA_REPAIR`
