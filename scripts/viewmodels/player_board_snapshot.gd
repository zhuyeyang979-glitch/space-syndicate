extends RefCounted
class_name PlayerBoardSnapshot

const ACTION_DOCK_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/action_dock_snapshot.gd")
const BID_BOARD_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/bid_board_snapshot.gd")

var title: String = ""
var hint: String = ""
var identity: String = ""
var cash_text: String = ""
var gdp_text: String = ""
var goal_text: String = ""
var goal_ratio: float = 0.0
var selected_district_summary: String = ""
var primary_action_label: String = ""
var primary_actions: Array = []
var quick_actions: Array = []
var table_state_lamps: Array = []
var readiness_chips: Array = []
var progress_path: Array = []
var bid_board: Dictionary = {}


func apply_dictionary(data: Dictionary) -> RefCounted:
	title = str(data.get("title", "玩家状态条"))
	hint = str(data.get("hint", "卡牌操作只在玩家卡牌坞中进行。"))
	identity = str(data.get("identity", data.get("player", title)))
	cash_text = str(data.get("cash_text", data.get("cash", "")))
	gdp_text = str(data.get("gdp_text", data.get("gdp", "")))
	goal_text = str(data.get("goal_text", data.get("goal", data.get("target", ""))))
	goal_ratio = clampf(float(data.get("goal_ratio", 0.0)), 0.0, 1.0)
	selected_district_summary = str(data.get("selected_district_summary", data.get("selected_district", data.get("selected_region", ""))))
	var action_dock: Dictionary = ACTION_DOCK_SNAPSHOT_SCRIPT.new().apply_dictionary(data).to_ui_dictionary()
	primary_actions = action_dock.get("actions", []) if action_dock.get("actions", []) is Array else []
	quick_actions = action_dock.get("quick_actions", []) if action_dock.get("quick_actions", []) is Array else []
	table_state_lamps = data.get("table_state_lamps", data.get("status_lamps", [])) if data.get("table_state_lamps", data.get("status_lamps", [])) is Array else []
	readiness_chips = data.get("readiness_chips", data.get("action_readiness", [])) if data.get("readiness_chips", data.get("action_readiness", [])) is Array else []
	progress_path = data.get("progress_path", data.get("runtime_path", data.get("path_steps", []))) if data.get("progress_path", data.get("runtime_path", data.get("path_steps", []))) is Array else []
	var bid_source: Dictionary = data.get("bid_board", data.get("auction_board", {})) if data.get("bid_board", data.get("auction_board", {})) is Dictionary else {}
	bid_board = BID_BOARD_SNAPSHOT_SCRIPT.new().apply_dictionary(bid_source).to_ui_dictionary()
	primary_action_label = str(data.get("primary_action", data.get("primary_action_label", _first_action_label(primary_actions))))
	return self


func to_ui_dictionary() -> Dictionary:
	return {
		"title": title,
		"hint": hint,
		"identity": identity,
		"cash_text": cash_text,
		"gdp_text": gdp_text,
		"goal_text": goal_text,
		"goal_ratio": goal_ratio,
		"selected_district_summary": selected_district_summary,
		"primary_action": primary_action_label,
		"actions": primary_actions,
		"quick_actions": quick_actions,
		"table_state_lamps": table_state_lamps,
		"readiness_chips": readiness_chips,
		"progress_path": progress_path,
		"bid_board": bid_board,
	}


func _first_action_label(actions: Array) -> String:
	for action_variant in actions:
		var action: Dictionary = action_variant if action_variant is Dictionary else {}
		if not bool(action.get("disabled", false)):
			var label := str(action.get("label", ""))
			if label.strip_edges() != "":
				return label
	return ""
