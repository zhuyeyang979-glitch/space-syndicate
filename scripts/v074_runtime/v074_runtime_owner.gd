extends "res://scripts/v073_runtime/v073_sample_runtime_owner.gd"
class_name V074RuntimeOwner

const MapRequest := preload("res://scripts/v074/map/map_genesis_request_v1.gd")
const MapGenesis := preload("res://scripts/v074/map/v074_map_genesis_core.gd")
const FacilityTypes := preload(
	"res://scripts/v074/facility/v074_facility_type_registry.gd"
)
const FacilityCore := preload(
	"res://scripts/v074/facility/v074_facility_runtime_core.gd"
)
const CardDefinitions := preload(
	"res://scripts/v074/facility/v074_card_definition_registry.gd"
)
const PlayerMapAdapter := preload(
	"res://scripts/v074/player/v074_player_map_projection_adapter.gd"
)
const MapTargetBinding := preload(
	"res://scripts/v074/player/v074_map_target_binding_v1.gd"
)
const AiMapAdapter := preload(
	"res://scripts/v074/ai/v074_dynamic_map_ai_observation_adapter.gd"
)
const PlanetPresentationAdapter := preload(
	"res://scripts/presentation/v074/v074_planet_presentation_adapter_v1.gd"
)
const SharedSushiTrackCore := preload(
	"res://scripts/v074/track/v074_shared_sushi_track_core.gd"
)

const V074_RULESET_ID := "v0.7.4"
const V074_SAMPLE_MODE_ID := "NEW_V074_GAME"
const CUTOVER_DOMAIN_COUNT := 15
const SUN_ROTATION_RADIANS_PER_BATCH := PI / 5.0
const AUTO_ACTION_LIMIT := 3
const V074_UNIFIED_TRACK_LOCAL_VISIBLE_CAPACITY := 10

var _map_genesis_receipt: Dictionary = {}
var _current_sun_direction := Vector3.ZERO
var _player_map_adapters: Dictionary = {}
var _ai_map_adapters: Dictionary = {}
var _planet_presentation_adapter: RefCounted = PlanetPresentationAdapter.new()
var _map_preview_count := 0
var _map_generation_count := 0
var _warehouse_solar_state_change_count := 0
var _warehouse_purchase_count := 0
var _warehouse_card_play_count := 0
var _warehouse_merge_count := 0
var _warehouse_action_mode_counts := {
	"BUILD_NEW": 0,
	"UPGRADE_OWN": 0,
	"REPAIR_OWN": 0,
}
var _warehouse_contention_fizzle_count := 0


func preview_map(map_request: Dictionary) -> Dictionary:
	var receipt := _generate_map(map_request)
	_map_preview_count += 1
	if not bool(receipt.get("accepted", false)):
		return {
			"accepted": false,
			"reason_code": str(receipt.get(
				"reason_code",
				"map_genesis_preview_failed"
			)),
		}
	return {
		"accepted": true,
		"reason_code": "map_genesis_preview_ready",
		"map_genesis_receipt": receipt.duplicate(true),
	}


func map_genesis_receipt() -> Dictionary:
	return _map_genesis_receipt.duplicate(true)


func acquire_track_item(
	actor_id: String,
	source_instance_id: String
) -> Dictionary:
	var warehouse_purchase := false
	if _track_core != null:
		var projection := (
			_track_core.call("player_projection_v1", actor_id) as Dictionary
		)
		var private_facts := (
			projection.get("viewer_private_facts", {}) as Dictionary
		)
		for item_variant in private_facts.get("own_segment_items", []) as Array:
			var item := item_variant as Dictionary
			if str(item.get("instance_id", "")) != source_instance_id:
				continue
			if (
				not bool(item.get("claimable", false))
				and str(item.get("claimability_state", ""))
				== "incoming_locked"
			):
				return _reject_action(
					"track_replacement_locked_until_next_scroll"
				)
			warehouse_purchase = str(
				item.get("card_definition_id", "")
			).contains(".warehouse.")
			break
	var receipt := super.acquire_track_item(actor_id, source_instance_id)
	if warehouse_purchase and bool(receipt.get("accepted", false)):
		_warehouse_purchase_count += 1
	return receipt


func merge_normal_pair(
	actor_id: String,
	left_instance_id: String,
	right_instance_id: String
) -> Dictionary:
	var facts := _dbg_projection(actor_id).get("facts", {}) as Dictionary
	var left := _dbg_card_by_id(facts, left_instance_id)
	var right := _dbg_card_by_id(facts, right_instance_id)
	var warehouse_pair := (
		_is_warehouse_card(left)
		and _is_warehouse_card(right)
	)
	var receipt := super.merge_normal_pair(
		actor_id,
		left_instance_id,
		right_instance_id
	)
	if warehouse_pair and bool(receipt.get("accepted", false)):
		_warehouse_merge_count += 1
	return receipt


func _is_warehouse_card(card: Dictionary) -> bool:
	return (
		str(card.get("card_type", "")) == "warehouse"
		or str(card.get("definition_id", "")).contains(".warehouse.")
	)


func queue_card_action(
	actor_id: String,
	card_instance_id: String,
	target_slot_id: String,
	target_binding: Dictionary = {}
) -> Dictionary:
	if not target_binding.is_empty():
		var validation := MapTargetBinding.validation_report(target_binding)
		if not bool(validation.get("valid", false)):
			return _reject_action("typed_target_binding_invalid")
		if (
			str(target_binding.get("card_instance_id", "")) != card_instance_id
			or str(target_binding.get("target_slot_id", "")) != target_slot_id
		):
			return _reject_action("typed_target_binding_identity_mismatch")
		var resolved := resolve_map_target(
			card_instance_id,
			str(target_binding.get("target_region_id", "")),
			str(target_binding.get("facility_type", "")),
			str(target_binding.get("industry_id", "")),
			str(target_binding.get("facility_action_mode", ""))
		)
		if (
			not bool(resolved.get("accepted", false))
			or not MapTargetBinding.same_slot_identity(
				target_binding,
				resolved.get("binding", {}) as Dictionary
			)
		):
			return _reject_action("typed_target_binding_stale")
	return super.queue_card_action(actor_id, card_instance_id, target_slot_id)


