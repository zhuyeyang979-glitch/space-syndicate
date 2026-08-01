extends Node
class_name CommercialMusicPresentationController

signal music_changed(public_state: String, asset_key: StringName)
signal music_rejected(requested_value: String, reason: String)

const CONTRACT_PATH := "res://resources/audio/commercial/commercial_music_playlist.json"
const SILENCE_DB := -80.0

@export var catalog: CardIllustrationCatalogResource
@export var music_enabled := true
@export_range(0.0, 10.0, 0.05) var crossfade_seconds := 1.5

@onready var _players: Array[AudioStreamPlayer] = [%PrimaryPlayer, %SecondaryPlayer]

var _tracks_by_state: Dictionary = {}
var _tracks_by_key: Dictionary = {}
var _contract_ready := false
var _active_index := -1
var _current_state := ""
var _current_asset_key := ""
var _transition_tween: Tween
var _request_count := 0
var _accepted_count := 0
var _crossfade_count := 0
var _rejection_count := 0
var _last_failure_reason := "not_ready"


func _ready() -> void:
	_load_contract()


func set_catalog_resource(value: CardIllustrationCatalogResource) -> void:
	catalog = value


func request_public_state(public_state: String) -> bool:
	_request_count += 1
	var normalized := public_state.strip_edges()
	if not _contract_ready or not _tracks_by_state.has(normalized):
		return _reject(normalized, "public_state_not_allowed")
	return _request_track(_tracks_by_state[normalized] as Dictionary)


func request_public_presentation_state(public_state: String) -> bool:
	return request_public_state(public_state)


func request_asset_key(asset_key: StringName) -> bool:
	_request_count += 1
	var normalized := str(asset_key).strip_edges()
	if not _contract_ready or not _tracks_by_key.has(normalized):
		return _reject(normalized, "asset_key_not_allowed")
	return _request_track(_tracks_by_key[normalized] as Dictionary)


func stop_music() -> void:
	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = null
	for player in _players:
		if player != null:
			player.stop()
			player.stream = null
			player.volume_db = SILENCE_DB
	_active_index = -1
	_current_state = ""
	_current_asset_key = ""


func debug_snapshot() -> Dictionary:
	var playing_count := 0
	for player in _players:
		if player != null and player.playing:
			playing_count += 1
	return {
		"controller_ready": _contract_ready and _players.size() == 2,
		"contract_ready": _contract_ready,
		"catalog_bound": catalog != null,
		"music_enabled": music_enabled,
		"crossfade_seconds": crossfade_seconds,
		"crossfade_active": _transition_tween != null and _transition_tween.is_valid() and _transition_tween.is_running(),
		"playing_player_count": playing_count,
		"active_player_index": _active_index,
		"current_public_state": _current_state,
		"current_asset_key": _current_asset_key,
		"request_count": _request_count,
		"accepted_count": _accepted_count,
		"crossfade_count": _crossfade_count,
		"rejection_count": _rejection_count,
		"last_failure_reason": _last_failure_reason,
		"reads_hidden_information": false,
		"rules_rng_draw_count": 0,
		"save_persisted": false,
		"presentation_only": true,
		"mutates_gameplay": false,
	}


func _request_track(track: Dictionary) -> bool:
	var public_state := str(track.get("public_state", ""))
	var asset_key := str(track.get("asset_key", ""))
	if not music_enabled:
		return _reject(public_state, "music_disabled")
	if catalog == null:
		return _reject(public_state, "catalog_missing")
	if asset_key == _current_asset_key and _active_index >= 0:
		_last_failure_reason = ""
		return true
	var stream_resource := catalog.resource_for_asset_key(StringName(asset_key))
	if stream_resource == null:
		return _reject(public_state, "catalog_asset_missing")
	if catalog.asset_kind_for_key(StringName(asset_key)) != &"AudioStream" or not (stream_resource is AudioStream):
		return _reject(public_state, "catalog_asset_not_audio_stream")
	var stream := stream_resource as AudioStream
	if stream is AudioStreamOggVorbis and not (stream as AudioStreamOggVorbis).loop:
		return _reject(public_state, "stream_loop_contract_mismatch")
	_finalize_interrupted_transition()
	var target_gain := float(track.get("volume_db", 0.0))
	if _active_index < 0:
		_active_index = 0
		var first_player := _players[_active_index]
		first_player.stream = stream
		first_player.volume_db = target_gain
		first_player.play()
	else:
		var previous_index := _active_index
		var next_index := 1 - previous_index
		var previous_player := _players[previous_index]
		var next_player := _players[next_index]
		var previous_gain := _volume_for_asset_key(_current_asset_key)
		next_player.stop()
		next_player.stream = stream
		next_player.volume_db = SILENCE_DB
		next_player.play()
		_transition_tween = create_tween()
		_transition_tween.tween_method(
			_apply_equal_power_crossfade.bind(previous_player, next_player, previous_gain, target_gain),
			0.0,
			1.0,
			crossfade_seconds
		)
		_transition_tween.finished.connect(_on_crossfade_finished.bind(previous_index, next_index, target_gain), CONNECT_ONE_SHOT)
		_active_index = next_index
		_crossfade_count += 1
	_current_state = public_state
	_current_asset_key = asset_key
	_accepted_count += 1
	_last_failure_reason = ""
	music_changed.emit(public_state, StringName(asset_key))
	return true


