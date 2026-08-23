@tool
extends RefCounted
class_name V076MonsterL1AuthorityCodecV1

const StateCodec := preload("res://scripts/v076/simulation/v076_authority_state_codec.gd")
const PartitionCodec := preload("res://scripts/v076/map/v076_partition_authority_codec_v1.gd")
const PartitionValidator := preload("res://scripts/v076/map/v076_partition_validator_v1.gd")
const Metric := preload("res://scripts/v076/monster/v076_integer_geodesic_metric_v1.gd")

const SCHEMA_VERSION := 3
const DOMAIN_ID := "monster.l1.move"
const START_COMMAND_TYPE := "start_directional_geodesic_move"
const START_PRODUCTION_BATCH_COMMAND_TYPE := "start_production_autonomy_geodesic_batch"
const ADVANCE_COMMAND_TYPE := "advance_directional_geodesic_move"
const MOVEMENT_CLASSES := ["GROUND", "FLYING", "PHASE"]
const MOVEMENT_STATUSES := ["IDLE", "MOVING", "ARRIVED", "MAX_DISTANCE"]
const REQUIRED_TOPOLOGY_SHA256 := Metric.REQUIRED_TOPOLOGY_SHA256

const STATE_FIELDS := [
	"schema_version", "domain_id", "topology_sha256", "partition",
	"partition_sha256", "owner_by_face", "monsters", "assets",
	"asset_activation_log", "move_receipts", "fizzle_receipts",
]
const MONSTER_FIELDS := [
	"schema_version", "monster_id", "movement_class", "current_face_id",
	"target_face_id", "target_point", "route", "route_sha256", "route_segment_index",
	"segment_progress_mu", "speed_mu_per_tick", "max_geodesic_distance_mu",
	"travelled_distance_mu", "status", "accepted_tick",
	"accepted_authority_sequence", "last_move_tick", "last_move_authority_sequence",
	"region_crossing_count", "trample_efficiency_ppm", "frozen_trample_modifiers_ppm",
	"effective_trample_efficiency_ppm", "trample_distance_by_region_mu",
	"trample_damage_by_region", "total_trample_damage", "move_revision",
	"next_step_index", "active_asset_id", "root_command_id", "production_cutover",
	"source_generation", "production_movement_id", "source_region_id",
	"target_region_id",
]
const ASSET_FIELDS := [
	"schema_version", "asset_id", "preferred_color", "total_quantity",
	"quantity_remaining", "cooldown_ticks", "cooldown_until_tick", "activation_count",
	"last_activation_command_id", "last_activation_tick",
	"last_activation_authority_sequence",
]
const START_PAYLOAD_FIELDS := [
	"monster_id", "target_face_id", "target_point", "max_geodesic_distance_mu",
	"speed_mu_per_tick", "asset_id", "preferred_color",
	"trample_modifiers_ppm", "expected_move_revision",
]
const ADVANCE_PAYLOAD_FIELDS := [
	"monster_id", "movement_revision", "step_index", "route_sha256",
]
const PRODUCTION_BATCH_PAYLOAD_FIELDS := ["plan_fingerprint", "moves"]
const PRODUCTION_MOVE_FIELDS := [
	"production_movement_id", "monster_id", "source_generation",
	"source_region_id", "target_region_id", "start_face_id", "target_face_id",
	"target_point", "max_geodesic_distance_mu", "speed_mu_per_tick",
	"movement_class", "trample_efficiency_ppm", "expected_move_revision",
]


