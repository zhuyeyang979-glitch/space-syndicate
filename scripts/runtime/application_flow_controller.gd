extends Node
class_name ApplicationFlowController

## Scene-owned application-flow handler. This first slice owns the rules page
## only; it coordinates the existing menu surface and static rules board, but
## never owns gameplay state, simulation timing, commands, RNG, or save data.

const RULES_BOARD_SCENE := preload("res://scenes/ui/RulesQuickReferenceBoard.tscn")
const RULES_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/rules_quick_reference_snapshot_v06.gd")

@export var menu_overlay_path: NodePath
@export var coordinator_path: NodePath

var _rules_open_count := 0


func open_rules() -> bool:
	var overlay := _menu_overlay()
	if overlay == null or not overlay.has_method("present_menu_shell") or not overlay.has_method("get_preview_host"):
		return false
	var coordinator := _coordinator()
	if coordinator != null and coordinator.has_method("pause_session"):
		coordinator.pause_session()
	var body := "读桌顺序：钱 → 城 → 牌 → 怪兽 → 线索。\n开局：公开角色，选起始怪兽，先把怪兽压到星球。\n赚钱：城市化份额吃GDP；商品、商路和破坏会改现金流。\n出牌：买牌花钱；高阶牌检查地区GDP份额，公开牌轨留下线索。"
	overlay.call("present_menu_shell", {
		"title": "游戏规则",
		"body": body,
		"context": "当前牌桌规则速览",
		"context_visible": true,
		"hint": "点击卡片查看关键规则；返回键回到当前牌桌。",
		"hint_visible": true,
		"continue_disabled": true,
		"continue_visible": false,
		"back_visible": true,
		"nav_visible": true,
		"run_save_visible": false,
		"root_table_menu": false,
		"compact_page": false,
		"quick_nav": _quick_nav_entries(),
		"quick_nav_active_id": "rules",
		"quick_nav_visible": true,
	})
	var preview_host := overlay.call("get_preview_host") as Container
	if preview_host == null:
		return false
	overlay.call("clear_preview")
	preview_host.visible = true
	var board := RULES_BOARD_SCENE.instantiate() as Control
	if board == null or not board.has_method("set_board"):
		return false
	preview_host.add_child(board)
	board.call("set_board", RULES_SNAPSHOT_SCRIPT.compose(_available_width(overlay)))
	_rules_open_count += 1
	return true


func debug_snapshot() -> Dictionary:
	return {
		"handler_id": "application_flow_controller_v06",
		"rules_open_count": _rules_open_count,
		"owns_gameplay_state": false,
		"owns_simulation_step": false,
		"owns_runtime_command_pipeline": false,
		"owns_mutation_authority": false,
		"owns_rng": false,
		"owns_save_data": false,
		"main_fallback": false,
	}


func _menu_overlay() -> Node:
	return get_node_or_null(menu_overlay_path) if not menu_overlay_path.is_empty() else null


func _coordinator() -> GameRuntimeCoordinator:
	return get_node_or_null(coordinator_path) as GameRuntimeCoordinator if not coordinator_path.is_empty() else null


func _available_width(overlay: Node) -> float:
	if overlay.has_method("available_content_width"):
		return float(overlay.call("available_content_width"))
	return 640.0


func _quick_nav_entries() -> Array:
	return [
		{"id": "setup", "label": "开局", "tooltip": "进入开局配置。", "accent": Color("#38bdf8")},
		{"id": "standings", "label": "局势", "tooltip": "查看局势排名。", "accent": Color("#facc15")},
		{"id": "economy", "label": "经济", "tooltip": "查看经济总览。", "accent": Color("#4ade80")},
		{"id": "intel", "label": "情报", "tooltip": "查看情报档案。", "accent": Color("#c084fc")},
		{"id": "rules", "label": "规则", "tooltip": "查看当前规则。", "accent": Color("#93c5fd")},
		{"id": "compendium", "label": "图鉴", "tooltip": "查看资料库。", "accent": Color("#f472b6")},
	]
