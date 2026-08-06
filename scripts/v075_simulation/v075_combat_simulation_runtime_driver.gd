extends "res://scripts/v075_runtime/v075_runtime_owner.gd"
class_name V075CombatSimulationRuntimeDriver

const AssetBatchCore := preload(
	"res://scripts/v07_semantic/v07_asset_batch_core.gd"
)
const CombatCardDefinitions := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)
const ProfilePublicActionBatchCore := preload(
	"res://scripts/v075/runtime/v075_public_action_batch_core.gd"
)

const SIMULATION_PROCESS_DELTA_SECONDS := 1.0

var _simulation_legal_card_actions_call_count: int = 0
var _simulation_legal_card_actions_cache_hit_count: int = 0
var _simulation_card_lookup_cache_hit_count: int = 0
var _simulation_private_skill_fast_skip_count: int = 0
var _simulation_presentation_observer_disabled: bool = true
var _simulation_process_call_count: int = 0
var _simulation_phase_process_counts: Dictionary = {}
var _simulation_phase_process_usec: Dictionary = {}
var _simulation_cache_actor_id: String = ""
var _simulation_legal_cache_valid: bool = false
var _simulation_legal_cache: Array = []
var _simulation_last_legal_actions_by_actor: Dictionary = {}
var _simulation_card_cache: Dictionary = {}
var _simulation_card_last_zone: Dictionary = {}
var _simulation_monster_discard_ids: Dictionary = {}
var _simulation_military_discard_ids: Dictionary = {}
var _simulation_monster_hand_ids: Dictionary = {}
var _simulation_military_hand_ids: Dictionary = {}
var _simulation_monster_discard_to_hand_count: int = 0
var _simulation_military_discard_to_hand_count: int = 0
var _simulation_monster_legal_option_count: int = 0
var _simulation_military_legal_option_count: int = 0
var _simulation_direct_monster_legal_option_count: int = 0
var _simulation_direct_military_legal_option_count: int = 0
var _simulation_first_combat_legal_projection_gap: Dictionary = {}
var _simulation_military_affordable_option_count: int = 0
var _simulation_military_available_option_count: int = 0
var _simulation_military_filtered_option_count: int = 0
var _simulation_monster_prebind_rejection_count: int = 0
var _simulation_monster_prebind_accept_count: int = 0
var _simulation_monster_prebind_rejection_reasons: Dictionary = {}
var _simulation_military_filter_reasons: Dictionary = {}
var _simulation_first_monster_prebind_rejection: Dictionary = {}
var _simulation_first_monster_prebind_observation: Dictionary = {}
var _simulation_first_military_filter_rejection: Dictionary = {}
var _simulation_monster_queued_action_ids: Dictionary = {}
var _simulation_military_queued_action_ids: Dictionary = {}
var _simulation_max_queued_actions_per_player: int = 0
var _simulation_pending_skill_request_keys: Array[String] = []
var _simulation_committed_skill_uses_by_key: Dictionary = {}
var _simulation_private_skill_reuse_commit_count: int = 0
var _simulation_observed_skill_commit_count: int = 0
var _simulation_observed_skill_fizzle_count: int = 0
var _simulation_runtime_failure: Dictionary = {}
var _simulation_profile_public_core_usec: int = 0
var _simulation_profile_resolve_total_usec: int = 0
var _simulation_profile_sync_facility_usec: int = 0
var _simulation_profile_sync_asset_usec: int = 0
var _simulation_profile_resolution_count: int = 0
var _simulation_profile_auto_queue_usec: int = 0
var _simulation_profile_ai_observation_usec: int = 0
var _simulation_profile_legal_actions_usec: int = 0
var _simulation_profile_available_actions_usec: int = 0
var _simulation_profile_acquisition_usec: int = 0
var _simulation_profile_lock_usec: int = 0
var _simulation_profile_enabled: bool = false


func run_simulation_until_settled(max_steps: int = 2000) -> Dictionary:
	if _match_id.is_empty():
		return _reject("match_not_started")
	_accelerated = true
	_automate_local_human = true
	_simulation_profile_enabled = "--profile-resolution" in OS.get_cmdline_user_args()
	var was_coalesced: bool = _projection_emit_coalesced
	_projection_emit_coalesced = true
	var steps: int = 0
	while _phase not in ["settled", "failed"] and steps < max_steps:
		var phase_before: String = _phase
		_simulation_phase_process_counts[phase_before] = int(
			_simulation_phase_process_counts.get(phase_before, 0)
		) + 1
		# The inherited production process owns every phase and receipt transition.
		var phase_started := Time.get_ticks_usec()
		super._process(SIMULATION_PROCESS_DELTA_SECONDS)
		_simulation_phase_process_usec[phase_before] = int(
			_simulation_phase_process_usec.get(phase_before, 0)
		) + Time.get_ticks_usec() - phase_started
		steps += 1
		_simulation_process_call_count += 1
		_observe_private_skill_resolution_deltas()
	_projection_emit_coalesced = was_coalesced
	if _projection_emit_pending and not _projection_emit_coalesced:
		_projection_emit_pending = false
		_emit_local_state()
	return {
		"accepted": _phase == "settled",
		"reason_code": (
			"sample_match_completed"
			if _phase == "settled"
			else "sample_match_step_limit_reached"
		),
		"steps": steps,
		"phase": _phase,
		"final_settlement": _final_settlement.duplicate(true),
		"debug": debug_snapshot(),
		"simulation_acceleration": {
			"mode": "inherited_process_submission_window_delta",
			"process_delta_seconds": SIMULATION_PROCESS_DELTA_SECONDS,
			"accelerated_clock_delta_seconds": (
				SIMULATION_PROCESS_DELTA_SECONDS * 30.0
			),
			"authority_method": "V073SampleRuntimeOwner._process",
			"runtime_owner_path": "V075RuntimeOwner",
			"direct_state_injection_count": 0,
		},
	}


