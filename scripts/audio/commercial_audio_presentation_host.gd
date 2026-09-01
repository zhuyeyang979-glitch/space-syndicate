extends Node
class_name CommercialAudioPresentationHost

signal sound_cue_routed(result: Dictionary)
signal sound_cue_silenced(result: Dictionary)
signal sound_cue_rejected(result: Dictionary)

const MENU_CANCEL_BUTTON_TOKENS := ["back", "cancel", "close"]
const SOUND_CUE_ROUTE_PATH := "res://data/presentation/v076_sound_cue_routes.json"
const CANONICAL_EVENT_ROUTE := "CANONICAL_EVENT"
const SILENT_REGISTERED_PLACEHOLDER := "SILENT_REGISTERED_PLACEHOLDER"
const REQUIRED_SOUND_CUE_COUNT := 15
const REGISTERED_SOUND_CUE_ROUTE_COUNT := 25
const ANIMATION_CATALOG_SOUND_CUE_COUNT := 23
const MUSIC_BUS := &"Music"
const RECEIPT_CONDITIONED_SCOPE := "reference_only_until_v07_receipt"
const AUDIO_SETTINGS_BUS_KEYS := {
	"Master": "master_volume",
	"Music": "music_volume",
	"SFX": "sfx_volume",
}
const DIRECTOR_SOUND_SIGNAL := &"sound_cue_requested"

@export var catalog: CardIllustrationCatalogResource
@export var player_card_dock_path: NodePath
@export var menu_overlay_path: NodePath
@export var animation_director_path: NodePath

@onready var _event_bus: AudioEventBus = %AudioEventBus
@onready var _sfx_service: CommercialAudioPresentationService = %CommercialAudioPresentationService
@onready var _music_controller: CommercialMusicPresentationController = %CommercialMusicPresentationController

var _player_card_dock: Node
var _menu_overlay: Control
var _animation_director: Node
var _sound_cue_routes: Dictionary = {}
var _required_sound_cue_ids: Array[String] = []
var _sound_cue_route_contract_id := ""
var _sound_cue_routes_ready := false
var _sound_cue_route_failure_reason := "not_loaded"
var _silent_placeholder_registered := false
var _receipt_conditioned_route_count := 0
var _bound_menu_button_count := 0
var _menu_has_been_presented := false
var _director_bind_count := 0
var _director_bind_rejection_count := 0
var _sound_cue_request_count := 0
var _sound_cue_routed_count := 0
var _sound_cue_silenced_count := 0
var _sound_cue_rejection_count := 0
var _audio_settings_apply_count := 0
var _audio_settings_rejection_count := 0
var _last_sound_cue_id := ""
var _last_canonical_event_id := ""
var _last_sound_cue_result: Dictionary = {}
var _last_audio_settings: Dictionary = {}


func _ready() -> void:
	_sfx_service.set_catalog_resource(catalog)
	_sfx_service.set_allowed_asset_scope_prefix("production_safe_")
	_music_controller.set_catalog_resource(catalog)
	_sfx_service.bind_event_bus(_event_bus)
	_configure_audio_buses()
	_load_sound_cue_routes()
	_bind_player_card_dock()
	_bind_menu_overlay()
	_bind_configured_animation_director()
	call_deferred("_sync_menu_music")


func emit_presentation_event(event_id: String, payload: Dictionary = {}) -> Dictionary:
	return _event_bus.emit_audio_event(event_id, payload)


func bind_animation_director(animation_director: Node) -> bool:
	var callback := Callable(self, "_on_sound_cue_requested")
	if (
		_animation_director != null
		and is_instance_valid(_animation_director)
		and _animation_director.has_signal(DIRECTOR_SOUND_SIGNAL)
		and _animation_director.is_connected(DIRECTOR_SOUND_SIGNAL, callback)
	):
		_animation_director.disconnect(DIRECTOR_SOUND_SIGNAL, callback)
	_animation_director = null
	if animation_director == null or not animation_director.has_signal(DIRECTOR_SOUND_SIGNAL):
		_director_bind_rejection_count += 1
		return false
	_animation_director = animation_director
	if not _animation_director.is_connected(DIRECTOR_SOUND_SIGNAL, callback):
		_animation_director.connect(DIRECTOR_SOUND_SIGNAL, callback)
	_director_bind_count += 1
	return true


func consume_animation_cue(cue: Dictionary) -> Dictionary:
	return route_sound_cue(str(cue.get("sound_cue_id", "")), cue)


