# PR #90 Presentation receipt collision characterization

## Conclusion

Both collisions are the same defect, not two unrelated gameplay failures. The Runtime Owner first publishes a presentation-shaped staged event and then publishes an application-level public action wrapper to the same mixed `resolution_presented` signal. Both publications reuse the same atomic Authority receipt ID, while their payload schemas differ. The Consumer correctly treats that as same-ID/different-fingerprint and fails closed.

Root-cause classification is `H=MULTIPLE(A+F+G)`:

- `F=DUPLICATE_PRODUCER_OR_DOUBLE_PUBLISH` is primary: one action is published through two producer paths.
- `A=RECEIPT_ID_DERIVATION_TOO_COARSE`: the Authority source receipt ID is incorrectly used as the Presentation event ID.
- `G=SOURCE_RECEIPT_LINEAGE_LOST`: source identity, Presentation identity, audience, ordinal and Authority sequence are not separate fields.

There is no evidence for mutation after fingerprinting, ephemeral wall-clock/frame fields, a private-audience collision, or a sequence cursor reset. All relevant publication boundaries deep-copy their dictionaries.

## Frozen evidence and reconstruction boundary

The frozen Exact-SHA MCP evidence remains unchanged. Its terminal raw response has SHA-256 `8385035080840c608adbd2ba008159cf00c0d88b754748634933117c5d86ff85` and records 12 unique staged combat receipts, 12 applied Presentation receipts, 2 collisions, 0 duplicates, 57 unsupported mixed-bus receipts, one `DEPLOY_NEW`, one `military_region_assault`, three trample-region receipts, four facility-damage receipts, FinalSettlement=1 and the last facility cue ID.

The frozen Consumer debug snapshot did not persist its private ledger or the two colliding payloads. Therefore the exact pair payloads and fingerprints in the JSON files are explicitly identified as a deterministic, Head-bound reconstruction rather than bytes recovered from the frozen run.

The reconstruction used the same Head, Tree, seed, map configuration, four-player profile and manual local-human batch flow. It reproduced all distinguishing frozen terminal metrics exactly, including the same final facility cue ID, 12/12 applied staged receipts, 2 collisions, 57 mixed-bus rejects, the same combat-domain counts and zero runtime errors. Godot and ports 7576/7586 returned to zero afterward.

## Pair 01: monster deploy

The first publication is `monster_deployed` with the public semantic payload. The second is the application wrapper with the detail nested under `combat_public_result`. Both reuse `receipt.batch.match.v075.sample.1786975827704.1.0004.anonymous.000000.15a0d5e7f7493a5b`.

- Source receipt fingerprint: `c3556853859993624d8b08aec0e87fbd2e7280575611c2ac10df0b5b3746fe10`
- First fingerprint: `577320e476471a710ffb67c9e9f5b4a70a9dedd14839f41a896bd14e13a6b215`
- Second fingerprint: `08c248df3ace32ed940dcdba2b5e24a1c1cdd579cb52e19f27421ddc96ddfea9`
- Leaf-expanded canonical diff paths: 27

## Pair 02: military region assault

The first publication is `military_region_assault` with the public semantic outcome. The second is the application wrapper with that outcome nested under `combat_public_result`. Both reuse `receipt.batch.match.v075.sample.1786975827704.1.0004.anonymous.000002.93f5858866f31e8c`.

- Source receipt fingerprint: `e770bbc88d1a25be6b628d2efc39fb9443ec5ae883f3b3509bb0bbd173d5a4ae`
- First fingerprint: `fb4572cfcdda0370cd26aac1e7bb3bf7787e59018d95f5521bde67ab3012bd80`
- Second fingerprint: `37f420eae057f8dcdbc9b43be7c623349f8fa895da5a388cb2cc6f042b85f1c8`
- Leaf-expanded canonical diff paths: 21

## Why trample is not the cause

Each trample-region receipt has a distinct `trample_region_receipt_id`. It has no `combat_receipt_id`, so the legacy publisher assigns a distinct monotonic fallback ID for each emission. The three frozen trample receipts therefore account for three distinct accepted staged events; they do not form a one-plus-two collision group.

## Repair boundary

The Consumer's negative contract is retained: same ID plus same canonical fingerprint is idempotent, while same ID plus a different canonical fingerprint remains a collision. The repair introduces a dedicated Presentation bus and one `PresentationReceiptIdentityV2` builder so that source receipt identity is lineage, not Presentation identity. Public audience, stable ordinal and Authority sequence become explicit. Application wrappers remain on the application/telemetry bus and no longer enter the Presentation Consumer.

`PRESENTATION_COLLISION_PAIR_COUNT=2`

`PRESENTATION_COLLISION_PAIR_FULL_LINEAGE_COVERAGE=2/2`

`PRESENTATION_COLLISION_UNRESOLVED_DIFF_PATH_COUNT=0`

`PRESENTATION_COLLISION_ROOT_CAUSE_CLASS=H_MULTIPLE_A_F_G`
