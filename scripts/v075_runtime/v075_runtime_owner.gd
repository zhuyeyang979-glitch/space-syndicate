extends "res://scripts/v074_runtime/v074_runtime_owner.gd"
class_name V075RuntimeOwner

const CardDefinitionsV075 := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)
const PublicActionBatchCore := preload(
	"res://scripts/v075/runtime/v075_public_action_batch_core.gd"
)
const CombatCatalog := preload(
	"res://scripts/v075/combat/v075_combat_catalog.gd"
)
const MonsterAutonomyCore := preload(
	"res://scripts/v075/monster/v075_monster_autonomy_core.gd"
)
const CombatProjectionAdapter := preload(
	"res://scripts/v075/player/v075_combat_projection_adapter.gd"
)
const CombatAIAdapter := preload(
	"res://scripts/v075/ai/v075_combat_ai_adapter.gd"
)
const FacilityDamageBridge := preload(
	"res://scripts/v075/combat/v075_facility_combat_damage_bridge.gd"
)
const FacilityDamageIntent := preload(
	"res://scripts/v075/combat/facility_combat_damage_intent_v1.gd"
)
const CombatTelemetryBridge := preload(
	"res://scripts/v075/telemetry/v075_combat_telemetry_bridge.gd"
)
const CombatPresentationConsumer := preload(
	"res://scripts/v075/presentation/v075_combat_presentation_consumer.gd"
)

const V075_RULESET_ID := "v0.7.5"
const V075_SAMPLE_MODE_ID := "NEW_V075_GAME"
const V075_CONSTITUTION_ID := "space_syndicate.v075.complete"
const V075_CARD_CAPACITY := 10
const V075_CUTOVER_DOMAIN_COUNT := 29
const V075_TRACK_ACQUISITION_POLICY_ID := (
	"v075.economy_dominant_combat_opportunity_v1"
)
const V075_COMBAT_ACQUISITION_PERIOD := 4
const V075_COMBAT_ACQUISITION_MAX_PER_PERIOD := 1
const V075_INITIAL_FACILITY_ACQUISITIONS_BEFORE_COMBAT := 0
const V075_FACILITY_ACQUISITIONS_BETWEEN_COMBAT := 3
const V075_AUTO_ACTION_LIMIT := 5
const V075_TRACK_REFILL_MODE_ID := "shared_scroll_vacancy"
const V075_TRACK_SLOW_SUSHI_MOTION := true
const V075_TRACK_IMMEDIATE_REFILL_ON_ACQUISITION := false
const COMBAT_OWNER_METHODS := [
	"initialize",
	"begin_batch",
	"set_phase",
	"prebind_monster_card_action",
	"resolve_monster_card_action",
	"build_military_lock",
	"resolve_military_action",
	"begin_public_receipt",
	"complete_public_receipt",
	"request_private_skill",
	"resolve_private_skill_safe_boundary",
	"plan_autonomy",
	"resolve_autonomy",
	"public_monsters",
	"owner_private_skill_zone",
	"projection_authority_for_viewer",
	"capture_checkpoint",
	"rollback_checkpoint",
	"debug_snapshot",
]
const COMBAT_TELEMETRY_METHODS := [
	"consume_public_receipt",
	"consume_public_cue",
	"recent_events",
	"reset_for_new_match",
	"debug_snapshot",
]
const PUBLIC_COMBAT_FIELDS := [
	"public_effect_id",
	"source_instance_id",
	"source_generation",
	"monster_family_id",
	"monster_card_mode",
	"old_rank",
	"new_rank",
	"refresh_percent",
	"hp_before",
	"hp_after",
	"armor_before",
	"armor_after",
	"preferred_industry_color",
	"movement_profile",
	"start_region_id",
	"destination_region_id",
	"region_id",
	"target_region_id",
	"target_facility_id",
	"target_monster_source_instance_id",
	"target_kind",
	"ordered_region_path",
	"distance_milli_arc",
	"damage_amount",
	"damage_before",
	"damage_after",
	"max_hp",
	"destroyed",
	"facility_type",
	"task_kind",
	"outcome",
	"status",
	"reason_code",
	"public_summary",
	"public_presentation_key",
	"effect_summary_key",
	"armor_absorbed",
	"status_changes",
	"facility_damage_receipt_ids",
	"facility_damage_state",
]

var _combat_owner: Node
var _combat_projection_adapter: RefCounted = CombatProjectionAdapter.new()
var _combat_ai_adapter: RefCounted = CombatAIAdapter.new()
var _combat_initialized := false
var _combat_autonomy_completed_batch_id := ""
var _combat_public_receipt_count := 0
var _combat_facility_damage_receipt_count := 0
var _combat_facility_damage_fizzle_count := 0
var _combat_private_skill_request_count := 0
var _combat_monster_purchase_count := 0
var _combat_military_purchase_count := 0
var _combat_first_monster_purchase_batch := -1
var _combat_first_military_purchase_batch := -1
var _combat_ai_private_skill_count := 0
var _combat_ai_military_region_count := 0
var _combat_ai_military_monster_count := 0
var _combat_ai_invalid_target_count := 0
var _processed_facility_damage_intents: Dictionary = {}
var _facility_damage_bridge_state: Dictionary = {}
var _combat_telemetry_bridge: Object = CombatTelemetryBridge.new()
var _combat_presentation_consumer: Node
var _combat_public_history: Array = []
var _combat_request_sequence := 0
var _v075_acquisition_opportunities: Dictionary = {}
var _v075_acquisition_facility_count: Dictionary = {}
var _v075_acquisition_monster_count: Dictionary = {}
var _v075_acquisition_military_count: Dictionary = {}
var _v075_acquisition_deferred_count: Dictionary = {}
var _v075_acquisition_last_domain: Dictionary = {}
var _v075_acquisition_facility_since_combat: Dictionary = {}
var _v075_acquisition_last_combat_opportunity: Dictionary = {}
var _v075_acquisition_hook_count := 0
var _v075_acquisition_rejection_count := 0
var _v075_acquisition_no_mutation_violation_count := 0
var _v075_submission_rollback_count := 0
var _v075_submission_legal_actions_cache: Dictionary = {}
var _v075_submission_card_cache: Dictionary = {}
var _v075_track_projection_cache: Dictionary = {}
var _v075_public_facility_slots_cache: Array = []


func bind_combat_owner(owner: Node) -> Dictionary:
	if not is_instance_valid(owner):
		return _reject_action("combat_runtime_owner_missing")
	for method_name in COMBAT_OWNER_METHODS:
		if not owner.has_method(method_name):
			return _reject_action(
				"combat_runtime_owner_method_missing:%s" % method_name
			)
	_combat_owner = owner
	_connect_combat_observers()
	return {
		"accepted": true,
		"reason_code": "v075_combat_runtime_owner_bound",
		"combat_runtime_owner_count": 1,
		"combat_state_writer_count": 1,
	}


func bind_combat_telemetry_service(service: Object) -> Dictionary:
	if not is_instance_valid(service):
		return _reject_action("combat_telemetry_service_missing")
	if is_instance_valid(_combat_presentation_consumer):
		return _reject_action("combat_observers_already_connected")
	for method_name in COMBAT_TELEMETRY_METHODS:
		if not service.has_method(method_name):
			return _reject_action(
				"combat_telemetry_method_missing:%s" % method_name
			)
	_combat_telemetry_bridge = service
	return {
		"accepted": true,
		"reason_code": "v075_combat_telemetry_service_bound",
		"combat_telemetry_gameplay_owner_count": 0,
		"combat_telemetry_rng_owner_count": 0,
		"combat_telemetry_world_mutation_count": 0,
	}


func start_new_game(
	player_count: int = 4,
	seed_value: int = DEFAULT_MATCH_SEED,
	accelerated: bool = false,
	automate_local_human: bool = false,
	map_request: Dictionary = {}
) -> Dictionary:
	if not is_instance_valid(_combat_owner):
		return _reject("combat_runtime_owner_not_bound")
	var started := super.start_new_game(
		player_count,
		seed_value,
		accelerated,
		automate_local_human,
		map_request
	)
	if not bool(started.get("accepted", false)):
		return started
	var initialized := _combat_owner.call(
		"initialize",
		_player_ids,
		_map_genesis_receipt,
		{}
	) as Dictionary
	if not bool(initialized.get("accepted", false)):
		return _fail("combat_runtime_initialization_failed", initialized)
	_combat_initialized = true
	var batch_started := _begin_combat_batch()
	if not bool(batch_started.get("accepted", false)):
		return _fail("combat_batch_initialization_failed", batch_started)
	_emit_local_state()
	var result := started.duplicate(true)
	result["reason_code"] = "v075_new_game_started"
	result["ruleset_id"] = V075_RULESET_ID
	result["constitution_id"] = V075_CONSTITUTION_ID
	result["combat_runtime_owner_count"] = 1
	result["combat_state_writer_count"] = 1
	result["combat_cutover_domain_count"] = V075_CUTOVER_DOMAIN_COUNT
	return result


func lock_player_submission(actor_id: String) -> Dictionary:
	if not _combat_initialized or not is_instance_valid(_combat_owner):
		return super.lock_player_submission(actor_id)
	var runtime_checkpoint := _v075_capture_submission_checkpoint(actor_id)
	if runtime_checkpoint.is_empty():
		return _reject_action("submission_checkpoint_unavailable")
	var checkpoint := _combat_owner.call(
		"capture_checkpoint",
		"checkpoint.submission.%s.%s" % [_batch_id(), actor_id]
	) as Dictionary
	if checkpoint.is_empty():
		return _reject_action("combat_submission_checkpoint_unavailable")
	var result := super.lock_player_submission(actor_id)
	if not bool(result.get("accepted", false)):
		var runtime_rollback := _v075_restore_submission_checkpoint(
			runtime_checkpoint
		)
		var combat_rollback := _combat_owner.call(
			"rollback_checkpoint",
			checkpoint
		) as Dictionary
		if (
			not bool(runtime_rollback.get("accepted", false))
			or not _rollback_result_accepted(combat_rollback)
		):
			return _fail("submission_rollback_failed", {
				"runtime_rollback": runtime_rollback,
				"combat_rollback": combat_rollback,
			})
		_v075_submission_rollback_count += 1
	_clear_v075_submission_caches()
	_clear_v075_track_projection_cache()
	return result


func _v075_capture_submission_checkpoint(actor_id: String) -> Dictionary:
	var dbg_checkpoint := _v075_capture_dbg_checkpoint(actor_id)
	if dbg_checkpoint.is_empty():
		return {}
	return {
		"accepted": true,
		"phase": _phase,
		"runtime_error_count": _runtime_error_count,
		"dbg_checkpoints": [dbg_checkpoint],
	}


func _v075_restore_submission_checkpoint(checkpoint: Dictionary) -> Dictionary:
	var rollback_ok := true
	var rollback_results: Array = []
	var rows := checkpoint.get("dbg_checkpoints", []) as Array
	for row_index in range(rows.size() - 1, -1, -1):
		var row_variant: Variant = rows[row_index]
		var row := row_variant as Dictionary
		var owner := row.get("owner") as Object
		var method_name := str(row.get("rollback_method", ""))
		if (
			owner != null
			and is_instance_valid(owner)
			and not method_name.is_empty()
			and owner.has_method(method_name)
		):
			var result := owner.call(
				method_name,
				row.get("checkpoint", {}) as Dictionary
			) as Dictionary
			rollback_results.append(result.duplicate(true))
			if not _rollback_result_accepted(result):
				rollback_ok = false
		else:
			rollback_ok = false
	_phase = str(checkpoint.get("phase", _phase))
	_runtime_error_count = int(
		checkpoint.get("runtime_error_count", _runtime_error_count)
	)
	return {
		"accepted": rollback_ok,
		"reason_code": "submission_checkpoint_restored"
			if rollback_ok
			else "submission_checkpoint_restore_failed",
		"rollback_results": rollback_results,
	}


func _v075_capture_dbg_checkpoint(owner_id: String) -> Dictionary:
	var owner_variant: Variant = _dbg_by_player.get(owner_id)
	var owner := owner_variant as Object
	if owner == null or not is_instance_valid(owner):
		return {}
	var checkpoint: Variant = {}
	var rollback_method := ""
	if owner.has_method("capture_checkpoint_v1") and owner.has_method(
		"rollback_v1"
	):
		checkpoint = owner.call("capture_checkpoint_v1")
		rollback_method = "rollback_v1"
	elif owner.has_method("capture_checkpoint") and owner.has_method(
		"rollback"
	):
		checkpoint = owner.call("capture_checkpoint")
		rollback_method = "rollback"
	if not checkpoint is Dictionary or (checkpoint as Dictionary).is_empty():
		return {}
	return {
		"owner_id": owner_id,
		"owner": owner,
		"checkpoint": (checkpoint as Dictionary).duplicate(true),
		"rollback_method": rollback_method,
	}


func _rollback_result_accepted(result: Dictionary) -> bool:
	return bool(result.get("accepted", result.get("rolled_back", false)))


func acquire_track_item(
	actor_id: String,
	source_instance_id: String
) -> Dictionary:
	var domain := ""
	if _track_core != null:
		var projection := _v075_track_projection(actor_id)
		var private_facts := (
			projection.get("viewer_private_facts", {}) as Dictionary
		)
		for item_variant in private_facts.get("own_segment_items", []) as Array:
			var item := item_variant as Dictionary
			if str(item.get("instance_id", "")) != source_instance_id:
				continue
			var definition := CardDefinitionsV075.definition(
				str(item.get("card_definition_id", ""))
			)
			domain = CardDefinitionsV075.card_domain(
				str(definition.get("card_type", ""))
			)
			break
	var receipt := super.acquire_track_item(actor_id, source_instance_id)
	_clear_v075_track_projection_cache()
	if bool(receipt.get("accepted", false)):
		_clear_v075_submission_caches()
		if domain == "monster":
			_combat_monster_purchase_count += 1
			if _combat_first_monster_purchase_batch < 0:
				_combat_first_monster_purchase_batch = _batch_number
		elif domain == "military":
			_combat_military_purchase_count += 1
			if _combat_first_military_purchase_batch < 0:
				_combat_first_military_purchase_batch = _batch_number
		if domain in ["monster", "military"]:
			receipt["combat_card_domain"] = domain
			receipt["event_kind"] = "%s_card_purchased" % domain
	return receipt


func _auto_acquire_track_item(actor_id: String) -> Dictionary:
	var facts := _v075_track_acquisition_facts(actor_id)
	if facts.is_empty():
		return _v075_acquisition_noop(
			actor_id,
			"v075_track_acquisition_context_unavailable"
		)
	var baseline := _combat_ai_adapter.call(
		"choose_track_acquisition",
		facts,
		{"phase": _phase}
	) as Dictionary
	_v075_acquisition_hook_count += 1
	var baseline_reason := str(baseline.get("reason_code", ""))
	if not bool(baseline.get("accepted", false)):
		if baseline_reason == "no_legal_track_acquisition":
			return _v075_acquisition_noop(
				actor_id,
				"no_claimable_track_item"
			)
		_v075_acquisition_rejection_count += 1
		return _reject_action(
			"v075_track_acquisition_policy_rejected:%s" % baseline_reason
		)
	var baseline_action := (
		baseline.get("action", {}) as Dictionary
	).duplicate(true)
	if baseline_action.is_empty():
		return _v075_acquisition_noop(
			actor_id,
			"v075_track_acquisition_action_missing"
		)
	var audit := (
		baseline.get("acquisition_audit", {}) as Dictionary
	).duplicate(true)
	var opportunity := int(
		_v075_acquisition_opportunities.get(actor_id, 0)
	) + 1
	_v075_acquisition_opportunities[actor_id] = opportunity
	var warehouse_action := _v075_choose_warehouse_action(
		actor_id,
		facts
	)
	if (
		str(baseline_action.get("card_domain", "")) == "facility"
		and not warehouse_action.is_empty()
		and not _v075_player_has_warehouse(actor_id)
	):
		baseline_action = warehouse_action
	var facility_available := int(
		audit.get("facility_candidate_count", 0)
	) > 0
	var combat_available := int(
		audit.get("monster_candidate_count", 0)
	) > 0 or int(
		audit.get("military_candidate_count", 0)
	) > 0
	var selected := baseline_action
	var selection_reason := "facility_economy_dominant"
	if combat_available and _v075_combat_slot_open(
		actor_id,
		facility_available,
		facts
	):
		var combat_action := _v075_choose_combat_track_action(
			actor_id,
			facts
		)
		if not combat_action.is_empty():
			selected = combat_action
			selection_reason = "bounded_combat_opportunity"
		elif not facility_available:
			_v075_acquisition_deferred_count[actor_id] = int(
				_v075_acquisition_deferred_count.get(actor_id, 0)
			) + 1
			return _v075_acquisition_noop(
				actor_id,
				"v075_combat_candidate_probe_empty"
			)
	elif not facility_available and combat_available:
		_v075_acquisition_deferred_count[actor_id] = int(
			_v075_acquisition_deferred_count.get(actor_id, 0)
		) + 1
		return _v075_acquisition_noop(
			actor_id,
			"v075_combat_acquisition_rate_limited"
		)
	var source_instance_id := str(
		selected.get("source_instance_id", selected.get(
			"card_instance_id",
			""
		))
	)
	if source_instance_id.is_empty():
		_v075_acquisition_rejection_count += 1
		return _reject_action("v075_track_acquisition_source_missing")
	var before := _v075_track_supply_probe()
	if before.is_empty():
		_v075_acquisition_rejection_count += 1
		return _reject_action("v075_track_supply_probe_unavailable")
	var receipt := acquire_track_item(actor_id, source_instance_id)
	var after := _v075_track_supply_probe()
	if after.is_empty():
		_v075_acquisition_no_mutation_violation_count += 1
		return _fail("v075_track_supply_probe_lost_after_acquisition", {})
	var delta := _v075_track_supply_delta(before, after)
	if not _v075_track_delta_is_safe(delta):
		_v075_acquisition_no_mutation_violation_count += 1
		return _fail("v075_track_acquisition_supply_mutation", delta)
	receipt["v075_acquisition_policy_id"] = (
		V075_TRACK_ACQUISITION_POLICY_ID
	)
	receipt["v075_acquisition_opportunity"] = opportunity
	receipt["v075_acquisition_selection_reason"] = selection_reason
	receipt["v075_acquisition_domain"] = str(
		selected.get("card_domain", "")
	)
	receipt["v075_track_delta"] = delta.duplicate(true)
	receipt["track_refill_mode_id"] = V075_TRACK_REFILL_MODE_ID
	receipt["track_slow_sushi_motion"] = V075_TRACK_SLOW_SUSHI_MOTION
	receipt["immediate_refill_on_acquisition"] = (
		V075_TRACK_IMMEDIATE_REFILL_ON_ACQUISITION
	)
	if bool(receipt.get("accepted", false)):
		var domain := str(selected.get("card_domain", ""))
		_v075_acquisition_last_domain[actor_id] = domain
		if domain == "facility":
			_v075_acquisition_facility_count[actor_id] = int(
				_v075_acquisition_facility_count.get(actor_id, 0)
			) + 1
			_v075_acquisition_facility_since_combat[actor_id] = int(
				_v075_acquisition_facility_since_combat.get(actor_id, 0)
			) + 1
		elif domain == "monster":
			_v075_acquisition_monster_count[actor_id] = int(
				_v075_acquisition_monster_count.get(actor_id, 0)
			) + 1
			_v075_acquisition_facility_since_combat[actor_id] = 0
			_v075_acquisition_last_combat_opportunity[actor_id] = (
				opportunity
			)
		elif domain == "military":
			_v075_acquisition_military_count[actor_id] = int(
				_v075_acquisition_military_count.get(actor_id, 0)
			) + 1
			_v075_acquisition_facility_since_combat[actor_id] = 0
			_v075_acquisition_last_combat_opportunity[actor_id] = (
				opportunity
			)
	else:
		_v075_acquisition_rejection_count += 1
	return receipt