static func build_initial_state(partition: Dictionary, monster_specs: Array, asset_specs: Array) -> Dictionary:
	var partition_validation := PartitionValidator.validate_partition(partition)
	if not bool(partition_validation.get("accepted", false)):
		return _failure("v076_monster_partition_invalid:%s" % str(partition_validation.get("reason", "")))
	if str(partition.get("topology_sha256", "")) != REQUIRED_TOPOLOGY_SHA256:
		return _failure("v076_monster_partition_topology_mismatch")
	var owner_by_face := (partition.get("owner_by_face", []) as Array).duplicate(true)
	var monsters := {}
	for spec_variant in monster_specs:
		if not (spec_variant is Dictionary):
			return _failure("v076_monster_spec_not_dictionary")
		var spec := spec_variant as Dictionary
		if (
			spec.size() != 4
			or not spec.has("monster_id")
			or not spec.has("movement_class")
			or not spec.has("start_face_id")
			or not spec.has("trample_efficiency_ppm")
		):
			return _failure("v076_monster_spec_shape_invalid")
		var monster_id := str(spec.get("monster_id", ""))
		var movement_class := str(spec.get("movement_class", ""))
		var start_face_id := int(spec.get("start_face_id", -1))
		var trample_efficiency_ppm := int(spec.get("trample_efficiency_ppm", -1))
		if (
			monster_id.is_empty() or monsters.has(monster_id)
			or not MOVEMENT_CLASSES.has(movement_class)
			or start_face_id < 0 or start_face_id >= owner_by_face.size()
			or typeof(spec.get("trample_efficiency_ppm")) != TYPE_INT
			or trample_efficiency_ppm < 0 or trample_efficiency_ppm > 1_000_000
		):
			return _failure("v076_monster_spec_invalid")
		monsters[monster_id] = {
			"schema_version": SCHEMA_VERSION,
			"monster_id": monster_id,
			"movement_class": movement_class,
			"current_face_id": start_face_id,
			"target_face_id": start_face_id,
			"target_point": {},
			"route": {},
			"route_sha256": "",
			"route_segment_index": 0,
			"segment_progress_mu": 0,
			"speed_mu_per_tick": 0,
			"max_geodesic_distance_mu": 0,
			"travelled_distance_mu": 0,
			"status": "IDLE",
			"accepted_tick": 0,
			"accepted_authority_sequence": 0,
			"last_move_tick": 0,
			"last_move_authority_sequence": 0,
			"region_crossing_count": 0,
			"trample_efficiency_ppm": trample_efficiency_ppm,
			"frozen_trample_modifiers_ppm": [],
			"effective_trample_efficiency_ppm": 0,
			"trample_distance_by_region_mu": {},
			"trample_damage_by_region": {},
			"total_trample_damage": 0,
			"move_revision": 0,
			"next_step_index": 0,
			"active_asset_id": "",
			"root_command_id": "",
			"production_cutover": false,
			"source_generation": 0,
			"production_movement_id": "",
			"source_region_id": "",
			"target_region_id": "",
		}
	var assets := {}
	for spec_variant in asset_specs:
		if not (spec_variant is Dictionary):
			return _failure("v076_monster_asset_spec_not_dictionary")
		var spec := spec_variant as Dictionary
		if (
			spec.size() != 4
			or not spec.has("asset_id")
			or not spec.has("preferred_color")
			or not spec.has("quantity")
			or not spec.has("cooldown_ticks")
		):
			return _failure("v076_monster_asset_spec_shape_invalid")
		var asset_id := str(spec.get("asset_id", ""))
		var preferred_color := str(spec.get("preferred_color", ""))
		var quantity := int(spec.get("quantity", -1))
		var cooldown_ticks := int(spec.get("cooldown_ticks", -1))
		if (
			asset_id.is_empty() or assets.has(asset_id) or preferred_color.is_empty()
			or typeof(spec.get("quantity")) != TYPE_INT or quantity <= 0
			or typeof(spec.get("cooldown_ticks")) != TYPE_INT or cooldown_ticks < 0
		):
			return _failure("v076_monster_asset_spec_invalid")
		assets[asset_id] = {
			"schema_version": SCHEMA_VERSION,
			"asset_id": asset_id,
			"preferred_color": preferred_color,
			"total_quantity": quantity,
			"quantity_remaining": quantity,
			"cooldown_ticks": cooldown_ticks,
			"cooldown_until_tick": 0,
			"activation_count": 0,
			"last_activation_command_id": "",
			"last_activation_tick": 0,
			"last_activation_authority_sequence": 0,
		}
	var state := {
		"schema_version": SCHEMA_VERSION,
		"domain_id": DOMAIN_ID,
		"topology_sha256": REQUIRED_TOPOLOGY_SHA256,
		"partition": partition.duplicate(true),
		"partition_sha256": PartitionCodec.fingerprint_partition(partition),
		"owner_by_face": owner_by_face,
		"monsters": monsters,
		"assets": assets,
		"asset_activation_log": [],
		"move_receipts": [],
		"fizzle_receipts": [],
	}
	# The partition was canonical-validated at function entry; avoid a second
	# identical Stage 2 generation audit while closing Monster-owned bytes.
	var validation := validate_state(state, false)
	if not bool(validation.get("valid", false)):
		return _failure(str(validation.get("reason", "v076_monster_initial_state_invalid")))
	return {
		"accepted": true,
		"reason": "",
		"state": state,
		"state_sha256": StateCodec.fingerprint(state),
	}


