@tool
extends RefCounted
class_name V076MonsterL1ReducerV1

const AuthorityCommand := preload("res://scripts/v076/simulation/v076_authority_command_v1.gd")
const StateCodec := preload("res://scripts/v076/simulation/v076_authority_state_codec.gd")
const Codec := preload("res://scripts/v076/monster/v076_monster_l1_authority_codec_v1.gd")
const Metric := preload("res://scripts/v076/monster/v076_integer_geodesic_metric_v1.gd")


func v076_domain_contract(domain_id: String) -> Dictionary:
	return {
		"schema_version": 1,
		"domain_id": domain_id,
		"stateless_handler": true,
		"deterministic": true,
		"replay_safe": true,
		"external_side_effects_allowed": false,
		"owns_presentation": false,
		"derived_only_command_types": [Codec.ADVANCE_COMMAND_TYPE],
	}


func v076_apply_command(state: Dictionary, command: Dictionary, _rng: Variant) -> Dictionary:
	var state_validation := Codec.validate_state(state)
	if not bool(state_validation.get("valid", false)):
		return _reject(state, str(state_validation.get("reason", "v076_monster_state_invalid")))
	match str(command.get("command_type", "")):
		Codec.START_COMMAND_TYPE:
			return _start_move(state, command)
		Codec.START_PRODUCTION_BATCH_COMMAND_TYPE:
			return _start_production_batch(state, command)
		Codec.ADVANCE_COMMAND_TYPE:
			return _advance_move(state, command)
		_:
			return _reject(state, "v076_monster_command_type_unknown")


