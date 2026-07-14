# v0.6 Save Envelope / Handshake / Atomic I/O Contract

## Ownership boundary

`GameSaveRuntimeCoordinator` is the only envelope and file-I/O owner. It validates an already captured envelope, writes a same-directory temporary file, validates the readback, replaces the destination with rollback protection, and returns a sanitized operation receipt. It never discovers or calls gameplay owners.

`GameSessionRuntimeController` owns only session and save-operation lifecycle. It forwards an already composed envelope and authorization; it does not capture or apply business sections.

`RulesetSaveHandshakeService` owns the v3 schema, registry handshake, deterministic codec/fingerprint, legacy inspection, and write authorization. It performs no file I/O.

## v3 envelope

Every resumable envelope has exactly these top-level fields:

- `envelope_schema=space_syndicate.v06.save.v3`
- `save_version=3`
- `ruleset_id=v0.6`
- `profile_schema_version=1`
- `currency_scale=100`
- `format_id=space_syndicate_json`
- `codec_id=explicit_tagged_json_v1`
- non-empty deterministic `envelope_id` and `write_id`
- exact `controller_state_versions`
- exact `section_manifest`
- exact required `sections`
- `migration_policy=new_session_only`

Unknown or missing top-level fields and sections fail closed. Each required section is owned by exactly one registry entry and carries the registry `schema_version`. The handshake declares required sections but never fabricates their payloads.

Raw arbitrary Variants are forbidden. The codec accepts JSON primitives plus explicit tagged `Vector2` and `Color` dictionaries. Dictionary keys are strings, floats must be finite, keys are sorted for serialization, and integral JSON numbers normalize consistently before SHA-256 fingerprinting.

## Legacy and overwrite contract

v1, v2, unknown, truncated, and corrupt inputs are inspect-only and never resumable. A v3 write cannot replace an existing file without a matching handshake authorization. Replacing legacy, unknown, or corrupt data additionally requires `allow_backup=true`; the byte-identical backup is completed before the original is parked.

The write sequence is:

1. validate v3 envelope and explicit `user://test_runs/.../*.save` path;
2. verify authorization against current destination fingerprint;
3. write deterministic JSON to a same-directory temporary file;
4. read and validate the temporary file and fingerprint;
5. create any required backup;
6. park the previous destination, install the temporary file, read and validate it;
7. restore the parked destination on failure, otherwise remove the park file.

The same `write_id` and fingerprint is idempotent. The same `write_id` with different content is a collision. Failed writes leave the previous valid file intact and remove task-owned temporary files.

## Narrow C16b API

Production owner orchestration must consume only:

- `validate_envelope(envelope)`
- `write_authorization(path, envelope, options)`
- `write_validated_envelope(path, envelope, authorization)`
- `read_and_validate(path)`
- `inspect_legacy(source)`

Owner capture/apply remains a C16b responsibility outside these services. `public_operation_receipt` is an allowlist projection and never contains the envelope, sections, balances, hands, ownership truth, or AI metadata.