func planet_map_view_payload(
	viewer_id: String,
	selected_card_instance_id: String = "",
	selected_region_id: String = ""
) -> Dictionary:
	var public_projection := player_snapshot(viewer_id)
	if public_projection.is_empty():
		return {}
	public_projection["sun_direction"] = _current_sun_direction
	public_projection["solar_threshold"] = float(
		_map_genesis_receipt.get("solar_threshold", 0.0)
	)
	return _planet_presentation_adapter.call(
		"build_map_view_payload",
		_map_genesis_receipt,
		public_projection,
		selected_card_instance_id,
		selected_region_id
	) as Dictionary


func region_popup(region_id: String) -> Dictionary:
	var adapter := _player_map_adapter(_local_player_id)
	if adapter == null:
		return {}
	if (adapter.call("projection") as Dictionary).is_empty():
		player_snapshot(_local_player_id)
	return adapter.call("region_popup", region_id) as Dictionary


func resolve_map_target(
	card_instance_id: String,
	region_id: String,
	facility_type: String,
	industry_id: String,
	action_mode: String
) -> Dictionary:
	var adapter := _player_map_adapter(_local_player_id)
	if adapter == null:
		return {"accepted": false, "reason_code": "player_map_adapter_missing"}
	if (adapter.call("projection") as Dictionary).is_empty():
		player_snapshot(_local_player_id)
	return adapter.call(
		"resolve_target",
		card_instance_id,
		region_id,
		facility_type,
		industry_id,
		action_mode
	) as Dictionary


func ai_observation(actor_id: String) -> Dictionary:
	var observation := super.ai_observation(actor_id)
	if observation.is_empty():
		return observation
	var warehouse_actions: Array = []
	var remaining_actions: Array = []
	for action_variant in observation.get("legal_actions", []) as Array:
		var action := action_variant as Dictionary
		if str(action.get("facility_type", "")) == "warehouse":
			warehouse_actions.append(action.duplicate(true))
		else:
			remaining_actions.append(action.duplicate(true))
	warehouse_actions.append_array(remaining_actions)
	observation["legal_actions"] = warehouse_actions
	return observation


func player_snapshot(viewer_id: String) -> Dictionary:
	var snapshot := super.player_snapshot(viewer_id)
	if snapshot.is_empty():
		return {}
	var adapter := _player_map_adapter(viewer_id)
	if adapter == null:
		_adapter_failure_count += 1
		return {}
	var projection := adapter.call(
		"adapt",
		viewer_id,
		_player_map_receipt(),
		_public_facility_slots(),
		legal_card_actions(viewer_id)
	) as Dictionary
	if projection.is_empty():
		_adapter_failure_count += 1
		return {}
	snapshot["ruleset_id"] = V074_RULESET_ID
	snapshot["sample_mode_id"] = V074_SAMPLE_MODE_ID
	snapshot["save_notice"] = "V0.7.4样品暂不支持中途保存"
	snapshot["map_seed"] = int(_map_genesis_receipt.get("map_seed", 0))
	snapshot["map_id"] = str(_map_genesis_receipt.get("map_id", ""))
	snapshot["map_fingerprint"] = str(
		_map_genesis_receipt.get("map_fingerprint", "")
	)
	snapshot["region_count"] = int(
		_map_genesis_receipt.get("region_count", 0)
	)
	snapshot["region_ids"] = (
		_map_genesis_receipt.get("region_ids", []) as Array
	).duplicate()
	snapshot["map_player_projection"] = projection
	snapshot["map_genesis_summary"] = _map_genesis_summary()
	return snapshot


