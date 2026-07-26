extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const SAVE_COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator/GameSessionRuntimeController/GameSaveRuntimeCoordinator"
const SOURCE_SERVICE_NAME := "CardCodexPublicSourceService"
const FACILITY_CARD_ID := "facility.factory.life.rank_1"
const INTERACTION_CARD_ID := "interaction.starlink_dismantle.rank_1"
const QA_SAVE_PATH := "user://test_runs/card_presentation_public_contract.save"
const PRIVATE_SENTINELS := [
	"CARD_PRESENTATION_PRIVATE_CASH_SENTINEL",
	"CARD_PRESENTATION_PRIVATE_HAND_SENTINEL",
	"CARD_PRESENTATION_PRIVATE_DISCARD_SENTINEL",
	"CARD_PRESENTATION_PRIVATE_CITY_GUESS_SENTINEL",
	"CARD_PRESENTATION_PRIVATE_AI_PLAN_SENTINEL",
]
const FORBIDDEN_PUBLIC_KEYS := [
	"cash",
	"cash_cents",
	"hand",
	"slots",
	"discard",
	"private_discard",
	"city_guesses",
	"ai_private_plan",
	"ai_plan",
	"hidden_owner",
	"owner_player_index",
]

var _checks := 0
var _failures: Array[String] = []
var _main: Node
var _coordinator: Node
var _source_service: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "main_scene_loads")
	if packed == null:
		_finish()
		return
	_main = packed.instantiate()
	_cleanup_test_save()
	var save := _main.get_node_or_null(SAVE_COORDINATOR_PATH)
	_expect(save != null and save.has_method("set_qa_default_save_path_override"), "qa_save_override_available_before_tree_entry")
	if save == null or not save.has_method("set_qa_default_save_path_override"):
		_main.free()
		_main = null
		_finish()
		return
	_expect(bool(save.call("set_qa_default_save_path_override", QA_SAVE_PATH)), "focused_gate_uses_isolated_qa_save_path")
	if save.has_method("operation_snapshot"):
		var operation: Dictionary = save.call("operation_snapshot")
		_expect(str(operation.get("default_save_path", "")) == QA_SAVE_PATH and bool(operation.get("qa_save_path_override_active", false)), "qa_save_override_points_to_test_runs_before_tree_entry")
	root.add_child(_main)
	await process_frame
	if _main.has_method("_new_game"):
		_main.set("configured_player_count", 4)
		_main.set("configured_ai_player_count", 3)
		_main.call("_new_game")
	await process_frame
	_coordinator = _main.get_node_or_null(COORDINATOR_PATH)
	_source_service = _coordinator.get_node_or_null(SOURCE_SERVICE_NAME) if _coordinator != null else null
	_test_source_service_contract()
	_test_public_card_facts_contract()
	_test_private_state_invariance()
	await _cleanup()
	_finish()


func _test_source_service_contract() -> void:
	_expect(_coordinator != null, "production_coordinator_reachable")
	_expect(_source_service != null and _source_service.has_method("compose_card_facts"), "scene_owned_card_codex_public_source_service_exposes_card_facts")
	if _source_service == null or not _source_service.has_method("debug_snapshot"):
		_expect(false, "card_codex_public_source_debug_available")
		return
	var debug: Dictionary = _source_service.call("debug_snapshot")
	_expect(bool(debug.get("service_ready", false)) and bool(debug.get("owns_public_source_assembly", false)), "source_service_owns_public_card_fact_assembly")
	_expect(not bool(debug.get("reads_private_world", true)) and not bool(debug.get("reads_player_state", true)), "source_service_declares_no_private_player_world_reads")
	_expect(not bool(debug.get("owns_rules", true)) and not bool(debug.get("has_save_api", true)), "source_service_does_not_own_rules_or_save")
	_expect(
		int(debug.get("dependency_count", 0)) == 4 \
			and bool(debug.get("dependencies_bound", false)),
		"source_service_has_exact_semantic_projection_localization_snapshot_dependencies"
	)


