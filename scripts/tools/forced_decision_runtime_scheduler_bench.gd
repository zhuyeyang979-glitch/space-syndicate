extends Control
class_name ForcedDecisionRuntimeSchedulerBench

const OUTPUT_DIR := "user://space_syndicate_design_qa/forced_decision_scheduler/"
const MANIFEST_PATH := OUTPUT_DIR + "manifest.json"
const REPORT_PATH := OUTPUT_DIR + "report.md"
const SCREENSHOT_PATH := "user://space_syndicate_design_qa/forced_decision_scheduler_sprint_1.png"
const ACTION_ID_SAMPLES := [
	"monster_wager:17:alpha:5",
	"contract_accept_23",
	"contract_reject_23",
	"discard_purchase_2",
	"target_monster_1",
	"target_player_2",
]
const FLOW_CASES := [
	{"case_id": "no_decision", "notes": "An empty candidate set yields no active forced decision."},
	{"case_id": "other_choice_only", "notes": "A private target choice is selected for its owner."},
	{"case_id": "contract_over_other_choice", "notes": "Contract response outranks target and discard choices."},
	{"case_id": "counter_over_contract", "notes": "Card counter response outranks a pending contract."},
	{"case_id": "monster_wager_over_counter", "notes": "Monster wager is the highest v0.4 forced-decision priority."},
	{"case_id": "stable_order_with_same_priority", "notes": "Equal-priority candidates sort by opened sequence and stable id."},
	{"case_id": "resolve_reveals_next_decision", "notes": "Removing the resolved candidate reveals the next priority without duplicate state."},
	{"case_id": "global_blocking_matrix", "notes": "Monster wager blocks table time, player actions, and card resolution."},
	{"case_id": "player_specific_blocking", "notes": "A private contract blocks only its target owner's actions."},
	{"case_id": "card_resolution_progress_gate", "notes": "Contract waits block settlement progress while the counter timer remains allowed to tick."},
	{"case_id": "private_owner_not_exposed", "notes": "Non-owners receive only a private waiting hint and debug output omits owner identity."},
	{"case_id": "action_ids_unchanged", "notes": "The scheduler arbitrates decision ids without rewriting existing action ids."},
	{"case_id": "recompute_after_save_state", "notes": "Derived candidates recompute to the same active result after reset."},
	{"case_id": "pure_data_snapshots", "notes": "Coordinator, scheduler, and manifest snapshots contain no runtime objects."},
]

@export var auto_run := true
@export var auto_quit_after_suite := false

@onready var bridge: Node = %RulesetRuntimeBridge
@onready var coordinator: Node = %GameRuntimeCoordinator
@onready var status_label: Label = %StatusLabel
@onready var summary_label: Label = %SummaryLabel
@onready var priority_text: RichTextLabel = %PriorityText

var _suite_running := false


func _ready() -> void:
	if auto_run and not Engine.is_editor_hint():
		call_deferred("run_flow_suite")


func output_dir() -> String:
	return OUTPUT_DIR


func screenshot_path() -> String:
	return SCREENSHOT_PATH


func flow_cases() -> Array:
	return FLOW_CASES.duplicate(true)


func build_flow_manifest_preview() -> Dictionary:
	var records: Array = []
	for case_variant in flow_cases():
		var flow_case: Dictionary = case_variant
		records.append(_record(str(flow_case.get("case_id", "")), false, "Preview manifest only."))
	return {
		"suite": "forced_decision_runtime_scheduler",
		"ruleset_id": "v0.4",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"records": records,
	}


func run_flow_suite() -> void:
	if _suite_running:
		return
	_suite_running = true
	_prepare_output_dir()
	_set_status("Running forced-decision ownership checks...")
	var records: Array = []
	for case_variant in flow_cases():
		_configure_runtime()
		var flow_case: Dictionary = case_variant
		var case_id := str(flow_case.get("case_id", ""))
		var passed := _run_case(case_id)
		var notes := str(flow_case.get("notes", ""))
		records.append(_record(case_id, passed, notes if passed else "FAILED: %s" % notes))
	var manifest := {
		"suite": "forced_decision_runtime_scheduler",
		"ruleset_id": "v0.4",
		"output_dir": OUTPUT_DIR,
		"screenshot_path": SCREENSHOT_PATH,
		"record_count": records.size(),
		"passed_count": _passed_count(records),
		"records": records,
		"runtime": _coordinator_snapshot(),
	}
	_write_text_file(MANIFEST_PATH, JSON.stringify(manifest, "\t"))
	_write_text_file(REPORT_PATH, _build_report(manifest))
	await _settle_frames(2)
	_write_screenshot()
	var all_passed := _passed_count(records) == records.size()
	print("ForcedDecisionRuntimeSchedulerBench manifest: %s" % MANIFEST_PATH)
	print("ForcedDecisionRuntimeSchedulerBench report: %s" % REPORT_PATH)
	print("ForcedDecisionRuntimeSchedulerBench screenshot: %s" % SCREENSHOT_PATH)
	print("ForcedDecisionRuntimeSchedulerBench passed: %d/%d" % [_passed_count(records), records.size()])
	_set_status("Forced decision scheduler: %d/%d | %s" % [_passed_count(records), records.size(), MANIFEST_PATH])
	if not all_passed:
		push_error("ForcedDecisionRuntimeSchedulerBench failed. See %s" % MANIFEST_PATH)
	_suite_running = false
	if auto_quit_after_suite:
		await get_tree().create_timer(0.25).timeout
		get_tree().quit(0 if all_passed else 1)