static func build_production_monster_record(move: Dictionary) -> Dictionary:
	var validation := validate_production_move(move)
	if not bool(validation.get("valid", false)):
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"monster_id": str(move.get("monster_id", "")),
		"movement_class": str(move.get("movement_class", "")),
		"current_face_id": int(move.get("start_face_id", -1)),
		"target_face_id": int(move.get("start_face_id", -1)),
		"target_point": {},
		"route": {},
		"route_sha256": "",
		"route_segment_index": 0,
		"segment_progress_mu": 0,
		"speed_mu_per_tick": 0,
		"max_geodesic_distance_mu": 0,
		"travelled_distance_mu": 0,
		"status": "IDLE",
		"accepted_tick": 0,
		"accepted_authority_sequence": 0,
		"last_move_tick": 0,
		"last_move_authority_sequence": 0,
		"region_crossing_count": 0,
		"trample_efficiency_ppm": int(move.get("trample_efficiency_ppm", 0)),
		"frozen_trample_modifiers_ppm": [],
		"effective_trample_efficiency_ppm": 0,
		"trample_distance_by_region_mu": {},
		"trample_damage_by_region": {},
		"total_trample_damage": 0,
		"move_revision": 0,
		"next_step_index": 0,
		"active_asset_id": "",
		"root_command_id": "",
		"production_cutover": true,
		"source_generation": int(move.get("source_generation", 0)),
		"production_movement_id": "",
		"source_region_id": str(move.get("source_region_id", "")),
		"target_region_id": str(move.get("source_region_id", "")),
	}


static func validate_state(state: Variant, validate_partition_canonical: bool = false) -> Dictionary:
	if not (state is Dictionary):
		return _invalid("v076_monster_state_not_dictionary")
	var value := state as Dictionary
	if not _has_exact_fields(value, STATE_FIELDS):
		return _invalid("v076_monster_state_shape_invalid")
	var closed := StateCodec.validate(value)
	if not bool(closed.get("valid", false)):
		return closed
	if (
		typeof(value.get("schema_version")) != TYPE_INT
		or int(value.get("schema_version", 0)) != SCHEMA_VERSION
		or str(value.get("domain_id", "")) != DOMAIN_ID
		or str(value.get("topology_sha256", "")) != REQUIRED_TOPOLOGY_SHA256
		or not (value.get("partition") is Dictionary)
		or not (value.get("owner_by_face") is Array)
		or not (value.get("monsters") is Dictionary)
		or not (value.get("assets") is Dictionary)
		or not (value.get("asset_activation_log") is Array)
		or not (value.get("move_receipts") is Array)
		or not (value.get("fizzle_receipts") is Array)
	):
		return _invalid("v076_monster_state_contract_mismatch")
	var partition := value.get("partition", {}) as Dictionary
	if (
		str(partition.get("topology_sha256", "")) != REQUIRED_TOPOLOGY_SHA256
		or str(value.get("partition_sha256", "")) != PartitionCodec.fingerprint_partition(partition)
		or value.get("owner_by_face", []) != partition.get("owner_by_face", [])
	):
		return _invalid("v076_monster_partition_binding_mismatch")
	if validate_partition_canonical:
		var canonical_partition := PartitionValidator.validate_partition(partition)
		if not bool(canonical_partition.get("accepted", false)):
			return _invalid("v076_monster_partition_noncanonical")
	var owner_by_face := value.get("owner_by_face", []) as Array
	if owner_by_face.size() != 320:
		return _invalid("v076_monster_owner_cardinality_invalid")
	var monsters := value.get("monsters", {}) as Dictionary
	for monster_id_variant in monsters.keys():
		if typeof(monster_id_variant) != TYPE_STRING or not (monsters[monster_id_variant] is Dictionary):
			return _invalid("v076_monster_inventory_invalid")
		var monster_validation := validate_monster(monsters[monster_id_variant] as Dictionary, owner_by_face.size())
		if not bool(monster_validation.get("valid", false)):
			return monster_validation
		if str((monsters[monster_id_variant] as Dictionary).get("monster_id", "")) != str(monster_id_variant):
			return _invalid("v076_monster_inventory_key_mismatch")
	var assets := value.get("assets", {}) as Dictionary
	for asset_id_variant in assets.keys():
		if typeof(asset_id_variant) != TYPE_STRING or not (assets[asset_id_variant] is Dictionary):
			return _invalid("v076_monster_asset_inventory_invalid")
		var asset_validation := validate_asset(assets[asset_id_variant] as Dictionary)
		if not bool(asset_validation.get("valid", false)):
			return asset_validation
		if str((assets[asset_id_variant] as Dictionary).get("asset_id", "")) != str(asset_id_variant):
			return _invalid("v076_monster_asset_inventory_key_mismatch")
	return {"valid": true, "reason": ""}


