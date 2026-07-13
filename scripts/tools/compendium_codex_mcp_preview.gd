extends Control
class_name CompendiumCodexMcpPreview

const FixturesScript := preload("res://scripts/tools/compendium_codex_mcp_preview_fixtures.gd")
const CardCodexBrowserScene := preload("res://scenes/ui/CardCodexBrowser.tscn")
const CardCodexDetailScene := preload("res://scenes/ui/CardCodexDetail.tscn")
const ProductCodexDetailScene := preload("res://scenes/ui/ProductCodexDetail.tscn")
const BestiaryDetailScene := preload("res://scenes/ui/BestiaryDetail.tscn")
const CompendiumHubScene := preload("res://scenes/ui/CompendiumHubBoard.tscn")

@onready var state_button_list: VBoxContainer = %CompendiumCodexStateButtonList
@onready var title_label: Label = %CompendiumCodexPreviewTitle
@onready var summary_label: Label = %CompendiumCodexPreviewSummary
@onready var component_label: Label = %CompendiumCodexPreviewComponentLabel
@onready var preview_host: Control = %CompendiumCodexPreviewHost

var _fixtures := FixturesScript.new()
var _current_fixture_id := ""
var _last_action_ids: Array[String] = []
var _last_preview_cards: Array[String] = []
var _last_detail_cards: Array[String] = []


func _ready() -> void:
	_build_fixture_buttons()
	var ids := fixture_ids()
	if not ids.is_empty():
		apply_fixture(ids[0])


func fixture_ids() -> Array[String]:
	return _fixtures.fixture_ids()


func current_fixture_id() -> String:
	return _current_fixture_id


func last_action_ids() -> Array[String]:
	return _last_action_ids.duplicate()


func last_preview_cards() -> Array[String]:
	return _last_preview_cards.duplicate()


func last_detail_cards() -> Array[String]:
	return _last_detail_cards.duplicate()


func apply_fixture(fixture_id: String) -> bool:
	var data := _fixtures.fixture(fixture_id)
	if data.is_empty() and fixture_id != "empty_payload_safe_state":
		return false
	_current_fixture_id = fixture_id
	_last_action_ids.clear()
	_last_preview_cards.clear()
	_last_detail_cards.clear()
	_show_fixture(data)
	return true


func fixture_payload(fixture_id: String) -> Dictionary:
	return _fixtures.fixture(fixture_id)


func _build_fixture_buttons() -> void:
	_clear_children(state_button_list)
	for fixture_id in fixture_ids():
		var button := Button.new()
		button.name = "%sButton" % fixture_id.to_pascal_case()
		button.text = fixture_id
		button.tooltip_text = "Show %s" % fixture_id
		button.custom_minimum_size = Vector2(0, 34)
		button.pressed.connect(func() -> void:
			apply_fixture(fixture_id)
		)
		state_button_list.add_child(button)


func _show_fixture(data: Dictionary) -> void:
	_clear_children(preview_host)
	title_label.text = str(data.get("title", "Compendium Codex Preview"))
	summary_label.text = str(data.get("summary", ""))
	component_label.text = "Fixture: %s | Component: %s" % [str(data.get("id", "")), str(data.get("expected_component", ""))]
	var view := str(data.get("view", "empty"))
	var payload: Dictionary = data.get("payload", {}) if data.get("payload", {}) is Dictionary else {}
	match view:
		"card_browser":
			var browser := CardCodexBrowserScene.instantiate() as Control
			preview_host.add_child(browser)
			_fill_host(browser)
			if browser.has_method("set_browser"):
				browser.call("set_browser", payload)
			if browser.has_signal("filter_selected"):
				browser.connect("filter_selected", _on_component_action_requested)
			if browser.has_signal("page_step_requested"):
				browser.connect("page_step_requested", func(delta: int) -> void:
					_last_action_ids.append("page_%d" % delta)
				)
			if browser.has_signal("card_preview_requested"):
				browser.connect("card_preview_requested", func(card_name: String) -> void:
					_last_preview_cards.append(card_name)
				)
			if browser.has_signal("card_detail_requested"):
				browser.connect("card_detail_requested", func(card_name: String) -> void:
					_last_detail_cards.append(card_name)
				)
		"card_detail":
			var detail := CardCodexDetailScene.instantiate() as Control
			preview_host.add_child(detail)
			_fill_host(detail)
			if detail.has_method("set_detail"):
				detail.call("set_detail", payload)
		"product_detail":
			var product := ProductCodexDetailScene.instantiate() as Control
			preview_host.add_child(product)
			_fill_host(product)
			if product.has_method("set_product"):
				product.call("set_product", payload)
		"bestiary_detail":
			var bestiary := BestiaryDetailScene.instantiate() as Control
			preview_host.add_child(bestiary)
			_fill_host(bestiary)
			if bestiary.has_method("set_monster"):
				bestiary.call("set_monster", payload)
		"compendium_hub":
			var hub := CompendiumHubScene.instantiate() as Control
			preview_host.add_child(hub)
			_fill_host(hub)
			if hub.has_method("set_hub"):
				hub.call("set_hub", payload)
			if hub.has_signal("action_requested"):
				hub.connect("action_requested", _on_component_action_requested)
		_:
			_render_empty_state(payload)


func _render_empty_state(_payload: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.name = "CompendiumCodexEmptyStateLayer"
	panel.custom_minimum_size = Vector2(440, 160)
	preview_host.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var label := Label.new()
	label.name = "CompendiumCodexEmptyStateLabel"
	label.text = "Empty codex payload | safe editor preview state"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("#bfdbfe"))
	margin.add_child(label)


func _fill_host(control: Control) -> void:
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _on_component_action_requested(action_id: String) -> void:
	_last_action_ids.append(action_id)


func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