func debug_snapshot() -> Dictionary:
	var result := super.debug_snapshot()
	var validation := (
		(_map_genesis_receipt.get("validation_summary", {}) as Dictionary)
		.duplicate(true)
		if not _map_genesis_receipt.is_empty()
		else {}
	)
	var warehouse_count := 0
	for slot_variant in _facility_slots:
		var slot := slot_variant as Dictionary
		if (
			str(slot.get("facility_type", "")) == "warehouse"
			and str(slot.get("occupancy", "")) == "occupied"
		):
			warehouse_count += 1
	var local_track_items: Array = []
	var track_ratios: Dictionary = {}
	if _track_core != null and not _player_ids.is_empty():
		var track_projection := _track_core.call(
			"player_projection_v1",
			_local_player_id
		) as Dictionary
		local_track_items = (
			(track_projection.get(
				"viewer_private_facts",
				{}
			) as Dictionary).get("own_segment_items", []) as Array
		).duplicate(true)
		track_ratios = (
			(track_projection.get("public_facts", {}) as Dictionary).get(
				"card_kind_ratio_basis_points",
				{}
			) as Dictionary
		).duplicate(true)
	var track_runtime_debug: Dictionary = {}
	if (
		_track_core != null
		and _track_core.has_method("debug_snapshot_v074")
	):
		track_runtime_debug = (
			_track_core.call("debug_snapshot_v074") as Dictionary
		).duplicate(true)
	var track_instance_ids := {}
	var track_duplicate_instance_count := 0
	for item_variant in local_track_items:
		var instance_id := str(
			(item_variant as Dictionary).get("instance_id", "")
		)
		if track_instance_ids.has(instance_id):
			track_duplicate_instance_count += 1
		track_instance_ids[instance_id] = true
	result["ruleset_id"] = V074_RULESET_ID
	result["map_genesis_owner_count"] = (
		1 if not _map_genesis_receipt.is_empty() else 0
	)
	result["map_genesis_rng_owner_count"] = (
		1 if not _map_genesis_receipt.is_empty() else 0
	)
	result["map_generation_count"] = _map_generation_count
	result["map_preview_count"] = _map_preview_count
	result["map_fingerprint"] = str(
		_map_genesis_receipt.get("map_fingerprint", "")
	)
	result["dynamic_region_count"] = int(
		_map_genesis_receipt.get("region_count", 0)
	)
	result["facility_slot_count"] = _facility_slots.size()
	result["facility_slot_count_per_region"] = (
		FacilityTypes.facility_slot_count_per_region()
	)
	result["registered_facility_types"] = (
		FacilityTypes.registered_facility_types()
	)
	result["unified_track_local_visible_card_capacity"] = (
		V074_UNIFIED_TRACK_LOCAL_VISIBLE_CAPACITY
	)
	result["track_player_projection_visible_card_count"] = (
		local_track_items.size()
	)
	result["track_duplicate_instance_count"] = (
		track_duplicate_instance_count
	)
	result["track_kind_ratio_basis_points"] = track_ratios
	result["track_refill_mode_id"] = str(
		track_runtime_debug.get("refill_mode_id", "")
	)
	result["track_acquisition_commit_count"] = int(
		track_runtime_debug.get("acquisition_commit_count", 0)
	)
	result["track_immediate_authoritative_refill_count"] = int(
		track_runtime_debug.get(
			"immediate_authoritative_refill_count",
			0
		)
	)
	result["track_supply_rng_draw_delta_on_acquisition"] = int(
		track_runtime_debug.get(
			"supply_rng_draw_delta_on_acquisition",
			0
		)
	)
	result["track_supply_cursor_delta_on_acquisition"] = int(
		track_runtime_debug.get(
			"supply_cursor_delta_on_acquisition",
			0
		)
	)
	result["track_supply_instance_sequence_delta_on_acquisition"] = int(
		track_runtime_debug.get(
			"supply_instance_sequence_delta_on_acquisition",
			0
		)
	)
	result["track_global_vacancy_count"] = int(
		track_runtime_debug.get("vacancy_count", 0)
	)
	result["track_scroll_sequence"] = int(
		track_runtime_debug.get("scroll_sequence", 0)
	)
	result["track_other_player_segment_disclosure_count"] = 0
	result["track_future_supply_disclosure_count"] = 0
	result["warehouse_facility_count"] = warehouse_count
	result["warehouse_solar_state_change_count"] = (
		_warehouse_solar_state_change_count
	)
	result["warehouse_purchase_count"] = _warehouse_purchase_count
	result["warehouse_card_play_count"] = _warehouse_card_play_count
	result["warehouse_merge_count"] = _warehouse_merge_count
	result["warehouse_build_count"] = int(
		_warehouse_action_mode_counts.get("BUILD_NEW", 0)
	)
	result["warehouse_upgrade_count"] = int(
		_warehouse_action_mode_counts.get("UPGRADE_OWN", 0)
	)
	result["warehouse_repair_count"] = int(
		_warehouse_action_mode_counts.get("REPAIR_OWN", 0)
	)
	result["warehouse_contention_fizzle_count"] = (
		_warehouse_contention_fizzle_count
	)
	result["map_validation"] = validation
	result["connected_domain_count"] = (
		CUTOVER_DOMAIN_COUNT if not _map_genesis_receipt.is_empty() else 0
	)
	result["map_dual_write_count"] = 0
	result["warehouse_dual_write_count"] = 0
	result["fixed_six_region_fallback_count"] = 0
	result["factory_market_only_fallback_count"] = 0
	result["solar_state_geometry_derived"] = true
	result["planet_presentation"] = (
		_planet_presentation_adapter.call("debug_snapshot") as Dictionary
	)
	return result


func _reset_runtime() -> void:
	super._reset_runtime()
	_map_genesis_receipt = {}
	_current_sun_direction = Vector3.ZERO
	_player_map_adapters = {}
	_ai_map_adapters = {}
	_planet_presentation_adapter = PlanetPresentationAdapter.new()
	_map_generation_count = 0
	_warehouse_solar_state_change_count = 0
	_warehouse_purchase_count = 0
	_warehouse_card_play_count = 0
	_warehouse_merge_count = 0
	_warehouse_action_mode_counts = {
		"BUILD_NEW": 0,
		"UPGRADE_OWN": 0,
		"REPAIR_OWN": 0,
	}
	_warehouse_contention_fizzle_count = 0


func _prepare_runtime_new_game(map_request: Dictionary) -> Dictionary:
	var receipt := _generate_map(map_request)
	if not bool(receipt.get("accepted", false)):
		return {
			"accepted": false,
			"reason_code": str(receipt.get(
				"reason_code",
				"map_genesis_failed"
			)),
			"map_validation": (
				receipt.get("validation_summary", {}) as Dictionary
			).duplicate(true),
		}
	_map_genesis_receipt = receipt.duplicate(true)
	_current_sun_direction = (
		receipt.get("initial_sun_direction", Vector3.ZERO) as Vector3
	).normalized()
	_map_generation_count = 1
	return {
		"accepted": true,
		"reason_code": "v074_authoritative_map_ready",
		"map_id": str(receipt.get("map_id", "")),
		"map_fingerprint": str(receipt.get("map_fingerprint", "")),
	}


func _generate_map(map_request: Dictionary) -> Dictionary:
	var request := MapRequest.build(
		int(map_request.get("map_seed", map_request.get("seed", 900626424))),
		int(map_request.get("region_count", 16)),
		str(map_request.get("geography_complexity", "STANDARD")),
		str(map_request.get("land_ocean_profile", "BALANCED")),
		FacilityTypes.registered_facility_types(),
		FacilityTypes.industry_ids()
	)
	return MapGenesis.generate(request)