func _load_contract() -> void:
	_tracks_by_state.clear()
	_tracks_by_key.clear()
	_contract_ready = false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH))
	if not (parsed is Dictionary):
		_last_failure_reason = "contract_parse_failed"
		return
	var contract: Dictionary = parsed
	if int(contract.get("schema_version", 0)) != 1 \
			or str(contract.get("contract_id", "")) != "space_syndicate.commercial_music.playlist.v1" \
			or not bool(contract.get("presentation_only", false)) \
			or str(contract.get("crossfade_curve", "")) != "equal_power" \
			or bool(contract.get("hidden_information_dependency", true)) \
			or bool(contract.get("gameplay_effect", true)) \
			or bool(contract.get("save_persisted", true)) \
			or int(contract.get("rules_rng_draw_count", -1)) != 0:
		_last_failure_reason = "contract_header_invalid"
		return
	crossfade_seconds = float(contract.get("crossfade_seconds", 1.5))
	if not is_equal_approx(crossfade_seconds, 1.5):
		_last_failure_reason = "crossfade_contract_invalid"
		return
	var rows_variant: Variant = contract.get("tracks", [])
	if not (rows_variant is Array):
		_last_failure_reason = "contract_rows_invalid"
		return
	for row_variant in rows_variant as Array:
		if not (row_variant is Dictionary):
			_last_failure_reason = "contract_row_invalid"
			return
		var row: Dictionary = row_variant
		var public_state := str(row.get("state_id", "")).strip_edges()
		var asset_key := str(row.get("asset_key", "")).strip_edges()
		var volume_db := float(row.get("gain_db", NAN))
		if public_state.is_empty() or asset_key.is_empty() \
				or _tracks_by_state.has(public_state) or _tracks_by_key.has(asset_key) \
				or not is_finite(volume_db) or not bool(row.get("loop", false)):
			_last_failure_reason = "contract_binding_invalid"
			return
		var metadata := {
			"public_state": public_state,
			"asset_key": asset_key,
			"volume_db": volume_db,
			"loop": true,
		}
		_tracks_by_state[public_state] = metadata
		_tracks_by_key[asset_key] = metadata
	_contract_ready = _tracks_by_state.size() == 4 and _tracks_by_key.size() == 4
	_last_failure_reason = "" if _contract_ready else "contract_count_invalid"


func _finalize_interrupted_transition() -> void:
	if _transition_tween == null or not _transition_tween.is_valid():
		return
	_transition_tween.kill()
	_transition_tween = null
	for index in range(_players.size()):
		var player := _players[index]
		if index == _active_index:
			player.volume_db = _volume_for_asset_key(_current_asset_key)
		else:
			player.stop()
			player.stream = null
			player.volume_db = SILENCE_DB


func _on_crossfade_finished(previous_index: int, next_index: int, target_gain: float) -> void:
	if previous_index >= 0 and previous_index < _players.size():
		_players[previous_index].stop()
		_players[previous_index].stream = null
		_players[previous_index].volume_db = SILENCE_DB
	if next_index >= 0 and next_index < _players.size():
		_players[next_index].volume_db = target_gain
	_transition_tween = null


func _apply_equal_power_crossfade(
		progress: float,
		previous_player: AudioStreamPlayer,
		next_player: AudioStreamPlayer,
		previous_gain: float,
		target_gain: float
) -> void:
	var angle := clampf(progress, 0.0, 1.0) * PI * 0.5
	var previous_factor := maxf(cos(angle), 0.0001)
	var next_factor := maxf(sin(angle), 0.0001)
	previous_player.volume_db = maxf(SILENCE_DB, previous_gain + linear_to_db(previous_factor))
	next_player.volume_db = maxf(SILENCE_DB, target_gain + linear_to_db(next_factor))


func _volume_for_asset_key(asset_key: String) -> float:
	var row_variant: Variant = _tracks_by_key.get(asset_key)
	return float((row_variant as Dictionary).get("volume_db", 0.0)) if row_variant is Dictionary else 0.0


func _reject(requested_value: String, reason: String) -> bool:
	_rejection_count += 1
	_last_failure_reason = reason
	music_rejected.emit(requested_value, reason)
	return false
