@tool
extends Node
class_name CompendiumApplicationFlowController

const CODEX_OPEN_REQUEST_SCRIPT := preload("res://scripts/runtime/codex_open_request.gd")
const NAVIGATION_PORT_SCRIPT := preload("res://scripts/runtime/compendium_navigation_port.gd")
const QUERY_PORT_SCRIPT := preload("res://scripts/presentation/compendium_readonly_query_port.gd")
const DOMAIN_TITLES := {
	"compendium": "资料大厅", "role": "角色图鉴", "card": "卡牌图鉴",
	"monster": "怪兽生态档案", "product": "商品图鉴", "region": "区域图鉴",
}

@export var menu_overlay_path: NodePath
@export var application_flow_port_path: NodePath
@export var navigation_port_path: NodePath
@export var navigation_owner_path: NodePath
@export var query_port_path: NodePath

var _input_count := 0
var _navigation_count := 0
var _query_count := 0
var _page_apply_count := 0
var _rejected_count := 0
var _duplicate_apply_count := 0
var _return_count := 0
var _last_applied_revision := 0


func open_hub() -> bool:
	return _navigation_port().request_open("compendium", "hub", "hub", -1, "", 0, "main", {"origin": "main"}) if _navigation_port() != null else false


func handle_navigation_request(request: CODEX_OPEN_REQUEST_SCRIPT) -> bool:
	_input_count += 1
	if request == null or request.request_revision <= _last_applied_revision:
		_duplicate_apply_count += 1
		_rejected_count += 1
		return false
	var overlay := _menu_overlay()
	var navigation := _navigation_owner()
	var query := _query_port()
	if overlay == null or navigation == null or query == null:
		_rejected_count += 1
		return false
	var content_width := overlay.available_content_width()
	var content_height := overlay.available_content_height()
	var resolved := query.resolve_request(request, navigation.navigation_snapshot(), content_width, content_height)
	if resolved.is_empty():
		_rejected_count += 1
		return false
	var transition := navigation.apply_request(request, resolved)
	if not bool(transition.get("accepted", false)):
		_rejected_count += 1
		return false
	_navigation_count += 1
	var result := query.compose_page(request, resolved, content_width, content_height)
	if result.is_empty():
		_rejected_count += 1
		return false
	_query_count += 1
	var scroll_value := overlay.content_scroll_value()
	if not _present_result(overlay, result, request.view == "preview"):
		_rejected_count += 1
		return false
	if request.view == "preview":
		overlay.set_content_scroll_value(scroll_value)
	_last_applied_revision = request.request_revision
	_page_apply_count += 1
	return true


func step_current_catalog(delta: int) -> bool:
	if delta not in [-1, 1]:
		_rejected_count += 1
		return false
	var navigation := _navigation_owner()
	var port := _navigation_port()
	if navigation == null or port == null:
		return false
	var snapshot := navigation.navigation_snapshot()
	var domain := str(snapshot.get("catalog_mode", ""))
	if domain not in ["role", "card", "monster", "product", "region"]:
		return false
	var view := str(snapshot.get("current_view", "browser"))
	var state := snapshot.get(domain, {}) as Dictionary if snapshot.get(domain, {}) is Dictionary else {}
	var filter_id := str(state.get("filter_id", "all")) if domain == "card" else ""
	if view == "detail" or domain in ["role", "region"]:
		return port.request_open(domain, "detail", str(snapshot.get("stable_item_id", "")), -1, filter_id, delta, str(snapshot.get("return_target", "compendium")), {"origin": "compendium"})
	return port.request_open(domain, "browser", "catalog", -1, filter_id, delta, str(snapshot.get("return_target", "compendium")), {"origin": "compendium"})


