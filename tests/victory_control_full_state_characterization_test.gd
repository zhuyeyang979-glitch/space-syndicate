extends SceneTree

const CONTROLLER_SCENE := preload("res://scenes/runtime/VictoryControlRuntimeController.tscn")
const SEMANTIC_WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const SAVE_WIRE_CODEC := preload("res://scripts/runtime/victory_control_save_wire_codec_v3.gd")
const POST_SETTLEMENT_CHECKPOINT := "post_world_settlement"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var idle: Node = _new_controller("idle")
	var qualification: Node = _new_controller("qualification")
	var audit: Node = _new_controller("audit")
	var audit_zero: Node = _new_controller("audit_zero")
	var resolved: Node = _new_controller("resolved")
	var special: Node = _new_controller("special")
	if [idle, qualification, audit, audit_zero, resolved, special].has(null):
		_finish({})
		return

	qualification.call("advance_world_effective", 2.125, _world([36, 36], [], 5))
	qualification.call("advance_world_effective", 3.25, _world([36, 36], [36, 36], 5))

	audit.call("advance_world_effective", 10.0, _world([36, 36], [], 5))
	audit.call("advance_world_effective", 17.125, _world([36, 36], [], 5))

	audit_zero.call("advance_world_effective", 10.0, _world([36, 36], [], 5))
	var stale_endpoint := _world([36, 36], [], 5)
	stale_endpoint["settlement_checkpoint"] = "pre_world_settlement"
	var awaiting: Dictionary = audit_zero.call("advance_world_effective", 119.9999995, stale_endpoint)

	var joint_world := _world([36, 36], [36, 36], 5, [10000, 10000])
	resolved.call("advance_world_effective", 10.0, joint_world)
	resolved.call("advance_world_effective", 120.0, joint_world)

	var survivor_world := _world([36, 36], [], 5)
	var survivor_players := survivor_world.get("players", []) as Array
	var eliminated_player := (survivor_players[1] as Dictionary).duplicate(true)
	eliminated_player["eliminated"] = true
	survivor_players[1] = eliminated_player
	survivor_world["players"] = survivor_players
	var special_receipt: Dictionary = special.call("resolve_special_outcome", "last_survivor", survivor_world)

	var saves := {
		"idle": idle.call("to_save_data"),
		"qualification": qualification.call("to_save_data"),
		"audit": audit.call("to_save_data"),
		"audit_zero_boundary": audit_zero.call("to_save_data"),
		"resolved": resolved.call("to_save_data"),
		"special_outcome": special.call("to_save_data"),
	}
	var runtime_saves: Dictionary = {}
	for scenario in saves.keys():
		var decoded := SAVE_WIRE_CODEC.decode_save_state(saves.get(scenario) as Dictionary)
		if not bool(decoded.get("ok", false)):
			_failures.append("save_v3_decode_failed:%s:%s" % [scenario, str(decoded.get("reason_code", "unknown"))])
		runtime_saves[scenario] = (decoded.get("value", {}) as Dictionary).duplicate(true)
	_assert_scenario_shapes(runtime_saves, awaiting, special_receipt)

	var representations := {}
	var wire_representations := {}
	for scenario in runtime_saves.keys():
		representations[scenario] = _analyze(runtime_saves.get(scenario), str(scenario))
		wire_representations[scenario] = _analyze(saves.get(scenario), "%s_save_v3_wire" % str(scenario))
		if int((wire_representations.get(scenario, {}) as Dictionary).get("non_closed_leaf_count", -1)) != 0 \
				or not SEMANTIC_WIRE.is_closed_data(saves.get(scenario)):
			_failures.append("save_v3_wire_not_closed:%s" % scenario)
	var aggregate := _aggregate(representations)
	if int(aggregate.get("object_count", -1)) != 0 \
			or int(aggregate.get("resource_count", -1)) != 0 \
			or int(aggregate.get("callable_count", -1)) != 0 \
			or int(aggregate.get("rid_count", -1)) != 0:
		_failures.append("victory_rebindable_dependency_found")
	if int((representations.get("idle", {}) as Dictionary).get("raw_float_count", -1)) != 1:
		_failures.append("attested_idle_raw_float_count_not_one")
	if int((representations.get("qualification", {}) as Dictionary).get("raw_float_count", -1)) != 3:
		_failures.append("qualification_raw_float_count_not_three")

	var report := {
		"schema_version": 1,
		"characterization_id": "alpha04c_victory_control_full_state_pre_v3",
		"production_ruleset_id": "v0.6",
		"fixture_kind": "legal_typed_world_facts",
		"private_payload_redacted": true,
		"timer_boundary_epsilon_seconds": 0.000001,
		"representations": representations,
		"save_v3_wire_representations": wire_representations,
		"aggregate": aggregate,
		"failures": _failures.duplicate(),
	}
	for controller in [idle, qualification, audit, audit_zero, resolved, special]:
		controller.queue_free()
	await process_frame
	_finish(report)