func route_sound_cue(sound_cue_id: String, context: Dictionary = {}) -> Dictionary:
	_sound_cue_request_count += 1
	var normalized := sound_cue_id.strip_edges().to_upper()
	_last_sound_cue_id = normalized
	if normalized.is_empty():
		return _reject_sound_cue(normalized, "sound_cue_id_missing")
	if not _sound_cue_routes_ready:
		return _reject_sound_cue(
			normalized,
			"sound_cue_routes_not_ready:%s" % _sound_cue_route_failure_reason
		)
	var route_variant: Variant = _sound_cue_routes.get(normalized)
	if not (route_variant is Dictionary):
		return _silence_sound_cue(normalized, "sound_cue_route_missing")
	var route: Dictionary = route_variant
	var route_mode := str(route.get("route_mode", ""))
	if route_mode == SILENT_REGISTERED_PLACEHOLDER:
		return _silence_sound_cue(normalized, "registered_silent_route")
	if route_mode != CANONICAL_EVENT_ROUTE:
		return _reject_sound_cue(normalized, "sound_cue_route_mode_invalid")
	var canonical_event_id := _canonical_event_for_route(route, context)
	if canonical_event_id.is_empty() or not _commercial_event_registered(canonical_event_id):
		return _reject_sound_cue(normalized, "canonical_audio_event_unregistered")
	if (
		bool(route.get("requires_receipt_identity_sha256", false))
		and _context_value(context, "receipt_id").is_empty()
	):
		return _reject_sound_cue(normalized, "receipt_identity_missing_for_conditioned_route")
	var payload := _public_sound_cue_payload(normalized, context)
	var play_count_before := int(_sfx_service.debug_snapshot().get("play_count", 0))
	var public_event := _event_bus.emit_audio_event(canonical_event_id, payload)
	var service_debug := _sfx_service.debug_snapshot()
	if (
		str(public_event.get("mode", "")) != "commercial"
		or int(service_debug.get("play_count", 0)) != play_count_before + 1
	):
		return _reject_sound_cue(
			normalized,
			"commercial_audio_playback_rejected:%s" % str(
				service_debug.get("last_failure_reason", "unknown")
			)
		)
	_sound_cue_routed_count += 1
	_last_canonical_event_id = canonical_event_id
	var result := {
		"accepted": true,
		"sound_cue_id": normalized,
		"route_mode": CANONICAL_EVENT_ROUTE,
		"canonical_event_id": canonical_event_id,
		"asset_key": str(public_event.get("asset_key", "")),
		"silent": false,
		"presentation_only": true,
		"rules_rng_draw_count": 0,
		"gameplay_mutation_count": 0,
	}
	_last_sound_cue_result = result.duplicate(true)
	sound_cue_routed.emit(result.duplicate(true))
	return result


func request_public_music_state(public_state: String) -> bool:
	return _music_controller.request_public_state(public_state)


func apply_presentation_settings(snapshot: Dictionary) -> Dictionary:
	if snapshot.has("instant_test_mode"):
		return _reject_audio_settings("instant_test_mode_production_unreachable")
	var normalized: Dictionary = {}
	for bus_name_variant in AUDIO_SETTINGS_BUS_KEYS.keys():
		var bus_name := str(bus_name_variant)
		var setting_key := str(AUDIO_SETTINGS_BUS_KEYS.get(bus_name_variant, ""))
		if not snapshot.has(setting_key):
			return _reject_audio_settings("audio_setting_missing:%s" % setting_key)
		var value_variant: Variant = snapshot.get(setting_key)
		if typeof(value_variant) not in [TYPE_FLOAT, TYPE_INT]:
			return _reject_audio_settings("audio_setting_type_invalid:%s" % setting_key)
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index < 0:
			return _reject_audio_settings("audio_bus_missing:%s" % bus_name)
		normalized[setting_key] = clampf(float(value_variant), 0.0, 1.0)
	for bus_name_variant in AUDIO_SETTINGS_BUS_KEYS.keys():
		var bus_name := str(bus_name_variant)
		var setting_key := str(AUDIO_SETTINGS_BUS_KEYS.get(bus_name_variant, ""))
		var linear := float(normalized.get(setting_key, 1.0))
		AudioServer.set_bus_volume_db(
			AudioServer.get_bus_index(bus_name),
			linear_to_db(maxf(linear, 0.0001))
		)
	_audio_settings_apply_count += 1
	_last_audio_settings = normalized.duplicate(true)
	return {
		"accepted": true,
		"reason_code": "presentation_audio_settings_applied",
		"snapshot": normalized.duplicate(true),
		"presentation_only": true,
		"rules_rng_draw_count": 0,
		"gameplay_mutation_count": 0,
	}


