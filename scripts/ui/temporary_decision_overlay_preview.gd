extends Control
class_name SpaceSyndicateTemporaryDecisionOverlayPreview

signal preview_action_requested(action_id: String)

const FIXTURES_SCRIPT := preload("res://scripts/ui/temporary_decision_preview_fixtures.gd")
const DEFAULT_PREVIEW_ID := "monster_wager"

@onready var overlay_layer: CanvasLayer = %OverlayLayer
@onready var current_label: Label = %TemporaryDecisionPreviewCurrentLabel
@onready var fixture_label: Label = %TemporaryDecisionPreviewFixtureLabel
@onready var variant_label: Label = %TemporaryDecisionPreviewVariantLabel
@onready var expected_panel_label: Label = %TemporaryDecisionPreviewPanelLabel
@onready var action_count_label: Label = %TemporaryDecisionPreviewActionCountLabel
@onready var status_label: Label = %TemporaryDecisionPreviewStatusLabel
@onready var last_action_label: Label = %TemporaryDecisionPreviewActionLabel
@onready var monster_wager_button: Button = %MonsterWagerPreviewButton
@onready var discard_button: Button = %DiscardPreviewButton
@onready var monster_target_button: Button = %MonsterTargetPreviewButton
@onready var player_target_button: Button = %PlayerTargetPreviewButton
@onready var long_text_button: Button = %LongTextPreviewButton
@onready var disabled_action_button: Button = %DisabledActionPreviewButton
@onready var payload_edge_button: Button = %PayloadEdgePreviewButton
@onready var hide_button: Button = %HideOverlayPreviewButton

var _fixtures: RefCounted = FIXTURES_SCRIPT.new()
var _current_id := DEFAULT_PREVIEW_ID
var _current_variant := "base"
var _current_payload: Dictionary = {}
var _long_text_mode := false
var _disabled_action_mode := false
var _edge_payload_empty_next := true


func _ready() -> void:
	_connect_buttons()
	if overlay_layer != null and overlay_layer.has_signal("temporary_decision_action_requested"):
		overlay_layer.connect("temporary_decision_action_requested", Callable(self, "_on_overlay_action_requested"))
	show_preview_id(DEFAULT_PREVIEW_ID)


func preview_ids() -> Array:
	return _fixtures.call("preview_ids") as Array


func current_payload() -> Dictionary:
	return _current_payload.duplicate(true)


func show_preview_id(id: String) -> void:
	_current_id = id
	_current_variant = "base"
	_long_text_mode = false
	_disabled_action_mode = false
	_show_payload(_fixtures.call("fixture", id) as Dictionary, _fixtures.call("preview_label", id) as String, _current_variant)


func show_long_text_stress() -> void:
	_long_text_mode = true
	_disabled_action_mode = false
	_current_variant = "long_text"
	_show_payload(_fixtures.call("long_text_fixture", _current_id) as Dictionary, "%s｜长文本" % (_fixtures.call("preview_label", _current_id) as String), _current_variant)


func show_disabled_action_stress() -> void:
	_disabled_action_mode = true
	_long_text_mode = false
	_current_variant = "disabled_action"
	_show_payload(_fixtures.call("disabled_action_fixture", _current_id) as Dictionary, "%s｜禁用按钮" % (_fixtures.call("preview_label", _current_id) as String), _current_variant)


func show_payload_edge_case() -> void:
	if _edge_payload_empty_next:
		show_empty_payload()
	else:
		show_malformed_payload()
	_edge_payload_empty_next = not _edge_payload_empty_next


func show_empty_payload() -> void:
	_current_payload = {}
	_current_variant = "empty_payload"
	if overlay_layer != null and overlay_layer.has_method("show_temporary_decision"):
		overlay_layer.call("show_temporary_decision", {})
	_update_labels("空 payload", "Overlay hidden", {})


func show_malformed_payload() -> void:
	_current_variant = "malformed_payload"
	_show_payload(_fixtures.call("malformed_fixture") as Dictionary, "异常 payload", _current_variant)


func hide_overlay() -> void:
	if overlay_layer != null and overlay_layer.has_method("hide_confirm"):
		overlay_layer.call("hide_confirm")
	_update_labels("隐藏", "Overlay hidden", _current_payload)


func _connect_buttons() -> void:
	_connect_button(monster_wager_button, "_on_monster_wager_pressed")
	_connect_button(discard_button, "_on_discard_pressed")
	_connect_button(monster_target_button, "_on_monster_target_pressed")
	_connect_button(player_target_button, "_on_player_target_pressed")
	_connect_button(long_text_button, "show_long_text_stress")
	_connect_button(disabled_action_button, "show_disabled_action_stress")
	_connect_button(payload_edge_button, "show_payload_edge_case")
	_connect_button(hide_button, "hide_overlay")


func _connect_button(button: Button, method_name: String) -> void:
	if button != null:
		button.pressed.connect(Callable(self, method_name))


func _show_payload(payload: Dictionary, label: String, variant: String = "base") -> void:
	_current_payload = payload.duplicate(true)
	_current_variant = variant
	if overlay_layer != null and overlay_layer.has_method("show_temporary_decision"):
		overlay_layer.call("show_temporary_decision", _current_payload)
	_update_labels(label, "Overlay visible", _current_payload)


func _update_labels(current_text: String, status_text: String, payload: Dictionary) -> void:
	if current_label != null:
		current_label.text = "当前：%s" % current_text
	if fixture_label != null:
		fixture_label.text = "Fixture: %s" % _fixture_id_for(payload)
	if variant_label != null:
		variant_label.text = "Variant: %s" % _current_variant
	if expected_panel_label != null:
		expected_panel_label.text = "Panel: %s" % _expected_panel_for(payload)
	if action_count_label != null:
		action_count_label.text = _action_count_text(payload)
	if status_label != null:
		status_label.text = status_text


func _fixture_id_for(payload: Dictionary) -> String:
	if payload.is_empty():
		return "empty_payload"
	return str(payload.get("kind", payload.get("id", "unknown")))


func _expected_panel_for(payload: Dictionary) -> String:
	match str(payload.get("kind", "")):
		"monster_wager":
			return "Monster Wager Panel"
		"discard_purchase", "monster_target_choice", "player_target_choice":
			return "Temporary Choice Panel"
		"":
			return "None"
	return "ConfirmPanel fallback"


func _action_count_text(payload: Dictionary) -> String:
	var actions: Array = payload.get("actions", []) if payload.get("actions", []) is Array else []
	var enabled_count := 0
	for action_variant in actions:
		if action_variant is Dictionary and not bool((action_variant as Dictionary).get("disabled", false)):
			enabled_count += 1
	return "Actions: %d / enabled %d" % [actions.size(), enabled_count]


func _on_monster_wager_pressed() -> void:
	show_preview_id("monster_wager")


func _on_discard_pressed() -> void:
	show_preview_id("discard_purchase")


func _on_monster_target_pressed() -> void:
	show_preview_id("monster_target_choice")


func _on_player_target_pressed() -> void:
	show_preview_id("player_target_choice")


func _on_overlay_action_requested(action_id: String) -> void:
	if last_action_label != null:
		last_action_label.text = "Last action: %s" % action_id
	preview_action_requested.emit(action_id)