static func validate_monster(monster: Dictionary, face_count: int) -> Dictionary:
	if not _has_exact_fields(monster, MONSTER_FIELDS):
		return _invalid("v076_monster_record_shape_invalid")
	var monster_id := str(monster.get("monster_id", ""))
	var movement_class := str(monster.get("movement_class", ""))
	var current_face_id := int(monster.get("current_face_id", -1))
	var target_face_id := int(monster.get("target_face_id", -1))
	if (
		int(monster.get("schema_version", 0)) != SCHEMA_VERSION
		or monster_id.is_empty() or not MOVEMENT_CLASSES.has(movement_class)
		or current_face_id < 0 or current_face_id >= face_count
		or target_face_id < 0 or target_face_id >= face_count
		or not MOVEMENT_STATUSES.has(str(monster.get("status", "")))
		or int(monster.get("route_segment_index", -1)) < 0
		or int(monster.get("segment_progress_mu", -1)) < 0
		or int(monster.get("speed_mu_per_tick", -1)) < 0
		or int(monster.get("max_geodesic_distance_mu", -1)) < 0
		or int(monster.get("travelled_distance_mu", -1)) < 0
		or int(monster.get("accepted_tick", -1)) < 0
		or int(monster.get("accepted_authority_sequence", -1)) < 0
		or int(monster.get("last_move_tick", -1)) < 0
		or int(monster.get("last_move_authority_sequence", -1)) < 0
		or int(monster.get("region_crossing_count", -1)) < 0
		or typeof(monster.get("trample_efficiency_ppm")) != TYPE_INT
		or int(monster.get("trample_efficiency_ppm", -1)) < 0
		or int(monster.get("trample_efficiency_ppm", -1)) > 1_000_000
		or not (monster.get("frozen_trample_modifiers_ppm") is Array)
		or typeof(monster.get("effective_trample_efficiency_ppm")) != TYPE_INT
		or int(monster.get("effective_trample_efficiency_ppm", -1)) < 0
		or int(monster.get("effective_trample_efficiency_ppm", -1)) > 1_000_000
		or int(monster.get("move_revision", -1)) < 0
		or int(monster.get("next_step_index", -1)) < 0
		or not (monster.get("route") is Dictionary)
		or not (monster.get("target_point") is Dictionary)
		or not (monster.get("trample_distance_by_region_mu") is Dictionary)
		or not (monster.get("trample_damage_by_region") is Dictionary)
		or typeof(monster.get("total_trample_damage")) != TYPE_INT
		or int(monster.get("total_trample_damage", -1)) < 0
		or typeof(monster.get("production_cutover")) != TYPE_BOOL
		or typeof(monster.get("source_generation")) != TYPE_INT
		or int(monster.get("source_generation", -1)) < 0
	):
		return _invalid("v076_monster_record_contract_invalid")
	var production_cutover := bool(monster.get("production_cutover", false))
	if production_cutover:
		if (
			int(monster.get("source_generation", 0)) <= 0
			or str(monster.get("source_region_id", "")).is_empty()
			or str(monster.get("target_region_id", "")).is_empty()
			or (
				int(monster.get("move_revision", 0)) > 0
				and str(monster.get("production_movement_id", "")).is_empty()
			)
		):
			return _invalid("v076_monster_production_binding_invalid")
	elif (
		int(monster.get("source_generation", 0)) != 0
		or not str(monster.get("production_movement_id", "")).is_empty()
		or not str(monster.get("source_region_id", "")).is_empty()
		or not str(monster.get("target_region_id", "")).is_empty()
	):
		return _invalid("v076_monster_isolated_production_fields_not_empty")
	var frozen_modifiers := monster.get("frozen_trample_modifiers_ppm", []) as Array
	if frozen_modifiers.size() > 8:
		return _invalid("v076_monster_trample_modifier_count_invalid")
	for modifier_variant in frozen_modifiers:
		if typeof(modifier_variant) != TYPE_INT or int(modifier_variant) < 0 or int(modifier_variant) > 1_000_000:
			return _invalid("v076_monster_trample_modifier_invalid")
	var route := monster.get("route", {}) as Dictionary
	if int(monster.get("move_revision", 0)) == 0:
		if (
			not route.is_empty()
			or not (monster.get("target_point", {}) as Dictionary).is_empty()
			or not str(monster.get("route_sha256", "")).is_empty()
			or str(monster.get("status", "")) != "IDLE"
			or int(monster.get("next_step_index", -1)) != 0
			or not frozen_modifiers.is_empty()
			or int(monster.get("effective_trample_efficiency_ppm", -1)) != 0
		):
			return _invalid("v076_monster_initial_record_invalid")
	else:
		var route_validation := Metric.validate_route(route, str(monster.get("route_sha256", "")))
		if not bool(route_validation.get("accepted", false)):
			return _invalid(str(route_validation.get("reason", "v076_monster_route_invalid")))
		if (
			int(route.get("target_face_id", -1)) != target_face_id
			or route.get("target_point", {}) != monster.get("target_point", {})
		):
			return _invalid("v076_monster_target_route_mismatch")
		if int(monster.get("route_segment_index", -1)) > int(route.get("segment_count", -1)):
			return _invalid("v076_monster_route_cursor_invalid")
		if int(monster.get("next_step_index", 0)) <= 0:
			return _invalid("v076_monster_next_step_index_invalid")
		var face_path := route.get("face_path", []) as Array
		var segment_index := int(monster.get("route_segment_index", -1))
		var segment_progress_mu := int(monster.get("segment_progress_mu", -1))
		var segment_count := int(route.get("segment_count", -1))
		var travelled_distance_mu := int(monster.get("travelled_distance_mu", -1))
		var distance_before_segment := Metric.distance_before_segment(route, segment_index)
		if distance_before_segment < 0 or travelled_distance_mu != distance_before_segment + segment_progress_mu:
			return _invalid("v076_monster_position_distance_cross_bind_failed")
		var expected_current_face_id := int(face_path[segment_index])
		if segment_index < segment_count:
			var current_segment_distance_mu := Metric.segment_distance_at(route, segment_index)
			if segment_progress_mu < 0 or segment_progress_mu >= current_segment_distance_mu:
				return _invalid("v076_monster_segment_progress_invalid")
			if segment_progress_mu >= Metric.segment_midpoint_mu(current_segment_distance_mu):
				expected_current_face_id = int(face_path[segment_index + 1])
		elif segment_progress_mu != 0:
			return _invalid("v076_monster_terminal_segment_progress_invalid")
		if current_face_id != expected_current_face_id:
			return _invalid("v076_monster_current_face_position_mismatch")
		var status := str(monster.get("status", ""))
		if (
			(status == "ARRIVED" and (segment_index != segment_count or segment_progress_mu != 0 or travelled_distance_mu != int(route.get("total_distance_mu", -1))))
			or (status == "MAX_DISTANCE" and (segment_index >= segment_count or travelled_distance_mu != int(monster.get("max_geodesic_distance_mu", -1))))
			or (status == "MOVING" and (segment_index >= segment_count or travelled_distance_mu >= int(monster.get("max_geodesic_distance_mu", -1))))
			or int(monster.get("speed_mu_per_tick", 0)) <= 0
			or int(monster.get("max_geodesic_distance_mu", 0)) <= 0
			or int(monster.get("accepted_tick", 0)) <= 0
			or int(monster.get("accepted_authority_sequence", 0)) <= 0
			or str(monster.get("active_asset_id", "")).is_empty()
			or str(monster.get("root_command_id", "")).is_empty()
			or int(monster.get("effective_trample_efficiency_ppm", -1)) != compute_effective_trample_efficiency_ppm(
				int(monster.get("trample_efficiency_ppm", 0)),
				frozen_modifiers
			)
		):
			return _invalid("v076_monster_movement_semantic_mismatch")
	for region_id_variant in (monster.get("trample_distance_by_region_mu", {}) as Dictionary).keys():
		if (
			typeof(region_id_variant) != TYPE_STRING
			or str(int(str(region_id_variant))) != str(region_id_variant)
			or int(str(region_id_variant)) < 0
			or int((monster.get("trample_distance_by_region_mu", {}) as Dictionary)[region_id_variant]) < 0
		):
			return _invalid("v076_monster_trample_ledger_invalid")
	for region_id_variant in (monster.get("trample_damage_by_region", {}) as Dictionary).keys():
		if (
			typeof(region_id_variant) != TYPE_STRING
			or str(int(str(region_id_variant))) != str(region_id_variant)
			or int(str(region_id_variant)) < 0
			or int((monster.get("trample_damage_by_region", {}) as Dictionary)[region_id_variant]) < 0
		):
			return _invalid("v076_monster_trample_damage_ledger_invalid")
	var expected_damage := compute_trample_damage_by_region(
		monster.get("trample_distance_by_region_mu", {}) as Dictionary,
		int(monster.get("effective_trample_efficiency_ppm", 0))
	)
	if movement_class == "GROUND":
		if (
			monster.get("trample_damage_by_region", {}) != expected_damage
			or int(monster.get("total_trample_damage", -1)) != _sum_integer_values(expected_damage)
		):
			return _invalid("v076_monster_ground_trample_damage_mismatch")
	elif (
		not (monster.get("trample_distance_by_region_mu", {}) as Dictionary).is_empty()
		or not (monster.get("trample_damage_by_region", {}) as Dictionary).is_empty()
		or int(monster.get("total_trample_damage", -1)) != 0
	):
		return _invalid("v076_monster_non_ground_trample_not_zero")
	return {"valid": true, "reason": ""}


