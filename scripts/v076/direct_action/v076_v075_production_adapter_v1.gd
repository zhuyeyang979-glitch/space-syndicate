extends Node
class_name V076V075ProductionAdapterV1

## Stateless consumer adapter for the authorized production composition.
##
## V075RuntimeOwner remains the only production card, asset, military-source,
## and combat mutation authority.  This adapter only translates the narrow
## V076 Direct Action dependency surface.  It stores only bindings and
## diagnostics; it owns no gameplay authority, ledger, queue, tick, map,
## asset, unit, damage, or presentation facts.

const CardDefinitionsV075 := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)
const AuthorityCommand := preload(
	"res://scripts/v076/simulation/v076_authority_command_v1.gd"
)
const DomainRng := preload("res://scripts/v076/simulation/v076_domain_rng.gd")
const StateCodec := preload(
	"res://scripts/v076/simulation/v076_authority_state_codec.gd"
)
const PartitionCodec := preload(
	"res://scripts/v076/map/v076_partition_authority_codec_v1.gd"
)
const Partitioner := preload(
	"res://scripts/v076/map/v076_shared_half_edge_partition_v1.gd"
)
const MonsterCodec := preload(
	"res://scripts/v076/monster/v076_monster_l1_authority_codec_v1.gd"
)
const MonsterMetric := preload(
	"res://scripts/v076/monster/v076_integer_geodesic_metric_v1.gd"
)
const MonsterReducer := preload(
	"res://scripts/v076/monster/v076_monster_l1_reducer_v1.gd"
)
const CombatCatalog := preload(
	"res://scripts/v075/combat/v075_combat_catalog.gd"
)
const MonsterTrampleCore := preload(
	"res://scripts/v075/monster/v075_monster_trample_core.gd"
)
const FacilityDamageIntent := preload(
	"res://scripts/v075/combat/facility_combat_damage_intent_v1.gd"
)

const OWNER_ID := "component.current.v075_runtime_owner"
const ADAPTER_ID := "component.v076.v075_production_adapter"

var _runtime_owner: Variant
var _kernel: Variant
var _monster_production_configured := false
var _monster_plan_prepare_count := 0
var _monster_root_submission_count := 0
var _monster_terminal_receipt_attempt_count := 0
var _monster_terminal_receipt_commit_count := 0
var _monster_consumer_failure_count := 0


func bind_runtime_owner(runtime_owner: Variant) -> Dictionary:
	if runtime_owner == null:
		return _reject("v076_v075_production_runtime_owner_missing")
	var required := [
		"validate_v076_production_military_bundle",
		"v076_commit_production_asset_reservation",
		"v076_release_production_asset_reservation",
		"v076_consume_production_asset_reservation",
		"v076_military_unit_index_by_uid",
		"v076_military_roster_snapshot",
		"v076_claim_military_submission",
		"v076_release_military_submission_claim",
		"v076_remove_military_unit",
		"v076_dispatch_military_monster_damage",
		"v076_monster_production_consumer_context",
		"v076_monster_production_receipt_status",
		"consume_v076_monster_production_result",
		"_runtime_region_ids",
	]
	for method_name in required:
		if not runtime_owner.has_method(method_name):
			return _reject("v076_v075_production_runtime_owner_method_missing:%s" % method_name)
	_runtime_owner = runtime_owner
	return {
		"accepted": true,
		"reason": "",
		"adapter_id": ADAPTER_ID,
		"owner_id": OWNER_ID,
	}


func validate_authorized_bundle(bundle: Dictionary) -> Dictionary:
	if not _bound():
		return _reject("v076_v075_production_adapter_not_bound")
	return _runtime_owner.call(
		"validate_v076_production_military_bundle",
		bundle
	) as Dictionary


func exact_definition(card_id: String) -> Dictionary:
	var definition := CardDefinitionsV075.definition(card_id)
	if definition.is_empty() or CardDefinitionsV075.card_domain(
		str(definition.get("card_type", ""))
	) != "military":
		return {}
	var result := definition.duplicate(true)
	result["kind"] = "military_force"
	result["rank"] = int(definition.get("level", 0))
	return result


func rank(card_id: String) -> int:
	return int(CardDefinitionsV075.definition(card_id).get("level", 0))


func commit_reservation(plan: Dictionary) -> Dictionary:
	if not _bound():
		return _reject("v076_v075_production_adapter_not_bound")
	return _runtime_owner.call(
		"v076_commit_production_asset_reservation",
		plan
	) as Dictionary


