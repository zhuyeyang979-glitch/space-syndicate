extends SceneTree

const INVENTORY_PATH := "res://docs/migration/v07_right_inspector_responsibility_inventory.json"

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var inventory := _load_inventory()
	_expect(not inventory.is_empty(), "machine-readable RightInspector inventory loads")
	_expect(str(inventory.get("status", "")) == "AUDIT_GREEN_PRODUCTION_CUTOVER_NOT_EXECUTED", "inventory distinguishes audit green from production cutover")
	_expect(bool(inventory.get("pr69_terminal_gate_green", false)), "PR69 terminal prerequisite is recorded green")
	_expect(str(inventory.get("pr69_prerequisite_evidence_mode", "")) == "REMOTE_SIBLING_BRANCH_NOT_GIT_ANCESTOR", "PR69 is recorded as an external sibling-branch prerequisite")
	_expect(not bool(inventory.get("pr69_is_lane_b_git_ancestor", true)), "inventory does not falsely claim PR69 is a Lane B ancestor")
	_expect(not bool(inventory.get("production_presentation_shell_cutover_complete", true)), "production shell cutover remains false")
	var responsibilities: Array = inventory.get("responsibilities", []) if inventory.get("responsibilities", []) is Array else []
	_expect(int(inventory.get("right_inspector_responsibility_count_before", -1)) == 10 and responsibilities.size() == 10, "all ten fixed-inspector responsibilities are enumerated")
	var ids: Array[String] = []
	for row_variant in responsibilities:
		var row: Dictionary = row_variant if row_variant is Dictionary else {}
		var responsibility_id := str(row.get("id", ""))
		_expect(not responsibility_id.is_empty() and responsibility_id not in ids, "responsibility id is present and unique: %s" % responsibility_id)
		ids.append(responsibility_id)
		_expect(not str(row.get("current_consumer", "")).is_empty(), "%s records its current consumer" % responsibility_id)
		_expect(not str(row.get("replacement", "")).is_empty(), "%s records its replacement target" % responsibility_id)
		_expect(not str(row.get("typed_api_status", "")).is_empty(), "%s records typed API status" % responsibility_id)
		_expect(not str(row.get("visibility_scope", "")).is_empty(), "%s records visibility scope" % responsibility_id)
		_expect(str(row.get("final_disposition", "")) == "MIGRATE_BEFORE_DELETE", "%s cannot be deleted before migration" % responsibility_id)
	_expect(ids.has("public_player_inspection") and ids.has("public_commodity_detail_claim") and ids.has("public_track_detail") and ids.has("hand_card_detail"), "all high-value interactive consumers are explicit")

	var game_screen_scene := FileAccess.get_file_as_string("res://scenes/ui/GameScreen.tscn")
	var game_screen_script := FileAccess.get_file_as_string("res://scripts/ui/game_screen.gd")
	_expect(int(inventory.get("game_screen_matching_source_line_count", -1)) == _matching_line_count(game_screen_script, "right_inspector"), "matching-line metric is exact")
	_expect(int(inventory.get("game_screen_symbol_occurrence_count", -1)) == game_screen_script.count("right_inspector"), "symbol-occurrence metric is exact")
	_expect(int(inventory.get("game_screen_dynamic_call_count", -1)) == game_screen_script.count("right_inspector.call("), "dynamic-call metric is exact")
	_expect(int(inventory.get("game_screen_signal_connection_count", -1)) == _matching_line_count_all(game_screen_script, ["right_inspector", ".connect("]), "signal-connection metric is exact")
	_expect(game_screen_scene.contains("[node name=\"RightInspector\"") and game_screen_scene.contains("custom_minimum_size = Vector2(292, 0)"), "production fixed inspector is honestly preserved")
	_expect(game_screen_script.contains("right_inspector") and game_screen_script.contains("show_public_player") and game_screen_script.contains("show_public_commodity") and game_screen_script.contains("show_card"), "production consumers remain visible until typed parity exists")

	var reference_scene := FileAccess.get_file_as_string("res://scenes/ui/v07/V07ContextualTableSurface.tscn")
	_expect(not reference_scene.contains("RightInspector") and not reference_scene.contains("res://scenes/ui/PlanetBoard.tscn"), "detached V0.7 reference has neither fixed inspector nor production board")
	var preserved: Array = inventory.get("temporarily_preserved_components", []) if inventory.get("temporarily_preserved_components", []) is Array else []
	_expect(preserved.size() == 3, "temporarily preserved production components are explicit")
	for row_variant in preserved:
		var row: Dictionary = row_variant if row_variant is Dictionary else {}
		_expect(not str(row.get("component", "")).is_empty() and not str(row.get("current_consumer", "")).is_empty() and not str(row.get("exact_deletion_gate", "")).is_empty(), "preserved component has consumer and exact deletion gate")
	_expect(str(inventory.get("next_task", "")) == "V07_PRODUCTION_TABLE_SHELL_TYPED_PRESENTATION_PORTS_PREFLIGHT", "next boundary is one exact typed-port preflight")
	_finish()


func _load_inventory() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INVENTORY_PATH))
	return parsed as Dictionary if parsed is Dictionary else {}


func _matching_line_count(source: String, needle: String) -> int:
	var count := 0
	for line in source.split("\n"):
		if line.to_lower().contains(needle.to_lower()):
			count += 1
	return count


func _matching_line_count_all(source: String, needles: Array[String]) -> int:
	var count := 0
	for line in source.split("\n"):
		var matches_all := true
		for needle in needles:
			if not line.to_lower().contains(needle.to_lower()):
				matches_all = false
				break
		if matches_all:
			count += 1
	return count


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("V07_RIGHT_INSPECTOR_RESPONSIBILITY_INVENTORY_TEST|status=%s|checks=%d|failures=%d|responsibilities=10" % [status, _checks, _failures.size()])
	for failure in _failures:
		push_error("V07_RIGHT_INSPECTOR_RESPONSIBILITY_INVENTORY_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