func _runtime_match_id(seed_value: int, sequence: int) -> String:
	return "match.v074.sample.%d.%d" % [absi(seed_value), sequence]


func _create_track_core() -> RefCounted:
	return SharedSushiTrackCore.new()


func _track_start_config() -> Dictionary:
	return {
		"balance_profile_id": TRACK_CORE.BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": TRACK_CORE.BALANCE_PROFILE_FINGERPRINT,
		"normal_card_ratio_basis_points": 6000,
		"commodity_card_ratio_basis_points": 4000,
		"local_visible_slot_count": V074_UNIFIED_TRACK_LOCAL_VISIBLE_CAPACITY,
		"match_instance_id": _match_id,
		"card_definition_registry_id": CardDefinitions.REGISTRY_ID,
	}


func _runtime_ruleset_id() -> String:
	return V074_RULESET_ID


func _runtime_sample_mode_id() -> String:
	return V074_SAMPLE_MODE_ID


func _runtime_new_game_reason() -> String:
	return "v074_new_game_started"


func _runtime_new_game_failure_reason() -> String:
	return "v074_new_game_initialization_failed"


func _runtime_new_game_metadata() -> Dictionary:
	return {
		"map_id": str(_map_genesis_receipt.get("map_id", "")),
		"map_fingerprint": str(
			_map_genesis_receipt.get("map_fingerprint", "")
		),
		"region_count": int(_map_genesis_receipt.get("region_count", 0)),
		"balance_profile_id": FacilityCore.BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": str(
			FacilityCore.contract_snapshot().get(
				"balance_profile_fingerprint",
				""
			)
		),
	}


func _runtime_legal_target_authority_id() -> String:
	return "v074.production.dynamic_map_legal_target_authority"


func _runtime_track_authorization_authority_id() -> String:
	return "v074.player_segment_authority"


func _runtime_victory_condition_id() -> String:
	return "v074.public_facility_network_threshold"


func _auto_acquire_track_item(actor_id: String) -> Dictionary:
	var track_projection := (
		_track_core.call("player_projection_v1", actor_id) as Dictionary
	)
	var private_facts := (
		track_projection.get("viewer_private_facts", {}) as Dictionary
	)
	var preferred_colors := _preferred_warehouse_colors(actor_id)
	var matching_warehouse_instance_id := ""
	var warehouse_instance_id := ""
	var fallback_instance_id := ""
	for item_variant in private_facts.get("own_segment_items", []) as Array:
		var item := item_variant as Dictionary
		if (
			not bool(item.get("claimable", false))
			or str(item.get("card_kind", "")) != "normal_card"
		):
			continue
		var instance_id := str(item.get("instance_id", ""))
		if fallback_instance_id.is_empty():
			fallback_instance_id = instance_id
		if not str(item.get("card_definition_id", "")).contains(
			".warehouse."
		):
			continue
		if warehouse_instance_id.is_empty():
			warehouse_instance_id = instance_id
		if (
			matching_warehouse_instance_id.is_empty()
			and preferred_colors.has(str(item.get("primary_color", "")))
		):
			matching_warehouse_instance_id = instance_id
	if not matching_warehouse_instance_id.is_empty():
		return acquire_track_item(actor_id, matching_warehouse_instance_id)
	if not warehouse_instance_id.is_empty():
		return acquire_track_item(actor_id, warehouse_instance_id)
	if not fallback_instance_id.is_empty():
		return acquire_track_item(actor_id, fallback_instance_id)
	return {
		"accepted": true,
		"reason_code": "no_claimable_track_item",
		"actor_id": actor_id,
	}


func _preferred_warehouse_colors(actor_id: String) -> Dictionary:
	var result := {}
	var facts := _dbg_projection(actor_id).get("facts", {}) as Dictionary
	for zone_name in ["hand", "discard"]:
		for card_variant in facts.get(zone_name, []) as Array:
			var card := card_variant as Dictionary
			if (
				str(card.get("card_type", "")) == "warehouse"
				or str(card.get("definition_id", "")).contains(
					".warehouse."
				)
			):
				result[str(card.get("primary_color", ""))] = true
	for slot_variant in _facility_slots:
		var slot := slot_variant as Dictionary
		if (
			str(slot.get("occupancy", "")) == "occupied"
			and str(slot.get("owner_id", "")) == actor_id
			and str(slot.get("facility_type", "")) == "warehouse"
		):
			result[str(slot.get("industry_id", ""))] = true
	result.erase("")
	return result


func _auto_queue_and_lock(actor_id: String) -> Dictionary:
	if bool(_locked_by_player.get(actor_id, false)):
		return {
			"accepted": true,
			"reason_code": "submission_already_locked",
			"actor_id": actor_id,
		}
	var queue := _queued_by_player.get(actor_id, []) as Array
	if queue.is_empty():
		var acquisition_receipt := _auto_acquire_track_item(actor_id)
		if not bool(acquisition_receipt.get("accepted", false)):
			return acquisition_receipt
		var legal := _auto_legal_actions(actor_id)
		for _action_index in range(AUTO_ACTION_LIMIT):
			queue = _queued_by_player.get(actor_id, []) as Array
			var available := _auto_available_actions(
				actor_id,
				queue,
				legal
			)
			if available.is_empty():
				break
			var preferred := _preferred_v074_ai_action(available)
			var queue_receipt := queue_card_action(
				actor_id,
				str(preferred.get("card_instance_id", "")),
				str(preferred.get("target_slot_id", ""))
			)
			if not bool(queue_receipt.get("accepted", false)):
				return queue_receipt
	return lock_player_submission(actor_id)