func _test_public_card_facts_contract() -> void:
	var facility := _compose_card_facts(FACILITY_CARD_ID)
	_expect(bool(facility.get("valid", false)), "stable_facility_card_facts_valid")
	_expect(
		str(facility.get("card_name", "")) == FACILITY_CARD_ID \
			and str(facility.get("category_id", "")) == "facility" \
			and (facility.get("family_ladder", []) as Array).size() == 4,
		"facility_identity_and_i_iv_ladder_come_from_playerface_dto"
	)
	_expect(
		not str(facility.get("acquisition_cost_text", "")).is_empty() \
			and not str(facility.get("activation_cost_text", "")).is_empty(),
		"facility_acquisition_and_activation_costs_are_separate"
	)
	_expect(
		not str(facility.get("timing_text", "")).is_empty() \
			and not str(facility.get("target_text", "")).is_empty() \
			and not (facility.get("condition_texts", []) as Array).is_empty() \
			and not (facility.get("effect_step_texts", []) as Array).is_empty() \
			and not str(facility.get("duration_text", "")).is_empty() \
			and not str(facility.get("counterability_text", "")).is_empty() \
			and not str(facility.get("information_scope_text", "")).is_empty(),
		"facility_structured_rule_facts_come_from_playerface_dto"
	)
	var interaction := _compose_card_facts(INTERACTION_CARD_ID)
	_expect(
		bool(interaction.get("valid", false)) \
			and str(interaction.get("category_id", "")) == "interaction" \
			and str(interaction.get("target_text", "")).contains("对手") \
			and not (interaction.get("effect_step_texts", []) as Array).is_empty(),
		"projection_only_interaction_is_publicly_structured_without_readiness_promotion"
	)
	_expect(
		_canonical_text(facility) != _canonical_text(interaction),
		"different_stable_card_ids_change_public_playerface_facts"
	)
	_expect(_forbidden_paths(facility).is_empty(), "public_facility_card_facts_have_no_private_keys|paths=%s" % [_forbidden_paths(facility)])
	_expect(_sentinel_paths(facility).is_empty(), "public_facility_card_facts_have_no_private_sentinels|paths=%s" % [_sentinel_paths(facility)])


func _test_private_state_invariance() -> void:
	_reset_private_fixture()
	var before := _public_projection(_compose_card_facts(FACILITY_CARD_ID))
	_mutate_private_state()
	var after := _public_projection(_compose_card_facts(FACILITY_CARD_ID))
	_expect(_canonical_text(before) == _canonical_text(after), "same_public_card_facts_are_viewer_private_state_invariant")
	_expect(_forbidden_paths(after).is_empty(), "mutated_public_card_facts_have_no_private_keys|paths=%s" % [_forbidden_paths(after)])
	_expect(_sentinel_paths(after).is_empty(), "mutated_public_card_facts_have_no_private_sentinels|paths=%s" % [_sentinel_paths(after)])