func _v075_track_acquisition_facts(actor_id: String) -> Dictionary:
	if (
		_track_core == null
		or _asset_state.is_empty()
		or not _player_ids.has(actor_id)
	):
		return {}
	var projection := _v075_track_projection(actor_id)
	var private_facts := (
		projection.get("viewer_private_facts", {}) as Dictionary
	)
	var own_items := private_facts.get("own_segment_items", []) as Array
	var asset_observation := ASSET_BATCH_CORE.asset_ai_observation(
		_asset_state,
		actor_id
	) as Dictionary
	var available := (
		asset_observation.get("own_available_assets", {}) as Dictionary
	)
	if own_items.is_empty() or not _v075_complete_asset_projection(available):
		return {}
	return {
		"viewer_player_id": actor_id,
		"own_segment_items": own_items.duplicate(true),
		"available_unreserved_assets": available.duplicate(true),
	}


func _v075_complete_asset_projection(available: Dictionary) -> bool:
	for color_id in COLORS:
		if not available.has(color_id):
			return false
		var value: Variant = available.get(color_id)
		if typeof(value) != TYPE_INT or int(value) < 0:
			return false
	return true


func _v075_combat_slot_open(
	actor_id: String,
	facility_available: bool,
	facts: Dictionary = {}
) -> bool:
	if (
		not facts.is_empty()
		and _v075_pending_monster_merge_candidate(actor_id, facts)
	):
		return true
	var opportunity := int(
		_v075_acquisition_opportunities.get(actor_id, 0)
	)
	var last_combat_opportunity := int(
		_v075_acquisition_last_combat_opportunity.get(actor_id, -1)
	)
	if (
		last_combat_opportunity >= 0
		and opportunity - last_combat_opportunity
			< V075_COMBAT_ACQUISITION_PERIOD
	):
		return false
	if not facility_available:
		return true
	var facility_count := int(
		_v075_acquisition_facility_count.get(actor_id, 0)
	)
	var combat_count := (
		int(_v075_acquisition_monster_count.get(actor_id, 0))
		+ int(_v075_acquisition_military_count.get(actor_id, 0))
	)
	if combat_count == 0:
		return facility_count >= (
			V075_INITIAL_FACILITY_ACQUISITIONS_BEFORE_COMBAT
		)
	return int(
		_v075_acquisition_facility_since_combat.get(actor_id, 0)
	) >= V075_FACILITY_ACQUISITIONS_BETWEEN_COMBAT


func _v075_pending_monster_merge_candidate(
	actor_id: String,
	facts: Dictionary
) -> bool:
	var active_families: Array[String] = []
	for source_variant in _v075_public_monsters():
		var source := source_variant as Dictionary
		if (
			str(source.get("owner_player_id", "")) == actor_id
			and str(source.get("status", "")) == "active"
			and int(source.get("rank", 0)) == 1
		):
			var family_id := str(source.get("monster_family_id", ""))
			if not family_id.is_empty() and family_id not in active_families:
				active_families.append(family_id)
	if active_families.is_empty():
		return false
	var known_merge_families := _v075_known_monster_merge_families(
		actor_id,
		active_families
	)
	if known_merge_families.is_empty():
		return false
	for item_variant in facts.get("own_segment_items", []) as Array:
		var item := item_variant as Dictionary
		var definition := CardDefinitionsV075.definition(str(item.get(
			"card_definition_id",
			""
		)))
		if (
			CardDefinitionsV075.card_domain(str(definition.get("card_type", "")))
			== "monster"
			and active_families.has(
				CardDefinitionsV075.monster_family_id_from_card_type(
					str(definition.get("card_type", ""))
				)
			)
			and known_merge_families.has(str(definition.get(
				"merge_family_id",
				""
			)))
		):
			return true
	return false


func _v075_choose_combat_track_action(
	actor_id: String,
	facts: Dictionary
) -> Dictionary:
	var options: Dictionary = {}
	var monster_merge_progress_action: Dictionary = {}
	for domain in ["monster", "military"]:
		var filtered := _v075_filter_track_facts_by_domain(
			facts,
			domain
		)
		if filtered.is_empty():
			continue
		var result := _combat_ai_adapter.call(
			"choose_track_acquisition",
			filtered,
			{"phase": _phase}
		) as Dictionary
		if not bool(result.get("accepted", false)):
			continue
		var action := result.get("action", {}) as Dictionary
		if action.is_empty():
			continue
		if domain == "monster":
			var matching_family_action := _v075_choose_matching_monster_action(
				actor_id,
				filtered
			)
			if not matching_family_action.is_empty():
				action = matching_family_action
				if _v075_monster_action_advances_known_merge(actor_id, action):
					monster_merge_progress_action = action.duplicate(true)
		options[domain] = action.duplicate(true)
	if options.is_empty():
		return {}
	# A visible exact merge-family duplicate is the only natural path from the
	# L1-only supply track to a higher-rank monster card. It is owner-private,
	# deterministic information from the player's own hand/discard, so prefer
	# it before alternating between otherwise equivalent combat domains.
	if not monster_merge_progress_action.is_empty():
		return monster_merge_progress_action
	if options.size() == 1:
		return (options.values()[0] as Dictionary).duplicate(true)
	if (
		_v075_actor_prefers_monster_upgrade(actor_id)
		and _v075_has_active_monster(actor_id)
		and options.has("monster")
	):
		# Keep the upgrade-oriented owner on the normal combat track until a
		# second same-family card can reach the personal hand and maintenance.
		# This changes only deterministic choice ordering; acquisition, DBG,
		# asset, and track authorities remain the same.
		return (options.get("monster", {}) as Dictionary).duplicate(true)
	var monster_count := int(
		_v075_acquisition_monster_count.get(actor_id, 0)
	)
	var military_count := int(
		_v075_acquisition_military_count.get(actor_id, 0)
	)
	var last_domain := str(
		_v075_acquisition_last_domain.get(actor_id, "")
	)
	var preferred_domain := ""
	if monster_count < military_count:
		preferred_domain = "monster"
	elif military_count < monster_count:
		preferred_domain = "military"
	elif last_domain == "monster":
		preferred_domain = "military"
	elif last_domain == "military":
		preferred_domain = "monster"
	if not preferred_domain.is_empty() and options.has(preferred_domain):
		return (options.get(preferred_domain, {}) as Dictionary).duplicate(
			true
		)
	var best: Dictionary = {}
	for action_variant in options.values():
		var action := action_variant as Dictionary
		if best.is_empty() or _v075_action_precedes(action, best):
			best = action.duplicate(true)
	return best


func _v075_has_active_monster(actor_id: String) -> bool:
	for source_variant in _v075_public_monsters():
		var source := source_variant as Dictionary
		if (
			str(source.get("owner_player_id", "")) == actor_id
			and str(source.get("status", "")) in ["active", "downed"]
		):
			return true
	return false


func _v075_filter_track_facts_by_domain(
	facts: Dictionary,
	domain: String
) -> Dictionary:
	var filtered := facts.duplicate(true)
	var items: Array = []
	for item_variant in facts.get("own_segment_items", []) as Array:
		var item := item_variant as Dictionary
		var definition := CardDefinitionsV075.definition(
			str(item.get("card_definition_id", ""))
		)
		var item_domain := CardDefinitionsV075.card_domain(
			str(definition.get("card_type", ""))
		)
		if item_domain == domain:
			items.append(item.duplicate(true))
	if items.is_empty():
		return {}
	filtered["own_segment_items"] = items
	return filtered


func _v075_choose_matching_monster_action(
	actor_id: String,
	facts: Dictionary
) -> Dictionary:
	if not _v075_actor_prefers_monster_upgrade(actor_id):
		return {}
	var active_families: Array[String] = []
	for source_variant in _v075_public_monsters():
		var source := source_variant as Dictionary
		if (
			str(source.get("owner_player_id", "")) == actor_id
			and str(source.get("status", "")) in ["active", "downed"]
		):
			var family_id := str(source.get("monster_family_id", ""))
			if not family_id.is_empty() and family_id not in active_families:
				active_families.append(family_id)
	active_families.sort()
	var known_merge_families := _v075_known_monster_merge_families(
		actor_id,
		active_families
	)
	for family_id in active_families:
		var exact_merge_items: Array = []
		var items: Array = []
		for item_variant in facts.get("own_segment_items", []) as Array:
			var item := item_variant as Dictionary
			var definition := CardDefinitionsV075.definition(
				str(item.get("card_definition_id", ""))
			)
			var card_type := str(definition.get("card_type", ""))
			if (
				CardDefinitionsV075.card_domain(card_type) == "monster"
				and CardDefinitionsV075.monster_family_id_from_card_type(
					card_type
				) == family_id
			):
				items.append(item.duplicate(true))
				if known_merge_families.has(str(definition.get(
					"merge_family_id",
					""
				))):
					exact_merge_items.append(item.duplicate(true))
		if items.is_empty():
			continue
		var filtered := facts.duplicate(true)
		if not exact_merge_items.is_empty():
			filtered["own_segment_items"] = exact_merge_items
		else:
			filtered["own_segment_items"] = items
		var chosen := _combat_ai_adapter.call(
			"choose_track_acquisition",
			filtered,
			{"phase": _phase}
		) as Dictionary
		if bool(chosen.get("accepted", false)):
			return (chosen.get("action", {}) as Dictionary).duplicate(true)
	return {}


func _v075_known_monster_merge_families(
	actor_id: String,
	active_families: Array[String]
) -> Dictionary:
	var result := {}
	var facts := _dbg_projection(actor_id).get("facts", {}) as Dictionary
	for zone_name in ["hand", "discard"]:
		for card_variant in facts.get(zone_name, []) as Array:
			var card := card_variant as Dictionary
			var card_type := str(card.get("card_type", ""))
			if CardDefinitionsV075.card_domain(card_type) != "monster":
				continue
			var family_id := (
				CardDefinitionsV075.monster_family_id_from_card_type(card_type)
			)
			if family_id not in active_families:
				continue
			var merge_family_id := str(card.get("merge_family_id", ""))
			if not merge_family_id.is_empty():
				result[merge_family_id] = true
	return result


func _v075_monster_action_advances_known_merge(
	actor_id: String,
	action: Dictionary
) -> bool:
	var definition := CardDefinitionsV075.definition(
		str(action.get("card_definition_id", ""))
	)
	if CardDefinitionsV075.card_domain(str(definition.get(
		"card_type",
		""
	))) != "monster":
		return false
	var family_id := CardDefinitionsV075.monster_family_id_from_card_type(
		str(definition.get("card_type", ""))
	)
	return _v075_known_monster_merge_families(
		actor_id,
		[family_id]
	).has(str(definition.get("merge_family_id", "")))


func _v075_choose_warehouse_action(
	actor_id: String,
	facts: Dictionary
) -> Dictionary:
	var filtered := facts.duplicate(true)
	var items: Array = []
	for item_variant in facts.get("own_segment_items", []) as Array:
		var item := item_variant as Dictionary
		var definition := CardDefinitionsV075.definition(
			str(item.get("card_definition_id", ""))
		)
		if str(definition.get("card_type", "")) == "warehouse":
			items.append(item.duplicate(true))
	if items.is_empty():
		return {}
	filtered["own_segment_items"] = items
	var chosen := _combat_ai_adapter.call(
		"choose_track_acquisition",
		filtered,
		{"phase": _phase, "actor_id": actor_id}
	) as Dictionary
	if not bool(chosen.get("accepted", false)):
		return {}
	return (chosen.get("action", {}) as Dictionary).duplicate(true)


func _v075_player_has_warehouse(actor_id: String) -> bool:
	for facility_variant in _public_occupied_facilities():
		var facility := facility_variant as Dictionary
		if (
			_facility_owner_id(facility) == actor_id
			and str(facility.get("facility_type", "")) == "warehouse"
		):
			return true
	return false


func _v075_action_precedes(
	left: Dictionary,
	right: Dictionary
) -> bool:
	var left_slot := int(left.get("local_slot_index", 0))
	var right_slot := int(right.get("local_slot_index", 0))
	if left_slot != right_slot:
		return left_slot < right_slot
	var left_score := int(left.get("score", 0))
	var right_score := int(right.get("score", 0))
	if left_score != right_score:
		return left_score > right_score
	return str(left.get("stable_action_key", "")) < str(
		right.get("stable_action_key", "")
	)


func _v075_acquisition_noop(
	actor_id: String,
	reason_code: String
) -> Dictionary:
	return {
		"accepted": true,
		"reason_code": reason_code,
		"actor_id": actor_id,
		"v075_acquisition_policy_id": (
			V075_TRACK_ACQUISITION_POLICY_ID
		),
		"track_refill_mode_id": V075_TRACK_REFILL_MODE_ID,
		"track_slow_sushi_motion": V075_TRACK_SLOW_SUSHI_MOTION,
		"immediate_refill_on_acquisition": (
			V075_TRACK_IMMEDIATE_REFILL_ON_ACQUISITION
		),
		"replacement_count": 0,
		"supply_cursor_delta_on_acquisition": 0,
		"supply_instance_sequence_delta_on_acquisition": 0,
		"supply_rng_draw_delta_on_acquisition": 0,
	}


func _v075_track_supply_probe() -> Dictionary:
	if _track_core == null:
		return {}
	if not _track_core.has_method("debug_snapshot_v074"):
		return {}
	var debug := _track_core.call("debug_snapshot_v074") as Dictionary
	if (
		str(debug.get("schema", "")) != "V074SharedSushiTrackDebugV1"
		or str(debug.get("refill_mode_id", ""))
			!= V075_TRACK_REFILL_MODE_ID
	):
		return {}
	for field_name in [
		"track_revision",
		"item_count",
		"vacancy_count",
		"next_instance_sequence",
		"supply_cursor_total",
		"supply_rng_draw_total",
		"immediate_authoritative_refill_count",
	]:
		if (
			not debug.has(field_name)
			or typeof(debug.get(field_name)) != TYPE_INT
			or int(debug.get(field_name, -1)) < 0
		):
			return {}
	return {
		"track_revision": int(debug.get("track_revision", 0)),
		"item_count": int(debug.get("item_count", 0)),
		"vacancy_count": int(debug.get("vacancy_count", 0)),
		"next_instance_sequence": int(
			debug.get("next_instance_sequence", 0)
		),
		"supply_cursor_total": int(debug.get("supply_cursor_total", 0)),
		"supply_rng_draw_total": int(
			debug.get("supply_rng_draw_total", 0)
		),
		"immediate_authoritative_refill_count": int(
			debug.get("immediate_authoritative_refill_count", 0)
		),
	}


func _v075_track_supply_delta(
	before: Dictionary,
	after: Dictionary
) -> Dictionary:
	return {
		"track_revision_delta": int(after.get("track_revision", 0))
			- int(before.get("track_revision", 0)),
		"track_item_count_delta": int(after.get("item_count", 0))
			- int(before.get("item_count", 0)),
		"vacancy_delta": int(after.get("vacancy_count", 0))
			- int(before.get("vacancy_count", 0)),
		"supply_cursor_delta_on_acquisition": int(
			after.get("supply_cursor_total", 0)
		) - int(before.get("supply_cursor_total", 0)),
		"supply_instance_sequence_delta_on_acquisition": int(
			after.get("next_instance_sequence", 0)
		) - int(before.get("next_instance_sequence", 0)),
		"supply_rng_draw_delta_on_acquisition": int(
			after.get("supply_rng_draw_total", 0)
		) - int(before.get("supply_rng_draw_total", 0)),
		"immediate_authoritative_refill_delta": int(
			after.get("immediate_authoritative_refill_count", 0)
		) - int(before.get("immediate_authoritative_refill_count", 0)),
		"replacement_count": 0,
	}


func _v075_track_delta_is_safe(delta: Dictionary) -> bool:
	return (
		int(delta.get("track_item_count_delta", 0)) in [0, -1]
		and int(delta.get("vacancy_delta", 0)) in [0, 1]
		and int(delta.get("supply_cursor_delta_on_acquisition", 0)) == 0
		and int(delta.get(
			"supply_instance_sequence_delta_on_acquisition",
			0
		)) == 0
		and int(delta.get("supply_rng_draw_delta_on_acquisition", 0)) == 0
		and int(delta.get("immediate_authoritative_refill_delta", 0)) == 0
	)


func legal_card_actions(actor_id: String) -> Array:
	if _phase == "submission" and _v075_submission_legal_actions_cache.has(
		actor_id
	):
		return (
			_v075_submission_legal_actions_cache.get(actor_id, []) as Array
		).duplicate(true)
	var result := super.legal_card_actions(actor_id)
	if (
		not _combat_initialized
		or not _player_ids.has(actor_id)
		or _phase != "submission"
	):
		return result
	var facts := _dbg_projection(actor_id).get("facts", {}) as Dictionary
	for card_variant in facts.get("hand", []) as Array:
		var card := card_variant as Dictionary
		var domain := CardDefinitionsV075.card_domain(
			str(card.get("card_type", ""))
		)
		if domain == "monster":
			result.append_array(_monster_card_options(actor_id, card))
		elif domain == "military":
			result.append_array(_military_card_options(actor_id, card))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("option_id", "")) < str(
			right.get("option_id", "")
		)
	)
	if _phase == "submission":
		_v075_submission_legal_actions_cache[actor_id] = result.duplicate(true)
	return result


