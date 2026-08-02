# Alpha 0.4-C retained V6 Registry Binding replay

STATUS=GREEN

The replay consumed the retained V6 ledger and evidence in place. The ledger SHA-256 remains
`fe843a4a924a12af5553afcb38a579f68a59acdeab0a4c5e5efb006c31e25c60`, the retained scenario
identity revalidated, and the reconstructed legacy Registry projection matched the fingerprint
stored by V6. No evidence bytes changed.

## Pre-fix characterization

The old diagnostic required every projected binding to contain a nonempty `checkpoint_method`.
The first rejected row was index 1, `region_infrastructure/public_facility_region`; the field was
omitted by contract, not missing by accident. Eleven of nineteen production bindings use this
shape, so V6 stopped before Owner Audit with
`diagnostic_registry_binding_contract_mismatch`. V6 remains a pre-Owner failure and not an Owner
Capture failure.

## Canonical transaction semantics

The replay now consumes only `V06SaveOwnerRegistry.registry_binding_contract_v1()` and validates
transaction behavior rather than a preferred field shape:

| Checkpoint strategy | Count | Contract |
| --- | ---: | --- |
| `explicit_owner_method` | 8 | The named checkpoint method exists, runs before apply, and has a real rollback method. |
| `registry_managed_checkpoint` | 11 | Registry retains the pure-data capture before any apply and passes it to the real rollback method in reverse restore-DAG order. |
| `owner_internal_transaction_checkpoint` | 0 | No current production binding relies on this strategy. |

The Registry-managed sections are `region_infrastructure`, `region_supply`, `commodity_flow`,
`player_mana`, `player_organization`, `monsters`, `weather`, `card_resolution_execution`,
`card_resolution_history`, `bankruptcy_neutral_estate`, and `victory_control`. All nineteen
bindings expose valid capture, preflight, apply, and rollback methods. There is no Owner without
checkpoint or rollback semantics.

## Replay result

```text
V6_RETAINED_LEDGER_REPLAY_GREEN=true
V6_SCENARIO_IDENTITY_REPLAY_GREEN=true
V6_REGISTRY_BINDING_REPLAY_GREEN=true
V6_REPLAY_BINDING_COUNT=19/19

REGISTRY_BINDING_WITH_EXPLICIT_CHECKPOINT_COUNT=8
REGISTRY_BINDING_WITH_REGISTRY_MANAGED_CHECKPOINT_COUNT=11
REGISTRY_BINDING_WITH_OWNER_INTERNAL_CHECKPOINT_COUNT=0
OWNER_WITHOUT_CHECKPOINT_OR_ROLLBACK_SEMANTICS_COUNT=0

REPLAY_DIAGNOSTIC_COUNT_DELTA=0
REPLAY_QUOTA_CLAIM_COUNT=0
REPLAY_PRODUCTION_SESSION_CREATE_COUNT=0
REPLAY_OWNER_CAPTURE_COUNT=0
REPLAY_SAVE_WRITE_COUNT=0
```

The focused replay test passed 49/49 checks. It covers the exact retained artifact, all eleven
legal omissions, a valid explicit method, a fake method, strategy conflict, missing rollback,
duplicate section and Owner IDs, missing and cyclic dependencies, wrong state version,
registration-order drift, fixture divergence, one binding source, and zero duplicate field lists.
The canonical Registry port test separately
passed 14/14 checks with rollback capability at 19/19.

No V7 authorization or run was created. Process A, Official Attempt 2, Process B, and Process C
were not started.
