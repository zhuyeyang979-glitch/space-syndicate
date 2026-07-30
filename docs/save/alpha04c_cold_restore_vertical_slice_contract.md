# ALPHA_0_4_C Cold Restore Vertical Slice Contract

```text
FORMAL_FULL_RUN=false
DRIVER_EXECUTION_READY=true
CONTRACT_SCHEMA_VERSION=3
CHILD_COMPLETION_ATTESTATION_SCHEMA_VERSION=1
PARENT_EXIT_ATTESTATION_SCHEMA_VERSION=1
CURRENT_RUNTIME_RULE_VERSION=v0.6
SAVE_SECTION_COUNT=19
NEW_SAVE_SECTION_COUNT=0
NEW_RNG_OWNER_COUNT=0
```

## Authority and boundary

- `mechanic_id`: `v06_save_resume_application_flow`
- Rule sources: `docs/tabletop_rulebook_v06.md` deterministic save clauses,
  `docs/rules_v06_runtime_directive.md` section 8, and
  `docs/v06_save_owner_registry_contract.md`.
- Player-facing meaning: pause-menu **保存游戏** writes the current run to one
  local slot; main-menu **继续游戏** restores that slot only after the complete
  owner registry accepts it.
- Authoritative owners: the existing 19-section registry, session owner, ruleset
  handshake, and file-I/O coordinator. The application flow owns none of them.
- Privacy: UI receives only slot readiness, concise local metadata, and fixed
  success/failure text. Paths, raw envelopes, section payloads, fingerprints,
  RNG state, hands, cash, ownership truth, and AI state never enter UI data.
- Persistence: fixed production slot `user://saves/v06/current_run.save`; isolated
  QA slots are created only by `SaveSlotPolicyV06` below
  `user://test_runs/alpha04c/<run-id>/`.

## Process protocol

0. One non-official qualification child runs through the same attested process
   helper. A completed Harness exits zero even when the product has no lawful
   Queue offer; `qualification_green` and `product_blocker` carry that product
   result. Only a green child proof, parent proof, and product result can create
   the exact-once official authorization ledger.
1. Process A (`producer`) launches a real production composition with a fixed
   seed, reaches a quiescent checkpoint, freezes the runtime loop, invokes the
   high-level save command, emits one allowlisted QA manifest, and exits.
2. Process B (`consumer`) starts only after A has exited. It launches a fresh
   production composition, restores before the first gameplay tick, verifies
   viewer-safe state and RNG continuation, advances at least one normal tick,
   asserts no duplicate receipt or settlement, emits its manifest, and exits.
3. Process C (`validator`) launches a third fresh process, restores Generation 2,
   performs exact recapture, and emits the same closed allowlisted manifest.
4. Every child atomically publishes its closed result and
   `ChildCompletionAttestationV1` before requesting exit. The external parent
   waits for the real process chain, hashes stdout/stderr, validates that child
   proof, proves task-owned process cleanup, and atomically writes
   `ParentExitAttestationV1`.
5. The external orchestrator compares only the three allowlisted manifests and
   validated attestations. It never parses the save envelope.

All 19 owners and the restore barrier are integrated. Harness execution is now
available only through the closed qualification and authorization gates; merely
setting the official switch is insufficient. The orchestrator rejects a dirty
worktree, resolves the Windows Godot console wrapper explicitly, and places the
production slot in one run-specific isolated user-data root shared by the
qualification child and A/B/C. A Queue-zero qualification consumes no official
authorization and must not launch Process A.

## Exit and evidence contract

`ChildCompletionAttestationV1` binds run id, role, repository HEAD, scenario,
product status, Queue identity, mutation counters, Save/official flags, and a
self-fingerprint. It is written to a temporary file, flushed, closed, parsed
back, fingerprint-checked, and atomically installed before `quit()`.

`ParentExitAttestationV1` binds the launched PID, observed exit, exact exit code,
timeout/termination state, stdout/stderr SHA-256, child-attestation fingerprint,
and the post-cleanup task-owned process count. Qualification and A/B/C share the
same PowerShell process helper and `ProcessStartInfo.ArgumentList`; engine flags
such as `--check-only` are rejected if placed after Godot's user-argument `--`.

```text
HARNESS_COMPLETE + PRODUCT_QUEUE_BLOCKED => EXIT_CODE=0
WRAPPER_EXIT_ATTESTATION_GREEN=true
PRODUCT_QUEUE_QUALIFICATION_GREEN=false

HARNESS_INCOMPLETE => EXIT_CODE!=0
WRAPPER_EXIT_ATTESTATION_GREEN=false
PRODUCT_QUEUE_QUALIFICATION_STATUS=UNTRUSTED
```

## High-level application gateway

`SaveResumeApplicationFlowController` calls exactly one method on its bound
runtime gateway:

```text
submit_save_resume_intent(intent: SaveResumeIntentV06)
  -> SaveResumeReceiptV06 | closed Dictionary
```

The intent carries only operation, fixed `current_run` slot id, source surface,
request id, and explicit overwrite/backup policy. It never carries a path or
envelope. The gateway response must contain exactly the fields declared by
`SaveResumeReceiptV06.GATEWAY_FIELDS`; unknown fields fail closed. The
application flow then removes request/reason metadata and emits only its closed
public snapshot to menu UI.

The integration writer must provide this high-level gateway after the Registry,
Session and atomic-I/O owners expose a complete orchestration command. The UI
branch must not bypass that gateway by calling capture, handshake, read, write,
or apply methods directly.
