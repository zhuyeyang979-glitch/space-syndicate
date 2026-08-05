extends RefCounted
class_name V074FacilityRuntimeCore

const FacilityTypes := preload(
	"res://scripts/v074/facility/v074_facility_type_registry.gd"
)
const WarehouseRuntime := preload(
	"res://scripts/v074/warehouse/v074_warehouse_runtime_policy.gd"
)


const SCHEMA_VERSION := 2
const STATE_VERSION := 2
const RULESET_ID := "v0.7.4"
const BALANCE_PROFILE_ID := "V074_ROGUELIKE_WAREHOUSE_BASELINE"

const CORE_AUTHORITY_ID := "v074.facility_runtime.core_authority.v1"
const AI_OBSERVATION_ID := "v074.facility_runtime.ai_observation.v1"
const PLAYER_PROJECTION_ID := "v074.facility_runtime.player_projection.v1"
const FACILITY_ACTION_INTENT_ID := "v074.facility_runtime.intent.v1"
const RECEIPT_ID := "v074.facility_runtime.authoritative_receipt.v1"
const SAVE_STATE_ID := "v074.facility_runtime.save_state.v1"
const PUBLIC_PROJECTION_ID := "v074.facility_runtime.public_projection.v1"

const RESOLUTION_ORDER_MODE := "fixed_hidden_round_robin"
const RESOLUTION_ORDER_SOURCE := "frozen_hidden_lead_order_at_batch_lock"
const INVALID_TARGET_POLICY_ID := "FIZZLE_FULL_ASSET_REFUND"
const MAX_ACTIONS_PER_PLAYER := 5
const MAX_FACILITY_RANK := 4
const MAX_SAFE_INTEGER := 9007199254740991

const FACILITY_ACTION_MODES := ["BUILD_NEW", "UPGRADE_OWN", "REPAIR_OWN"]
const FACILITY_TYPES := FacilityTypes.REGISTERED_FACILITY_TYPES
const INDUSTRIES := FacilityTypes.INDUSTRY_IDS
const COLORS := INDUSTRIES
const ORIGIN_CLASSES := ["starter_bootstrap", "standard"]
const OCCUPANCY_VALUES := ["empty", "occupied"]

const TYPED_RESOLUTION_RESULTS := [
	"facility_action_resolved",
	"facility_target_invalid_slot_occupied",
	"facility_target_invalid_generation_changed",
	"facility_target_invalid_owner_changed",
	"facility_target_invalid_rank_changed",
	"facility_target_invalid_damage_changed",
]

const STATE_FIELDS := [
	"schema_version",
	"state_version",
	"ruleset_id",
	"balance_profile_id",
	"contract_id",
	"production_runtime_connected",
	"batch_id",
	"revision",
	"warehouse_solar_refresh_count",
	"status",
	"resolution_order_source",
	"player_ids",
	"frozen_hidden_lead_order_at_batch_lock",
	"player_local_queues",
	"authority_queue",
	"anonymous_global_queue",
	"resolution_cursor",
	"facility_slots",
	"processed_action_ids",
	"resolution_receipts",
	"state_fingerprint",
]
const ACTION_FIELDS := [
	"schema_version",
	"contract_id",
	"action_id",
	"source_card_instance_id",
	"source_card_rank",
	"actor_id",
	"local_action_index",
	"origin_class",
	"facility_action_mode",
	"region_id",
	"region_revision",
	"facility_type",
	"industry_id",
	"target_slot_id",
	"target_slot_generation",
	"expected_occupancy",
	"expected_facility_id",
	"expected_facility_generation",
	"expected_owner_id",
	"expected_rank",
	"expected_damage_revision",
	"reserved_assets",
	"invalid_target_policy_id",
	"action_fingerprint",
]
const SLOT_FIELDS := [
	"slot_id",
	"region_id",
	"region_revision",
	"facility_type",
	"industry_id",
	"slot_generation",
	"occupancy",
	"facility_id",
	"facility_generation",
	"owner_id",
	"rank",
	"damage_revision",
	"damage_points",
	"capacity",
	"base_ingress_throughput",
	"base_egress_throughput",
	"ingress_throughput",
	"egress_throughput",
	"solar_efficiency_state",
	"commercial_art_key",
	"warehouse_stock_runtime_phase",
]
const AUTHORITY_QUEUE_FIELDS := [
	"anonymous_action_id",
	"action_id",
	"actor_id",
	"local_action_index",
]
const PUBLIC_QUEUE_FIELDS := [
	"queue_index",
	"anonymous_action_id",
	"local_action_index",
	"resolution_status",
	"public_reason_code",
	"asset_reservation_released",
	"normal_card_destination",
	"action_slot_refunded",
]
const RECEIPT_FIELDS := [
	"schema_version",
	"contract_id",
	"receipt_id",
	"batch_id",
	"state_revision",
	"anonymous_action_id",
	"action_id",
	"actor_id",
	"facility_action_mode",
	"accepted",
	"outcome_id",
	"reason_code",
	"invalid_target_policy_id",
	"asset_reservation_released",
	"asset_reservation_consumed",
	"asset_release_amount",
	"normal_card_destination",
	"action_slot_refunded",
	"target_reselected",
	"facility_created",
	"facility_upgraded",
	"facility_repaired",
	"exact_once",
	"public_history_reason_code",
	"receipt_fingerprint",
]
const SAVE_FIELDS := [
	"schema_version",
	"state_version",
	"contract_id",
	"ruleset_id",
	"balance_profile_id",
	"v072_direct_resume_allowed",
	"v06_direct_resume_allowed",
	"state",
	"save_fingerprint",
]

const FORBIDDEN_RUNTIME_FIELDS := [
	"initiative_bid",
	"bid_cash",
	"bid_reservation",
	"bid_rank",
	"bid_histogram",
	"auction_status",
	"auction_receipt",
	"public_tiebreak_cursor",
	"resolution_priority_bid_order",
]


static func contract_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"core_authority_id": CORE_AUTHORITY_ID,
		"ai_observation_id": AI_OBSERVATION_ID,
		"player_projection_id": PLAYER_PROJECTION_ID,
		"intent_id": FACILITY_ACTION_INTENT_ID,
		"receipt_id": RECEIPT_ID,
		"save_state_id": SAVE_STATE_ID,
		"resolution_order_mode": RESOLUTION_ORDER_MODE,
		"resolution_order_source": RESOLUTION_ORDER_SOURCE,
		"resolution_order_writer": "lock_batch",
		"resolution_order_writer_count": 1,
		"resolution_order_modifier_count": 0,
		"resolution_order_mutation_after_batch_lock": false,
		"maximum_actions_per_player": MAX_ACTIONS_PER_PLAYER,
		"layered_round_robin": true,
		"facility_slot_key_fields": ["region_id", "facility_type", "industry_id"],
		"facility_slot_kind": "region_unique_facility_slot",
		"facility_action_modes": FACILITY_ACTION_MODES.duplicate(),
		"facility_action_mode_mutable_after_lock": false,
		"target_reselection_during_resolution": false,
		"build_to_upgrade_auto_conversion": false,
		"build_to_repair_auto_conversion": false,
		"upgrade_to_repair_auto_conversion": false,
		"repair_to_upgrade_auto_conversion": false,
		"contention_invalid_target_policy_id": INVALID_TARGET_POLICY_ID,
		"contention_asset_reservation_released": true,
		"contention_normal_card_destination": "discard",
		"contention_action_slot_refunded": false,
		"typed_resolution_results": TYPED_RESOLUTION_RESULTS.duplicate(),
		"initiative_auction_enabled": false,
		"resolution_order_bidding_enabled": false,
		"cash_can_change_resolution_order": false,
		"initiative_auction_core_count": 0,
		"initiative_bid_intent_count": 0,
		"initiative_bid_save_field_count": 0,
		"initiative_bid_ui_surface_count": 0,
		"ai_initiative_bid_policy_count": 0,
		"registered_facility_types": FacilityTypes.registered_facility_types(),
		"starter_facility_types": FacilityTypes.starter_facility_types(),
		"standard_track_facility_types": (
			FacilityTypes.standard_track_facility_types()
		),
		"facility_slot_count_per_region": (
			FacilityTypes.facility_slot_count_per_region()
		),
		"warehouse_runtime_contract": WarehouseRuntime.contract_snapshot(),
		"warehouse_stock_runtime_phase": (
			"existing_external_owner_or_deferred"
		),
		"production_runtime_connection_count": 0,
		"v06_mutation_count": 0,
		"dual_write_count": 0,
		"gameplay_owner_count": 0,
		"save_owner_count": 0,
		"rng_owner_count": 0,
		"detached": true,
	}


