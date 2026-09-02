# Exact Resource/script typed-identity repair

This is a tooling-only current-delta repair. It does not alter the Registry,
product code, frozen Raw reports, correction fingerprints, SPR/HDM projections,
Generation 9 failure, or Generation 10 formal PASS. It is not Required Gate GO.

The serialized `resources/ai/ai_policy_profile_v1.tres` is an instance of the
class declared in `scripts/ai/ai_policy_profile_resource.gd`. The old Resource
row is immutable. Renaming it would introduce a silent identity replacement;
using historical backfill alone cannot supply the mandatory current inventory
identity. Both alternatives were rejected before Registry application.

The original gate now assigns an internal path-bound instance key only for
this exact two-row pair after independently verifiable source-byte and row
bindings. The script retains its global class name. All other duplicate class,
path, ID, Owner, authority, declaration and monotonic guards remain unchanged.
Both rows stay non-production TEST_SUPPORT, writes_authority=false, all owns_*
false, reads_authority=true, bound to the existing V075 Owner and domain.
The internal key is never written into Registry or historical identity fields.

Source hashes are fixed to the actual reviewed blobs. Missing proof, changed
source, an altered old resource row, changed permissions or a third same-class
row restores the original duplicate-class failure. No failure waiver exists.
Historical validation reads each historical commit; worktree validation reads
actual worktree bytes. Mutable refs resolve uncached to an immutable commit
before cached blob reads.

## Review chronology

The pre_review reports retain the initially passing 56/56 focused, 162/162
original and 118/118 V2 self-tests. Independent review nevertheless rejected
gate SHA cafa646c94462899178d7ddf6ce0f5db90934ec4cccdad542e6bf1d059c8754a:
a moving ref could reuse previously cached good bytes. That version was not
applied to the Registry. The new ref-resolution guard and explicit regression
case address that finding; prior test PASS is not substituted for review GO.

Final focused characterization is 58/58 and is now an aggregate case in the
original reuse suite: 163/163, false-green count 0. V2 is 118/118 with current
violation false-accept count 0. These are focused tooling tests, not a new full
Raw history scan, full Required Gate run, or product/runtime qualification.

Batch011's proposal builder additionally preserves every old inventory row,
requires both original snapshot and monotonic guards, pins scripts/resources/
scenes/addons/assets/project and the mechanic document to the reviewed source
epoch, and binds its own executed bytes plus five existing helpers to the
committed Head. The prototype alias-changing candidate remains un-applied at
`D:/ss-v076-generation10-batch011-registry-projection-001-20260902/`.

Human/production green remain false. STEP13-15 remain pending. PR93 synchronization
is authorized only after remaining repairs; it remains Draft and is not merged
or released. No Godot run, new formal attempt or system configuration change
was performed for this repair.
