extends "res://scripts/v075_runtime/v075_runtime_owner.gd"
class_name V075CombatSimulationRuntimeDriver

const AssetBatchCore := preload(
	"res://scripts/v07_semantic/v07_asset_batch_core.gd"
)
const CombatCardDefinitions := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)

const SIMULATION_PROCESS_DELTA_SECONDS := 1.0

var _simulation_legal_card_actions_call_count: int = 0
var _simulation_legal_card_actions_cache_hit_count: int = 0
var _simulation_card_lookup_cache_hit_count: int = 0
var _simulation_private_skill_fast_skip_count: int = 0
var _simulation_presentation_observer_disabled: bool = true
var _simulation_process_call_count: int = 0
var _simulation_phase_process_counts: Dictionary = {}
var _simulation_cache_actor_id: String = ""
var _simulation_legal_cache_valid: bool = false
var _simulation_legal_cache: Array = []
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
var _simulation_monster_queued_action_ids: Dictionary = {}
var _simulation_military_queued_action_ids: Dictionary = {}
var _simulation_max_queued_actions_per_player: int = 0
var _simulation_pending_skill_request_keys: Array[String] = []
var _simulation_committed_skill_uses_by_key: Dictionary = {}
var _simulation_private_skill_reuse_commit_count: int = 0
var _simulation_observed_skill_commit_count: int = 0
var _simulation_observed_skill_fizzle_count: int = 0


func run_simulation_until_settled(max_steps: int = 2000) -> Dictionary:
	if _match_id.is_empty():
		return _reject("match_not_started")
	_accelerated = true
	_automate_local_human = true
	var was_coalesced: bool = _projection_emit_coalesced
	_projection_emit_coalesced = true
	var steps: int = 0
	while _phase not in ["settled", "failed"] and steps < max_steps:
		var phase_before: String = _phase
		_simulation_phase_process_counts[phase_before] = int(
			_simulation_phase_process_counts.get(phase_before, 0)
		) + 1
		# The inherited production process owns every phase and receipt transition.
		super._process(SIMULATION_PROCESS_DELTA_SECONDS)
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
	_simulation_legal_card_actions_call_count += 1
	if actor_id == _simulation_cache_actor_id and _simulation_legal_cache_valid:
		_simulation_legal_card_actions_cache_hit_count += 1
		return _simulation_legal_cache.duplicate(true)
	var result: Array = super.legal_card_actions(actor_id)
	if actor_id == _simulation_cache_actor_id:
		_simulation_legal_cache = result.duplicate(true)
		_simulation_legal_cache_valid = true
	return result


func _auto_legal_actions(actor_id: String) -> Array:
	var result: Array = super._auto_legal_actions(actor_id)
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


func _auto_queue_and_lock(actor_id: String) -> Dictionary:
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
	_observe_card_zone(actor_id, "hand", facts.get("hand", []) as Array)


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
	return {
		"acceleration_mode": "inherited_process_submission_window_delta",
		"process_delta_seconds": SIMULATION_PROCESS_DELTA_SECONDS,
		"accelerated_clock_delta_seconds": (
			SIMULATION_PROCESS_DELTA_SECONDS * 30.0
		),
		"inherited_process_authority": "V073SampleRuntimeOwner._process",
		"direct_state_injection_count": 0,
		"process_call_count": _simulation_process_call_count,
		"phase_process_counts": _simulation_phase_process_counts.duplicate(true),
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
