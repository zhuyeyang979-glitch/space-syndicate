extends Node
class_name CommercialAudioPresentationService

signal event_played(canonical_event_id: String, asset_key: StringName)
signal event_rejected(canonical_event_id: String, reason: String)

const CONTRACT_PATH := "res://resources/audio/commercial/commercial_audio_event_map.json"
const VOICE_POOL_SIZE := 4
const SFX_BUS := &"SFX"
const RECEIPT_CONDITIONED_SCOPE := "reference_only_until_v07_receipt"
const V076_ANIMATION_SOURCE := "v076_animation_director"

@export var catalog: CardIllustrationCatalogResource
@export var audio_enabled := true
@export var allowed_asset_scope_prefix := ""

@onready var _primary_player: AudioStreamPlayer = %SfxPlayer

var _events_by_id: Dictionary = {}
var _voice_pool: Array[AudioStreamPlayer] = []
var _contract_ready := false
var _event_bus: AudioEventBus
var _next_voice_index := 0
var _request_count := 0
var _play_count := 0
var _rejection_count := 0
var _voice_steal_count := 0
var _receipt_conditioned_scope_play_count := 0
var _last_voice_index := -1
var _last_asset_key := ""
var _last_canonical_event_id := ""
var _last_failure_reason := "not_ready"


func _ready() -> void:
	_initialize_voice_pool()
	_load_contract()


func _exit_tree() -> void:
	## Release live one-shot streams before the isolated test/process tree exits.
	## This is presentation cleanup only; no authority state is persisted.
	for player in _voice_pool:
		if player == null or not is_instance_valid(player):
			continue
		player.stop()
		player.stream = null
	_voice_pool.clear()
	unbind_event_bus()


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
	if not _voice_pool_ready():
		return _reject(normalized, "audio_voice_pool_not_ready")
	var metadata: Dictionary = _events_by_id[normalized]
	var asset_key := str(metadata.get("asset_key", ""))
	if public_event.has("asset_key") and str(public_event.get("asset_key", "")) != asset_key:
		return _reject(normalized, "event_asset_key_mismatch")
	var asset_scope := str(catalog.asset_scope_for_key(StringName(asset_key)))
	var receipt_conditioned_scope := asset_scope == RECEIPT_CONDITIONED_SCOPE
	if not _asset_scope_allowed(asset_scope, public_event):
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
	var voice_selection := _acquire_voice()
	var player := voice_selection.get("player") as AudioStreamPlayer
	if player == null:
		return _reject(normalized, "audio_voice_unavailable")
	player.stream = stream
	player.volume_db = float(metadata.get("volume_db", 0.0))
	player.play()
	_play_count += 1
	if receipt_conditioned_scope:
		_receipt_conditioned_scope_play_count += 1
	_last_voice_index = int(voice_selection.get("index", -1))
	_last_asset_key = asset_key
	_last_canonical_event_id = normalized
	_last_failure_reason = ""
	event_played.emit(normalized, StringName(asset_key))
	return true


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _contract_ready and _voice_pool_ready(),
		"contract_ready": _contract_ready,
		"catalog_bound": catalog != null,
		"event_bus_bound": _event_bus != null,
		"audio_enabled": audio_enabled,
		"allowed_asset_scope_prefix": allowed_asset_scope_prefix,
		"request_count": _request_count,
		"play_count": _play_count,
		"rejection_count": _rejection_count,
		"voice_pool_size": _voice_pool.size(),
		"configured_voice_pool_size": VOICE_POOL_SIZE,
		"playing_voice_count": _playing_voice_count(),
		"next_voice_index": _next_voice_index,
		"last_voice_index": _last_voice_index,
		"voice_steal_count": _voice_steal_count,
		"receipt_conditioned_scope_play_count": _receipt_conditioned_scope_play_count,
		"sfx_bus": str(SFX_BUS),
		"sfx_bus_present": AudioServer.get_bus_index(SFX_BUS) >= 0,
		"last_asset_key": _last_asset_key,
		"last_canonical_event_id": _last_canonical_event_id,
		"last_failure_reason": _last_failure_reason,
		"player_playing": _playing_voice_count() > 0,
		"fixed_single_file": true,
		"voice_selection_policy": "idle_round_robin_then_oldest_slot_steal",
		"randomized_selection": false,
		"rules_rng_draw_count": 0,
		"presentation_only": true,
		"mutates_gameplay": false,
	}


func _initialize_voice_pool() -> void:
	_voice_pool.clear()
	_next_voice_index = 0
	_last_voice_index = -1
	if _primary_player == null:
		_last_failure_reason = "primary_audio_player_missing"
		return
	_primary_player.bus = SFX_BUS
	_voice_pool.append(_primary_player)
	for voice_index in range(1, VOICE_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SfxVoice%d" % (voice_index + 1)
		player.bus = SFX_BUS
		add_child(player)
		_voice_pool.append(player)


func _voice_pool_ready() -> bool:
	if _voice_pool.size() != VOICE_POOL_SIZE:
		return false
	for player in _voice_pool:
		if player == null or not is_instance_valid(player) or player.bus != SFX_BUS:
			return false
	return true


func _acquire_voice() -> Dictionary:
	if not _voice_pool_ready():
		return {}
	for offset in range(_voice_pool.size()):
		var candidate_index := (_next_voice_index + offset) % _voice_pool.size()
		var candidate := _voice_pool[candidate_index]
		if candidate.playing:
			continue
		_next_voice_index = (candidate_index + 1) % _voice_pool.size()
		return {"player": candidate, "index": candidate_index, "stolen": false}
	var stolen_index := _next_voice_index
	var stolen_player := _voice_pool[stolen_index]
	stolen_player.stop()
	_voice_steal_count += 1
	_next_voice_index = (stolen_index + 1) % _voice_pool.size()
	return {"player": stolen_player, "index": stolen_index, "stolen": true}


func _playing_voice_count() -> int:
	var count := 0
	for player in _voice_pool:
		if player != null and is_instance_valid(player) and player.playing:
			count += 1
	return count


func _asset_scope_allowed(asset_scope: String, public_event: Dictionary) -> bool:
	if allowed_asset_scope_prefix.is_empty() or asset_scope.begins_with(allowed_asset_scope_prefix):
		return true
	return (
		asset_scope == RECEIPT_CONDITIONED_SCOPE
		and _has_v076_receipt_evidence(public_event)
	)


func _has_v076_receipt_evidence(public_event: Dictionary) -> bool:
	var payload_variant: Variant = public_event.get("payload", {})
	if not (payload_variant is Dictionary):
		return false
	var payload: Dictionary = payload_variant
	var receipt_hash := str(payload.get("receipt_id_sha256", "")).strip_edges()
	return (
		str(payload.get("source", "")) == V076_ANIMATION_SOURCE
		and not str(payload.get("animation_cue_id", "")).strip_edges().is_empty()
		and str(payload.get("sound_cue_id", "")).ends_with("_SFX")
		and bool(payload.get("presentation_only", false))
		and int(payload.get("rules_rng_draw_count", -1)) == 0
		and int(payload.get("gameplay_mutation_count", -1)) == 0
		and _is_lower_hex_sha256(receipt_hash)
	)


func _is_lower_hex_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true


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