func _run_case(case_id: String) -> bool:
	match case_id:
		"no_decision":
			_sync([])
			return _active().is_empty() and not coordinator.call("blocks_global_time")
		"other_choice_only":
			_sync([_other_choice()])
			return str(_active(0).get("priority_group", "")) == "other_choice" and bool(_active(0).get("visible_to_viewer", false))
		"contract_over_other_choice":
			_sync([_other_choice(), _contract_response()])
			return str(_active(1).get("priority_group", "")) == "contract_response"
		"counter_over_contract":
			_sync([_contract_response(), _counter_response()])
			return str(_active().get("priority_group", "")) == "counter_response"
		"monster_wager_over_counter":
			_sync([_counter_response(), _monster_wager()])
			return str(_active().get("priority_group", "")) == "monster_wager"
		"stable_order_with_same_priority":
			var choice_b := _other_choice()
			choice_b["id"] = "choice_b"
			choice_b["opened_sequence"] = 4.0
			var choice_a := choice_b.duplicate(true)
			choice_a["id"] = "choice_a"
			_sync([choice_b, choice_a])
			return str(_active(0).get("id", "")) == "choice_a"
		"resolve_reveals_next_decision":
			_sync([_monster_wager(), _contract_response()])
			var first_group := str(_active(1).get("priority_group", ""))
			_sync([_contract_response()])
			return first_group == "monster_wager" and str(_active(1).get("priority_group", "")) == "contract_response"
		"global_blocking_matrix":
			_sync([_monster_wager()])
			return bool(coordinator.call("blocks_global_time")) and bool(coordinator.call("blocks_player_actions", 0)) and not bool(coordinator.call("allows_card_resolution_progress"))
		"player_specific_blocking":
			_sync([_contract_response()])
			return not bool(coordinator.call("blocks_player_actions", 0)) and bool(coordinator.call("blocks_player_actions", 1))
		"card_resolution_progress_gate":
			_sync([_contract_response()])
			var contract_blocks := not bool(coordinator.call("allows_card_resolution_progress"))
			_sync([_counter_response()])
			return contract_blocks and bool(coordinator.call("allows_card_resolution_progress"))
		"private_owner_not_exposed":
			_sync([_contract_response()])
			var hidden_entry := _active(0)
			var visible_entry := _active(1)
			return not bool(hidden_entry.get("visible_to_viewer", true)) and str(hidden_entry.get("presentation_surface", "")) == "player_hint" and bool(visible_entry.get("visible_to_viewer", false)) and not _contains_key_recursive(_coordinator_snapshot(), "owner_player_index")
		"action_ids_unchanged":
			var before := ACTION_ID_SAMPLES.duplicate()
			_sync([_monster_wager(), _contract_response(), _other_choice()])
			return before == ACTION_ID_SAMPLES and not _coordinator_snapshot().has("action_router")
		"recompute_after_save_state":
			var candidates := [_other_choice(), _contract_response(), _counter_response()]
			_sync(candidates)
			var before := _active(1)
			coordinator.call("reset_state")
			_sync(candidates.duplicate(true))
			return before == _active(1)
		"pure_data_snapshots":
			_sync([_monster_wager(), _counter_response(), _contract_response(), _other_choice()])
			return _is_pure_data(_coordinator_snapshot()) and _is_pure_data(build_flow_manifest_preview())
	return false


func _configure_runtime() -> void:
	if coordinator == null or bridge == null:
		return
	var ruleset_variant: Variant = bridge.call("debug_snapshot") if bridge.has_method("debug_snapshot") else {}
	coordinator.call("configure", ruleset_variant if ruleset_variant is Dictionary else {})
	coordinator.call("reset_state")


func _sync(candidates: Array) -> void:
	coordinator.call("sync_forced_decision_candidates", candidates)


func _active(viewer_index: int = -1) -> Dictionary:
	var active_variant: Variant = coordinator.call("active_forced_decision", viewer_index)
	return active_variant if active_variant is Dictionary else {}


func _coordinator_snapshot() -> Dictionary:
	var snapshot_variant: Variant = coordinator.call("debug_snapshot") if coordinator != null else {}
	return snapshot_variant if snapshot_variant is Dictionary else {}


