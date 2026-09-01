# V076 subject-projection formal attempt 001 — consumed failure

This is an append-only failure receipt. It does not promote, complete, or
rewrite the retained staging directory.

The machine-readable invariants for this receipt are `append_only=true` and
`history_rewrite_allowed=false`. The exact staging allowlist contains only
`reports/reuse/full_convergence/subject_projection_revalidation_formal_attempt_001_failure.json`
and
`reports/reuse/full_convergence/subject_projection_revalidation_formal_attempt_001_failure.md`.
The retained failure staging directory and the four local baseline files are
explicitly excluded from staging.

## Binding and disposition

- Evaluated head: `903af55e4e99331c7ab58b87c79538ecca53ca9b`
- Evaluated tree: `028d7688319296acd047d56e173264277c8c71a8`
- Result: `CONSUMED_FAILURE`
- Same-head retry: forbidden; a new descendant head is required.
- Formal authority directory: absent; formal record count: `0`.

The old builder (`274cdcfd51b669a0fd52b7ef258dac29bce4a2c5ec17184673ca877c8ddfccae`)
returned exit code `1` with `private staging cleanup failed` before promotion.
The detached probe at `C:/Users/Administrator/Documents/Codex/2026-08-20/qu/outputs/spr-write-probe-274cdc`
also observed a `FileNotFoundError` for a temporary record path. No raw stderr
file was persisted, so this receipt records that limitation explicitly.

## Frozen staging evidence

The retained path
`docs/architecture/reuse_corrections/v2/.v076-spr-stage-932dca6ae7d92f14209512b9c9a3ddfb/`
contains only `manifest.json` (SHA-256
`2809490a991347c56a88819ce1a2963cd41175e65e280f4424e9747f94e36463`, 92,644
bytes) and an empty `records/` directory. It is not the formal authority path,
contains zero record files, and is intentionally retained as frozen failure
evidence. It must not be completed, moved, promoted, deleted, or staged.

The external lock evidence is retained at
`%TEMP%/space-syndicate-v076-formal-locks/7a8ab2b761c9163fb8bcbddfeb0fdf55.lock`
with full SHA-256
`93dd6eeeb10542df6926f948ae2851ea320d6d8c05c0d415aeec2a06d6b0f0b6`; its
recorded PID was `7084`, that PID was absent at audit time, and the matching
builder-process count at audit time was `0`.

## Replacement candidate

The replacement external builder is currently sealed by SHA-256
`15649ded167667742e01eb29e808d35efa15dc0dd0057232f750dd37331a4bd3` and has
passed `py_compile`, a fresh detached real write (`83 created`), a second
idempotent write (`0 created / 83 identical`), and fail-closed fault probes.
Those results are evidence for the replacement candidate only; they do not
retroactively make the old attempt green or permit a same-head retry.

No Godot product file was changed by this attempt. The four untracked baseline
files remain byte-identical and are not part of this receipt's staging set.
