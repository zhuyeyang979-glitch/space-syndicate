@tool
extends Node
class_name CompendiumReadOnlyQueryPort

const CODEX_OPEN_REQUEST_SCRIPT := preload("res://scripts/runtime/codex_open_request.gd")
const HUB_SNAPSHOT_SCRIPT := preload("res://scripts/viewmodels/compendium_hub_snapshot.gd")
const ROLE_ACCENTS := [
	Color("#38bdf8"), Color("#f472b6"), Color("#4ade80"), Color("#facc15"),
	Color("#c084fc"), Color("#fb7185"), Color("#67e8f9"), Color("#fb923c"),
]

@export var role_catalog_path: NodePath
@export var role_source_path: NodePath
@export var codex_snapshot_path: NodePath
@export var card_source_path: NodePath
@export var card_snapshot_path: NodePath
@export var monster_source_path: NodePath
@export var monster_snapshot_path: NodePath
@export var product_source_path: NodePath
@export var product_snapshot_path: NodePath
@export var region_source_path: NodePath

var _resolve_count := 0
var _query_count := 0
var _rejected_count := 0


func resolve_request(request: CODEX_OPEN_REQUEST_SCRIPT, navigation: Dictionary, content_width: float, content_height: float) -> Dictionary:
	if request == null or not bool(request.validation_report().get("valid", false)) or not _dependencies_ready():
		_rejected_count += 1
		return {}
	var context := _resolve_context(request, navigation, content_width, content_height)
	if context.is_empty() or not _is_pure_data(context):
		_rejected_count += 1
		return {}
	_resolve_count += 1
	return context


func compose_page(request: CODEX_OPEN_REQUEST_SCRIPT, resolved_context: Dictionary, content_width: float, content_height: float) -> Dictionary:
	if request == null or resolved_context.is_empty() or not _dependencies_ready():
		_rejected_count += 1
		return {}
	var result: Dictionary
	match request.domain:
		"compendium": result = compose_hub_page(content_width)
		"role": result = compose_role_page(resolved_context, content_width)
		"card":
			result = compose_card_detail_page(resolved_context) if request.view == "detail" else compose_card_browser_page(resolved_context)
		"monster":
			result = compose_monster_detail_page(resolved_context) if request.view == "detail" else compose_monster_browser_page(resolved_context)
		"product":
			result = compose_product_detail_page(resolved_context) if request.view == "detail" else compose_product_browser_page(resolved_context)
		"region": result = compose_region_page(resolved_context)
	if result.is_empty() or not _is_pure_data(result):
		_rejected_count += 1
		return {}
	result["resolved_context"] = resolved_context.duplicate(true)
	result["content_width"] = content_width
	result["content_height"] = content_height
	_query_count += 1
	return result


func compose_hub_page(content_width: float) -> Dictionary:
	return _result("资料大厅", "选择一个公开资料板；浏览不会改变牌桌、随机数或运行时状态。", {
		"mode": "compendium",
		"view": "hub",
		"hub": HUB_SNAPSHOT_SCRIPT.compose(content_width),
		"navigation": _navigation_data(false, "main"),
	})


func compose_role_page(context: Dictionary, content_width: float) -> Dictionary:
	var role_index := int(context.get("selected_index", -1))
	var catalog := _role_catalog()
	var definition := catalog.public_definition_at(role_index)
	if definition.is_empty():
		return {}
	var accent: Color = (ROLE_ACCENTS[wrapi(role_index, 0, ROLE_ACCENTS.size())] as Color).lerp(Color("#f59e0b"), 0.18)
	var trait_text := str(definition.get("trait", "暂无特征"))
	var passive_text := str(definition.get("passive", "暂无被动"))
	var presentation := {
		"accent": accent,
		"kpi_columns": clampi(int(floor(content_width / 210.0)), 1, 4),
		"route_columns": clampi(int(floor(content_width / 300.0)), 1, 3),
		"face": {
			"name": str(definition.get("name", "外星辛迪加")),
			"cost": "R",
			"effect": "特征:%s\n被动:%s\n公开角色" % [_short_text(trait_text, 34), _short_text(passive_text, 26)],
			"type": "角色卡 / %s" % str(definition.get("species", "未知外星人")),
			"rank": _short_text(str(definition.get("species", "角色")), 8),
			"card_kind": "player_role",
			"card_stats": "公开身份",
			"accent": accent,
			"minimum_width": 142.0,
			"minimum_height": 140.0,
		},
		"face_effect": "特征：%s\n被动：%s\n角色资料：公开身份；开局怪兽独立选择。" % [trait_text, passive_text],
	}
	var snapshot := _role_source().compose_snapshot(role_index, presentation)
	if snapshot.is_empty():
		return {}
	return _result("角色图鉴", str(snapshot.get("summary_text", "")), {
		"mode": "role", "view": "detail", "detail": snapshot.get("board", {}),
		"navigation": _navigation_data(true, str(context.get("return_target", "compendium"))),
	})


