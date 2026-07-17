extends SceneTree

const BASELINE_PATH := "res://docs/migration/main_gd_budget_baseline.json"
const LEDGER_PATH := "res://docs/migration/main_gd_cutover_ledger.json"
const MAIN_PATH := "res://scripts/main.gd"
const VALID_STATUSES := ["pending", "migrating", "cut_over", "blocked"]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var baseline := _json(BASELINE_PATH)
	var ledger := _json(LEDGER_PATH)
	_expect(not baseline.is_empty(), "main budget baseline loads")
	_expect(not ledger.is_empty(), "main cutover ledger loads")
	_expect(
		str(baseline.get("baseline_commit", "")) == "689c77af4867e2f85fc1edf356e1f7abb295bc7a",
		"budget baseline is pinned to onboarding-purge commit"
	)

	var main_source := FileAccess.get_file_as_string(MAIN_PATH) if FileAccess.file_exists(MAIN_PATH) else ""
	var metrics := _main_metrics(main_source)
	_expect(not main_source.contains("func _on_victory_outcome_applied") and not main_source.contains("var log_lines"), "Main owns neither victory presentation nor public log storage")
	_expect(not main_source.contains("func _city_markers_for_selected_player") and not main_source.contains("func _auto_monster_markers"), "Main no longer assembles public map markers")
	_expect(not main_source.contains("_card_resolution_presentation_source") and not main_source.contains("_card_resolution_presentation_snapshot"), "Main no longer owns card-resolution presentation source or snapshot methods")
	var contract_bridge_source := FileAccess.get_file_as_string("res://scripts/runtime/contract_runtime_world_bridge.gd")
	_expect(not contract_bridge_source.contains("_pulse_district") and not contract_bridge_source.contains("_add_action_callout"), "ContractRuntimeWorldBridge has no presentation callback to Main")
	var victory_bridge_source := FileAccess.get_file_as_string("res://scripts/runtime/victory_control_world_bridge.gd")
	_expect(not victory_bridge_source.contains("apply_outcome_receipt") and not victory_bridge_source.contains("_on_victory_outcome_applied"), "victory fact bridge has no Main presentation callback")
	var baseline_metrics: Dictionary = baseline.get("main", {})
	for key in [
		"physical_lines",
		"nonblank_lines",
		"methods",
		"top_level_variables",
		"constants",
		"signals",
		"top_level_preloads",
	]:
		_expect(
			int(metrics.get(key, 0)) <= int(baseline_metrics.get(key, 0)),
			"main budget does not increase: %s" % key
		)

	var domains: Array = ledger.get("domains", []) if ledger.get("domains", []) is Array else []
	_expect(domains.size() >= 10, "ledger covers every extinction domain")
	var names: Array[String] = []
	for domain_variant in domains:
		var domain: Dictionary = domain_variant
		var name := str(domain.get("domain", ""))
		var status := str(domain.get("status", ""))
		_expect(name != "" and not names.has(name), "ledger domain names are unique")
		_expect(VALID_STATUSES.has(status), "ledger status is valid: %s" % name)
		if status == "cut_over":
			_expect(bool(domain.get("old_path_deleted", false)), "cut-over domain deleted old path: %s" % name)
			_expect(bool(domain.get("duplicate_execution_checked", false)), "cut-over domain checked duplicates: %s" % name)
		names.append(name)

	var agents := FileAccess.get_file_as_string("res://AGENTS.md")
	_expect(agents.contains("## main.gd Extinction Policy"), "AGENTS carries permanent main extinction policy")
	_expect(
		agents.contains("No production task may") and agents.contains("monotonically reduce"),
		"AGENTS policy freezes new Main ownership and requires monotonic reduction"
	)
	_finish()


func _json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _main_metrics(source: String) -> Dictionary:
	var lines := source.split("\n", false)
	var nonblank := 0
	var methods := 0
	var variables := 0
	var constants := 0
	var signals := 0
	var preloads := 0
	for line_variant in lines:
		var line := str(line_variant)
		if line.strip_edges() != "":
			nonblank += 1
		if line.begins_with("func "):
			methods += 1
		elif line.begins_with("var "):
			variables += 1
		elif line.begins_with("const "):
			constants += 1
			if line.contains("preload("):
				preloads += 1
		elif line.begins_with("signal "):
			signals += 1
	return {
		"physical_lines": lines.size(),
		"nonblank_lines": nonblank,
		"methods": methods,
		"top_level_variables": variables,
		"constants": constants,
		"signals": signals,
		"top_level_preloads": preloads,
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Main.gd architecture gate passed (%d checks)." % _checks)
		quit(0)
		return
	push_error("Main.gd architecture gate failed:\n- " + "\n- ".join(_failures))
	quit(1)
