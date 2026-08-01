extends Node
class_name CommercialAudioPresentationService

signal event_played(canonical_event_id: String, asset_key: StringName)
signal event_rejected(canonical_event_id: String, reason: String)

const CONTRACT_PATH := "res://resources/audio/commercial/commercial_audio_event_map.json"

@export var catalog: CardIllustrationCatalogResource
@export var audio_enabled := true
@export var allowed_asset_scope_prefix := ""

@onready var _player: AudioStreamPlayer = %SfxPlayer

var _events_by_id: Dictionary = {}
var _contract_ready := false
var _event_bus: AudioEventBus
var _request_count := 0
var _play_count := 0
var _rejection_count := 0
var _last_asset_key := ""
var _last_canonical_event_id := ""
var _last_failure_reason := "not_ready"


func _ready() -> void:
	_load_contract()


func set_catalog_resource(value: CardIllustrationCatalogResource) -> void:
	catalog = value


func set_allowed_asset_scope_prefix(value: String) -> void:
	allowed_asset_scope_prefix = value.strip_edges()


func bind_event_bus(event_bus: AudioEventBus) -> bool:
	if event_bus == null:
		_last_failure_reason = "event_bus_missing"
		return false
	if _event_bus != null and _event_bus.audio_event_emitted.is_connected(_on_audio_event_emitted):
		_event_bus.audio_event_emitted.disconnect(_on_audio_event_emitted)
	_event_bus = event_bus
	if not _event_bus.audio_event_emitted.is_connected(_on_audio_event_emitted):
		_event_bus.audio_event_emitted.connect(_on_audio_event_emitted)
	return true


func unbind_event_bus() -> void:
	if _event_bus != null and _event_bus.audio_event_emitted.is_connected(_on_audio_event_emitted):
		_event_bus.audio_event_emitted.disconnect(_on_audio_event_emitted)
	_event_bus = null


func play_event(canonical_event_id: String, public_event: Dictionary = {}) -> bool:
	_request_count += 1
	var normalized := canonical_event_id.strip_edges()
	if public_event.has("canonical_id"):
		normalized = str(public_event.get("canonical_id", "")).strip_edges()
	if not _contract_ready or not _events_by_id.has(normalized):
		return _reject(normalized, "event_not_in_contract")
	if not audio_enabled:
		return _reject(normalized, "audio_disabled")
	if catalog == null:
		return _reject(normalized, "catalog_missing")
	if _player == null:
		return _reject(normalized, "audio_player_missing")
	var metadata: Dictionary = _events_by_id[normalized]
	var asset_key := str(metadata.get("asset_key", ""))
	if public_event.has("asset_key") and str(public_event.get("asset_key", "")) != asset_key:
		return _reject(normalized, "event_asset_key_mismatch")
	var asset_scope := str(catalog.asset_scope_for_key(StringName(asset_key)))
	if not allowed_asset_scope_prefix.is_empty() and not asset_scope.begins_with(allowed_asset_scope_prefix):
		return _reject(normalized, "asset_scope_not_allowed")
	var stream_resource := catalog.resource_for_asset_key(StringName(asset_key))
	if stream_resource == null:
		return _reject(normalized, "catalog_asset_missing")
	if catalog.asset_kind_for_key(StringName(asset_key)) != &"AudioStream" or not (stream_resource is AudioStream):
		return _reject(normalized, "catalog_asset_not_audio_stream")
	var stream := stream_resource as AudioStream
	var should_loop := bool(metadata.get("loop", false))
	if stream is AudioStreamOggVorbis and (stream as AudioStreamOggVorbis).loop != should_loop:
		return _reject(normalized, "stream_loop_contract_mismatch")
	_player.stop()
	_player.stream = stream
	_player.volume_db = float(metadata.get("volume_db", 0.0))
	_player.play()
	_play_count += 1
	_last_asset_key = asset_key
	_last_canonical_event_id = normalized
	_last_failure_reason = ""
	event_played.emit(normalized, StringName(asset_key))
	return true


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _contract_ready and _player != null,
		"contract_ready": _contract_ready,
		"catalog_bound": catalog != null,
		"event_bus_bound": _event_bus != null,
		"audio_enabled": audio_enabled,
		"allowed_asset_scope_prefix": allowed_asset_scope_prefix,
		"request_count": _request_count,
		"play_count": _play_count,
		"rejection_count": _rejection_count,
		"last_asset_key": _last_asset_key,
		"last_canonical_event_id": _last_canonical_event_id,
		"last_failure_reason": _last_failure_reason,
		"player_playing": _player != null and _player.playing,
		"fixed_single_file": true,
		"randomized_selection": false,
		"rules_rng_draw_count": 0,
		"presentation_only": true,
		"mutates_gameplay": false,
	}


func _load_contract() -> void:
	_events_by_id.clear()
	_contract_ready = false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
	if not (parsed is Dictionary):
		_last_failure_reason = "contract_parse_failed"
		return
	var contract: Dictionary = parsed
	if int(contract.get("schema_version", 0)) != 1 \
			or str(contract.get("contract_id", "")) != "space_syndicate.commercial_audio.events.v1" \
			or not bool(contract.get("presentation_only", false)) \
			or bool(contract.get("randomize", true)) \
			or int(contract.get("rules_rng_draw_count", -1)) != 0:
		_last_failure_reason = "contract_header_invalid"
		return
	var rows_variant: Variant = contract.get("events", [])
	if not (rows_variant is Array):
		_last_failure_reason = "contract_rows_invalid"
		return
	for row_variant in rows_variant as Array:
		if not (row_variant is Dictionary):
			_last_failure_reason = "contract_row_invalid"
			return
		var row: Dictionary = row_variant
		var event_id := str(row.get("event_id", "")).strip_edges()
		var asset_key := str(row.get("asset_key", "")).strip_edges()
		var volume_db := float(row.get("gain_db", NAN))
		if event_id.is_empty() or asset_key.is_empty() or _events_by_id.has(event_id) or not is_finite(volume_db):
			_last_failure_reason = "contract_binding_invalid"
			return
		_events_by_id[event_id] = {
			"asset_key": asset_key,
			"volume_db": volume_db,
			"loop": bool(row.get("loop", false)),
		}
	_contract_ready = _events_by_id.size() == 17
	_last_failure_reason = "" if _contract_ready else "contract_count_invalid"


func _on_audio_event_emitted(event_id: String, public_event: Dictionary) -> void:
	play_event(event_id, public_event)


func _reject(canonical_event_id: String, reason: String) -> bool:
	_rejection_count += 1
	_last_canonical_event_id = canonical_event_id
	_last_failure_reason = reason
	event_rejected.emit(canonical_event_id, reason)
	return false
