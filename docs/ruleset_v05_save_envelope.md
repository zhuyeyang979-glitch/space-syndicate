# Ruleset v0.5 Save Envelope

Status: passive handshake contract for SS05-01. Production save ownership remains with `GameSaveRuntimeCoordinator`, whose active format is version 1.

## v0.5 envelope

```text
save_version: 2
ruleset_id: "v0.5"
profile_schema_version: positive integer
currency_scale: 100
controller_state_versions: Dictionary[String, int]
session: Dictionary
domains: Dictionary
```

The envelope and every nested domain payload contain only dictionaries, arrays, strings, numbers, booleans, and null. Nodes, Callables, Objects, Resources, wall-clock deadlines, and UI state are forbidden.

## Compatibility handshake

- Version 1 without `ruleset_id` is classified as `legacy_v04`.
- The active v0.4 runtime keeps its existing version-1 read/write behavior.
- A v0.5 target may back up and identify a v1 save, but cannot resume or overwrite it. The player starts a new v0.5 session.
- A v0.4 writer cannot downgrade-overwrite a v0.5 envelope.
- Unknown versions, unknown rulesets, a currency scale other than 100, missing required controller versions, or non-pure payloads fail closed.
- No v0.4 active contract, wager, project, timer, financial position, or other live domain state is migrated by SS05-01.

`RulesetSaveHandshakeService` is a passive classifier and envelope composer. It performs no file IO and is not connected to the current production save path. QA round trips use `user://space_syndicate_design_qa/test_runs/` only.

## Deferred decision

The acquisition-cost basis for emergency sale of a merged or upgraded card remains unresolved. Save migration and v0.5 crisis valuation must not infer cumulative, latest-copy, base-family, or another basis until a product decision is recorded.