func _start_move(state: Dictionary, command: Dictionary) -> Dictionary:
	var payload := command.get("payload", {}) as Dictionary
	var payload_validation := Codec.validate_start_payload(payload)
	if not bool(payload_validation.get("valid", false)):
		return _reject(state, str(payload_validation.get("reason", "v076_monster_start_payload_invalid")))
	var monster_id := str(payload.get("monster_id", ""))
	var asset_id := str(payload.get("asset_id", ""))
	var monsters := state.get("monsters", {}) as Dictionary
	var assets := state.get("assets", {}) as Dictionary
	if not monsters.has(monster_id):
		return _fizzle(state, command, "monster_not_found", monster_id, asset_id)
	if not assets.has(asset_id):
		return _fizzle(state, command, "asset_not_found", monster_id, asset_id)
	var monster := (monsters[monster_id] as Dictionary).duplicate(true)
	var asset := (assets[asset_id] as Dictionary).duplicate(true)
	var tick := int(command.get("scheduled_tick", 0))
	var authority_sequence := int(command.get("authority_sequence", 0))
	if int(payload.get("expected_move_revision", -1)) != int(monster.get("move_revision", 0)):
		return _fizzle(state, command, "move_revision_stale", monster_id, asset_id)
	if str(monster.get("status", "")) == "MOVING":
		return _fizzle(state, command, "monster_already_moving", monster_id, asset_id)
	if int(monster.get("segment_progress_mu", 0)) != 0:
		return _fizzle(state, command, "monster_not_at_face_center", monster_id, asset_id)
	if tick < int(asset.get("cooldown_until_tick", 0)):
		return _fizzle(state, command, "asset_cooldown_active", monster_id, asset_id)
	if int(asset.get("quantity_remaining", 0)) <= 0:
		return _fizzle(state, command, "asset_quantity_exhausted", monster_id, asset_id)
	if str(payload.get("preferred_color", "")) != str(asset.get("preferred_color", "")):
		return _fizzle(state, command, "asset_preferred_color_mismatch", monster_id, asset_id)
	var current_face_id := int(monster.get("current_face_id", -1))
	var target_face_id := int(payload.get("target_face_id", -1))
	var target_point := payload.get("target_point", {}) as Dictionary
	if target_face_id < 0 or target_face_id >= (state.get("owner_by_face", []) as Array).size():
		return _fizzle(state, command, "target_face_out_of_range", monster_id, asset_id)
	if target_face_id == current_face_id:
		return _fizzle(state, command, "target_already_reached", monster_id, asset_id)
	var route_result := Metric.build_route(current_face_id, target_face_id, target_point)
	if not bool(route_result.get("accepted", false)):
		return _reject(state, str(route_result.get("reason", "v076_monster_route_build_failed")))
	var next_revision := int(monster.get("move_revision", 0)) + 1
	monster["target_face_id"] = target_face_id
	monster["target_point"] = target_point.duplicate(true)
	monster["route"] = (route_result.get("route", {}) as Dictionary).duplicate(true)
	monster["route_sha256"] = str(route_result.get("route_sha256", ""))
	monster["route_segment_index"] = 0
	monster["segment_progress_mu"] = 0
	monster["speed_mu_per_tick"] = int(payload.get("speed_mu_per_tick", 0))
	monster["max_geodesic_distance_mu"] = int(payload.get("max_geodesic_distance_mu", 0))
	monster["travelled_distance_mu"] = 0
	monster["status"] = "MOVING"
	monster["accepted_tick"] = tick
	monster["accepted_authority_sequence"] = authority_sequence
	monster["last_move_tick"] = tick
	monster["last_move_authority_sequence"] = authority_sequence
	monster["region_crossing_count"] = 0
	monster["frozen_trample_modifiers_ppm"] = (payload.get("trample_modifiers_ppm", []) as Array).duplicate()
	monster["effective_trample_efficiency_ppm"] = Codec.compute_effective_trample_efficiency_ppm(
		int(monster.get("trample_efficiency_ppm", 0)),
		monster.get("frozen_trample_modifiers_ppm", []) as Array
	)
	monster["trample_distance_by_region_mu"] = {}
	monster["trample_damage_by_region"] = {}
	monster["total_trample_damage"] = 0
	monster["move_revision"] = next_revision
	monster["next_step_index"] = 1
	monster["active_asset_id"] = asset_id
	monster["root_command_id"] = str(command.get("command_id", ""))
	asset["cooldown_until_tick"] = tick + maxi(1, int(asset.get("cooldown_ticks", 0)))
	var quantity_before := int(asset.get("quantity_remaining", 0))
	asset["quantity_remaining"] = quantity_before - 1
	asset["activation_count"] = int(asset.get("activation_count", 0)) + 1
	asset["last_activation_command_id"] = str(command.get("command_id", ""))
	asset["last_activation_tick"] = tick
	asset["last_activation_authority_sequence"] = authority_sequence
	monsters[monster_id] = monster
	assets[asset_id] = asset
	state["monsters"] = monsters
	state["assets"] = assets
	var activation_log := state.get("asset_activation_log", []) as Array
	activation_log.append({
		"asset_id": asset_id,
		"command_id": str(command.get("command_id", "")),
		"monster_id": monster_id,
		"tick": tick,
		"authority_sequence": authority_sequence,
		"cooldown_until_tick": int(asset.get("cooldown_until_tick", 0)),
		"preferred_color": str(asset.get("preferred_color", "")),
		"quantity_before": quantity_before,
		"quantity_after": int(asset.get("quantity_remaining", -1)),
	})
	state["asset_activation_log"] = activation_log
	var derived_result := _build_advance_command(command, monster, 1)
	if not bool(derived_result.get("accepted", false)):
		return _reject(state, str(derived_result.get("reason", "v076_monster_advance_build_failed")))
	var receipt := {
		"kind": "MOVE_ACCEPTED",
		"monster_id": monster_id,
		"asset_id": asset_id,
		"accepted_tick": tick,
		"accepted_authority_sequence": authority_sequence,
		"route_sha256": str(monster.get("route_sha256", "")),
		"target_point_sha256": StateCodec.fingerprint(monster.get("target_point", {})),
		"route_distance_mu": int((monster.get("route", {}) as Dictionary).get("total_distance_mu", 0)),
		"max_geodesic_distance_mu": int(monster.get("max_geodesic_distance_mu", 0)),
		"speed_mu_per_tick": int(monster.get("speed_mu_per_tick", 0)),
		"preferred_color": str(asset.get("preferred_color", "")),
		"asset_quantity_remaining": int(asset.get("quantity_remaining", -1)),
		"effective_trample_efficiency_ppm": int(monster.get("effective_trample_efficiency_ppm", -1)),
	}
	_append_move_receipt(state, receipt)
	return _commit(state, receipt, [derived_result.get("command", {})])