func _auto_legal_actions(actor_id: String) -> Array:
	if actor_id == _local_player_id:
		return legal_card_actions(actor_id)
	var observation := ai_observation(actor_id)
	if observation.is_empty():
		return []
	return (
		observation.get("legal_actions", []) as Array
	).duplicate(true)


func _auto_available_actions(
	actor_id: String,
	queue: Array,
	legal: Array
) -> Array:
	var queued_card_ids := {}
	var queued_slot_ids := {}
	for binding_variant in queue:
		var binding := binding_variant as Dictionary
		queued_card_ids[str(binding.get("card_instance_id", ""))] = true
		queued_slot_ids[str(binding.get("target_slot_id", ""))] = true
	var result: Array = []
	for option_variant in legal:
		var option := option_variant as Dictionary
		if (
			queued_card_ids.has(str(option.get("card_instance_id", "")))
			or queued_slot_ids.has(str(option.get("target_slot_id", "")))
			or _auto_preserves_warehouse_merge_material(actor_id, option)
			or not _auto_action_affordable(actor_id, option, queue)
		):
			continue
		result.append(option.duplicate(true))
	return result


func _auto_preserves_warehouse_merge_material(
	actor_id: String,
	option: Dictionary
) -> bool:
	if (
		str(option.get("facility_type", "")) != "warehouse"
		or str(option.get("facility_action_mode", "")) != "BUILD_NEW"
	):
		return false
	var card := _card_in_hand(
		actor_id,
		str(option.get("card_instance_id", ""))
	)
	if card.is_empty():
		return false
	var source_rank := int(card.get("level", card.get("rank", 0)))
	var industry_id := str(card.get("primary_color", ""))
	for slot_variant in _facility_slots:
		var slot := slot_variant as Dictionary
		if (
			str(slot.get("occupancy", "")) == "occupied"
			and str(slot.get("owner_id", "")) == actor_id
			and str(slot.get("facility_type", "")) == "warehouse"
			and str(slot.get("industry_id", "")) == industry_id
			and int(slot.get("rank", 0)) >= source_rank
		):
			return true
	return false


func _auto_action_affordable(
	actor_id: String,
	option: Dictionary,
	queue: Array
) -> bool:
	var players := _asset_state.get("players", {}) as Dictionary
	var player := players.get(actor_id, {}) as Dictionary
	var available := player.get("assets", {}) as Dictionary
	var reserved := {}
	for color_id in COLORS:
		reserved[color_id] = 0
	for binding_variant in queue:
		var binding := binding_variant as Dictionary
		var queued_card := _card_in_hand(
			actor_id,
			str(binding.get("card_instance_id", ""))
		)
		var queued_color := str(queued_card.get("primary_color", ""))
		if queued_color in COLORS:
			reserved[queued_color] = int(reserved.get(queued_color, 0)) + int(
				queued_card.get("primary_asset_cost", 0)
			)
	var candidate := _card_in_hand(
		actor_id,
		str(option.get("card_instance_id", ""))
	)
	var candidate_color := str(candidate.get("primary_color", ""))
	if candidate_color not in COLORS:
		return false
	reserved[candidate_color] = int(
		reserved.get(candidate_color, 0)
	) + int(candidate.get("primary_asset_cost", 0))
	for color_id in COLORS:
		if int(reserved.get(color_id, 0)) > int(available.get(color_id, 0)):
			return false
	return true


func _auto_maintenance(actor_id: String) -> void:
	var facts := _dbg_projection(actor_id).get("facts", {}) as Dictionary
	var pairs := facts.get("eligible_merge_pairs", []) as Array
	var selected_pair: Array = []
	for pair_variant in pairs:
		var pair := pair_variant as Array
		if pair.size() != 2:
			continue
		var left := _dbg_card_by_id(facts, str(pair[0]))
		var right := _dbg_card_by_id(facts, str(pair[1]))
		if (
			str(left.get("card_type", "")) == "warehouse"
			and str(right.get("card_type", "")) == "warehouse"
		):
			selected_pair = pair
			break
	if selected_pair.is_empty() and not pairs.is_empty() and absi(
		actor_id.hash()
	) % 2 == 0:
		selected_pair = pairs[0] as Array
	if selected_pair.size() == 2:
		merge_normal_pair(
			actor_id,
			str(selected_pair[0]),
			str(selected_pair[1])
		)
	finish_maintenance(actor_id)


func _dbg_card_by_id(facts: Dictionary, instance_id: String) -> Dictionary:
	for zone_name in ["hand", "discard"]:
		for card_variant in facts.get(zone_name, []) as Array:
			var card := card_variant as Dictionary
			if str(card.get("instance_id", "")) == instance_id:
				return card
	return {}


func _preferred_v074_ai_action(legal: Array) -> Dictionary:
	var preferred_region_id := _preferred_ai_region_id()
	for mode in ["REPAIR_OWN", "UPGRADE_OWN", "BUILD_NEW"]:
		var mode_fallback := {}
		for option_variant in legal:
			var option := option_variant as Dictionary
			if (
				str(option.get("facility_type", "")) != "warehouse"
				or str(option.get("facility_action_mode", "")) != mode
			):
				continue
			if mode_fallback.is_empty():
				mode_fallback = option
			if str(option.get("target_region_id", "")) == preferred_region_id:
				return option
		if not mode_fallback.is_empty():
			return mode_fallback
	for option_variant in legal:
		var option := option_variant as Dictionary
		if (
			str(option.get("target_region_id", "")) == preferred_region_id
			and str(option.get("industry_id", "")) == "life"
		):
			return option
	return legal[0] as Dictionary