func release_reservation(reservation_id: String, reason: String) -> Dictionary:
	if not _bound():
		return _reject("v076_v075_production_adapter_not_bound")
	return _runtime_owner.call(
		"v076_release_production_asset_reservation",
		reservation_id,
		reason
	) as Dictionary


func consume_reservation(
	reservation_id: String,
	settlement: Dictionary
) -> Dictionary:
	if not _bound():
		return _reject("v076_v075_production_adapter_not_bound")
	return _runtime_owner.call(
		"v076_consume_production_asset_reservation",
		reservation_id,
		settlement
	) as Dictionary


func unit_index_by_uid(unit_uid: int) -> int:
	if not _bound():
		return -1
	return int(_runtime_owner.call(
		"v076_military_unit_index_by_uid",
		unit_uid
	))


func roster_snapshot(include_hidden: bool = true) -> Array:
	if not _bound():
		return []
	return (_runtime_owner.call(
		"v076_military_roster_snapshot",
		include_hidden
	) as Array).duplicate(true)


func claim_submission(
	unit_uid: int,
	submission_id: String,
	card_instance_id: String,
	request_fingerprint: String
) -> Dictionary:
	if not _bound():
		return _reject("v076_v075_production_adapter_not_bound")
	return _runtime_owner.call(
		"v076_claim_military_submission",
		unit_uid,
		submission_id,
		card_instance_id,
		request_fingerprint
	) as Dictionary


func release_submission_claim(
	unit_uid: int,
	submission_id: String,
	reason: String
) -> Dictionary:
	if not _bound():
		return _reject("v076_v075_production_adapter_not_bound")
	return _runtime_owner.call(
		"v076_release_military_submission_claim",
		unit_uid,
		submission_id,
		reason
	) as Dictionary


func remove_unit(unit_index: int, reason: String) -> bool:
	if not _bound():
		return false
	return bool(_runtime_owner.call(
		"v076_remove_military_unit",
		unit_index,
		reason
	))


func dispatch_military_monster_damage(command: Dictionary) -> Dictionary:
	if not _bound():
		return {"handled": false, "reason": "v076_v075_production_adapter_not_bound"}
	return _runtime_owner.call(
		"v076_dispatch_military_monster_damage",
		command
	) as Dictionary


func configure_monster_production(
	kernel: Variant,
	root_seed: int,
	region_count: int,
	shape_complexity: String
) -> Dictionary:
	if not _bound():
		return _reject("v076_monster_production_runtime_owner_not_bound")
	if _monster_production_configured:
		return _reject("v076_monster_production_already_configured")
	if kernel == null \
			or not kernel.has_method("register_domain") \
			or not kernel.has_method("domain_state") \
			or not kernel.has_method("submit_command") \
			or not kernel.has_method("current_tick"):
		return _reject("v076_monster_production_kernel_invalid")
	if int(kernel.call("current_tick")) != 0:
		return _reject("v076_monster_production_registration_not_tick_zero")
	var region_ids := _runtime_region_ids()
	if region_count <= 0 or region_ids.size() != region_count:
		return _reject("v076_monster_production_region_binding_invalid")
	var rng := DomainRng.new()
	var rng_config := rng.configure(root_seed, PartitionCodec.DOMAIN_ID)
	if not bool(rng_config.get("accepted", false)):
		return _reject("v076_monster_production_partition_rng_invalid")
	var generated := Partitioner.generate(
		root_seed,
		region_count,
		shape_complexity,
		rng
	)
	if not bool(generated.get("accepted", false)):
		return _reject(str(generated.get(
			"reason",
			"v076_monster_production_partition_generation_failed"
		)))
	var initial := MonsterCodec.build_initial_state(
		generated.get("partition", {}) as Dictionary,
		[],
		[]
	)
	if not bool(initial.get("accepted", false)):
		return _reject(str(initial.get(
			"reason",
			"v076_monster_production_initial_state_invalid"
		)))
	var registration := kernel.call(
		"register_domain",
		MonsterCodec.DOMAIN_ID,
		initial.get("state", {}) as Dictionary,
		MonsterReducer
	) as Dictionary
	if not bool(registration.get("accepted", false)):
		return _reject(str(registration.get(
			"reason",
			"v076_monster_production_domain_registration_failed"
		)))
	_kernel = kernel
	_monster_production_configured = true
	return {
		"accepted": true,
		"reason": "",
		"domain_id": MonsterCodec.DOMAIN_ID,
		"partition_sha256": str(generated.get("partition_sha256", "")),
		"region_count": region_count,
		"production_asset_quantity_count": 0,
	}


