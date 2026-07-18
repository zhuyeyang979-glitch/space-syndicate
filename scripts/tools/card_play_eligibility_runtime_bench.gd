extends Control
class_name CardPlayEligibilityRuntimeBench

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const SERVICE_SCENE_PATH := "res://scenes/runtime/CardPlayEligibilityRuntimeService.tscn"
const BRIDGE_SCENE_PATH := "res://scenes/runtime/CardPlayEligibilityWorldBridge.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const OUTPUT_DIR := "user://space_syndicate_design_qa/card_play_eligibility/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/card_play_eligibility_sprint_43.png"

const LEGACY_FUNCTIONS := [
	"_hand_card_play_state", "_can_play_skill_now", "_skill_play_requirement_profile",
	"_skill_play_requirement_status", "_skill_play_requirement_text",
	"_skill_play_requirement_chip_text", "_skill_play_region_share_required",
	"_skill_play_region_scope", "_skill_play_requirement_district",
	"_skill_play_cash_cost", "_skill_targets_monster", "_skill_targets_player",
	"_skill_requires_target_monster", "_skill_requires_target_player",
	"_is_direct_monster_skill_kind", "_is_counter_skill",
	"_skill_is_counterable_player_interaction", "_can_convert_monster_card_to_counter",
	"_card_play_requirement_audit",
]

@export var auto_run := true

@onready var runtime_main_host: Control = %RuntimeMainHost
@onready var summary_label: Label = %SummaryLabel
@onready var status_label: Label = %StatusLabel
@onready var ownership_text: RichTextLabel = %OwnershipText
@onready var results_text: RichTextLabel = %ResultsText

var _runtime_main: Control = null
var _records: Array = []
var _failures: Array[String] = []


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_eligibility_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func eligibility_cases() -> Array:
	return [
		"service_scene_composition", "world_bridge_scene_composition", "coordinator_api_contract",
		"invalid_player", "bankrupt_player", "game_over", "already_queued",
		"pending_monster_target", "pending_player_target", "forced_decision", "monster_wager",
		"player_cooldown", "card_cooldown", "card_lock",
		"starter_missing_district", "starter_destroyed_district", "starter_ready",
		"gdp_share_insufficient", "gdp_share_satisfied", "cash_insufficient",
		"contract_invalid", "contract_valid", "city_development_invalid", "city_development_valid",
		"military_unit_missing", "military_unit_cooldown", "military_deployment_invalid",
		"monster_target_unavailable", "monster_target_ready", "player_target_ready",
		"counter_window_closed", "counter_target_invalid", "counter_window_open",
		"monster_counter_conversion", "organize_phase_metadata", "lock_phase_metadata",
		"group_full_metadata", "active_resolution_metadata", "ai_ui_coach_execution_parity",
		"stable_reason_code", "presentation_mapping", "pure_data_payloads", "privacy_boundary",
		"legacy_algorithms_absent", "main_deletion_gate", "no_parallel_eligibility_owner",
	]


func build_eligibility_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_id_variant in eligibility_cases():
		records.append(_record(str(case_id_variant), {}, false, "preview"))
	return {
		"suite": "card-play-eligibility-runtime-cutover-v04",
		"ruleset_id": "v0.4",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"case_count": records.size(),
		"passed_count": 0,
		"records": records,
	}


