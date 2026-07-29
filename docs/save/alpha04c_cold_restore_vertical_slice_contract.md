# ALPHA_0_4_C Cold Restore Vertical Slice Contract

```text
FORMAL_FULL_RUN=false
DRIVER_EXECUTION_READY=true
CONTRACT_SCHEMA_VERSION=4
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

1. Process A (`producer`) launches a real production composition with a fixed
   seed, reaches a quiescent checkpoint, freezes the runtime loop, invokes the
   high-level save command, emits one allowlisted QA manifest, and exits.
2. Process B (`consumer`) starts only after A has exited. It launches a fresh
   production composition, restores before the first gameplay tick, verifies
   viewer-safe state and RNG continuation, advances at least one normal tick,
   asserts no duplicate receipt or settlement, emits its manifest, and exits.
3. Process C (`validator`) launches a third fresh process, restores Generation 2,
   performs exact recapture, and emits the same closed allowlisted manifest.
4. The external orchestrator compares only the three allowlisted manifests and
   process exit results. It never parses the save envelope.

All 19 owners and the restore barrier are integrated. The fixed depth-1,
seed-900626424 non-official qualification reached a real production facility
offer through the Action Spine, captured one pending Queue entry, and observed
zero world, card-resolution, and RNG advance after submission. Qualification
wrote no Save and did not create the shared official ledger. The orchestrator
rejects a dirty worktree, requires the one shared ledger plus PID-bound launch
attestations, and places the production slot in one run-specific isolated
user-data root shared by A, B, and C. `DRIVER_EXECUTION_READY=true` authorizes
only that guarded one-shot protocol; it is not itself cold-restore evidence.

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