static func facility_slot_id(
	region_id: String,
	facility_type: String,
	industry_id: String
) -> String:
	if not _stable_id(region_id) or not FACILITY_TYPES.has(facility_type) \
			or not INDUSTRIES.has(industry_id):
		return ""
	return "slot.%s.%s.%s" % [region_id, facility_type, industry_id]


static func build_empty_slot(
	region_id: String,
	region_revision: int,
	facility_type: String,
	industry_id: String,
	slot_generation: int
) -> Dictionary:
	var slot_id := facility_slot_id(region_id, facility_type, industry_id)
	if slot_id.is_empty() or not _nonnegative_integer(region_revision) \
			or not _nonnegative_integer(slot_generation):
		return {}
	return {
		"slot_id": slot_id,
		"region_id": region_id,
		"region_revision": region_revision,
		"facility_type": facility_type,
		"industry_id": industry_id,
		"slot_generation": slot_generation,
		"occupancy": "empty",
		"facility_id": null,
		"facility_generation": null,
		"owner_id": null,
		"rank": null,
		"damage_revision": null,
		"damage_points": null,
		"capacity": null,
		"base_ingress_throughput": null,
		"base_egress_throughput": null,
		"ingress_throughput": null,
		"egress_throughput": null,
		"solar_efficiency_state": null,
		"commercial_art_key": null,
		"warehouse_stock_runtime_phase": null,
	}


static func build_occupied_slot(
	region_id: String,
	region_revision: int,
	facility_type: String,
	industry_id: String,
	slot_generation: int,
	facility_id: String,
	facility_generation: int,
	owner_id: String,
	rank: int,
	damage_revision: int,
	damage_points: int,
	solar_efficiency_state: String = "dark"
) -> Dictionary:
	var slot := build_empty_slot(
		region_id,
		region_revision,
		facility_type,
		industry_id,
		slot_generation
	)
	if slot.is_empty() or not _stable_id(facility_id) or not _stable_id(owner_id) \
			or not _nonnegative_integer(facility_generation) \
			or not _positive_integer(rank) or rank > MAX_FACILITY_RANK \
			or not _nonnegative_integer(damage_revision) \
			or not _nonnegative_integer(damage_points):
		return {}
	slot["occupancy"] = "occupied"
	slot["facility_id"] = facility_id
	slot["facility_generation"] = facility_generation
	slot["owner_id"] = owner_id
	slot["rank"] = rank
	slot["damage_revision"] = damage_revision
	slot["damage_points"] = damage_points
	slot = WarehouseRuntime.decorate_slot(slot, solar_efficiency_state)
	return slot


static func refresh_slot_solar_state(
	slot: Dictionary,
	solar_efficiency_state: String
) -> Dictionary:
	if _slot_error(slot) != "":
		return {}
	var refreshed := WarehouseRuntime.decorate_slot(
		slot,
		solar_efficiency_state
	)
	if refreshed.is_empty() or _slot_error(refreshed) != "":
		return {}
	return refreshed


static func refresh_warehouse_solar_states(
	state: Dictionary,
	solar_by_region: Dictionary
) -> Dictionary:
	if _state_error(state) != "" or _solar_map_error(solar_by_region) != "":
		return {}
	var next := state.duplicate(true)
	var slots := (
		next.get("facility_slots") as Dictionary
	).duplicate(true)
	var slot_ids: Array[String] = []
	for slot_id_variant in slots.keys():
		slot_ids.append(str(slot_id_variant))
	slot_ids.sort()
	for slot_id in slot_ids:
		var slot := slots.get(slot_id) as Dictionary
		if (
			str(slot.get("facility_type", "")) != "warehouse"
			or str(slot.get("occupancy", "")) != "occupied"
		):
			continue
		var region_id := str(slot.get("region_id", ""))
		if not solar_by_region.has(region_id):
			return {}
		var refreshed := WarehouseRuntime.decorate_slot(
			slot,
			str(solar_by_region.get(region_id, ""))
		)
		if refreshed.is_empty() or _slot_error(refreshed) != "":
			return {}
		slots[slot_id] = refreshed
	next["facility_slots"] = slots
	next["revision"] = int(next.get("revision", 0)) + 1
	next["warehouse_solar_refresh_count"] = (
		int(next.get("warehouse_solar_refresh_count", 0)) + 1
	)
	next.erase("state_fingerprint")
	next = _seal(next, "state_fingerprint")
	if _state_error(next) != "":
		return {}
	return next


static func warehouse_public_projection(slot: Dictionary) -> Dictionary:
	return WarehouseRuntime.public_projection(slot)


static func build_new_action(
	action_id: String,
	source_card_instance_id: String,
	actor_id: String,
	local_action_index: int,
	slot: Dictionary,
	reserved_assets: Dictionary,
	origin_class: String = "standard",
	source_card_rank: int = 0
) -> Dictionary:
	var resolved_rank := 1 if source_card_rank == 0 else source_card_rank
	if (
		_slot_error(slot) != ""
		or slot.get("occupancy") != "empty"
		or resolved_rank < 1
		or resolved_rank > MAX_FACILITY_RANK
	):
		return {}
	if (
		origin_class == "starter_bootstrap"
		and not FacilityTypes.is_starter_type(
			str(slot.get("facility_type", ""))
		)
	):
		return {}
	return _build_action(
		action_id,
		source_card_instance_id,
		resolved_rank,
		actor_id,
		local_action_index,
		origin_class,
		"BUILD_NEW",
		slot,
		reserved_assets,
		null,
		null,
		null,
		null,
		null
	)


static func build_upgrade_action(
	action_id: String,
	source_card_instance_id: String,
	actor_id: String,
	local_action_index: int,
	slot: Dictionary,
	reserved_assets: Dictionary,
	origin_class: String = "standard",
	source_card_rank: int = 0
) -> Dictionary:
	var current_rank := int(slot.get("rank", 0))
	var resolved_rank := (
		current_rank + 1 if source_card_rank == 0 else source_card_rank
	)
	if (
		_slot_error(slot) != ""
		or slot.get("occupancy") != "occupied"
		or slot.get("owner_id") != actor_id
		or current_rank >= MAX_FACILITY_RANK
		or resolved_rank <= current_rank
		or resolved_rank > MAX_FACILITY_RANK
	):
		return {}
	return _build_action(
		action_id,
		source_card_instance_id,
		resolved_rank,
		actor_id,
		local_action_index,
		origin_class,
		"UPGRADE_OWN",
		slot,
		reserved_assets,
		slot.get("facility_id"),
		slot.get("facility_generation"),
		actor_id,
		slot.get("rank"),
		null
	)


