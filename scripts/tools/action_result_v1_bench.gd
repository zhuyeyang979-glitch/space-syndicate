@tool
extends Control

const OUTCOMES := [
	"player_unavailable",
	"queued_entry_missing",
	"group_window_closed",
	"already_ready",
	"ready_rejected",
	"group_ready_committed",
]

@export var auto_run := true
@export var exit_on_complete := true

@onready var service: Node = $ActionResultPresentationService
@onready var result_label: Label = %ResultLabel

var manifest: Dictionary = {}


func _ready() -> void:
	if Engine.is_editor_hint() or not auto_run:
		return
	call_deferred("_run")


func _run() -> void:
	service.call("configure", {})
	var records: Array = []
	var passed := 0
	for outcome_variant in OUTCOMES:
		var outcome := str(outcome_variant)
		var result: Dictionary = service.call("compose", {
			"schema_version": 1,
			"action_id": "card_group_ready",
			"action_family": "card_resolution",
			"outcome_code": outcome,
			"resolution_id": 101,
		})
		var record_passed: bool = not result.is_empty() \
			and bool(result.get("success", false)) == (outcome == "group_ready_committed") \
			and str(result.get("failure_code", "")) == ("" if outcome == "group_ready_committed" else outcome) \
			and result.get("affected_entity_ids", []) == ["resolution:101"]
		records.append({"outcome": outcome, "passed": record_passed})
		if record_passed:
			passed += 1
	var debug: Dictionary = service.call("debug_snapshot")
	var boundary_passed := bool(debug.get("service_ready", false)) \
		and not bool(debug.get("service_authoritative", true)) \
		and not bool(debug.get("owns_rules", true)) \
		and not bool(debug.get("owns_save_state", true)) \
		and not bool(debug.get("reads_world_bridge", true)) \
		and not bool(debug.get("mutates_game_state", true))
	records.append({"outcome": "service_boundary", "passed": boundary_passed})
	if boundary_passed:
		passed += 1
	var scene_unique := get_tree().get_nodes_in_group("action_result_presentation_service").size() == 0 \
		and find_children("ActionResultPresentationService", "", true, false).size() == 1
	records.append({"outcome": "scene_unique", "passed": scene_unique})
	if scene_unique:
		passed += 1
	manifest = {
		"record_count": records.size(),
		"passed_count": passed,
		"records": records,
		"status": "PASS" if passed == records.size() else "FAIL",
	}
	result_label.text = "ActionResult v1｜%d/%d｜%s" % [passed, records.size(), str(manifest.get("status", "FAIL"))]
	print("ACTION_RESULT_V1_BENCH|status=%s|checks=%d|passed=%d" % [str(manifest.get("status", "FAIL")), records.size(), passed])
	if exit_on_complete:
		get_tree().quit(0 if passed == records.size() else 1)


func debug_snapshot() -> Dictionary:
	return manifest.duplicate(true)
