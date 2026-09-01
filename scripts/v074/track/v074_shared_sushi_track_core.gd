extends "res://scripts/v07_semantic/v07_unified_card_track_core.gd"
class_name V074SharedSushiTrackCore

const REFILL_MODE_ID := "shared_scroll_vacancy"

var _acquisition_commit_count := 0
var _immediate_authoritative_refill_count := 0
var _supply_rng_draw_delta_on_acquisition := 0
var _supply_cursor_delta_on_acquisition := 0
var _supply_instance_sequence_delta_on_acquisition := 0


func acquisition_refill_mode_id() -> String:
	return REFILL_MODE_ID


func authoritative_scroll_sequence_v1() -> int:
	# Read-only scalar diagnostic for pacing probes.  It intentionally avoids
	# cloning the full authority envelope while the production owner remains the
	# sole writer of the track state.
	return int((_state.get("track_state", {}) as Dictionary).get(
		"scroll_sequence",
		0
	))


func _incoming_claimable_scroll_sequence_for_advance(
	track: Dictionary
) -> int:
	return int(track.get("scroll_sequence", 0)) + 1


func _commit_visible_acquisition(source_instance_id: String) -> Dictionary:
	var supply_rng_before := _supply_rng_draw_total()
	var supply_cursor_before := _supply_cursor_total()
	var track := _state.get("track_state", {}) as Dictionary
	var instance_sequence_before := int(
		track.get("next_instance_sequence", 0)
	)
	var items := track.get("items", []) as Array
	var removed_item: Dictionary = {}
	var surviving_items: Array = []
	for item_variant in items:
		var item := (item_variant as Dictionary).duplicate(true)
		if str(item.get("instance_id", "")) == source_instance_id:
			removed_item = item
			continue
		surviving_items.append(item)
	if removed_item.is_empty():
		return {}

	track["items"] = surviving_items
	track["revision"] = int(track.get("revision", 0)) + 1
	_state["track_state"] = track
	_acquisition_commit_count += 1
	_supply_rng_draw_delta_on_acquisition += (
		_supply_rng_draw_total() - supply_rng_before
	)
	_supply_cursor_delta_on_acquisition += (
		_supply_cursor_total() - supply_cursor_before
	)
	_supply_instance_sequence_delta_on_acquisition += (
		int(track.get("next_instance_sequence", 0))
		- instance_sequence_before
	)
	return {
		"track_item_removed": true,
		"replacement_count": 0,
		"vacancy_count": (
			int(track.get("capacity", 0)) - surviving_items.size()
		),
		"vacated_path_position": int(
			removed_item.get("path_position", -1)
		),
		"refill_mode_id": REFILL_MODE_ID,
		"track_revision": int(track.get("revision", 0)),
	}


func debug_snapshot_v074() -> Dictionary:
	var track := _state.get("track_state", {}) as Dictionary
	var item_count := (track.get("items", []) as Array).size()
	return {
		"schema": "V074SharedSushiTrackDebugV1",
		"refill_mode_id": REFILL_MODE_ID,
		"track_revision": int(track.get("revision", 0)),
		"capacity": int(track.get("capacity", 0)),
		"item_count": item_count,
		"next_instance_sequence": int(
			track.get("next_instance_sequence", 0)
		),
		"supply_cursor_total": _supply_cursor_total(),
		"supply_rng_draw_total": _supply_rng_draw_total(),
		"acquisition_commit_count": _acquisition_commit_count,
		"immediate_authoritative_refill_count": (
			_immediate_authoritative_refill_count
		),
		"supply_rng_draw_delta_on_acquisition": (
			_supply_rng_draw_delta_on_acquisition
		),
		"supply_cursor_delta_on_acquisition": (
			_supply_cursor_delta_on_acquisition
		),
		"supply_instance_sequence_delta_on_acquisition": (
			_supply_instance_sequence_delta_on_acquisition
		),
		"vacancy_count": (
			int(track.get("capacity", 0))
			- item_count
		),
		"scroll_sequence": int(track.get("scroll_sequence", 0)),
	}



func _supply_rng_draw_total() -> int:
	var color_cycle := _state.get("color_cycle_state", {}) as Dictionary
	var color_supply := (
		color_cycle.get("color_supply_state", {}) as Dictionary
	)
	return (
		int((_state.get("type_supply_state", {}) as Dictionary).get(
			"rng_draw_count",
			0
		))
		+ int((_state.get("normal_supply_state", {}) as Dictionary).get(
			"rng_draw_count",
			0
		))
		+ int((_state.get("commodity_supply_state", {}) as Dictionary).get(
			"rng_draw_count",
			0
		))
		+ int(color_supply.get("rng_draw_count", 0))
	)


func _supply_cursor_total() -> int:
	var color_cycle := _state.get("color_cycle_state", {}) as Dictionary
	var color_supply := (
		color_cycle.get("color_supply_state", {}) as Dictionary
	)
	return (
		int((_state.get("type_supply_state", {}) as Dictionary).get(
			"cursor",
			0
		))
		+ int((_state.get("normal_supply_state", {}) as Dictionary).get(
			"cursor",
			0
		))
		+ int((_state.get("commodity_supply_state", {}) as Dictionary).get(
			"cursor",
			0
		))
		+ int(color_supply.get("cursor", 0))
	)


func _track_segment_item_counts_are_valid(
	segment_local_slots: Dictionary,
	roster: Array,
	local_slots: int
) -> bool:
	for actor_id_variant in roster:
		var actor_slots := (
			segment_local_slots.get(str(actor_id_variant), []) as Array
		)
		if actor_slots.size() > local_slots:
			return false
	return true


func _track_item_count_is_valid(track: Dictionary) -> bool:
	var item_count := (track.get("items", []) as Array).size()
	var capacity := int(track.get("capacity", 0))
	return item_count >= 0 and item_count <= capacity