static func build_repair_action(
	action_id: String,
	source_card_instance_id: String,
	actor_id: String,
	local_action_index: int,
	slot: Dictionary,
	reserved_assets: Dictionary,
	origin_class: String = "standard",
	source_card_rank: int = 0
) -> Dictionary:
	var current_rank := int(slot.get("rank", 0))
	var resolved_rank := current_rank if source_card_rank == 0 else source_card_rank
	if (
		_slot_error(slot) != ""
		or slot.get("occupancy") != "occupied"
		or slot.get("owner_id") != actor_id
		or int(slot.get("damage_points", 0)) <= 0
		or resolved_rank < 1
		or resolved_rank > current_rank
	):
		return {}
	return _build_action(
		action_id,
		source_card_instance_id,
		resolved_rank,
		actor_id,
		local_action_index,
		origin_class,
		"REPAIR_OWN",
		slot,
		reserved_assets,
		slot.get("facility_id"),
		slot.get("facility_generation"),
		actor_id,
		null,
		slot.get("damage_revision")
	)


static func lock_batch(
	batch_id: String,
	player_ids: Array,
	frozen_hidden_lead_order_at_batch_lock: Array,
	player_local_queues: Dictionary,
	facility_slots: Array,
	production_runtime_connected: bool = false
) -> Dictionary:
	var normalized_players := _string_id_array(player_ids, false)
	var normalized_order := _string_id_array(
		frozen_hidden_lead_order_at_batch_lock,
		false
	)
	if not _stable_id(batch_id) or normalized_players.is_empty() \
			or not _same_string_set(normalized_players, normalized_order) \
			or not _exact_keys(player_local_queues, normalized_players):
		return {}

	var slots := {}
	for slot_variant in facility_slots:
		if not (slot_variant is Dictionary):
			return {}
		var slot := (slot_variant as Dictionary).duplicate(true)
		if _slot_error(slot) != "":
			return {}
		var slot_id := str(slot.get("slot_id", ""))
		if slots.has(slot_id):
			return {}
		slots[slot_id] = slot

	var queues := {}
	var seen_action_ids: Array[String] = []
	for player_id in normalized_players:
		var queue_variant: Variant = player_local_queues.get(player_id)
		if not (queue_variant is Array):
			return {}
		var source_queue := queue_variant as Array
		if source_queue.size() > MAX_ACTIONS_PER_PLAYER:
			return {}
		var queue: Array = []
		for local_action_index in range(source_queue.size()):
			var action_variant: Variant = source_queue[local_action_index]
			if not (action_variant is Dictionary):
				return {}
			var action := (action_variant as Dictionary).duplicate(true)
			var action_id := str(action.get("action_id", ""))
			if _action_error(action) != "" or action.get("actor_id") != player_id \
					or action.get("local_action_index") != local_action_index \
					or seen_action_ids.has(action_id):
				return {}
			var slot_id := str(action.get("target_slot_id", ""))
			if not slots.has(slot_id) \
					or _submission_binding_error(action, slots.get(slot_id) as Dictionary) != "":
				return {}
			seen_action_ids.append(action_id)
			queue.append(action)
		queues[player_id] = queue

	var authority_queue := _build_authority_queue(batch_id, normalized_order, queues)
	var public_queue: Array = []
	for index in range(authority_queue.size()):
		public_queue.append(_pending_public_entry(authority_queue[index], index))
	var state := {
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"contract_id": CORE_AUTHORITY_ID,
		"production_runtime_connected": production_runtime_connected,
		"batch_id": batch_id,
		"revision": 1,
		"warehouse_solar_refresh_count": 0,
		"status": "resolved" if authority_queue.is_empty() else "resolution_ready",
		"resolution_order_source": RESOLUTION_ORDER_SOURCE,
		"player_ids": normalized_players.duplicate(),
		"frozen_hidden_lead_order_at_batch_lock": normalized_order.duplicate(),
		"player_local_queues": queues,
		"authority_queue": authority_queue,
		"anonymous_global_queue": public_queue,
		"resolution_cursor": 0,
		"facility_slots": slots,
		"processed_action_ids": [],
		"resolution_receipts": [],
	}
	return _seal(state, "state_fingerprint")


static func attempt_resolution_order_mutation(
	state: Dictionary,
	proposed_order: Array,
	modifier_kind: String
) -> Dictionary:
	if _state_error(state) != "" or not _is_pure_data(proposed_order) \
			or not _stable_id(modifier_kind):
		return _failure(state, "resolution_order_mutation_request_invalid")
	return _failure(state, "resolution_order_immutable_after_batch_lock")


static func revalidate_facility_action(
	action: Dictionary,
	authoritative_slot: Dictionary
) -> Dictionary:
	if _action_error(action) != "" or _slot_error(authoritative_slot) != "":
		return {
			"valid": false,
			"reason_code": "facility_target_invalid_generation_changed",
		}
	var reason_code := _revalidation_reason(action, authoritative_slot)
	return {
		"valid": reason_code.is_empty(),
		"reason_code": "facility_action_resolved" if reason_code.is_empty() else reason_code,
	}


static func resolve_next(state: Dictionary) -> Dictionary:
	var state_error := _state_error(state)
	if state_error != "":
		return _failure(state, "state_invalid")
	if not ["resolution_ready", "resolving"].has(state.get("status")):
		return _failure(state, "resolution_not_active")
	var cursor := int(state.get("resolution_cursor", -1))
	var authority_queue := state.get("authority_queue") as Array
	if cursor < 0 or cursor >= authority_queue.size():
		return _failure(state, "resolution_cursor_invalid")
	var authority_entry := authority_queue[cursor] as Dictionary
	var actor_id := str(authority_entry.get("actor_id", ""))
	var action_id := str(authority_entry.get("action_id", ""))
	if (state.get("processed_action_ids") as Array).has(action_id):
		return _failure(state, "action_already_resolved")
	var action := _action_by_id(state, actor_id, action_id)
	if action.is_empty():
		return _failure(state, "action_binding_missing")
	var slots := state.get("facility_slots") as Dictionary
	var slot_id := str(action.get("target_slot_id", ""))
	if not slots.has(slot_id):
		return _failure(state, "facility_slot_binding_missing")
	var slot := slots.get(slot_id) as Dictionary
	var invalid_reason := _revalidation_reason(action, slot)
	var next := state.duplicate(true)
	if invalid_reason.is_empty():
		_apply_successful_action(next, action)
	var next_revision := int(next.get("revision", 0)) + 1
	next["revision"] = next_revision
	var receipt := _build_receipt(
		next,
		authority_entry,
		action,
		invalid_reason,
		next_revision
	)
	(next.get("processed_action_ids") as Array).append(action_id)
	(next.get("resolution_receipts") as Array).append(receipt)
	(next.get("anonymous_global_queue") as Array)[cursor] = _public_entry_from_receipt(
		authority_entry,
		cursor,
		receipt
	)
	next["resolution_cursor"] = cursor + 1
	next["status"] = "resolved" if cursor + 1 == authority_queue.size() else "resolving"
	next.erase("state_fingerprint")
	next = _seal(next, "state_fingerprint")
	if _state_error(next) != "":
		return _failure(state, "resolution_commit_invalid")
	return {
		"accepted": true,
		"reason_code": str(receipt.get("reason_code", "")),
		"state": next,
		"receipt": receipt.duplicate(true),
	}