func _preferred_ai_region_id() -> String:
	var region_ids := _runtime_region_ids()
	for region_id in region_ids:
		if (
			str((_map_genesis_receipt.get(
				"terrain_by_region",
				{}
			) as Dictionary).get(region_id, "")) == "land"
			and bool(_region_sunlit.get(region_id, false))
		):
			return region_id
	return str(region_ids[0]) if not region_ids.is_empty() else ""


func _runtime_region_ids() -> Array[String]:
	var result: Array[String] = []
	for region_id_variant in _map_genesis_receipt.get("region_ids", []) as Array:
		result.append(str(region_id_variant))
	return result


func _build_genesis_facility_slots() -> Array:
	var registry := (
		_map_genesis_receipt.get("facility_slot_registry", {}) as Dictionary
	)
	var slot_ids: Array[String] = []
	for slot_id_variant in registry.keys():
		slot_ids.append(str(slot_id_variant))
	slot_ids.sort()
	var result: Array = []
	for slot_id in slot_ids:
		var source := registry.get(slot_id, {}) as Dictionary
		var slot := FacilityCore.build_empty_slot(
			str(source.get("region_id", "")),
			int(source.get("region_revision", 0)),
			str(source.get("facility_type", "")),
			str(source.get("industry_id", "")),
			int(source.get("slot_generation", 0))
		)
		if slot.is_empty() or str(slot.get("slot_id", "")) != slot_id:
			return []
		result.append(slot)
	return result


func _facility_resolve_next(state: Dictionary) -> Dictionary:
	var pending_action := _pending_facility_action(state)
	var outcome := FacilityCore.resolve_next(state)
	if (
		str(pending_action.get("facility_type", "")) == "warehouse"
		and bool(outcome.get("accepted", false))
	):
		var receipt := outcome.get("receipt", {}) as Dictionary
		_warehouse_card_play_count += 1
		if str(receipt.get("outcome_id", "")) == "facility_action_fizzled":
			_warehouse_contention_fizzle_count += 1
		else:
			var mode := str(receipt.get("facility_action_mode", ""))
			if _warehouse_action_mode_counts.has(mode):
				_warehouse_action_mode_counts[mode] = int(
					_warehouse_action_mode_counts.get(mode, 0)
				) + 1
	return outcome


func _pending_facility_action(state: Dictionary) -> Dictionary:
	var cursor := int(state.get("resolution_cursor", -1))
	var authority_queue := state.get("authority_queue", []) as Array
	if cursor < 0 or cursor >= authority_queue.size():
		return {}
	var authority_entry := authority_queue[cursor] as Dictionary
	var actor_id := str(authority_entry.get("actor_id", ""))
	var action_id := str(authority_entry.get("action_id", ""))
	var queues := state.get("player_local_queues", {}) as Dictionary
	for action_variant in queues.get(actor_id, []) as Array:
		var action := action_variant as Dictionary
		if str(action.get("action_id", "")) == action_id:
			return action
	return {}


func _facility_player_projection(
	state: Dictionary,
	viewer_id: String
) -> Dictionary:
	return FacilityCore.player_projection(state, viewer_id)


func _facility_ai_observation(
	state: Dictionary,
	viewer_id: String
) -> Dictionary:
	return FacilityCore.ai_observation(state, viewer_id)


func _facility_validation_report(state: Dictionary) -> Dictionary:
	return FacilityCore.validation_report(state)


func _facility_lock_batch(
	batch_id: String,
	player_ids: Array,
	hidden_order: Array,
	player_local_queues: Dictionary,
	facility_slots: Array
) -> Dictionary:
	return FacilityCore.lock_batch(
		batch_id,
		player_ids,
		hidden_order,
		player_local_queues,
		facility_slots,
		true
	)


func _facility_build_action(
	mode: String,
	action_id: String,
	source_card_instance_id: String,
	actor_id: String,
	local_action_index: int,
	slot: Dictionary,
	reserved_assets: Dictionary,
	origin_class: String,
	source_card_rank: int
) -> Dictionary:
	match mode:
		"BUILD_NEW":
			return FacilityCore.build_new_action(
				action_id,
				source_card_instance_id,
				actor_id,
				local_action_index,
				slot,
				reserved_assets,
				origin_class,
				source_card_rank
			)
		"UPGRADE_OWN":
			return FacilityCore.build_upgrade_action(
				action_id,
				source_card_instance_id,
				actor_id,
				local_action_index,
				slot,
				reserved_assets,
				origin_class,
				source_card_rank
			)
		"REPAIR_OWN":
			return FacilityCore.build_repair_action(
				action_id,
				source_card_instance_id,
				actor_id,
				local_action_index,
				slot,
				reserved_assets,
				origin_class,
				source_card_rank
			)
	return {}


func _facility_max_rank() -> int:
	return FacilityCore.MAX_FACILITY_RANK


func _facility_slot_card_mode_legal(
	_actor_id: String,
	card: Dictionary,
	slot: Dictionary
) -> bool:
	var source_rank := int(card.get("level", card.get("rank", 0)))
	var current_rank := int(slot.get("rank", 0))
	if int(slot.get("damage_points", 0)) > 0:
		return source_rank >= 1 and source_rank <= current_rank
	return source_rank > current_rank and source_rank <= _facility_max_rank()


func _initialize_region_solar() -> void:
	_apply_geometric_solar(_current_sun_direction, false)


func _update_region_solar() -> void:
	var initial := (
		_map_genesis_receipt.get(
			"initial_sun_direction",
			Vector3.FORWARD
		) as Vector3
	).normalized()
	var rotation := Quaternion(
		Vector3.UP,
		SUN_ROTATION_RADIANS_PER_BATCH * float(_batch_number)
	)
	_apply_geometric_solar((rotation * initial).normalized(), true)


