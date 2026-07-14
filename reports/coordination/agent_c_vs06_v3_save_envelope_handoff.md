# VS06-C16a v3 Save Envelope Handoff

## Status

C16a implements the outer v3 save foundation without touching main, GameRuntimeCoordinator, or gameplay owners. Save identity is `save_version=3`, `ruleset_id=v0.6`, `currency_scale=100`. Legacy v1/v2 and malformed files are inspect-only; resume is always rejected.

The production Bench and focused test use only explicit `user://test_runs/...` paths. No default player save path is read, enumerated, or written.

## Files

- `scripts/runtime/game_save_runtime_coordinator.gd`
- `scenes/runtime/GameSaveRuntimeCoordinator.tscn`
- `scripts/runtime/game_session_runtime_controller.gd`
- `scripts/runtime/ruleset_save_handshake_service.gd`
- `scenes/runtime/RulesetSaveHandshakeService.tscn`
- `resources/rules/controller_state_version_registry_v06.tres`
- `scripts/tools/v06_save_envelope_runtime_bench.gd`
- `scenes/tools/V06SaveEnvelopeRuntimeBench.tscn`
- `tests/v06_save_envelope_runtime_test.gd`
- `docs/v06_save_envelope_runtime_contract.md`
- this handoff

## Public API

- `validate_envelope(envelope)`
- `write_authorization(path, envelope, options={})`
- `write_validated_envelope(path, envelope, authorization)`
- `read_and_validate(path)`
- `inspect_legacy(source)`
- `public_operation_receipt(receipt)`

Handshake additionally exposes deterministic composition, required registry metadata, explicit `Vector2`/`Color` codec, canonical JSON, fingerprinting, and authorization verification. GameSession only records read/write lifecycle and forwards already composed envelopes.

## Evidence

- Godot 4.7 isolated focused test: `V06_SAVE_ENVELOPE_RUNTIME_TEST`, 60/60 PASS.
- Godot 4.7 isolated Bench checkpoint: `V06_SAVE_ENVELOPE_RUNTIME_BENCH`, 10/10 PASS before the final explicit-path evidence row was added.
- Godot 4.7 MCP `res://scenes/tools/V06SaveEnvelopeRuntimeBench.tscn`: 11/11 PASS; debug `errors=[]`; stop `finalErrors=[]`. Runtime evidence reports v3/v0.6/currency 100, atomic roundtrip, idempotent replay, rollback after injected replacement failure, `qa_root=user://test_runs/`, `explicit_qa_path_only=true`, and `default_player_path_accessed=false`.

The focused test covers every top-level field removal, unknown header/section, registry mismatch, deterministic codec/fingerprint, roundtrip, idempotency, write-id collision, all five injected atomic failure stages, temp/swap cleanup, v1/v2 inspect-only behavior, legacy backup authorization, truncated/corrupt/unknown rejection, Session operation lifecycle, explicit QA path enforcement, and recursive public-receipt privacy.

## Known risks / C16b boundary

- Required section metadata is declared, but this batch intentionally captures no business payload. C16b must gather and checkpoint owners before composition.
- Transitional main/Coordinator legacy save wrappers cannot write because they do not provide a v3 envelope and authorization. C16b must replace that orchestration; C16a does not restore v1 behavior.
- The registry now includes the frozen player-organization owner. C16b must verify every required owner has a real checkpoint/save-load contract before it supplies that section.
- C16a does not compose or apply owners; the next step remains C16b and must not reopen this I/O boundary without a failing focused oracle.

## Lessons for other agents

- **Invariant:** only a fully validated v3/v0.6 envelope may reach temporary-file I/O; owners are captured before this boundary.
- **Failed approach:** serializing arbitrary Variant data or rewriting the destination directly cannot provide deterministic fingerprints or rollback-safe replacement.
- **Stable API:** C16b passes an already composed envelope through `validate_envelope`, `write_authorization`, `write_validated_envelope`, and `read_and_validate`.
- **Test oracle:** every injected failure preserves the prior fingerprint and leaves no `.tmp-` or `.swap-` artifact.
- **Integration trap:** a legacy or corrupt destination needs both backup and replace authorization; silently treating it as an empty path destroys recovery evidence.
- **Reusable pattern:** canonical pure-data JSON + readback validation + same-directory park/install/restore provides a narrow atomic boundary without duplicating owner truth.
- **Stale evidence:** assertions requiring production save version 1, the default `space_syndicate_current_run.save` path, or resumable v2 envelopes are obsolete and must not restore those paths.
- **Next dependency:** C16b must checkpoint, capture, validate, and atomically apply the registry owners while leaving this envelope/I/O owner unchanged.