func _fail(reason_code: String, detail: Dictionary) -> Dictionary:
	if _simulation_runtime_failure.is_empty():
		var nested_reasons: Array[String] = []
		_collect_reason_codes(detail, nested_reasons, 0)
		_simulation_runtime_failure = {
			"reason_code": reason_code,
			"nested_reason_codes": nested_reasons,
			"phase": _phase,
			"batch_number": _batch_number,
		}
	return super._fail(reason_code, detail)


func resolve_next_action() -> Dictionary:
	if _simulation_profile_enabled:
		var core_started := Time.get_ticks_usec()
		ProfilePublicActionBatchCore.resolve_next_authority_owned(_facility_state)
		_simulation_profile_public_core_usec += (
			Time.get_ticks_usec() - core_started
		)
	var started := Time.get_ticks_usec()
	var result := super.resolve_next_action()
	_simulation_profile_resolve_total_usec += Time.get_ticks_usec() - started
	_simulation_profile_resolution_count += 1
	return result


func _sync_facility_slots() -> void:
	if not _simulation_profile_enabled:
		super._sync_facility_slots()
		return
	var started := Time.get_ticks_usec()
	super._sync_facility_slots()
	_simulation_profile_sync_facility_usec += Time.get_ticks_usec() - started


func _sync_asset_balances() -> void:
	if not _simulation_profile_enabled:
		super._sync_asset_balances()
		return
	var started := Time.get_ticks_usec()
	super._sync_asset_balances()
	_simulation_profile_sync_asset_usec += Time.get_ticks_usec() - started


func ai_observation(actor_id: String) -> Dictionary:
	if not _simulation_profile_enabled:
		return super.ai_observation(actor_id)
	var started := Time.get_ticks_usec()
	var result := super.ai_observation(actor_id)
	_simulation_profile_ai_observation_usec += Time.get_ticks_usec() - started
	return result


func _auto_acquire_track_item(actor_id: String) -> Dictionary:
	if not _simulation_profile_enabled:
		return super._auto_acquire_track_item(actor_id)
	var started := Time.get_ticks_usec()
	var result := super._auto_acquire_track_item(actor_id)
	_simulation_profile_acquisition_usec += Time.get_ticks_usec() - started
	return result


func lock_player_submission(actor_id: String) -> Dictionary:
	if not _simulation_profile_enabled:
		return super.lock_player_submission(actor_id)
	var started := Time.get_ticks_usec()
	var result := super.lock_player_submission(actor_id)
	_simulation_profile_lock_usec += Time.get_ticks_usec() - started
	return result


func _collect_reason_codes(
	value: Variant,
	result: Array[String],
	depth: int
) -> void:
	if depth > 5:
		return
	if value is Dictionary:
		var row := value as Dictionary
		if row.has("reason_code"):
			var reason := str(row.get("reason_code", ""))
			if not reason.is_empty() and reason not in result:
				result.append(reason)
		for child_variant in row.values():
			_collect_reason_codes(child_variant, result, depth + 1)
	elif value is Array:
		for child_variant in value as Array:
			_collect_reason_codes(child_variant, result, depth + 1)


