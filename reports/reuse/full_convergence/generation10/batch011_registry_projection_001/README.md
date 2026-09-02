# Batch011 exact Registry append

The dual-reviewed candidate from committed Head
`30002f6e691ad8a9c555f95abc29c9e71a638236` appended exactly 49 inventory rows
and reused one existing mechanic-document row. All 474 prior rows and prior
Registry bytes are preserved; the resulting inventory contains 523 rows.
The target Registry SHA-256 is
`fa8486af2023a067df3af6e4e1eb5f4247e78f96f2b26e18a050d015c3a7667f`.

The 50 frozen identities are classified as 48 historical test-only, one
passive production definition, and one diagnostic document. No Owner, authority
write, runtime state or product file was introduced. The earlier alias-changing
prototype is preserved externally and was never applied. The existing resource
row and all correction/SPR/HDM identity records remain unchanged.

Pre-apply and applied audits passed 37/37. The real post-apply original reuse
self-test passed 163/163 (including 58 focused typed-identity cases).
The first post-commit V2 self-test failed 117/118, case 111: its current-scanner
hash admission still named the previous source. That exact failed JSON is
preserved here. The adjacent scanner_successor_binding_001 evidence records
the existing mechanism's two-hash update and separate postcommit verification.
It does not rebuild or edit any historical seal.

## Remaining work

Registry readiness is not correction-batch authority GO. Batch011 still needs
its exact authority proposal generated from the committed registered Head,
real A/B reviews, and 7 batch files plus 3 nonempty correction records (48 T,
1 P, 1 D). Reuse batch009's pure document constructors with explicit default-
preserving parameters; do not copy a complete materializer or change global
batch constants. Historical membership Head remains 86fc75eb4c1a; current
binding Head must be the new committed registered Head. Preserve the different
historical/current mechanic-document hashes. No internal typed class key may
enter Registry, projection or historical identity fields.

Next are the remaining Batch012/013 items and exact current-subject/SPR/HDM/
post-touch bindings, then the actual Required Gate. Only after remaining
repairs are complete may the newly authorized PR93 Head/body synchronization
occur. PR93 remains Draft; no merge, release or formal STEP11 retry is allowed.
Generation9 failure and Generation10 formal PASS remain unchanged.
Human/production green remain false; STEP13-15 remain pending.