static func public_projection(state: Dictionary) -> Dictionary:
	if _state_error(state) != "":
		return {}
	var projection := {
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"contract_id": PUBLIC_PROJECTION_ID,
		"batch_id": state.get("batch_id"),
		"state_revision": state.get("revision"),
		"resolution_order_disclosed": false,
		"anonymous_global_queue": (
			state.get("anonymous_global_queue") as Array
		).duplicate(true),
		"resolution_cursor": state.get("resolution_cursor"),
		"public_facility_slots": _public_facility_slots(state),
		"projection_fingerprint": "",
	}
	projection.erase("projection_fingerprint")
	return _seal(projection, "projection_fingerprint")


static func ai_observation(state: Dictionary, viewer_id: String) -> Dictionary:
	return _viewer_projection(state, viewer_id, AI_OBSERVATION_ID)


static func player_projection(state: Dictionary, viewer_id: String) -> Dictionary:
	return _viewer_projection(state, viewer_id, PLAYER_PROJECTION_ID)


static func to_save_state(state: Dictionary) -> Dictionary:
	if _state_error(state) != "":
		return {}
	var save_state := {
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"contract_id": SAVE_STATE_ID,
		"ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"v072_direct_resume_allowed": false,
		"v06_direct_resume_allowed": false,
		"state": state.duplicate(true),
	}
	return _seal(save_state, "save_fingerprint")


static func restore_save_state(save_state: Dictionary) -> Dictionary:
	var error := _save_error(save_state)
	if error != "":
		return {
			"restored": false,
			"reason_code": error,
			"state": {},
		}
	return {
		"restored": true,
		"reason_code": "save_restored",
		"state": (save_state.get("state") as Dictionary).duplicate(true),
	}


static func slot_validation_report(slot: Variant) -> Dictionary:
	var reason_code := (
		_slot_error(slot as Dictionary)
		if slot is Dictionary
		else "facility_slot_not_dictionary"
	)
	return {
		"valid": reason_code.is_empty(),
		"reason_code": "none" if reason_code.is_empty() else reason_code,
	}


static func validation_report(state: Variant) -> Dictionary:
	var reason_code := _state_error(state)
	return {
		"valid": reason_code.is_empty(),
		"reason_code": "none" if reason_code.is_empty() else reason_code,
	}


static func is_pure_data(value: Variant) -> bool:
	return _is_pure_data(value)


static func _build_action(
	action_id: String,
	source_card_instance_id: String,
	source_card_rank: int,
	actor_id: String,
	local_action_index: int,
	origin_class: String,
	mode: String,
	slot: Dictionary,
	reserved_assets: Dictionary,
	expected_facility_id: Variant,
	expected_facility_generation: Variant,
	expected_owner_id: Variant,
	expected_rank: Variant,
	expected_damage_revision: Variant
) -> Dictionary:
	if not _stable_id(action_id) or not _stable_id(source_card_instance_id) \
			or source_card_rank < 1 \
			or source_card_rank > MAX_FACILITY_RANK \
			or not _stable_id(actor_id) \
			or not _nonnegative_integer(local_action_index) \
			or local_action_index >= MAX_ACTIONS_PER_PLAYER \
			or not ORIGIN_CLASSES.has(origin_class) \
			or not FACILITY_ACTION_MODES.has(mode) \
			or not _asset_map_valid(reserved_assets):
		return {}
	if origin_class == "starter_bootstrap" and reserved_assets != _zero_assets():
		return {}
	var action := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": FACILITY_ACTION_INTENT_ID,
		"action_id": action_id,
		"source_card_instance_id": source_card_instance_id,
		"source_card_rank": source_card_rank,
		"actor_id": actor_id,
		"local_action_index": local_action_index,
		"origin_class": origin_class,
		"facility_action_mode": mode,
		"region_id": slot.get("region_id"),
		"region_revision": slot.get("region_revision"),
		"facility_type": slot.get("facility_type"),
		"industry_id": slot.get("industry_id"),
		"target_slot_id": slot.get("slot_id"),
		"target_slot_generation": slot.get("slot_generation"),
		"expected_occupancy": slot.get("occupancy"),
		"expected_facility_id": expected_facility_id,
		"expected_facility_generation": expected_facility_generation,
		"expected_owner_id": expected_owner_id,
		"expected_rank": expected_rank,
		"expected_damage_revision": expected_damage_revision,
		"reserved_assets": reserved_assets.duplicate(true),
		"invalid_target_policy_id": INVALID_TARGET_POLICY_ID,
	}
	return _seal(action, "action_fingerprint")


static func _submission_binding_error(action: Dictionary, slot: Dictionary) -> String:
	if action.get("target_slot_id") != slot.get("slot_id") \
			or action.get("region_id") != slot.get("region_id") \
			or action.get("facility_type") != slot.get("facility_type") \
			or action.get("industry_id") != slot.get("industry_id") \
			or action.get("region_revision") != slot.get("region_revision") \
			or action.get("target_slot_generation") != slot.get("slot_generation") \
			or action.get("expected_occupancy") != slot.get("occupancy"):
		return "facility_submission_target_snapshot_mismatch"
	match str(action.get("facility_action_mode", "")):
		"BUILD_NEW":
			if slot.get("occupancy") != "empty":
				return "facility_build_slot_not_empty"
		"UPGRADE_OWN":
			if slot.get("occupancy") != "occupied" \
					or action.get("expected_facility_id") != slot.get("facility_id") \
					or action.get("expected_facility_generation") != slot.get("facility_generation") \
					or action.get("expected_owner_id") != action.get("actor_id") \
					or action.get("expected_owner_id") != slot.get("owner_id") \
					or action.get("expected_rank") != slot.get("rank") \
					or int(slot.get("rank", 0)) >= MAX_FACILITY_RANK \
					or int(action.get("source_card_rank", 0)) \
					<= int(slot.get("rank", 0)):
				return "facility_upgrade_target_not_owned_or_legal"
		"REPAIR_OWN":
			if slot.get("occupancy") != "occupied" \
					or action.get("expected_facility_id") != slot.get("facility_id") \
					or action.get("expected_facility_generation") != slot.get("facility_generation") \
					or action.get("expected_owner_id") != action.get("actor_id") \
					or action.get("expected_owner_id") != slot.get("owner_id") \
					or action.get("expected_damage_revision") != slot.get("damage_revision") \
					or int(slot.get("damage_points", 0)) <= 0 \
					or int(action.get("source_card_rank", 0)) \
					> int(slot.get("rank", 0)):
				return "facility_repair_target_not_owned_or_damaged"
		_:
			return "facility_action_mode_invalid"
	return ""