func compose_card_browser_page(context: Dictionary) -> Dictionary:
	var source := _card_source()
	var filter_id := str(context.get("filter_id", "all"))
	var names := source.ordered_card_ids(filter_id)
	var filters: Array = []
	for option_variant: Variant in source.public_filter_options():
		if not (option_variant is Dictionary):
			continue
		var option := (option_variant as Dictionary).duplicate(true)
		var option_id := str(option.get("id", "all"))
		option["count"] = source.ordered_card_ids(option_id).size()
		filters.append(option)
	var snapshot := source.compose_browser({
		"names": names,
		"columns": int(context.get("columns", 3)),
		"rows": int(context.get("rows", 1)),
		"page_index": int(context.get("page_index", 0)),
		"filter_id": filter_id,
		"selected_card": str(context.get("stable_item_id", "")),
		"run_pool_count": 0,
		"district_supply_count": 0,
		"filters": filters,
	})
	if snapshot.is_empty():
		return {}
	return _result("卡牌图鉴", str(snapshot.get("summary_text", "")), {
		"mode": "card", "view": "browser", "browser": snapshot,
		"navigation": _navigation_data(bool(context.get("can_step", false)), str(context.get("return_target", "compendium"))),
	})


func compose_card_detail_page(context: Dictionary) -> Dictionary:
	var snapshot := _card_source().compose_detail(
		str(context.get("stable_item_id", "")),
		int(context.get("selected_index", -1)),
		int(context.get("total_count", 0))
	)
	if snapshot.is_empty():
		return {}
	return _result("卡牌图鉴", str(snapshot.get("summary_text", "")), {
		"mode": "card", "view": "detail", "detail": snapshot.get("detail", {}),
		"navigation": _navigation_data(true, str(context.get("return_target", "compendium")), "返回缩略图"),
	})


func compose_monster_browser_page(context: Dictionary) -> Dictionary:
	var snapshot := _monster_source().compose_browser_source({
		"start_index": int(context.get("start_index", 0)),
		"end_index": int(context.get("end_index", 0)),
		"columns": int(context.get("columns", 3)),
		"selected_index": int(context.get("selected_index", 0)),
		"can_page": bool(context.get("can_step", false)),
		"page_label": str(context.get("page_label", "")),
	})
	if snapshot.is_empty():
		return {}
	return _result("怪兽生态档案", "怪兽生态｜%s\n查看公开移动、偏好与行动类别；隐藏归属、预选目标和内部权重不会显示。" % str(context.get("page_label", "")), {
		"mode": "monster", "view": "browser", "browser": snapshot,
		"navigation": _navigation_data(bool(context.get("can_step", false)), str(context.get("return_target", "compendium"))),
	})


func compose_monster_detail_page(context: Dictionary) -> Dictionary:
	var snapshot := _monster_source().compose_snapshot(int(context.get("selected_index", -1)), true)
	if snapshot.is_empty():
		return {}
	return _result("怪兽生态档案", str(snapshot.get("summary_text", "")), {
		"mode": "monster", "view": "detail", "detail": snapshot.get("detail", {}),
		"monster_card_link": snapshot.get("monster_card_link", {}),
		"navigation": _navigation_data(true, str(context.get("return_target", "compendium")), "返回缩略图"),
	})


func compose_product_browser_page(context: Dictionary) -> Dictionary:
	var snapshot := _product_source().compose_browser_snapshot({
		"start_index": int(context.get("start_index", 0)),
		"end_index": int(context.get("end_index", 0)),
		"selected_index": int(context.get("selected_index", 0)),
		"columns": int(context.get("columns", 3)),
		"can_page": bool(context.get("can_step", false)),
		"page_label": str(context.get("page_label", "")),
	})
	if snapshot.is_empty():
		return {}
	return _result("商品图鉴", str(snapshot.get("summary_text", "商品目录")), {
		"mode": "product", "view": "browser", "browser": snapshot,
		"navigation": _navigation_data(bool(context.get("can_step", false)), str(context.get("return_target", "compendium"))),
	})


func compose_product_detail_page(context: Dictionary) -> Dictionary:
	var snapshot := _product_source().compose_snapshot(str(context.get("stable_item_id", "")), int(context.get("selected_index", -1)), true)
	if snapshot.is_empty():
		return {}
	return _result("商品图鉴", str(snapshot.get("summary_text", "")), {
		"mode": "product", "view": "detail", "detail": snapshot.get("detail", {}),
		"navigation": _navigation_data(true, str(context.get("return_target", "compendium")), "返回缩略图"),
	})