static func validate_asset(asset: Dictionary) -> Dictionary:
	if not _has_exact_fields(asset, ASSET_FIELDS):
		return _invalid("v076_monster_asset_shape_invalid")
	if (
		int(asset.get("schema_version", 0)) != SCHEMA_VERSION
		or str(asset.get("asset_id", "")).is_empty()
		or str(asset.get("preferred_color", "")).is_empty()
		or typeof(asset.get("total_quantity")) != TYPE_INT
		or int(asset.get("total_quantity", 0)) <= 0
		or typeof(asset.get("quantity_remaining")) != TYPE_INT
		or int(asset.get("quantity_remaining", -1)) < 0
		or int(asset.get("quantity_remaining", 0)) > int(asset.get("total_quantity", 0))
		or int(asset.get("cooldown_ticks", -1)) < 0
		or int(asset.get("cooldown_until_tick", -1)) < 0
		or int(asset.get("activation_count", -1)) < 0
		or int(asset.get("activation_count", 0)) > int(asset.get("total_quantity", 0))
		or int(asset.get("quantity_remaining", -1)) != int(asset.get("total_quantity", 0)) - int(asset.get("activation_count", 0))
		or int(asset.get("last_activation_tick", -1)) < 0
		or int(asset.get("last_activation_authority_sequence", -1)) < 0
	):
		return _invalid("v076_monster_asset_contract_invalid")
	var activation_count := int(asset.get("activation_count", 0))
	if (
		(activation_count == 0 and (
			not str(asset.get("last_activation_command_id", "")).is_empty()
			or int(asset.get("last_activation_tick", -1)) != 0
			or int(asset.get("last_activation_authority_sequence", -1)) != 0
		))
		or (activation_count > 0 and (
			str(asset.get("last_activation_command_id", "")).is_empty()
			or int(asset.get("last_activation_tick", 0)) <= 0
			or int(asset.get("last_activation_authority_sequence", 0)) <= 0
		))
	):
		return _invalid("v076_monster_asset_activation_identity_invalid")
	return {"valid": true, "reason": ""}