func run_eligibility_suite() -> void:
	_records.clear()
	_failures.clear()
	_prepare_output_dir()
	if not await _ensure_runtime_main():
		push_error("CardPlayEligibilityRuntimeBench could not instantiate real main.tscn")
		if DisplayServer.get_name() == "headless":
			get_tree().quit(1)
		return
	for case_id_variant in eligibility_cases():
		var case_id := str(case_id_variant)
		var result := _run_case(case_id)
		result["pure_data_checked"] = bool(result.get("pure_data_checked", false)) and _is_data_only(result)
		_records.append(result)
		if not bool(result.get("passed", false)):
			_failures.append("%s: %s" % [case_id, str(result.get("notes", "failed"))])
	var manifest := {
		"suite": "card-play-eligibility-runtime-cutover-v04",
		"ruleset_id": "v0.4",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"case_count": _records.size(),
		"passed_count": _passed_count(),
		"records": _records.duplicate(true),
	}
	_write_text(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text(REPORT_PATH, _markdown_report(manifest))
	_update_ui(manifest)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_screenshot()
	print("CardPlayEligibilityRuntimeBench manifest: %s" % MANIFEST_PATH)
	print("CardPlayEligibilityRuntimeBench report: %s" % REPORT_PATH)
	print("CardPlayEligibilityRuntimeBench screenshot: %s" % SCREENSHOT_PATH)
	print("CardPlayEligibilityRuntimeBench passed: %d/%d" % [_passed_count(), _records.size()])
	if not _failures.is_empty():
		push_error("CardPlayEligibilityRuntimeBench failed:\n- %s" % "\n- ".join(_failures))
	if DisplayServer.get_name() == "headless":
		_release_runtime_main()
		await get_tree().process_frame
		get_tree().quit(0 if _failures.is_empty() else 1)


func run_suite() -> void:
	run_eligibility_suite()


func _run_case(case_id: String) -> Dictionary:
	match case_id:
		"service_scene_composition":
			return _scene_case(case_id, SERVICE_SCENE_PATH, "CardPlayEligibilityRuntimeService", ["evaluate_play", "evaluate_hand", "requirement_status", "target_status", "debug_snapshot"])
		"world_bridge_scene_composition":
			return _scene_case(case_id, BRIDGE_SCENE_PATH, "CardPlayEligibilityWorldBridge", ["build_facts", "debug_snapshot"])
		"coordinator_api_contract":
			return _coordinator_api_case()
		"ai_ui_coach_execution_parity":
			return _parity_case()
		"stable_reason_code":
			return _stable_reason_case()
		"presentation_mapping":
			return _presentation_case()
		"pure_data_payloads":
			return _pure_data_case()
		"privacy_boundary":
			return _privacy_case()
		"legacy_algorithms_absent":
			return _legacy_absent_case()
		"main_deletion_gate":
			return _main_deletion_case()
		"no_parallel_eligibility_owner":
			return _single_owner_case()
	var spec := _behavior_spec(case_id)
	return _behavior_case(case_id, spec)


func _behavior_spec(case_id: String) -> Dictionary:
	var specs := {
		"invalid_player": {"facts": {"player_valid": false}, "reason": "invalid_player", "allowed": false},
		"bankrupt_player": {"facts": {"player_eliminated": true}, "reason": "player_eliminated", "allowed": false},
		"game_over": {"mode": "hand", "facts": {"game_over": true}, "reason": "game_over", "allowed": false},
		"already_queued": {"mode": "hand", "skill": {"queued_for_resolution": true}, "reason": "already_queued", "allowed": false},
		"pending_monster_target": {"mode": "hand", "facts": {"pending_target_choice": true}, "reason": "pending_target_choice", "allowed": false},
		"pending_player_target": {"mode": "hand", "facts": {"pending_target_choice": true}, "reason": "pending_target_choice", "allowed": false},
		"forced_decision": {"mode": "hand", "facts": {"forced_decision_pending": true}, "reason": "forced_decision_pending", "allowed": false},
		"monster_wager": {"mode": "hand", "facts": {"monster_wager_freeze": true}, "reason": "monster_wager_freeze", "allowed": false},
		"player_cooldown": {"mode": "hand", "facts": {"player_action_cooldown": 2.5}, "reason": "player_action_cooldown", "allowed": false},
		"card_cooldown": {"mode": "hand", "skill": {"cooldown_left": 3.0}, "reason": "card_cooldown", "allowed": false},
		"card_lock": {"mode": "hand", "skill": {"lock_left": 4.0}, "reason": "card_locked", "allowed": false},
		"starter_missing_district": {"mode": "hand", "skill_kind": "monster_card", "skill": {"starter_play_free": true}, "facts": {"selected_district_valid": false}, "reason": "starter_district_missing", "allowed": false},
		"starter_destroyed_district": {"mode": "hand", "skill_kind": "monster_card", "skill": {"starter_play_free": true}, "facts": {"selected_district_destroyed": true}, "reason": "starter_district_destroyed", "allowed": false},
		"starter_ready": {"mode": "hand", "skill_kind": "monster_card", "skill": {"starter_play_free": true}, "reason": "starter_ready", "allowed": true},
		"gdp_share_insufficient": {"skill_id": "城市融资2", "facts": {"share_basis_points_by_district": {"0": 0}}, "reason": "gdp_share_insufficient", "allowed": false},
		"gdp_share_satisfied": {"skill_id": "城市融资2", "facts": {"share_basis_points_by_district": {"0": 10000}}, "reason": "playable", "allowed": true},
		"cash_insufficient": {"skill": {"play_cash": 120}, "facts": {"player_cash": 20}, "reason": "cash_insufficient", "allowed": false},
		"contract_invalid": {"mode": "hand", "skill_kind": "area_trade_contract", "facts": {"contract_error": "合约端点无效"}, "reason": "contract_invalid", "allowed": false},
		"contract_valid": {"mode": "hand", "skill_kind": "area_trade_contract", "reason": "playable", "allowed": true},
		"city_development_invalid": {"mode": "hand", "skill_kind": "city_development", "facts": {"city_development_error": "目标没有商品项目"}, "reason": "city_development_invalid", "allowed": false},
		"city_development_valid": {"mode": "hand", "skill_kind": "city_development", "reason": "playable", "allowed": true},
		"military_unit_missing": {"skill_kind": "military_command", "facts": {"military_unit_present": false}, "reason": "military_unit_missing", "allowed": false},
		"military_unit_cooldown": {"skill_kind": "military_command", "facts": {"military_unit_cooldown": 3.0}, "reason": "military_unit_cooldown", "allowed": false},
		"military_deployment_invalid": {"skill_kind": "military_force", "facts": {"military_deployment_valid": false}, "reason": "military_deployment_invalid", "allowed": false},
		"monster_target_unavailable": {"mode": "hand", "skill_kind": "monster_target", "facts": {"monster_count": 0}, "reason": "monster_target_unavailable", "allowed": false},
		"monster_target_ready": {"mode": "hand", "skill_kind": "monster_target", "reason": "needs_monster_target", "allowed": true},
		"player_target_ready": {"mode": "hand", "skill_id": "星链拆解1", "reason": "needs_player_target", "allowed": true},
		"counter_window_closed": {"mode": "hand", "skill_id": "相位否决1", "facts": {"counter_window_active": false}, "reason": "counter_window_closed", "allowed": false},
		"counter_target_invalid": {"mode": "hand", "skill_id": "相位否决1", "facts": {"counter_window_active": true, "active_resolution_present": true, "active_skill_counterable": false}, "reason": "counter_target_invalid", "allowed": false},
		"counter_window_open": {"mode": "hand", "skill_id": "相位否决1", "facts": {"counter_window_active": true, "active_resolution_present": true, "active_skill_counterable": true}, "reason": "playable", "allowed": true},
		"monster_counter_conversion": {"mode": "hand", "skill_kind": "monster_card", "facts": {"role_can_convert_monster_to_counter": true, "counter_window_active": true, "active_resolution_present": true, "active_skill_counterable": true}, "reason": "counter_conversion_ready", "allowed": true},
		"organize_phase_metadata": {"queue": {"batch_locked": false, "active_present": false, "current_count": 1, "routes_to_next_batch": false}, "reason": "playable", "allowed": true},
		"lock_phase_metadata": {"queue": {"batch_locked": true, "active_present": false, "current_count": 1, "routes_to_next_batch": true}, "reason": "playable", "allowed": true},
		"group_full_metadata": {"queue": {"batch_locked": false, "active_present": false, "current_count": 3, "group_count": 3, "group_limit": 3}, "reason": "playable", "allowed": true},
		"active_resolution_metadata": {"queue": {"batch_locked": false, "active_present": true, "current_count": 0, "routes_to_next_batch": true}, "reason": "playable", "allowed": true},
	}
	return (specs.get(case_id, {}) as Dictionary).duplicate(true)


func _behavior_case(case_id: String, spec: Dictionary) -> Dictionary:
	var skill := _skill_for_spec(spec)
	var mode := str(spec.get("mode", "rule"))
	var facts := _base_facts(skill)
	_merge(facts, spec.get("facts", {}) as Dictionary)
	if spec.has("queue"):
		facts["queue_preflight"] = (spec.get("queue", {}) as Dictionary).duplicate(true)
	_merge(skill, spec.get("skill", {}) as Dictionary)
	var result := _evaluate(skill, facts, mode)
	var expected_reason := str(spec.get("reason", "playable"))
	var expected_allowed := bool(spec.get("allowed", true))
	var queue_checked: bool = not spec.has("queue") or (result.get("queue_preflight", {}) as Dictionary) == facts.get("queue_preflight", {})
	var passed: bool = not skill.is_empty() and str(result.get("reason_code", "")) == expected_reason and bool(result.get("allowed", false)) == expected_allowed and queue_checked
	return _record(case_id, result, passed, "expected %s/%s" % [expected_reason, expected_allowed], {
		"requirement_checked": result.get("requirement_status", {}) is Dictionary,
		"target_checked": result.get("target_status", {}) is Dictionary,
		"queue_preflight_checked": queue_checked,
	})


func _scene_case(case_id: String, scene_path: String, node_name: String, methods: Array) -> Dictionary:
	var packed := load(scene_path) as PackedScene
	var node := _coordinator().get_node_or_null(node_name) if _coordinator() != null else null
	var passed := packed != null and node != null and node.scene_file_path == scene_path
	for method_variant in methods:
		passed = passed and node != null and node.has_method(str(method_variant))
	var debug: Dictionary = node.call("debug_snapshot") if node != null and node.has_method("debug_snapshot") else {}
	passed = passed and _is_data_only(debug)
	return _record(case_id, debug, passed, "%s is a static editable Coordinator child" % node_name, {"service_checked": node != null})


func _coordinator_api_case() -> Dictionary:
	var coordinator := _coordinator()
	var methods := ["card_play_world_facts", "evaluate_card_play", "evaluate_card_hand", "card_play_requirement_status", "card_play_target_status", "compose_card_play_eligibility"]
	var passed := coordinator != null
	for method_variant in methods:
		passed = passed and coordinator != null and coordinator.has_method(str(method_variant))
	return _record("coordinator_api_contract", {"methods": methods}, passed, "Coordinator exposes one pure-data eligibility route", {"service_checked": true})


func _parity_case() -> Dictionary:
	var skill := _skill_for_spec({"skill_id": "城市融资2"})
	var facts := _base_facts(skill)
	facts["share_basis_points_by_district"] = {"0": 0}
	var direct := _evaluate(skill, facts, "rule")
	var via_main_variant: Variant = _runtime_main.call("_card_play_eligibility_snapshot", 0, skill, "rule", {})
	var via_main: Dictionary = via_main_variant if via_main_variant is Dictionary else {}
	var main_source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var ai_source := FileAccess.get_file_as_string("res://scripts/runtime/ai_runtime_controller.gd")
	var execution_source := FileAccess.get_file_as_string("res://scripts/runtime/card_resolution_execution_world_bridge.gd")
	var routed := ai_source.contains("_card_play_eligibility_snapshot") and execution_source.contains("_authorize_card_play") and main_source.contains("_card_play_eligibility_snapshot(player_index, skill, \"hand\")")
	var passed := str(direct.get("reason_code", "")) == "gdp_share_insufficient" and not via_main.is_empty() and routed
	return _record("ai_ui_coach_execution_parity", direct, passed, "AI, UI/Coach, Queue and Execution route through Coordinator eligibility", {"parity_checked": routed})


func _stable_reason_case() -> Dictionary:
	var skill := _skill_for_spec({"skill_id": "城市融资2"})
	var facts := _base_facts(skill)
	facts["share_basis_points_by_district"] = {"0": 0}
	var first := _evaluate(skill, facts, "rule")
	var second := _evaluate(skill, facts, "rule")
	var passed := str(first.get("reason_code", "")) == "gdp_share_insufficient" and first == second
	return _record("stable_reason_code", first, passed, "identical requests return an identical stable reason envelope", {"parity_checked": passed})


func _presentation_case() -> Dictionary:
	var skill := _skill_for_spec({"skill_id": "城市融资2"})
	var facts := _base_facts(skill)
	facts["share_basis_points_by_district"] = {"0": 0}
	var result := _evaluate(skill, facts, "rule")
	var presentation_variant: Variant = _coordinator().call("compose_card_play_eligibility", result, {"card_name": str(skill.get("name", "卡牌")), "display_name": str(skill.get("name", "卡牌"))})
	var presentation: Dictionary = presentation_variant if presentation_variant is Dictionary else {}
	var passed := str(presentation.get("reason_code", "")) == "gdp_share_insufficient" and str(presentation.get("label", "")) == "需份额" and not str(presentation.get("detail", "")).is_empty()
	return _record("presentation_mapping", result, passed, "CardPresentation maps reason_code without deciding legality", {"presentation_checked": passed})


func _pure_data_case() -> Dictionary:
	var skill := _skill_for_spec({})
	var facts := _base_facts(skill)
	var result := _evaluate(skill, facts, "hand")
	var debug: Dictionary = _service().call("debug_snapshot") if _service() != null else {}
	var passed := _is_data_only(facts) and _is_data_only(result) and _is_data_only(debug)
	return _record("pure_data_payloads", result, passed, "facts, eligibility and debug snapshots contain data only", {"pure_data_checked": passed})


func _privacy_case() -> Dictionary:
	var result := _evaluate(_skill_for_spec({"skill_id": "星链拆解1"}), _base_facts(_skill_for_spec({"skill_id": "星链拆解1"})), "hand")
	var encoded := JSON.stringify(result)
	var passed := not encoded.contains("hidden_owner") and not encoded.contains("private_target") and not encoded.contains("private_discard") and not encoded.contains("ai_private")
	return _record("privacy_boundary", result, passed, "eligibility output contains no hidden owner or private-plan fields", {"privacy_checked": passed})


func _legacy_absent_case() -> Dictionary:
	var source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var absent := true
	for name_variant in LEGACY_FUNCTIONS:
		absent = absent and not source.contains("func %s(" % str(name_variant))
	return _record("legacy_algorithms_absent", {"retired_count": LEGACY_FUNCTIONS.size()}, absent, "all legacy eligibility/target functions are deleted", {"legacy_absent": absent})


func _main_deletion_case() -> Dictionary:
	var source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var nonblank := 0
	var function_count := 0
	for line_variant in source.split("\n"):
		var line := str(line_variant)
		if not line.strip_edges().is_empty():
			nonblank += 1
		if line.begins_with("func "):
			function_count += 1
	var passed := nonblank <= 28525 and function_count <= 1641
	return _record("main_deletion_gate", {"nonblank_lines": nonblank, "function_count": function_count}, passed, "main.gd meets the Sprint 43 hard deletion ceiling", {"legacy_absent": passed})


func _single_owner_case() -> Dictionary:
	var main_source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var service_debug: Dictionary = _service().call("debug_snapshot") if _service() != null else {}
	var adapter_count := main_source.count("func _card_play_") + main_source.count("func _authorize_card_play") + main_source.count("func _log_card_play_rejection")
	var passed := bool(service_debug.get("service_authoritative", false)) and not bool(service_debug.get("legacy_main_fallback_active", true)) and adapter_count <= 7
	return _record("no_parallel_eligibility_owner", {"adapter_function_count": adapter_count, "service": service_debug}, passed, "main keeps only a narrow world/action adapter surface", {"service_checked": passed, "legacy_absent": passed})


func _base_facts(skill: Dictionary) -> Dictionary:
	var coordinator := _coordinator()
	var value: Variant = coordinator.call("card_play_world_facts", 0, skill, {"selected_district": 0}) if coordinator != null else {}
	var facts: Dictionary = value if value is Dictionary else {}
	_merge(facts, {
		"player_valid": true, "player_count": 4, "monster_count": 1,
		"player_name": "玩家1", "player_eliminated": false, "player_cash": 5000,
		"player_action_cooldown": 0.0, "game_over": false,
		"selected_district": 0, "selected_district_valid": true,
		"selected_district_destroyed": false, "selected_district_name": "测试区域",
		"contract_source_district": 0, "contract_share_discount_percent": 0,
		"best_share_district": 0, "share_basis_points_by_district": {"0": 10000},
		"pending_target_choice": false, "monster_wager_freeze": false,
		"forced_decision_pending": false, "role_can_convert_monster_to_counter": false,
		"counter_window_active": false, "active_resolution_present": false,
		"active_skill_counterable": true, "contract_error": "", "city_development_error": "",
		"military_unit_present": true, "military_unit_cooldown": 0.0,
		"military_deployment_valid": true, "military_deploy_terrain_label": "陆地区域",
		"desired_bid_cents": 0, "player_cash_cents": 200000, "queue_preflight": {"batch_locked": false, "active_present": false, "current_count": 0, "next_count": 0, "routes_to_next_batch": false},
		"default_monster_play_cash_per_existing": 100,
	})
	return facts


func _skill_for_spec(spec: Dictionary) -> Dictionary:
	var skill_id := str(spec.get("skill_id", "城市融资1"))
	var skill_kind := str(spec.get("skill_kind", ""))
	if skill_kind == "monster_target":
		for candidate_kind in ["monster_lure", "special_monster_delay", "mudslide", "monster_takeover", "attack"]:
			var candidate := _real_skill_for_kind(candidate_kind)
			if not candidate.is_empty():
				return candidate
	if skill_kind != "":
		var by_kind := _real_skill_for_kind(skill_kind)
		if not by_kind.is_empty():
			return by_kind
	var value: Variant = _runtime_main.call("_make_skill", skill_id)
	var skill: Dictionary = value if value is Dictionary else {}
	if skill.is_empty():
		skill = {"name": skill_id, "kind": "cash_gain", "rank": 1}
	if skill_kind == "monster_target":
		skill["kind"] = "monster_lure"
	elif skill_kind != "":
		skill["kind"] = skill_kind
	return skill.duplicate(true)


func _real_skill_for_kind(kind: String) -> Dictionary:
	var names_variant: Variant = (_runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") as GameRuntimeCoordinator).card_runtime_catalog_service().ordered_card_ids()
	var names: Array = names_variant if names_variant is Array else []
	for name_variant in names:
		var value: Variant = _runtime_main.call("_make_skill", str(name_variant))
		if value is Dictionary and str((value as Dictionary).get("kind", "")) == kind:
			return (value as Dictionary).duplicate(true)
	return {}


func _evaluate(skill: Dictionary, facts: Dictionary, mode: String) -> Dictionary:
	var coordinator := _coordinator()
	var value: Variant = coordinator.call("evaluate_card_play", {"player_index": 0, "skill": skill, "evaluation_mode": mode}, facts) if coordinator != null else {}
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _coordinator() -> Node:
	return _runtime_main.get_node_or_null("RuntimeServices/RuntimeControllerHost/GameRuntimeCoordinator") if _runtime_main != null else null


func _service() -> Node:
	return _coordinator().get_node_or_null("CardPlayEligibilityRuntimeService") if _coordinator() != null else null


func _ensure_runtime_main() -> bool:
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_runtime_main = packed.instantiate() as Control if packed != null else null
	if _runtime_main == null:
		return false
	_runtime_main.visible = false
	runtime_main_host.add_child(_runtime_main)
	await get_tree().process_frame
	await get_tree().process_frame
	if _runtime_main.has_method("_new_game"):
		_runtime_main.set("configured_player_count", 4)
		_runtime_main.set("configured_ai_player_count", 3)
		_runtime_main.call("_new_game")
		await get_tree().process_frame
	return _coordinator() != null and _service() != null


func _release_runtime_main() -> void:
	if _runtime_main != null and is_instance_valid(_runtime_main):
		_runtime_main.queue_free()
	_runtime_main = null


func _record(case_id: String, result: Dictionary, passed: bool, notes: String, flags: Dictionary = {}) -> Dictionary:
	var record := {
		"case_id": case_id,
		"reason_code": str(result.get("reason_code", "")),
		"allowed": bool(result.get("allowed", false)),
		"requirement_checked": false,
		"target_checked": false,
		"queue_preflight_checked": false,
		"presentation_checked": false,
		"parity_checked": false,
		"service_checked": false,
		"privacy_checked": false,
		"pure_data_checked": _is_data_only(result),
		"legacy_absent": false,
		"passed": passed,
		"notes": notes,
	}
	for key_variant in flags.keys():
		record[key_variant] = flags[key_variant]
	return record


func _merge(target: Dictionary, values: Dictionary) -> void:
	for key_variant in values.keys():
		target[key_variant] = values[key_variant]


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write %s" % path)
		return
	file.store_string(text)


func _markdown_report(manifest: Dictionary) -> String:
	var lines := [
		"# Card Play Eligibility Runtime Cutover",
		"",
		"- Ruleset: v0.4",
		"- Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("case_count", 0))],
		"- Owner: CardPlayEligibilityRuntimeService",
		"- World facts: CardPlayEligibilityWorldBridge",
		"",
		"| Case | Reason | Allowed | Result |",
		"| --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record := record_variant as Dictionary
		lines.append("| %s | %s | %s | %s |" % [str(record.get("case_id", "")), str(record.get("reason_code", "-")), str(record.get("allowed", false)), "PASS" if bool(record.get("passed", false)) else "FAIL"])
	return "\n".join(lines) + "\n"


func _update_ui(manifest: Dictionary) -> void:
	var passed := int(manifest.get("passed_count", 0))
	var total := int(manifest.get("case_count", 0))
	status_label.text = "PASS" if passed == total else "FAIL"
	summary_label.text = "%d / %d eligibility cases" % [passed, total]
	ownership_text.text = "[b]AUTHORITATIVE[/b]\nCardPlayEligibilityRuntimeService\n\n[b]FACT BRIDGE[/b]\nCardPlayEligibilityWorldBridge\n\n[b]PRESENTATION[/b]\nCardPresentationRuntimeService\n\nQueue and Execution retain their narrow transaction boundaries."
	var lines: Array[String] = []
	for record_variant in _records:
		var record := record_variant as Dictionary
		lines.append("[color=%s]%s[/color]  %s" % ["#6ee7b7" if bool(record.get("passed", false)) else "#fb7185", "PASS" if bool(record.get("passed", false)) else "FAIL", str(record.get("case_id", ""))])
	results_text.text = "\n".join(lines)


func _save_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(ProjectSettings.globalize_path(SCREENSHOT_PATH))


func _passed_count() -> int:
	var count := 0
	for record_variant in _records:
		if bool((record_variant as Dictionary).get("passed", false)):
			count += 1
	return count


func _is_data_only(value: Variant) -> bool:
	if value == null or value is String or value is StringName or value is bool or value is int or value is float:
		return true
	if value is Array:
		for child in value:
			if not _is_data_only(child):
				return false
		return true
	if value is Dictionary:
		for key_variant in value.keys():
			if not _is_data_only(key_variant) or not _is_data_only(value[key_variant]):
				return false
		return true
	return false