func _assert_scenario_shapes(saves: Dictionary, awaiting: Dictionary, special_receipt: Dictionary) -> void:
	var idle := _payload(saves.get("idle", {}))
	var qualification := _payload(saves.get("qualification", {}))
	var audit := _payload(saves.get("audit", {}))
	var audit_zero := _payload(saves.get("audit_zero_boundary", {}))
	var resolved := _payload(saves.get("resolved", {}))
	var special := _payload(saves.get("special_outcome", {}))
	_expect(str(idle.get("state", "")) == "idle" \
			and (idle.get("qualification_elapsed_by_player", {}) as Dictionary).is_empty() \
			and (idle.get("audit_roster", []) as Array).is_empty() \
			and (idle.get("outcome_receipt", {}) as Dictionary).is_empty(), "idle_shape_invalid")
	var qualification_map := qualification.get("qualification_elapsed_by_player", {}) as Dictionary
	_expect(str(qualification.get("state", "")) == "qualification" \
			and qualification_map.size() == 2 \
			and float(qualification_map.get("0", 0.0)) != float(qualification_map.get("1", 0.0)) \
			and float(qualification_map.get("0", 0.0)) > 0.0 \
			and float(qualification_map.get("1", 0.0)) > 0.0, "qualification_shape_invalid")
	_expect(str(audit.get("state", "")) == "audit" \
			and not (audit.get("audit_roster", []) as Array).is_empty() \
			and float(audit.get("audit_remaining_seconds", 0.0)) > 0.0 \
			and (audit.get("outcome_receipt", {}) as Dictionary).is_empty(), "audit_shape_invalid")
	_expect(str(audit_zero.get("state", "")) == "audit" \
			and float(audit_zero.get("audit_remaining_seconds", -1.0)) == 0.0 \
			and str(awaiting.get("reason", "")) == "awaiting_post_world_settlement_checkpoint" \
			and (audit_zero.get("outcome_receipt", {}) as Dictionary).is_empty(), "audit_zero_boundary_shape_invalid")
	_expect(str(resolved.get("state", "")) == "resolved" \
			and int(resolved.get("outcome_sequence", 0)) == 1 \
			and not (resolved.get("outcome_receipt", {}) as Dictionary).is_empty(), "resolved_shape_invalid")
	_expect(str(special.get("state", "")) == "resolved" \
			and str(special_receipt.get("reason_code", "")) == "last_survivor", "special_outcome_shape_invalid")


func _new_controller(label: String) -> Node:
	var controller: Node = CONTROLLER_SCENE.instantiate()
	_expect(controller != null, "%s_controller_missing" % label)
	if controller == null:
		return null
	root.add_child(controller)
	var configured: Dictionary = controller.call("configure")
	_expect(bool(configured.get("configured", false)), "%s_controller_not_configured" % label)
	return controller


func _world(
	player_zero_regions: Array,
	player_one_regions: Array,
	total_region_count: int,
	cash_values: Array = [10000, 9000]
) -> Dictionary:
	var regions: Array = []
	var district_index := 0
	for amount_variant in player_zero_regions:
		var amount := maxi(1, int(amount_variant))
		regions.append(_region(district_index, amount * 200, {"0": amount * 100}))
		district_index += 1
	for amount_variant in player_one_regions:
		var amount := maxi(1, int(amount_variant))
		regions.append(_region(district_index, amount * 200, {"1": amount * 100}))
		district_index += 1
	while regions.size() < total_region_count:
		regions.append(_region(district_index, 0, {}))
		district_index += 1
	return {
		"schema_version": "v0.6.victory-world.2",
		"players": [_player(0, int(cash_values[0])), _player(1, int(cash_values[1]))],
		"regions": regions,
		"clock_pause": {},
		"settlement_checkpoint": POST_SETTLEMENT_CHECKPOINT,
	}


