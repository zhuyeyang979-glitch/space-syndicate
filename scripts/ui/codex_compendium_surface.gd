extends VBoxContainer
class_name SpaceSyndicateCodexCompendiumSurface

signal action_requested(action_id: String, payload: Dictionary)

const VALID_MODES := ["compendium", "card", "monster", "product", "role", "region"]
const REQUIRED_CONTRACTS := {
	"CompendiumHubBoardPanel": "set_hub",
	"CardCodexBrowserPanel": "set_browser",
	"CardCodexDetailPanel": "set_detail",
	"BestiaryCodexBrowser": "set_browser",
	"BestiaryMonsterBoardPanel": "set_monster",
	"ProductCodexBrowser": "set_browser",
	"ProductCodexMarketBoardPanel": "set_product",
	"RoleCodexIdentityBoardPanel": "set_role",
	"RegionCodexTileBoardPanel": "set_region",
}

@onready var compendium_hub: Control = %CompendiumHubBoardPanel
@onready var card_browser: Control = %CardCodexBrowserPanel
@onready var card_detail: Control = %CardCodexDetailPanel
@onready var bestiary_browser: Control = %BestiaryCodexBrowser
@onready var bestiary_detail: Control = %BestiaryMonsterBoardPanel
@onready var monster_card_link: VBoxContainer = %BestiaryMonsterCardLink
@onready var monster_card_link_label: Label = %BestiaryMonsterCardLinkLabel
@onready var monster_card_link_button: Button = %BestiaryMonsterCardLinkButton
@onready var product_browser: Control = %ProductCodexBrowser
@onready var product_detail: Control = %ProductCodexMarketBoardPanel
@onready var role_detail: Control = %RoleCodexIdentityBoardPanel
@onready var region_detail: Control = %RegionCodexTileBoardPanel
@onready var empty_state: PanelContainer = %CodexEmptyState
@onready var empty_title: Label = %CodexEmptyTitle
@onready var empty_body: Label = %CodexEmptyBody

var _mode := ""
var _view := ""
var _last_page: Dictionary = {}
var _contract_errors: Array[String] = []
var _monster_card_name := ""


func _ready() -> void:
	_validate_contracts()
	_connect_surface_signals()
	_hide_all_surfaces()


func set_page(data: Dictionary) -> bool:
	_last_page = data.duplicate(true)
	_mode = str(data.get("mode", ""))
	_view = str(data.get("view", "browser"))
	_hide_all_surfaces()
	if not VALID_MODES.has(_mode):
		_show_empty({"title": "资料页不可用", "body": "未知资料页：%s" % _mode})
		visible = true
		return false
	if _view == "empty":
		_show_empty(data.get("empty", {}))
		visible = true
		return true
	var rendered := true
	match _mode:
		"compendium":
			rendered = _show_contract_surface(compendium_hub, "set_hub", data.get("hub", {}))
		"card":
			if _view == "detail":
				rendered = _show_contract_surface(card_detail, "set_detail", data.get("detail", {}))
			else:
				rendered = _show_contract_surface(card_browser, "set_browser", data.get("browser", {}))
		"monster":
			if _view == "detail":
				rendered = _show_contract_surface(bestiary_detail, "set_monster", data.get("detail", {}))
				_set_monster_card_link(data.get("monster_card_link", {}))
			else:
				rendered = _show_contract_surface(bestiary_browser, "set_browser", data.get("browser", {}))
		"product":
			if _view == "detail":
				rendered = _show_contract_surface(product_detail, "set_product", data.get("detail", {}))
			else:
				rendered = _show_contract_surface(product_browser, "set_browser", data.get("browser", {}))
		"role":
			rendered = _show_contract_surface(role_detail, "set_role", data.get("detail", {}))
		"region":
			rendered = _show_contract_surface(region_detail, "set_region", data.get("detail", {}))
	visible = true
	return rendered


func contracts_ready() -> bool:
	return _contract_errors.is_empty()


func debug_snapshot() -> Dictionary:
	return {
		"mode": _mode,
		"view": _view,
		"visible": visible,
		"contracts_ready": contracts_ready(),
		"contract_errors": _contract_errors.duplicate(),
		"visible_surfaces": _visible_surface_names(),
		"page_is_pure_data": _is_pure_data(_last_page),
	}


func _show_contract_surface(surface: Control, method_name: String, data_variant: Variant) -> bool:
	if surface == null or not surface.has_method(method_name):
		_show_empty({"title": "资料场景不可用", "body": "%s 缺少 %s 数据入口。" % [surface.name if surface != null else "Unknown", method_name]})
		return false
	var data := data_variant as Dictionary if data_variant is Dictionary else {}
	surface.visible = true
	surface.call(method_name, data.duplicate(true))
	return true


func _show_empty(data_variant: Variant) -> void:
	var data := data_variant as Dictionary if data_variant is Dictionary else {}
	empty_title.text = str(data.get("title", "资料页暂无内容"))
	empty_body.text = str(data.get("body", "当前没有可展示的公开资料。"))
	empty_state.visible = true