func debug_snapshot() -> Dictionary:
	return {
		"catalog_bound": catalog != null,
		"player_card_dock_bound": _player_card_dock != null,
		"menu_overlay_bound": _menu_overlay != null,
		"bound_menu_button_count": _bound_menu_button_count,
		"animation_director_bound": _animation_director != null,
		"animation_director_signal": str(DIRECTOR_SOUND_SIGNAL),
		"director_bind_count": _director_bind_count,
		"director_bind_rejection_count": _director_bind_rejection_count,
		"sound_cue_route_contract_id": _sound_cue_route_contract_id,
		"sound_cue_routes_ready": _sound_cue_routes_ready,
		"sound_cue_route_failure_reason": _sound_cue_route_failure_reason,
		"sound_cue_route_count": _sound_cue_routes.size(),
		"receipt_conditioned_route_count": _receipt_conditioned_route_count,
		"required_sound_cue_count": _required_sound_cue_ids.size(),
		"required_sound_cue_coverage_percent": (
			100.0
			if _sound_cue_routes_ready and _required_sound_cue_ids.size() == REQUIRED_SOUND_CUE_COUNT
			else 0.0
		),
		"silent_placeholder_registered": _silent_placeholder_registered,
		"sound_cue_request_count": _sound_cue_request_count,
		"sound_cue_routed_count": _sound_cue_routed_count,
		"sound_cue_silenced_count": _sound_cue_silenced_count,
		"sound_cue_rejection_count": _sound_cue_rejection_count,
		"audio_settings_apply_count": _audio_settings_apply_count,
		"audio_settings_rejection_count": _audio_settings_rejection_count,
		"last_audio_settings": _last_audio_settings.duplicate(true),
		"last_sound_cue_id": _last_sound_cue_id,
		"last_canonical_event_id": _last_canonical_event_id,
		"last_sound_cue_result": _last_sound_cue_result.duplicate(true),
		"music_bus_present": AudioServer.get_bus_index(MUSIC_BUS) >= 0,
		"production_registry_connected": true,
		"presentation_only": true,
		"rules_rng_draw_count": 0,
		"save_persisted": false,
		"mutates_gameplay": false,
		"sfx": _sfx_service.debug_snapshot(),
		"music": _music_controller.debug_snapshot(),
	}


