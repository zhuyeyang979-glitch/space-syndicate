extends RefCounted
class_name ScenarioReplayPanelSnapshot

var ui: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	var snapshots: Array = data.get("snapshots", []) if data.get("snapshots", []) is Array else []
	var current_snapshot := str(data.get("current_snapshot", "start"))
	var entries: Array = []
	for snapshot_variant in snapshots:
		if not (snapshot_variant is Dictionary):
			continue
		var snapshot: Dictionary = snapshot_variant
		var key := str(snapshot.get("key", ""))
		if key == "":
			continue
		entries.append({
			"key": key,
			"label": str(snapshot.get("label", key)),
			"selected": key == current_snapshot,
			"action_id": "scenario_replay_%s" % key,
		})
	ui = {
		"visible": bool(data.get("visible", true)),
		"title": str(data.get("title", "剧本复盘")),
		"scenario_id": str(data.get("scenario_id", "")),
		"current_snapshot": current_snapshot,
		"snapshots": entries,
	}
	return self


func to_ui_dictionary() -> Dictionary:
	return ui.duplicate(true)
