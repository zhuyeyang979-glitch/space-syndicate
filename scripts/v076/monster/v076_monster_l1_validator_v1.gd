@tool
extends RefCounted
class_name V076MonsterL1ValidatorV1

const StateCodec := preload("res://scripts/v076/simulation/v076_authority_state_codec.gd")
const Codec := preload("res://scripts/v076/monster/v076_monster_l1_authority_codec_v1.gd")
const Metric := preload("res://scripts/v076/monster/v076_integer_geodesic_metric_v1.gd")

const ACTIVATION_LOG_FIELDS := [
	"asset_id", "command_id", "monster_id", "tick", "authority_sequence",
	"cooldown_until_tick", "preferred_color", "quantity_before", "quantity_after",
]


static func validate_terminal_state(state: Dictionary) -> Dictionary:
	var state_validation := Codec.validate_state(state, true)
	if not bool(state_validation.get("valid", false)):
		return _failure(str(state_validation.get("reason", "v076_monster_terminal_state_invalid")))
	var activation_log := state.get("asset_activation_log", []) as Array
	var activation_by_asset := {}
	var activation_color_by_asset := {}
	var expected_quantity_by_asset := {}
	var activation_commands := {}
	for entry_variant in activation_log:
		if not (entry_variant is Dictionary):
			return _failure("v076_monster_asset_activation_log_invalid")
		var entry := entry_variant as Dictionary
		if not _has_exact_fields(entry, ACTIVATION_LOG_FIELDS):
			return _failure("v076_monster_asset_activation_log_shape_invalid")
		var asset_id := str(entry.get("asset_id", ""))
		var command_id := str(entry.get("command_id", ""))
		if (
			asset_id.is_empty() or command_id.is_empty() or activation_commands.has(command_id)
			or str(entry.get("preferred_color", "")).is_empty()
			or typeof(entry.get("quantity_before")) != TYPE_INT
			or typeof(entry.get("quantity_after")) != TYPE_INT
			or int(entry.get("quantity_before", 0)) <= 0
			or int(entry.get("quantity_after", -1)) != int(entry.get("quantity_before", 0)) - 1
		):
			return _failure("v076_monster_asset_activation_not_exact_once")
		if expected_quantity_by_asset.has(asset_id) and int(entry.get("quantity_before", -1)) != int(expected_quantity_by_asset[asset_id]):
			return _failure("v076_monster_asset_quantity_chain_mismatch")
		expected_quantity_by_asset[asset_id] = int(entry.get("quantity_after", -1))
		if activation_color_by_asset.has(asset_id) and str(activation_color_by_asset[asset_id]) != str(entry.get("preferred_color", "")):
			return _failure("v076_monster_asset_preferred_color_chain_mismatch")
		activation_color_by_asset[asset_id] = str(entry.get("preferred_color", ""))
		activation_commands[command_id] = true
		activation_by_asset[asset_id] = int(activation_by_asset.get(asset_id, 0)) + 1
	var assets := state.get("assets", {}) as Dictionary
	for asset_id_variant in assets.keys():
		var asset_id := str(asset_id_variant)
		var asset := assets[asset_id_variant] as Dictionary
		if (
			int(asset.get("activation_count", -1)) != int(activation_by_asset.get(asset_id, 0))
			or int(asset.get("quantity_remaining", -1)) != int(asset.get("total_quantity", 0)) - int(asset.get("activation_count", 0))
			or (expected_quantity_by_asset.has(asset_id) and int(asset.get("quantity_remaining", -1)) != int(expected_quantity_by_asset[asset_id]))
			or (activation_color_by_asset.has(asset_id) and str(asset.get("preferred_color", "")) != str(activation_color_by_asset[asset_id]))
		):
			return _failure("v076_monster_asset_activation_count_mismatch")
	var owners := state.get("owner_by_face", []) as Array
	for monster_variant in (state.get("monsters", {}) as Dictionary).values():
		var monster := monster_variant as Dictionary
		var travelled := int(monster.get("travelled_distance_mu", 0))
		var trample_sum := 0
		for distance_variant in (monster.get("trample_distance_by_region_mu", {}) as Dictionary).values():
			trample_sum += int(distance_variant)
		var expected_physical := _expected_physical_projection(monster, owners)
		if not bool(expected_physical.get("accepted", false)):
			return expected_physical
		if int(monster.get("region_crossing_count", -1)) != int(expected_physical.get("region_crossing_count", -2)):
			return _failure("v076_monster_region_crossing_count_mismatch")
		if str(monster.get("movement_class", "")) == "GROUND":
			if trample_sum != travelled or monster.get("trample_distance_by_region_mu", {}) != expected_physical.get("distance_by_region_mu", {}):
				return _failure("v076_monster_ground_trample_distance_mismatch")
			var expected_damage := Codec.compute_trample_damage_by_region(
				expected_physical.get("distance_by_region_mu", {}) as Dictionary,
				int(monster.get("effective_trample_efficiency_ppm", 0))
			)
			if (
				monster.get("trample_damage_by_region", {}) != expected_damage
				or int(monster.get("total_trample_damage", -1)) != _sum_values(expected_damage)
			):
				return _failure("v076_monster_ground_trample_damage_mismatch")
		else:
			if trample_sum != 0 or int(monster.get("total_trample_damage", -1)) != 0:
				return _failure("v076_monster_non_ground_trample_nonzero")
		if int(monster.get("move_revision", 0)) > 0:
			var route := monster.get("route", {}) as Dictionary
			var route_validation := Metric.validate_route(route, str(monster.get("route_sha256", "")))
			if not bool(route_validation.get("accepted", false)):
				return _failure(str(route_validation.get("reason", "v076_monster_route_invalid")))
			if travelled > int(monster.get("max_geodesic_distance_mu", 0)) or travelled > int(route.get("total_distance_mu", 0)):
				return _failure("v076_monster_distance_bound_exceeded")
			var current_face_id := int(monster.get("current_face_id", -1))
			if current_face_id < 0 or current_face_id >= owners.size():
				return _failure("v076_monster_position_face_invalid")
			if int(monster.get("accepted_tick", 0)) <= 0 or int(monster.get("accepted_authority_sequence", 0)) <= 0:
				return _failure("v076_monster_acceptance_identity_missing")
			if route.get("target_point", {}) != monster.get("target_point", {}):
				return _failure("v076_monster_target_point_cross_bind_failed")
	if StateCodec.count_float_fields(state) != 0:
		return _failure("v076_monster_float_authority_detected")
	return {
		"accepted": true,
		"reason": "",
		"topology_sha256": Codec.REQUIRED_TOPOLOGY_SHA256,
		"state_sha256": StateCodec.fingerprint(state),
		"monster_count": (state.get("monsters", {}) as Dictionary).size(),
		"asset_activation_count": activation_log.size(),
		"float_authority_field_count": 0,
	}