static func _revalidation_reason(action: Dictionary, slot: Dictionary) -> String:
	if action.get("target_slot_id") != slot.get("slot_id") \
			or action.get("region_id") != slot.get("region_id") \
			or action.get("facility_type") != slot.get("facility_type") \
			or action.get("industry_id") != slot.get("industry_id"):
		return "facility_target_invalid_generation_changed"
	var mode := str(action.get("facility_action_mode", ""))
	if mode == "BUILD_NEW":
		if slot.get("occupancy") != "empty":
			return "facility_target_invalid_slot_occupied"
		if action.get("target_slot_generation") != slot.get("slot_generation") \
				or action.get("region_revision") != slot.get("region_revision"):
			return "facility_target_invalid_generation_changed"
		return ""
	if action.get("target_slot_generation") != slot.get("slot_generation") \
			or action.get("region_revision") != slot.get("region_revision") \
			or slot.get("occupancy") != "occupied" \
			or action.get("expected_facility_id") != slot.get("facility_id") \
			or action.get("expected_facility_generation") != slot.get("facility_generation"):
		return "facility_target_invalid_generation_changed"
	if action.get("expected_owner_id") != slot.get("owner_id") \
			or action.get("expected_owner_id") != action.get("actor_id"):
		return "facility_target_invalid_owner_changed"
	if mode == "UPGRADE_OWN":
		if action.get("expected_rank") != slot.get("rank") \
				or int(slot.get("rank", 0)) >= MAX_FACILITY_RANK \
				or int(action.get("source_card_rank", 0)) \
				<= int(slot.get("rank", 0)):
			return "facility_target_invalid_rank_changed"
		return ""
	if mode == "REPAIR_OWN":
		if action.get("expected_damage_revision") != slot.get("damage_revision") \
				or int(slot.get("damage_points", 0)) <= 0 \
				or int(action.get("source_card_rank", 0)) \
				> int(slot.get("rank", 0)):
			return "facility_target_invalid_damage_changed"
		return ""
	return "facility_target_invalid_generation_changed"


static func _apply_successful_action(state: Dictionary, action: Dictionary) -> void:
	var slots := state.get("facility_slots") as Dictionary
	var slot_id := str(action.get("target_slot_id", ""))
	var slot := (slots.get(slot_id) as Dictionary).duplicate(true)
	var source_card_rank := int(action.get("source_card_rank", 1))
	var solar_state := str(slot.get("solar_efficiency_state", "dark"))
	if solar_state not in WarehouseRuntime.SOLAR_STATES:
		solar_state = "dark"
	match str(action.get("facility_action_mode", "")):
		"BUILD_NEW":
			slot["occupancy"] = "occupied"
			slot["facility_id"] = _created_facility_id(action)
			slot["facility_generation"] = 1
			slot["owner_id"] = action.get("actor_id")
			slot["rank"] = source_card_rank
			slot["damage_revision"] = 0
			slot["damage_points"] = 0
		"UPGRADE_OWN":
			slot["facility_generation"] = (
				int(slot.get("facility_generation", 0)) + 1
			)
			slot["rank"] = source_card_rank
		"REPAIR_OWN":
			slot["facility_generation"] = (
				int(slot.get("facility_generation", 0)) + 1
			)
			slot["damage_revision"] = int(slot.get("damage_revision", 0)) + 1
			var repair_points := WarehouseRuntime.repair_points_for_rank(
				source_card_rank
			)
			slot["damage_points"] = maxi(
				0,
				int(slot.get("damage_points", 0)) - repair_points
			)
	slot["slot_generation"] = int(slot.get("slot_generation", 0)) + 1
	slot["region_revision"] = int(slot.get("region_revision", 0)) + 1
	slot = WarehouseRuntime.decorate_slot(slot, solar_state)
	slots[slot_id] = slot


static func _build_receipt(
	state: Dictionary,
	authority_entry: Dictionary,
	action: Dictionary,
	invalid_reason: String,
	state_revision: int
) -> Dictionary:
	var fizzled := not invalid_reason.is_empty()
	var mode := str(action.get("facility_action_mode", ""))
	var receipt := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": RECEIPT_ID,
		"receipt_id": "receipt.%s" % str(authority_entry.get("anonymous_action_id", "")),
		"batch_id": state.get("batch_id"),
		"state_revision": state_revision,
		"anonymous_action_id": authority_entry.get("anonymous_action_id"),
		"action_id": action.get("action_id"),
		"actor_id": action.get("actor_id"),
		"facility_action_mode": mode,
		"accepted": true,
		"outcome_id": "facility_action_fizzled" if fizzled else "facility_action_resolved",
		"reason_code": invalid_reason if fizzled else "facility_action_resolved",
		"invalid_target_policy_id": INVALID_TARGET_POLICY_ID,
		"asset_reservation_released": fizzled,
		"asset_reservation_consumed": not fizzled,
		"asset_release_amount": (
			(action.get("reserved_assets") as Dictionary).duplicate(true)
			if fizzled else _zero_assets()
		),
		"normal_card_destination": "discard",
		"action_slot_refunded": false,
		"target_reselected": false,
		"facility_created": not fizzled and mode == "BUILD_NEW",
		"facility_upgraded": not fizzled and mode == "UPGRADE_OWN",
		"facility_repaired": not fizzled and mode == "REPAIR_OWN",
		"exact_once": true,
		"public_history_reason_code": (
			"facility_slot_occupied_by_earlier_action"
			if invalid_reason == "facility_target_invalid_slot_occupied"
			else "facility_target_invalidated"
			if fizzled
			else "facility_action_resolved"
		),
	}
	return _seal(receipt, "receipt_fingerprint")


static func _build_authority_queue(
	batch_id: String,
	frozen_order: Array,
	player_local_queues: Dictionary
) -> Array:
	var queue: Array = []
	for local_action_index in range(MAX_ACTIONS_PER_PLAYER):
		for actor_variant in frozen_order:
			var actor_id := str(actor_variant)
			var local_queue := player_local_queues.get(actor_id) as Array
			if local_action_index >= local_queue.size():
				continue
			var action := local_queue[local_action_index] as Dictionary
			var queue_index := queue.size()
			queue.append({
				"anonymous_action_id": _anonymous_action_id(
					batch_id,
					queue_index,
					str(action.get("action_id", ""))
				),
				"action_id": action.get("action_id"),
				"actor_id": actor_id,
				"local_action_index": local_action_index,
			})
	return queue


static func _pending_public_entry(authority_entry: Dictionary, queue_index: int) -> Dictionary:
	return {
		"queue_index": queue_index,
		"anonymous_action_id": authority_entry.get("anonymous_action_id"),
		"local_action_index": authority_entry.get("local_action_index"),
		"resolution_status": "pending",
		"public_reason_code": "pending",
		"asset_reservation_released": false,
		"normal_card_destination": "pending",
		"action_slot_refunded": false,
	}


static func _public_entry_from_receipt(
	authority_entry: Dictionary,
	queue_index: int,
	receipt: Dictionary
) -> Dictionary:
	return {
		"queue_index": queue_index,
		"anonymous_action_id": authority_entry.get("anonymous_action_id"),
		"local_action_index": authority_entry.get("local_action_index"),
		"resolution_status": (
			"fizzled"
			if receipt.get("outcome_id") == "facility_action_fizzled"
			else "resolved"
		),
		"public_reason_code": receipt.get("public_history_reason_code"),
		"asset_reservation_released": receipt.get("asset_reservation_released"),
		"normal_card_destination": receipt.get("normal_card_destination"),
		"action_slot_refunded": receipt.get("action_slot_refunded"),
	}


static func _viewer_projection(
	state: Dictionary,
	viewer_id: String,
	contract_id: String
) -> Dictionary:
	if _state_error(state) != "" or not (state.get("player_ids") as Array).has(viewer_id):
		return {}
	var projection := {
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"contract_id": contract_id,
		"viewer_id": viewer_id,
		"batch_id": state.get("batch_id"),
		"state_revision": state.get("revision"),
		"own_local_queue": (
			(state.get("player_local_queues") as Dictionary).get(viewer_id) as Array
		).duplicate(true),
		"anonymous_public_queue": (
			state.get("anonymous_global_queue") as Array
		).duplicate(true),
		"public_facility_slots": _public_facility_slots(state),
		"resolution_cursor": state.get("resolution_cursor"),
		"complete_hidden_order_disclosed": false,
	}
	return _seal(projection, "projection_fingerprint")


