# Component Landing Compositional Acceptance v1

This contract allows a narrowly scoped component landing to reuse a real,
terminal-green Formal ancestor. It does not turn an incomplete Formal into a
successful Formal, and it does not lower the release-level terminal standard.

The canonical end-to-end definition remains
`docs/contracts/v06_full_run_terminal_acceptance_v1.json`. A successful Formal
still requires a real matched economy chain and Sale Receipt, the exact
`idle -> qualification -> audit -> resolved` Victory sequence, exactly one
FinalSettlement, presentation, and final public-log entry, at least eight
terminal-quiescent frames, terminal world and RNG deltas of zero, and zero
invalid or nonfinite results.

## Allowed scope

Compositional acceptance may be evaluated only for:

- UI and presentation;
- read-only projections;
- player input adapters;
- artwork and catalogs;
- accessibility;
- non-rule interaction shells; and
- QA observation.

An unclassified production change fails closed.

## Forbidden scope

Compositional acceptance is forbidden for any change to gameplay values,
Victory rules, qualification or audit timers, RuntimeLoop behavior, economy
formulas, AI production behavior, action semantic execution, Save owners or
schemas, RNG owners or draw points, terminal owners, multiplayer or replay
authority, or the full V0.7 runtime cutover.

## Conjunctive gates

Every item below must pass. One failure blocks component acceptance.

1. A settled terminal-green Formal commit satisfying the canonical terminal
   contract exists and is a real Git ancestor of the candidate. This ancestor
   is the only evidence reused for terminal-green status.
2. A later Formal used only to prove traversal of the changed component path
   may be a non-ancestor source commit when the candidate is a clean extraction.
   In that case, the source and candidate must share the terminal-green
   ancestor; the extraction destination must be a Git ancestor of the
   candidate; every behavior-bearing component and every owner-discovered
   dependency in the traversed Formal path must be byte-identical or have an
   enumerated, deterministic nonsemantic normalization; and there must be zero
   semantic mismatches, unclassified differences, terminal-critical
   differences, or post-extraction behavior changes. Commit names, subjects,
   matching paths, or claimed intent alone do not establish equivalence.
3. Real owner discovery proves zero candidate changes to terminal runtime
   owners, Victory rules and timers, FinalSettlement runtime, RuntimeLoop
   terminal behavior, the world-effective clock formula, terminal RNG, terminal
   Save behavior, and terminal state injection.
4. At least one real production Formal traversed the changed component path.
5. The changed component gates were green in that Formal; invalid and nonfinite
   counts were zero.
6. The Formal entered authoritative Victory audit and ended with authoritative
   progress still active rather than stalled.
7. The exact candidate passes deterministic component tests for Victory timer
   precision and ordering, audit-to-resolved, FinalSettlement exact-once,
   terminal presentation and final public log exact-once, RuntimeLoop freeze,
   eight-frame quiescence, terminal world/RNG zero, post-eligibility production
   guard, settlement composition and Save checkpoint, Action Spine terminal
   compatibility, the static FullRun Driver contract, and the authoritative
   runtime stepper policy.
8. The exact candidate passes its functional, privacy, Action Spine, Main,
   Save, RNG, reference-dependency, and `git diff --check` gates.
9. The incomplete end-to-end Formal result remains explicitly preserved.

Owner discovery is mandatory. A path-name-only audit is insufficient. A test
that starts a new game and advances it to audit or settlement is an end-to-end
run, not a component test, regardless of its filename.

## Decision and truthful claims

When every gate passes, the component result may be recorded as
`GREEN_COMPONENT_ACCEPTED`, with the terminal-green ancestor explicitly marked
as reused. The same record must also preserve:

```text
EXACT_FORMAL_HEAD_FULL_RUN_TO_TERMINAL_PROVEN=false
FULL_RUN_TO_SETTLEMENT_GREEN=false
RELEASE_LEVEL_FULL_RUN_DEFERRED=true
```

`EXACT_HEAD_TERMINAL_GREEN=true` is forbidden without exact end-to-end proof.
Missing evidence, an unknown change class, or any forbidden diff produces
`BLOCKED`, not an optimistic partial green.

## Run policy

This contract cannot authorize another Formal. It permits only bounded,
deterministic component fixtures and static audits. A hidden, renamed, extended,
background, or worktree-based Formal equivalent is forbidden.