func production_face_for_region(region_id: String) -> int:
	if not _monster_production_configured or region_id.is_empty():
		return -1
	var region_ids := _runtime_region_ids()
	var region_index := region_ids.find(region_id)
	var state := _monster_state()
	var seed_faces := (
		(state.get("partition", {}) as Dictionary).get("seed_face_ids", []) as Array
	)
	if region_index < 0 or region_index >= seed_faces.size():
		return -1
	return int(seed_faces[region_index])


func prepare_monster_autonomy_cutover(plan: Dictionary) -> Dictionary:
	if not _monster_production_configured:
		return _reject("v076_monster_production_not_configured")
	var plan_fingerprint := str(plan.get("plan_fingerprint", ""))
	if plan_fingerprint.is_empty() or not (plan.get("plans") is Array):
		return _reject("v076_monster_production_plan_invalid")
	var settlement_plan := plan.duplicate(true)
	var settlement_rows := settlement_plan.get("plans", []) as Array
	var moves: Array = []
	var state := _monster_state()
	var monsters := state.get("monsters", {}) as Dictionary
	for row_index in range(settlement_rows.size()):
		var row := settlement_rows[row_index] as Dictionary
		var legacy_movement := row.get("movement_receipt", {}) as Dictionary
		if legacy_movement.is_empty():
			continue
		var monster_id := str(row.get("source_instance_id", ""))
		var context := _runtime_owner.call(
			"v076_monster_production_consumer_context",
			monster_id
		) as Dictionary
		if not bool(context.get("accepted", false)):
			return _reject(str(context.get(
				"reason_code",
				"v076_monster_production_context_missing"
			)))
		var source := context.get("source", {}) as Dictionary
		var start_region_id := str(source.get("region_id", ""))
		var target_region_id := str(row.get("target_region_id", ""))
		var start_face_id := production_face_for_region(start_region_id)
		var target_face_id := production_face_for_region(target_region_id)
		if start_face_id < 0 or target_face_id < 0:
			return _reject("v076_monster_production_face_binding_missing")
		if start_face_id == target_face_id:
			row["movement_receipt"] = {}
			row["movement_destination_region_id"] = start_region_id
			row["reached_target_region"] = true
			settlement_rows[row_index] = row
			continue
		var existing := monsters.get(monster_id, {}) as Dictionary
		if not existing.is_empty():
			if str(existing.get("status", "")) == "MOVING":
				return _reject("v076_monster_production_prior_move_in_flight")
			start_face_id = int(existing.get("current_face_id", -1))
			if _region_for_face(start_face_id) != start_region_id:
				return _reject("v076_monster_production_source_projection_stale")
		var target_point_result := MonsterMetric.canonical_target_point(target_face_id)
		if not bool(target_point_result.get("accepted", false)):
			return _reject("v076_monster_production_target_point_invalid")
		var route_result := MonsterMetric.build_route(
			start_face_id,
			target_face_id,
			target_point_result.get("target_point", {}) as Dictionary
		)
		if not bool(route_result.get("accepted", false)):
			return _reject(str(route_result.get(
				"reason",
				"v076_monster_production_route_invalid"
			)))
		var movement_budget := int(source.get("movement_budget_milli_arc", 0))
		if movement_budget <= 0:
			return _reject("v076_monster_production_speed_source_invalid")
		var movement_class := _movement_class(str(source.get("movement_profile", "")))
		if movement_class.is_empty():
			return _reject("v076_monster_production_movement_profile_invalid")
		var production_movement_id := str(legacy_movement.get("movement_id", ""))
		var move := {
			"production_movement_id": production_movement_id,
			"monster_id": monster_id,
			"source_generation": int(source.get("source_generation", 0)),
			"source_region_id": start_region_id,
			"target_region_id": target_region_id,
			"start_face_id": start_face_id,
			"target_face_id": target_face_id,
			"target_point": (
				target_point_result.get("target_point", {}) as Dictionary
			).duplicate(true),
			"max_geodesic_distance_mu": int((route_result.get(
				"route", {}
			) as Dictionary).get("total_distance_mu", 0)),
			"speed_mu_per_tick": movement_budget,
			"movement_class": movement_class,
			"trample_efficiency_ppm": _trample_efficiency_ppm(
				int(source.get("rank", 0))
			),
			"expected_move_revision": int(existing.get("move_revision", 0)),
		}
		var move_validation := MonsterCodec.validate_production_move(move)
		if not bool(move_validation.get("valid", false)):
			return _reject(str(move_validation.get(
				"reason",
				"v076_monster_production_move_invalid"
			)))
		moves.append(move)
		# The V075 plan remains target/detection authority, but its movement and
		# trample receipt is now reference-only and cannot reach its old writer.
		row["movement_receipt"] = {}
		row["movement_destination_region_id"] = start_region_id
		row["reached_target_region"] = false
		settlement_rows[row_index] = row
	settlement_plan["plans"] = settlement_rows
	_monster_plan_prepare_count += 1
	if moves.is_empty():
		return {
			"accepted": true,
			"reason": "",
			"settlement_plan": settlement_plan,
			"command": {},
			"move_count": 0,
		}
	var built := AuthorityCommand.build(
		"v076.monster.production.batch.%s" % plan_fingerprint.substr(0, 32),
		MonsterCodec.DOMAIN_ID,
		MonsterCodec.START_PRODUCTION_BATCH_COMMAND_TYPE,
		"system.v075.autonomy_consumer",
		int(_kernel.call("current_tick")) + 1,
		30,
		0,
		{
			"plan_fingerprint": plan_fingerprint,
			"moves": moves,
		}
	)
	if not bool(built.get("accepted", false)):
		return _reject(str(built.get(
			"reason",
			"v076_monster_production_root_build_failed"
		)))
	return {
		"accepted": true,
		"reason": "",
		"settlement_plan": settlement_plan,
		"command": (built.get("command", {}) as Dictionary).duplicate(true),
		"move_count": moves.size(),
	}