func _combat_ai_private_facts(actor_id: String) -> Dictionary:
	var monster_options_by_card: Dictionary = {}
	var military_options_by_card: Dictionary = {}
	for option_variant in legal_card_actions(actor_id):
		if not (option_variant is Dictionary):
			continue
		var option: Dictionary = option_variant as Dictionary
		var card_id: String = str(option.get("card_instance_id", ""))
		var domain: String = str(option.get("action_domain", ""))
		if domain == "monster":
			var existing_row: Variant = monster_options_by_card.get(card_id, {})
			var row: Dictionary = {}
			if existing_row is Dictionary:
				row = (existing_row as Dictionary).duplicate(true)
			else:
				row = {
					"card_instance_id": card_id,
					"card_definition_id": str(option.get("card_definition_id", "")),
					"card_rank": 1,
					"legal_modes": [],
					"prebound_target_by_mode": {},
				}
			var mode: String = str(option.get("monster_card_mode", ""))
			var legal_modes: Array = []
			var legal_modes_value: Variant = row.get("legal_modes", [])
			if legal_modes_value is Array:
				legal_modes = (legal_modes_value as Array).duplicate(true)
			if mode not in legal_modes:
				legal_modes.append(mode)
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
			row["legal_modes"] = legal_modes
			row["prebound_target_by_mode"] = targets
			monster_options_by_card[card_id] = row
		elif domain == "military":
			var existing_row: Variant = military_options_by_card.get(card_id, {})
			var row: Dictionary = {}
			if existing_row is Dictionary:
				row = (existing_row as Dictionary).duplicate(true)
			else:
				row = {
					"card_instance_id": card_id,
					"card_definition_id": str(option.get("card_definition_id", "")),
					"legal_task_kinds": [],
				}
			var task: String = str(option.get("task_kind", ""))
			var task_kinds: Array = []
			var task_kinds_value: Variant = row.get("legal_task_kinds", [])
			if task_kinds_value is Array:
				task_kinds = (task_kinds_value as Array).duplicate(true)
			if task not in task_kinds:
				task_kinds.append(task)
			row["legal_task_kinds"] = task_kinds
			military_options_by_card[card_id] = row
	var owned: Array = []
	var zone: Array = []
	var zone_value: Variant = _combat_owner.call(
		"owner_private_skill_zone",
		actor_id
	)
	if zone_value is Array:
		zone = (zone_value as Array).duplicate(true)
	elif zone_value is Dictionary:
		var zone_dictionary: Dictionary = zone_value as Dictionary
		var sources_value: Variant = zone_dictionary.get("sources", [])
		if sources_value is Array:
			zone = (sources_value as Array).duplicate(true)
	for source_variant in zone:
		if not (source_variant is Dictionary):
			continue
		var source: Dictionary = (source_variant as Dictionary).duplicate(true)
		var skills: Array = []
		var source_skills_value: Variant = source.get("skills", [])
		if source_skills_value is Array:
			for skill_variant in source_skills_value as Array:
				if not (skill_variant is Dictionary):
					continue
				var skill: Dictionary = (skill_variant as Dictionary).duplicate(true)
				var contract: Dictionary = {}
				var contract_value: Variant = skill.get("target_contract", {})
				if contract_value is Dictionary:
					contract = (contract_value as Dictionary).duplicate(true)
				skill["target_contract"] = _ai_target_contract(
					str(contract.get("target_kind", ""))
				)
				skills.append(skill)
		source["private_skills"] = skills
		source.erase("skills")
		owned.append(source)
	var asset_view: Dictionary = AssetBatchCore.monster_skill_available_asset_view(
		_asset_state,
		actor_id
	)
	var available_assets: Dictionary = {}
	var available_assets_value: Variant = asset_view.get(
		"own_available_assets",
		{}
	)
	if available_assets_value is Dictionary:
		available_assets = (available_assets_value as Dictionary).duplicate(true)
	return {
		"viewer_player_id": actor_id,
		"monster_card_options": monster_options_by_card.values(),
		"military_card_options": military_options_by_card.values(),
		"owned_monsters": owned,
		"available_unreserved_assets": available_assets,
	}


func legal_card_actions(actor_id: String) -> Array:
	var started := Time.get_ticks_usec() if _simulation_profile_enabled else 0
	_simulation_legal_card_actions_call_count += 1
	if actor_id == _simulation_cache_actor_id and _simulation_legal_cache_valid:
		_simulation_legal_card_actions_cache_hit_count += 1
		var cached: Array = _simulation_legal_cache.duplicate(true)
		_simulation_last_legal_actions_by_actor[actor_id] = cached.duplicate(
			true
		)
		_observe_monster_hand_without_legal_options(actor_id, cached)
		if _simulation_profile_enabled:
			_simulation_profile_legal_actions_usec += (
				Time.get_ticks_usec() - started
			)
		return cached
	var result: Array = super.legal_card_actions(actor_id)
	_simulation_last_legal_actions_by_actor[actor_id] = result.duplicate(
		true
	)
	if actor_id == _simulation_cache_actor_id:
		_simulation_legal_cache = result.duplicate(true)
		_simulation_legal_cache_valid = true
	_observe_monster_hand_without_legal_options(actor_id, result)
	if _simulation_profile_enabled:
		_simulation_profile_legal_actions_usec += Time.get_ticks_usec() - started
	return result


func _auto_legal_actions(actor_id: String) -> Array:
	var result: Array = super._auto_legal_actions(actor_id)
	var direct: Array = legal_card_actions(actor_id)
	var result_ids: Dictionary = {}
	for existing_variant in result:
		if existing_variant is Dictionary:
			result_ids[_simulation_option_identity(existing_variant as Dictionary)] = true
	# AI observations historically carried only the facility subset. The
	# authority's own legal projection is the source of truth for combat cards;
	# merge those options without exposing any rival-private fields.
	for direct_variant in direct:
		if not (direct_variant is Dictionary):
			continue
		var direct_option := direct_variant as Dictionary
		var domain := str(direct_option.get("action_domain", ""))
		if domain not in ["monster", "military"]:
			continue
		var identity := _simulation_option_identity(direct_option)
		if not result_ids.has(identity):
			result.append(direct_option.duplicate(true))
			result_ids[identity] = true
	var projected_counts := _combat_legal_counts(result)
	var direct_counts := _combat_legal_counts(direct)
	_simulation_direct_monster_legal_option_count += int(
		direct_counts.get("monster", 0)
	)
	_simulation_direct_military_legal_option_count += int(
		direct_counts.get("military", 0)
	)
	if (
		_simulation_first_combat_legal_projection_gap.is_empty()
		and (
			int(direct_counts.get("monster", 0))
				> int(projected_counts.get("monster", 0))
			or int(direct_counts.get("military", 0))
				> int(projected_counts.get("military", 0))
		)
	):
		_simulation_first_combat_legal_projection_gap = {
			"phase": _phase,
			"batch_number": _batch_number,
			"actor_is_local": actor_id == _local_player_id,
			"direct_monster_count": int(direct_counts.get("monster", 0)),
			"projected_monster_count": int(
				projected_counts.get("monster", 0)
			),
			"direct_military_count": int(direct_counts.get("military", 0)),
			"projected_military_count": int(
				projected_counts.get("military", 0)
			),
			"direct_legal_count": direct.size(),
			"projected_legal_count": result.size(),
		}
	if _simulation_profile_enabled:
		_observe_dbg_card_lifecycle(actor_id)
	for option_variant in result:
		if not (option_variant is Dictionary):
			continue
		var domain: String = str(
			(option_variant as Dictionary).get("action_domain", "")
		)
		if domain == "monster":
			_simulation_monster_legal_option_count += 1
		elif domain == "military":
			_simulation_military_legal_option_count += 1
	return result