static func validate_start_payload(payload: Variant) -> Dictionary:
	if not (payload is Dictionary) or not _has_exact_fields(payload as Dictionary, START_PAYLOAD_FIELDS):
		return _invalid("v076_monster_start_payload_shape_invalid")
	var value := payload as Dictionary
	if (
		str(value.get("monster_id", "")).is_empty()
		or str(value.get("asset_id", "")).is_empty()
		or str(value.get("preferred_color", "")).is_empty()
		or typeof(value.get("target_face_id")) != TYPE_INT
		or not (value.get("target_point") is Dictionary)
		or typeof(value.get("max_geodesic_distance_mu")) != TYPE_INT
		or typeof(value.get("speed_mu_per_tick")) != TYPE_INT
		or not (value.get("trample_modifiers_ppm") is Array)
		or typeof(value.get("expected_move_revision")) != TYPE_INT
		or int(value.get("max_geodesic_distance_mu", 0)) <= 0
		or int(value.get("speed_mu_per_tick", 0)) <= 0
		or int(value.get("expected_move_revision", -1)) < 0
	):
		return _invalid("v076_monster_start_payload_invalid")
	var target_point_validation := Metric.validate_target_point(
		value.get("target_point", {}) as Dictionary,
		int(value.get("target_face_id", -1))
	)
	if not bool(target_point_validation.get("accepted", false)):
		return _invalid(str(target_point_validation.get("reason", "v076_monster_target_point_invalid")))
	var modifiers := value.get("trample_modifiers_ppm", []) as Array
	if modifiers.size() > 8:
		return _invalid("v076_monster_trample_modifier_count_invalid")
	for modifier_variant in modifiers:
		if typeof(modifier_variant) != TYPE_INT or int(modifier_variant) < 0 or int(modifier_variant) > 1_000_000:
			return _invalid("v076_monster_trample_modifier_invalid")
	return StateCodec.validate(value)