func back_from_catalog() -> bool:
	var navigation := _navigation_owner()
	var port := _navigation_port()
	if navigation == null or port == null:
		return false
	var spec := navigation.back_request_spec()
	if str(spec.get("kind", "")) == "return":
		return _route_return(str(spec.get("target", "main")))
	return port.request_open(
		str(spec.get("domain", "")), str(spec.get("view", "")), str(spec.get("stable_item_id", "")),
		int(spec.get("optional_index", -1)), str(spec.get("filter_id", "")), 0,
		str(spec.get("return_target", "compendium")),
		(spec.get("public_source_context", {}) as Dictionary).duplicate(true) if spec.get("public_source_context", {}) is Dictionary else {}
	)


func handle_surface_action(action_id: String, payload: Dictionary) -> bool:
	if not _payload_keys_valid(action_id, payload):
		_rejected_count += 1
		return false
	var port := _navigation_port()
	var navigation := _navigation_owner()
	if port == null or navigation == null:
		return false
	var current := navigation.navigation_snapshot()
	var return_target := str(current.get("return_target", "compendium"))
	match action_id:
		"hub_action":
			var domain := str(payload.get("action_id", ""))
			if domain == "main": return _route_return("main")
			if domain == "role": return port.request_open("role", "detail", "catalog", 0, "", 0, "compendium", {"origin": "compendium"})
			if domain == "region": return port.request_open("region", "detail", "catalog", 0, "", 0, "compendium", {"origin": "compendium"})
			return port.request_open(domain, "browser", "catalog", -1, "all" if domain == "card" else "", 0, "compendium", {"origin": "compendium"})
		"card_filter": return port.request_open("card", "browser", "catalog", -1, str(payload.get("filter_id", "")), 0, return_target, {"origin": "card"})
		"card_page_step": return port.request_open("card", "browser", "catalog", -1, str((current.get("card", {}) as Dictionary).get("filter_id", "all")), int(payload.get("delta", 0)), return_target, {"origin": "card"})
		"card_preview", "card_detail":
			var card_view := "preview" if action_id == "card_preview" else "detail"
			return port.request_open("card", card_view, str(payload.get("card_name", "")), -1, str((current.get("card", {}) as Dictionary).get("filter_id", "all")), 0, return_target, {"origin": "card"})
		"card_deep_link": return port.request_open("card", "detail", str(payload.get("card_name", "")), -1, "all", 0, return_target, {"origin": "monster", "push_current": true})
		"monster_page_step": return port.request_open("monster", "browser", "catalog", -1, "", int(payload.get("delta", 0)), return_target, {"origin": "monster"})
		"monster_preview", "monster_detail":
			var monster_index := int(payload.get("catalog_index", -1))
			return port.request_open("monster", "preview" if action_id == "monster_preview" else "detail", "monster:%d" % monster_index, monster_index, "", 0, return_target, {"origin": "monster"})
		"product_page_step": return port.request_open("product", "browser", "catalog", -1, "", int(payload.get("delta", 0)), return_target, {"origin": "product"})
		"product_preview", "product_detail":
			var product_index := int(payload.get("catalog_index", -1))
			return port.request_open("product", "preview" if action_id == "product_preview" else "detail", "catalog", product_index, "", 0, return_target, {"origin": "product"})
	return false


func debug_snapshot() -> Dictionary:
	return {
		"controller_id": "compendium_application_flow_controller_v06",
		"input_count": _input_count, "navigation_transition_count": _navigation_count,
		"query_count": _query_count, "page_apply_count": _page_apply_count,
		"rejected_count": _rejected_count, "duplicate_apply_count": _duplicate_apply_count,
		"return_count": _return_count, "last_applied_revision": _last_applied_revision,
		"references_main": false, "owns_navigation_state": false, "owns_gameplay_state": false,
		"exact_once_page_apply": _duplicate_apply_count == 0,
	}


