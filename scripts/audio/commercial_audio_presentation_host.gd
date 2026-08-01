extends Node
class_name CommercialAudioPresentationHost

const MENU_CANCEL_BUTTON_TOKENS := ["back", "cancel", "close"]

@export var catalog: CardIllustrationCatalogResource
@export var player_card_dock_path: NodePath
@export var menu_overlay_path: NodePath

@onready var _event_bus: AudioEventBus = %AudioEventBus
@onready var _sfx_service: CommercialAudioPresentationService = %CommercialAudioPresentationService
@onready var _music_controller: CommercialMusicPresentationController = %CommercialMusicPresentationController

var _player_card_dock: Node
var _menu_overlay: Control
var _bound_menu_button_count := 0
var _menu_has_been_presented := false


func _ready() -> void:
	_sfx_service.set_catalog_resource(catalog)
	_sfx_service.set_allowed_asset_scope_prefix("production_safe_")
	_music_controller.set_catalog_resource(catalog)
	_sfx_service.bind_event_bus(_event_bus)
	_bind_player_card_dock()
	_bind_menu_overlay()
	call_deferred("_sync_menu_music")


func emit_presentation_event(event_id: String, payload: Dictionary = {}) -> Dictionary:
	return _event_bus.emit_audio_event(event_id, payload)


func request_public_music_state(public_state: String) -> bool:
	return _music_controller.request_public_state(public_state)


func debug_snapshot() -> Dictionary:
	return {
		"catalog_bound": catalog != null,
		"player_card_dock_bound": _player_card_dock != null,
		"menu_overlay_bound": _menu_overlay != null,
		"bound_menu_button_count": _bound_menu_button_count,
		"production_registry_connected": true,
		"presentation_only": true,
		"rules_rng_draw_count": 0,
		"save_persisted": false,
		"mutates_gameplay": false,
		"sfx": _sfx_service.debug_snapshot(),
		"music": _music_controller.debug_snapshot(),
	}


func _bind_player_card_dock() -> void:
	_player_card_dock = get_node_or_null(player_card_dock_path) if not player_card_dock_path.is_empty() else null
	if _player_card_dock == null or not _player_card_dock.has_signal("presentation_audio_event_requested"):
		return
	var callback := Callable(self, "_on_presentation_audio_event_requested")
	if not _player_card_dock.is_connected("presentation_audio_event_requested", callback):
		_player_card_dock.connect("presentation_audio_event_requested", callback)


func _bind_menu_overlay() -> void:
	_menu_overlay = get_node_or_null(menu_overlay_path) as Control if not menu_overlay_path.is_empty() else null
	if _menu_overlay == null:
		return
	if not _menu_overlay.visibility_changed.is_connected(_sync_menu_music):
		_menu_overlay.visibility_changed.connect(_sync_menu_music)
	for node in _menu_overlay.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null:
			continue
		var hover_callback := Callable(self, "_on_menu_button_hovered")
		if not button.mouse_entered.is_connected(hover_callback):
			button.mouse_entered.connect(hover_callback)
		var pressed_callback := Callable(self, "_on_menu_button_pressed").bind(button.name)
		if not button.pressed.is_connected(pressed_callback):
			button.pressed.connect(pressed_callback)
		_bound_menu_button_count += 1


func _sync_menu_music() -> void:
	if _menu_overlay == null:
		return
	if _menu_overlay.visible:
		_menu_has_been_presented = true
		_music_controller.request_public_state("menu")
	elif _menu_has_been_presented:
		_music_controller.request_public_state("gameplay")
	else:
		_music_controller.stop_music()


func _on_presentation_audio_event_requested(event_id: String, payload: Dictionary) -> void:
	emit_presentation_event(event_id, payload)


func _on_menu_button_hovered() -> void:
	emit_presentation_event("ui.hover", {"surface": "menu_overlay"})


func _on_menu_button_pressed(button_name: StringName) -> void:
	var normalized := str(button_name).to_lower()
	var event_id := "ui.confirm"
	for token in MENU_CANCEL_BUTTON_TOKENS:
		if normalized.contains(token):
			event_id = "ui.cancel"
			break
	emit_presentation_event(event_id, {"surface": "menu_overlay"})
