extends SceneTree

const RuntimeOwner := preload(
	"res://scripts/v075_runtime/v075_runtime_owner.gd"
)
const CombatOwner := preload(
	"res://scripts/v075/runtime/v075_combat_runtime_owner.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	var runtime := RuntimeOwner.new()
	var combat := CombatOwner.new()
	host.add_child(runtime)
	host.add_child(combat)
	var bound := runtime.bind_combat_owner(combat)
	_expect(bool(bound.get("accepted", false)), "combat owner binds")
	var started := runtime.start_new_game(
		4,
		900626424,
		true,
		true,
		{
			"map_seed": 900626424,
			"region_count": 16,
			"geography_complexity": "STANDARD",
			"land_ocean_profile": "BALANCED",
		}
	)
	_expect(bool(started.get("accepted", false)), "V075 new game starts")
	_expect(
		str(started.get("ruleset_id", "")) == "v0.7.5",
		"new game reports V075 ruleset"
	)

	var snapshot := runtime.player_snapshot("player.local")
	_expect(not snapshot.is_empty(), "local player projection exists")
	_expect(
		str(snapshot.get("ruleset_id", "")) == "v0.7.5",
		"player projection reports V075"
	)
	_expect(
		(snapshot.get("special_actions", []) as Array).is_empty(),
		"legacy tactical support placeholder is absent"
	)
	var combat_projection := snapshot.get(
		"v075_combat_projection",
		{}
	) as Dictionary
	_expect(
		str(combat_projection.get("ruleset_id", "")) == "v0.7.5",
		"combat projection is connected"
	)
	_expect(
		int((combat_projection.get("privacy_report", {}) as Dictionary).get(
			"public_skill_card_disclosure_count",
			0
		)) == 0,
		"public combat projection leaks no skill cards"
	)
	var debug := runtime.debug_snapshot()
	_expect(
		int(debug.get("combat_runtime_owner_count", 0)) == 1
		and int(debug.get("combat_state_writer_count", 0)) == 1,
		"single combat writer is production connected"
	)
	_expect(
		int(debug.get("unified_track_local_visible_card_capacity", 0)) == 10,
		"ten-card shared track remains configured"
	)
	_expect(
		str(debug.get("track_refill_mode_id", "")) == "shared_scroll_vacancy",
		"shared scroll vacancy refill remains configured"
	)
	_expect(
		int(debug.get("track_immediate_authoritative_refill_count", -1)) == 0,
		"combat cutover adds no immediate track refill"
	)
	_expect(
		int(debug.get("special_support_placeholder_count", -1)) == 0,
		"runtime debug reports no special support placeholder"
	)
	_expect(
		int(debug.get("old_monster_controller_production_reachable_count", -1)) == 0
		and int(debug.get("old_military_controller_production_reachable_count", -1)) == 0,
		"legacy combat controllers remain unreachable"
	)
	var accelerated := runtime.run_accelerated_until_settled(4000)

	_expect(
		bool(accelerated.get("accepted", false)),
		"accelerated production loop reaches settlement"
	)
	_expect(
		str(accelerated.get("phase", "")) == "settled",
		"production loop settles exactly once"
	)
	var final_debug := runtime.debug_snapshot()
	_expect(
		int(final_debug.get("final_settlement_count", 0)) == 1,
		"final settlement count is one"
	)
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print(
		"V075_RUNTIME_OWNER_INTEGRATION_TEST|%s"
		% JSON.stringify({
			"status": "PASS" if _failures.is_empty() else "FAIL",
			"passed": _checks - _failures.size(),
			"total": _checks,
			"failures": _failures,
		})
	)
	quit(0 if _failures.is_empty() else 1)