func _start_production_batch(state: Dictionary, command: Dictionary) -> Dictionary:
	var payload := command.get("payload", {}) as Dictionary
	var payload_validation := Codec.validate_production_batch_payload(payload)
	if not bool(payload_validation.get("valid", false)):
		return _reject(state, str(payload_validation.get(
			"reason",
			"v076_monster_production_batch_payload_invalid"
		)))
	var staged := state.duplicate(true)
	var derived_commands: Array = []
	var accepted_ids: Array[String] = []
	var fizzled_ids: Array[String] = []
	for move_variant in payload.get("moves", []) as Array:
		var move := move_variant as Dictionary
		var started := _start_production_move(staged, command, move)
		if not bool(started.get("accepted", false)):
			return _reject(staged, str(started.get(
				"reason",
				"v076_monster_production_move_rejected"
			)))
		staged = (started.get("state", staged) as Dictionary).duplicate(true)
		if str(started.get("outcome", "")) == "FIZZLE":
			fizzled_ids.append(str(move.get("production_movement_id", "")))
			continue
		accepted_ids.append(str(move.get("production_movement_id", "")))
		derived_commands.append_array(
			(started.get("derived_commands", []) as Array).duplicate(true)
		)
	var receipt := {
		"kind": "PRODUCTION_BATCH_ACCEPTED",
		"plan_fingerprint": str(payload.get("plan_fingerprint", "")),
		"tick": int(command.get("scheduled_tick", 0)),
		"authority_sequence": int(command.get("authority_sequence", 0)),
		"accepted_production_movement_ids": accepted_ids,
		"fizzled_production_movement_ids": fizzled_ids,
		"production_asset_quantity_write_count": 0,
	}
	return _commit(staged, receipt, derived_commands)


func _start_production_move(
	state: Dictionary,
	command: Dictionary,
	move: Dictionary
) -> Dictionary:
	var monsters := state.get("monsters", {}) as Dictionary
	var monster_id := str(move.get("monster_id", ""))
	if not monsters.has(monster_id):
		var created := Codec.build_production_monster_record(move)
		if created.is_empty():
			return _reject(state, "v076_monster_production_record_invalid")
		monsters[monster_id] = created
	var monster := (monsters.get(monster_id, {}) as Dictionary).duplicate(true)
	var movement_id := str(move.get("production_movement_id", ""))
	if not bool(monster.get("production_cutover", false)):
		return _production_fizzle(
			state, command, move,
			"production_monster_identity_collides_with_isolated_state"
		)
	if int(move.get("source_generation", 0)) < int(monster.get("source_generation", 0)):
		return _production_fizzle(state, command, move, "production_source_generation_stale")
	if int(move.get("expected_move_revision", -1)) != int(monster.get("move_revision", 0)):
		return _production_fizzle(state, command, move, "production_move_revision_stale")
	if str(monster.get("status", "")) == "MOVING":
		return _production_fizzle(state, command, move, "production_monster_already_moving")
	if int(monster.get("segment_progress_mu", 0)) != 0:
		return _production_fizzle(state, command, move, "production_monster_not_at_face_center")
	if int(monster.get("current_face_id", -1)) != int(move.get("start_face_id", -1)):
		return _production_fizzle(state, command, move, "production_source_face_stale")
	var route_result := Metric.build_route(
		int(move.get("start_face_id", -1)),
		int(move.get("target_face_id", -1)),
		move.get("target_point", {}) as Dictionary
	)
	if not bool(route_result.get("accepted", false)):
		return _reject(state, str(route_result.get(
			"reason",
			"v076_monster_production_route_build_failed"
		)))
	var tick := int(command.get("scheduled_tick", 0))
	var authority_sequence := int(command.get("authority_sequence", 0))
	var next_revision := int(monster.get("move_revision", 0)) + 1
	monster["movement_class"] = str(move.get("movement_class", ""))
	monster["target_face_id"] = int(move.get("target_face_id", -1))
	monster["target_point"] = (move.get("target_point", {}) as Dictionary).duplicate(true)
	monster["route"] = (route_result.get("route", {}) as Dictionary).duplicate(true)
	monster["route_sha256"] = str(route_result.get("route_sha256", ""))
	monster["route_segment_index"] = 0
	monster["segment_progress_mu"] = 0
	monster["speed_mu_per_tick"] = int(move.get("speed_mu_per_tick", 0))
	monster["max_geodesic_distance_mu"] = int(move.get("max_geodesic_distance_mu", 0))
	monster["travelled_distance_mu"] = 0
	monster["status"] = "MOVING"
	monster["accepted_tick"] = tick
	monster["accepted_authority_sequence"] = authority_sequence
	monster["last_move_tick"] = tick
	monster["last_move_authority_sequence"] = authority_sequence
	monster["region_crossing_count"] = 0
	monster["trample_efficiency_ppm"] = int(move.get("trample_efficiency_ppm", 0))
	monster["frozen_trample_modifiers_ppm"] = []
	monster["effective_trample_efficiency_ppm"] = int(
		move.get("trample_efficiency_ppm", 0)
	)
	monster["trample_distance_by_region_mu"] = {}
	monster["trample_damage_by_region"] = {}
	monster["total_trample_damage"] = 0
	monster["move_revision"] = next_revision
	monster["next_step_index"] = 1
	monster["active_asset_id"] = "production.autonomy"
	monster["root_command_id"] = str(command.get("command_id", ""))
	monster["source_generation"] = int(move.get("source_generation", 0))
	monster["production_movement_id"] = movement_id
	monster["source_region_id"] = str(move.get("source_region_id", ""))
	monster["target_region_id"] = str(move.get("target_region_id", ""))
	monsters[monster_id] = monster
	state["monsters"] = monsters
	var derived_result := _build_advance_command(command, monster, 1)
	if not bool(derived_result.get("accepted", false)):
		return _reject(state, str(derived_result.get(
			"reason",
			"v076_monster_production_advance_build_failed"
		)))
	var receipt := {
		"kind": "MOVE_ACCEPTED",
		"monster_id": monster_id,
		"production_cutover": true,
		"production_movement_id": movement_id,
		"source_generation": int(monster.get("source_generation", 0)),
		"source_region_id": str(monster.get("source_region_id", "")),
		"target_region_id": str(monster.get("target_region_id", "")),
		"accepted_tick": tick,
		"accepted_authority_sequence": authority_sequence,
		"route_sha256": str(monster.get("route_sha256", "")),
		"route_distance_mu": int((monster.get("route", {}) as Dictionary).get(
			"total_distance_mu", 0
		)),
		"production_asset_quantity_write_count": 0,
	}
	_append_move_receipt(state, receipt)
	return _commit(state, receipt, [derived_result.get("command", {})])