static func _expected_physical_projection(monster: Dictionary, owners: Array) -> Dictionary:
	if int(monster.get("move_revision", 0)) == 0:
		return {"accepted": true, "reason": "", "distance_by_region_mu": {}, "region_crossing_count": 0}
	var route := monster.get("route", {}) as Dictionary
	var face_path := route.get("face_path", []) as Array
	var remaining_distance_mu := int(monster.get("travelled_distance_mu", 0))
	var distance_by_region_mu := {}
	var crossing_count := 0
	for segment_index in range(maxi(0, face_path.size() - 1)):
		if remaining_distance_mu <= 0:
			break
		var canonical_segment_distance_mu := Metric.segment_distance_at(route, segment_index)
		if canonical_segment_distance_mu <= 0:
			return _failure("v076_monster_physical_segment_distance_missing")
		var segment_distance_mu := mini(remaining_distance_mu, canonical_segment_distance_mu)
		var allocation := Metric.interval_region_distance(
			int(face_path[segment_index]),
			int(face_path[segment_index + 1]),
			canonical_segment_distance_mu,
			0,
			segment_distance_mu,
			owners
		)
		if not bool(allocation.get("accepted", false)):
			return _failure(str(allocation.get("reason", "v076_monster_physical_projection_failed")))
		for region_id_variant in (allocation.get("distance_by_region_mu", {}) as Dictionary).keys():
			var region_id := str(region_id_variant)
			distance_by_region_mu[region_id] = int(distance_by_region_mu.get(region_id, 0)) + int((allocation.get("distance_by_region_mu", {}) as Dictionary)[region_id_variant])
		if bool(allocation.get("crossed_region_boundary", false)):
			crossing_count += 1
		remaining_distance_mu -= segment_distance_mu
	if remaining_distance_mu != 0:
		return _failure("v076_monster_physical_projection_distance_overflow")
	return {
		"accepted": true,
		"reason": "",
		"distance_by_region_mu": distance_by_region_mu,
		"region_crossing_count": crossing_count,
	}


static func _sum_values(values: Dictionary) -> int:
	var total := 0
	for value_variant in values.values():
		total += int(value_variant)
	return total


static func _has_exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_name in fields:
		if not value.has(field_name):
			return false
	return true


static func validate_execution_lineage(execution_log: Array, derived_outbox: Array) -> Dictionary:
	var outbox_by_sha := {}
	for entry_variant in derived_outbox:
		if not (entry_variant is Dictionary):
			return _failure("v076_monster_outbox_entry_invalid")
		var entry := entry_variant as Dictionary
		outbox_by_sha[StateCodec.fingerprint(entry)] = entry
	var expected_sequence := 1
	for log_variant in execution_log:
		if not (log_variant is Dictionary):
			return _failure("v076_monster_execution_log_entry_invalid")
		var log_entry := log_variant as Dictionary
		if int(log_entry.get("authority_sequence", 0)) != expected_sequence:
			return _failure("v076_monster_authority_sequence_gap")
		expected_sequence += 1
		if str(log_entry.get("command_source", "")) == "DERIVED":
			var source_sha := str(log_entry.get("source_outbox_sha256", ""))
			if source_sha.is_empty() or not outbox_by_sha.has(source_sha):
				return _failure("v076_monster_derived_lineage_missing")
		elif str(log_entry.get("command_source", "")) != "ROOT":
			return _failure("v076_monster_command_source_invalid")
	return {"accepted": true, "reason": "", "authority_sequence_count": execution_log.size()}


static func _failure(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}
