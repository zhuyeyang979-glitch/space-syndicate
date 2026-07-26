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

`OperationHandlerRegistry` stores only declared projection metadata. It has no
handler pointer, Callable, transaction, gameplay state, catalog, save section,
or RNG authority. `register_handler` always rejects because this PR has neither
a trusted compiler manifest nor a real owner-port attestation. Projection
metadata uses explicitly named declaration, seal, fingerprint, and lookup APIs.
Identical declaration is idempotent, conflicting metadata fails closed, and an
`active` manifest can never produce a valid report or active readiness claim.

The adversarial follow-up also establishes these gates:

- unknown or retired ID arrays force `SemanticValidationReport.valid=false`
  even when the issue array is empty;
- legality proof fingerprints are canonical and every request, ruleset,
  semantic, actor, source, rules, world, registry, and RNG revision/fingerprint
  is equality-bound to its `RuleExecutionPlan`;
- operations use the exact randomness policy declared by their closed contract,
  deterministic operations use explicit `none`, random operations use non-none,
  and result visibility must match the randomness policy;
- descriptor identities use semantic prefixes and stable ASCII IDs only;
  paths, slashes, double-colon dispatch, method fields, and printable prose are
  rejected;
- execution and RulesProjection capability flags are rejected in this PR.

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
- Original focused gate: `70/70 PASS`.
- Adversarial focused gate: `116/116 PASS`, 0.564 seconds process time,
  49.930 milliseconds in-suite.
- `smoke_test.gd --check-only`: PASS, 5.222 seconds, zero script errors.
- Scoped Godot processes after each run: 0.

Coverage includes schema/version/ASCII-ID rejection, canonical fingerprints,
deep detachment, forbidden runtime values, unknown condition/target/operation
failure, clipping-before-projection privacy rejection, explicit randomness
policies for random operations, registry exact-once/idempotency/conflict/seal
behavior, unknown lookup, and zero RNG draws during construction.

The focused test is intentionally large because one SceneTree gate exercises
all shared value types plus the metadata registry and their cross-boundary
adversarial matrix. It does not instantiate a domain owner, production scene,
catalog, card adapter, or dispatch path.

## Deliberate limitations

- No domain semantic compiler or domain schema is added in this PR.
- No operation executes; existing owner-bound transaction ports remain the
  required future dispatch boundary.
- No trusted compiler-manifest or owner-port attestation exists here, so no
  active readiness can be certified.
- Revision-bound legality proof refs are integrity envelopes, not authorization
  capabilities, and they grant no access to hidden values.
- Privacy authority, production dispatch, and a Card adapter remain explicit
  unresolved major risks for later PRs.
- Parameter, observation, message, cost, and activation schemas must be supplied
  as closed trusted manifests by later domain composition.
- No production consumer is cut over, so this PR changes no rule, balance,
  target, RNG order, save shape, privacy entitlement, or runtime behavior.