func _player(player_index: int, cash_cents: int) -> Dictionary:
	return {
		"player_index": player_index,
		"eliminated": false,
		"cash_ledger_cents": cash_cents,
		"audit_assets": {
			"available_cents": cash_cents,
			"escrow_cents": 0,
			"cash_ledger_cents": cash_cents,
			"ordinary_hand": [],
			"facilities": [],
			"installations": [],
			"commodity_inventory": [],
			"color_gdp": {},
			"units": [],
			"financial_positions": [],
		},
	}


func _region(index: int, total_cents: int, by_player: Dictionary) -> Dictionary:
	return {
		"region_id": "region.%04d" % index,
		"district_index": index,
		"lifecycle_state": "active",
		"destroyed": false,
		"region_gdp_per_minute_cents": total_cents,
		"player_gdp_by_index": by_player.duplicate(true),
	}


func _payload(save: Variant) -> Dictionary:
	if save is Dictionary and (save as Dictionary).get("victory_control_runtime") is Dictionary:
		return ((save as Dictionary).get("victory_control_runtime") as Dictionary).duplicate(true)
	return {}


func _analyze(value: Variant, representation: String) -> Dictionary:
	var result := {
		"representation": representation,
		"leaf_count": 0,
		"non_closed_leaf_count": 0,
		"raw_float_count": 0,
		"null_count": 0,
		"non_string_dictionary_key_count": 0,
		"unsafe_integer_count": 0,
		"object_count": 0,
		"resource_count": 0,
		"callable_count": 0,
		"rid_count": 0,
		"non_closed_type_counts": {},
		"float_source_counts": {},
		"leaf_records": [],
	}
	_walk(value, "$", "none", result)
	return result


func _walk(value: Variant, path: String, dictionary_key_type: String, result: Dictionary) -> void:
	if value is Dictionary:
		var dictionary := value as Dictionary
		if dictionary.is_empty():
			_record_leaf(value, path, dictionary_key_type, result, "empty_container")
			return
		var keys := dictionary.keys()
		keys.sort_custom(func(left: Variant, right: Variant) -> bool:
			return "%s|%s" % [type_string(typeof(left)), str(left)] < "%s|%s" % [type_string(typeof(right)), str(right)]
		)
		for key_index in range(keys.size()):
			var key_variant: Variant = keys[key_index]
			var key_kind := type_string(typeof(key_variant))
			if not (key_variant is String):
				result["non_string_dictionary_key_count"] = int(result.get("non_string_dictionary_key_count", 0)) + 1
				_increment(result.get("non_closed_type_counts", {}) as Dictionary, "dictionary_key:%s" % key_kind)
			_walk(dictionary.get(key_variant), "%s.%s" % [path, _path_component(path, key_variant, key_index)], key_kind, result)
		return
	if value is Array:
		var array := value as Array
		if array.is_empty():
			_record_leaf(value, path, dictionary_key_type, result, "empty_container")
			return
		for index in range(array.size()):
			_walk(array[index], "%s[%d]" % [path, index], dictionary_key_type, result)
		return
	_record_leaf(value, path, dictionary_key_type, result, _reason_code(value))


func _record_leaf(
	value: Variant,
	path: String,
	dictionary_key_type: String,
	result: Dictionary,
	reason_code: String
) -> void:
	result["leaf_count"] = int(result.get("leaf_count", 0)) + 1
	var kind := type_string(typeof(value))
	var non_closed := reason_code not in ["closed_scalar", "empty_container"]
	if non_closed:
		result["non_closed_leaf_count"] = int(result.get("non_closed_leaf_count", 0)) + 1
		_increment(result.get("non_closed_type_counts", {}) as Dictionary, kind)
	if value is float:
		result["raw_float_count"] = int(result.get("raw_float_count", 0)) + 1
		_increment(result.get("float_source_counts", {}) as Dictionary, _source_subdomain(path))
	elif value == null:
		result["null_count"] = int(result.get("null_count", 0)) + 1
	elif value is int and not SEMANTIC_WIRE.is_safe_integer(value):
		result["unsafe_integer_count"] = int(result.get("unsafe_integer_count", 0)) + 1
	elif value is Object:
		result["object_count"] = int(result.get("object_count", 0)) + 1
		if value is Resource:
			result["resource_count"] = int(result.get("resource_count", 0)) + 1
	elif value is Callable:
		result["callable_count"] = int(result.get("callable_count", 0)) + 1
	elif value is RID:
		result["rid_count"] = int(result.get("rid_count", 0)) + 1
	var exact_once := path.contains("outcome_sequence") or path.contains("outcome_receipt")
	var privacy_sensitive := path.contains("cash_ledger_cents") or path.contains("rankings")
	var fingerprint_basis := "%s|%s|%s|%s" % [path, kind, _source_subdomain(path), reason_code]
	(result.get("leaf_records", []) as Array).append({
		"json_path": path,
		"source_subdomain": _source_subdomain(path),
		"variant_type": kind,
		"dictionary_key_type": dictionary_key_type,
		"persisted_authority": true,
		"derived_world_fact": false,
		"diagnostic_only": false,
		"privacy_sensitive": privacy_sensitive,
		"exact_once_required": exact_once,
		"finite": not (value is float) or is_finite(value),
		"safe_integer": value is int and SEMANTIC_WIRE.is_safe_integer(value),
		"reason_code": reason_code,
		"redacted_fingerprint": fingerprint_basis.sha256_text(),
	})