func compose_region_page(context: Dictionary) -> Dictionary:
	var snapshot := _region_source().compose_region(int(context.get("selected_index", -1)))
	if snapshot.is_empty():
		return {}
	return _result("区域图鉴", str(snapshot.get("summary_text", "区域不存在。")), {
		"mode": "region", "view": "detail", "detail": snapshot.get("detail", {}),
		"navigation": _navigation_data(true, str(context.get("return_target", "compendium"))),
	})


func debug_snapshot() -> Dictionary:
	return {
		"port_id": "compendium_readonly_query_port_v06",
		"dependencies_ready": _dependencies_ready(),
		"resolve_count": _resolve_count,
		"query_count": _query_count,
		"rejected_count": _rejected_count,
		"references_main": false,
		"reads_mutable_players": false,
		"reads_private_world": false,
		"mutates_runtime": false,
		"uses_dynamic_discovery": false,
		"pure_data_only": true,
	}


func _resolve_context(request: CODEX_OPEN_REQUEST_SCRIPT, navigation: Dictionary, content_width: float, content_height: float) -> Dictionary:
	if request.domain == "compendium":
		return {"valid": true, "stable_item_id": "hub", "selected_index": -1, "page_index": 0, "return_target": request.return_target}
	var total_count := _domain_count(request.domain, request.filter_id)
	if total_count <= 0:
		return {}
	var domain_state := navigation.get(request.domain, {}) as Dictionary if navigation.get(request.domain, {}) is Dictionary else {}
	var selected_index := _resolve_item_index(request, domain_state, total_count)
	if selected_index < 0 or selected_index >= total_count:
		return {}
	if request.view == "detail" and request.page_delta != 0:
		selected_index = wrapi(selected_index + request.page_delta, 0, total_count)
	var layout := _layout_for_domain(request.domain, content_width, content_height)
	var entries_per_page := int(layout.get("entries_per_page", 1))
	var page_count := maxi(1, int(ceil(float(total_count) / float(entries_per_page))))
	var page_index := clampi(int(domain_state.get("page_index", 0)), 0, page_count - 1)
	if request.page_delta != 0 and request.view != "detail":
		page_index = wrapi(page_index + request.page_delta, 0, page_count)
		selected_index = page_index * entries_per_page
	elif request.view == "detail" or request.view == "preview" or request.optional_index >= 0 or request.stable_item_id != "catalog":
		page_index = clampi(int(floor(float(selected_index) / float(entries_per_page))), 0, page_count - 1)
	var stable_item_id := _stable_item_id(request.domain, selected_index, request.filter_id)
	if stable_item_id == "":
		return {}
	var start_index := page_index * entries_per_page
	var end_index := mini(total_count, start_index + entries_per_page)
	return {
		"valid": true,
		"stable_item_id": stable_item_id,
		"selected_index": selected_index,
		"page_index": page_index,
		"filter_id": request.filter_id if request.domain == "card" else "",
		"return_target": request.return_target,
		"total_count": total_count,
		"page_count": page_count,
		"start_index": start_index,
		"end_index": end_index,
		"columns": int(layout.get("columns", 1)),
		"rows": int(layout.get("rows", 1)),
		"entries_per_page": entries_per_page,
		"can_step": total_count > 1,
		"page_label": "第%d/%d页｜共%d项｜本页%d-%d" % [page_index + 1, page_count, total_count, start_index + 1, end_index],
	}


func _resolve_item_index(request: CODEX_OPEN_REQUEST_SCRIPT, domain_state: Dictionary, total_count: int) -> int:
	if request.optional_index >= 0:
		return request.optional_index if request.optional_index < total_count else -1
	if request.stable_item_id == "catalog":
		return clampi(int(domain_state.get("selected_index", 0)), 0, total_count - 1)
	match request.domain:
		"role":
			if request.stable_item_id.begins_with("role:") and request.stable_item_id.trim_prefix("role:").is_valid_int():
				return int(request.stable_item_id.trim_prefix("role:"))
			return _role_catalog().index_by_name(request.stable_item_id)
		"card":
			var card_id := _card_source().resolve_card_id(request.stable_item_id)
			return _card_source().ordered_card_ids(request.filter_id).find(card_id)
		"monster": return _monster_source().index_for_stable_item_id(request.stable_item_id)
		"product": return _product_source().index_by_product_id(request.stable_item_id)
		"region": return _region_source().index_for_stable_item_id(request.stable_item_id)
	return -1