func submit_prepared_monster_autonomy(prepared: Dictionary) -> Dictionary:
	if not _monster_production_configured:
		return _reject("v076_monster_production_not_configured")
	var command := prepared.get("command", {}) as Dictionary
	if command.is_empty():
		return {"accepted": true, "reason": "", "submitted_count": 0}
	var submitted := _kernel.call("submit_command", command) as Dictionary
	if not bool(submitted.get("accepted", false)):
		return _reject(str(submitted.get(
			"reason",
			"v076_monster_production_root_submission_failed"
		)))
	if not bool(submitted.get("duplicate", false)):
		_monster_root_submission_count += 1
	return {
		"accepted": true,
		"reason": "",
		"submitted_count": 0 if bool(submitted.get("duplicate", false)) else 1,
		"duplicate": bool(submitted.get("duplicate", false)),
	}


func drain_monster_production_receipts() -> Dictionary:
	if not _monster_production_configured:
		return _reject("v076_monster_production_not_configured")
	var committed_count := 0
	var duplicate_count := 0
	for receipt_variant in _monster_state().get("move_receipts", []) as Array:
		if not (receipt_variant is Dictionary):
			return _reject("v076_monster_production_receipt_not_dictionary")
		var receipt := receipt_variant as Dictionary
		if (
			str(receipt.get("kind", "")) != "MOVE_STEP"
			or not bool(receipt.get("production_cutover", false))
			or str(receipt.get("status", "")) not in ["ARRIVED", "MAX_DISTANCE"]
		):
			continue
		_monster_terminal_receipt_attempt_count += 1
		var prior := _runtime_owner.call(
			"v076_monster_production_receipt_status",
			str(receipt.get("production_movement_id", ""))
		) as Dictionary
		if bool(prior.get("consumed", false)):
			duplicate_count += 1
			continue
		var consumer_result := _build_monster_consumer_result(receipt)
		if not bool(consumer_result.get("accepted", false)):
			_monster_consumer_failure_count += 1
			return consumer_result
		var consumed := _runtime_owner.call(
			"consume_v076_monster_production_result",
			consumer_result.get("result", {}) as Dictionary
		) as Dictionary
		if not bool(consumed.get("accepted", false)):
			_monster_consumer_failure_count += 1
			return _reject(str(consumed.get(
				"reason_code",
				"v076_monster_production_consumer_rejected"
			)))
		if bool(consumed.get("duplicate", false)):
			duplicate_count += 1
		else:
			committed_count += 1
			_monster_terminal_receipt_commit_count += 1
	return {
		"accepted": true,
		"reason": "",
		"committed_count": committed_count,
		"duplicate_count": duplicate_count,
	}