func _auto_legal_actions(actor_id: String) -> Array:
	# The parent AI DTO is presentation-shaped and scans this projection again.
	# One authoritative V075 legal query is enough for both facility and combat
	# choices; keep the actor-local fields intact and never expose rival data.
	var all_options := legal_card_actions(actor_id)
	var result: Array = []
	var known: Dictionary = {}
	for option_variant in all_options:
		if not (option_variant is Dictionary):
			continue
		var option := option_variant as Dictionary
		var domain := str(option.get("action_domain", "facility"))
		if domain not in ["monster", "military"]:
			result.append(option.duplicate(true))
			continue
		var identity := _combat_option_identity(option)
		if not known.has(identity):
			result.append(option.duplicate(true))
			known[identity] = true
	return result


func _combat_option_identity(option: Dictionary) -> String:
	return "%s|%s|%s|%s" % [
		str(option.get("action_domain", "")),
		str(option.get("card_instance_id", "")),
		str(option.get("target_slot_id", "")),
		str(option.get("monster_card_mode", option.get("task_kind", ""))),
	]


func _card_in_hand(actor_id: String, card_instance_id: String) -> Dictionary:
	if _phase == "submission":
		var actor_cache := _v075_submission_card_cache.get(
			actor_id,
			{}
		) as Dictionary
		if actor_cache.has(card_instance_id):
			return (
				actor_cache.get(card_instance_id, {}) as Dictionary
			).duplicate(true)
	var result := super._card_in_hand(actor_id, card_instance_id)
	if _phase == "submission":
		var actor_cache := _v075_submission_card_cache.get(
			actor_id,
			{}
		) as Dictionary
		actor_cache[card_instance_id] = result.duplicate(true)
		_v075_submission_card_cache[actor_id] = actor_cache
	return result


func queue_card_action(
	actor_id: String,
	card_instance_id: String,
	target_slot_id: String,
	target_binding: Dictionary = {}
) -> Dictionary:
	var card := _card_in_hand(actor_id, card_instance_id)
	var domain := CardDefinitionsV075.card_domain(
		str(card.get("card_type", ""))
	)
	if domain not in ["monster", "military"]:
		var facility_receipt := super.queue_card_action(
			actor_id,
			card_instance_id,
			target_slot_id,
			target_binding
		)
		if bool(facility_receipt.get("accepted", false)):
			_clear_v075_submission_caches()
		return facility_receipt
	if _phase != "submission":
		return _reject_action("submission_window_not_open")
	if not _player_ids.has(actor_id) or bool(
		_locked_by_player.get(actor_id, false)
	):
		return _reject_action("actor_not_available")
	var queue := _queued_by_player.get(actor_id, []) as Array
	if queue.size() >= MAX_ACTIONS_PER_PLAYER:
		return _reject_action("local_queue_full")
	for row_variant in queue:
		if str((row_variant as Dictionary).get(
			"card_instance_id",
			""
		)) == card_instance_id:
			return _reject_action("card_already_queued")
	var selected := _combat_option_by_identity(
		actor_id,
		card_instance_id,
		target_slot_id,
		target_binding
	)
	if selected.is_empty():
		return _reject_action("combat_target_binding_invalid_or_stale")
	var binding := {
		"actor_id": actor_id,
		"action_id": "action.%s.%s.%02d" % [
			_batch_id(),
			actor_id,
			queue.size(),
		],
		"card_instance_id": card_instance_id,
		"card_definition_id": str(card.get("definition_id", "")),
		"target_slot_id": target_slot_id,
		"target_region_id": str(selected.get("target_region_id", "")),
		"target_source_instance_id": str(
			selected.get("target_source_instance_id", "")
		),
		"target_monster_source_instance_id": str(
			selected.get("target_monster_source_instance_id", "")
		),
		"monster_card_mode": str(selected.get("monster_card_mode", "")),
		"task_kind": str(selected.get("task_kind", "")),
		"action_domain": domain,
		"target_bound": true,
	}
	queue.append(binding)
	_queued_by_player[actor_id] = queue
	_clear_v075_submission_caches()
	var receipt := {
		"accepted": true,
		"reason_code": "v075_combat_card_action_prebound",
		"actor_id": actor_id,
		"action_domain": domain,
		"binding": binding.duplicate(true),
		"queue_size": queue.size(),
	}
	action_queued.emit(receipt)
	_emit_local_state()
	return receipt


func queue_monster_card_action(
	actor_id: String,
	card_instance_id: String,
	monster_card_mode: String,
	target_region_id: String = "",
	target_source_instance_id: String = ""
) -> Dictionary:
	for option_variant in legal_card_actions(actor_id):
		var option := option_variant as Dictionary
		if (
			str(option.get("action_domain", "")) == "monster"
			and str(option.get("card_instance_id", "")) == card_instance_id
			and str(option.get("monster_card_mode", "")) == monster_card_mode
			and (
				target_region_id.is_empty()
				or str(option.get("target_region_id", "")) == target_region_id
			)
			and (
				target_source_instance_id.is_empty()
				or str(option.get("target_source_instance_id", ""))
				== target_source_instance_id
			)
		):
			return queue_card_action(
				actor_id,
				card_instance_id,
				str(option.get("target_slot_id", "")),
				option
			)
	return _reject_action("monster_card_mode_has_no_legal_prebound_target")


func reorder_queued_action(
	actor_id: String,
	from_index: int,
	to_index: int
) -> Dictionary:
	var receipt := super.reorder_queued_action(
		actor_id,
		from_index,
		to_index
	)
	if bool(receipt.get("accepted", false)):
		_clear_v075_submission_caches()
	return receipt


func remove_queued_action(actor_id: String, action_id: String) -> Dictionary:
	var receipt := super.remove_queued_action(actor_id, action_id)
	if bool(receipt.get("accepted", false)):
		_clear_v075_submission_caches()
	return receipt


func queue_military_card_action(
	actor_id: String,
	card_instance_id: String,
	task_kind: String,
	target_region_id: String = "",
	target_monster_source_instance_id: String = ""
) -> Dictionary:
	for option_variant in legal_card_actions(actor_id):
		var option := option_variant as Dictionary
		if (
			str(option.get("action_domain", "")) == "military"
			and str(option.get("card_instance_id", "")) == card_instance_id
			and str(option.get("task_kind", "")) == task_kind
			and (
				target_region_id.is_empty()
				or str(option.get("target_region_id", "")) == target_region_id
			)
			and (
				target_monster_source_instance_id.is_empty()
				or str(option.get(
					"target_monster_source_instance_id",
					""
				)) == target_monster_source_instance_id
			)
		):
			return queue_card_action(
				actor_id,
				card_instance_id,
				str(option.get("target_slot_id", "")),
				option
			)
	return _reject_action("military_task_has_no_legal_prebound_target")


func queue_selected_military_mission(
	actor_id: String,
	task_kind: String,
	parameters: Dictionary = {}
) -> Dictionary:
	var card_instance_id := str(parameters.get("card_instance_id", ""))
	if card_instance_id.is_empty():
		return _reject_action("military_card_option_identity_missing")
	if str(parameters.get("option_id", "")).is_empty():
		return _reject_action("military_option_id_missing")
	if str(parameters.get("target_slot_id", "")).is_empty():
		return _reject_action("military_target_slot_missing")
	var option_id := str(parameters.get("option_id", ""))
	for option_variant in legal_card_actions(actor_id):
		var option := option_variant as Dictionary
		if (
			str(option.get("action_domain", "")) == "military"
			and str(option.get("option_id", "")) == option_id
			and str(option.get("card_instance_id", "")) == card_instance_id
			and str(option.get("task_kind", "")) == task_kind
			and str(option.get("target_slot_id", "")) == str(
				parameters.get("target_slot_id", "")
			)
			and str(option.get("target_region_id", "")) == str(
				parameters.get("target_region_id", "")
			)
			and str(option.get("target_monster_source_instance_id", "")) == str(
				parameters.get("target_monster_source_instance_id", "")
			)
		):
			return queue_card_action(
				actor_id,
				card_instance_id,
				str(option.get("target_slot_id", "")),
				option
			)
	return _reject_action("military_option_identity_stale")


func request_private_monster_skill(
	actor_id: String,
	parameters: Dictionary
) -> Dictionary:
	if not _combat_initialized or not _player_ids.has(actor_id):
		return _reject_action("private_skill_actor_or_runtime_invalid")
	var source_id := str(parameters.get("source_instance_id", ""))
	var skill_id := str(parameters.get("skill_definition_id", ""))
	var source := _public_monster_by_id(source_id)
	if source.is_empty() or str(source.get("owner_player_id", "")) != actor_id:
		return _reject_action("private_skill_source_not_owned")
	var skill := _owner_skill_by_id(actor_id, source_id, skill_id)
	if skill.is_empty():
		return _reject_action("private_skill_definition_not_available")
	var target_request := _private_skill_target_request(
		actor_id,
		source,
		skill,
		parameters
	)
	if target_request.is_empty():
		return _reject_action("private_skill_has_no_legal_target")
	_combat_request_sequence += 1
	var request := {
		"request_id": "request.skill.%s.%06d" % [
			_batch_id(),
			_combat_request_sequence,
		],
		"owner_player_id": actor_id,
		"source_instance_id": source_id,
		"source_generation": int(source.get("source_generation", 0)),
		"skill_definition_id": skill_id,
		"target_request": target_request,
	}
	var before_facility_state := _facility_state.duplicate(true)
	var transaction_checkpoint := _capture_combat_transaction_state()
	var checkpoint := _combat_owner.call(
		"capture_checkpoint",
		"checkpoint.private.%s.%06d" % [
			_batch_id(),
			_combat_request_sequence,
		]
	) as Dictionary
	var result := _combat_owner.call(
		"request_private_skill",
		request,
		_asset_state,
		_public_occupied_facilities()
	) as Dictionary
	_combat_private_skill_request_count += 1
	if not bool(result.get("accepted", false)):
		var rollback := _rollback_combat_transaction(
			checkpoint,
			transaction_checkpoint
		)
		_facility_state = before_facility_state
		if not bool(rollback.get("accepted", false)):
			return _reject_action("private_skill_transaction_rollback_failed")
		return _private_skill_failure_application_receipt(result)
	var next_public_state := _facility_state.duplicate(true)
	var damage_result := _apply_facility_damage_intents(
		next_public_state,
		result.get("facility_damage_intents", []) as Array
	)
	if not bool(damage_result.get("accepted", false)):
		var rollback := _rollback_combat_transaction(
			checkpoint,
			transaction_checkpoint
		)
		_facility_state = before_facility_state
		if not bool(rollback.get("accepted", false)):
			return _reject_action("private_skill_transaction_rollback_failed")
		return _reject_action("private_skill_facility_damage_commit_failed")
	_facility_state = (
		damage_result.get("public_batch_state", next_public_state) as Dictionary
	).duplicate(true)
	_asset_state = (
		result.get("asset_state", _asset_state) as Dictionary
	).duplicate(true)
	_sync_asset_balances()
	_sync_facility_slots()
	# A private skill can consume assets or damage a public target before the
	# next AI/legal-action query. Never reuse a submission snapshot across that
	# authority boundary.
	_clear_v075_submission_caches()
	_clear_v075_track_projection_cache()
	for public_variant in result.get("public_results", []) as Array:
		_publish_combat_event(
			"monster_private_skill_resolved",
			public_variant as Dictionary,
			str((public_variant as Dictionary).get(
				"public_result_id",
				""
			))
		)
	_emit_facility_damage_events(
		damage_result.get("receipts", []) as Array
	)
	_emit_local_state()
	var receipt := result.duplicate(true)
	receipt.erase("facility_damage_intents")
	receipt.erase("asset_state")
	receipt["event_kind"] = "monster_private_skill_requested"
	receipt["combat_channel"] = "private_instant_serial"
	return receipt


func _private_skill_failure_application_receipt(
	result: Dictionary
) -> Dictionary:
	return {
		"accepted": false,
		"reason_code": str(result.get(
			"reason_code",
			"private_skill_request_rejected"
		)),
		"event_kind": "monster_private_skill_request_rejected",
		"combat_channel": "private_instant_serial",
	}


func resolve_next_action() -> Dictionary:
	if _phase != "resolving":
		return _reject_action("resolution_not_active")
	_clear_v075_submission_caches()
	var alignment_reason := _resolution_alignment_reason()
	if not alignment_reason.is_empty():
		_dual_authority_count += 1
		return _fail(alignment_reason, {
			"asset_cursor": int(_asset_state.get("resolution_cursor", -1)),
			"public_cursor": int(_facility_state.get("resolution_cursor", -1)),
		})
	var public_outcome := PublicActionBatchCore.resolve_next_authority_owned(
		_facility_state
	)
	if not bool(public_outcome.get("accepted", false)):
		return _fail("public_action_resolution_failed", public_outcome)
	var next_public_state := (
		public_outcome.get("state", {}) as Dictionary
	).duplicate(false)
	var action_receipt := (
		public_outcome.get("receipt", {}) as Dictionary
	).duplicate(true)
	var action_id := str(action_receipt.get("action_id", ""))
	var actor_id := str(action_receipt.get("actor_id", ""))
	var action_domain := str(action_receipt.get("action_domain", "facility"))
	var source_card_id := _source_card_id_for_action(actor_id, action_id)
	var resolution_checkpoint := _capture_resolution_checkpoint(
		actor_id,
		action_domain,
		action_id,
		source_card_id
	)
	if resolution_checkpoint.is_empty():
		return _fail("resolution_checkpoint_unavailable", {
			"action_id": action_id,
			"action_domain": action_domain,
		})
	var resolved := true
	var combat_result: Dictionary = {}
	var combat_damage_receipts: Array = []
	if action_domain in ["monster", "military"]:
		combat_result = _resolve_combat_public_action(
			action_receipt,
			next_public_state,
			resolution_checkpoint
		)
		if not bool(combat_result.get("accepted", false)):
			if bool(combat_result.get("transaction_rolled_back", false)):
				return _fail("combat_public_action_failed", combat_result)
			return _fail_after_resolution_rollback(
				"combat_public_action_failed",
				combat_result,
				resolution_checkpoint
			)
		next_public_state = (
			combat_result.get("public_batch_state", next_public_state) as Dictionary
		).duplicate(true)
		resolved = bool(combat_result.get("resolved", false))
		combat_damage_receipts = (
			combat_result.get("facility_damage_receipts", []) as Array
		).duplicate(true)
	elif str(action_receipt.get("outcome_id", "")) == "facility_action_fizzled":
		resolved = false
	var candidate_asset_state := _asset_state.duplicate(true)
	if action_domain in ["monster", "military"]:
		candidate_asset_state = (
			combat_result.get("asset_state", candidate_asset_state) as Dictionary
		).duplicate(true)
	var asset_outcome: Dictionary
	if resolved:
		asset_outcome = ASSET_BATCH_CORE.settle_next_action(
			candidate_asset_state,
			action_id,
			"success"
		)
	else:
		asset_outcome = ASSET_BATCH_CORE.settle_invalid_target(
			candidate_asset_state,
			action_id,
			str(combat_result.get(
				"reason_code",
				action_receipt.get("reason_code", "target_invalid")
			))
		)
	if not bool(asset_outcome.get("accepted", false)):
		return _fail_after_resolution_rollback(
			"asset_resolution_failed",
			asset_outcome,
			resolution_checkpoint
		)
	if not source_card_id.is_empty():
		var dbg := _dbg_by_player.get(actor_id) as RefCounted
		var play_intent := dbg.call(
			"create_intent",
			"intent.play.%s" % action_id,
			actor_id,
			DBG_CORE.ACTION_PLAY_CARD,
			{"instance_id": source_card_id}
		) as Dictionary
		var play_receipt := dbg.call("apply_intent", play_intent) as Dictionary
		if not bool(play_receipt.get("success", false)):
			return _fail_after_resolution_rollback(
				"dbg_card_resolution_failed",
				play_receipt,
				resolution_checkpoint
			)
	_facility_state = next_public_state
	_asset_state = (
		asset_outcome.get("state", {}) as Dictionary
	).duplicate(true)
	_sync_facility_slots()
	_sync_asset_balances()
	if action_domain == "facility" and str(
		action_receipt.get("outcome_id", "")
	) == "facility_action_resolved":
		_public_progress_points += 1
	var public_receipt := _public_action_receipt(
		action_receipt,
		combat_result,
		resolved
	)
	_public_history.append(public_receipt.duplicate(true))
	for event_variant in combat_result.get("staged_events", []) as Array:
		var staged_event := event_variant as Dictionary
		_publish_combat_event(
			str(staged_event.get("event_kind", "")),
			staged_event.get("payload", {}) as Dictionary,
			str(staged_event.get("receipt_id", ""))
		)
	resolution_presented.emit(public_receipt.duplicate(true))
	_emit_facility_damage_events(combat_damage_receipts)
	if str(_facility_state.get("status", "")) == "resolved":
		_complete_batch_resolution()
	else:
		_emit_local_state()
	return public_receipt


func _capture_resolution_checkpoint(
	actor_id: String,
	action_domain: String,
	action_id: String,
	source_card_id: String
) -> Dictionary:
	var checkpoint := {
		"runtime_combat": {},
		"combat_checkpoint": {},
		"dbg_checkpoint": {},
	}
	if action_domain in ["monster", "military"]:
		if (
			not is_instance_valid(_combat_owner)
			or not _combat_owner.has_method("capture_checkpoint")
			or not _combat_owner.has_method("rollback_checkpoint")
		):
			return {}
		var combat_checkpoint := _combat_owner.call(
			"capture_checkpoint",
			"checkpoint.resolution.%s.%s" % [_batch_id(), action_id]
		) as Dictionary
		if combat_checkpoint.is_empty():
			return {}
		checkpoint["runtime_combat"] = _capture_combat_transaction_state()
		checkpoint["combat_checkpoint"] = combat_checkpoint.duplicate(true)
	if not source_card_id.is_empty():
		var dbg_checkpoint := _v075_capture_dbg_checkpoint(actor_id)
		if dbg_checkpoint.is_empty():
			return {}
		checkpoint["dbg_checkpoint"] = dbg_checkpoint
	return checkpoint