func _combat_legal_counts(options: Array) -> Dictionary:
	var result := {"monster": 0, "military": 0}
	for option_variant in options:
		if not (option_variant is Dictionary):
			continue
		var domain := str((option_variant as Dictionary).get(
			"action_domain",
			""
		))
		if result.has(domain):
			result[domain] = int(result.get(domain, 0)) + 1
	return result


func _monster_card_options(actor_id: String, card: Dictionary) -> Array:
	var result: Array = super._monster_card_options(actor_id, card)
	if result.is_empty():
		_observe_first_monster_prebind_rejection(actor_id, card)
	return result


func _auto_available_actions(
	actor_id: String,
	queue: Array,
	legal: Array
) -> Array:
	var started := Time.get_ticks_usec() if _simulation_profile_enabled else 0
	var result: Array = super._auto_available_actions(actor_id, queue, legal)
	if _simulation_profile_enabled:
		_observe_military_available_filter(actor_id, queue, legal, result)
		_simulation_profile_available_actions_usec += (
			Time.get_ticks_usec() - started
		)
	return result


func _auto_queue_and_lock(actor_id: String) -> Dictionary:
	var started := Time.get_ticks_usec() if _simulation_profile_enabled else 0
	_simulation_cache_actor_id = actor_id
	_simulation_legal_cache_valid = false
	_simulation_legal_cache = []
	_simulation_card_cache = {}
	var result: Dictionary = super._auto_queue_and_lock(actor_id)
	_observe_queued_combat_actions(actor_id)
	_simulation_cache_actor_id = ""
	_simulation_legal_cache_valid = false
	_simulation_legal_cache = []
	_simulation_card_cache = {}
	if _simulation_profile_enabled:
		_simulation_profile_auto_queue_usec += Time.get_ticks_usec() - started
	return result


func acquire_track_item(
	actor_id: String,
	source_instance_id: String
) -> Dictionary:
	var result: Dictionary = super.acquire_track_item(
		actor_id,
		source_instance_id
	)
	# Purchase mutates only the owner's DBG discard; invalidate any pre-purchase
	# observation captured while the queue scope was being entered.
	if actor_id == _simulation_cache_actor_id:
		_simulation_legal_cache_valid = false
		_simulation_legal_cache = []
		_simulation_card_cache = {}
	return result


func _card_in_hand(actor_id: String, card_instance_id: String) -> Dictionary:
	if actor_id == _simulation_cache_actor_id:
		if _simulation_card_cache.has(card_instance_id):
			_simulation_card_lookup_cache_hit_count += 1
			return (
				_simulation_card_cache.get(card_instance_id, {}) as Dictionary
			).duplicate(true)
		var card: Dictionary = super._card_in_hand(actor_id, card_instance_id)
		_simulation_card_cache[card_instance_id] = card.duplicate(true)
		return card
	return super._card_in_hand(actor_id, card_instance_id)


func request_private_monster_skill(
	actor_id: String,
	parameters: Dictionary
) -> Dictionary:
	var result: Dictionary = super.request_private_monster_skill(
		actor_id,
		parameters
	)
	if bool(result.get("accepted", false)):
		_simulation_legal_cache_valid = false
		_simulation_legal_cache = []
		_simulation_card_cache = {}
		_simulation_pending_skill_request_keys.append(
			"%s|%s|%s" % [
				actor_id,
				str(parameters.get("source_instance_id", "")),
				str(parameters.get("skill_definition_id", "")),
			]
		)
	return result


func _connect_combat_observers() -> void:
	# Keep read-only telemetry in the simulation, but omit the presentation node.
	# Combat receipts and state ownership remain in the production runtime ports.
	_simulation_presentation_observer_disabled = true
	var telemetry_receipt := Callable(
		_combat_telemetry_bridge,
		"consume_public_receipt"
	)
	if not resolution_presented.is_connected(telemetry_receipt):
		resolution_presented.connect(telemetry_receipt)



func _auto_request_private_skill(actor_id: String) -> void:
	if not _combat_initialized:
		return
	if not _simulation_has_active_owned_monster(actor_id):
		_simulation_private_skill_fast_skip_count += 1
		return
	super._auto_request_private_skill(actor_id)