func _present_result(overlay: SpaceSyndicateMenuOverlay, result: Dictionary, preserve_scroll: bool) -> bool:
	var title := str(result.get("title", "资料大厅"))
	var body := str(result.get("body", ""))
	if not overlay.visible:
		var app_port := _application_flow_port()
		if app_port == null or not app_port.request_menu(title, body if body != "" else "公开资料页", false):
			return false
	overlay.present_menu_shell({
		"title": title, "body": body, "context": "公开资料库｜浏览不会改变牌桌", "context_visible": true,
		"hint": "对手现金、手牌、隐藏归属和内部权重保持隐藏。", "hint_visible": true,
		"continue_disabled": true, "continue_visible": false, "back_visible": true, "nav_visible": true,
		"run_save_visible": false, "root_table_menu": false, "compact_page": false,
		"quick_nav": _quick_nav_entries(), "quick_nav_active_id": "compendium", "quick_nav_visible": true,
		"reset_scroll": not preserve_scroll,
	})
	return overlay.present_codex_page((result.get("page", {}) as Dictionary).duplicate(true)) if result.get("page", {}) is Dictionary else false


func _route_return(target: String) -> bool:
	var app_port := _application_flow_port()
	var overlay := _menu_overlay()
	if app_port == null or overlay == null:
		return false
	_return_count += 1
	match target:
		"compendium": return open_hub()
		"economy", "standings", "intel": return app_port.submit_action(target)
		"game": overlay.continue_requested.emit(); return true
		"main": overlay.main_menu_requested.emit(); return true
	return false


func _payload_keys_valid(action_id: String, payload: Dictionary) -> bool:
	var expected: Array[String]
	match action_id:
		"hub_action": expected = ["action_id"]
		"card_filter": expected = ["filter_id"]
		"card_page_step", "monster_page_step", "product_page_step": expected = ["delta"]
		"card_preview", "card_detail", "card_deep_link": expected = ["card_name"]
		"monster_preview", "monster_detail", "product_preview", "product_detail": expected = ["catalog_index"]
		_: return false
	var keys: Array[String] = []
	for key_variant: Variant in payload.keys(): keys.append(str(key_variant))
	keys.sort(); expected.sort()
	if keys != expected: return false
	if expected == ["delta"] and int(payload.get("delta", 0)) not in [-1, 1]: return false
	if expected == ["catalog_index"] and int(payload.get("catalog_index", -1)) < 0: return false
	if expected == ["card_name"] and str(payload.get("card_name", "")).strip_edges() == "": return false
	if action_id == "hub_action" and str(payload.get("action_id", "")) not in ["role", "monster", "card", "product", "region", "main"]: return false
	return true


func _quick_nav_entries() -> Array:
	return [
		{"id": "setup", "label": "开局", "tooltip": "进入开局配置。", "accent": Color("#38bdf8")},
		{"id": "standings", "label": "局势", "tooltip": "查看局势排名。", "accent": Color("#facc15")},
		{"id": "economy", "label": "经济", "tooltip": "查看经济总览。", "accent": Color("#4ade80")},
		{"id": "intel", "label": "情报", "tooltip": "查看情报档案。", "accent": Color("#c084fc")},
		{"id": "rules", "label": "规则", "tooltip": "查看当前规则。", "accent": Color("#93c5fd")},
		{"id": "compendium", "label": "图鉴", "tooltip": "查看资料库。", "accent": Color("#f472b6")},
	]


func _menu_overlay() -> SpaceSyndicateMenuOverlay: return get_node_or_null(menu_overlay_path) as SpaceSyndicateMenuOverlay
func _application_flow_port() -> ApplicationFlowPort: return get_node_or_null(application_flow_port_path) as ApplicationFlowPort
func _navigation_port() -> NAVIGATION_PORT_SCRIPT: return get_node_or_null(navigation_port_path) as NAVIGATION_PORT_SCRIPT
func _navigation_owner() -> CodexNavigationRuntimeController: return get_node_or_null(navigation_owner_path) as CodexNavigationRuntimeController
func _query_port() -> QUERY_PORT_SCRIPT: return get_node_or_null(query_port_path) as QUERY_PORT_SCRIPT
