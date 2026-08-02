extends SceneTree

const CONTRACT := preload("res://scripts/tools/monster_runtime_owner_replay_scenario_identity_v1.gd")
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	var authorization := CONTRACT.authorization()
	_expect(not authorization.is_empty(), "Monster replay authorization is readable")
	_expect(str(authorization.get("authorization_id", "")) == CONTRACT.AUTHORIZATION_ID, "authorization id is exact")
	_expect(int(authorization.get("replay_attempt_count_before", -1)) == 0 \
			and int(authorization.get("authorized_new_replay_count", -1)) == 1 \
			and int(authorization.get("replay_attempt_count_after", -1)) == 1, "authorization permits exactly one replay")
	_expect(int(authorization.get("targeted_owner_capture_diagnostic_count_before", -1)) == 7 \
			and int(authorization.get("targeted_owner_capture_diagnostic_count_after", -1)) == 7, "replay cannot consume diagnostic quota")

	var source := _valid_source(authorization)
	var identity := CONTRACT.build(source)
	_expect(bool(CONTRACT.validation_report(identity, str(source.get("repository_head", ""))).get("valid", false)), "production Monster replay identity validates")
	_expect(WIRE.is_closed_data(identity), "Monster replay identity is strict closed data")
	_expect(str(identity.get("production_runtime_ruleset_id", "")) == "v0.6" \
			and str(identity.get("highest_target_ruleset_id", "")) == "v0.7.3" \
			and not bool(identity.get("highest_target_ruleset_used_as_runtime_identity", true)), "production and highest target rulesets stay separate")
	_expect(int(identity.get("owner_index", -1)) == 9 \
			and str(identity.get("section_id", "")) == "monsters" \
			and str(identity.get("owner_id", "")) == "monster_runtime", "identity binds only Owner index 9")
	_expect(int(identity.get("monster_save_schema_version", -1)) == 2 \
			and int(identity.get("monster_registry_state_version", -1)) == 2 \
			and str(identity.get("monster_checkpoint_strategy", "")) == "registry_managed_checkpoint", "identity binds Monster Save v2 and registry-managed checkpoint")

	_expect(_rejects_change(source, "production_runtime_ruleset_id", "v0.7.3"), "highest target cannot replace production ruleset")
	_expect(_rejects_change(source, "production_runtime_ruleset_id", ""), "missing production ruleset fails closed")
	_expect(_rejects_change(source, "owner_index", 8), "wrong Owner index fails closed")
	_expect(_rejects_change(source, "owner_index", 9.0), "numeric coercion fails closed")
	_expect(_rejects_change(source, "monster_save_schema_version", 1), "Monster v1 cannot qualify")
	_expect(_rejects_change(source, "monster_checkpoint_strategy", "owner_internal_transaction_checkpoint"), "independent checkpoint strategy cannot qualify")
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
		"monster_save_schema_version": CONTRACT.SAVE_SCHEMA_VERSION,
		"monster_registry_state_version": CONTRACT.REGISTRY_STATE_VERSION,
		"monster_checkpoint_strategy": CONTRACT.CHECKPOINT_STRATEGY,
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
	print("MONSTER_RUNTIME_OWNER_REPLAY_SCENARIO_IDENTITY_V1_TEST|status=%s|checks=%d|failures=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks,
		_failures.size(),
	])
	if not _failures.is_empty():
		push_error("Monster replay identity failures:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