func _advance_move(state: Dictionary, command: Dictionary) -> Dictionary:
	var payload := command.get("payload", {}) as Dictionary
	var payload_validation := Codec.validate_advance_payload(payload)
	if not bool(payload_validation.get("valid", false)):
		return _reject(state, str(payload_validation.get("reason", "v076_monster_advance_payload_invalid")))
	var monster_id := str(payload.get("monster_id", ""))
	var monsters := state.get("monsters", {}) as Dictionary
	if not monsters.has(monster_id):
		return _fizzle(state, command, "derived_monster_not_found", monster_id, "")
	var monster := (monsters[monster_id] as Dictionary).duplicate(true)
	if (
		str(monster.get("status", "")) != "MOVING"
		or int(payload.get("movement_revision", -1)) != int(monster.get("move_revision", 0))
		or str(payload.get("route_sha256", "")) != str(monster.get("route_sha256", ""))
		or int(payload.get("step_index", -1)) != int(monster.get("next_step_index", 0))
	):
		return _fizzle(state, command, "derived_move_no_longer_active", monster_id, str(monster.get("active_asset_id", "")))
	var route := monster.get("route", {}) as Dictionary
	var face_path := route.get("face_path", []) as Array
	var segment_index := int(monster.get("route_segment_index", 0))
	var segment_progress_mu := int(monster.get("segment_progress_mu", 0))
	var travelled_distance_mu := int(monster.get("travelled_distance_mu", 0))
	var max_distance_mu := int(monster.get("max_geodesic_distance_mu", 0))
	var move_budget_mu := mini(int(monster.get("speed_mu_per_tick", 0)), maxi(0, max_distance_mu - travelled_distance_mu))
	var moved_this_tick_mu := 0
	var trample_this_tick := {}
	var crossings_this_tick := 0
	var owner_by_face := state.get("owner_by_face", []) as Array
	while move_budget_mu > 0 and segment_index + 1 < face_path.size():
		var from_face_id := int(face_path[segment_index])
		var to_face_id := int(face_path[segment_index + 1])
		var segment_distance_mu := Metric.segment_distance_at(route, segment_index)
		if segment_distance_mu <= 0:
			return _reject(state, "v076_monster_segment_distance_missing")
		var step_mu := mini(move_budget_mu, segment_distance_mu - segment_progress_mu)
		var next_progress_mu := segment_progress_mu + step_mu
		var allocation := Metric.interval_region_distance(
			from_face_id,
			to_face_id,
			segment_distance_mu,
			segment_progress_mu,
			next_progress_mu,
			owner_by_face
		)
		if not bool(allocation.get("accepted", false)):
			return _reject(state, str(allocation.get("reason", "v076_monster_segment_allocation_failed")))
		if bool(allocation.get("crossed_region_boundary", false)):
			crossings_this_tick += 1
		if str(monster.get("movement_class", "")) == "GROUND":
			_merge_distance_ledger(trample_this_tick, allocation.get("distance_by_region_mu", {}) as Dictionary)
		segment_progress_mu = next_progress_mu
		move_budget_mu -= step_mu
		moved_this_tick_mu += step_mu
		travelled_distance_mu += step_mu
		if segment_progress_mu == segment_distance_mu:
			segment_index += 1
			segment_progress_mu = 0
			monster["current_face_id"] = to_face_id
		else:
			monster["current_face_id"] = from_face_id if segment_progress_mu < Metric.segment_midpoint_mu(segment_distance_mu) else to_face_id
	monster["route_segment_index"] = segment_index
	monster["segment_progress_mu"] = segment_progress_mu
	monster["travelled_distance_mu"] = travelled_distance_mu
	monster["last_move_tick"] = int(command.get("scheduled_tick", 0))
	monster["last_move_authority_sequence"] = int(command.get("authority_sequence", 0))
	monster["region_crossing_count"] = int(monster.get("region_crossing_count", 0)) + crossings_this_tick
	monster["next_step_index"] = int(payload.get("step_index", 0)) + 1
	var trample_damage_this_tick := {}
	if str(monster.get("movement_class", "")) == "GROUND":
		var total_trample := monster.get("trample_distance_by_region_mu", {}) as Dictionary
		_merge_distance_ledger(total_trample, trample_this_tick)
		monster["trample_distance_by_region_mu"] = total_trample
		var damage_by_region := Codec.compute_trample_damage_by_region(
			total_trample,
			int(monster.get("effective_trample_efficiency_ppm", 0))
		)
		monster["trample_damage_by_region"] = damage_by_region
		monster["total_trample_damage"] = _sum_ledger(damage_by_region)
		trample_damage_this_tick = Codec.compute_trample_damage_by_region(
			trample_this_tick,
			int(monster.get("effective_trample_efficiency_ppm", 0))
		)
	else:
		monster["trample_distance_by_region_mu"] = {}
		monster["trample_damage_by_region"] = {}
		monster["total_trample_damage"] = 0
	if segment_index + 1 >= face_path.size():
		monster["status"] = "ARRIVED"
	elif travelled_distance_mu >= max_distance_mu:
		monster["status"] = "MAX_DISTANCE"
	else:
		monster["status"] = "MOVING"
	monsters[monster_id] = monster
	state["monsters"] = monsters
	var receipt := {
		"kind": "MOVE_STEP",
		"monster_id": monster_id,
		"production_cutover": bool(monster.get("production_cutover", false)),
		"production_movement_id": str(monster.get("production_movement_id", "")),
		"source_generation": int(monster.get("source_generation", 0)),
		"source_region_id": str(monster.get("source_region_id", "")),
		"target_region_id": str(monster.get("target_region_id", "")),
		"movement_revision": int(monster.get("move_revision", 0)),
		"step_index": int(payload.get("step_index", 0)),
		"tick": int(command.get("scheduled_tick", 0)),
		"authority_sequence": int(command.get("authority_sequence", 0)),
		"moved_distance_mu": moved_this_tick_mu,
		"travelled_distance_mu": travelled_distance_mu,
		"segment_progress_mu": segment_progress_mu,
		"current_face_id": int(monster.get("current_face_id", -1)),
		"status": str(monster.get("status", "")),
		"region_crossing_count": crossings_this_tick,
		"trample_distance_by_region_mu": trample_this_tick if str(monster.get("movement_class", "")) == "GROUND" else {},
		"trample_damage_by_region": trample_damage_this_tick,
		"total_trample_damage": int(monster.get("total_trample_damage", 0)),
	}
	_append_move_receipt(state, receipt)
	var derived_commands: Array = []
	if str(monster.get("status", "")) == "MOVING":
		var next_step := int(payload.get("step_index", 0)) + 1
		var derived_result := _build_advance_command(command, monster, next_step)
		if not bool(derived_result.get("accepted", false)):
			return _reject(state, str(derived_result.get("reason", "v076_monster_advance_build_failed")))
		derived_commands.append(derived_result.get("command", {}))
	return _commit(state, receipt, derived_commands)