func _simulation_has_active_owned_monster(actor_id: String) -> bool:
	var monsters_value: Variant = _combat_owner.call("public_monsters")
	if not (monsters_value is Array):
		return false
	for monster_variant in monsters_value as Array:
		if not (monster_variant is Dictionary):
			continue
		var monster: Dictionary = monster_variant as Dictionary
		if (
			str(monster.get("owner_player_id", "")) == actor_id
			and str(monster.get("status", "")) == "active"
		):
			return true
	return false


func _observe_dbg_card_lifecycle(actor_id: String) -> void:
	var projection: Dictionary = super._dbg_projection(actor_id)
	var facts: Dictionary = projection.get("facts", {}) as Dictionary
	_observe_card_zone(actor_id, "discard", facts.get("discard", []) as Array)
	var hand: Array = facts.get("hand", []) as Array
	_observe_card_zone(actor_id, "hand", hand)
	_observe_monster_hand_without_legal_options(
		actor_id,
		_simulation_last_legal_actions_by_actor.get(actor_id, []) as Array
	)


func _observe_first_monster_prebind_rejection(
	actor_id: String,
	card: Dictionary
) -> void:
	var definition_id: String = str(card.get("definition_id", ""))
	var definition: Dictionary = CombatCardDefinitions.definition(definition_id)
	if definition.is_empty():
		_record_monster_prebind_rejection({
			"reason_code": "monster_card_definition_unknown",
			"monster_card_mode": "DEPLOY_NEW",
			"definition_known": false,
			"runtime_region_count": _runtime_region_ids().size(),
			"combat_debug_unchanged": true,
		})
		return
	var regions: Array[String] = _runtime_region_ids()
	if regions.is_empty():
		_record_monster_prebind_rejection({
			"reason_code": "monster_deploy_region_invalid",
			"monster_card_mode": "DEPLOY_NEW",
			"definition_known": true,
			"runtime_region_count": 0,
			"combat_debug_unchanged": true,
		})
		return
	var before: Dictionary = _combat_owner.call("debug_snapshot") as Dictionary
	if str(before.get("phase", "")) != "batch_active":
		_record_monster_prebind_rejection({
			"reason_code": "monster_card_prebind_probe_skipped_non_active_phase",
			"monster_card_mode": "DEPLOY_NEW",
			"definition_known": true,
			"card_rank": int(definition.get("level", 0)),
			"runtime_region_count": regions.size(),
			"controlled_source_count": _owned_active_monster_count(actor_id),
			"combat_debug_unchanged": true,
		})
		return
	var request := {
		"request_id": "simulation.diagnostic.%s" % str(
			card.get("instance_id", "")
		).sha256_text().substr(0, 12),
		"card_instance_id": str(card.get("instance_id", "")),
		"card_definition_id": definition_id,
		"owner_player_id": actor_id,
		"monster_card_mode": "DEPLOY_NEW",
		"target_region_id": regions[0],
		"target_source_instance_id": "",
	}
	var prebound: Dictionary = _combat_owner.call(
		"prebind_monster_card_action",
		request
	) as Dictionary
	var after: Dictionary = _combat_owner.call("debug_snapshot") as Dictionary
	var observation := {
		"accepted": bool(prebound.get("accepted", false)),
		"reason_code": str(prebound.get(
			"reason_code",
			"monster_prebind_result_without_reason"
		)),
		"monster_card_mode": "DEPLOY_NEW",
		"definition_known": true,
		"card_rank": int(definition.get("level", 0)),
		"runtime_region_count": regions.size(),
		"controlled_source_count": _owned_active_monster_count(actor_id),
		"combat_debug_unchanged": _same_combat_debug_identity(before, after),
	}
	if _simulation_first_monster_prebind_observation.is_empty():
		_simulation_first_monster_prebind_observation = observation.duplicate(
			true
		)
	if bool(prebound.get("accepted", false)):
		_simulation_monster_prebind_accept_count += 1
		return
	_record_monster_prebind_rejection(observation)


func _observe_monster_hand_without_legal_options(
	actor_id: String,
	legal: Array
) -> void:
	var projection: Dictionary = super._dbg_projection(actor_id)
	var facts: Dictionary = projection.get("facts", {}) as Dictionary
	for card_variant in facts.get("hand", []) as Array:
		if not (card_variant is Dictionary):
			continue
		var card: Dictionary = card_variant as Dictionary
		if CombatCardDefinitions.card_domain(
			str(card.get("card_type", ""))
		) != "monster":
			continue
		var has_option: bool = false
		for option_variant in legal:
			if not (option_variant is Dictionary):
				continue
			var option: Dictionary = option_variant as Dictionary
			if (
				str(option.get("action_domain", "")) == "monster"
				and str(option.get("card_instance_id", "")) == str(
					card.get("instance_id", "")
				)
			):
				has_option = true
				break
		if not has_option:
			_observe_first_monster_prebind_rejection(actor_id, card)


func _record_monster_prebind_rejection(observation: Dictionary) -> void:
	var reason: String = str(observation.get("reason_code", ""))
	_simulation_monster_prebind_rejection_count += 1
	_simulation_monster_prebind_rejection_reasons[reason] = int(
		_simulation_monster_prebind_rejection_reasons.get(reason, 0)
	) + 1
	if _simulation_first_monster_prebind_rejection.is_empty():
		_simulation_first_monster_prebind_rejection = observation.duplicate(true)


