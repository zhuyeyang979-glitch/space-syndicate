# Existing scanner successor admission

The typed-identity implementation committed at 30002f6e changed two scanner
files. V2 case111 correctly rejected the new committed bytes while its current
successor table still named the prior scanner. The first failed 117/118 result
remains in the adjacent Batch011 evidence directory.

This repair changes only two SHA-256 literals in the existing
SCANNER_SUCCESSOR_SHA256_BY_PATH table. It does not change its validation logic,
the third mechanic-checker binding, the evolvable-input set, frozen manifests,
plans, sidecars, records, Raw reports, fingerprints or historical claim counts.
Independent verification of the proposed exact values passed 8/8, including
wrong hashes for all three scanners and frozen artifact-drift rejection.

After commit 278fc282f402b5cf33bd82a6723b90a0a5b36c48, the actual V2 suite passed
118/118 and the original `seal-evidence --verify-only` command returned VERIFIED.
That command executed the original current reuse self-test internally. It
preserved the old seal's FAIL/HARD_STOP status and all historical counts. These
old counts are not the current Required Gate results. No new seal was created.

Batch011's exact Registry append is complete, but correction authority and the
remaining Required Gate work are not. No product or human green is claimed.
PR93 remains Draft and unchanged until the remaining repairs are complete.
