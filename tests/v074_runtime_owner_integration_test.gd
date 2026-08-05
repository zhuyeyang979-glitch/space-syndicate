extends SceneTree

const Owner := preload("res://scripts/v074_runtime/v074_runtime_owner.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var owner := Owner.new()
	root.add_child(owner)
	var started := owner.start_new_game(
		4,
		900626424,
		false,
		false,
		{
			"map_seed": 900626424,
			"region_count": 16,
			"geography_complexity": "STANDARD",
			"land_ocean_profile": "BALANCED",
		}
	)
	_expect(
		bool(started.get("accepted", false)),
		"production owner starts a V0.7.4 match: %s" % JSON.stringify(started)
	)
	owner.set_process(false)
	var local_id := owner.local_player_id()
	var track_instance_id := _first_claimable_normal_track_instance_id(
		owner,
		local_id
	)
	_expect(
		not track_instance_id.is_empty(),
		"manual sample exposes a claimable normal track card"
	)
	var acquisition := owner.acquire_track_item(local_id, track_instance_id)
	_expect(
		bool(acquisition.get("accepted", false)),
		"manual track purchase commits before deadline: %s"
		% JSON.stringify(acquisition)
	)
	owner.call("_process", 0.01)
	owner.call("_process", 31.0)
	var deadline_debug := owner.debug_snapshot()
	_expect(
		str(deadline_debug.get("phase", "")) != "failed",
		"deadline finalization remains live after manual track purchase"
	)
	_expect(
		int(deadline_debug.get("runtime_error_count", -1)) == 0,
		"manual track purchase does not cause an autofinalize runtime fault"
	)
	var snapshot := owner.player_snapshot(local_id)
	var debug := owner.debug_snapshot()
	_expect(str(snapshot.get("ruleset_id", "")) == "v0.7.4", "snapshot is V0.7.4")
	_expect(int(snapshot.get("region_count", 0)) == 16, "snapshot has dynamic regions")
	_expect(int(debug.get("facility_slot_count", 0)) == 288, "runtime has 18 slots per region")
	_expect(int(debug.get("map_genesis_owner_count", 0)) == 1, "one map owner is active")
	_expect(not owner.ai_observation("player.ai.1").is_empty(), "dynamic AI observation adapts")
	var completed := owner.run_accelerated_until_settled(3000)
	_expect(
		bool(completed.get("accepted", false)),
		"production match reaches FinalSettlement: %s" % JSON.stringify(completed)
	)
	debug = owner.debug_snapshot()
	_expect(int(debug.get("final_settlement_count", 0)) == 1, "settlement commits once")
	_expect(int(debug.get("duplicate_settlement_count", -1)) == 0, "settlement has no duplicate")
	_expect(int(debug.get("runtime_error_count", -1)) == 0, "runtime has no errors")
	owner.queue_free()
	_finish()


func _first_claimable_normal_track_instance_id(
	owner: Node,
	actor_id: String
) -> String:
	var core_variant: Variant = owner.get("_track_core")
	if not (core_variant is RefCounted):
		return ""
	var core := core_variant as RefCounted
	var projection := core.call(
		"player_projection_v1",
		actor_id
	) as Dictionary
	var private_facts := (
		projection.get("viewer_private_facts", {}) as Dictionary
	)
	for item_variant in private_facts.get("own_segment_items", []) as Array:
		var item := item_variant as Dictionary
		if (
			bool(item.get("claimable", false))
			and str(item.get("card_kind", "")) == "normal_card"
		):
			return str(item.get("instance_id", ""))
	return ""


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print(
		"V074_RUNTIME_OWNER_INTEGRATION_TEST|status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