func _compose_card_facts(card_id: String) -> Dictionary:
	if _source_service == null or not _source_service.has_method("compose_card_facts"):
		return {}
	var value: Variant = _source_service.call("compose_card_facts", card_id, -1)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _reset_private_fixture() -> void:
	var players := _array(((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	for index in range(players.size()):
		var player := (players[index] as Dictionary).duplicate(true)
		player["cash"] = 100000 + index
		player["cash_cents"] = (100000 + index) * 100
		player["slots"] = [{"name": "CARD_PRESENTATION_PRIVATE_HAND_SENTINEL"}]
		player["discard"] = ["CARD_PRESENTATION_PRIVATE_DISCARD_SENTINEL"]
		player["private_discard"] = ["CARD_PRESENTATION_PRIVATE_DISCARD_SENTINEL"]
		player["city_guesses"] = {}
		player["ai_private_plan"] = "CARD_PRESENTATION_PRIVATE_AI_PLAN_SENTINEL"
		players[index] = player
	((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players


func _mutate_private_state() -> void:
	var players := _array(((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players)
	if players.size() < 2:
		return
	var player := (players[1] as Dictionary).duplicate(true)
	player["cash"] = "CARD_PRESENTATION_PRIVATE_CASH_SENTINEL"
	player["cash_cents"] = 77777777
	player["slots"] = [{"name": "CARD_PRESENTATION_PRIVATE_HAND_SENTINEL"}]
	player["discard"] = ["CARD_PRESENTATION_PRIVATE_DISCARD_SENTINEL"]
	player["private_discard"] = ["CARD_PRESENTATION_PRIVATE_DISCARD_SENTINEL"]
	player["city_guesses"] = {0: "CARD_PRESENTATION_PRIVATE_CITY_GUESS_SENTINEL"}
	player["ai_private_plan"] = "CARD_PRESENTATION_PRIVATE_AI_PLAN_SENTINEL"
	players[1] = player
	((_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).world_session_state()).players = players


func _public_projection(snapshot: Dictionary) -> Dictionary:
	return {
		"valid": snapshot.get("valid", false),
		"card_name": snapshot.get("card_name", ""),
		"family_id": snapshot.get("family_id", ""),
		"rank": snapshot.get("rank", 0),
		"category_id": snapshot.get("category_id", ""),
		"industry_id": snapshot.get("industry_id", ""),
		"acquisition_cost_text": snapshot.get("acquisition_cost_text", ""),
		"activation_cost_text": snapshot.get("activation_cost_text", ""),
		"timing_text": snapshot.get("timing_text", ""),
		"target_text": snapshot.get("target_text", ""),
		"condition_texts": _array(snapshot.get("condition_texts", [])),
		"effect_step_texts": _array(snapshot.get("effect_step_texts", [])),
		"duration_text": snapshot.get("duration_text", ""),
		"counterability_text": snapshot.get("counterability_text", ""),
		"information_scope_text": snapshot.get("information_scope_text", ""),
		"semantic_fingerprint": snapshot.get("semantic_fingerprint", ""),
		"dto_fingerprint": snapshot.get("dto_fingerprint", ""),
	}


func _forbidden_paths(value: Variant, path: String = "$") -> Array[String]:
	var result: Array[String] = []
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			if FORBIDDEN_PUBLIC_KEYS.has(key):
				result.append("%s.%s" % [path, key])
			result.append_array(_forbidden_paths((value as Dictionary)[key_variant], "%s.%s" % [path, key]))
	elif value is Array:
		for index in range((value as Array).size()):
			result.append_array(_forbidden_paths((value as Array)[index], "%s[%d]" % [path, index]))
	return result


func _sentinel_paths(value: Variant, path: String = "$") -> Array[String]:
	var result: Array[String] = []
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			result.append_array(_sentinel_paths((value as Dictionary)[key_variant], "%s.%s" % [path, str(key_variant)]))
	elif value is Array:
		for index in range((value as Array).size()):
			result.append_array(_sentinel_paths((value as Array)[index], "%s[%d]" % [path, index]))
	else:
		var text := str(value)
		for sentinel in PRIVATE_SENTINELS:
			if text.contains(sentinel):
				result.append(path)
	return result


func _canonical_text(value: Variant) -> String:
	return JSON.stringify(_canonical_value(value))


func _canonical_value(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		var keys := (value as Dictionary).keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
		for key_variant in keys:
			result[str(key_variant)] = _canonical_value((value as Dictionary)[key_variant])
		return result
	if value is Array:
		var result := []
		for item in value:
			result.append(_canonical_value(item))
		return result
	if value is Color:
		return (value as Color).to_html()
	return value


func _array(value: Variant) -> Array:
	return (value as Array).duplicate(true) if value is Array else []


func _cleanup() -> void:
	if _main != null:
		_main.queue_free()
	_main = null
	_coordinator = null
	_source_service = null
	await process_frame
	await process_frame
	_cleanup_test_save()


func _cleanup_test_save() -> void:
	var absolute_path := ProjectSettings.globalize_path(QA_SAVE_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(label)
	push_error("CARD_PRESENTATION_PUBLIC_CONTRACT: %s" % label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("CARD_PRESENTATION_PUBLIC_CONTRACT|status=%s|checks=%d|failures=%d|details=%s" % [status, _checks, _failures.size(), JSON.stringify(_failures)])
	quit(0 if _failures.is_empty() else 1)