func _rollback_resolution_checkpoint(checkpoint: Dictionary) -> Dictionary:
	var rollback_ok := true
	var rollback_results: Array = []
	var dbg_row := checkpoint.get("dbg_checkpoint", {}) as Dictionary
	if not dbg_row.is_empty():
		var owner := dbg_row.get("owner") as Object
		var method_name := str(dbg_row.get("rollback_method", ""))
		if (
			owner == null
			or not is_instance_valid(owner)
			or method_name.is_empty()
			or not owner.has_method(method_name)
		):
			rollback_ok = false
		else:
			var dbg_result := owner.call(
				method_name,
				dbg_row.get("checkpoint", {}) as Dictionary
			) as Dictionary
			rollback_results.append(dbg_result.duplicate(true))
			rollback_ok = rollback_ok and _rollback_result_accepted(dbg_result)
	var combat_checkpoint := checkpoint.get("combat_checkpoint", {}) as Dictionary
	if not combat_checkpoint.is_empty():
		if not is_instance_valid(_combat_owner):
			rollback_ok = false
		else:
			var combat_result := _combat_owner.call(
				"rollback_checkpoint",
				combat_checkpoint
			) as Dictionary
			rollback_results.append(combat_result.duplicate(true))
			rollback_ok = rollback_ok and _rollback_result_accepted(
				combat_result
			)
	_restore_combat_transaction_state(
		checkpoint.get("runtime_combat", {}) as Dictionary
	)
	return {
		"accepted": rollback_ok,
		"reason_code": "resolution_checkpoint_restored"
			if rollback_ok
			else "resolution_checkpoint_restore_failed",
		"rollback_results": rollback_results,
	}


func _fail_after_resolution_rollback(
	reason_code: String,
	detail: Dictionary,
	checkpoint: Dictionary
) -> Dictionary:
	var rollback := _rollback_resolution_checkpoint(checkpoint)
	if not bool(rollback.get("accepted", false)):
		return _fail("resolution_rollback_failed", {
			"failure_reason_code": reason_code,
			"failure": detail.duplicate(true),
			"rollback": rollback,
		})
	return _fail(reason_code, detail)


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
	var facility_projection := _facility_player_projection(
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
		"ruleset_id": V075_RULESET_ID,
		"viewer_id": viewer_id,
		"unified_track": track_projection,
		"personal_dbg": dbg_projection,
		"six_color_assets": asset_projection,
		"card_batch": batch_projection,
		"facility_contention": facility_projection,
	}

func player_snapshot(viewer_id: String) -> Dictionary:
	var snapshot := super.player_snapshot(viewer_id)
	if snapshot.is_empty():
		return {}
	snapshot["ruleset_id"] = V075_RULESET_ID
	snapshot["sample_mode_id"] = V075_SAMPLE_MODE_ID
	snapshot["save_notice"] = "V0.7.5 sample save/resume disabled"
	snapshot["special_actions"] = []
	if _combat_initialized:
		var private_facts := _combat_player_private_facts(viewer_id)
		var authority := _combat_owner.call(
			"projection_authority_for_viewer",
			viewer_id,
			private_facts
		) as Dictionary
		var projection := _combat_projection_adapter.call(
			"project_for_viewer",
			authority,
			viewer_id
		) as Dictionary
		snapshot["v075_combat_projection"] = projection
		snapshot["combat_player_projection"] = projection.duplicate(true)
		snapshot["combat_public_history"] = _combat_public_history.duplicate(true)
	return snapshot


func _ai_legal_actions(actor_id: String) -> Array:
	var result: Array = []
	for option_variant in legal_card_actions(actor_id):
		var option := option_variant as Dictionary
		if str(option.get("action_domain", "facility")) in [
			"monster",
			"military",
		]:
			continue
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


func _ai_own_cards(actor_id: String) -> Array:
	var facts := _dbg_projection(actor_id).get("facts", {}) as Dictionary
	var result: Array = []
	for card_variant in facts.get("hand", []) as Array:
		var card := card_variant as Dictionary
		if CardDefinitionsV075.card_domain(str(card.get(
			"card_type",
			""
		))) != "facility":
			continue
		result.append({
			"card_instance_id": str(card.get("instance_id", "")),
			"card_definition_id": str(card.get("definition_id", "")),
			"facility_type": str(card.get("card_type", "")),
			"industry_id": str(card.get("primary_color", "")),
			"rank": int(card.get("level", 1)),
		})
	return result


func ai_observation(actor_id: String) -> Dictionary:
	var observation := super.ai_observation(actor_id)
	if observation.is_empty() or not _combat_initialized:
		return observation
	var private_facts := _combat_ai_private_facts(actor_id)
	var public_facts := _combat_ai_public_facts()
	var candidates := _combat_ai_adapter.call(
		"enumerate_candidates",
		private_facts,
		public_facts
	) as Dictionary
	observation["ruleset_id"] = V075_RULESET_ID
	observation["combat_private_facts"] = private_facts
	observation["combat_public_facts"] = public_facts
	observation["combat_candidates"] = (
		candidates.get("candidates", []) as Array
	).duplicate(true)
	observation["combat_hidden_info_violation_count"] = int(
		candidates.get("hidden_info_violation_count", 0)
	)
	return observation


func debug_snapshot() -> Dictionary:
	var result := super.debug_snapshot()
	var combat_debug := (
		_combat_owner.call("debug_snapshot") as Dictionary
		if _combat_initialized and is_instance_valid(_combat_owner)
		else {}
	)
	result["ruleset_id"] = V075_RULESET_ID
	result["constitution_id"] = V075_CONSTITUTION_ID
	result["current_production_runtime_ruleset"] = V075_RULESET_ID
	result["combat"] = combat_debug
	result["combat_runtime_owner_count"] = int(
		combat_debug.get("combat_runtime_owner_count", 0)
	)
	result["combat_state_writer_count"] = int(
		combat_debug.get("combat_state_writer_count", 0)
	)
	result["combat_dual_authority_count"] = int(
		combat_debug.get("combat_dual_authority_count", 0)
	)
	result["combat_public_receipt_count"] = _combat_public_receipt_count
	result["facility_combat_damage_receipt_count"] = (
		_combat_facility_damage_receipt_count
	)
	result["facility_combat_damage_fizzle_count"] = (
		_combat_facility_damage_fizzle_count
	)
	var telemetry_debug := _combat_telemetry_bridge.call(
		"debug_snapshot"
	) as Dictionary
	result["combat_telemetry"] = telemetry_debug
	result["combat_telemetry_gameplay_owner_count"] = int(
		telemetry_debug.get("gameplay_owner_count", -1)
	)
	result["combat_telemetry_rng_owner_count"] = int(
		telemetry_debug.get("rng_owner_count", -1)
	)
	result["combat_telemetry_world_mutation_count"] = int(
		telemetry_debug.get("world_mutation_count", -1)
	)
	result["combat_telemetry_hidden_field_count"] = int(
		telemetry_debug.get("stored_hidden_field_count", -1)
	)
	result["combat_presentation"] = (
		_combat_presentation_consumer.call("debug_snapshot") as Dictionary
		if is_instance_valid(_combat_presentation_consumer)
		else {}
	)
	result["facility_damage_bridge_receipt_count"] = int(
		(_facility_damage_bridge_state.get(
			"receipt_journal",
			{}
		) as Dictionary).size()
	)
	result["facility_damage_bridge_direct_write_count"] = int(
		_facility_damage_bridge_state.get(
			"combat_direct_facility_write_count",
			0
		)
	)
	result["monster_card_purchase_count"] = _combat_monster_purchase_count
	result["military_card_purchase_count"] = _combat_military_purchase_count
	result["first_monster_card_purchase_batch"] = (
		_combat_first_monster_purchase_batch
	)
	result["first_military_card_purchase_batch"] = (
		_combat_first_military_purchase_batch
	)
	result["ai_monster_private_skill_count"] = _combat_ai_private_skill_count
	result["ai_military_region_assault_count"] = _combat_ai_military_region_count
	result["ai_military_monster_assault_count"] = _combat_ai_military_monster_count
	result["ai_combat_invalid_target_count"] = _combat_ai_invalid_target_count
	result["ai_action_slot_limit"] = V075_AUTO_ACTION_LIMIT
	result["special_support_placeholder_count"] = 0
	result["military_guard_task_count"] = 0
	result["military_bound_action_count"] = 0
	result["old_monster_controller_production_reachable_count"] = 0
	result["old_military_controller_production_reachable_count"] = 0
	result["cutover_domain_count"] = V075_CUTOVER_DOMAIN_COUNT
	result["connected_domain_count"] = (
		V075_CUTOVER_DOMAIN_COUNT if _combat_initialized else 0
	)
	var acquisition_policy := v075_track_acquisition_policy_snapshot()
	result["track_acquisition_policy"] = acquisition_policy
	result["track_acquisition_policy_id"] = (
		V075_TRACK_ACQUISITION_POLICY_ID
	)
	result["track_acquisition_hook_count"] = int(
		acquisition_policy.get("hook_count", 0)
	)
	result["track_acquisition_no_mutation_violation_count"] = int(
		acquisition_policy.get("no_mutation_violation_count", 0)
	)
	result["submission_transaction_rollback_count"] = (
		_v075_submission_rollback_count
	)
	return result


func v075_track_acquisition_policy_snapshot() -> Dictionary:
	var registry_contract := CardDefinitionsV075.registry_contract()
	return {
		"schema": "V075TrackAcquisitionPolicyDebugV1",
		"ruleset_id": V075_RULESET_ID,
		"policy_id": V075_TRACK_ACQUISITION_POLICY_ID,
		"typed_ai_hook": (
			"V075CombatAIAdapter.choose_track_acquisition"
		),
		"owner_private_input_fields": [
			"own_segment_items",
			"available_unreserved_assets",
		],
		"local_visible_capacity": V075_CARD_CAPACITY,
		"facility_economy_dominant": true,
		"combat_acquisition_period": V075_COMBAT_ACQUISITION_PERIOD,
		"combat_acquisition_max_per_period": (
			V075_COMBAT_ACQUISITION_MAX_PER_PERIOD
		),
		"initial_facility_acquisitions_before_combat": (
			V075_INITIAL_FACILITY_ACQUISITIONS_BEFORE_COMBAT
		),
		"facility_acquisitions_between_combat": (
			V075_FACILITY_ACQUISITIONS_BETWEEN_COMBAT
		),
		"normal_subtype_weights_basis_points": (
			registry_contract.get(
				"normal_subtype_weights_basis_points",
				{}
			) as Dictionary
		).duplicate(true),
		"outer_normal_card_ratio_basis_points": int(
			registry_contract.get(
				"outer_normal_card_ratio_basis_points",
				0
			)
		),
		"outer_commodity_card_ratio_basis_points": int(
			registry_contract.get(
				"outer_commodity_card_ratio_basis_points",
				0
			)
		),
		"track_refill_mode_id": V075_TRACK_REFILL_MODE_ID,
		"track_slow_sushi_motion": V075_TRACK_SLOW_SUSHI_MOTION,
		"track_immediate_refill_on_acquisition": (
			V075_TRACK_IMMEDIATE_REFILL_ON_ACQUISITION
		),
		"hook_count": _v075_acquisition_hook_count,
		"opportunity_count": _v075_counter_total(
			_v075_acquisition_opportunities
		),
		"facility_acquisition_count": _v075_counter_total(
			_v075_acquisition_facility_count
		),
		"monster_acquisition_count": _v075_counter_total(
			_v075_acquisition_monster_count
		),
		"military_acquisition_count": _v075_counter_total(
			_v075_acquisition_military_count
		),
		"combat_acquisition_count": (
			_v075_counter_total(_v075_acquisition_monster_count)
			+ _v075_counter_total(_v075_acquisition_military_count)
		),
		"deferred_combat_opportunity_count": _v075_counter_total(
			_v075_acquisition_deferred_count
		),
		"rejection_count": _v075_acquisition_rejection_count,
		"no_mutation_violation_count": (
			_v075_acquisition_no_mutation_violation_count
		),
		"track_direct_write_count": 0,
		"card_injection_count": 0,
		"asset_injection_count": 0,
		"target_injection_count": 0,
		"immediate_authoritative_refill_count": 0,
		"supply_cursor_delta_on_acquisition": 0,
		"supply_instance_sequence_delta_on_acquisition": 0,
		"supply_rng_draw_delta_on_acquisition": 0,
	}


func _v075_counter_total(counter: Dictionary) -> int:
	var total := 0
	for value_variant in counter.values():
		total += int(value_variant)
	return total


func _reset_runtime() -> void:
	super._reset_runtime()
	_combat_initialized = false
	_combat_autonomy_completed_batch_id = ""
	_combat_public_receipt_count = 0
	_combat_facility_damage_receipt_count = 0
	_combat_facility_damage_fizzle_count = 0
	_combat_private_skill_request_count = 0
	_combat_monster_purchase_count = 0
	_combat_military_purchase_count = 0
	_combat_first_monster_purchase_batch = -1
	_combat_first_military_purchase_batch = -1
	_combat_ai_private_skill_count = 0
	_combat_ai_military_region_count = 0
	_combat_ai_military_monster_count = 0
	_combat_ai_invalid_target_count = 0
	_processed_facility_damage_intents = {}
	_facility_damage_bridge_state = {}
	_combat_telemetry_bridge.call("reset_for_new_match")
	if is_instance_valid(_combat_presentation_consumer):
		_combat_presentation_consumer.call("reset_for_new_match")
	_combat_public_history = []
	_combat_request_sequence = 0
	_v075_acquisition_opportunities = {}
	_v075_acquisition_facility_count = {}
	_v075_acquisition_monster_count = {}
	_v075_acquisition_military_count = {}
	_v075_acquisition_deferred_count = {}
	_v075_acquisition_last_domain = {}
	_v075_acquisition_facility_since_combat = {}
	_v075_acquisition_last_combat_opportunity = {}
	_v075_acquisition_hook_count = 0
	_v075_acquisition_rejection_count = 0
	_v075_acquisition_no_mutation_violation_count = 0
	_v075_submission_rollback_count = 0
	_v075_public_facility_slots_cache = []
	_clear_v075_submission_caches()
	_clear_v075_track_projection_cache()


func _begin_batch() -> void:
	_clear_v075_submission_caches()
	_clear_v075_track_projection_cache()
	super._begin_batch()
	if _combat_initialized and _phase != "failed":
		var result := _begin_combat_batch()
		if not bool(result.get("accepted", false)):
			_fail("combat_batch_start_failed", result)
			return
		_emit_local_state()


func _clear_v075_submission_caches() -> void:
	_v075_submission_legal_actions_cache = {}
	_v075_submission_card_cache = {}


func _v075_track_projection(actor_id: String) -> Dictionary:
	if _phase == "submission" and _v075_track_projection_cache.has(actor_id):
		return (
			_v075_track_projection_cache.get(actor_id, {}) as Dictionary
		).duplicate(true)
	if _track_core == null:
		return {}
	var projection := _track_core.call(
		"player_projection_v1",
		actor_id
	) as Dictionary
	if _phase == "submission" and not projection.is_empty():
		_v075_track_projection_cache[actor_id] = projection.duplicate(true)
	return projection


func _clear_v075_track_projection_cache() -> void:
	_v075_track_projection_cache = {}


func set_track_stance(
	actor_id: String,
	increase_color: String,
	decrease_color: String
) -> Dictionary:
	var result := super.set_track_stance(
		actor_id,
		increase_color,
		decrease_color
	)
	if bool(result.get("accepted", false)):
		_clear_v075_track_projection_cache()
	return result


func _complete_batch_resolution() -> void:
	if _combat_initialized and _combat_autonomy_completed_batch_id != _batch_id():
		var completed := _resolve_combat_maintenance()
		if not bool(completed.get("accepted", false)):
			_fail("combat_maintenance_failed", completed)
			return
		_combat_autonomy_completed_batch_id = _batch_id()
	super._complete_batch_resolution()


func _commit_victory() -> void:
	if _combat_initialized:
		var pending := _combat_owner.call(
			"set_phase",
			"victory_pending"
		) as Dictionary
		if not bool(pending.get("accepted", false)):
			_fail("combat_victory_pending_rejected", pending)
			return
	super._commit_victory()
	if _combat_initialized and _phase == "settled":
		_combat_owner.call("set_phase", "final_settlement")


func _apply_geometric_solar(
	sun_direction: Vector3,
	refresh_facilities: bool
) -> void:
	if (
		refresh_facilities
		and bool(PublicActionBatchCore.validation_report(
			_facility_state
		).get("valid", false))
	):
		var batch_state := _facility_state.duplicate(true)
		_facility_state = PublicActionBatchCore.facility_substate(batch_state)
		super._apply_geometric_solar(sun_direction, refresh_facilities)
		if _phase == "failed":
			return
		var replaced := PublicActionBatchCore.replace_facility_substate(
			batch_state,
			_facility_state
		)
		if replaced.is_empty():
			_fail("warehouse_solar_public_batch_replace_failed", {})
			return
		_facility_state = replaced
		_sync_facility_slots()
		return
	super._apply_geometric_solar(sun_direction, refresh_facilities)


