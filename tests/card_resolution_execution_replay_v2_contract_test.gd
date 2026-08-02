extends SceneTree

const IDENTITY := preload("res://scripts/tools/card_resolution_execution_owner_replay_scenario_identity_v2.gd")
const V1_IDENTITY := preload("res://scripts/tools/card_resolution_execution_owner_replay_scenario_identity_v1.gd")

const V1_CHILD_SHA256 := "6eb417efebc8d01e80c55bda846bca9667c54bddabbe06af184beacd7dc36740"
const V1_PARENT_SHA256 := "6e56a87a884c93ac0dbd2caf1850c6d209de538a763c420a2f716070f7bb0ed1"
const V1_CLAIM_SHA256 := "08d52b59f12805f1e79db7ec294d78dfc64f38a63c66e81879c12c7949b950ba"
const V1_CONSUMED_SHA256 := "c629aa44323b5a7bc72c7ce1933f702e662a8763cd3f1e810550ca82073020fd"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var authorization := IDENTITY.authorization()
	_expect(not authorization.is_empty(), "replay v2 authorization is valid")
	_expect(int(authorization.get("replay_attempt_count_before", -1)) == 1 \
			and int(authorization.get("authorized_new_replay_count", -1)) == 1 \
			and int(authorization.get("replay_attempt_count_after", -1)) == 2, "authorization permits only transition 1 to 2")
	_expect(str(authorization.get("authorization_id", "")) \
			== "alpha04c-card-resolution-execution-replay-v2-authoritative-parity", "authorization id is exact")
	_expect(str(authorization.get("replay_v1_child_sha256", "")) == V1_CHILD_SHA256 \
			and str(authorization.get("replay_v1_parent_sha256", "")) == V1_PARENT_SHA256 \
			and str(authorization.get("replay_v1_claim_sha256", "")) == V1_CLAIM_SHA256 \
			and str(authorization.get("replay_v1_consumed_admission_sha256", "")) == V1_CONSUMED_SHA256, "authorization seals all four replay v1 hashes")

	var identity := IDENTITY.build({
		"replay_id": IDENTITY.RUN_ID,
		"repository_head": "a".repeat(40),
		"scene_path": IDENTITY.SCENE_PATH,
		"registry_id": IDENTITY.REGISTRY_ID,
		"production_runtime_ruleset_id": IDENTITY.PRODUCTION_RUNTIME_RULESET_ID,
		"highest_target_ruleset_id": IDENTITY.HIGHEST_TARGET_RULESET_ID,
		"challenge_depth": IDENTITY.CHALLENGE_DEPTH,
		"run_seed": IDENTITY.RUN_SEED,
		"local_player_count": IDENTITY.LOCAL_PLAYER_COUNT,
		"ai_player_count": IDENTITY.AI_PLAYER_COUNT,
		"owner_index": IDENTITY.OWNER_INDEX,
		"section_id": IDENTITY.SECTION_ID,
		"owner_id": IDENTITY.OWNER_ID,
		"execution_save_schema_version": IDENTITY.SAVE_SCHEMA_VERSION,
		"execution_wire_version": IDENTITY.EXECUTION_WIRE_VERSION,
		"transition_state_wire_version": IDENTITY.TRANSITION_STATE_WIRE_VERSION,
		"execution_registry_state_version": IDENTITY.REGISTRY_STATE_VERSION,
		"execution_checkpoint_strategy": IDENTITY.CHECKPOINT_STRATEGY,
	})
	_expect(bool(IDENTITY.validation_report(identity, "a".repeat(40)).get("valid", false)), "scenario identity validates exact production configuration")
	_expect(str(identity.get("restore_parity_authority_source", "")) == "save_v4_and_typed_authoritative_queries" \
			and not bool(identity.get("debug_snapshot_used_as_restore_authority", true)), "identity binds authoritative projection and rejects debug authority")
	_expect(int(identity.get("execution_save_schema_version", -1)) == 4 \
			and int(identity.get("transition_state_wire_version", -1)) == 2 \
			and int(identity.get("execution_registry_state_version", -1)) == 2, "Save v4, Transition wire v2, and Owner state v2 stay fixed")

	_expect(FileAccess.get_sha256("res://reports/handoffs/alpha04c_card_resolution_execution_save_v4_replay_v1.json").to_lower() == V1_CHILD_SHA256, "replay v1 child evidence remains byte-identical")
	_expect(FileAccess.get_sha256("res://reports/handoffs/alpha04c_card_resolution_execution_save_v4_replay_v1_parent_attestation.json").to_lower() == V1_PARENT_SHA256, "replay v1 parent evidence remains byte-identical")
	var v1_root := V1_IDENTITY.authorized_replay_root()
	_expect(not v1_root.is_empty() \
			and FileAccess.get_sha256(v1_root.path_join("replay_attempt_claim.json")).to_lower() == V1_CLAIM_SHA256, "replay v1 claim remains byte-identical")
	_expect(not v1_root.is_empty() \
			and FileAccess.get_sha256(v1_root.path_join("replay_child_admission_consumed.json")).to_lower() == V1_CONSUMED_SHA256, "replay v1 consumed admission remains byte-identical")
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("CARD_RESOLUTION_EXECUTION_REPLAY_V2_CONTRACT_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Execution replay v2 contract failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