func _apply_geometric_solar(
	sun_direction: Vector3,
	refresh_facilities: bool
) -> void:
	var previous_warehouse_solar := _occupied_warehouse_solar_states()
	var solar_rows := MapGenesis.geometric_solar_by_region(
		_map_genesis_receipt,
		sun_direction
	)
	if solar_rows.size() != _runtime_region_ids().size():
		_fail("geometric_solar_projection_failed", {})
		return
	_current_sun_direction = sun_direction
	_region_sunlit = {}
	var solar_states := {}
	for region_id in _runtime_region_ids():
		var row := solar_rows.get(region_id, {}) as Dictionary
		var solar_state := str(row.get("solar_state", "dark"))
		var sunlit := solar_state == "sunlit"
		_region_sunlit[region_id] = sunlit
		solar_states[region_id] = solar_state
	if refresh_facilities and not _facility_state.is_empty():
		var refreshed := FacilityCore.refresh_warehouse_solar_states(
			_facility_state,
			solar_states
		)
		if refreshed.is_empty():
			_fail("warehouse_solar_refresh_failed", {})
			return
		_facility_state = refreshed
		_sync_facility_slots()
		var current_warehouse_solar := _occupied_warehouse_solar_states()
		for facility_id_variant in previous_warehouse_solar.keys():
			var facility_id := str(facility_id_variant)
			if (
				current_warehouse_solar.has(facility_id)
				and str(previous_warehouse_solar.get(facility_id, "")) != str(
					current_warehouse_solar.get(facility_id, "")
				)
			):
				_warehouse_solar_state_change_count += 1
	var global_sunlit := _current_sun_direction.dot(Vector3.FORWARD) > 0.0
	var intent := {
		"schema_version": SOLAR_VICTORY_CORE.SCHEMA_VERSION,
		"intent_id": "intent.solar.geometry.%d" % _batch_number,
		"intent_kind_id": SOLAR_VICTORY_CORE.INTENT_KIND_SOLAR,
		"expected_revision": int(_solar_state.get("revision", 0)),
		"sunlit": global_sunlit,
		"source_revision": _batch_number,
	}
	var outcome := SOLAR_VICTORY_CORE.apply_solar_intent(
		_solar_state,
		intent
	)
	if not outcome.is_empty():
		_solar_state = (
			outcome.get("state", {}) as Dictionary
		).duplicate(true)


func _region_solar_projection() -> Array:
	var rows := _solar_projection_by_region()
	var result: Array = []
	for region_id in _runtime_region_ids():
		result.append((rows.get(region_id, {}) as Dictionary).duplicate(true))
	return result


func _solar_projection_by_region() -> Dictionary:
	var source := MapGenesis.geometric_solar_by_region(
		_map_genesis_receipt,
		_current_sun_direction
	)
	var result := {}
	for region_id in _runtime_region_ids():
		var row := source.get(region_id, {}) as Dictionary
		var solar_state := str(row.get("solar_state", "dark"))
		var sunlit := solar_state == "sunlit"
		var multiplier := float(row.get(
			"efficiency_multiplier",
			2.0 if sunlit else 1.0
		))
		result[region_id] = {
			"region_id": region_id,
			"solar_state": solar_state,
			"sunlit": sunlit,
			"surface_dot_sun": float(row.get("surface_dot_sun", 0.0)),
			"facility_efficiency_multiplier": multiplier,
			"solar_efficiency_multiplier_bps": int(round(
				multiplier * 10000.0
			)),
			"unified_track_supply_affected": false,
		}
	return result


func _occupied_warehouse_solar_states() -> Dictionary:
	var result := {}
	for slot_variant in _facility_slots:
		var slot := slot_variant as Dictionary
		if (
			str(slot.get("facility_type", "")) != "warehouse"
			or str(slot.get("occupancy", "")) != "occupied"
		):
			continue
		var facility_id := str(slot.get("facility_id", ""))
		if not facility_id.is_empty():
			result[facility_id] = str(
				slot.get("solar_efficiency_state", "dark")
			)
	return result


func _canonical_player_projection(viewer_id: String) -> Dictionary:
	var track_projection := _track_core.call(
		"player_projection_v1",
		viewer_id
	) as Dictionary
	var dbg_projection := _dbg_projection(viewer_id)
	var asset_projection := ASSET_BATCH_CORE.asset_player_projection(
		_asset_state,
		viewer_id
	)
	var batch_projection := ASSET_BATCH_CORE.batch_player_projection(
		_asset_state,
		viewer_id
	)
	var facility_projection := FacilityCore.player_projection(
		_facility_state,
		viewer_id
	)
	for source in [
		track_projection,
		dbg_projection,
		asset_projection,
		batch_projection,
		facility_projection,
	]:
		if (source as Dictionary).is_empty():
			_adapter_failure_count += 1
			return {}
	_canonical_player_projection_count += 1
	return {
		"ruleset_id": V074_RULESET_ID,
		"viewer_id": viewer_id,
		"unified_track": track_projection,
		"personal_dbg": dbg_projection,
		"six_color_assets": asset_projection,
		"card_batch": batch_projection,
		"facility_contention": facility_projection,
	}


func _canonical_ai_observation(actor_id: String) -> Dictionary:
	var adapter := _ai_map_adapter(actor_id)
	if adapter == null:
		_adapter_failure_count += 1
		return {}
	var observation := adapter.call(
		"adapt",
		actor_id,
		_ai_map_receipt(),
		{
			"schema_version": 1,
			"source_revision": maxi(1, _batch_number),
			"public_facility_slots": _ai_public_facility_slots(),
		},
		{
			"schema_version": 1,
			"source_revision": maxi(1, _batch_number),
			"authorized_legal_actions": _ai_legal_actions(actor_id),
		},
		{
			"schema_version": 1,
			"source_revision": maxi(1, _batch_number),
			"viewer_id": actor_id,
			"own_cards": _ai_own_cards(actor_id),
		}
	) as Dictionary
	if observation.is_empty():
		_adapter_failure_count += 1
		return {}
	_canonical_ai_observation_count += 1
	return observation