func _build_monster_consumer_result(receipt: Dictionary) -> Dictionary:
	var monster_id := str(receipt.get("monster_id", ""))
	var context := _runtime_owner.call(
		"v076_monster_production_consumer_context",
		monster_id
	) as Dictionary
	if not bool(context.get("accepted", false)):
		return _reject(str(context.get(
			"reason_code",
			"v076_monster_production_context_missing"
		)))
	var source := context.get("source", {}) as Dictionary
	if int(source.get("source_generation", 0)) != int(receipt.get(
		"source_generation", -1
	)):
		return _reject("v076_monster_production_source_generation_stale")
	var destination_region_id := _region_for_face(int(receipt.get(
		"current_face_id", -1
	)))
	if destination_region_id.is_empty():
		return _reject("v076_monster_production_destination_region_missing")
	var movement_id := str(receipt.get("production_movement_id", ""))
	var distance_by_region := _map_region_ledger(
		receipt.get("trample_distance_by_region_mu", {}) as Dictionary
	)
	var damage_by_region := _map_region_ledger(
		receipt.get("trample_damage_by_region", {}) as Dictionary
	)
	var movement_profile := _movement_profile(str((
		(_monster_state().get("monsters", {}) as Dictionary).get(
			monster_id, {}
		) as Dictionary
	).get("movement_class", "")))
	var movement_payload := {
		"schema_version": 1,
		"contract_id": "MonsterMovementReceiptV1",
		"ruleset_id": "v0.7.5",
		"movement_id": movement_id,
		"source_instance_id": monster_id,
		"source_generation": int(receipt.get("source_generation", 0)),
		"source_rank": int(source.get("rank", 0)),
		"owner_player_id": str(source.get("owner_player_id", "")),
		"movement_profile": movement_profile,
		"forced_movement": false,
		"forced_movement_trample": false,
		"start_region_id": str(receipt.get("source_region_id", "")),
		"destination_region_id": destination_region_id,
		"target_region_id": str(receipt.get("target_region_id", "")),
		"ordered_region_path": _ordered_regions_from_ledger(
			distance_by_region,
			str(receipt.get("source_region_id", "")),
			destination_region_id
		),
		"region_path_segments": _region_segments(distance_by_region),
		"movement_budget_milli_arc": int(source.get(
			"movement_budget_milli_arc", 0
		)),
		"distance_milli_arc": int(receipt.get("travelled_distance_mu", 0)),
		"authoritative_position_mode": "v076_integer_geodesic_face_progress",
		"movement_receipt_fingerprint": "",
	}
	movement_payload["movement_receipt_fingerprint"] = StateCodec.fingerprint(
		_without_field(movement_payload, "movement_receipt_fingerprint")
	)
	var trample := _build_trample_consumer_payload(
		movement_id,
		source,
		context.get("facilities", []) as Array,
		destination_region_id,
		distance_by_region,
		damage_by_region
	)
	if not bool(trample.get("accepted", false)):
		return trample
	var result := {
		"schema_version": 1,
		"contract_id": "V076MonsterProductionConsumerResultV1",
		"movement_id": movement_id,
		"source_instance_id": monster_id,
		"source_generation": int(receipt.get("source_generation", 0)),
		"kernel_tick": int(receipt.get("tick", 0)),
		"kernel_authority_sequence": int(receipt.get("authority_sequence", 0)),
		"movement_payload": movement_payload,
		"trample_payloads": (
			trample.get("trample_payloads", []) as Array
		).duplicate(true),
		"facility_damage_intents": (
			trample.get("facility_damage_intents", []) as Array
		).duplicate(true),
		"v075_movement_write_count": 0,
		"production_asset_quantity_write_count": 0,
		"result_fingerprint": "",
	}
	result["result_fingerprint"] = StateCodec.fingerprint(
		_without_field(result, "result_fingerprint")
	)
	if str(result.get("result_fingerprint", "")).is_empty():
		return _reject("v076_monster_production_consumer_result_not_closed")
	return {"accepted": true, "reason": "", "result": result}


