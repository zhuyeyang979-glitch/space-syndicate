extends SceneTree

const CONTRACT := preload("res://scripts/tools/card_inventory_owner_replay_scenario_identity_v1.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var authorization := CONTRACT.authorization()
	_expect(not authorization.is_empty(), "replay-v2 authorization is readable")
	_expect(str(authorization.get("authorization_id", "")) == "alpha04c-v7-card-inventory-save-v4-checkpoint-v2-replay-v2-scenario-identity", "authorization id is exact")
	_expect(int(authorization.get("replay_attempt_count_before", -1)) == 1 \
			and int(authorization.get("authorized_new_replay_count", -1)) == 1 \
			and int(authorization.get("replay_attempt_count_after", -1)) == 2, "authorization permits only transition 1 to 2")
	_expect(int(authorization.get("targeted_owner_capture_diagnostic_count_before", -1)) == 7 \
			and int(authorization.get("targeted_owner_capture_diagnostic_count_after", -1)) == 7, "replay authorization cannot consume diagnostic quota")

	var source := _valid_source(authorization)
	var identity := CONTRACT.build(source)
	var report := CONTRACT.validation_report(identity, str(source.get("repository_head", "")))
	_expect(bool(report.get("valid", false)), "production replay scenario identity validates")
	_expect(WIRE.is_closed_data(identity), "scenario identity is strict closed data")
	_expect(str(identity.get("production_runtime_ruleset_id", "")) == "v0.6", "production runtime identity is v0.6")
	_expect(str(identity.get("highest_target_ruleset_id", "")) == "v0.7.3", "highest target identity is recorded separately")
	_expect(str(identity.get("scenario_identity_authority", "")) == "production_runtime_ruleset_id" \
			and not bool(identity.get("highest_target_ruleset_used_as_runtime_identity", true)), "highest target cannot satisfy runtime identity")
	_expect(int(identity.get("card_inventory_save_schema_version", -1)) == 4 \
			and int(identity.get("card_inventory_checkpoint_schema_version", -1)) == 2, "Card Inventory schema versions are bound")

	_expect(_rejects_change(source, "production_runtime_ruleset_id", "v0.7.3"), "target ruleset cannot replace production runtime ruleset")
	_expect(_rejects_change(source, "production_runtime_ruleset_id", ""), "missing runtime ruleset fails closed")
	_expect(_rejects_change(source, "highest_target_ruleset_id", "v0.6"), "highest target must remain v0.7.3")
	_expect(_rejects_change(source, "scene_path", "res://scenes/runtime/GameSessionRuntimeController.tscn"), "scene path is production main")
	_expect(_rejects_change(source, "registry_id", "other_registry"), "registry identity is exact")
	_expect(_rejects_change(source, "owner_index", 8), "owner index is exactly seven")
	_expect(_rejects_change(source, "owner_index", 7.0), "numeric identity fields reject float coercion")
	_expect(_rejects_change(source, "section_id", &"card_inventory"), "string identity fields reject StringName coercion")
	_expect(_rejects_change(source, "card_inventory_save_schema_version", 3), "Save v3 cannot qualify")
	_expect(_rejects_change(source, "card_inventory_checkpoint_schema_version", 1), "Checkpoint v1 cannot qualify")
	_finish()


func _valid_source(authorization: Dictionary) -> Dictionary:
	return {
		"replay_id": str(authorization.get("run_id", "")),
		"repository_head": "0123456789abcdef0123456789abcdef01234567",
		"scene_path": CONTRACT.SCENE_PATH,
		"registry_id": CONTRACT.REGISTRY_ID,
		"production_runtime_ruleset_id": CONTRACT.PRODUCTION_RUNTIME_RULESET_ID,
		"highest_target_ruleset_id": CONTRACT.HIGHEST_TARGET_RULESET_ID,
		"challenge_depth": CONTRACT.CHALLENGE_DEPTH,
		"run_seed": CONTRACT.RUN_SEED,
		"local_player_count": CONTRACT.LOCAL_PLAYER_COUNT,
		"ai_player_count": CONTRACT.AI_PLAYER_COUNT,
		"owner_index": CONTRACT.OWNER_INDEX,
		"section_id": CONTRACT.SECTION_ID,
		"owner_id": CONTRACT.OWNER_ID,
		"card_inventory_save_schema_version": CONTRACT.SAVE_SCHEMA_VERSION,
		"card_inventory_checkpoint_schema_version": CONTRACT.CHECKPOINT_SCHEMA_VERSION,
	}


func _rejects_change(source: Dictionary, field: String, value: Variant) -> bool:
	var changed := source.duplicate(true)
	changed[field] = value
	return not bool(CONTRACT.validation_report(
		CONTRACT.build(changed),
		str(source.get("repository_head", ""))
	).get("valid", true))


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print("CARD_INVENTORY_OWNER_REPLAY_SCENARIO_IDENTITY_V1_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Replay scenario identity failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