func _same_combat_debug_identity(
	before: Dictionary,
	after: Dictionary
) -> bool:
	for key in [
		"revision",
		"monster_source_count",
		"combat_receipt_count",
		"runtime_error_count",
	]:
		if before.get(key) != after.get(key):
			return false
	return true


func _owned_active_monster_count(actor_id: String) -> int:
	var count: int = 0
	var monsters_value: Variant = _combat_owner.call("public_monsters")
	if not (monsters_value is Array):
		return 0
	for monster_variant in monsters_value as Array:
		if not (monster_variant is Dictionary):
			continue
		var monster: Dictionary = monster_variant as Dictionary
		if (
			str(monster.get("owner_player_id", "")) == actor_id
			and str(monster.get("status", "")) not in [
				"destroyed",
				"withdrawn",
			]
		):
			count += 1
	return count


func _observe_military_available_filter(
	actor_id: String,
	queue: Array,
	legal: Array,
	available_options: Array
) -> void:
	var available_ids: Dictionary = {}
	for option_variant in available_options:
		if not (option_variant is Dictionary):
			continue
		var option: Dictionary = option_variant as Dictionary
		available_ids[_simulation_option_identity(option)] = true
	var queued_card_ids: Dictionary = {}
	var queued_slot_ids: Dictionary = {}
	for binding_variant in queue:
		if not (binding_variant is Dictionary):
			continue
		var binding: Dictionary = binding_variant as Dictionary
		queued_card_ids[str(binding.get("card_instance_id", ""))] = true
		queued_slot_ids[str(binding.get("target_slot_id", ""))] = true
	for option_variant in legal:
		if not (option_variant is Dictionary):
			continue
		var option: Dictionary = option_variant as Dictionary
		if str(option.get("action_domain", "")) != "military":
			continue
		var affordability: Dictionary = _military_affordability_snapshot(
			actor_id,
			queue,
			option
		)
		if bool(affordability.get("affordable", false)):
			_simulation_military_affordable_option_count += 1
		var option_available: bool = available_ids.has(
			_simulation_option_identity(option)
		)
		if option_available:
			_simulation_military_available_option_count += 1
			continue
		_simulation_military_filtered_option_count += 1
		var reason: String = _military_filter_reason(
			option,
			queued_card_ids,
			queued_slot_ids,
			affordability
		)
		_simulation_military_filter_reasons[reason] = int(
			_simulation_military_filter_reasons.get(reason, 0)
		) + 1
		if _simulation_first_military_filter_rejection.is_empty():
			_simulation_first_military_filter_rejection = {
				"reason_code": reason,
				"task_kind": str(option.get("task_kind", "")),
				"asset_color": str(affordability.get("asset_color", "")),
				"available_asset_count": int(
					affordability.get("available_asset_count", 0)
				),
				"queued_reserved_asset_count": int(
					affordability.get("queued_reserved_asset_count", 0)
				),
				"candidate_asset_cost": int(
					affordability.get("candidate_asset_cost", 0)
				),
				"required_asset_count": int(
					affordability.get("required_asset_count", 0)
				),
				"asset_shortage_count": int(
					affordability.get("asset_shortage_count", 0)
				),
				"target_present": _military_target_present(option),
				"target_slot_present": not str(
					option.get("target_slot_id", "")
				).is_empty(),
				"target_slot_conflict": queued_slot_ids.has(str(
					option.get("target_slot_id", "")
				)),
				"queue_size": queue.size(),
				"batch_number": _batch_number,
			}


func _military_affordability_snapshot(
	actor_id: String,
	queue: Array,
	option: Dictionary
) -> Dictionary:
	var players: Dictionary = _asset_state.get("players", {}) as Dictionary
	var player: Dictionary = players.get(actor_id, {}) as Dictionary
	var assets: Dictionary = player.get("assets", {}) as Dictionary
	var candidate: Dictionary = _card_in_hand(
		actor_id,
		str(option.get("card_instance_id", ""))
	)
	if candidate.is_empty():
		return {
			"affordable": false,
			"reason_code": "military_card_not_in_hand",
			"asset_color": "",
			"available_asset_count": 0,
			"queued_reserved_asset_count": 0,
			"candidate_asset_cost": 0,
			"required_asset_count": 0,
			"asset_shortage_count": 0,
		}
	var color: String = str(candidate.get("primary_color", ""))
	if color not in COLORS:
		return {
			"affordable": false,
			"reason_code": "military_asset_color_invalid",
			"asset_color": color,
			"available_asset_count": 0,
			"queued_reserved_asset_count": 0,
			"candidate_asset_cost": int(
				candidate.get("primary_asset_cost", 0)
			),
			"required_asset_count": 0,
			"asset_shortage_count": 0,
		}
	var reserved: int = 0
	for binding_variant in queue:
		if not (binding_variant is Dictionary):
			continue
		var binding: Dictionary = binding_variant as Dictionary
		var queued_card: Dictionary = _card_in_hand(
			actor_id,
			str(binding.get("card_instance_id", ""))
		)
		if str(queued_card.get("primary_color", "")) == color:
			reserved += int(queued_card.get("primary_asset_cost", 0))
	var candidate_cost: int = int(candidate.get("primary_asset_cost", 0))
	var required: int = reserved + candidate_cost
	var available: int = int(assets.get(color, 0))
	return {
		"affordable": required <= available,
		"reason_code": (
			""
			if required <= available
			else "military_asset_color_insufficient"
		),
		"asset_color": color,
		"available_asset_count": available,
		"queued_reserved_asset_count": reserved,
		"candidate_asset_cost": candidate_cost,
		"required_asset_count": required,
		"asset_shortage_count": maxi(0, required - available),
	}