func _domain_count(domain: String, filter_id: String) -> int:
	match domain:
		"role": return _role_catalog().role_count()
		"card": return _card_source().ordered_card_ids(filter_id).size()
		"monster": return _monster_source().public_catalog_count()
		"product": return _product_source().ordered_product_ids().size()
		"region": return _region_source().public_region_count()
	return 0


func _stable_item_id(domain: String, index: int, filter_id: String) -> String:
	match domain:
		"role": return "role:%d" % index if index >= 0 and index < _role_catalog().role_count() else ""
		"card":
			var ids := _card_source().ordered_card_ids(filter_id)
			return str(ids[index]) if index >= 0 and index < ids.size() else ""
		"monster": return _monster_source().stable_item_id_at(index)
		"product":
			var ids := _product_source().ordered_product_ids()
			return str(ids[index]) if index >= 0 and index < ids.size() else ""
		"region": return _region_source().stable_item_id_at(index)
	return ""


func _layout_for_domain(domain: String, content_width: float, content_height: float) -> Dictionary:
	var card_width := 185.0
	var card_height := 230.0
	match domain:
		"monster": card_width = 180.0; card_height = 176.0
		"product": card_width = 170.0; card_height = 150.0
		"role", "region": return {"columns": 1, "rows": 1, "entries_per_page": 1}
	var columns := clampi(int(floor(content_width / card_width)), 2, 5)
	var rows := clampi(int(floor(content_height / card_height)), 1, 4)
	return {"columns": columns, "rows": rows, "entries_per_page": maxi(1, columns * rows)}


func _navigation_data(can_step: bool, return_target: String, back_override: String = "") -> Dictionary:
	return {
		"prev_text": "上一个", "next_text": "下一个",
		"back_text": back_override if back_override != "" else _back_text(return_target),
		"prev_visible": can_step, "next_visible": can_step, "back_visible": true,
	}


func _back_text(return_target: String) -> String:
	match return_target:
		"compendium": return "返回图鉴"
		"intel": return "返回情报档案"
		"economy": return "返回经济总览"
		"standings": return "返回局势"
		"game": return "返回牌桌"
	return "返回主菜单"


func _result(title: String, body: String, page: Dictionary) -> Dictionary:
	return {"valid": true, "title": title, "body": body, "page": page.duplicate(true)}


func _dependencies_ready() -> bool:
	return _role_catalog() != null and _role_source() != null and _codex_snapshot() != null \
		and _card_source() != null and _card_snapshot() != null \
		and _monster_source() != null and _monster_snapshot() != null \
		and _product_source() != null and _product_snapshot() != null and _region_source() != null


func _role_catalog() -> RoleCatalogRuntimeService: return get_node_or_null(role_catalog_path) as RoleCatalogRuntimeService
func _role_source() -> RoleCodexPublicSourceService: return get_node_or_null(role_source_path) as RoleCodexPublicSourceService
func _codex_snapshot() -> CodexPublicSnapshotService: return get_node_or_null(codex_snapshot_path) as CodexPublicSnapshotService
func _card_source() -> CardCodexPublicSourceService: return get_node_or_null(card_source_path) as CardCodexPublicSourceService
func _card_snapshot() -> CardCodexPublicSnapshotService: return get_node_or_null(card_snapshot_path) as CardCodexPublicSnapshotService
func _monster_source() -> MonsterCodexPublicSourceService: return get_node_or_null(monster_source_path) as MonsterCodexPublicSourceService
func _monster_snapshot() -> MonsterCodexPublicSnapshotService: return get_node_or_null(monster_snapshot_path) as MonsterCodexPublicSnapshotService
func _product_source() -> ProductCodexPublicSourceService: return get_node_or_null(product_source_path) as ProductCodexPublicSourceService
func _product_snapshot() -> ProductCodexPublicSnapshotService: return get_node_or_null(product_snapshot_path) as ProductCodexPublicSnapshotService
func _region_source() -> RegionCodexPublicSourceService: return get_node_or_null(region_source_path) as RegionCodexPublicSourceService


func _is_pure_data(value: Variant) -> bool:
	if value is Callable or typeof(value) == TYPE_OBJECT:
		return false
	if value is Dictionary:
		for key_variant: Variant in value:
			if not _is_pure_data(key_variant) or not _is_pure_data(value[key_variant]):
				return false
	elif value is Array:
		for item_variant: Variant in value:
			if not _is_pure_data(item_variant):
				return false
	return true


func _short_text(value: String, limit: int) -> String:
	return value if limit <= 0 or value.length() <= limit else value.substr(0, maxi(0, limit - 1)) + "…"