func _facility_resolve_next(state: Dictionary) -> Dictionary:
	var pending_action := _pending_facility_action(state)
	var outcome := PublicActionBatchCore.resolve_next(state)
	if (
		str(pending_action.get("action_domain", "facility")) == "facility"
		and str(pending_action.get("facility_type", "")) == "warehouse"
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


func _facility_player_projection(
	state: Dictionary,
	viewer_id: String
) -> Dictionary:
	return PublicActionBatchCore.player_projection(state, viewer_id)


func _facility_ai_observation(
	state: Dictionary,
	viewer_id: String
) -> Dictionary:
	return PublicActionBatchCore.ai_observation(state, viewer_id)


func _facility_validation_report(state: Dictionary) -> Dictionary:
	return PublicActionBatchCore.validation_report(state)


func _facility_lock_batch(
	batch_id: String,
	player_ids: Array,
	hidden_order: Array,
	player_local_queues: Dictionary,
	facility_slots: Array
) -> Dictionary:
	return PublicActionBatchCore.lock_batch(
		batch_id,
		player_ids,
		hidden_order,
		player_local_queues,
		facility_slots
	)


func _sync_facility_slots() -> void:
	var source_state := _facility_state.get(
		"facility_substate",
		_facility_state
	) as Dictionary
	var slots := source_state.get("facility_slots", {}) as Dictionary
	var ids: Array[String] = []
	for id_variant in slots.keys():
		ids.append(str(id_variant))
	ids.sort()
	_facility_slots = []
	_v075_public_facility_slots_cache = []
	for slot_id in ids:
		var slot := slots.get(slot_id, {}) as Dictionary
		_facility_slots.append(slot)
		_v075_public_facility_slots_cache.append(
			_v075_public_facility_row(slot)
		)


func _sync_asset_balances() -> void:
	var players := _asset_state.get("players", {}) as Dictionary
	for actor_id in _player_ids:
		var player := players.get(actor_id, {}) as Dictionary
		var assets_value: Variant = player.get("assets", {})
		if assets_value is Dictionary and _v075_complete_asset_projection(
			assets_value as Dictionary
		):
			_asset_balances[actor_id] = (
				assets_value as Dictionary
			).duplicate(true)


func _public_facility_slots() -> Array:
	if _facility_state.is_empty():
		return []
	return _v075_public_facility_slots_cache.duplicate(true)


func _v075_public_facility_row(slot: Dictionary) -> Dictionary:
	return {
		"slot_id": slot.get("slot_id"),
		"region_id": slot.get("region_id"),
		"facility_type": slot.get("facility_type"),
		"industry_id": slot.get("industry_id"),
		"slot_generation": slot.get("slot_generation"),
		"occupancy": slot.get("occupancy"),
		"facility_id": slot.get("facility_id"),
		"facility_generation": slot.get("facility_generation"),
		"owner_id": slot.get("owner_id"),
		"owner_player_id": slot.get("owner_id"),
		"rank": slot.get("rank"),
		"damage_revision": slot.get("damage_revision"),
		"damage_points": slot.get("damage_points"),
		"capacity": slot.get("capacity"),
		"base_ingress_throughput": slot.get("base_ingress_throughput"),
		"base_egress_throughput": slot.get("base_egress_throughput"),
		"ingress_throughput": slot.get("ingress_throughput"),
		"egress_throughput": slot.get("egress_throughput"),
		"solar_efficiency_state": slot.get("solar_efficiency_state"),
		"commercial_art_key": slot.get("commercial_art_key"),
		"warehouse_stock_runtime_phase": slot.get(
			"warehouse_stock_runtime_phase"
		),
	}


func _public_occupied_facilities() -> Array:
	return _occupied_public_facility_rows(_public_facility_slots())


func _occupied_public_facility_rows(rows: Array) -> Array:
	var result: Array = []
	for row_variant in rows:
		var row := row_variant as Dictionary
		if not _facility_is_publicly_occupied(row):
			continue
		result.append(row.duplicate(true))
	return result


func _facility_is_publicly_occupied(facility: Dictionary) -> bool:
	var generation: Variant = facility.get("facility_generation")
	return (
		str(facility.get("occupancy", "occupied")) == "occupied"
		and not str(facility.get("facility_id", "")).is_empty()
		and not _facility_owner_id(facility).is_empty()
		and generation is int
		and int(generation) > 0
		and str(facility.get("facility_type", "")) in [
			"factory",
			"market",
			"warehouse",
		]
	)


func _build_bound_actions(
	actor_id: String,
	binding: Dictionary,
	local_index: int
) -> Dictionary:
	var domain := str(binding.get("action_domain", "facility"))
	if domain not in ["monster", "military"]:
		return super._build_bound_actions(actor_id, binding, local_index)
	var card := _card_in_hand(
		actor_id,
		str(binding.get("card_instance_id", ""))
	)
	if card.is_empty():
		return {}
	var action_id := str(binding.get("action_id", ""))
	var primary_color := str(card.get("primary_color", ""))
	if primary_color not in COLORS:
		return {}
	var cost := _zero_colors()
	cost["any"] = 0
	cost[primary_color] = int(card.get("primary_asset_cost", 0))
	var target_ids: Array[String] = []
	for field_name in [
		"target_region_id",
		"target_source_instance_id",
		"target_monster_source_instance_id",
	]:
		var target_id := str(binding.get(field_name, ""))
		if not target_id.is_empty() and target_id not in target_ids:
			target_ids.append(target_id)
	if target_ids.is_empty():
		return {}
	var asset_binding := ASSET_BATCH_CORE.build_target_binding(
		"binding.%s" % action_id,
		target_ids,
		maxi(1, _batch_number)
	)
	var asset_action := ASSET_BATCH_CORE.build_prebound_action(
		action_id,
		"normal_card",
		str(card.get("instance_id", "")),
		local_index,
		str(card.get("definition_id", "")),
		asset_binding,
		"%s.%s" % [
			domain,
			str(binding.get(
				"monster_card_mode" if domain == "monster" else "task_kind",
				""
			)).to_lower(),
		],
		cost,
		_zero_colors()
	)
	if asset_action.is_empty():
		return {}
	var combat_binding: Dictionary
	if domain == "monster":
		var prebound := _combat_owner.call(
			"prebind_monster_card_action",
			{
				"request_id": "request.%s" % action_id,
				"card_instance_id": str(card.get("instance_id", "")),
				"card_definition_id": str(card.get("definition_id", "")),
				"owner_player_id": actor_id,
				"monster_card_mode": str(binding.get("monster_card_mode", "")),
				"target_region_id": str(binding.get("target_region_id", "")),
				"target_source_instance_id": str(
					binding.get("target_source_instance_id", "")
				),
			}
		) as Dictionary
		if not bool(prebound.get("accepted", false)):
			return {}
		combat_binding = {
			"prebound_action": (
				prebound.get("action", {}) as Dictionary
			).duplicate(true),
		}
	else:
		var mission_id := "mission.%s" % action_id
		var lock := _combat_owner.call(
			"build_military_lock",
			{
				"request_id": "request.%s" % mission_id,
				"mission_id": mission_id,
				"owner_player_id": actor_id,
				"card_instance_id": str(card.get("instance_id", "")),
				"card_definition_id": str(card.get("definition_id", "")),
				"action_slot_id": action_id,
				"asset_reservation_id": "reservation.%s" % action_id,
				"committed_escrow_revision": maxi(1, _batch_number),
				"target_region_revision": maxi(1, _batch_number),
				"task_kind": str(binding.get("task_kind", "")),
				"target_region_id": str(binding.get("target_region_id", "")),
				"target_monster_source_instance_id": str(
					binding.get("target_monster_source_instance_id", "")
				),
			},
			_public_occupied_facilities()
		) as Dictionary
		if not bool(lock.get("accepted", false)):
			return {}
		combat_binding = {
			"mission_id": mission_id,
			"locked_mission": (
				lock.get("locked_mission", {}) as Dictionary
			).duplicate(true),
		}
	var public_action := {
		"action_id": action_id,
		"actor_id": actor_id,
		"local_action_index": local_index,
		"action_domain": domain,
		"source_card_instance_id": str(card.get("instance_id", "")),
		"combat_binding": combat_binding,
	}
	return {
		"asset_action": asset_action,
		"facility_action": public_action,
	}


func _track_start_config() -> Dictionary:
	return {
		"balance_profile_id": TRACK_CORE.BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": TRACK_CORE.BALANCE_PROFILE_FINGERPRINT,
		"normal_card_ratio_basis_points": 6000,
		"commodity_card_ratio_basis_points": 4000,
		"local_visible_slot_count": V075_CARD_CAPACITY,
		"match_instance_id": _match_id,
		"card_definition_registry_id": CardDefinitionsV075.REGISTRY_ID,
	}


func _runtime_ruleset_id() -> String:
	return V075_RULESET_ID


func _runtime_sample_mode_id() -> String:
	return V075_SAMPLE_MODE_ID


func _runtime_match_id(seed_value: int, sequence: int) -> String:
	return "match.v075.sample.%d.%d" % [absi(seed_value), sequence]


func _runtime_new_game_reason() -> String:
	return "v075_new_game_started"


func _runtime_new_game_failure_reason() -> String:
	return "v075_new_game_initialization_failed"


func _runtime_new_game_metadata() -> Dictionary:
	var result := super._runtime_new_game_metadata()
	result["combat_balance_profile_id"] = (
		CardDefinitionsV075.BALANCE_PROFILE_ID
	)
	result["combat_balance_profile_fingerprint"] = (
		CardDefinitionsV075.BALANCE_PROFILE_FINGERPRINT
	)
	return result


func _runtime_legal_target_authority_id() -> String:
	return "v075.production.dynamic_map_combat_legal_target_authority"


func _runtime_track_authorization_authority_id() -> String:
	return "v075.player_segment_authority"


func _runtime_victory_condition_id() -> String:
	return "v075.public_facility_network_threshold"


func _special_actions_for_viewer(_viewer_id: String) -> Array:
	return []


func _begin_combat_batch() -> Dictionary:
	_combat_autonomy_completed_batch_id = ""
	return _combat_owner.call(
		"begin_batch",
		_batch_id(),
		maxi(0, _batch_number - 1),
		_asset_state,
		_public_occupied_facilities()
	) as Dictionary


func _monster_card_options(actor_id: String, card: Dictionary) -> Array:
	var result: Array = []
	var definition_id := str(card.get("definition_id", ""))
	var regions := _runtime_region_ids()
	var own_sources: Array = []
	for source_variant in _v075_public_monsters():
		var source := source_variant as Dictionary
		if str(source.get("owner_player_id", "")) == actor_id and str(
			source.get("status", "")
		) not in ["destroyed", "withdrawn"]:
			own_sources.append(source)
	for mode in [
		"DEPLOY_NEW",
		"REFRESH_EXISTING",
		"UPGRADE_EXISTING",
		"REPLACE_EXISTING",
	]:
		var candidates: Array = []
		if mode == "DEPLOY_NEW":
			for region_id in regions:
				candidates.append({
					"target_region_id": region_id,
					"target_source_instance_id": "",
				})
		else:
			for source_variant in own_sources:
				var source := source_variant as Dictionary
				candidates.append({
					"target_region_id": str(source.get("region_id", "")),
					"target_source_instance_id": str(
						source.get("source_instance_id", "")
					),
				})
		var deploy_preview_checked := false
		var deploy_preview_accepted := false
		for candidate_variant in candidates:
			var candidate := candidate_variant as Dictionary
			var request := {
				"request_id": "preview.%s.%s.%s" % [
					str(card.get("instance_id", "")),
					mode.to_lower(),
					str(candidate).sha256_text().substr(0, 8),
				],
				"card_instance_id": str(card.get("instance_id", "")),
				"card_definition_id": definition_id,
				"owner_player_id": actor_id,
				"monster_card_mode": mode,
				"target_region_id": str(candidate.get("target_region_id", "")),
				"target_source_instance_id": str(
					candidate.get("target_source_instance_id", "")
				),
			}
			if mode == "DEPLOY_NEW" and deploy_preview_checked:
				if not deploy_preview_accepted:
					continue
			else:
				var preview_method := (
					"preview_monster_card_action"
					if _combat_owner.has_method("preview_monster_card_action")
					else "prebind_monster_card_action"
				)
				var prebound := _combat_owner.call(
					preview_method,
					request
				) as Dictionary
				if mode == "DEPLOY_NEW":
					deploy_preview_checked = true
					deploy_preview_accepted = bool(
						prebound.get("accepted", false)
					)
				if not bool(prebound.get("accepted", false)):
					continue
			var target_identity := str(candidate.get(
				"target_source_instance_id",
				""
			))
			if target_identity.is_empty():
				target_identity = str(candidate.get("target_region_id", ""))
			var target_slot_id := "combat.monster.%s.%s" % [
				mode.to_lower(),
				target_identity.sha256_text().substr(0, 12),
			]
			result.append({
				"option_id": "option.%s.%s" % [
					str(card.get("instance_id", "")).sha256_text().substr(0, 10),
					target_slot_id.sha256_text().substr(0, 10),
				],
				"actor_id": actor_id,
				"card_instance_id": str(card.get("instance_id", "")),
				"card_definition_id": definition_id,
				"card_rank": int(card.get("level", 0)),
				"primary_color": str(card.get("primary_color", "")),
				"asset_cost": int(card.get("primary_asset_cost", 0)),
				"action_domain": "monster",
				"monster_card_mode": mode,
				"target_slot_id": target_slot_id,
				"target_region_id": str(candidate.get("target_region_id", "")),
				"target_source_instance_id": str(
					candidate.get("target_source_instance_id", "")
				),
				"mode_prebound": true,
			})
	return result


func _military_card_options(actor_id: String, card: Dictionary) -> Array:
	var result: Array = []
	var regions := {}
	for facility_variant in _public_occupied_facilities():
		var facility := facility_variant as Dictionary
		if _facility_owner_id(facility) == actor_id or str(
			facility.get("status", "active")
		) == "destroyed":
			continue
		regions[str(facility.get("region_id", ""))] = true
	var region_ids: Array[String] = []
	for region_id_variant in regions.keys():
		if not str(region_id_variant).is_empty():
			region_ids.append(str(region_id_variant))
	region_ids.sort()
	for region_id in region_ids:
		result.append(_military_option(
			actor_id,
			card,
			"assault_region",
			region_id,
			""
		))
	var monster_ids: Array[String] = []
	for source_variant in _v075_public_monsters():
		var source := source_variant as Dictionary
		if (
			str(source.get("owner_player_id", "")) != actor_id
			and str(source.get("status", "")) not in ["destroyed", "withdrawn"]
		):
			monster_ids.append(str(source.get("source_instance_id", "")))
	monster_ids.sort()
	for source_id in monster_ids:
		result.append(_military_option(
			actor_id,
			card,
			"assault_monster",
			"",
			source_id
		))
	return result


func _military_option(
	actor_id: String,
	card: Dictionary,
	task_kind: String,
	target_region_id: String,
	target_monster_id: String
) -> Dictionary:
	var target_id := target_region_id if task_kind == "assault_region" else target_monster_id
	var target_slot_id := "combat.military.%s.%s" % [
		task_kind,
		target_id.sha256_text().substr(0, 12),
	]
	return {
		"option_id": "option.%s.%s" % [
			str(card.get("instance_id", "")).sha256_text().substr(0, 10),
			target_slot_id.sha256_text().substr(0, 10),
		],
		"actor_id": actor_id,
		"card_instance_id": str(card.get("instance_id", "")),
		"card_definition_id": str(card.get("definition_id", "")),
		"primary_color": str(card.get("primary_color", "")),
		"asset_cost": int(card.get("primary_asset_cost", 0)),
		"action_domain": "military",
		"task_kind": task_kind,
		"target_slot_id": target_slot_id,
		"target_region_id": target_region_id,
		"target_monster_source_instance_id": target_monster_id,
		"mode_prebound": true,
	}


func _combat_option_by_identity(
	actor_id: String,
	card_instance_id: String,
	target_slot_id: String,
	target_binding: Dictionary
) -> Dictionary:
	for option_variant in legal_card_actions(actor_id):
		var option := option_variant as Dictionary
		if (
			str(option.get("card_instance_id", "")) == card_instance_id
			and str(option.get("target_slot_id", "")) == target_slot_id
		):
			if not target_binding.is_empty():
				for field_name in [
					"action_domain",
					"monster_card_mode",
					"task_kind",
					"target_region_id",
					"target_source_instance_id",
					"target_monster_source_instance_id",
				]:
					if target_binding.has(field_name) and target_binding.get(
						field_name
					) != option.get(field_name):
						return {}
			return option.duplicate(true)
	return {}


func _resolve_combat_public_action(
	action_receipt: Dictionary,
	next_public_state: Dictionary,
	existing_checkpoint: Dictionary = {}
) -> Dictionary:
	var action_domain := str(action_receipt.get("action_domain", ""))
	var action_binding := (
		action_receipt.get("action_binding", {}) as Dictionary
	)
	var combat_binding := (
		action_binding.get("combat_binding", {}) as Dictionary
	)
	var atomic_receipt_id := str(action_receipt.get("receipt_id", ""))
	var transaction_checkpoint := _combat_public_action_checkpoint(
		existing_checkpoint,
		atomic_receipt_id
	)
	if transaction_checkpoint.is_empty():
		return {
			"accepted": false,
			"reason_code": "combat_public_action_checkpoint_unavailable",
		}
	var begun := _combat_owner.call(
		"begin_public_receipt",
		atomic_receipt_id
	) as Dictionary
	if not bool(begun.get("accepted", false)):
		return _rollback_failed_combat_public_action(
			begun,
			transaction_checkpoint
		)
	var resolved_action: Dictionary
	var event_kind := ""
	var main_payload: Dictionary = {}
	var action_resolved := false
	if action_domain == "monster":
		resolved_action = _combat_owner.call(
			"resolve_monster_card_action",
			combat_binding.get("prebound_action", {}) as Dictionary
		) as Dictionary
		if not bool(resolved_action.get("accepted", false)):
			return _rollback_failed_combat_public_action(
				resolved_action,
				transaction_checkpoint
			)
		main_payload = (
			resolved_action.get("receipt", {}) as Dictionary
		).duplicate(true)
		action_resolved = str(main_payload.get("outcome_id", "")) == (
			"monster_card_resolved"
		)
		event_kind = {
			"DEPLOY_NEW": "monster_deployed",
			"REFRESH_EXISTING": "monster_refreshed",
			"UPGRADE_EXISTING": "monster_upgraded",
			"REPLACE_EXISTING": "monster_replaced",
		}.get(
			str(main_payload.get("monster_card_mode", "")),
			"monster_deployed"
		)
	else:
		resolved_action = _combat_owner.call(
			"resolve_military_action",
			str(combat_binding.get("mission_id", "")),
			_public_facilities_from_batch_state(next_public_state)
		) as Dictionary
		if not bool(resolved_action.get("accepted", false)):
			return _rollback_failed_combat_public_action(
				resolved_action,
				transaction_checkpoint
			)
		main_payload = (
			resolved_action.get("receipt", {}) as Dictionary
		).duplicate(true)
		action_resolved = str(main_payload.get("outcome", "")) == "resolved"
		var task_kind := str(main_payload.get("task_kind", ""))
		event_kind = "military_region_assault" if task_kind == (
			"assault_region"
		) else "military_monster_assault"
	var damage_result := _apply_facility_damage_intents(
		next_public_state,
		resolved_action.get("facility_damage_intents", []) as Array
	)
	if not bool(damage_result.get("accepted", false)):
		return _rollback_failed_combat_public_action(
			damage_result,
			transaction_checkpoint
		)
	next_public_state = (
		damage_result.get("public_batch_state", next_public_state) as Dictionary
	).duplicate(true)
	var safe_boundary := _combat_owner.call(
		"complete_public_receipt",
		atomic_receipt_id,
		_asset_state,
		_public_facilities_from_batch_state(next_public_state)
	) as Dictionary
	if not bool(safe_boundary.get("accepted", false)):
		return _rollback_failed_combat_public_action(
			safe_boundary,
			transaction_checkpoint
		)
	var boundary_damage := _apply_facility_damage_intents(
		next_public_state,
		safe_boundary.get("facility_damage_intents", []) as Array
	)
	if not bool(boundary_damage.get("accepted", false)):
		return _rollback_failed_combat_public_action(
			boundary_damage,
			transaction_checkpoint
		)
	next_public_state = (
		boundary_damage.get("public_batch_state", next_public_state) as Dictionary
	).duplicate(true)
	var staged_events: Array = [{
		"event_kind": event_kind,
		"payload": main_payload.duplicate(true),
		"receipt_id": atomic_receipt_id,
	}]
	if action_domain == "military":
		staged_events.append({
			"event_kind": "military_withdrawn",
			"payload": main_payload.duplicate(true),
			"receipt_id": "withdrawal.%s" % atomic_receipt_id,
		})
	for public_variant in safe_boundary.get("public_results", []) as Array:
		staged_events.append({
			"event_kind": "monster_private_skill_resolved",
			"payload": (public_variant as Dictionary).duplicate(true),
			"receipt_id": str((public_variant as Dictionary).get(
				"public_result_id",
				""
			)),
		})
	var receipts := damage_result.get("receipts", []) as Array
	receipts.append_array(
		boundary_damage.get("receipts", []) as Array
	)
	return {
		"accepted": true,
		"reason_code": str(main_payload.get("reason_code", "")),
		"resolved": action_resolved,
		"event_kind": event_kind,
		"staged_events": staged_events,
		"combat_receipt": _public_combat_payload(main_payload),
		"public_batch_state": next_public_state,
		"asset_state": (
			safe_boundary.get("asset_state", _asset_state) as Dictionary
		).duplicate(true),
		"facility_damage_receipts": receipts,
	}


func _combat_public_action_checkpoint(
	existing_checkpoint: Dictionary,
	atomic_receipt_id: String
) -> Dictionary:
	var existing_combat := existing_checkpoint.get(
		"combat_checkpoint",
		{}
	) as Dictionary
	var existing_runtime := existing_checkpoint.get(
		"runtime_combat",
		{}
	) as Dictionary
	if not existing_combat.is_empty() and not existing_runtime.is_empty():
		return {
			"combat_checkpoint": existing_combat,
			"runtime_combat": existing_runtime,
		}
	if (
		not is_instance_valid(_combat_owner)
		or not _combat_owner.has_method("capture_checkpoint")
		or not _combat_owner.has_method("rollback_checkpoint")
	):
		return {}
	var combat_checkpoint := _combat_owner.call(
		"capture_checkpoint",
		"checkpoint.%s" % atomic_receipt_id
	) as Dictionary
	if combat_checkpoint.is_empty():
		return {}
	return {
		"combat_checkpoint": combat_checkpoint,
		"runtime_combat": _capture_combat_transaction_state(),
	}


func _rollback_failed_combat_public_action(
	failure: Dictionary,
	transaction_checkpoint: Dictionary
) -> Dictionary:
	var rollback := _rollback_combat_transaction(
		transaction_checkpoint.get("combat_checkpoint", {}) as Dictionary,
		transaction_checkpoint.get("runtime_combat", {}) as Dictionary
	)
	var result := failure.duplicate(true)
	result["transaction_rolled_back"] = bool(rollback.get("accepted", false))
	if not bool(rollback.get("accepted", false)):
		result["reason_code"] = "combat_transaction_rollback_failed"
		result["rollback_failure"] = rollback
	return result


func _resolve_combat_maintenance() -> Dictionary:
	if (
		not is_instance_valid(_combat_owner)
		or not _combat_owner.has_method("capture_checkpoint")
		or not _combat_owner.has_method("rollback_checkpoint")
	):
		return {
			"accepted": false,
			"reason_code": "combat_maintenance_checkpoint_unavailable",
		}
	var checkpoint := _combat_owner.call(
		"capture_checkpoint",
		"checkpoint.maintenance.%s" % _batch_id()
	) as Dictionary
	if checkpoint.is_empty():
		return {
			"accepted": false,
			"reason_code": "combat_maintenance_checkpoint_unavailable",
		}
	var transaction_checkpoint := _capture_combat_transaction_state()
	var phased := _combat_owner.call(
		"set_phase",
		"maintenance_before_autonomy"
	) as Dictionary
	if not bool(phased.get("accepted", false)):
		return _fail_after_maintenance_rollback(
			phased,
			checkpoint,
			transaction_checkpoint
		)
	var next_public_state := _facility_state.duplicate(true)
	var next_asset_state := _asset_state.duplicate(true)
	var safe_boundary := _combat_owner.call(
		"resolve_private_skill_safe_boundary",
		next_asset_state,
		_public_facilities_from_batch_state(next_public_state)
	) as Dictionary
	if not bool(safe_boundary.get("accepted", false)):
		return _fail_after_maintenance_rollback(
			safe_boundary,
			checkpoint,
			transaction_checkpoint
		)
	next_asset_state = (
		safe_boundary.get("asset_state", next_asset_state) as Dictionary
	).duplicate(true)
	var skill_damage := _apply_facility_damage_intents(
		next_public_state,
		safe_boundary.get("facility_damage_intents", []) as Array
	)
	if not bool(skill_damage.get("accepted", false)):
		return _fail_after_maintenance_rollback(
			skill_damage,
			checkpoint,
			transaction_checkpoint
		)
	next_public_state = (
		skill_damage.get("public_batch_state", next_public_state) as Dictionary
	).duplicate(true)
	var facilities := _public_facilities_from_batch_state(next_public_state)
	var planned := _combat_owner.call("plan_autonomy", facilities) as Dictionary
	if not bool(planned.get("accepted", false)):
		return _fail_after_maintenance_rollback(
			planned,
			checkpoint,
			transaction_checkpoint
		)
	var autonomy := _combat_owner.call("resolve_autonomy", facilities) as Dictionary
	if not bool(autonomy.get("accepted", false)):
		return _fail_after_maintenance_rollback(
			autonomy,
			checkpoint,
			transaction_checkpoint
		)
	var autonomy_damage := _apply_facility_damage_intents(
		next_public_state,
		autonomy.get("facility_damage_intents", []) as Array
	)
	if not bool(autonomy_damage.get("accepted", false)):
		return _fail_after_maintenance_rollback(
			autonomy_damage,
			checkpoint,
			transaction_checkpoint
		)
	next_public_state = (
		autonomy_damage.get("public_batch_state", next_public_state) as Dictionary
	).duplicate(true)
	_facility_state = next_public_state
	_asset_state = next_asset_state
	_sync_facility_slots()
	_sync_asset_balances()
	for public_variant in safe_boundary.get("public_results", []) as Array:
		_publish_combat_event(
			"monster_private_skill_resolved",
			public_variant as Dictionary,
			str((public_variant as Dictionary).get("public_result_id", ""))
		)
	for movement_variant in autonomy.get("movement_receipts", []) as Array:
		var movement := movement_variant as Dictionary
		_publish_combat_event(
			"monster_moved",
			movement,
			str(movement.get("movement_id", ""))
		)
	for trample_variant in autonomy.get(
		"trample_region_receipts",
		[]
	) as Array:
		var trample := trample_variant as Dictionary
		_publish_combat_event(
			"monster_trample_resolved",
			trample,
			str(trample.get("combat_receipt_id", trample.get(
				"receipt_id",
				""
			)))
		)
	for attack_variant in autonomy.get("basic_attack_receipts", []) as Array:
		var attack := attack_variant as Dictionary
		_publish_combat_event(
			"monster_basic_attack",
			attack,
			str(attack.get("combat_receipt_id", ""))
		)
	var facility_receipts := skill_damage.get("receipts", []) as Array
	facility_receipts.append_array(
		autonomy_damage.get("receipts", []) as Array
	)
	_emit_facility_damage_events(facility_receipts)
	return {
		"accepted": true,
		"reason_code": "v075_combat_maintenance_resolved",
		"autonomy": autonomy,
	}


func _fail_after_maintenance_rollback(
	failure: Dictionary,
	checkpoint: Dictionary,
	transaction_checkpoint: Dictionary
) -> Dictionary:
	var rollback := _rollback_combat_authority_transaction(
		checkpoint,
		transaction_checkpoint
	)
	if not bool(rollback.get("accepted", false)):
		return {
			"accepted": false,
			"reason_code": "combat_maintenance_rollback_failed",
			"failure": failure.duplicate(true),
			"rollback": rollback,
		}
	return failure


func _rollback_combat_authority_transaction(
	checkpoint: Dictionary,
	transaction_checkpoint: Dictionary
) -> Dictionary:
	if not is_instance_valid(_combat_owner):
		return {
			"accepted": false,
			"reason_code": "combat_owner_missing_during_rollback",
		}
	var result := _combat_owner.call(
		"rollback_checkpoint",
		checkpoint
	) as Dictionary
	_restore_combat_transaction_state(transaction_checkpoint)
	return {
		"accepted": _rollback_result_accepted(result),
		"reason_code": "combat_transaction_restored"
			if _rollback_result_accepted(result)
			else "combat_transaction_restore_failed",
		"combat_rollback": result.duplicate(true),
	}


func _apply_facility_damage_intents(
	public_batch_state: Dictionary,
	intents: Array
) -> Dictionary:
	if intents.is_empty():
		return {
			"accepted": true,
			"reason_code": "facility_damage_intents_empty",
			"public_batch_state": public_batch_state.duplicate(false),
			"receipts": [],
		}
	var facility_state := PublicActionBatchCore.facility_substate(
		public_batch_state
	)
	if facility_state.is_empty():
		return {
			"accepted": false,
			"reason_code": "facility_damage_substate_missing",
		}
	var processed_next := _processed_facility_damage_intents.duplicate(true)
	var bridge_state_next := _facility_damage_bridge_state.duplicate(true)
	var safe_bridge_state := _build_facility_damage_bridge_state(
		facility_state
	)
	if safe_bridge_state.is_empty():
		return {
			"accepted": false,
			"reason_code": "facility_damage_bridge_safe_boundary_failed",
		}
	if bridge_state_next.is_empty():
		bridge_state_next = safe_bridge_state
	else:
		bridge_state_next = FacilityDamageBridge.rebase_state(
			bridge_state_next,
			safe_bridge_state.get("facility_state", {}) as Dictionary
		)
		if bridge_state_next.is_empty():
			return {
				"accepted": false,
				"reason_code": "facility_damage_bridge_rebase_failed",
			}
	var receipts: Array = []
	var committed_receipt_count := 0
	var fizzle_receipt_count := 0
	for intent_variant in intents:
		var intent := intent_variant as Dictionary
		var intent_report: Dictionary = FacilityDamageIntent.validation_report(
			intent
		)
		if not bool(intent_report.get("valid", false)):
			return {
				"accepted": false,
				"reason_code": "facility_damage_intent_invalid",
				"detail": intent_report,
			}
		var receipt_key := "%s|%s" % [
			str(intent.get("combat_receipt_id", "")),
			str(intent.get("target_facility_id", "")),
		]
		var fingerprint := str(intent.get("intent_fingerprint", ""))
		if processed_next.has(receipt_key):
			var prior := processed_next.get(receipt_key, {}) as Dictionary
			if str(prior.get("fingerprint", "")) != fingerprint:
				return {
					"accepted": false,
					"reason_code": "facility_damage_receipt_collision",
				}
			receipts.append(
				(prior.get("receipt", {}) as Dictionary).duplicate(true)
			)
			continue
		var applied := FacilityDamageBridge.apply_intent(
			bridge_state_next,
			intent
		)
		if not bool(applied.get("accepted", false)):
			var fizzle_reason := str(applied.get("reason_code", ""))
			var fizzle_receipt := (
				applied.get("receipt", {}) as Dictionary
			).duplicate(true)
			if (
				fizzle_reason not in [
					"facility_combat_damage_target_missing",
					"facility_combat_damage_target_not_occupied",
					"facility_combat_damage_generation_stale",
				]
				or not bool(
					FacilityDamageBridge.receipt_validation_report(
						fizzle_receipt
					).get("valid", false)
				)
			):
				return applied
			# A previously valid target can disappear earlier in the same atomic
			# combat boundary. Commit one zero-damage Fizzle Receipt and never
			# retarget; replay returns this receipt without a second effect.
			processed_next[receipt_key] = {
				"fingerprint": fingerprint,
				"receipt": fizzle_receipt,
			}
			receipts.append(fizzle_receipt)
			fizzle_receipt_count += 1
			continue
		bridge_state_next = (
			applied.get("state", {}) as Dictionary
		).duplicate(true)
		var bridged_slots := applied.get(
			"facility_slots",
			[]
		) as Array
		var bridged_batch := PublicActionBatchCore.replace_facility_slots(
			public_batch_state,
			bridged_slots
		)
		if bridged_batch.is_empty():
			return {
				"accepted": false,
				"reason_code": "facility_damage_public_batch_slot_replace_failed",
			}
		public_batch_state = bridged_batch
		facility_state = PublicActionBatchCore.facility_substate(
			public_batch_state
		)
		var receipt := (
			applied.get("receipt", {}) as Dictionary
		).duplicate(true)
		processed_next[receipt_key] = {
			"fingerprint": fingerprint,
			"receipt": receipt,
		}
		receipts.append(receipt)
		committed_receipt_count += 1
	var replaced := public_batch_state
	if replaced.is_empty():
		return {
			"accepted": false,
			"reason_code": "facility_damage_public_batch_replace_failed",
		}
	_processed_facility_damage_intents = processed_next
	_facility_damage_bridge_state = bridge_state_next
	_combat_facility_damage_receipt_count += committed_receipt_count
	_combat_facility_damage_fizzle_count += fizzle_receipt_count
	return {
		"accepted": true,
		"reason_code": "facility_damage_intents_committed",
		"public_batch_state": replaced,
		"receipts": receipts,
	}


func _build_facility_damage_bridge_state(
	facility_state: Dictionary
) -> Dictionary:
	var players := (
		facility_state.get("player_ids", []) as Array
	).duplicate()
	var hidden_order := (
		facility_state.get(
			"frozen_hidden_lead_order_at_batch_lock",
			[]
		) as Array
	).duplicate()
	if players.is_empty() or hidden_order.is_empty():
		return {}
	var empty_queues := {}
	for player_id_variant in players:
		empty_queues[str(player_id_variant)] = []
	var bridge_token := str(
		facility_state.get("batch_id", "")
	).sha256_text().left(24)
	var safe_state := FacilityCore.lock_batch(
		"batch.v075.combat.bridge.%s" % bridge_token,
		players,
		hidden_order,
		empty_queues,
		_facility_slots_from_state(facility_state),
		bool(facility_state.get(
			"production_runtime_connected",
			false
		))
	)
	if safe_state.is_empty() or str(
		safe_state.get("status", "")
	) != "resolved":
		return {}
	return FacilityDamageBridge.create_state(safe_state)


func _facility_slots_from_state(facility_state: Dictionary) -> Array:
	var slots := facility_state.get("facility_slots", {}) as Dictionary
	var slot_ids: Array[String] = []
	for slot_id_variant in slots.keys():
		slot_ids.append(str(slot_id_variant))
	slot_ids.sort()
	var result: Array = []
	for slot_id in slot_ids:
		result.append(
			(slots.get(slot_id, {}) as Dictionary).duplicate(true)
		)
	return result

func _public_facilities_from_batch_state(state: Dictionary) -> Array:
	var facility_state := state.get("facility_substate", {}) as Dictionary
	if facility_state.is_empty():
		return []
	var slots := facility_state.get("facility_slots", {}) as Dictionary
	var slot_ids: Array[String] = []
	for slot_id_variant in slots.keys():
		slot_ids.append(str(slot_id_variant))
	slot_ids.sort()
	var rows: Array = []
	for slot_id in slot_ids:
		var row := _v075_public_facility_row(
			slots.get(slot_id, {}) as Dictionary
		)
		if _facility_is_publicly_occupied(row):
			rows.append(row)
	return rows


func _public_action_receipt(
	action_receipt: Dictionary,
	combat_result: Dictionary,
	resolved: bool
) -> Dictionary:
	var domain := str(action_receipt.get("action_domain", "facility"))
	var outcome_id := str(action_receipt.get("outcome_id", ""))
	var reason_code := str(action_receipt.get("reason_code", ""))
	if domain in ["monster", "military"]:
		outcome_id = (
			"%s_action_resolved" % domain
			if resolved
			else "%s_action_fizzled" % domain
		)
		reason_code = str(combat_result.get("reason_code", reason_code))
	return {
		"accepted": true,
		"combat_receipt_id": str(action_receipt.get("receipt_id", "")),
		"anonymous_action_id": str(action_receipt.get(
			"anonymous_action_id",
			""
		)),
		"action_domain": domain,
		"event_kind": str(combat_result.get("event_kind", "")),
		"outcome_id": outcome_id,
		"reason_code": reason_code,
		"facility_created": bool(action_receipt.get("facility_created", false)),
		"facility_upgraded": bool(action_receipt.get("facility_upgraded", false)),
		"facility_repaired": bool(action_receipt.get("facility_repaired", false)),
		"asset_reservation_released": not resolved,
		"normal_card_destination": "discard",
		"action_slot_refunded": false,
		"combat_public_result": (
			combat_result.get("combat_receipt", {}) as Dictionary
		).duplicate(true),
	}


func _publish_combat_event(
	event_kind: String,
	payload: Dictionary,
	receipt_id: String
) -> void:
	if event_kind.is_empty():
		return
	var stable_id := receipt_id
	if stable_id.is_empty():
		stable_id = "combat.public.%06d" % (_combat_public_receipt_count + 1)
	var receipt := _public_combat_payload(payload)
	receipt["combat_receipt_id"] = stable_id
	receipt["event_kind"] = event_kind
	receipt["ruleset_id"] = V075_RULESET_ID
	receipt["batch_id"] = _batch_id()
	_combat_public_receipt_count += 1
	_combat_public_history.append(receipt.duplicate(true))
	resolution_presented.emit(receipt.duplicate(true))


func consume_combat_presentation_cue(cue: Dictionary) -> Dictionary:
	return _combat_telemetry_bridge.call(
		"consume_public_cue",
		cue,
		_batch_id()
	) as Dictionary


func combat_presentation_consumer() -> Node:
	return _combat_presentation_consumer


func _connect_combat_observers() -> void:
	if not is_instance_valid(_combat_presentation_consumer):
		_combat_presentation_consumer = CombatPresentationConsumer.new()
		_combat_presentation_consumer.name = "V075CombatPresentationConsumer"
		add_child(_combat_presentation_consumer)
	var telemetry_receipt := Callable(
		_combat_telemetry_bridge,
		"consume_public_receipt"
	)
	if not resolution_presented.is_connected(telemetry_receipt):
		resolution_presented.connect(telemetry_receipt)
	var presentation_receipt := Callable(
		_combat_presentation_consumer,
		"consume_receipt"
	)
	if not resolution_presented.is_connected(presentation_receipt):
		resolution_presented.connect(presentation_receipt)
	var telemetry_cue := Callable(
		_combat_telemetry_bridge,
		"consume_public_cue"
	)
	if not _combat_presentation_consumer.is_connected(
		"presentation_cue_ready",
		telemetry_cue
	):
		_combat_presentation_consumer.connect(
			"presentation_cue_ready",
			telemetry_cue
		)


func _emit_facility_damage_events(receipts: Array) -> void:
	for receipt_variant in receipts:
		var receipt := receipt_variant as Dictionary
		var payload := receipt.duplicate(true)
		payload["facility_type"] = str(
			receipt.get(
				"facility_type",
				receipt.get("target_facility_type", "")
			)
		)
		payload["damage_amount"] = int(receipt.get("applied_damage", 0))
		payload["damage_before"] = int(
			receipt.get("damage_points_before", 0)
		)
		payload["damage_after"] = int(
			receipt.get("damage_points_after", 0)
		)
		payload["facility_damage_state"] = "damaged"
		if not bool(receipt.get("accepted", false)):
			payload["facility_damage_state"] = "fizzled"
			_publish_combat_event(
				"facility_combat_damage_fizzled",
				payload,
				"facility.fizzle.%s.%s" % [
					str(receipt.get("combat_receipt_id", "")),
					str(receipt.get("target_facility_id", "")),
				]
			)
			continue
		if bool(receipt.get("facility_destroyed", false)):
			payload["facility_damage_state"] = "destroyed"
			payload["destroyed"] = true
		_publish_combat_event(
			"facility_combat_damaged",
			payload,
			"facility.%s.%s" % [
				str(receipt.get("combat_receipt_id", "")),
				str(receipt.get("target_facility_id", "")),
			]
		)


func _capture_combat_transaction_state() -> Dictionary:
	return {
		"facility_damage_bridge_state": (
			_facility_damage_bridge_state.duplicate(true)
		),
		"processed_facility_damage_intents": (
			_processed_facility_damage_intents.duplicate(true)
		),
		"combat_facility_damage_receipt_count": (
			_combat_facility_damage_receipt_count
		),
		"combat_facility_damage_fizzle_count": (
			_combat_facility_damage_fizzle_count
		),
		"combat_public_receipt_count": _combat_public_receipt_count,
		"combat_public_history": _combat_public_history.duplicate(true),
	}


func _restore_combat_transaction_state(checkpoint: Dictionary) -> void:
	_facility_damage_bridge_state = (
		checkpoint.get("facility_damage_bridge_state", {}) as Dictionary
	).duplicate(true)
	_processed_facility_damage_intents = (
		checkpoint.get(
			"processed_facility_damage_intents",
			{}
		) as Dictionary
	).duplicate(true)
	_combat_facility_damage_receipt_count = int(
		checkpoint.get("combat_facility_damage_receipt_count", 0)
	)
	_combat_facility_damage_fizzle_count = int(
		checkpoint.get("combat_facility_damage_fizzle_count", 0)
	)
	_combat_public_receipt_count = int(
		checkpoint.get("combat_public_receipt_count", 0)
	)
	_combat_public_history = (
		checkpoint.get("combat_public_history", []) as Array
	).duplicate(true)


func _rollback_combat_transaction(
	combat_checkpoint: Dictionary,
	runtime_checkpoint: Dictionary
) -> Dictionary:
	var combat_result := {}
	if (
		is_instance_valid(_combat_owner)
		and _combat_owner.has_method("rollback_checkpoint")
		and not combat_checkpoint.is_empty()
	):
		combat_result = _combat_owner.call(
			"rollback_checkpoint",
			combat_checkpoint
		) as Dictionary
	_restore_combat_transaction_state(runtime_checkpoint)
	var accepted := _rollback_result_accepted(combat_result)
	return {
		"accepted": accepted,
		"reason_code": (
			"combat_transaction_rolled_back"
			if accepted
			else "combat_owner_rollback_failed"
		),
		"combat_result": combat_result.duplicate(true),
	}


func _public_combat_payload(source: Dictionary) -> Dictionary:
	var result := {}
	var public_target := source.get("public_target", {}) as Dictionary
	var public_result := source.get("public_result", {}) as Dictionary
	for field_name in PUBLIC_COMBAT_FIELDS:
		if source.has(field_name):
			result[field_name] = _pure_copy(source.get(field_name))
		elif public_target.has(field_name):
			result[field_name] = _pure_copy(public_target.get(field_name))
		elif public_result.has(field_name):
			result[field_name] = _pure_copy(public_result.get(field_name))
	return result


func _combat_player_private_facts(viewer_id: String) -> Dictionary:
	var military_selected := false
	for card_variant in (_dbg_projection(viewer_id).get(
		"facts",
		{}
	) as Dictionary).get("hand", []) as Array:
		if CardDefinitionsV075.card_domain(
			str((card_variant as Dictionary).get("card_type", ""))
		) == "military":
			military_selected = true
			break
	var has_region := false
	var has_monster := false
	var military_options: Array[Dictionary] = []
	for option_variant in legal_card_actions(viewer_id):
		var option := option_variant as Dictionary
		if str(option.get("action_domain", "")) != "military":
			continue
		military_options.append(
			_military_private_option(option, viewer_id)
		)
		if str(option.get("task_kind", "")) == "assault_region":
			has_region = true
		elif str(option.get("task_kind", "")) == "assault_monster":
			has_monster = true
	return {
		"military_card_selected": military_selected,
		"can_assault_region": has_region,
		"can_assault_monster": has_monster,
		"military_options": military_options,
	}


func _combat_ai_private_facts(actor_id: String) -> Dictionary:
	var monster_options_by_card: Dictionary = {}
	var military_options_by_card: Dictionary = {}
	var military_options: Array[Dictionary] = []
	for option_variant in legal_card_actions(actor_id):
		var option := option_variant as Dictionary
		var card_id := str(option.get("card_instance_id", ""))
		var domain := str(option.get("action_domain", ""))
		if domain == "monster":
			var default_row := {
				"card_instance_id": card_id,
				"card_definition_id": str(option.get("card_definition_id", "")),
				"card_rank": int(option.get("card_rank", 0)),
				"legal_modes": [],
				"prebound_target_by_mode": {},
			}
			var row := monster_options_by_card.get(
				card_id,
				default_row
			) as Dictionary
			var mode := str(option.get("monster_card_mode", ""))
			var legal_modes: Array = []
			var legal_modes_value: Variant = row.get("legal_modes", [])
			if legal_modes_value is Array:
				legal_modes = (legal_modes_value as Array).duplicate(true)
			if mode not in legal_modes:
				legal_modes.append(mode)
			row["legal_modes"] = legal_modes
			var targets: Dictionary = {}
			var targets_value: Variant = row.get(
				"prebound_target_by_mode",
				{}
			)
			if targets_value is Dictionary:
				targets = (targets_value as Dictionary).duplicate(true)
			targets[mode] = (
				str(option.get("target_region_id", ""))
				if mode == "DEPLOY_NEW"
				else str(option.get("target_source_instance_id", ""))
			)
			row["prebound_target_by_mode"] = targets
			monster_options_by_card[card_id] = row
		elif domain == "military":
			var private_option := _military_private_option(option, actor_id)
			military_options.append(private_option)
			var default_row := {
				"card_instance_id": card_id,
				"card_definition_id": str(option.get("card_definition_id", "")),
				"legal_task_kinds": [],
				"options": [],
			}
			var row := military_options_by_card.get(
				card_id,
				default_row
			) as Dictionary
			var task := str(option.get("task_kind", ""))
			var task_kinds: Array = []
			var task_kinds_value: Variant = row.get("legal_task_kinds", [])
			if task_kinds_value is Array:
				task_kinds = (task_kinds_value as Array).duplicate(true)
			if task not in task_kinds:
				task_kinds.append(task)
			row["legal_task_kinds"] = task_kinds
			var option_rows := row.get("options", []) as Array
			option_rows.append(private_option.duplicate(true))
			row["options"] = option_rows
			military_options_by_card[card_id] = row
	var owned: Array = []
	var zone := _v075_owner_skill_zone(
		actor_id,
		_public_occupied_facilities()
	)
	for source_variant in zone:
		var source := (source_variant as Dictionary).duplicate(true)
		var skills: Array = []
		var source_skills: Variant = source.get("skills", [])
		if source_skills is Array:
			for skill_variant in source_skills as Array:
				var skill := (skill_variant as Dictionary).duplicate(true)
				var contract := skill.get("target_contract", {}) as Dictionary
				skill["target_contract"] = _ai_target_contract(
					str(contract.get("target_kind", ""))
				)
				skills.append(skill)
		source["private_skills"] = skills
		source.erase("skills")
		owned.append(source)
	var asset_view := ASSET_BATCH_CORE.monster_skill_available_asset_view(
		_asset_state,
		actor_id
	)
	return {
		"viewer_player_id": actor_id,
		"monster_card_options": monster_options_by_card.values(),
		"military_card_options": military_options_by_card.values(),
		"military_options": military_options,
		"owned_monsters": owned,
		"available_unreserved_assets": (
			asset_view.get("own_available_assets", {}) as Dictionary
		).duplicate(true),
	}


func _combat_ai_public_facts() -> Dictionary:
	return {
		"phase": str(_combat_owner.call("debug_snapshot").get(
			"phase",
			"batch_active"
		)),
		"facilities": _public_occupied_facilities(),
		"monsters": _v075_public_monsters(),
		"regions": _runtime_region_ids(),
	}


func _military_private_option(
	option: Dictionary,
	owner_player_id: String
) -> Dictionary:
	var task_kind := str(option.get("task_kind", ""))
	var target_monster_id := str(option.get(
		"target_monster_source_instance_id",
		""
	))
	var target_generation := int(option.get("target_source_generation", 0))
	if task_kind == "assault_monster" and not target_monster_id.is_empty():
		for monster_variant in _v075_public_monsters():
			var monster := monster_variant as Dictionary
			if str(monster.get("source_instance_id", "")) == target_monster_id:
				target_generation = int(monster.get("source_generation", 0))
				break
	var launch_region_id := ""
	var launch_regions: Array[String] = []
	for facility_variant in _public_occupied_facilities():
		var facility := facility_variant as Dictionary
		if (
			_facility_owner_id(facility) == owner_player_id
			and str(facility.get("status", "active")) != "destroyed"
		):
			var region_id := str(facility.get("region_id", ""))
			if not region_id.is_empty():
				launch_regions.append(region_id)
	launch_regions.sort()
	if not launch_regions.is_empty():
		launch_region_id = launch_regions[0]
	var primary_color := str(option.get("primary_color", ""))
	var primary_cost := maxi(0, int(option.get("asset_cost", 0)))
	var asset_cost_by_color := {}
	if not primary_color.is_empty() and primary_cost > 0:
		asset_cost_by_color[primary_color] = primary_cost
	return {
		"option_id": str(option.get("option_id", "")),
		"owner_player_id": owner_player_id,
		"card_instance_id": str(option.get("card_instance_id", "")),
		"card_definition_id": str(option.get("card_definition_id", "")),
		"card_generation": maxi(1, int(option.get("card_generation", 1))),
		"target_slot_id": str(option.get("target_slot_id", "")),
		"task_kind": task_kind,
		"target_region_id": str(option.get("target_region_id", "")),
		"target_monster_source_instance_id": target_monster_id,
		"target_source_generation": target_generation,
		"launch_region_id": launch_region_id,
		"asset_cost_by_color": asset_cost_by_color,
		"enabled": not launch_region_id.is_empty(),
		"disabled_reason": (
			"none" if not launch_region_id.is_empty()
			else "owned_launch_facility_required"
		),
		"action_domain": "military",
	}


func _auto_queue_and_lock(actor_id: String) -> Dictionary:
	if bool(_locked_by_player.get(actor_id, false)):
		return {
			"accepted": true,
			"reason_code": "submission_already_locked",
			"actor_id": actor_id,
		}
	if actor_id == _local_player_id and not _automate_local_human:
		if _clock_msec >= _submission_deadline_msec:
			_clock_msec = maxi(
				_opened_at_msec,
				_submission_deadline_msec - 1
			)
		return lock_player_submission(actor_id)
	_auto_request_private_skill(actor_id)
	var queue := _queued_by_player.get(actor_id, []) as Array
	if queue.is_empty():
		var acquisition := _auto_acquire_track_item(actor_id)
		if not bool(acquisition.get("accepted", false)):
			return acquisition
		var legal := _auto_legal_actions(actor_id)
		for _action_index in range(V075_AUTO_ACTION_LIMIT):
			queue = _queued_by_player.get(actor_id, []) as Array
			var available := _auto_available_actions(actor_id, queue, legal)
			if available.is_empty():
				break
			var preferred := _preferred_v075_ai_action(available, actor_id)
			# A selector may decline every currently available binding. Lock the
			# legal empty submission instead of creating an invalid card target.
			if preferred.is_empty():
				break
			var action_domain := str(preferred.get("action_domain", "facility"))
			var combat_binding := (
				preferred
				if action_domain in ["monster", "military"]
				else {}
			)
			var queue_receipt := queue_card_action(
				actor_id,
				str(preferred.get("card_instance_id", "")),
				str(preferred.get("target_slot_id", "")),
				combat_binding
			)
			if not bool(queue_receipt.get("accepted", false)):
				_combat_ai_invalid_target_count += 1
				return queue_receipt
			if str(preferred.get("action_domain", "")) == "military":
				if str(preferred.get("task_kind", "")) == "assault_region":
					_combat_ai_military_region_count += 1
				else:
					_combat_ai_military_monster_count += 1
	return lock_player_submission(actor_id)


func _auto_available_actions(
	actor_id: String,
	queue: Array,
	legal: Array
) -> Array:
	var inherited := super._auto_available_actions(actor_id, queue, legal)
	var reserve := _v075_combat_asset_reserve_by_color(
		actor_id,
		queue,
		legal
	)
	var result: Array = []
	for option_variant in inherited:
		var option := option_variant as Dictionary
		if str(option.get("action_domain", "facility")) in [
			"monster",
			"military",
		] or _v075_action_preserves_combat_asset_reserve(
			actor_id,
			option,
			queue,
			reserve
		):
			result.append(option.duplicate(true))
	return result


func _v075_combat_asset_reserve_by_color(
	actor_id: String,
	queue: Array,
	legal: Array
) -> Dictionary:
	var reserve := {}
	for color_id in COLORS:
		reserve[color_id] = 0
	var players := _asset_state.get("players", {}) as Dictionary
	var available := (
		players.get(actor_id, {}) as Dictionary
	).get("assets", {}) as Dictionary
	var queued_card_ids := {}
	for binding_variant in queue:
		queued_card_ids[str((binding_variant as Dictionary).get(
			"card_instance_id",
			""
		))] = true
	# Keep one affordable combat opportunity alive per player/batch. Reserving
	# one card per color can starve the facility economy and is not the intended
	# first-sample policy.
	var selected_card_id := ""
	var selected_color := ""
	var selected_cost := 0
	var selected_domain := ""
	var seen_card_ids: Dictionary = {}
	for option_variant in legal:
		var option := option_variant as Dictionary
		var domain := str(option.get("action_domain", ""))
		if domain not in ["monster", "military"]:
			continue
		var card_id := str(option.get("card_instance_id", ""))
		if (
			card_id.is_empty()
			or queued_card_ids.has(card_id)
			or seen_card_ids.has(card_id)
		):
			continue
		seen_card_ids[card_id] = true
		var card := _card_in_hand(actor_id, card_id)
		if card.is_empty():
			continue
		var color_id := str(card.get("primary_color", ""))
		var cost := maxi(0, int(card.get("primary_asset_cost", 0)))
		if (
			color_id not in COLORS
			or cost == 0
			or cost > int(available.get(color_id, 0))
		):
			continue
		var better := selected_card_id.is_empty()
		if not better and cost < selected_cost:
			better = true
		if not better and cost == selected_cost:
			if domain == "monster" and selected_domain != "monster":
				better = true
			elif domain == selected_domain and card_id < selected_card_id:
				better = true
		if better:
			selected_card_id = card_id
			selected_color = color_id
			selected_cost = cost
			selected_domain = domain
	if not selected_card_id.is_empty():
		reserve[selected_color] = selected_cost
	return reserve


func _v075_action_preserves_combat_asset_reserve(
	actor_id: String,
	option: Dictionary,
	queue: Array,
	reserve: Dictionary
) -> bool:
	var players := _asset_state.get("players", {}) as Dictionary
	var player := players.get(actor_id, {}) as Dictionary
	var available := player.get("assets", {}) as Dictionary
	var committed := {}
	for color_id in COLORS:
		committed[color_id] = 0
	for binding_variant in queue:
		var binding := binding_variant as Dictionary
		var queued_card := _card_in_hand(
			actor_id,
			str(binding.get("card_instance_id", ""))
		)
		var queued_color := str(queued_card.get("primary_color", ""))
		if queued_color in COLORS:
			committed[queued_color] = int(committed.get(
				queued_color,
				0
			)) + int(queued_card.get("primary_asset_cost", 0))
	var candidate := _card_in_hand(
		actor_id,
		str(option.get("card_instance_id", ""))
	)
	var candidate_color := str(candidate.get("primary_color", ""))
	if candidate_color not in COLORS:
		return false
	committed[candidate_color] = int(committed.get(
		candidate_color,
		0
	)) + int(candidate.get("primary_asset_cost", 0))
	for color_id in COLORS:
		if (
			int(committed.get(color_id, 0))
			+ int(reserve.get(color_id, 0))
			> int(available.get(color_id, 0))
		):
			return false
	return true


func _auto_request_private_skill(actor_id: String) -> void:
	if not _combat_initialized:
		return
	# Private skills have a separate decision surface. Card transitions and
	# military missions must not hide a ready skill from the AI's instant lane.
	var chosen := _combat_ai_adapter.call(
		"choose_private_skill",
		_combat_ai_private_facts(actor_id),
		_combat_ai_public_facts()
	) as Dictionary
	if not bool(chosen.get("accepted", false)):
		return
	var action := chosen.get("action", {}) as Dictionary
	if str(action.get("action_kind", "")) != "monster_private_skill":
		return
	var result := request_private_monster_skill(actor_id, action)
	if bool(result.get("accepted", false)):
		_combat_ai_private_skill_count += 1
	else:
		_combat_ai_invalid_target_count += 1


func _auto_maintenance(actor_id: String) -> void:
	var facts := _dbg_projection(actor_id).get("facts", {}) as Dictionary
	var pairs := facts.get("eligible_merge_pairs", []) as Array
	var advancing_monster_pair: Array = []
	var monster_pair: Array = []
	var warehouse_pair: Array = []
	var active_rank_by_family := {}
	for source_variant in _v075_public_monsters():
		var source := source_variant as Dictionary
		if (
			str(source.get("owner_player_id", "")) == actor_id
			and str(source.get("status", "")) in ["active", "downed"]
		):
			active_rank_by_family[str(source.get(
				"monster_family_id",
				""
			))] = int(source.get("rank", 0))
	for pair_variant in pairs:
		var pair := pair_variant as Array
		if pair.size() != 2:
			continue
		var left := _dbg_card_by_id(facts, str(pair[0]))
		var right := _dbg_card_by_id(facts, str(pair[1]))
		var left_domain := CardDefinitionsV075.card_domain(
			str(left.get("card_type", ""))
		)
		var right_domain := CardDefinitionsV075.card_domain(
			str(right.get("card_type", ""))
		)
		if left_domain == "monster" and right_domain == "monster":
			if monster_pair.is_empty():
				monster_pair = pair.duplicate()
			var family_id := CardDefinitionsV075.monster_family_id_from_card_type(
				str(left.get("card_type", ""))
			)
			if (
				active_rank_by_family.has(family_id)
				and int(left.get("level", 0)) + 1
				> int(active_rank_by_family.get(family_id, 0))
			):
				advancing_monster_pair = pair.duplicate()
				break
		elif (
			warehouse_pair.is_empty()
			and str(left.get("card_type", "")) == "warehouse"
			and str(right.get("card_type", "")) == "warehouse"
		):
			warehouse_pair = pair.duplicate()
	var selected_pair := advancing_monster_pair
	if selected_pair.is_empty():
		selected_pair = monster_pair
	if selected_pair.is_empty():
		selected_pair = warehouse_pair
	if selected_pair.is_empty() and not pairs.is_empty():
		selected_pair = (pairs[0] as Array).duplicate()
	if selected_pair.size() == 2:
		merge_normal_pair(
			actor_id,
			str(selected_pair[0]),
			str(selected_pair[1])
		)
	finish_maintenance(actor_id)


func _preferred_v075_ai_action(
	legal: Array,
	actor_id: String = ""
) -> Dictionary:
	var stable_actor_id := actor_id
	if stable_actor_id.is_empty() and not legal.is_empty():
		stable_actor_id = str(
			(legal[0] as Dictionary).get("actor_id", "")
		)
	var military_modes := ["assault_monster", "assault_region"]
	var stable_number := int(
		stable_actor_id.sha256_text().substr(0, 8).hex_to_int()
	)
	if (stable_number + _batch_number) % 2 == 0:
		military_modes = ["assault_region", "assault_monster"]
	var held_refresh_option_ids: Dictionary = {}
	for option_variant in legal:
		var option := option_variant as Dictionary
		if _v075_should_hold_monster_refresh(actor_id, option):
			held_refresh_option_ids[str(option.get("option_id", ""))] = true
	var domain_modes := [
		"monster:UPGRADE_EXISTING",
		"monster:REFRESH_EXISTING",
		"monster:DEPLOY_NEW",
		"monster:REPLACE_EXISTING",
	]
	for military_mode in military_modes:
		domain_modes.append("military:%s" % military_mode)
	for domain_mode in domain_modes:
		var parts: PackedStringArray = str(domain_mode).split(":")
		var matching: Array = []
		for option_variant in legal:
			var option := option_variant as Dictionary
			if str(option.get("action_domain", "")) != str(parts[0]):
				continue
			var mode := str(option.get(
				"monster_card_mode" if str(parts[0]) == "monster" else "task_kind",
				""
			))
			if mode == str(parts[1]):
				if (
					str(domain_mode) == "monster:REFRESH_EXISTING"
					and held_refresh_option_ids.has(str(option.get(
						"option_id",
						""
					)))
				):
					continue
				matching.append(option.duplicate(true))
		if not matching.is_empty():
			if str(domain_mode) == "monster:DEPLOY_NEW":
				return _preferred_monster_deployment_option(matching)
			return (matching[0] as Dictionary).duplicate(true)
	if held_refresh_option_ids.is_empty():
		return _preferred_v074_ai_action(legal)
	var fallback_legal: Array = []
	for option_variant in legal:
		var option := option_variant as Dictionary
		if not held_refresh_option_ids.has(str(option.get("option_id", ""))):
			fallback_legal.append(option.duplicate(true))
	if not fallback_legal.is_empty():
		return _preferred_v074_ai_action(fallback_legal)
	# Holding is a preference, not a deadlock permission. If the hand has no
	# other legal action, consume the refresh card through the normal authority.
	for option_variant in legal:
		var option := option_variant as Dictionary
		if held_refresh_option_ids.has(str(option.get("option_id", ""))):
			return option.duplicate(true)
	return {}


func _v075_should_hold_monster_refresh(
	actor_id: String,
	option: Dictionary
) -> bool:
	if (
		str(option.get("action_domain", "")) != "monster"
		or str(option.get("monster_card_mode", "")) != "REFRESH_EXISTING"
	):
		return false
	var card_definition := CardDefinitionsV075.definition(
		str(option.get("card_definition_id", ""))
	)
	if int(card_definition.get("level", 0)) != 1:
		return false
	if not _v075_actor_prefers_monster_upgrade(actor_id):
		return false
	var source_id := str(option.get("target_source_instance_id", ""))
	var source := _public_monster_by_id(source_id)
	if (
		source.is_empty()
		or str(source.get("owner_player_id", "")) != actor_id
		or str(source.get("status", "")) != "active"
		or int(source.get("rank", 0)) != 1
	):
		return false
	var family_id := CardDefinitionsV075.monster_family_id_from_card_type(
		str(card_definition.get("card_type", ""))
	)
	if family_id != str(source.get("monster_family_id", "")):
		return false
	var facts := _dbg_projection(actor_id).get("facts", {}) as Dictionary
	var matching_hand_count := 0
	for card_variant in facts.get("hand", []) as Array:
		var card := card_variant as Dictionary
		if str(card.get("merge_family_id", "")) == str(
			card_definition.get("merge_family_id", "")
		):
			matching_hand_count += 1
	return matching_hand_count >= 1


func _v075_actor_prefers_monster_upgrade(actor_id: String) -> bool:
	if actor_id.is_empty():
		return false
	for source_variant in _v075_public_monsters():
		var source := source_variant as Dictionary
		if (
			str(source.get("owner_player_id", "")) == actor_id
			and str(source.get("status", "")) in ["active", "downed"]
			and int(source.get("rank", 0)) == 1
		):
			return true
	return false


func _preferred_monster_deployment_option(options: Array) -> Dictionary:
	var topology := MonsterAutonomyCore.topology_snapshot_from_map_receipt(
		_map_genesis_receipt
	)
	if not bool(topology.get("accepted", false)):
		return (options[0] as Dictionary).duplicate(true)
	var facilities := _public_occupied_facilities()
	var best := {}
	var best_score := -2147483648
	var best_key := ""
	for option_variant in options:
		var option := option_variant as Dictionary
		var score := _monster_deployment_route_score(
			option,
			topology,
			facilities
		)
		var stable_key := "%s|%s|%s" % [
			str(option.get("card_instance_id", "")),
			str(option.get("target_region_id", "")),
			str(option.get("option_id", "")),
		]
		if (
			best.is_empty()
			or score > best_score
			or (score == best_score and stable_key < best_key)
		):
			best = option.duplicate(true)
			best_score = score
			best_key = stable_key
	return best


func _monster_deployment_route_score(
	option: Dictionary,
	topology: Dictionary,
	public_facilities: Array
) -> int:
	var card_definition := CardDefinitionsV075.definition(
		str(option.get("card_definition_id", ""))
	)
	var family_id := CardDefinitionsV075.monster_family_id_from_card_type(
		str(card_definition.get("card_type", ""))
	)
	var source_definition := CombatCatalog.monster_source_definition(family_id)
	if source_definition.is_empty():
		return 0
	var preferred_color := str(
		source_definition.get("preferred_industry_color", "")
	)
	var actor_id := str(option.get("actor_id", ""))
	var start_region_id := str(option.get("target_region_id", ""))
	var nearest_path: Array = []
	for facility_variant in public_facilities:
		var facility := facility_variant as Dictionary
		if (
			_facility_owner_id(facility) == actor_id
			or str(facility.get("industry_id", "")) != preferred_color
			or str(facility.get("status", "active")) == "destroyed"
		):
			continue
		var path := MonsterAutonomyCore.shortest_path(
			topology,
			start_region_id,
			str(facility.get("region_id", ""))
		)
		if path.is_empty():
			continue
		if nearest_path.is_empty() or path.size() < nearest_path.size():
			nearest_path = path
	if nearest_path.is_empty():
		return 0
	var hops := nearest_path.size() - 1
	var base_range := int(
		source_definition.get("base_detection_range_hops", 0)
	)
	var score := 0
	if hops >= 2 and hops <= base_range:
		score = 100000 + hops * 1000
	elif hops == 1:
		score = 80000
	elif hops > base_range:
		score = 50000 - hops * 100
	else:
		score = 10000
	if str(source_definition.get("movement_profile", "")) == "ground_trample":
		score += 10000
	if nearest_path.size() > 1:
		var first_edge_distance := MonsterAutonomyCore.path_distance_milli_arc(
			topology,
			[nearest_path[0], nearest_path[1]]
		)
		var rank := clampi(int(card_definition.get("level", 1)), 1, 4)
		var budgets := source_definition.get(
			"movement_budget_milli_arc_by_rank",
			[]
		) as Array
		if budgets.size() >= rank and first_edge_distance > 0:
			score += (
				5000
				if first_edge_distance <= int(budgets[rank - 1])
				else -5000
			)
	return score


func _private_skill_target_request(
	actor_id: String,
	source: Dictionary,
	skill: Dictionary,
	parameters: Dictionary
) -> Dictionary:
	var contract := skill.get("target_contract", {}) as Dictionary
	if contract.is_empty() and skill.get("target_contract", "") is String:
		contract = {
			"target_kind": {
				"self": "self_source",
				"enemy_facility": "enemy_public_facility",
				"enemy_monster": "enemy_public_monster",
				"region": "enemy_facilities_in_public_region",
			}.get(str(skill.get("target_contract", "")), "")
		}
	var target_kind := str(contract.get("target_kind", ""))
	if parameters.has("target_binding"):
		var binding := parameters.get("target_binding", {}) as Dictionary
		if binding.is_empty():
			return {}
		var binding_kind := str(binding.get("target_kind", ""))
		var binding_id := str(binding.get("target_id", ""))
		if binding_id.is_empty():
			return {}
		if target_kind == "self_source":
			var self_generation := int(binding.get(
				"target_source_generation",
				0
			))
			if binding_kind != "monster" or binding_id != str(
				source.get("source_instance_id", "")
			) or self_generation <= 0:
				return {}
			return {
				"target_kind": target_kind,
				"target_id": binding_id,
				"target_source_generation": self_generation,
			}
		if target_kind == "enemy_public_facility":
			var facility_generation := int(binding.get(
				"target_facility_generation",
				0
			))
			if (
				binding_kind != "facility"
				or str(binding.get("target_facility_id", "")) != binding_id
				or binding.has("target_region_id")
				or facility_generation <= 0
			):
				return {}
			return {
				"target_kind": target_kind,
				"target_id": binding_id,
				"target_facility_id": binding_id,
				"target_facility_generation": facility_generation,
			}
		if target_kind in [
			"enemy_facilities_in_public_region",
			"enemy_facilities_in_current_region",
		]:
			if (
				binding_kind != "region"
				or str(binding.get("target_region_id", "")) != binding_id
				or binding.has("target_facility_id")
			):
				return {}
			return {
				"target_kind": target_kind,
				"target_id": binding_id,
				"target_region_id": binding_id,
			}
		if target_kind == "enemy_public_monster":
			var monster_generation := int(binding.get(
				"target_source_generation",
				0
			))
			if (
				binding_kind != "monster"
				or str(binding.get(
					"target_monster_source_instance_id",
					binding_id
				)) != binding_id
				or monster_generation <= 0
			):
				return {}
			return {
				"target_kind": target_kind,
				"target_id": binding_id,
				"target_source_generation": monster_generation,
			}
		return {}
	var explicit_id := str(parameters.get(
		"target_id",
		parameters.get("target_facility_id", parameters.get(
			"target_monster_source_instance_id",
			parameters.get("target_region_id", "")
		))
	))
	if target_kind == "self_source":
		return {
			"target_kind": "self_source",
			"target_id": str(source.get("source_instance_id", "")),
			"target_source_generation": int(
				source.get("source_generation", 0)
			),
		}
	if target_kind == "enemy_public_facility":
		var facility_id := explicit_id
		if facility_id.is_empty():
			facility_id = str(source.get("tracked_facility_id", ""))
		if facility_id.is_empty():
			facility_id = _first_enemy_facility_id(actor_id)
		var facility := _public_facility_by_id(facility_id)
		return {
			"target_kind": target_kind,
			"target_id": facility_id,
			"target_facility_generation": int(
				facility.get("facility_generation", 0)
			),
		} if not facility.is_empty() else {}
	if target_kind in [
		"enemy_facilities_in_public_region",
		"enemy_facilities_in_current_region",
	]:
		var region_id := (
			str(source.get("region_id", ""))
			if target_kind == "enemy_facilities_in_current_region"
			else explicit_id
		)
		if region_id.is_empty():
			region_id = str(source.get("tracked_region_id", ""))
		if region_id.is_empty():
			region_id = _first_enemy_facility_region(actor_id)
		return {
			"target_kind": target_kind,
			"target_id": region_id,
			"target_region_id": region_id,
		} if not region_id.is_empty() else {}
	if target_kind == "enemy_public_monster":
		var monster_id := explicit_id
		if monster_id.is_empty():
			for monster_variant in _v075_public_monsters():
				var monster := monster_variant as Dictionary
				if (
					str(monster.get("owner_player_id", "")) != actor_id
					and str(monster.get("status", "")) == "active"
				):
					monster_id = str(monster.get("source_instance_id", ""))
					break
		var monster := _public_monster_by_id(monster_id)
		return {
			"target_kind": target_kind,
			"target_id": monster_id,
			"target_source_generation": int(
				monster.get("source_generation", 0)
			),
		} if not monster.is_empty() else {}
	return {}


func _v075_public_monsters() -> Array:
	if (
		not is_instance_valid(_combat_owner)
		or not _combat_owner.has_method("public_monsters")
	):
		return []
	var value: Variant = _combat_owner.call("public_monsters")
	if value is Array:
		return (value as Array).duplicate(true)
	return []


func _v075_owner_skill_zone(
	owner_id: String,
	public_facilities: Array = []
) -> Array:
	if (
		not is_instance_valid(_combat_owner)
		or not _combat_owner.has_method("owner_private_skill_zone")
	):
		return []
	var value: Variant
	if (
		not public_facilities.is_empty()
		and _combat_owner.has_method(
			"owner_private_skill_zone_for_public_facts"
		)
	):
		value = _combat_owner.call(
			"owner_private_skill_zone_for_public_facts",
			owner_id,
			public_facilities
		)
	else:
		value = _combat_owner.call("owner_private_skill_zone", owner_id)
	if value is Array:
		return (value as Array).duplicate(true)
	return []


func _owner_skill_by_id(
	owner_id: String,
	source_id: String,
	skill_id: String
) -> Dictionary:
	for source_variant in _v075_owner_skill_zone(owner_id):
		var source := source_variant as Dictionary
		if str(source.get("source_instance_id", "")) != source_id:
			continue
		for skill_variant in source.get("skills", []) as Array:
			var skill := skill_variant as Dictionary
			if str(skill.get("skill_definition_id", "")) == skill_id:
				return skill.duplicate(true)
	return {}


func _public_monster_by_id(source_id: String) -> Dictionary:
	for source_variant in _v075_public_monsters():
		var source := source_variant as Dictionary
		if str(source.get("source_instance_id", "")) == source_id:
			return source.duplicate(true)
	return {}


func _public_facility_by_id(facility_id: String) -> Dictionary:
	for facility_variant in _public_occupied_facilities():
		var facility := facility_variant as Dictionary
		if str(facility.get("facility_id", "")) == facility_id:
			return facility.duplicate(true)
	return {}


func _first_enemy_facility_id(actor_id: String) -> String:
	var ids: Array[String] = []
	for facility_variant in _public_occupied_facilities():
		var facility := facility_variant as Dictionary
		if (
			_facility_owner_id(facility) != actor_id
			and str(facility.get("status", "active")) != "destroyed"
		):
			ids.append(str(facility.get("facility_id", "")))
	ids.sort()
	return ids[0] if not ids.is_empty() else ""


func _first_enemy_facility_region(actor_id: String) -> String:
	var ids: Array[String] = []
	for facility_variant in _public_occupied_facilities():
		var facility := facility_variant as Dictionary
		var region_id := str(facility.get("region_id", ""))
		if (
			_facility_owner_id(facility) != actor_id
			and str(facility.get("status", "active")) != "destroyed"
			and not region_id.is_empty()
			and region_id not in ids
		):
			ids.append(region_id)
	ids.sort()
	return ids[0] if not ids.is_empty() else ""


func _facility_owner_id(facility: Dictionary) -> String:
	return str(facility.get(
		"owner_player_id",
		facility.get("owner_id", facility.get("owner_public_id", ""))
	))


func _ai_target_contract(target_kind: String) -> String:
	return {
		"self_source": "self",
		"enemy_public_facility": "enemy_facility",
		"enemy_public_monster": "enemy_monster",
		"enemy_facilities_in_public_region": "region",
		"enemy_facilities_in_current_region": "region",
	}.get(target_kind, "none")


func _pure_copy(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value