func _military_filter_reason(
	option: Dictionary,
	queued_card_ids: Dictionary,
	queued_slot_ids: Dictionary,
	affordability: Dictionary
) -> String:
	if queued_card_ids.has(str(option.get("card_instance_id", ""))):
		return "military_card_already_queued"
	var slot_id: String = str(option.get("target_slot_id", ""))
	if slot_id.is_empty():
		return "military_target_slot_missing"
	if queued_slot_ids.has(slot_id):
		return "military_target_slot_conflict"
	if not _military_target_present(option):
		return "military_target_missing"
	var affordability_reason: String = str(
		affordability.get("reason_code", "")
	)
	if not affordability_reason.is_empty():
		return affordability_reason
	return "military_filtered_unclassified"


func _military_target_present(option: Dictionary) -> bool:
	var task: String = str(option.get("task_kind", ""))
	if task == "assault_region":
		return not str(option.get("target_region_id", "")).is_empty()
	if task == "assault_monster":
		return not str(
			option.get("target_monster_source_instance_id", "")
		).is_empty()
	return false


func _simulation_option_identity(option: Dictionary) -> String:
	var option_id: String = str(option.get("option_id", ""))
	if not option_id.is_empty():
		return option_id
	return "%s|%s" % [
		str(option.get("card_instance_id", "")),
		str(option.get("target_slot_id", "")),
	]


func _observe_card_zone(
	actor_id: String,
	zone_name: String,
	cards: Array
) -> void:
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card: Dictionary = card_variant as Dictionary
		var domain: String = CombatCardDefinitions.card_domain(
			str(card.get("card_type", ""))
		)
		if domain not in ["monster", "military"]:
			continue
		var card_key: String = "%s|%s" % [
			actor_id,
			str(card.get("instance_id", "")),
		]
		var previous_zone: String = str(
			_simulation_card_last_zone.get(card_key, "")
		)
		if domain == "monster":
			if zone_name == "discard":
				_simulation_monster_discard_ids[card_key] = true
			else:
				_simulation_monster_hand_ids[card_key] = true
				if previous_zone == "discard":
					_simulation_monster_discard_to_hand_count += 1
				if _simulation_first_monster_prebind_rejection.is_empty():
					_observe_first_monster_prebind_rejection(
						actor_id,
						card
					)
		else:
			if zone_name == "discard":
				_simulation_military_discard_ids[card_key] = true
			else:
				_simulation_military_hand_ids[card_key] = true
				if previous_zone == "discard":
					_simulation_military_discard_to_hand_count += 1
		_simulation_card_last_zone[card_key] = zone_name


func _observe_queued_combat_actions(actor_id: String) -> void:
	var queue: Array = _queued_by_player.get(actor_id, []) as Array
	_simulation_max_queued_actions_per_player = maxi(
		_simulation_max_queued_actions_per_player,
		queue.size()
	)
	for binding_variant in queue:
		if not (binding_variant is Dictionary):
			continue
		var binding: Dictionary = binding_variant as Dictionary
		var action_id: String = str(binding.get("action_id", ""))
		var domain: String = str(binding.get("action_domain", ""))
		if domain == "monster":
			_simulation_monster_queued_action_ids[action_id] = true
		elif domain == "military":
			_simulation_military_queued_action_ids[action_id] = true


func _observe_private_skill_resolution_deltas() -> void:
	if not _combat_initialized or not is_instance_valid(_combat_owner):
		return
	var debug_value: Variant = _combat_owner.call("debug_snapshot")
	if not (debug_value is Dictionary):
		return
	var debug: Dictionary = debug_value as Dictionary
	var commit_count: int = int(
		debug.get("monster_private_skill_commit_count", 0)
	)
	var fizzle_count: int = int(
		debug.get("monster_private_skill_fizzle_count", 0)
	)
	var commit_delta: int = maxi(
		0,
		commit_count - _simulation_observed_skill_commit_count
	)
	var fizzle_delta: int = maxi(
		0,
		fizzle_count - _simulation_observed_skill_fizzle_count
	)
	for _index in range(commit_delta):
		var request_key: String = _pop_pending_skill_request_key()
		if request_key.is_empty():
			continue
		var prior_uses: int = int(
			_simulation_committed_skill_uses_by_key.get(request_key, 0)
		)
		if prior_uses > 0:
			_simulation_private_skill_reuse_commit_count += 1
		_simulation_committed_skill_uses_by_key[request_key] = prior_uses + 1
	for _index in range(fizzle_delta):
		_pop_pending_skill_request_key()
	_simulation_observed_skill_commit_count = commit_count
	_simulation_observed_skill_fizzle_count = fizzle_count


func _pop_pending_skill_request_key() -> String:
	if _simulation_pending_skill_request_keys.is_empty():
		return ""
	return _simulation_pending_skill_request_keys.pop_front()