func _public_facility_slots() -> Array:
	if _facility_state.is_empty():
		return []
	var projection := FacilityCore.public_projection(_facility_state)
	return (
		projection.get("public_facility_slots", []) as Array
	).duplicate(true)


func _player_map_receipt() -> Dictionary:
	var result := _map_genesis_receipt.duplicate(true)
	result["solar_state_by_region"] = _solar_projection_by_region()
	result["current_sun_direction"] = _current_sun_direction
	return result


func _ai_map_receipt() -> Dictionary:
	var sunlight := {}
	for region_id in _runtime_region_ids():
		sunlight[region_id] = (
			"sunlit" if bool(_region_sunlit.get(region_id, false)) else "dark"
		)
	return {
		"schema_version": 1,
		"ruleset_id": V074_RULESET_ID,
		"source_revision": maxi(1, _batch_number),
		"map_id": str(_map_genesis_receipt.get("map_id", "")),
		"map_fingerprint": str(
			_map_genesis_receipt.get("map_fingerprint", "")
		),
		"region_count": int(_map_genesis_receipt.get("region_count", 0)),
		"region_ids": _runtime_region_ids(),
		"terrain_by_region": (
			_map_genesis_receipt.get("terrain_by_region", {}) as Dictionary
		).duplicate(true),
		"adjacency_graph": (
			_map_genesis_receipt.get("adjacency_graph", {}) as Dictionary
		).duplicate(true),
		"sunlight_by_region": sunlight,
	}


func _ai_public_facility_slots() -> Array:
	var result: Array = []
	for slot_variant in _facility_slots:
		var slot := slot_variant as Dictionary
		var occupied := str(slot.get("occupancy", "")) == "occupied"
		var is_warehouse := (
			occupied
			and str(slot.get("facility_type", "")) == "warehouse"
		)
		var region_id := str(slot.get("region_id", ""))
		result.append({
			"slot_id": str(slot.get("slot_id", "")),
			"region_id": region_id,
			"facility_type": str(slot.get("facility_type", "")),
			"industry_id": str(slot.get("industry_id", "")),
			"occupied": occupied,
			"facility_id": str(slot.get("facility_id", "")) if occupied else "",
			"owner_id": str(slot.get("owner_id", "")) if occupied else "",
			"rank": int(slot.get("rank", 0)) if occupied else 0,
			"damage_points": (
				int(slot.get("damage_points", 0)) if occupied else 0
			),
			"damage_revision": (
				int(slot.get("damage_revision", 0)) if occupied else 0
			),
			"facility_generation": (
				int(slot.get("facility_generation", 0)) if occupied else 0
			),
			"slot_generation": int(slot.get("slot_generation", 0)),
			"solar_efficiency_state": (
				"sunlit"
				if bool(_region_sunlit.get(region_id, false))
				else "dark"
			),
			"public_capacity": (
				int(slot.get("capacity", 0)) if is_warehouse else 0
			),
			"public_ingress_throughput": (
				int(slot.get("ingress_throughput", 0))
				if is_warehouse
				else 0
			),
			"public_egress_throughput": (
				int(slot.get("egress_throughput", 0))
				if is_warehouse
				else 0
			),
		})
	return result


func _ai_own_cards(actor_id: String) -> Array:
	var facts := _dbg_projection(actor_id).get("facts", {}) as Dictionary
	var result: Array = []
	for card_variant in facts.get("hand", []) as Array:
		var card := card_variant as Dictionary
		result.append({
			"card_instance_id": str(card.get("instance_id", "")),
			"card_definition_id": str(card.get("definition_id", "")),
			"facility_type": str(card.get("card_type", "")),
			"industry_id": str(card.get("primary_color", "")),
			"rank": int(card.get("level", 1)),
		})
	return result


func _ai_legal_actions(actor_id: String) -> Array:
	var result: Array = []
	for option_variant in legal_card_actions(actor_id):
		var option := option_variant as Dictionary
		result.append({
			"card_instance_id": str(option.get("card_instance_id", "")),
			"card_definition_id": str(option.get(
				"card_definition_id",
				""
			)),
			"facility_type": str(option.get("facility_type", "")),
			"industry_id": str(option.get("industry_id", "")),
			"action_mode": str(option.get("facility_action_mode", "")),
			"target_slot_id": str(option.get("target_slot_id", "")),
			"region_id": str(option.get("target_region_id", "")),
		})
	return result


func _player_map_adapter(viewer_id: String) -> RefCounted:
	if not _player_map_adapters.has(viewer_id):
		_player_map_adapters[viewer_id] = PlayerMapAdapter.new()
	return _player_map_adapters.get(viewer_id) as RefCounted


func _ai_map_adapter(actor_id: String) -> RefCounted:
	if not _ai_map_adapters.has(actor_id):
		_ai_map_adapters[actor_id] = AiMapAdapter.new()
	return _ai_map_adapters.get(actor_id) as RefCounted


func _map_genesis_summary() -> Dictionary:
	return {
		"map_id": str(_map_genesis_receipt.get("map_id", "")),
		"map_seed": int(_map_genesis_receipt.get("map_seed", 0)),
		"map_profile_id": str(
			_map_genesis_receipt.get("map_profile_id", "")
		),
		"map_fingerprint": str(
			_map_genesis_receipt.get("map_fingerprint", "")
		),
		"region_count": int(_map_genesis_receipt.get("region_count", 0)),
		"region_ids": _runtime_region_ids(),
		"terrain_by_region": (
			_map_genesis_receipt.get("terrain_by_region", {}) as Dictionary
		).duplicate(true),
		"solar_state_by_region": _solar_projection_by_region(),
	}