func _path_component(parent_path: String, key: Variant, key_index: int) -> String:
	if parent_path.ends_with("qualification_elapsed_by_player"):
		return "<player-key-%d>" % key_index
	return str(key)


func _source_subdomain(path: String) -> String:
	if path.contains("qualification_elapsed_by_player"):
		return "qualification_timer"
	if path.contains("audit_remaining_seconds"):
		return "audit_timer"
	if path.contains("audit_roster"):
		return "audit_roster"
	if path.contains("outcome_sequence"):
		return "outcome_exact_once_sequence"
	if path.contains("outcome_receipt"):
		return "outcome_receipt"
	return "owner_metadata"


func _reason_code(value: Variant) -> String:
	if value is float:
		return "raw_float_not_closed_data"
	if value == null:
		return "raw_null_not_closed_data"
	if value is int and not SEMANTIC_WIRE.is_safe_integer(value):
		return "unsafe_integer_not_closed_data"
	if value is Object:
		return "object_dependency_not_closed_data"
	if value is Callable:
		return "callable_not_closed_data"
	if value is RID:
		return "rid_not_closed_data"
	return "closed_scalar"


func _aggregate(representations: Dictionary) -> Dictionary:
	var aggregate := {
		"leaf_count": 0,
		"non_closed_leaf_count": 0,
		"raw_float_count": 0,
		"null_count": 0,
		"non_string_dictionary_key_count": 0,
		"unsafe_integer_count": 0,
		"object_count": 0,
		"resource_count": 0,
		"callable_count": 0,
		"rid_count": 0,
		"non_closed_type_counts": {},
		"float_source_counts": {},
	}
	for analysis_variant in representations.values():
		var analysis := analysis_variant as Dictionary
		for field in ["leaf_count", "non_closed_leaf_count", "raw_float_count", "null_count", "non_string_dictionary_key_count", "unsafe_integer_count", "object_count", "resource_count", "callable_count", "rid_count"]:
			aggregate[field] = int(aggregate.get(field, 0)) + int(analysis.get(field, 0))
		for key in (analysis.get("non_closed_type_counts", {}) as Dictionary).keys():
			_increment_by(aggregate.get("non_closed_type_counts", {}) as Dictionary, str(key), int((analysis.get("non_closed_type_counts", {}) as Dictionary).get(key, 0)))
		for key in (analysis.get("float_source_counts", {}) as Dictionary).keys():
			_increment_by(aggregate.get("float_source_counts", {}) as Dictionary, str(key), int((analysis.get("float_source_counts", {}) as Dictionary).get(key, 0)))
	return aggregate


func _increment(target: Dictionary, key: String) -> void:
	_increment_by(target, key, 1)


func _increment_by(target: Dictionary, key: String, amount: int) -> void:
	target[key] = int(target.get(key, 0)) + amount


func _expect(condition: bool, reason: String) -> void:
	if not condition:
		_failures.append(reason)


func _finish(report: Dictionary) -> void:
	var output_path := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--characterization-output="):
			output_path = argument.trim_prefix("--characterization-output=")
	if not output_path.is_empty() and not report.is_empty():
		var file := FileAccess.open(output_path, FileAccess.WRITE)
		if file == null:
			_failures.append("characterization_output_open_failed")
		else:
			file.store_string(JSON.stringify(report, "  "))
			file.close()
	print("VICTORY_CONTROL_FULL_STATE_CHARACTERIZATION_TEST|status=%s|failures=%d|output_written=%s" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_failures.size(),
		str(not output_path.is_empty()),
	])
	for failure in _failures:
		push_error(failure)
	quit(0 if _failures.is_empty() else 1)