func simulation_performance_snapshot() -> Dictionary:
	var profiled_call_usec := (
		_simulation_profile_public_core_usec
		+ _simulation_profile_resolve_total_usec
		+ _simulation_profile_sync_facility_usec
		+ _simulation_profile_sync_asset_usec
		+ _simulation_profile_auto_queue_usec
		+ _simulation_profile_ai_observation_usec
		+ _simulation_profile_legal_actions_usec
		+ _simulation_profile_available_actions_usec
		+ _simulation_profile_acquisition_usec
		+ _simulation_profile_lock_usec
	)
	var phase_wall_usec := 0
	for value_variant in _simulation_phase_process_usec.values():
		phase_wall_usec += int(value_variant)
	return {
		"profile_schema_version": 1,
		"acceleration_mode": "inherited_process_submission_window_delta",
		"process_delta_seconds": SIMULATION_PROCESS_DELTA_SECONDS,
		"accelerated_clock_delta_seconds": (
			SIMULATION_PROCESS_DELTA_SECONDS * 30.0
		),
		"inherited_process_authority": "V073SampleRuntimeOwner._process",
		"direct_state_injection_count": 0,
		"process_call_count": _simulation_process_call_count,
		"phase_process_counts": _simulation_phase_process_counts.duplicate(true),
		"phase_process_usec": _simulation_phase_process_usec.duplicate(true),
		"legal_card_actions_call_count": _simulation_legal_card_actions_call_count,
		"legal_card_actions_cache_hit_count": (
			_simulation_legal_card_actions_cache_hit_count
		),
		"card_lookup_cache_hit_count": _simulation_card_lookup_cache_hit_count,
		"private_skill_fast_skip_count": _simulation_private_skill_fast_skip_count,
		"monster_card_discard_observation_count": (
			_simulation_monster_discard_ids.size()
		),
		"military_card_discard_observation_count": (
			_simulation_military_discard_ids.size()
		),
		"monster_card_hand_observation_count": (
			_simulation_monster_hand_ids.size()
		),
		"military_card_hand_observation_count": (
			_simulation_military_hand_ids.size()
		),
		"monster_card_discard_to_hand_count": (
			_simulation_monster_discard_to_hand_count
		),
		"military_card_discard_to_hand_count": (
			_simulation_military_discard_to_hand_count
		),
		"monster_legal_option_observation_count": (
			_simulation_monster_legal_option_count
		),
		"military_legal_option_observation_count": (
			_simulation_military_legal_option_count
		),
		"direct_monster_legal_option_observation_count": (
			_simulation_direct_monster_legal_option_count
		),
		"direct_military_legal_option_observation_count": (
			_simulation_direct_military_legal_option_count
		),
		"first_combat_legal_projection_gap": (
			_simulation_first_combat_legal_projection_gap.duplicate(true)
		),
		"runtime_failure": _simulation_runtime_failure.duplicate(true),
		"profile_public_core_usec": _simulation_profile_public_core_usec,
		"profile_resolve_total_usec": _simulation_profile_resolve_total_usec,
		"profile_sync_facility_usec": _simulation_profile_sync_facility_usec,
		"profile_sync_asset_usec": _simulation_profile_sync_asset_usec,
		"profile_resolution_count": _simulation_profile_resolution_count,
		"profile_auto_queue_usec": _simulation_profile_auto_queue_usec,
		"profile_ai_observation_usec": _simulation_profile_ai_observation_usec,
		"profile_legal_actions_usec": _simulation_profile_legal_actions_usec,
		"profile_available_actions_usec": (
			_simulation_profile_available_actions_usec
		),
		"profile_acquisition_usec": _simulation_profile_acquisition_usec,
		"profile_lock_usec": _simulation_profile_lock_usec,
		"profiled_call_usec_total": profiled_call_usec,
		"phase_process_usec_total": phase_wall_usec,
		"military_affordable_option_observation_count": (
			_simulation_military_affordable_option_count
		),
		"military_available_option_observation_count": (
			_simulation_military_available_option_count
		),
		"military_filtered_option_observation_count": (
			_simulation_military_filtered_option_count
		),
		"monster_prebind_rejection_observation_count": (
			_simulation_monster_prebind_rejection_count
		),
		"monster_prebind_accept_observation_count": (
			_simulation_monster_prebind_accept_count
		),
		"monster_prebind_rejection_reasons": (
			_simulation_monster_prebind_rejection_reasons.duplicate(true)
		),
		"military_filter_reasons": (
			_simulation_military_filter_reasons.duplicate(true)
		),
		"first_monster_prebind_rejection": (
			_simulation_first_monster_prebind_rejection.duplicate(true)
		),
		"first_monster_prebind_observation": (
			_simulation_first_monster_prebind_observation.duplicate(true)
		),
		"first_military_filter_rejection": (
			_simulation_first_military_filter_rejection.duplicate(true)
		),
		"monster_queued_action_count": (
			_simulation_monster_queued_action_ids.size()
		),
		"military_queued_action_count": (
			_simulation_military_queued_action_ids.size()
		),
		"max_queued_actions_per_player": (
			_simulation_max_queued_actions_per_player
		),
		"private_skill_reuse_commit_count": (
			_simulation_private_skill_reuse_commit_count
		),
		"presentation_observer_disabled": _simulation_presentation_observer_disabled,
		"presentation_gameplay_mutation_count": 0,
		"presentation_rng_draw_delta": 0,
	}