func _build_trample_consumer_payload(
	movement_id: String,
	source: Dictionary,
	facilities: Array,
	destination_region_id: String,
	distance_by_region: Dictionary,
	damage_by_region: Dictionary
) -> Dictionary:
	if str(source.get("movement_profile", "")) != "ground_trample":
		return {
			"accepted": true,
			"reason": "",
			"trample_payloads": [],
			"facility_damage_intents": [],
		}
	var intents: Array = []
	var candidate_ids: Array[String] = []
	for region_id_variant in damage_by_region.keys():
		var region_id := str(region_id_variant)
		var damage_budget := int(damage_by_region[region_id_variant])
		if damage_budget <= 0:
			continue
		var candidates := MonsterTrampleCore._ordered_region_facilities(
			source,
			facilities,
			region_id
		)
		var allocation := MonsterTrampleCore._allocate_budget(
			damage_budget,
			candidates
		)
		for candidate_variant in candidates:
			candidate_ids.append(str((candidate_variant as Dictionary).get(
				"facility_id", ""
			)))
		for allocation_variant in allocation.get("allocations", []) as Array:
			var row := allocation_variant as Dictionary
			var facility := row.get("facility", {}) as Dictionary
			var amount := int(row.get("damage_amount", 0))
			if amount <= 0:
				continue
			var combat_receipt_id := "combat.receipt.v076.%s" % StateCodec.fingerprint({
				"movement_id": movement_id,
				"region_id": region_id,
				"facility_id": str(facility.get("facility_id", "")),
			}).substr(0, 24)
			var intent := FacilityDamageIntent.build(
				"combat.trample.v076.%s" % StateCodec.fingerprint({
					"movement_id": movement_id,
					"region_id": region_id,
				}).substr(0, 24),
				str(facility.get("facility_id", "")),
				int(facility.get("facility_generation", 0)),
				amount,
				"monster_ground_trample",
				combat_receipt_id
			)
			if intent.is_empty():
				return _reject("v076_monster_production_facility_intent_invalid")
			intents.append(intent)
	var trample_payloads: Array = []
	if not distance_by_region.is_empty():
		var receipt_id := "combat.trample.v076.%s" % StateCodec.fingerprint({
			"movement_id": movement_id,
			"distance_by_region": distance_by_region,
			"damage_by_region": damage_by_region,
		}).substr(0, 24)
		trample_payloads.append({
			"schema_version": 1,
			"contract_id": "MonsterTrampleRegionReceiptV1",
			"ruleset_id": "v0.7.5",
			"trample_region_receipt_id": receipt_id,
			"movement_id": movement_id,
			"source_instance_id": str(source.get("source_instance_id", "")),
			"source_generation": int(source.get("source_generation", 0)),
			"source_rank": int(source.get("rank", 0)),
			"region_id": destination_region_id,
			"distance_milli_arc": _sum_ledger(distance_by_region),
			"damage_amount": _sum_ledger(damage_by_region),
			"region_damage_budget": _sum_ledger(damage_by_region),
			"allocated_damage": _sum_intent_damage(intents),
			"unallocated_damage": maxi(
				0,
				_sum_ledger(damage_by_region) - _sum_intent_damage(intents)
			),
			"candidate_facility_ids": candidate_ids,
			"facility_damage_intent_receipt_ids": _intent_receipt_ids(intents),
			"distance_by_region_milli_arc": distance_by_region.duplicate(true),
			"damage_by_region": damage_by_region.duplicate(true),
			"exact_once": true,
		})
	return {
		"accepted": true,
		"reason": "",
		"trample_payloads": trample_payloads,
		"facility_damage_intents": intents,
	}


func debug_snapshot() -> Dictionary:
	return {
		"adapter_id": ADAPTER_ID,
		"owner_id": OWNER_ID,
		"bound": _bound(),
		"owns_tick": false,
		"owns_authority_sequence": false,
		"owns_rng": false,
		"owns_asset_quantity": false,
		"owns_military_unit_state": false,
		"owns_damage": false,
		"owns_card_catalog": false,
		"owns_presentation": false,
		"monster_production_configured": _monster_production_configured,
		"monster_owner_id": "component.v076.monster_l1",
		"monster_owner_count": 1 if _monster_production_configured else 0,
		"monster_plan_prepare_count": _monster_plan_prepare_count,
		"monster_root_submission_count": _monster_root_submission_count,
		"monster_terminal_receipt_attempt_count": (
			_monster_terminal_receipt_attempt_count
		),
		"monster_terminal_receipt_commit_count": (
			_monster_terminal_receipt_commit_count
		),
		"monster_consumer_failure_count": _monster_consumer_failure_count,
		"monster_production_asset_quantity_count": 0,
		"v075_production_movement_write_count": 0,
	}