static func validate_advance_payload(payload: Variant) -> Dictionary:
	if not (payload is Dictionary) or not _has_exact_fields(payload as Dictionary, ADVANCE_PAYLOAD_FIELDS):
		return _invalid("v076_monster_advance_payload_shape_invalid")
	var value := payload as Dictionary
	if (
		str(value.get("monster_id", "")).is_empty()
		or str(value.get("route_sha256", "")).is_empty()
		or typeof(value.get("movement_revision")) != TYPE_INT
		or typeof(value.get("step_index")) != TYPE_INT
		or int(value.get("movement_revision", 0)) <= 0
		or int(value.get("step_index", 0)) <= 0
	):
		return _invalid("v076_monster_advance_payload_invalid")
	return StateCodec.validate(value)


static func validate_production_batch_payload(payload: Variant) -> Dictionary:
	if not (payload is Dictionary) or not _has_exact_fields(
		payload as Dictionary,
		PRODUCTION_BATCH_PAYLOAD_FIELDS
	):
		return _invalid("v076_monster_production_batch_payload_shape_invalid")
	var value := payload as Dictionary
	if (
		str(value.get("plan_fingerprint", "")).is_empty()
		or not (value.get("moves") is Array)
		or (value.get("moves", []) as Array).is_empty()
		or (value.get("moves", []) as Array).size() > 64
	):
		return _invalid("v076_monster_production_batch_payload_invalid")
	var monster_ids := {}
	var movement_ids := {}
	for move_variant in value.get("moves", []) as Array:
		var move_validation := validate_production_move(move_variant)
		if not bool(move_validation.get("valid", false)):
			return move_validation
		var move := move_variant as Dictionary
		var monster_id := str(move.get("monster_id", ""))
		var movement_id := str(move.get("production_movement_id", ""))
		if monster_ids.has(monster_id) or movement_ids.has(movement_id):
			return _invalid("v076_monster_production_batch_identity_duplicate")
		monster_ids[monster_id] = true
		movement_ids[movement_id] = true
	return StateCodec.validate(value)