static func _public_facility_slots(state: Dictionary) -> Array:
	var result: Array = []
	var slot_ids: Array[String] = []
	for slot_id_variant in (state.get("facility_slots") as Dictionary).keys():
		slot_ids.append(str(slot_id_variant))
	slot_ids.sort()
	for slot_id in slot_ids:
		var slot := (state.get("facility_slots") as Dictionary).get(slot_id) as Dictionary
		result.append({
			"slot_id": slot.get("slot_id"),
			"region_id": slot.get("region_id"),
			"facility_type": slot.get("facility_type"),
			"industry_id": slot.get("industry_id"),
			"slot_generation": slot.get("slot_generation"),
			"occupancy": slot.get("occupancy"),
			"facility_id": slot.get("facility_id"),
			"facility_generation": slot.get("facility_generation"),
			"owner_id": slot.get("owner_id"),
			"rank": slot.get("rank"),
			"damage_revision": slot.get("damage_revision"),
			"damage_points": slot.get("damage_points"),
			"capacity": slot.get("capacity"),
			"base_ingress_throughput": (
				slot.get("base_ingress_throughput")
			),
			"base_egress_throughput": (
				slot.get("base_egress_throughput")
			),
			"ingress_throughput": slot.get("ingress_throughput"),
			"egress_throughput": slot.get("egress_throughput"),
			"solar_efficiency_state": (
				slot.get("solar_efficiency_state")
			),
			"commercial_art_key": slot.get("commercial_art_key"),
			"warehouse_stock_runtime_phase": (
				slot.get("warehouse_stock_runtime_phase")
			),
		})
	return result


static func _action_by_id(
	state: Dictionary,
	actor_id: String,
	action_id: String
) -> Dictionary:
	var queues := state.get("player_local_queues") as Dictionary
	for action_variant in queues.get(actor_id) as Array:
		var action := action_variant as Dictionary
		if action.get("action_id") == action_id:
			return action.duplicate(true)
	return {}


static func _state_error(value: Variant) -> String:
	if not (value is Dictionary) or not _is_pure_data(value):
		return "state_not_pure_data"
	var state := value as Dictionary
	if not _exact_fields(state, STATE_FIELDS):
		return "state_fields_invalid"
	var unsealed := state.duplicate(true)
	var fingerprint := str(unsealed.get("state_fingerprint", ""))
	unsealed.erase("state_fingerprint")
	if not _fingerprint_valid(fingerprint) or fingerprint != _fingerprint(unsealed):
		return "state_fingerprint_invalid"
	if state.get("schema_version") != SCHEMA_VERSION \
			or state.get("state_version") != STATE_VERSION \
			or state.get("ruleset_id") != RULESET_ID \
			or state.get("balance_profile_id") != BALANCE_PROFILE_ID \
			or state.get("contract_id") != CORE_AUTHORITY_ID \
			or not (state.get("production_runtime_connected") is bool) \
			or state.get("resolution_order_source") != RESOLUTION_ORDER_SOURCE \
			or not _stable_id(state.get("batch_id")) \
			or not _positive_integer(state.get("revision")) \
			or not _nonnegative_integer(
				state.get("warehouse_solar_refresh_count")
			):
		return "state_context_invalid"
	if _contains_forbidden_runtime_field(state):
		return "retired_auction_field_present"
	var players := _string_id_array(state.get("player_ids"), false)
	var frozen_order := _string_id_array(
		state.get("frozen_hidden_lead_order_at_batch_lock"),
		false
	)
	if players.is_empty() or not _same_string_set(players, frozen_order):
		return "frozen_resolution_order_invalid"
	var queues_variant: Variant = state.get("player_local_queues")
	if not (queues_variant is Dictionary) or not _exact_keys(queues_variant, players):
		return "player_local_queues_invalid"
	var action_ids: Array[String] = []
	for player_id in players:
		var queue_variant: Variant = (queues_variant as Dictionary).get(player_id)
		if not (queue_variant is Array) \
				or (queue_variant as Array).size() > MAX_ACTIONS_PER_PLAYER:
			return "player_local_queue_invalid"
		for index in range((queue_variant as Array).size()):
			var action_variant: Variant = (queue_variant as Array)[index]
			if not (action_variant is Dictionary):
				return "facility_action_invalid"
			var action := action_variant as Dictionary
			var action_id := str(action.get("action_id", ""))
			if _action_error(action) != "" or action.get("actor_id") != player_id \
					or action.get("local_action_index") != index \
					or action_ids.has(action_id):
				return "facility_action_invalid"
			action_ids.append(action_id)
	var slots_variant: Variant = state.get("facility_slots")
	if not (slots_variant is Dictionary):
		return "facility_slots_invalid"
	for slot_id_variant in (slots_variant as Dictionary).keys():
		var slot_id := str(slot_id_variant)
		var slot_variant: Variant = (slots_variant as Dictionary).get(slot_id_variant)
		if not (slot_variant is Dictionary) or _slot_error(slot_variant as Dictionary) != "" \
				or (slot_variant as Dictionary).get("slot_id") != slot_id:
			return "facility_slot_invalid"
	var expected_queue := _build_authority_queue(
		str(state.get("batch_id", "")),
		frozen_order,
		queues_variant as Dictionary
	)
	var authority_queue_variant: Variant = state.get("authority_queue")
	if not (authority_queue_variant is Array) \
			or (authority_queue_variant as Array) != expected_queue:
		return "authority_queue_invalid"
	var public_queue_variant: Variant = state.get("anonymous_global_queue")
	var receipts_variant: Variant = state.get("resolution_receipts")
	var processed_variant: Variant = state.get("processed_action_ids")
	if not (public_queue_variant is Array) or not (receipts_variant is Array) \
			or not (processed_variant is Array):
		return "resolution_journal_invalid"
	var cursor_variant: Variant = state.get("resolution_cursor")
	if not _nonnegative_integer(cursor_variant):
		return "resolution_cursor_invalid"
	var cursor := int(cursor_variant)
	if cursor > expected_queue.size() \
			or (public_queue_variant as Array).size() != expected_queue.size() \
			or (receipts_variant as Array).size() != cursor \
			or (processed_variant as Array).size() != cursor:
		return "resolution_journal_invalid"
	for index in range(expected_queue.size()):
		var expected_public := _pending_public_entry(expected_queue[index], index)
		if index < cursor:
			var receipt_variant: Variant = (receipts_variant as Array)[index]
			if not (receipt_variant is Dictionary) \
					or _receipt_error(receipt_variant as Dictionary) != "":
				return "resolution_receipt_invalid"
			var receipt := receipt_variant as Dictionary
			if receipt.get("action_id") != expected_queue[index].get("action_id") \
					or receipt.get("actor_id") != expected_queue[index].get("actor_id") \
					or (processed_variant as Array)[index] != receipt.get("action_id"):
				return "resolution_receipt_binding_invalid"
			expected_public = _public_entry_from_receipt(
				expected_queue[index],
				index,
				receipt
			)
		if (public_queue_variant as Array)[index] != expected_public:
			return "anonymous_public_queue_invalid"
	var expected_status := (
		"resolved"
		if expected_queue.is_empty() or cursor == expected_queue.size()
		else "resolution_ready"
		if cursor == 0
		else "resolving"
	)
	if state.get("status") != expected_status \
			or int(state.get("revision", 0)) != (
				cursor
				+ 1
				+ int(state.get("warehouse_solar_refresh_count", 0))
			):
		return "resolution_status_invalid"
	return ""


