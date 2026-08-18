extends SceneTree

const RuntimeOwner := preload(
	"res://scripts/v075_runtime/v075_runtime_owner.gd"
)
const CombatOwner := preload(
	"res://scripts/v075/runtime/v075_combat_runtime_owner.gd"
)
const Registry := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)

const MATCH_SEED := 901626424
const MAP_SEED := 900626424
const PLAYERS := [
	"player.local",
	"player.ai.1",
	"player.ai.2",
	"player.ai.3",
]

class TraceRuntime extends V075RuntimeOwner:
	var acquisitions: Array = []
	var trace_started_usec := Time.get_ticks_usec()

	func _trace(label: String) -> void:
		print("V075_TRACE|%s|msec=%d" % [
			label,
			int((Time.get_ticks_usec() - trace_started_usec) / 1000),
		])

	func _auto_acquire_track_item(actor_id: String) -> Dictionary:
		_trace("acquire.begin.%s" % actor_id)
		var facts := _v075_track_acquisition_facts(actor_id)
		var available := facts.get(
			"available_unreserved_assets",
			{}
		) as Dictionary
		var result := super._auto_acquire_track_item(actor_id)
		_trace("acquire.end.%s.%s" % [actor_id, str(result.get("reason_code", ""))])
		acquisitions.append({
			"batch": _batch_number,
			"actor": actor_id,
			"available": available.duplicate(true),
			"result": result.duplicate(true),
		})
		return result

	func _auto_legal_actions(actor_id: String) -> Array:
		_trace("legal.begin.%s" % actor_id)
		var result := super._auto_legal_actions(actor_id)
		_trace("legal.end.%s.%d" % [actor_id, result.size()])
		return result

	func ai_observation(actor_id: String) -> Dictionary:
		_trace("observation.begin.%s" % actor_id)
		var result := super.ai_observation(actor_id)
		_trace("observation.end.%s.%d" % [actor_id, result.size()])
		return result

	func lock_player_submission(actor_id: String) -> Dictionary:
		_trace("lock.begin.%s" % actor_id)
		var result := super.lock_player_submission(actor_id)
		_trace("lock.end.%s.%s" % [actor_id, str(result.get("reason_code", ""))])
		return result

	func advance_one_batch_direct() -> void:
		_clock_msec = _submission_deadline_msec
		_process_submission()
		while _phase == "resolving":
			resolve_next_action()
		while _phase == "maintenance":
			_process_maintenance()


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var runtime := TraceRuntime.new()
	var combat := CombatOwner.new()
	host.add_child(runtime)
	host.add_child(combat)
	var bound := runtime.bind_combat_owner(combat)
	if not bool(bound.get("accepted", false)):
		push_error("combat owner binding failed")
		quit(1)
		return
	var started := runtime.start_new_game(
		4,
		MATCH_SEED,
		true,
		true,
		{
			"map_seed": MAP_SEED,
			"region_count": 16,
			"geography_complexity": "STANDARD",
			"land_ocean_profile": "BALANCED",
		}
	)
	if not bool(started.get("accepted", false)):
		push_error("runtime start failed")
		quit(1)
		return
	var batches: Array = []
	runtime._trace("manual.actor.begin")
	var actor_result := runtime.call(
		"_auto_queue_and_lock",
		"player.ai.1"
	) as Dictionary
	runtime._trace("manual.actor.end.%s" % str(actor_result.get("reason_code", "")))
	batches.append({
		"batch": int(runtime.debug_snapshot().get("batch_number", 0)),
		"phase": runtime.phase(),
		"actor_result": actor_result,
		"acquisitions": runtime.acquisitions.duplicate(true),
	})
	print("V075_RUNTIME_ACQUISITION_TRACE|%s" % JSON.stringify({
		"started": started,
		"batches": batches,
	}))
	quit(0)


func _asset_rows(runtime: TraceRuntime) -> Array:
	var result: Array = []
	for player_id in PLAYERS:
		var projection := runtime.player_snapshot(player_id)
		var assets := (
			(projection.get("canonical_player_projection", {}) as Dictionary)
			.get("six_color_assets", {}) as Dictionary
		).get("own_available_assets", {}) as Dictionary
		result.append({"player": player_id, "assets": assets})
	return result


func _track_rows(runtime: TraceRuntime) -> Array:
	var result: Array = []
	for player_id in PLAYERS:
		var projection := runtime.player_snapshot(player_id)
		var items := (
			((projection.get("canonical_player_projection", {}) as Dictionary)
			.get("unified_track", {}) as Dictionary)
			.get("viewer_private_facts", {}) as Dictionary
		).get("own_segment_items", []) as Array
		var domains: Array = []
		for item_variant in items:
			var item := item_variant as Dictionary
			var definition := Registry.definition(str(item.get(
				"card_definition_id", ""
			)))
			domains.append({
				"slot": int(item.get("local_slot_index", -1)),
				"domain": Registry.card_domain(str(definition.get("card_type", ""))),
				"color": str(item.get("primary_color", "")),
			})
		result.append({"player": player_id, "cards": domains})
	return result
