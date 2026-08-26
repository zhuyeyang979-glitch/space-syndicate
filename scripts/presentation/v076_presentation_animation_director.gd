extends "res://scripts/ui/showcase_director.gd"
class_name V076PresentationAnimationDirector

## The single receipt-to-animation boundary for the commercial presentation
## layer.  ShowcaseDirector remains the historical deterministic stage reader;
## this subclass adds receipt identity, cue lookup, privacy filtering and motion
## policy without creating a second gameplay or presentation authority.

const CUE_CATALOG_PATH := "res://data/presentation/v076_animation_cue_catalog.json"
const PresentationReceiptIdentity := preload(
	"res://scripts/v075/presentation/v075_presentation_receipt_identity_v2.gd"
)

signal cue_queued(cue: Dictionary)
signal cue_finished(cue: Dictionary)
signal sound_cue_requested(sound_cue_id: String, cue: Dictionary)

const PERFORMANCE_SAMPLE_LIMIT := 600
const OUTSIDE_LOADING_STALL_MS := 250.0
const FULL_MOTION_FLASH_LIMIT := 0.65
const REDUCED_MOTION_FLASH_LIMIT := 0.28

var _cue_catalog: Dictionary = {}
var _cue_by_id: Dictionary = {}
var _seen_receipt_ids: Dictionary = {}
var _queued_cues: Array[Dictionary] = []
var _finished_cues: Array[Dictionary] = []
var _receipt_duplicate_count := 0
var _receipt_collision_count := 0
var _receipt_rejection_count := 0
var _last_rejection_reason := "none"
var _reduced_motion := false
var _instant_test_mode := false
var _screen_shake_enabled := true
var _flash_intensity_limit := FULL_MOTION_FLASH_LIMIT
var _presentation_policy_apply_count := 0
var _presentation_policy_rejection_count := 0
var _loading_active := false
var _idle_frame_samples_ms: Array[float] = []
var _animation_frame_samples_ms: Array[float] = []
var _card_input_response_samples_ms: Array[float] = []
var _menu_input_response_samples_ms: Array[float] = []
var _outside_loading_stall_count := 0
var _animation_gameplay_mutation_count := 0
var _animation_rng_draw_delta := 0
var _animation_authority_sequence_delta := 0
var _animation_deck_order_mutation_count := 0
var _animation_card_zone_mutation_count := 0
var _animation_facility_state_mutation_count := 0


func _ready() -> void:
	super._ready()
	load_cue_catalog()
	set_process(true)


func _process(delta: float) -> void:
	record_performance_frame(
		maxf(0.0, delta * 1000.0),
		not _queued_cues.is_empty(),
		_loading_active
	)