static func _action_error(action: Dictionary) -> String:
	if not _is_pure_data(action) or not _exact_fields(action, ACTION_FIELDS):
		return "facility_action_fields_invalid"
	var unsealed := action.duplicate(true)
	var fingerprint := str(unsealed.get("action_fingerprint", ""))
	unsealed.erase("action_fingerprint")
	if not _fingerprint_valid(fingerprint) or fingerprint != _fingerprint(unsealed):
		return "facility_action_fingerprint_invalid"
	if action.get("schema_version") != SCHEMA_VERSION \
			or action.get("contract_id") != FACILITY_ACTION_INTENT_ID \
			or not _stable_id(action.get("action_id")) \
			or not _stable_id(action.get("source_card_instance_id")) \
			or not _positive_integer(action.get("source_card_rank")) \
			or int(action.get("source_card_rank", 0)) > MAX_FACILITY_RANK \
			or not _stable_id(action.get("actor_id")) \
			or not _nonnegative_integer(action.get("local_action_index")) \
			or int(action.get("local_action_index", -1)) >= MAX_ACTIONS_PER_PLAYER \
			or not ORIGIN_CLASSES.has(action.get("origin_class")) \
			or not FACILITY_ACTION_MODES.has(action.get("facility_action_mode")) \
			or not _stable_id(action.get("region_id")) \
			or not _nonnegative_integer(action.get("region_revision")) \
			or not FACILITY_TYPES.has(action.get("facility_type")) \
			or not INDUSTRIES.has(action.get("industry_id")) \
			or action.get("target_slot_id") != facility_slot_id(
				str(action.get("region_id", "")),
				str(action.get("facility_type", "")),
				str(action.get("industry_id", ""))
			) \
			or not _nonnegative_integer(action.get("target_slot_generation")) \
			or not OCCUPANCY_VALUES.has(action.get("expected_occupancy")) \
			or not _asset_map_valid(action.get("reserved_assets")) \
			or action.get("invalid_target_policy_id") != INVALID_TARGET_POLICY_ID:
		return "facility_action_context_invalid"
	if action.get("origin_class") == "starter_bootstrap" \
			and action.get("reserved_assets") != _zero_assets():
		return "starter_asset_reservation_invalid"
	var mode := str(action.get("facility_action_mode", ""))
	if mode == "BUILD_NEW":
		if action.get("expected_occupancy") != "empty" \
				or action.get("expected_facility_id") != null \
				or action.get("expected_facility_generation") != null \
				or action.get("expected_owner_id") != null \
				or action.get("expected_rank") != null \
				or action.get("expected_damage_revision") != null:
			return "facility_build_closed_none_fields_invalid"
	elif mode == "UPGRADE_OWN":
		if action.get("expected_occupancy") != "occupied" \
				or not _stable_id(action.get("expected_facility_id")) \
				or not _nonnegative_integer(action.get("expected_facility_generation")) \
				or not _stable_id(action.get("expected_owner_id")) \
				or not _positive_integer(action.get("expected_rank")) \
				or int(action.get("expected_rank", 0)) >= MAX_FACILITY_RANK \
				or action.get("expected_damage_revision") != null:
			return "facility_upgrade_closed_none_fields_invalid"
	elif mode == "REPAIR_OWN":
		if action.get("expected_occupancy") != "occupied" \
				or not _stable_id(action.get("expected_facility_id")) \
				or not _nonnegative_integer(action.get("expected_facility_generation")) \
				or not _stable_id(action.get("expected_owner_id")) \
				or action.get("expected_rank") != null \
				or not _nonnegative_integer(action.get("expected_damage_revision")):
			return "facility_repair_closed_none_fields_invalid"
	return ""


static func _slot_error(slot: Dictionary) -> String:
	if not _is_pure_data(slot) or not _exact_fields(slot, SLOT_FIELDS) \
			or not _stable_id(slot.get("region_id")) \
			or not _nonnegative_integer(slot.get("region_revision")) \
			or not FACILITY_TYPES.has(slot.get("facility_type")) \
			or not INDUSTRIES.has(slot.get("industry_id")) \
			or slot.get("slot_id") != facility_slot_id(
				str(slot.get("region_id", "")),
				str(slot.get("facility_type", "")),
				str(slot.get("industry_id", ""))
			) \
			or not _nonnegative_integer(slot.get("slot_generation")) \
			or not OCCUPANCY_VALUES.has(slot.get("occupancy")):
		return "facility_slot_context_invalid"
	if slot.get("occupancy") == "empty":
		for field in [
			"facility_id",
			"facility_generation",
			"owner_id",
			"rank",
			"damage_revision",
			"damage_points",
			"capacity",
			"base_ingress_throughput",
			"base_egress_throughput",
			"ingress_throughput",
			"egress_throughput",
			"solar_efficiency_state",
			"commercial_art_key",
			"warehouse_stock_runtime_phase",
		]:
			if slot.get(field) != null:
				return "empty_facility_slot_closed_none_invalid"
		return ""
	if not _stable_id(slot.get("facility_id")) \
			or not _nonnegative_integer(slot.get("facility_generation")) \
			or not _stable_id(slot.get("owner_id")) \
			or not _positive_integer(slot.get("rank")) \
			or int(slot.get("rank", 0)) > MAX_FACILITY_RANK \
			or not _nonnegative_integer(slot.get("damage_revision")) \
			or not _nonnegative_integer(slot.get("damage_points")):
		return "occupied_facility_slot_invalid"
	if str(slot.get("facility_type", "")) == "warehouse":
		return WarehouseRuntime.slot_runtime_error(slot)
	for field_name in [
		"capacity",
		"base_ingress_throughput",
		"base_egress_throughput",
		"ingress_throughput",
		"egress_throughput",
		"solar_efficiency_state",
		"commercial_art_key",
		"warehouse_stock_runtime_phase",
	]:
		if slot.get(field_name) != null:
			return "nonwarehouse_runtime_field_not_null"
	return ""


static func _receipt_error(receipt: Dictionary) -> String:
	if not _is_pure_data(receipt) or not _exact_fields(receipt, RECEIPT_FIELDS):
		return "receipt_fields_invalid"
	var unsealed := receipt.duplicate(true)
	var fingerprint := str(unsealed.get("receipt_fingerprint", ""))
	unsealed.erase("receipt_fingerprint")
	if not _fingerprint_valid(fingerprint) or fingerprint != _fingerprint(unsealed):
		return "receipt_fingerprint_invalid"
	if receipt.get("schema_version") != SCHEMA_VERSION \
			or receipt.get("contract_id") != RECEIPT_ID \
			or not _stable_id(receipt.get("receipt_id")) \
			or not _stable_id(receipt.get("batch_id")) \
			or not _positive_integer(receipt.get("state_revision")) \
			or not _stable_id(receipt.get("anonymous_action_id")) \
			or not _stable_id(receipt.get("action_id")) \
			or not _stable_id(receipt.get("actor_id")) \
			or not FACILITY_ACTION_MODES.has(receipt.get("facility_action_mode")) \
			or receipt.get("accepted") != true \
			or receipt.get("invalid_target_policy_id") != INVALID_TARGET_POLICY_ID \
			or not _asset_map_valid(receipt.get("asset_release_amount")) \
			or receipt.get("normal_card_destination") != "discard" \
			or receipt.get("action_slot_refunded") != false \
			or receipt.get("target_reselected") != false \
			or receipt.get("exact_once") != true:
		return "receipt_context_invalid"
	var fizzled: bool = receipt.get("outcome_id") == "facility_action_fizzled"
	if fizzled:
		if not TYPED_RESOLUTION_RESULTS.has(receipt.get("reason_code")) \
				or receipt.get("reason_code") == "facility_action_resolved" \
				or receipt.get("asset_reservation_released") != true \
				or receipt.get("asset_reservation_consumed") != false \
				or receipt.get("facility_created") != false \
				or receipt.get("facility_upgraded") != false \
				or receipt.get("facility_repaired") != false:
			return "fizzle_receipt_invalid"
		return ""
	if receipt.get("outcome_id") != "facility_action_resolved" \
			or receipt.get("reason_code") != "facility_action_resolved" \
			or receipt.get("asset_reservation_released") != false \
			or receipt.get("asset_reservation_consumed") != true \
			or receipt.get("asset_release_amount") != _zero_assets():
		return "success_receipt_invalid"
	var effect_count := int(receipt.get("facility_created")) \
		+ int(receipt.get("facility_upgraded")) \
		+ int(receipt.get("facility_repaired"))
	return "" if effect_count == 1 else "success_receipt_effect_invalid"


