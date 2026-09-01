extends SceneTree

const DIRECTOR_SCRIPT := preload("res://scripts/presentation/v076_presentation_animation_director.gd")
const CATALOG_PATH := "res://data/presentation/v076_animation_cue_catalog.json"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var text := FileAccess.get_file_as_string(CATALOG_PATH)
	var parsed: Variant = JSON.parse_string(text)
	_expect(parsed is Dictionary, "animation cue catalog parses")
	var catalog: Dictionary = parsed if parsed is Dictionary else {}
	var cues: Array = catalog.get("cues", []) if catalog.get("cues", []) is Array else []
	_expect(cues.size() == 31, "catalog contains all 31 required cue families")
	var required_fields := [
		"cue_id", "receipt_kind", "source_kind", "target_kind", "privacy_class", "priority",
		"queue_policy", "duration_ms", "reduced_motion_duration_ms", "source_anchor", "target_anchor",
		"motion_path", "scale_curve", "rotation_curve", "opacity_curve", "hit_stop_ms",
		"screen_shake_profile", "particle_profile", "sound_cue_id", "completion_policy",
		"interrupt_policy", "fallback_cue_id",
	]
	var ids: Array[String] = []
	for cue_variant in cues:
		if not (cue_variant is Dictionary):
			_failures.append("catalog cue is not a dictionary")
			continue
		var cue: Dictionary = cue_variant
		for field in required_fields:
			_expect(cue.has(field), "cue %s has %s" % [str(cue.get("cue_id", "")), field])
		var cue_id := str(cue.get("cue_id", ""))
		_expect(not cue_id.is_empty() and not ids.has(cue_id), "cue IDs are unique")
		ids.append(cue_id)
		_expect(int(cue.get("reduced_motion_duration_ms", -1)) <= int(cue.get("duration_ms", -1)), "reduced motion does not lengthen cue")
	var director := DIRECTOR_SCRIPT.new() as Node
	get_root().add_child(director)
	await process_frame
	_expect(bool(director.call("load_cue_catalog")), "V076PresentationAnimationDirector loads cue catalog")
	var catalog_debug: Dictionary = director.call("cue_catalog_snapshot")
	_expect(int(catalog_debug.get("cue_count", 0)) == 31, "director exposes the complete cue catalog")
	var public_cue: Dictionary = director.call("enqueue_receipt", {
		"receipt_id": "receipt.facility.001",
		"receipt_kind": "facility_commit_receipt",
	}, {"target_anchor": "region.000", "current_player_authorized": true})
	_expect(not public_cue.is_empty() and str(public_cue.get("cue_id", "")) == "FACILITY_BUILD", "facility receipt queues the facility build cue")
	var duplicate: Dictionary = director.call("enqueue_receipt", {
		"receipt_id": "receipt.facility.001",
		"receipt_kind": "facility_commit_receipt",
	}, {})
	_expect(duplicate.is_empty(), "a receipt queues exactly once")
	var private_rejected: Dictionary = director.call("enqueue_receipt", {
		"receipt_id": "receipt.private.001",
		"receipt_kind": "private_card_play_receipt",
	}, {"current_player_authorized": false})
	_expect(private_rejected.is_empty(), "unauthorized private receipt is not presented")
	var private_cue: Dictionary = director.call("enqueue_receipt", {
		"receipt_id": "receipt.private.002",
		"receipt_kind": "private_card_play_receipt",
	}, {"current_player_authorized": true, "public_label": "private"})
	_expect(not private_cue.is_empty() and str(private_cue.get("cue_id", "")) == "CARD_PLAY_PRIVATE", "authorized private receipt queues a private cue")
	director.call("set_motion_policy", true)
	var reduced_cue: Dictionary = director.call("enqueue_receipt", {
		"receipt_id": "receipt.track.001",
		"receipt_kind": "track_handoff_receipt",
	}, {})
	_expect(int(reduced_cue.get("duration_ms", 99999)) <= 420, "reduced motion shortens track handoff")
	_expect(bool(director.call("finish_receipt", "receipt.facility.001")), "finished receipt leaves the presentation queue")
	var debug: Dictionary = director.call("animation_debug_snapshot")
	for key in [
		"animation_gameplay_mutation_count", "animation_rng_draw_delta", "animation_authority_sequence_delta",
		"animation_deck_order_mutation_count", "animation_card_zone_mutation_count", "animation_facility_state_mutation_count",
	]:
		_expect(int(debug.get(key, -1)) == 0, "%s remains zero" % key)
	_expect(not bool(debug.get("production_ui_instant_test_mode_reachable", true)), "instant test mode is not production reachable")
	director.queue_free()
	await process_frame
	print("V076_PRESENTATION_ANIMATION_DIRECTOR|status=%s|cue_count=%d|queued_once=%s|mutation_count=%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		cues.size(),
		str(duplicate.is_empty()),
		int(debug.get("animation_gameplay_mutation_count", -1)),
	])
	_finish()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		printerr("- %s" % failure)
	quit(1)
