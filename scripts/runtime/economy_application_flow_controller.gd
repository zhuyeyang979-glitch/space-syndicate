@tool
extends Node
class_name EconomyApplicationFlowController

const DASHBOARD_SCENE := preload("res://scenes/ui/EconomyDashboard.tscn")

@export var menu_overlay_path: NodePath
@export var query_port_path: NodePath

var _open_count := 0
var _rejected_count := 0
var _dashboard_set_count := 0


func open_economy() -> bool:
	var overlay := _menu_overlay()
	var query := _query_port()
	if overlay == null or query == null:
		_rejected_count += 1
		return false
	var snapshot := query.snapshot_for_authorized_viewer(overlay.available_content_width())
	if snapshot.is_empty():
		_rejected_count += 1
		return false
	overlay.present_menu_shell({
		"title": "经济总览",
		"body": str(snapshot.get("summary_text", "还没有可用经济数据。")),
		"context": "公共市场与物流 + 我的私人经济",
		"context_visible": true,
		"hint": "对手现金、账本、仓库库存与隐藏所有权保持隐藏。",
		"hint_visible": true,
		"continue_disabled": true,
		"continue_visible": false,
		"back_visible": true,
		"nav_visible": true,
		"run_save_visible": false,
		"root_table_menu": false,
		"compact_page": false,
		"quick_nav": _quick_nav_entries(),
		"quick_nav_active_id": "economy",
		"quick_nav_visible": true,
	})
	var preview_host := overlay.get_preview_host()
	if preview_host == null:
		_rejected_count += 1
		return false
	overlay.clear_preview()
	preview_host.visible = true
	var dashboard := DASHBOARD_SCENE.instantiate() as SpaceSyndicateEconomyDashboard
	if dashboard == null:
		_rejected_count += 1
		return false
	dashboard.name = "EconomyDashboardPanel"
	dashboard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_host.add_child(dashboard)
	dashboard.set_dashboard(snapshot.get("dashboard", {}) as Dictionary)
	_dashboard_set_count += 1
	_open_count += 1
	return true


func debug_snapshot() -> Dictionary:
	return {"controller_id": "economy_application_flow_controller_v06", "open_count": _open_count, "rejected_count": _rejected_count, "dashboard_set_count": _dashboard_set_count, "mutates_world_on_open": false, "references_main": false}


func _menu_overlay() -> SpaceSyndicateMenuOverlay: return get_node_or_null(menu_overlay_path) as SpaceSyndicateMenuOverlay
func _query_port() -> EconomyDashboardViewerQueryPort: return get_node_or_null(query_port_path) as EconomyDashboardViewerQueryPort


func _quick_nav_entries() -> Array:
	return [
		{"id": "setup", "label": "开局", "tooltip": "进入开局配置。", "accent": Color("#38bdf8")},
		{"id": "standings", "label": "局势", "tooltip": "查看局势排名。", "accent": Color("#facc15")},
		{"id": "economy", "label": "经济", "tooltip": "查看经济总览。", "accent": Color("#4ade80")},
		{"id": "intel", "label": "情报", "tooltip": "查看情报档案。", "accent": Color("#c084fc")},
		{"id": "rules", "label": "规则", "tooltip": "查看当前规则。", "accent": Color("#93c5fd")},
		{"id": "compendium", "label": "图鉴", "tooltip": "查看资料库。", "accent": Color("#f472b6")},
	]
