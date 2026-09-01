# V076 Subject Projection Revalidation Formal Attempt 002 — SUCCESS

This append-only receipt records the successful landing of the 83-file subject-projection revalidation sidecar. It does **not** claim that the complete V076 Reuse Gate is green.

## Exact binding

- Authorized write Head: `e73e033f915ad420d8d15d78c5bf5dab68b2e5cc`
- Authorized write tree: `50cecd693638c27109cc628ee09096610e969d51`
- Formal commit A: `4aafc8cdc74ed987036f24908bdbb4fef943db43`
- Formal commit tree: `17124057298e14de96eeda724b732324ed5a26a6`
- Formal root: `docs/architecture/reuse_corrections/v2/subject_projection_revalidation/`
- Files: `83 = 1 manifest + 82 records`
- Manifest SHA-256: `dff148179980c4e49f277a516bf7f1d0670f4d8b02a40e0f95b077ed92e0967e`
- Record-chain terminal: `c36b968b316fd3c9153d07d2d07c1ddade1d893304b8b282aacdcf8fbb7622ba`

## Exactly-once formal result

The sealed formal invocation ran once, with no retry, and returned one PASS JSON object:

- PID: `29408`
- Result: `83/0`
- stdout: `3557` bytes, SHA-256 `7a696f5094de9da226bb5d18b1f46830b7e6a17213479deee620d50f124c28a0`
- stderr: empty
- Namespace terminal: `CLEAN_CANCEL_COMPLETION`
- Namespace mutations observed: `0`
- Builder/Git/bootstrap terminal seals: closed

The raw streams were not separately persisted; their hashes and terminal fields come from the task tool transcript. The 83 committed blobs were independently re-read from commit A and matched the formal working bytes exactly.

## Proof and audit

- Fresh sealed proof: dry-run PASS, first write `83/0`, second write `0/83`.
- Fault matrix: `24/24 PASS`, zero failures, matrix SHA-256 `15a708e7d6d56426f442fd9e993f68c925b1b91250a1c0881c06697df840d75c`.
- Primary validator on commit A: `PASS`, trusted `82/82`.
- Independent audit on commit A: `GO`, trusted `82/82`.
- Both audits explicitly selected batch-007 from a seven-batch chain.
- Independent security reviews: `P0=0`, `P1=0`, `GO`.

## Protected evidence

The frozen failed stage and four local baseline files were not modified or staged. Their exact before/after hashes are recorded in the JSON receipt.

## Honest boundary

```text
FORMAL_LANDING_STATUS=PASS
FORMAL_SUCCESSOR_COMMITTED=true
REUSE_GATE_GREEN=false
CURRENT_ACTIVE_VIOLATION_ZERO_REPROVED=false
COMMERCIAL_SPRINT_RESUMED=false
HUMAN_GREEN=false
STEP13_STATUS=PENDING
STEP14_STATUS=PENDING
STEP15_STATUS=PENDING
```

The next required repairs are the standalone subject-projection batch-chain resolver and the Alpha01 resource-instance to implementation-script binding, followed by terminal batch-008 through batch-013 convergence.
