# Public Region Selection Catalog Audit

## Scope

This boundary publishes a read-only region catalog for later typed table-selection requests. It does not change table focus, card submission, domain execution, save data, or gameplay rules.

## Authority

- Stable IDs are authored by `SessionStartWorldPlanBuilder` using the existing `region.%03d` contract.
- `WorldSessionState` owns the authoritative district array and therefore its public order.
- `WorldSessionState.public_region_selection_catalog_source()` projects only allowlisted public fields and never synthesizes a missing ID.
- `TableSelectionCatalogQueryPort` is stateless. It validates the source and builds a detached `PublicRegionSelectionCatalogSnapshot`.
- Public indices are compatibility metadata. `region_id` is the identity.

## Session And Source Envelope

Every snapshot also carries `session_id`, `session_revision`, `source_owner_id`, and `source_ready`. Active snapshots bind to the read-only `GameSessionRuntimeController.session_summary()` and `session_start_revision()` result. The exact region `source_owner_id` is `WorldSessionState`; `source_ready` must equal `available`.

Pre-session output uses the deterministic identity `session_id=""`, `session_revision=0`, and `source_ready=false`. A missing or malformed session identity fails closed. A new session may retain identical region ordering hashes, but its different session identity lets downstream consumers reject old/new snapshot mixing.

## Entry Contract

Each entry contains exactly:

- `region_id`
- `public_index`
- `public_name`
- `public_status`
- `selectable`
- `disabled_reason`
- `public_terrain`

Destroyed regions remain selectable for public inspection and report `public_status=ruins`. No owner, cash, hand, AI, private inference, card inventory, or save data is projected.

## Revisions

`ordering_revision` hashes the domain tag plus ordered rows of:

```text
region_id, public_index, selectable
```

`ordering_fingerprint` hashes the same ordered membership with a distinct domain/version tag. `data_revision` hashes only the entry allowlist in field order.

The order values exclude names, terrain, lifecycle, game time, geometry, selection, hover, camera, product focus, timestamp, and RNG. Public name, terrain, and lifecycle changes affect only `data_revision`.

Session identity and source metadata are intentionally excluded from both ordering hashes and `data_revision`.

## Fail-Closed Rules

The query returns a deterministic unavailable empty snapshot for pre-session state, missing dependencies, malformed session/source identity, malformed rows, non-pure data, blank or duplicate IDs, missing public names, noncontiguous indices, invalid primitive metadata, or invalid hashes. Integer and Boolean fields require their exact primitive types and are not recovered through coercion. It does not fall back to `Main`, map-node order, Codex IDs, UI child order, or generated IDs.

## Composition

Production scene composition contains exactly one:

```text
GameRuntimeCoordinator/TableSelectionCatalogQueryPort
```

Its explicit dependencies are:

```text
../WorldSessionState
../ProductMarketRuntimeController
../GameSessionRuntimeController
```

The product dependency belongs to the sibling product catalog method; the region snapshot has no product revision dependency.