func sound_cue_route_snapshot() -> Dictionary:
	var route_ids := _sound_cue_routes.keys()
	route_ids.sort()
	return {
		"contract_id": _sound_cue_route_contract_id,
		"ready": _sound_cue_routes_ready,
		"failure_reason": _sound_cue_route_failure_reason,
		"required_sound_cue_ids": _required_sound_cue_ids.duplicate(),
		"route_ids": route_ids,
		"receipt_conditioned_route_count": _receipt_conditioned_route_count,
		"silent_placeholder_registered": _silent_placeholder_registered,
		"presentation_only": true,
		"rules_rng_draw_count": 0,
		"gameplay_mutation_count": 0,
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


func _bind_configured_animation_director() -> void:
	if animation_director_path.is_empty():
		return
	var director := get_node_or_null(animation_director_path)
	if director != null:
		bind_animation_director(director)


func _configure_audio_buses() -> void:
	for node in _music_controller.find_children("*", "AudioStreamPlayer", true, false):
		var player := node as AudioStreamPlayer
		if player != null:
			player.bus = MUSIC_BUS


func _load_sound_cue_routes() -> void:
	_sound_cue_routes.clear()
	_required_sound_cue_ids.clear()
	_sound_cue_route_contract_id = ""
	_sound_cue_routes_ready = false
	_silent_placeholder_registered = false
	_receipt_conditioned_route_count = 0
	_sound_cue_route_failure_reason = "route_contract_parse_failed"
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(SOUND_CUE_ROUTE_PATH)
	)
	if not (parsed is Dictionary):
		return
	var contract: Dictionary = parsed
	if (
		int(contract.get("schema_version", 0)) != 1
		or str(contract.get("contract_id", ""))
			!= "space_syndicate.v076.sound_cue_routes.v1"
		or not bool(contract.get("presentation_only", false))
		or bool(contract.get("randomize", true))
		or int(contract.get("catalog_sound_cue_count", 0))
			!= ANIMATION_CATALOG_SOUND_CUE_COUNT
		or int(contract.get("registered_route_count", 0))
			!= REGISTERED_SOUND_CUE_ROUTE_COUNT
		or str(contract.get("unknown_route_policy", ""))
			!= SILENT_REGISTERED_PLACEHOLDER
		or int(contract.get("rules_rng_draw_count", -1)) != 0
		or int(contract.get("gameplay_mutation_count", -1)) != 0
	):
		_sound_cue_route_failure_reason = "route_contract_header_invalid"
		return
	_sound_cue_route_contract_id = str(contract.get("contract_id", ""))
	var placeholder_variant: Variant = contract.get("silent_placeholder", {})
	_silent_placeholder_registered = (
		placeholder_variant is Dictionary
		and str((placeholder_variant as Dictionary).get("route_mode", ""))
			== SILENT_REGISTERED_PLACEHOLDER
		and bool((placeholder_variant as Dictionary).get("registered", false))
	)
	if not _silent_placeholder_registered:
		_sound_cue_route_failure_reason = "silent_placeholder_not_registered"
		return
	var required_variant: Variant = contract.get("required_sound_cue_ids", [])
	if not (required_variant is Array):
		_sound_cue_route_failure_reason = "required_sound_cue_ids_invalid"
		return
	for sound_cue_variant in required_variant as Array:
		var sound_cue_id := str(sound_cue_variant).strip_edges().to_upper()
		if (
			sound_cue_id.is_empty()
			or not sound_cue_id.ends_with("_SFX")
			or _required_sound_cue_ids.has(sound_cue_id)
		):
			_sound_cue_route_failure_reason = "required_sound_cue_id_invalid"
			return
		_required_sound_cue_ids.append(sound_cue_id)
	if _required_sound_cue_ids.size() != REQUIRED_SOUND_CUE_COUNT:
		_sound_cue_route_failure_reason = "required_sound_cue_count_invalid"
		return
	var routes_variant: Variant = contract.get("routes", [])
	if not (routes_variant is Array):
		_sound_cue_route_failure_reason = "sound_cue_routes_invalid"
		return
	for route_variant in routes_variant as Array:
		if not (route_variant is Dictionary):
			_sound_cue_route_failure_reason = "sound_cue_route_row_invalid"
			return
		var route: Dictionary = (route_variant as Dictionary).duplicate(true)
		var sound_cue_id := str(route.get("sound_cue_id", "")).strip_edges()
		var route_mode := str(route.get("route_mode", ""))
		if (
			sound_cue_id.is_empty()
			or sound_cue_id != sound_cue_id.to_upper()
			or not sound_cue_id.ends_with("_SFX")
			or _sound_cue_routes.has(sound_cue_id)
			or not [CANONICAL_EVENT_ROUTE, SILENT_REGISTERED_PLACEHOLDER].has(route_mode)
			or not _route_events_are_registered(route)
		):
			_sound_cue_route_failure_reason = "sound_cue_route_binding_invalid:%s" % sound_cue_id
			return
		_sound_cue_routes[sound_cue_id] = route
		if bool(route.get("requires_receipt_identity_sha256", false)):
			_receipt_conditioned_route_count += 1
	if _sound_cue_routes.size() != REGISTERED_SOUND_CUE_ROUTE_COUNT:
		_sound_cue_route_failure_reason = "registered_sound_cue_route_count_invalid"
		return
	for required_id in _required_sound_cue_ids:
		if not _sound_cue_routes.has(required_id):
			_sound_cue_route_failure_reason = "required_sound_cue_route_missing:%s" % required_id
			return
	_sound_cue_routes_ready = true
	_sound_cue_route_failure_reason = ""


func _route_events_are_registered(route: Dictionary) -> bool:
	var route_mode := str(route.get("route_mode", ""))
	if route_mode == SILENT_REGISTERED_PLACEHOLDER:
		return bool(route.get("registered", false))
	if route_mode != CANONICAL_EVENT_ROUTE:
		return false
	var requires_receipt := bool(route.get("requires_receipt_identity_sha256", false))
	var canonical_event_id := str(route.get("canonical_event_id", "")).strip_edges()
	if (
		canonical_event_id.is_empty()
		or not _commercial_event_route_allowed(canonical_event_id, requires_receipt)
	):
		return false
	var variants_variant: Variant = route.get("canonical_event_by_selector", {})
	if not (variants_variant is Dictionary):
		return false
	for event_id_variant in (variants_variant as Dictionary).values():
		if not _commercial_event_route_allowed(str(event_id_variant), requires_receipt):
			return false
	return true


