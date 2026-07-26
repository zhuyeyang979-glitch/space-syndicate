# Semantic Kernel v1 Narrow PR Validation

## Baseline and scope

- Base commit: `4f50cc439d2879849ca1c125a320af8a18c7465e`
- Branch: `codex/semantic-kernel-pr-4f50cc4`
- Production changes are limited to new files under `scripts/semantic/`.
- No existing compiler, schema, catalog, AI projection, PlayerFace service,
  coordinator, Main, save, RNG, or domain-owner file was edited.

## Delivered boundary

The PR adds closed JSON v1 validation/building primitives for the shared types
named by `semantic_kernel_v1_contract`. Wire values permit only dictionaries,
arrays, strings, booleans, and safe integers. They reject nulls, floats,
non-string dictionary keys, and Godot runtime values. Stable identifiers are
ASCII-only and fingerprints use canonical lower-case SHA-256.

All builders return deep detached dictionaries. Self-fingerprinted values are
sealed only after closed-shape validation. GDScript dictionaries are not
physically immutable, so the boundary guarantees immutability by never
retaining caller dictionaries and by returning detached copies from registry
lookups.

`OperationHandlerRegistry` stores only sealed `OperationHandlerDescriptor`
metadata. It has no handler pointer, Callable, transaction, gameplay state,
catalog, save section, or RNG authority. Identical pre-seal registration is an
idempotent no-op; a different descriptor for the same operation ID/version is
rejected; all post-seal registration and unknown lookup fail closed. Owner-bound
dispatch is explicitly deferred to a later scene-composition PR.

## Focused Godot evidence

Command:

```powershell
pwsh -NoProfile -File tools/invoke_godot_test.ps1 `
  -TestScript res://tests/semantic_kernel_v1_test.gd `
  -TimeoutSeconds 60 `
  -ExpectedCompletionMarker SEMANTIC_KERNEL_V1_TEST
```

Results:

- Import bootstrap: PASS, 26.891 seconds, zero script errors.
- First focused run: `70/70 PASS`, 0.540 seconds process time,
  46.377 milliseconds in-suite.
- Warm focused rerun: `70/70 PASS`, 0.558 seconds process time,
  40.603 milliseconds in-suite.
- `smoke_test.gd --check-only`: PASS, 5.204 seconds, zero script errors.
- Scoped Godot processes after each run: 0.

Coverage includes schema/version/ASCII-ID rejection, canonical fingerprints,
deep detachment, forbidden runtime values, unknown condition/target/operation
failure, clipping-before-projection privacy rejection, explicit randomness
policies for random operations, registry exact-once/idempotency/conflict/seal
behavior, unknown lookup, and zero RNG draws during construction.

## Deliberate limitations

- No domain semantic compiler or domain schema is added in this PR.
- No operation executes; existing owner-bound transaction ports remain the
  required future dispatch boundary.
- Parameter, observation, message, cost, and activation schemas must be supplied
  as closed trusted manifests by later domain composition.
- No production consumer is cut over, so this PR changes no rule, balance,
  target, RNG order, save shape, privacy entitlement, or runtime behavior.
