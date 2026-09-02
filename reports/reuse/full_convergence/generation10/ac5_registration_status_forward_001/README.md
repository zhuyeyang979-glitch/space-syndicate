# Historical AC5 registration status, forward-only repair

This corrects an invalid Stage status token, not the product or any frozen
formal attempt. Source Head: `a026c0a8c6708a878e6e030e7702afb4607a1873`.

The existing AC5 identity manifest was independently reconstructed through
the original `validate_manifest` at its recorded AC5 subject and evaluated
Head. Exact identity validation passes while all historical runtime/product,
human and cutover claims remain false. Its original bytes remain unchanged.

The existing terminal INFRASTRUCTURE Stage changes only:

- the invalid `SUBJECT_REGISTERED_PENDING_GATE` status to a narrowly scoped
  `CURRENT_DELTA_GREEN` for historical identity-registration completion;
- an explanatory suffix on the existing infrastructure justification;
- one appended evidence object, retaining the invalid original token and
  a reference to the frozen Gate002 failure.

No Stage ID, head/tree, owner, sequence, not-claimed value, canonical status,
candidate pointer or Golden step changes. No invented regression or rollback.
The old rejected regression/rollback proposal remains frozen and rejected.

Primary and independent exact-byte review passed. The proposal has 14/14
preservation/contract checks; original snapshot and monotonic validators pass.
The independent partial-model comparison removes exactly two status errors,
adds none, and remains FAIL overall. This is not a Raw scan or Required Gate
PASS. No runtime, formal STEP11, full-world proof or product modification ran.

Candidate001 stayed external, not applied. Candidate002 adds the explicit
scope explanation and is the sole applied target. Both are hash-listed in
the external evidence index. The first harness invocation used a nonexistent
top-level candidate field; it failed before creating any output directory or
changing an authority. The check now compares the actual nested candidate.

The user's later PR93 synchronization authorization is recorded separately.
Actual PR changes remain deferred until the remaining repairs are complete;
Draft, no merge and no release remain mandatory.