func _set_monster_card_link(data_variant: Variant) -> void:
	var data := data_variant as Dictionary if data_variant is Dictionary else {}
	_monster_card_name = str(data.get("card_name", ""))
	monster_card_link.visible = bool(data.get("visible", false)) and _monster_card_name != ""
	monster_card_link_label.text = str(data.get("label", "对应怪兽牌（属于卡牌图鉴）："))
	monster_card_link_button.text = str(data.get("button_text", "打开对应怪兽牌"))
	monster_card_link_button.tooltip_text = str(data.get("tooltip", ""))


func _hide_all_surfaces() -> void:
	for surface in [compendium_hub, card_browser, card_detail, bestiary_browser, bestiary_detail, monster_card_link, product_browser, product_detail, role_detail, region_detail, empty_state]:
		if surface != null:
			surface.visible = false
	_monster_card_name = ""


func _validate_contracts() -> void:
	_contract_errors.clear()
	var surfaces := _contract_surfaces()
	for node_name_variant: Variant in surfaces:
		var node_name := str(node_name_variant)
		var method_name := str(REQUIRED_CONTRACTS.get(node_name, ""))
		var node := surfaces.get(node_name) as Control
		if node == null or not node.has_method(method_name):
			var message := "%s must expose %s" % [node_name, method_name]
			_contract_errors.append(message)
			push_error("CodexCompendiumSurface: %s; generated fallbacks are disabled." % message)


func _contract_surfaces() -> Dictionary:
	return {
		"CompendiumHubBoardPanel": compendium_hub,
		"CardCodexBrowserPanel": card_browser,
		"CardCodexDetailPanel": card_detail,
		"BestiaryCodexBrowser": bestiary_browser,
		"BestiaryMonsterBoardPanel": bestiary_detail,
		"ProductCodexBrowser": product_browser,
		"ProductCodexMarketBoardPanel": product_detail,
		"RoleCodexIdentityBoardPanel": role_detail,
		"RegionCodexTileBoardPanel": region_detail,
	}


func _connect_surface_signals() -> void:
	compendium_hub.connect("action_requested", Callable(self, "_on_hub_action_requested"))
	card_browser.connect("filter_selected", Callable(self, "_on_card_filter_selected"))
	card_browser.connect("page_step_requested", Callable(self, "_on_card_page_step_requested"))
	card_browser.connect("card_preview_requested", Callable(self, "_on_card_preview_requested"))
	card_browser.connect("card_detail_requested", Callable(self, "_on_card_detail_requested"))
	bestiary_browser.connect("page_step_requested", Callable(self, "_on_monster_page_step_requested"))
	bestiary_browser.connect("entry_preview_requested", Callable(self, "_on_monster_preview_requested"))
	bestiary_browser.connect("entry_detail_requested", Callable(self, "_on_monster_detail_requested"))
	product_browser.connect("page_step_requested", Callable(self, "_on_product_page_step_requested"))
	product_browser.connect("entry_preview_requested", Callable(self, "_on_product_preview_requested"))
	product_browser.connect("entry_detail_requested", Callable(self, "_on_product_detail_requested"))
	monster_card_link_button.pressed.connect(_on_monster_card_link_pressed)


func _on_hub_action_requested(hub_action_id: String) -> void:
	action_requested.emit("hub_action", {"action_id": hub_action_id})


func _on_card_filter_selected(filter_id: String) -> void:
	action_requested.emit("card_filter", {"filter_id": filter_id})


func _on_card_page_step_requested(delta: int) -> void:
	action_requested.emit("card_page_step", {"delta": delta})


func _on_card_preview_requested(card_name: String) -> void:
	action_requested.emit("card_preview", {"card_name": card_name})


func _on_card_detail_requested(card_name: String) -> void:
	action_requested.emit("card_detail", {"card_name": card_name})


func _on_monster_page_step_requested(delta: int) -> void:
	action_requested.emit("monster_page_step", {"delta": delta})


func _on_monster_preview_requested(catalog_index: int) -> void:
	action_requested.emit("monster_preview", {"catalog_index": catalog_index})


func _on_monster_detail_requested(catalog_index: int) -> void:
	action_requested.emit("monster_detail", {"catalog_index": catalog_index})


func _on_product_page_step_requested(delta: int) -> void:
	action_requested.emit("product_page_step", {"delta": delta})


func _on_product_preview_requested(catalog_index: int) -> void:
	action_requested.emit("product_preview", {"catalog_index": catalog_index})


func _on_product_detail_requested(catalog_index: int) -> void:
	action_requested.emit("product_detail", {"catalog_index": catalog_index})


func _on_monster_card_link_pressed() -> void:
	if _monster_card_name != "":
		action_requested.emit("card_deep_link", {"card_name": _monster_card_name})


func _visible_surface_names() -> Array[String]:
	var names: Array[String] = []
	for surface in [compendium_hub, card_browser, card_detail, bestiary_browser, bestiary_detail, monster_card_link, product_browser, product_detail, role_detail, region_detail, empty_state]:
		if surface != null and surface.visible:
			names.append(surface.name)
	return names


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