func _monster_state() -> Dictionary:
	if not _monster_production_configured or _kernel == null:
		return {}
	return (_kernel.call("domain_state", MonsterCodec.DOMAIN_ID) as Dictionary).duplicate(true)


func _runtime_region_ids() -> Array:
	return (_runtime_owner.call("_runtime_region_ids") as Array).duplicate()


func _region_for_face(face_id: int) -> String:
	var state := _monster_state()
	var owner_by_face := state.get("owner_by_face", []) as Array
	var region_ids := _runtime_region_ids()
	if face_id < 0 or face_id >= owner_by_face.size():
		return ""
	var owner_index := int(owner_by_face[face_id])
	if owner_index < 0 or owner_index >= region_ids.size():
		return ""
	return str(region_ids[owner_index])


func _movement_class(profile: String) -> String:
	return {
		"ground_trample": "GROUND",
		"flying_no_trample": "FLYING",
		"teleport_no_trample": "PHASE",
	}.get(profile, "")


func _movement_profile(movement_class: String) -> String:
	return {
		"GROUND": "ground_trample",
		"FLYING": "flying_no_trample",
		"PHASE": "teleport_no_trample",
	}.get(movement_class, "")


func _trample_efficiency_ppm(source_rank: int) -> int:
	var balance := CombatCatalog.trample_balance()
	var step_distance := int(balance.get("trample_distance_step_milli_arc", 0))
	var damage_by_rank := balance.get("trample_damage_per_step_by_rank", {}) as Dictionary
	var damage_per_step := int(damage_by_rank.get(str(source_rank), 0))
	if step_distance <= 0 or damage_per_step <= 0:
		return -1
	@warning_ignore("integer_division")
	return (damage_per_step * 1_000_000) / step_distance


func _map_region_ledger(index_ledger: Dictionary) -> Dictionary:
	var result := {}
	var region_ids := _runtime_region_ids()
	for index_variant in index_ledger.keys():
		var index := int(str(index_variant))
		if index < 0 or index >= region_ids.size():
			continue
		var region_id := str(region_ids[index])
		result[region_id] = int(result.get(region_id, 0)) + int(
			index_ledger[index_variant]
		)
	return result


func _region_segments(distance_by_region: Dictionary) -> Array:
	var region_ids: Array[String] = []
	for region_id_variant in distance_by_region.keys():
		region_ids.append(str(region_id_variant))
	region_ids.sort()
	var result: Array = []
	for region_id in region_ids:
		result.append({
			"region_id": region_id,
			"distance_milli_arc": int(distance_by_region.get(region_id, 0)),
		})
	return result


func _ordered_regions_from_ledger(
	distance_by_region: Dictionary,
	start_region_id: String,
	destination_region_id: String
) -> Array:
	var result: Array[String] = []
	if not start_region_id.is_empty():
		result.append(start_region_id)
	var middle: Array[String] = []
	for region_id_variant in distance_by_region.keys():
		var region_id := str(region_id_variant)
		if region_id != start_region_id and region_id != destination_region_id:
			middle.append(region_id)
	middle.sort()
	result.append_array(middle)
	if not destination_region_id.is_empty() and not result.has(destination_region_id):
		result.append(destination_region_id)
	return result


func _sum_ledger(values: Dictionary) -> int:
	var result := 0
	for value_variant in values.values():
		result += int(value_variant)
	return result


func _sum_intent_damage(intents: Array) -> int:
	var result := 0
	for intent_variant in intents:
		result += int((intent_variant as Dictionary).get("damage_amount", 0))
	return result


func _intent_receipt_ids(intents: Array) -> Array:
	var result: Array[String] = []
	for intent_variant in intents:
		result.append(str((intent_variant as Dictionary).get(
			"combat_receipt_id", ""
		)))
	return result


func _without_field(value: Dictionary, field_name: String) -> Dictionary:
	var result := value.duplicate(true)
	result.erase(field_name)
	return result


func _bound() -> bool:
	return _runtime_owner != null and is_instance_valid(_runtime_owner)


static func _reject(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason}