func _build_advance_command(source_command: Dictionary, monster: Dictionary, step_index: int) -> Dictionary:
	return AuthorityCommand.build(
		"monster.advance.%s.%d.%d" % [str(monster.get("monster_id", "")), int(monster.get("move_revision", 0)), step_index],
		Codec.DOMAIN_ID,
		Codec.ADVANCE_COMMAND_TYPE,
		"system.monster_l1",
		int(source_command.get("scheduled_tick", 0)) + 1,
		int(source_command.get("domain_priority", 0)),
		int(source_command.get("authority_sequence", 0)),
		{
			"monster_id": str(monster.get("monster_id", "")),
			"movement_revision": int(monster.get("move_revision", 0)),
			"step_index": step_index,
			"route_sha256": str(monster.get("route_sha256", "")),
		}
	)


func _merge_distance_ledger(target: Dictionary, addition: Dictionary) -> void:
	for region_id_variant in addition.keys():
		var region_id := str(region_id_variant)
		target[region_id] = int(target.get(region_id, 0)) + int(addition[region_id_variant])


func _sum_ledger(values: Dictionary) -> int:
	var total := 0
	for value_variant in values.values():
		total += int(value_variant)
	return total


func _append_move_receipt(state: Dictionary, receipt: Dictionary) -> void:
	var receipts := state.get("move_receipts", []) as Array
	receipts.append(receipt)
	state["move_receipts"] = receipts