static func _save_error(save_state: Dictionary) -> String:
	if not _is_pure_data(save_state) or not _exact_fields(save_state, SAVE_FIELDS):
		return "save_fields_invalid"
	var unsealed := save_state.duplicate(true)
	var fingerprint := str(unsealed.get("save_fingerprint", ""))
	unsealed.erase("save_fingerprint")
	if not _fingerprint_valid(fingerprint) or fingerprint != _fingerprint(unsealed):
		return "save_fingerprint_invalid"
	if save_state.get("schema_version") != SCHEMA_VERSION \
			or save_state.get("state_version") != STATE_VERSION \
			or save_state.get("contract_id") != SAVE_STATE_ID \
			or save_state.get("ruleset_id") != RULESET_ID \
			or save_state.get("balance_profile_id") != BALANCE_PROFILE_ID \
			or save_state.get("v072_direct_resume_allowed") != false \
			or save_state.get("v06_direct_resume_allowed") != false \
			or not (save_state.get("state") is Dictionary) \
			or _state_error(save_state.get("state")) != "" \
			or _contains_forbidden_runtime_field(save_state):
		return "save_context_invalid"
	return ""


static func _failure(state: Dictionary, reason_code: String) -> Dictionary:
	return {
		"accepted": false,
		"reason_code": reason_code,
		"state": state.duplicate(true) if state is Dictionary else {},
		"receipt": {},
	}


static func _created_facility_id(action: Dictionary) -> String:
	var input := "%s|%s|%s" % [
		action.get("action_id"),
		action.get("actor_id"),
		action.get("target_slot_id"),
	]
	return "facility.%s" % input.sha256_text().substr(0, 24)


static func _anonymous_action_id(
	batch_id: String,
	queue_index: int,
	action_id: String
) -> String:
	var input := "%s|%d|%s" % [batch_id, queue_index, action_id]
	return "anonymous.%s" % input.sha256_text().substr(0, 24)


static func _solar_map_error(value: Variant) -> String:
	if not (value is Dictionary) or not _is_pure_data(value):
		return "solar_map_not_pure_data"
	for region_id_variant in (value as Dictionary).keys():
		if (
			not (region_id_variant is String)
			or not _stable_id(region_id_variant)
			or str((value as Dictionary).get(region_id_variant))
			not in WarehouseRuntime.SOLAR_STATES
		):
			return "solar_map_entry_invalid"
	return ""


static func _asset_map_valid(value: Variant) -> bool:
	if not (value is Dictionary) or not _exact_fields(value as Dictionary, COLORS):
		return false
	for color in COLORS:
		if not _nonnegative_integer((value as Dictionary).get(color)):
			return false
	return true


static func _zero_assets() -> Dictionary:
	var result := {}
	for color in COLORS:
		result[color] = 0
	return result


static func _contains_forbidden_runtime_field(value: Variant) -> bool:
	if value is Array:
		for item_variant in value as Array:
			if _contains_forbidden_runtime_field(item_variant):
				return true
		return false
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			if FORBIDDEN_RUNTIME_FIELDS.has(key) \
					or key.begins_with("initiative_bid_") \
					or key.begins_with("auction_"):
				return true
			if _contains_forbidden_runtime_field((value as Dictionary).get(key_variant)):
				return true
	return false


static func _seal(unsealed: Dictionary, fingerprint_field: String) -> Dictionary:
	if not _is_pure_data(unsealed) or unsealed.has(fingerprint_field):
		return {}
	var sealed := unsealed.duplicate(true)
	sealed[fingerprint_field] = _fingerprint(sealed)
	return sealed


static func _fingerprint(value: Variant) -> String:
	var canonical := _canonical_json(value)
	return canonical.sha256_text().to_lower() if not canonical.is_empty() else ""


static func _canonical_json(value: Variant) -> String:
	if not _is_pure_data(value):
		return ""
	if value == null or value is String or value is bool or value is int:
		return JSON.stringify(value)
	if value is Array:
		var parts: Array[String] = []
		for item_variant in value as Array:
			parts.append(_canonical_json(item_variant))
		return "[" + ",".join(parts) + "]"
	var source := value as Dictionary
	var keys: Array[String] = []
	for key_variant in source.keys():
		keys.append(str(key_variant))
	keys.sort()
	var members: Array[String] = []
	for key in keys:
		members.append(JSON.stringify(key) + ":" + _canonical_json(source.get(key)))
	return "{" + ",".join(members) + "}"


static func _fingerprint_valid(value: Variant) -> bool:
	if not (value is String) or str(value).length() != 64:
		return false
	for index in range(str(value).length()):
		var code := str(value).unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true


static func _is_pure_data(value: Variant, depth: int = 0) -> bool:
	if depth > 64:
		return false
	if value == null or value is String or value is bool or value is int:
		return not (value is int) or _safe_integer(value)
	if value is Array:
		for item_variant in value as Array:
			if not _is_pure_data(item_variant, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not (key_variant is String) \
					or not _is_pure_data((value as Dictionary).get(key_variant), depth + 1):
				return false
		return true
	return false


static func _safe_integer(value: Variant) -> bool:
	return value is int and int(value) >= -MAX_SAFE_INTEGER and int(value) <= MAX_SAFE_INTEGER


static func _nonnegative_integer(value: Variant) -> bool:
	return _safe_integer(value) and int(value) >= 0


static func _positive_integer(value: Variant) -> bool:
	return _safe_integer(value) and int(value) > 0


static func _stable_id(value: Variant) -> bool:
	if not (value is String):
		return false
	var text := str(value)
	if text.is_empty() or text.length() > 160:
		return false
	var previous_separator := false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		var lower := code >= 97 and code <= 122
		var digit := code >= 48 and code <= 57
		var separator := code == 46 or code == 95 or code == 45
		if index == 0 and not lower:
			return false
		if not lower and not digit and not separator:
			return false
		if separator and previous_separator:
			return false
		previous_separator = separator
	return not previous_separator


static func _string_id_array(value: Variant, allow_empty: bool) -> Array[String]:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for item_variant in value as Array:
		if not _stable_id(item_variant) or result.has(str(item_variant)):
			return []
		result.append(str(item_variant))
	if not allow_empty and result.is_empty():
		return []
	return result


static func _exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


static func _exact_keys(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key_variant in keys:
		if not value.has(str(key_variant)):
			return false
	return true


static func _same_string_set(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false
	var left_sorted := left.duplicate()
	var right_sorted := right.duplicate()
	left_sorted.sort()
	right_sorted.sort()
	return left_sorted == right_sorted