func load_cue_catalog(path: String = CUE_CATALOG_PATH) -> bool:
	if path != CUE_CATALOG_PATH:
		return false
	var text := FileAccess.get_file_as_string(CUE_CATALOG_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return false
	_cue_catalog = parsed as Dictionary
	_cue_by_id.clear()
	for cue_variant in _cue_catalog.get("cues", []) as Array:
		if not (cue_variant is Dictionary):
			continue
		var cue := (cue_variant as Dictionary).duplicate(true)
		var cue_id := str(cue.get("cue_id", ""))
		if cue_id.is_empty() or _cue_by_id.has(cue_id):
			continue
		_cue_by_id[cue_id] = cue
	return not _cue_by_id.is_empty()


func set_motion_policy(reduced_motion: bool, instant_test_mode: bool = false) -> void:
	_reduced_motion = reduced_motion
	# Instant mode is a test-only capability and is never exposed by production
	# controls.  The director accepts it only from an explicit test caller.
	_instant_test_mode = instant_test_mode
	_flash_intensity_limit = (
		REDUCED_MOTION_FLASH_LIMIT
		if _reduced_motion
		else FULL_MOTION_FLASH_LIMIT
	)


func apply_presentation_policy(
	snapshot: Dictionary,
	allow_instant_test_mode: bool = false
) -> Dictionary:
	## Production callers use the default `allow_instant_test_mode=false`.
	## Focused fixtures may opt in explicitly without creating a player-facing
	## control or changing any authoritative result.
	var requested_instant := bool(snapshot.get("instant_test_mode", false))
	if requested_instant and not allow_instant_test_mode:
		_presentation_policy_rejection_count += 1
		return {
			"accepted": false,
			"reason_code": "instant_test_mode_production_unreachable",
			"policy": presentation_policy_snapshot(),
		}
	_screen_shake_enabled = bool(snapshot.get("screen_shake", true))
	set_motion_policy(
		bool(snapshot.get("reduced_motion", false)),
		requested_instant and allow_instant_test_mode
	)
	if snapshot.has("flash_intensity_limit"):
		var requested_flash: Variant = snapshot.get("flash_intensity_limit")
		if typeof(requested_flash) in [TYPE_INT, TYPE_FLOAT]:
			_flash_intensity_limit = minf(
				_flash_intensity_limit,
				clampf(float(requested_flash), 0.0, 1.0)
			)
	_presentation_policy_apply_count += 1
	return {
		"accepted": true,
		"reason_code": "presentation_policy_applied",
		"policy": presentation_policy_snapshot(),
	}


func presentation_policy_snapshot() -> Dictionary:
	return {
		"schema": "V076PresentationPolicySnapshotV1",
		"motion_mode": _motion_mode(),
		"reduced_motion": _reduced_motion,
		"instant_test_mode": _instant_test_mode,
		"screen_shake_enabled": (
			_screen_shake_enabled
			and not _reduced_motion
			and not _instant_test_mode
		),
		"flash_intensity_limit": _flash_intensity_limit,
		"production_ui_instant_test_mode_reachable": false,
	}


func set_loading_active(active: bool) -> void:
	_loading_active = active


func record_performance_frame(
	delta_ms: float,
	animation_active: bool,
	loading_active: bool = false
) -> void:
	var sample := maxf(0.0, delta_ms)
	var samples: Array[float] = (
		_animation_frame_samples_ms
		if animation_active
		else _idle_frame_samples_ms
	)
	samples.append(sample)
	while samples.size() > PERFORMANCE_SAMPLE_LIMIT:
		samples.pop_front()
	if not loading_active and sample > OUTSIDE_LOADING_STALL_MS:
		_outside_loading_stall_count += 1


func record_input_response(sample_kind: String, elapsed_ms: float) -> bool:
	var normalized := sample_kind.strip_edges().to_lower()
	var sample := maxf(0.0, elapsed_ms)
	var samples: Array[float]
	match normalized:
		"card", "card_animation":
			samples = _card_input_response_samples_ms
		"menu", "menu_action":
			samples = _menu_input_response_samples_ms
		_:
			return false
	samples.append(sample)
	while samples.size() > PERFORMANCE_SAMPLE_LIMIT:
		samples.pop_front()
	return true


func performance_snapshot() -> Dictionary:
	return {
		"schema": "V076CommercialPresentationPerformanceV1",
		"idle_frame_p95_ms": _sample_p95(_idle_frame_samples_ms),
		"animation_frame_p95_ms": _sample_p95(
			_animation_frame_samples_ms
		),
		"card_input_response_p95_ms": _sample_p95(
			_card_input_response_samples_ms
		),
		"menu_input_response_p95_ms": _sample_p95(
			_menu_input_response_samples_ms
		),
		"idle_frame_sample_count": _idle_frame_samples_ms.size(),
		"animation_frame_sample_count": (
			_animation_frame_samples_ms.size()
		),
		"card_input_response_sample_count": (
			_card_input_response_samples_ms.size()
		),
		"menu_input_response_sample_count": (
			_menu_input_response_samples_ms.size()
		),
		"outside_loading_stall_threshold_ms": OUTSIDE_LOADING_STALL_MS,
		"outside_loading_stall_count": _outside_loading_stall_count,
		"loading_active": _loading_active,
		"sample_limit": PERFORMANCE_SAMPLE_LIMIT,
	}


func enqueue_receipt(receipt: Dictionary, projection: Dictionary = {}) -> Dictionary:
	var receipt_id := str(receipt.get("receipt_id", receipt.get("id", ""))).strip_edges()
	if receipt_id.is_empty():
		_receipt_rejection_count += 1
		_last_rejection_reason = "animation_receipt_identity_missing"
		return {}
	var receipt_fingerprint := _receipt_fingerprint(receipt)
	if receipt_fingerprint.is_empty():
		_receipt_rejection_count += 1
		_last_rejection_reason = "animation_receipt_fingerprint_invalid"
		return {}
	if _seen_receipt_ids.has(receipt_id):
		if str(_seen_receipt_ids.get(receipt_id, "")) == receipt_fingerprint:
			_receipt_duplicate_count += 1
			_last_rejection_reason = "animation_receipt_duplicate_suppressed"
			return {}
		_receipt_collision_count += 1
		_last_rejection_reason = "animation_receipt_identity_collision"
		return {}
	var cue_id := _cue_id_for_receipt(receipt)
	var cue := _cue_by_id.get(cue_id, {}) as Dictionary
	if cue.is_empty():
		var fallback_id := str(_cue_catalog.get("fallback_cue_id", "COMBAT_FIZZLE"))
		cue = _cue_by_id.get(fallback_id, {}) as Dictionary
		if cue.is_empty():
			_receipt_rejection_count += 1
			_last_rejection_reason = "animation_fallback_cue_missing"
			return {}
	var privacy_class := str(cue.get("privacy_class", "PUBLIC"))
	if privacy_class == "CURRENT_PLAYER" and not bool(projection.get("current_player_authorized", true)):
		_receipt_rejection_count += 1
		_last_rejection_reason = "animation_private_projection_unauthorized"
		return {}
	_seen_receipt_ids[receipt_id] = receipt_fingerprint
	var duration_ms := int(cue.get("duration_ms", 0))
	if _reduced_motion:
		duration_ms = int(cue.get("reduced_motion_duration_ms", duration_ms))
	if _instant_test_mode:
		duration_ms = 0
	var queued := cue.duplicate(true)
	queued["receipt_id"] = receipt_id
	queued["receipt_fingerprint"] = receipt_fingerprint
	queued["receipt_kind"] = str(receipt.get("receipt_kind", cue.get("receipt_kind", "")))
	queued["duration_ms"] = maxi(0, duration_ms)
	queued["reduced_motion"] = _reduced_motion
	queued["instant_test_mode"] = _instant_test_mode
	queued["motion_mode"] = _motion_mode()
	queued["effective_motion_path"] = _effective_motion_path(
		str(cue.get("motion_path", "none"))
	)
	queued["effective_screen_shake_profile"] = (
		str(cue.get("screen_shake_profile", "none"))
		if _screen_shake_enabled and not _reduced_motion and not _instant_test_mode
		else "none"
	)
	queued["effective_hit_stop_ms"] = (
		0
		if _reduced_motion or _instant_test_mode
		else maxi(0, int(cue.get("hit_stop_ms", 0)))
	)
	queued["effective_flash_intensity"] = _effective_flash_intensity(cue)
	queued["projection"] = _public_projection_copy(projection, privacy_class)
	_queued_cues.append(queued)
	cue_queued.emit(queued.duplicate(true))
	var sound_cue_id := str(queued.get("sound_cue_id", "")).strip_edges()
	if not sound_cue_id.is_empty():
		sound_cue_requested.emit(sound_cue_id, queued.duplicate(true))
	return queued.duplicate(true)


func consume_receipt(receipt: Dictionary, projection: Dictionary = {}) -> Dictionary:
	return enqueue_receipt(receipt, projection)


func finish_receipt(receipt_id: String) -> bool:
	for index in range(_queued_cues.size()):
		var cue := _queued_cues[index]
		if str(cue.get("receipt_id", "")) != receipt_id:
			continue
		_queued_cues.remove_at(index)
		_finished_cues.append(cue.duplicate(true))
		while _finished_cues.size() > 64:
			_finished_cues.pop_front()
		cue_finished.emit(cue.duplicate(true))
		return true
	return false


func clear_presentation_queue() -> void:
	_queued_cues.clear()
	_finished_cues.clear()
	_seen_receipt_ids.clear()
	_receipt_duplicate_count = 0
	_receipt_collision_count = 0
	_receipt_rejection_count = 0
	_last_rejection_reason = "none"


func cue_catalog_snapshot() -> Dictionary:
	return {
		"catalog_id": str(_cue_catalog.get("catalog_id", "")),
		"cue_count": _cue_by_id.size(),
		"cue_ids": _cue_by_id.keys(),
		"reduced_motion": _reduced_motion,
		"instant_test_mode": _instant_test_mode,
	}


func animation_debug_snapshot() -> Dictionary:
	return {
		"schema": "V076PresentationAnimationDirectorDebugV1",
		"catalog": cue_catalog_snapshot(),
		"queued_cue_count": _queued_cues.size(),
		"finished_cue_count": _finished_cues.size(),
		"seen_receipt_count": _seen_receipt_ids.size(),
		"receipt_duplicate_count": _receipt_duplicate_count,
		"receipt_collision_count": _receipt_collision_count,
		"receipt_rejection_count": _receipt_rejection_count,
		"last_rejection_reason": _last_rejection_reason,
		"presentation_policy": presentation_policy_snapshot(),
		"presentation_policy_apply_count": _presentation_policy_apply_count,
		"presentation_policy_rejection_count": (
			_presentation_policy_rejection_count
		),
		"performance": performance_snapshot(),
		"queued_cues": _queued_cues.duplicate(true),
		"animation_gameplay_mutation_count": _animation_gameplay_mutation_count,
		"animation_rng_draw_delta": _animation_rng_draw_delta,
		"animation_authority_sequence_delta": _animation_authority_sequence_delta,
		"animation_deck_order_mutation_count": _animation_deck_order_mutation_count,
		"animation_card_zone_mutation_count": _animation_card_zone_mutation_count,
		"animation_facility_state_mutation_count": _animation_facility_state_mutation_count,
		"production_ui_instant_test_mode_reachable": false,
		"receipt_exact_once": true,
	}


func _motion_mode() -> String:
	if _instant_test_mode:
		return "INSTANT_TEST_MODE"
	return "REDUCED_MOTION" if _reduced_motion else "FULL_MOTION"


func _effective_motion_path(full_motion_path: String) -> String:
	if _instant_test_mode:
		return "instant_settle"
	if _reduced_motion:
		return "reduced_fade_pulse"
	return full_motion_path


func _effective_flash_intensity(cue: Dictionary) -> float:
	var requested := 0.0
	var particle := str(cue.get("particle_profile", "")).to_lower()
	var motion := str(cue.get("motion_path", "")).to_lower()
	if "flash" in particle or "flash" in motion:
		requested = 1.0
	elif str(cue.get("screen_shake_profile", "none")) != "none":
		requested = 0.55
	elif str(cue.get("particle_profile", "none")) != "none":
		requested = 0.35
	if _instant_test_mode:
		return 0.0
	return minf(requested, _flash_intensity_limit)


func _sample_p95(samples: Array[float]) -> float:
	if samples.is_empty():
		return 0.0
	var ordered := samples.duplicate()
	ordered.sort()
	var index := clampi(
		int(ceil(float(ordered.size()) * 0.95)) - 1,
		0,
		ordered.size() - 1
	)
	return snappedf(float(ordered[index]), 0.001)


func _receipt_fingerprint(receipt: Dictionary) -> String:
	var canonical_source := receipt.duplicate(true)
	var supplied := str(canonical_source.get("receipt_fingerprint", ""))
	canonical_source.erase("receipt_fingerprint")
	for transient_field in [
		"source_global_rect",
		"target_global_rect",
		"hand_target_global_rect",
	]:
		canonical_source.erase(transient_field)
	var canonical := PresentationReceiptIdentity.canonical_sha256(
		canonical_source
	)
	if supplied.is_empty():
		return canonical
	if (
		not PresentationReceiptIdentity.valid_sha256(supplied)
		or supplied != canonical
	):
		return ""
	return supplied


func _cue_id_for_receipt(receipt: Dictionary) -> String:
	var explicit := str(receipt.get("cue_id", "")).strip_edges()
	if not explicit.is_empty() and _cue_by_id.has(explicit):
		return explicit
	var kind := str(receipt.get("receipt_kind", "")).to_lower()
	var normalized := kind.replace(".", "_").replace("-", "_")
	for cue_id_variant in _cue_by_id.keys():
		var cue_id := str(cue_id_variant)
		var cue := _cue_by_id[cue_id] as Dictionary
		if str(cue.get("receipt_kind", "")).to_lower() == kind:
			return cue_id
		if normalized.contains(cue_id.to_lower()) or cue_id.to_lower().contains(normalized):
			return cue_id
	return "COMBAT_FIZZLE"


func _public_projection_copy(projection: Dictionary, privacy_class: String) -> Dictionary:
	if privacy_class == "PUBLIC":
		return projection.duplicate(true)
	var result: Dictionary = {}
	for key in ["current_player_authorized", "source_anchor", "target_anchor", "public_label"]:
		if projection.has(key):
			result[key] = projection[key]
	return result