func _commercial_event_route_allowed(event_id: String, requires_receipt: bool) -> bool:
	if not _commercial_event_registered(event_id) or catalog == null:
		return false
	var definition := _event_bus.registry.call("event_definition", event_id) as Dictionary
	var asset_key := str(definition.get("asset_key", ""))
	var asset_scope := str(catalog.asset_scope_for_key(StringName(asset_key)))
	if asset_scope.begins_with("production_safe_"):
		return not requires_receipt
	return asset_scope == RECEIPT_CONDITIONED_SCOPE and requires_receipt


func _commercial_event_registered(event_id: String) -> bool:
	if _event_bus == null or _event_bus.registry == null:
		return false
	var definition := _event_bus.registry.call("event_definition", event_id) as Dictionary
	return (
		str(definition.get("canonical_id", "")) == event_id
		and str(definition.get("mode", "")) == "commercial"
		and not str(definition.get("asset_key", "")).is_empty()
	)


func _canonical_event_for_route(route: Dictionary, context: Dictionary) -> String:
	var fallback := str(route.get("canonical_event_id", "")).strip_edges()
	var selector_field := str(route.get("selector_field", "")).strip_edges()
	var variants_variant: Variant = route.get("canonical_event_by_selector", {})
	if selector_field.is_empty() or not (variants_variant is Dictionary):
		return fallback
	var selector_value := _context_value(context, selector_field).to_lower()
	if selector_value.is_empty():
		return fallback
	return str((variants_variant as Dictionary).get(selector_value, fallback)).strip_edges()


func _context_value(context: Dictionary, field_name: String) -> String:
	if context.has(field_name):
		return str(context.get(field_name, "")).strip_edges()
	for container_name in ["projection", "receipt", "payload", "canonical_payload"]:
		var nested_variant: Variant = context.get(container_name, {})
		if nested_variant is Dictionary and (nested_variant as Dictionary).has(field_name):
			return str((nested_variant as Dictionary).get(field_name, "")).strip_edges()
	return ""


func _public_sound_cue_payload(sound_cue_id: String, context: Dictionary) -> Dictionary:
	var receipt_id := _context_value(context, "receipt_id")
	return {
		"source": "v076_animation_director",
		"sound_cue_id": sound_cue_id,
		"animation_cue_id": str(context.get("cue_id", "")),
		"receipt_id_sha256": receipt_id.sha256_text() if not receipt_id.is_empty() else "",
		"route_contract_id": _sound_cue_route_contract_id,
		"presentation_only": true,
		"rules_rng_draw_count": 0,
		"gameplay_mutation_count": 0,
	}


func _silence_sound_cue(sound_cue_id: String, reason: String) -> Dictionary:
	_sound_cue_silenced_count += 1
	_last_canonical_event_id = ""
	var result := {
		"accepted": true,
		"sound_cue_id": sound_cue_id,
		"route_mode": SILENT_REGISTERED_PLACEHOLDER,
		"canonical_event_id": "",
		"asset_key": "",
		"silent": true,
		"registered_placeholder": _silent_placeholder_registered,
		"reason_code": reason,
		"presentation_only": true,
		"rules_rng_draw_count": 0,
		"gameplay_mutation_count": 0,
	}
	_last_sound_cue_result = result.duplicate(true)
	sound_cue_silenced.emit(result.duplicate(true))
	return result


func _reject_sound_cue(sound_cue_id: String, reason: String) -> Dictionary:
	_sound_cue_rejection_count += 1
	_last_canonical_event_id = ""
	var result := {
		"accepted": false,
		"sound_cue_id": sound_cue_id,
		"route_mode": "REJECTED",
		"canonical_event_id": "",
		"asset_key": "",
		"silent": true,
		"reason_code": reason,
		"presentation_only": true,
		"rules_rng_draw_count": 0,
		"gameplay_mutation_count": 0,
	}
	_last_sound_cue_result = result.duplicate(true)
	sound_cue_rejected.emit(result.duplicate(true))
	return result


func _reject_audio_settings(reason: String) -> Dictionary:
	_audio_settings_rejection_count += 1
	return {
		"accepted": false,
		"reason_code": reason,
		"snapshot": _last_audio_settings.duplicate(true),
		"presentation_only": true,
		"rules_rng_draw_count": 0,
		"gameplay_mutation_count": 0,
	}


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


func _on_sound_cue_requested(sound_cue_id: String, cue: Dictionary) -> void:
	route_sound_cue(sound_cue_id, cue)


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
