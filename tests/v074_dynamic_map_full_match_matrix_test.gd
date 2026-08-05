extends SceneTree

const Owner := preload("res://scripts/v074_runtime/v074_runtime_owner.gd")

const CASES := [
	{
		"id": "3p_8_simple",
		"players": 3,
		"regions": 8,
		"complexity": "SIMPLE",
		"seed": 900626424,
	},
	{
		"id": "4p_16_standard",
		"players": 4,
		"regions": 16,
		"complexity": "STANDARD",
		"seed": 900731153,
	},
	{
		"id": "4p_24_complex",
		"players": 4,
		"regions": 24,
		"complexity": "COMPLEX",
		"seed": 900835882,
	},
	{
		"id": "6p_24_standard",
		"players": 6,
		"regions": 24,
		"complexity": "STANDARD",
		"seed": 900940611,
	},
	{
		"id": "8p_30_complex",
		"players": 8,
		"regions": 30,
		"complexity": "COMPLEX",
		"seed": 901045340,
	},
]

var _checks := 0
var _failures: Array[String] = []
var _rows: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var selected_cases: Array = CASES.duplicate(true)
	var case_filter := OS.get_environment("V074_MATCH_CASE_ID")
	if not case_filter.is_empty():
		selected_cases = []
		for case_variant in CASES:
			var case_spec := case_variant as Dictionary
			if str(case_spec.get("id", "")) == case_filter:
				selected_cases.append(case_spec.duplicate(true))
		_expect(
			selected_cases.size() == 1,
			"requested full-match case exists: %s" % case_filter
		)
	var warehouse_build_count := 0
	var warehouse_upgrade_count := 0
	var warehouse_repair_count := 0
	var warehouse_solar_change_count := 0
	for case_variant in selected_cases:
		var spec := case_variant as Dictionary
		var owner := Owner.new()
		root.add_child(owner)
		var players := int(spec.get("players", 0))
		var regions := int(spec.get("regions", 0))
		var seed_value := int(spec.get("seed", 0))
		var seed_override := OS.get_environment("V074_MATCH_SEED")
		if not seed_override.is_empty():
			seed_value = int(seed_override)
		var started := owner.start_new_game(
			players,
			seed_value,
			false,
			false,
			{
				"map_seed": seed_value,
				"region_count": regions,
				"geography_complexity": str(spec.get("complexity", "")),
				"land_ocean_profile": "BALANCED",
			}
		)
		_expect(
			bool(started.get("accepted", false)),
			"%s starts: %s" % [spec.get("id", ""), JSON.stringify(started)]
		)
		var local_snapshot := owner.player_snapshot(owner.local_player_id())
		var ai_observation := owner.ai_observation("player.ai.1")
		var start_debug := owner.debug_snapshot()
		_expect(
			str(local_snapshot.get("ruleset_id", "")) == "v0.7.4",
			"%s uses V0.7.4" % spec.get("id", "")
		)
		_expect(
			int(local_snapshot.get("region_count", 0)) == regions,
			"%s projects %d regions" % [spec.get("id", ""), regions]
		)
		_expect(
			int(start_debug.get("facility_slot_count", 0)) == regions * 18,
			"%s owns %d dynamic slots" % [
				spec.get("id", ""),
				regions * 18,
			]
		)
		_expect(
			int(start_debug.get("map_genesis_owner_count", 0)) == 1,
			"%s has one Map Genesis owner" % spec.get("id", "")
		)
		_expect(
			not ai_observation.is_empty(),
			"%s builds a production AI observation" % spec.get("id", "")
		)
		var completed: Dictionary = {}
		var total_accelerated_steps := 0
		while total_accelerated_steps < 5000:
			var chunk := owner.run_accelerated_until_settled(20)
			total_accelerated_steps += int(chunk.get("steps", 0))
			completed = chunk
			if bool(chunk.get("accepted", false)) or str(
				chunk.get("phase", "")
			) == "failed":
				break
			var progress_debug := owner.debug_snapshot()
			print(
				"V074_DYNAMIC_MAP_FULL_MATCH_PROGRESS|id=%s|steps=%d|phase=%s|batch=%d"
				% [
					str(spec.get("id", "")),
					total_accelerated_steps,
					str(chunk.get("phase", "")),
					int(progress_debug.get("batch_number", -1)),
				]
			)
		completed["steps"] = total_accelerated_steps
		var debug := owner.debug_snapshot()
		var final_settlement := completed.get("final_settlement", {}) as Dictionary
		_expect(
			bool(completed.get("accepted", false)),
			"%s reaches FinalSettlement: %s" % [
				spec.get("id", ""),
				JSON.stringify(completed),
			]
		)
		_expect(
			str(completed.get("phase", "")) == "settled",
			"%s terminal phase is settled" % spec.get("id", "")
		)
		_expect(
			int(debug.get("final_settlement_count", 0)) == 1,
			"%s commits settlement once" % spec.get("id", "")
		)
		_expect(
			int(debug.get("duplicate_settlement_count", -1)) == 0,
			"%s has no duplicate settlement" % spec.get("id", "")
		)
		_expect(
			(final_settlement.get("standings", []) as Array).size() == players,
			"%s settlement includes every player" % spec.get("id", "")
		)
		for counter_name in [
			"invalid_action_count",
			"runtime_error_count",
			"hidden_info_violation_count",
			"nonfinite_count",
			"adapter_failure_count",
			"dual_authority_count",
		]:
			_expect(
				int(debug.get(counter_name, -1)) == 0,
				"%s %s is zero" % [spec.get("id", ""), counter_name]
			)
		_expect(
			int(debug.get("connected_domain_count", 0)) == 15,
			"%s connects all cutover domains" % spec.get("id", "")
		)
		var map_validation := debug.get("map_validation", {}) as Dictionary
		_expect(
			bool(map_validation.get("valid", false)),
			"%s retains valid connected map geometry" % spec.get("id", "")
		)
		var warehouse_count := int(
			debug.get("warehouse_facility_count", 0)
		)
		var case_solar_changes := int(
			debug.get("warehouse_solar_state_change_count", 0)
		)
		_expect(
			warehouse_count > 0 or case_solar_changes == 0,
			"%s does not report warehouse solar changes without warehouses"
			% spec.get("id", "")
		)
		warehouse_build_count += int(debug.get("warehouse_build_count", 0))
		warehouse_upgrade_count += int(
			debug.get("warehouse_upgrade_count", 0)
		)
		warehouse_repair_count += int(debug.get("warehouse_repair_count", 0))
		warehouse_solar_change_count += case_solar_changes
		_rows.append({
			"id": str(spec.get("id", "")),
			"players": players,
			"regions": regions,
			"complexity": str(spec.get("complexity", "")),
			"steps": int(completed.get("steps", -1)),
			"batch_number": int(debug.get("batch_number", -1)),
			"facility_slot_count": int(debug.get("facility_slot_count", -1)),
			"warehouse_purchase_count": int(
				debug.get("warehouse_purchase_count", 0)
			),
			"warehouse_card_play_count": int(
				debug.get("warehouse_card_play_count", 0)
			),
			"warehouse_merge_count": int(
				debug.get("warehouse_merge_count", 0)
			),
			"warehouse_build_count": int(
				debug.get("warehouse_build_count", 0)
			),
			"warehouse_upgrade_count": int(
				debug.get("warehouse_upgrade_count", 0)
			),
			"warehouse_repair_count": int(
				debug.get("warehouse_repair_count", 0)
			),
			"warehouse_contention_fizzle_count": int(
				debug.get("warehouse_contention_fizzle_count", 0)
			),
			"warehouse_solar_state_change_count": case_solar_changes,
			"final_settlement_count": int(
				debug.get("final_settlement_count", 0)
			),

		})
		root.remove_child(owner)
		owner.free()
	_finish(
		warehouse_build_count,
		warehouse_upgrade_count,
		warehouse_repair_count,
		warehouse_solar_change_count
	)



func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish(
	warehouse_build_count: int,
	warehouse_upgrade_count: int,
	warehouse_repair_count: int,
	warehouse_solar_change_count: int
) -> void:
	print(
		(
			"V074_DYNAMIC_MAP_FULL_MATCH_MATRIX"
			+ "|status=%s|passed=%d|total=%d"
			+ "|cases=%d|warehouse_build=%d|warehouse_upgrade=%d"
			+ "|warehouse_repair=%d|warehouse_solar_changes=%d"
			+ "|rows=%s|failures=%s"
		)
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			_rows.size(),
			warehouse_build_count,
			warehouse_upgrade_count,
			warehouse_repair_count,
			warehouse_solar_change_count,
			JSON.stringify(_rows),
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
