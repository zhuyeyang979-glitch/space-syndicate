extends SceneTree

const COORDINATOR_PATH := "RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator"
const SESSION_START_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const SOURCE_SERVICE_NAME := "CardCodexPublicSourceService"
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
var _primary_card_id := ""
var _interaction_card_id := ""


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_cleanup_test_save()
	var start_result := await SESSION_START_DRIVER.start_default_session(
		self,
		QA_SAVE_PATH,
		"card-presentation-public-contract"
	)
	_main = start_result.get("main_root") as Node
	_coordinator = start_result.get("coordinator") as GameRuntimeCoordinator
	var started := (
		bool(start_result.get("started", false))
		and bool(start_result.get("qa_save_override_ready", false))
		and int(start_result.get("main_start_call_count", -1)) == 0
		and int(start_result.get("setup_fallback_count", -1)) == 0
	)
	_expect(started, "formal_session_start_uses_typed_transaction")
	if not started or _main == null or _coordinator == null:
		await _cleanup()
		_finish()
		return
	_source_service = _coordinator.get_node_or_null(SOURCE_SERVICE_NAME)
	_primary_card_id = _first_public_card_id()
	_interaction_card_id = _first_public_card_id("interaction", true)
	_expect(_primary_card_id != "" and _interaction_card_id != "", "v06_public_fixture_cards_resolve")
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
		(debug.get("dependency_allowlist", []) as Array) == ["snapshot"]
			and int(debug.get("dependency_count", 0)) == 1
			and int(debug.get("public_catalog_card_count", 0)) == 348
			and bool(debug.get("uses_v06_player_contract", false))
			and not bool(debug.get("reads_legacy_v04_catalog", true)),
		"source_service_uses_only_the_v06_public_snapshot_dependency"
	)


func _test_public_card_facts_contract() -> void:
	var primary := _compose_card_facts(_primary_card_id)
	_expect(
		bool(primary.get("valid", false))
			and str(primary.get("card_name", "")) == _primary_card_id
			and str(primary.get("strategy_route_label", "")) != ""
			and str(primary.get("art_stats", "")) != ""
			and not _array(primary.get("key_rule_facts", [])).is_empty(),
		"legal_v06_card_facts_use_the_public_player_contract"
	)
	var interaction := _compose_card_facts(_interaction_card_id)
	_expect(
		bool(interaction.get("valid", false))
			and str(interaction.get("category_id", "")) == "interaction"
			and bool(interaction.get("targets_player", false))
			and not _array(interaction.get("key_rule_facts", [])).is_empty(),
		"direct_interaction_public_source_marks_player_target_and_rule_facts"
	)
	_expect(_canonical_text(primary) != _canonical_text(interaction), "different_public_card_changes_public_facts")
	_expect(_forbidden_paths(primary).is_empty(), "public_card_facts_have_no_private_keys|paths=%s" % [_forbidden_paths(primary)])
	_expect(_sentinel_paths(primary).is_empty(), "public_card_facts_have_no_private_sentinels|paths=%s" % [_sentinel_paths(primary)])


func _test_private_state_invariance() -> void:
	_reset_private_fixture()
	var before := _public_projection(_compose_card_facts(_primary_card_id))
	_mutate_private_state()
	var after := _public_projection(_compose_card_facts(_primary_card_id))
	_expect(_canonical_text(before) == _canonical_text(after), "same_public_card_facts_are_viewer_private_state_invariant")
	_expect(_forbidden_paths(after).is_empty(), "mutated_public_card_facts_have_no_private_keys|paths=%s" % [_forbidden_paths(after)])
	_expect(_sentinel_paths(after).is_empty(), "mutated_public_card_facts_have_no_private_sentinels|paths=%s" % [_sentinel_paths(after)])


func _compose_card_facts(card_name: String) -> Dictionary:
	if _source_service == null or not _source_service.has_method("compose_card_facts"):
		return {}
	var value: Variant = _source_service.call("compose_card_facts", card_name, -1)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _first_public_card_id(category_id: String = "", require_player_target := false) -> String:
	if _source_service == null:
		return ""
	var filter_id := category_id if category_id != "" else "all"
	var ids_variant: Variant = _source_service.call("ordered_card_ids", filter_id)
	var ids: Array = ids_variant if ids_variant is Array else []
	for card_id_variant in ids:
		var card_id := str(card_id_variant)
		var facts := _compose_card_facts(card_id)
		if not bool(facts.get("valid", false)):
			continue
		if require_player_target and not bool(facts.get("targets_player", false)):
			continue
		if (
			str(facts.get("strategy_route_label", "")) == ""
				or str(facts.get("art_stats", "")) == ""
				or _array(facts.get("key_rule_facts", [])).is_empty()
		):
			continue
		return card_id
	return ""


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
		"strategy_route_label": snapshot.get("strategy_route_label", ""),
		"art_stats": snapshot.get("art_stats", ""),
		"key_rule_facts": _array(snapshot.get("key_rule_facts", [])),
		"quick_effect_compact": snapshot.get("quick_effect_compact", ""),
		"detail_tooltip": snapshot.get("detail_tooltip", ""),
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
	_primary_card_id = ""
	_interaction_card_id = ""
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