func _production_fizzle(
	state: Dictionary,
	command: Dictionary,
	move: Dictionary,
	reason: String
) -> Dictionary:
	var receipts := state.get("fizzle_receipts", []) as Array
	var receipt := {
		"kind": "FIZZLE",
		"reason": reason,
		"command_id": str(command.get("command_id", "")),
		"monster_id": str(move.get("monster_id", "")),
		"asset_id": "",
		"production_cutover": true,
		"production_movement_id": str(move.get("production_movement_id", "")),
		"tick": int(command.get("scheduled_tick", 0)),
		"authority_sequence": int(command.get("authority_sequence", 0)),
	}
	receipts.append(receipt)
	state["fizzle_receipts"] = receipts
	return {
		"accepted": true,
		"reason": reason,
		"outcome": "FIZZLE",
		"state": state,
		"receipt": receipt,
		"derived_commands": [],
	}


func _fizzle(state: Dictionary, command: Dictionary, reason: String, monster_id: String, asset_id: String) -> Dictionary:
	var receipts := state.get("fizzle_receipts", []) as Array
	var receipt := {
		"kind": "FIZZLE",
		"reason": reason,
		"command_id": str(command.get("command_id", "")),
		"monster_id": monster_id,
		"asset_id": asset_id,
		"tick": int(command.get("scheduled_tick", 0)),
		"authority_sequence": int(command.get("authority_sequence", 0)),
	}
	receipts.append(receipt)
	state["fizzle_receipts"] = receipts
	return {
		"accepted": true,
		"reason": reason,
		"outcome": "FIZZLE",
		"state": state,
		"receipt": receipt,
		"derived_commands": [],
	}


func _commit(state: Dictionary, receipt: Dictionary, derived_commands: Array) -> Dictionary:
	return {
		"accepted": true,
		"reason": "",
		"outcome": "COMMIT",
		"state": state,
		"receipt": receipt,
		"derived_commands": derived_commands,
	}


func _reject(state: Dictionary, reason: String) -> Dictionary:
	return {
		"accepted": false,
		"reason": reason,
		"outcome": "REJECT",
		"state": state,
		"receipt": {},
		"derived_commands": [],
	}
