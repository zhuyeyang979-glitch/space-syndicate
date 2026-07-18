extends Node

const RestoreDependencyContract := preload("res://scripts/runtime/card_history_restore_dependency_contract.gd")
const EXPECTED_ORDER := [
	"ruleset", "region_infrastructure", "region_supply", "commodity_flow", "routes",
	"player_mana", "commodity_belt_visibility", "card_inventory", "player_organization",
	"monsters", "military", "weather", "card_resolution_queue", "card_resolution_execution",
	"card_resolution_history", "ai", "bankruptcy_neutral_estate", "victory_control", "session",
]

@export var auto_run := true
var checks := 0
var failures: Array[String] = []


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("_run_from_scene")


func _run_from_scene() -> void:
	var result := run_bench()
	print("CARD_RESOLUTION_HISTORY_SAVE_OWNER_BENCH|status=%s|checks=%d|failures=%d|details=%s" % [
		"PASS" if bool(result.get("passed", false)) else "FAIL",
		int(result.get("checks", 0)),
		int(result.get("failure_count", 0)),
		JSON.stringify(result.get("failures", [])),
	])
	get_tree().quit(0 if bool(result.get("passed", false)) else 1)


func run_bench() -> Dictionary:
	checks = 0
	failures.clear()
	var coordinator := get_node_or_null("GameRuntimeCoordinator")
	var service := get_node_or_null("GameRuntimeCoordinator/CardResolutionHistoryRuntimeService")
	var execution := get_node_or_null("GameRuntimeCoordinator/CardResolutionExecutionRuntimeService")
	var session := get_node_or_null("GameRuntimeCoordinator/GameSessionRuntimeController")
	var registry := get_node_or_null("GameRuntimeCoordinator/GameSessionRuntimeController/V06SaveOwnerRegistry")
	_check(coordinator != null and service != null and execution != null and session != null and registry != null, "production Coordinator wires history, execution, session, and registry")
	if service != null:
		service.configure({"history_limit": 3})
		var appended: Dictionary = service.append_resolved({
			"resolution_id": 91,
			"player_index": 2,
			"skill": {"name": "相位否决", "kind": "card_counter", "hidden_owner": "retired"},
			"ai_plan": "private",
			"public_owner_revealed": false,
			"guessers": [1],
		})
		_check(bool(appended.get("appended", false)), "resolution appends")
		_check(bool(service.append_resolved({"resolution_id": 91}).get("duplicate", false)), "duplicate is rejected")
		var public_history: Array = service.public_history_snapshot()
		_check(not JSON.stringify(public_history).contains("player_index"), "public projection hides actor")
		_check(service.private_viewer_snapshot(0) == public_history and service.private_viewer_snapshot(3) == public_history, "viewer projections remain public and byte-equivalent")
		_check(not bool(service.patch_entry(91, {"public_owner_label": "归属：玩家3"}).get("patched", true)), "retired owner reveal patch fails closed")
		var saved: Dictionary = service.to_save_data()
		var before_preflight: Dictionary = service.to_save_data()
		var preflight: Dictionary = service.preflight_save_data(saved)
		_check(bool(preflight.get("accepted", false)) and service.to_save_data() == before_preflight, "pure save preflight accepts without live mutation")
		_check(saved.keys().size() == 5 and saved.has("schema") and saved.has("history_limit") and saved.has("history") and saved.has("appended_resolution_ids") and saved.has("revision"), "save uses the exact five-field schema")
		_check(not JSON.stringify(saved).contains("guessers") and not JSON.stringify(saved).contains("public_owner_") and not JSON.stringify(saved).contains("private"), "save omits retired and private history fields")
		var dependency: Dictionary = RestoreDependencyContract.validate_annotation_dependency({"annotations_by_viewer": {"0": {"card-history:91": {"subscribed": true}}}}, saved)
		_check(bool(dependency.get("accepted", false)) and dependency.get("history_entry_ids", []) == ["card-history:91"], "pure dependency contract resolves stable public history IDs")
		service.reset_state()
		_check(bool(service.apply_save_data(saved).get("applied", false)) and service.to_save_data() == saved, "save roundtrip is exact")
		var invalid := saved.duplicate(true)
		(invalid.get("history", []) as Array)[0]["owner_truth"] = 2
		var before_invalid: Dictionary = service.to_save_data()
		_check(not bool(service.preflight_save_data(invalid).get("accepted", true)) and service.to_save_data() == before_invalid, "private import fails closed without mutation")
	if registry != null:
		var snapshot: Dictionary = registry.registry_snapshot()
		_check(registry.fixed_section_order() == EXPECTED_ORDER and EXPECTED_ORDER[-1] == "session", "production registry uses the fixed 19-owner order with session last")
		_check(int(snapshot.get("required_section_count", 0)) == 19 and int(snapshot.get("transactional_section_count", 0)) == 12 and int(snapshot.get("unsupported_section_count", 0)) == 7 and not bool(snapshot.get("resume_ready", true)), "production registry exposes the 12/7 fail-closed capability boundary")
		_check(_history_binding_valid(registry), "production registry binds history once with pure preflight and transactional rollback")
	if execution != null and session != null:
		_check(not execution.to_save_data().has("history") and not execution.to_save_data().has("card_resolution_history"), "execution save owns no history payload")
		_check(not session.to_save_data().has("history") and not session.to_save_data().has("card_resolution_history"), "session save owns no history payload")
	var result := {"passed": failures.is_empty(), "checks": checks, "failure_count": failures.size(), "failures": failures.duplicate()}
	print("CardResolutionHistoryRuntimeServiceBench: %s %d/%d" % ["PASS" if failures.is_empty() else "FAIL", checks - failures.size(), checks])
	if not failures.is_empty():
		push_error("CardResolutionHistoryRuntimeServiceBench failures:\n- " + "\n- ".join(failures))
	return result


func _history_binding_valid(registry: Node) -> bool:
	var matches := 0
	for binding in registry.bindings:
		if binding == null or binding.section_id != "card_resolution_history":
			continue
		matches += 1
		if binding.owner_id != "card_resolution_history" \
			or str(binding.owner_path) != "../../CardResolutionHistoryRuntimeService" \
			or binding.capture_method != "to_save_data" \
			or binding.preflight_method != "preflight_save_data" \
			or binding.apply_method != "apply_save_data" \
			or binding.rollback_method != "apply_save_data" \
			or binding.restore_mode != "transactional":
			return false
	return matches == 1


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