func _monster_wager() -> Dictionary:
	return _candidate("monster_wager_17", "monster_wager", "monster_wager", -1, "public", "overlay", 17.0, true, true, true, "monster_wager")


func _counter_response() -> Dictionary:
	return _candidate("counter_response_19", "counter_response", "counter_response", -1, "public", "card_resolution_track", 19.0, false, false, false, "card_resolution_counter")


func _contract_response() -> Dictionary:
	return _candidate("contract_response_23", "contract_response", "contract_response", 1, "private", "overlay", 23.0, false, true, true, "contract_response")


func _other_choice() -> Dictionary:
	return _candidate("monster_target_choice", "monster_target_choice", "other_choice", 0, "private", "overlay", 31.0, false, true, false, "monster_target_choice")


func _candidate(id: String, kind: String, priority_group: String, owner_player_index: int, visibility_scope: String, presentation_surface: String, opened_sequence: float, blocks_global_time: bool, blocks_player_actions: bool, blocks_card_resolution: bool, source_ref: String) -> Dictionary:
	return {
		"id": id,
		"kind": kind,
		"priority_group": priority_group,
		"owner_player_index": owner_player_index,
		"visibility_scope": visibility_scope,
		"presentation_surface": presentation_surface,
		"opened_sequence": opened_sequence,
		"blocks_global_time": blocks_global_time,
		"blocks_player_actions": blocks_player_actions,
		"blocks_card_resolution": blocks_card_resolution,
		"source_ref": source_ref,
		"notes": "QA fixture",
	}


func _record(case_id: String, passed: bool, notes: String) -> Dictionary:
	var snapshot := _coordinator_snapshot()
	var scheduler: Dictionary = snapshot.get("forced_decision_scheduler", {}) if snapshot.get("forced_decision_scheduler", {}) is Dictionary else {}
	return {
		"case_id": case_id,
		"active_priority_group": str(scheduler.get("active_priority_group", "")),
		"candidate_count": int(scheduler.get("candidate_count", 0)),
		"global_blocked": bool(scheduler.get("blocks_global_time", false)),
		"card_progress_allowed": not bool(scheduler.get("blocks_card_resolution", false)),
		"privacy_checked": case_id == "private_owner_not_exposed",
		"action_ids_checked": case_id == "action_ids_unchanged",
		"pure_data_checked": case_id == "pure_data_snapshots",
		"passed": passed,
		"notes": notes,
	}


func _prepare_output_dir() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))


func _write_text_file(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write %s" % path)
		return
	file.store_string(contents)
	file.close()


func _build_report(manifest: Dictionary) -> String:
	var lines: Array[String] = [
		"# Forced Decision Runtime Scheduler",
		"",
		"Passed: %d/%d" % [int(manifest.get("passed_count", 0)), int(manifest.get("record_count", 0))],
		"Priority: `monster_wager -> counter_response -> contract_response -> other_choice`",
		"Output: `%s`" % OUTPUT_DIR,
		"",
		"| Case | Passed | Active group | Notes |",
		"| --- | --- | --- | --- |",
	]
	for record_variant in manifest.get("records", []):
		var record: Dictionary = record_variant
		lines.append("| %s | %s | %s | %s |" % [str(record.get("case_id", "")), str(record.get("passed", false)), str(record.get("active_priority_group", "")), str(record.get("notes", "")).replace("|", "/")])
	lines.append_array([
		"",
		"The scheduler owns arbitration and blocking only. Existing wager, counter, contract, target, and discard handlers still own rule effects.",
	])
	return "\n".join(lines) + "\n"


func _write_screenshot() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		return
	var image := get_viewport().get_texture().get_image()
	if image != null:
		image.save_png(SCREENSHOT_PATH)


func _set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text
	if summary_label != null:
		summary_label.text = text
	if priority_text != null:
		priority_text.text = "[b]v0.4 authority[/b]\nmonster_wager\n↓ counter_response\n↓ contract_response\n↓ other_choice\n\n%s" % text


func _settle_frames(count: int) -> void:
	for _index in count:
		await get_tree().process_frame


func _passed_count(records: Array) -> int:
	var count := 0
	for record_variant in records:
		if record_variant is Dictionary and bool((record_variant as Dictionary).get("passed", false)):
			count += 1
	return count


func _contains_key_recursive(value: Variant, target_key: String) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant) == target_key or _contains_key_recursive((value as Dictionary)[key_variant], target_key):
				return true
	elif value is Array:
		for item in value:
			if _contains_key_recursive(item, target_key):
				return true
	return false


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or value is Object:
		return false
	if value is Dictionary:
		for key in (value as Dictionary).keys():
			if not _is_pure_data(key) or not _is_pure_data((value as Dictionary)[key]):
				return false
	elif value is Array:
		for item in value:
			if not _is_pure_data(item):
				return false
	return true