static func validate_production_move(move: Variant) -> Dictionary:
	if not (move is Dictionary) or not _has_exact_fields(
		move as Dictionary,
		PRODUCTION_MOVE_FIELDS
	):
		return _invalid("v076_monster_production_move_shape_invalid")
	var value := move as Dictionary
	if (
		str(value.get("production_movement_id", "")).is_empty()
		or str(value.get("monster_id", "")).is_empty()
		or typeof(value.get("source_generation")) != TYPE_INT
		or int(value.get("source_generation", 0)) <= 0
		or str(value.get("source_region_id", "")).is_empty()
		or str(value.get("target_region_id", "")).is_empty()
		or typeof(value.get("start_face_id")) != TYPE_INT
		or int(value.get("start_face_id", -1)) < 0
		or typeof(value.get("target_face_id")) != TYPE_INT
		or int(value.get("target_face_id", -1)) < 0
		or int(value.get("start_face_id", -1)) == int(value.get("target_face_id", -1))
		or not (value.get("target_point") is Dictionary)
		or typeof(value.get("max_geodesic_distance_mu")) != TYPE_INT
		or int(value.get("max_geodesic_distance_mu", 0)) <= 0
		or typeof(value.get("speed_mu_per_tick")) != TYPE_INT
		or int(value.get("speed_mu_per_tick", 0)) <= 0
		or str(value.get("movement_class", "")) not in MOVEMENT_CLASSES
		or typeof(value.get("trample_efficiency_ppm")) != TYPE_INT
		or int(value.get("trample_efficiency_ppm", -1)) < 0
		or int(value.get("trample_efficiency_ppm", 0)) > 1_000_000
		or typeof(value.get("expected_move_revision")) != TYPE_INT
		or int(value.get("expected_move_revision", -1)) < 0
	):
		return _invalid("v076_monster_production_move_invalid")
	var target_validation := Metric.validate_target_point(
		value.get("target_point", {}) as Dictionary,
		int(value.get("target_face_id", -1))
	)
	if not bool(target_validation.get("accepted", false)):
		return _invalid(str(target_validation.get(
			"reason",
			"v076_monster_production_target_point_invalid"
		)))
	return StateCodec.validate(value)


static func compute_effective_trample_efficiency_ppm(base_efficiency_ppm: int, modifiers_ppm: Array) -> int:
	if base_efficiency_ppm < 0 or base_efficiency_ppm > 1_000_000:
		return -1
	var effective := base_efficiency_ppm
	for modifier_variant in modifiers_ppm:
		if typeof(modifier_variant) != TYPE_INT:
			return -1
		var modifier := int(modifier_variant)
		if modifier < 0 or modifier > 1_000_000:
			return -1
		@warning_ignore("integer_division")
		effective = (effective * modifier) / 1_000_000
	return effective


static func compute_trample_damage_by_region(distance_by_region_mu: Dictionary, effective_efficiency_ppm: int) -> Dictionary:
	var damage_by_region := {}
	if effective_efficiency_ppm < 0 or effective_efficiency_ppm > 1_000_000:
		return damage_by_region
	for region_id_variant in distance_by_region_mu.keys():
		var distance_mu := int(distance_by_region_mu[region_id_variant])
		@warning_ignore("integer_division")
		damage_by_region[str(region_id_variant)] = (distance_mu * effective_efficiency_ppm) / 1_000_000
	return damage_by_region


static func _sum_integer_values(values: Dictionary) -> int:
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


static func _failure(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}


static func _invalid(reason: String) -> Dictionary:
	return {"valid": false, "reason": reason}
