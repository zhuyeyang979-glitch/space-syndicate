extends RefCounted
class_name V075MonsterSourceCore

const CapacityPort := preload(
	"res://scripts/v075/monster/v075_character_monster_capacity_port.gd"
)

const SCHEMA_VERSION := "1.0.0"
const RULESET_ID := "v0.7.5"
const CORE_CONTRACT_ID := "v075.monster_source_core.v1"
const STATE_CONTRACT_ID := "v075.monster_source_state.v1"
const DEFINITION_CONTRACT_ID := "v075.monster_source_definition.v1"
const SOURCE_CONTRACT_ID := "v075.monster_source.v1"
const ACTION_CONTRACT_ID := "v075.monster_card_prebound_action.v1"
const RECEIPT_CONTRACT_ID := "v075.monster_card_resolution_receipt.v1"
const CHECKPOINT_CONTRACT_ID := "v075.monster_source_checkpoint.v1"
const BASE_MONSTER_CONTROL_CAPACITY_PER_PLAYER := (
	CapacityPort.BASE_MONSTER_CONTROL_CAPACITY_PER_PLAYER
)
const MAX_MONSTER_RANK := 4
const MAX_SAFE_INTEGER := 9007199254740991

const MODE_DEPLOY_NEW := "DEPLOY_NEW"
const MODE_REFRESH_EXISTING := "REFRESH_EXISTING"
const MODE_UPGRADE_EXISTING := "UPGRADE_EXISTING"
const MODE_REPLACE_EXISTING := "REPLACE_EXISTING"
const CARD_MODES := [
	MODE_DEPLOY_NEW,
	MODE_REFRESH_EXISTING,
	MODE_UPGRADE_EXISTING,
	MODE_REPLACE_EXISTING,
]
const SOURCE_STATUSES := ["active", "downed", "destroyed", "withdrawn"]
const CONTROLLED_STATUSES := ["active", "downed"]
const PREFERRED_COLORS := [
	"life",
	"energy",
	"industry",
	"technology",
	"commerce",
	"shipping",
]
const FACILITY_TYPES := ["factory", "market", "warehouse"]
const MOVEMENT_PROFILES := [
	"ground_trample",
	"flying_no_trample",
	"teleport_no_trample",
]
const SKILL_LOCKED := "LOCKED_BY_RANK"
const SKILL_READY := "READY"
const SKILL_PENDING := "PENDING_SAFE_BOUNDARY"
const SKILL_RESOLVING := "RESOLVING"
const SKILL_COOLDOWN := "COOLDOWN"
const SKILL_DISABLED := "DISABLED"
const SKILL_REVOKED := "REVOKED"
const SKILL_STATUSES := [
	SKILL_LOCKED,
	SKILL_READY,
	SKILL_PENDING,
	SKILL_RESOLVING,
	SKILL_COOLDOWN,
	SKILL_DISABLED,
	SKILL_REVOKED,
]
const REFRESH_PERCENT_BY_RANK := {
	1: 25,
	2: 50,
	3: 75,
	4: 100,
}
const DEFINITION_FIELDS := [
	"schema_version",
	"contract_id",
	"ruleset_id",
	"source_definition_id",
	"monster_family_id",
	"preferred_industry_color",
	"facility_type_preference",
	"base_detection_range_hops",
	"movement_profile",
	"movement_budget_milli_arc_by_rank",
	"max_hp_by_rank",
	"armor_by_rank",
	"active_skill_definition_ids",
	"definition_fingerprint",
]
const SOURCE_FIELDS := [
	"schema_version",
	"contract_id",
	"ruleset_id",
	"source_instance_id",
	"source_definition_id",
	"definition_fingerprint",
	"monster_family_id",
	"owner_player_id",
	"region_id",
	"source_generation",
	"rank",
	"hp",
	"max_hp",
	"armor",
	"status",
	"damage_revision",
	"preferred_industry_color",
	"facility_type_preference",
	"base_detection_range_hops",
	"current_detection_range_hops",
	"movement_profile",
	"movement_budget_milli_arc",
	"unlocked_skill_definition_ids",
	"skill_states",
	"batch_active_skill_use_count",
	"created_from_card_instance_id",
	"withdrawal_reason",
	"kill_reward_count",
	"source_fingerprint",
]
const SKILL_STATE_FIELDS := [
	"skill_definition_id",
	"status",
	"cooldown_batches_remaining",
	"skill_generation",
	"resume_status",
]
const ACTION_FIELDS := [
	"schema_version",
	"contract_id",
	"ruleset_id",
	"request_id",
	"card_instance_id",
	"card_definition_id",
	"owner_player_id",
	"card_rank",
	"monster_card_mode",
	"target_source_instance_id",
	"target_source_generation",
	"deployment_region_id",
	"bound_state_revision",
	"definition_snapshot",
	"prebound",
	"mode_auto_conversion_allowed",
	"action_fingerprint",
]
const RECEIPT_FIELDS := [
	"schema_version",
	"contract_id",
	"ruleset_id",
	"receipt_id",
	"request_id",
	"action_fingerprint",
	"card_instance_id",
	"card_definition_id",
	"owner_player_id",
	"monster_card_mode",
	"accepted",
	"outcome_id",
	"reason_code",
	"state_revision",
	"mode_auto_converted",
	"mode_auto_conversion_count",
	"source_instance_id",
	"source_generation",
	"withdrawn_source_instance_id",
	"old_rank",
	"new_rank",
	"refresh_percent",
	"healing_amount_requested",
	"healing_amount_applied",
	"upgrade_full_heal",
	"upgrade_cooldown_reset_count",
	"old_skill_state_preserved_count",
	"new_skill_ready_count",
	"replace_kill_reward_count",
	"withdrawn_counts_as_kill",
	"card_destination",
	"dbg_write_count",
	"exact_once",
	"receipt_fingerprint",
]
const STATE_FIELDS := [
	"schema_version",
	"contract_id",
	"ruleset_id",
	"revision",
	"player_ids",
	"character_capacity_semantics",
	"sources",
	"next_source_sequence",
	"processed_cards",
	"receipt_journal",
	"state_fingerprint",
]
const CHECKPOINT_FIELDS := [
	"schema_version",
	"contract_id",
	"ruleset_id",
	"checkpoint_id",
	"captured_state_revision",
	"state",
	"checkpoint_fingerprint",
]


static func new_state(
	player_ids: Array,
	character_semantics_by_player: Dictionary = {},
	initial_sources: Array = []
) -> Dictionary:
	var normalized_players := _string_id_array(player_ids, false)
	if normalized_players.is_empty():
		return {}
	normalized_players.sort()
	var semantics := {}
	for player_id in normalized_players:
		var semantic_variant: Variant = character_semantics_by_player.get(
			player_id,
			{}
		)
		var semantic := (
			semantic_variant as Dictionary
			if semantic_variant is Dictionary
			else {}
		)
		if semantic.is_empty():
			semantic = CapacityPort.build_semantic(player_id, 0)
		var capacity := CapacityPort.capacity_receipt(semantic)
		if (
			not bool(capacity.get("accepted", false))
			or str(capacity.get("player_id", "")) != player_id
		):
			return {}
		semantics[player_id] = semantic.duplicate(true)
	var sources := {}
	for source_variant in initial_sources:
		if not (source_variant is Dictionary):
			return {}
		var source := source_variant as Dictionary
		if _source_error(source) != "":
			return {}
		var source_id := str(source.get("source_instance_id", ""))
		if (
			sources.has(source_id)
			or not normalized_players.has(
				str(source.get("owner_player_id", ""))
			)
		):
			return {}
		sources[source_id] = source.duplicate(true)
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": STATE_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"revision": 1,
		"player_ids": normalized_players,
		"character_capacity_semantics": semantics,
		"sources": sources,
		"next_source_sequence": 1,
		"processed_cards": {},
		"receipt_journal": [],
	}
	while sources.has(_source_id_for_sequence(
		int(unsealed.get("next_source_sequence", 1))
	)):
		unsealed["next_source_sequence"] = (
			int(unsealed.get("next_source_sequence", 1)) + 1
		)
	var state := _seal(unsealed, "state_fingerprint")
	return state if _state_error(state) == "" else {}


static func normalize_definition(raw: Dictionary) -> Dictionary:
	if not _is_pure_data(raw):
		return {}
	var facility_preference := _string_id_array(
		raw.get("facility_type_preference", []),
		false
	)
	var movement_budgets := _integer_array(
		raw.get("movement_budget_milli_arc_by_rank", []),
		MAX_MONSTER_RANK,
		true
	)
	var max_hp_by_rank := _integer_array(
		raw.get("max_hp_by_rank", []),
		MAX_MONSTER_RANK,
		true
	)
	var armor_by_rank := _integer_array(
		raw.get("armor_by_rank", []),
		MAX_MONSTER_RANK,
		false
	)
	var skill_ids := _string_id_array(
		raw.get("active_skill_definition_ids", []),
		false
	)
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": DEFINITION_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"source_definition_id": str(
			raw.get("source_definition_id", "")
		),
		"monster_family_id": str(raw.get("monster_family_id", "")),
		"preferred_industry_color": str(
			raw.get("preferred_industry_color", "")
		),
		"facility_type_preference": facility_preference,
		"base_detection_range_hops": int(
			raw.get("base_detection_range_hops", -1)
		),
		"movement_profile": str(raw.get("movement_profile", "")),
		"movement_budget_milli_arc_by_rank": movement_budgets,
		"max_hp_by_rank": max_hp_by_rank,
		"armor_by_rank": armor_by_rank,
		"active_skill_definition_ids": skill_ids,
	}
	var definition := _seal(unsealed, "definition_fingerprint")
	return definition if _definition_error(definition) == "" else {}


static func build_source_snapshot(
	raw_definition: Dictionary,
	source_instance_id: String,
	owner_player_id: String,
	region_id: String,
	rank: int,
	hp_override: int = -1,
	status: String = "active",
	source_generation: int = 1,
	created_from_card_instance_id: String = "card.checkpoint.origin",
	skill_state_overrides: Dictionary = {}
) -> Dictionary:
	var definition := normalize_definition(raw_definition)
	if (
		definition.is_empty()
		or not _stable_id(source_instance_id)
		or not _stable_id(owner_player_id)
		or not _stable_id(region_id)
		or rank < 1
		or rank > MAX_MONSTER_RANK
		or not SOURCE_STATUSES.has(status)
		or source_generation < 1
		or not _stable_id(created_from_card_instance_id)
		or not _is_pure_data(skill_state_overrides)
	):
		return {}
	var max_hp := int(
		(definition.get("max_hp_by_rank", []) as Array)[rank - 1]
	)
	var hp := max_hp if hp_override < 0 else hp_override
	if hp < 0 or hp > max_hp:
		return {}
	if status == "active" and hp <= 0:
		return {}
	if status == "downed" and hp != 0:
		return {}
	var skill_states := _initial_skill_states(definition, rank, status)
	for skill_id_variant in skill_state_overrides.keys():
		var skill_id := str(skill_id_variant)
		if not skill_states.has(skill_id):
			return {}
		var normalized_state := _normalize_skill_state(
			skill_id,
			skill_state_overrides.get(skill_id)
		)
		if normalized_state.is_empty():
			return {}
		skill_states[skill_id] = normalized_state
	if status in ["destroyed", "withdrawn"]:
		skill_states = _revoked_skill_states(skill_states)
	var unlocked := _unlocked_skill_ids(definition, rank)
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": SOURCE_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"source_instance_id": source_instance_id,
		"source_definition_id": str(
			definition.get("source_definition_id", "")
		),
		"definition_fingerprint": str(
			definition.get("definition_fingerprint", "")
		),
		"monster_family_id": str(
			definition.get("monster_family_id", "")
		),
		"owner_player_id": owner_player_id,
		"region_id": region_id,
		"source_generation": source_generation,
		"rank": rank,
		"hp": hp,
		"max_hp": max_hp,
		"armor": int(
			(definition.get("armor_by_rank", []) as Array)[rank - 1]
		),
		"status": status,
		"damage_revision": 0,
		"preferred_industry_color": str(
			definition.get("preferred_industry_color", "")
		),
		"facility_type_preference": (
			definition.get("facility_type_preference", []) as Array
		).duplicate(),
		"base_detection_range_hops": int(
			definition.get("base_detection_range_hops", 0)
		),
		"current_detection_range_hops": int(
			definition.get("base_detection_range_hops", 0)
		),
		"movement_profile": str(
			definition.get("movement_profile", "")
		),
		"movement_budget_milli_arc": int(
			(definition.get(
				"movement_budget_milli_arc_by_rank",
				[]
			) as Array)[rank - 1]
		),
		"unlocked_skill_definition_ids": unlocked,
		"skill_states": skill_states,
		"batch_active_skill_use_count": 0,
		"created_from_card_instance_id": created_from_card_instance_id,
		"withdrawal_reason": (
			"replaced" if status == "withdrawn" else ""
		),
		"kill_reward_count": 0,
	}
	var source := _seal(unsealed, "source_fingerprint")
	return source if _source_error(source) == "" else {}


static func apply_character_capacity_semantic(
	state: Dictionary,
	request_id: String,
	character_semantic: Dictionary
) -> Dictionary:
	var state_error := _state_error(state)
	var capacity := CapacityPort.capacity_receipt(character_semantic)
	if (
		state_error != ""
		or not _stable_id(request_id)
		or not bool(capacity.get("accepted", false))
	):
		return _failure(
			state,
			state_error if state_error != "" else
			"character_capacity_update_invalid"
		)
	var player_id := str(capacity.get("player_id", ""))
	var player_ids := state.get("player_ids", []) as Array
	if not player_ids.has(player_id):
		return _failure(state, "character_capacity_player_unknown")
	var semantics := (
		state.get("character_capacity_semantics", {}) as Dictionary
	)
	var current := semantics.get(player_id, {}) as Dictionary
	if (
		int(character_semantic.get("revision", 0))
		<= int(current.get("revision", 0))
	):
		return _failure(state, "character_capacity_revision_stale")
	var sources_before := (
		state.get("sources", {}) as Dictionary
	).duplicate(true)
	var next_state := state.duplicate(true)
	next_state.erase("state_fingerprint")
	var next_semantics := (
		next_state.get("character_capacity_semantics", {}) as Dictionary
	)
	next_semantics[player_id] = character_semantic.duplicate(true)
	next_state["character_capacity_semantics"] = next_semantics
	next_state["revision"] = int(state.get("revision", 0)) + 1
	next_state = _seal(next_state, "state_fingerprint")
	var controlled_count := controlled_source_count(next_state, player_id)
	var effective_capacity := int(capacity.get("effective_capacity", -1))
	return {
		"accepted": true,
		"reason_code": "character_capacity_updated",
		"request_id": request_id,
		"player_id": player_id,
		"previous_capacity": CapacityPort.effective_capacity(current),
		"effective_capacity": effective_capacity,
		"controlled_source_count": controlled_count,
		"over_capacity_count": maxi(
			0,
			controlled_count - effective_capacity
		),
		"deployment_blocked": controlled_count >= effective_capacity,
		"forced_kill_count": 0,
		"source_state_mutation_count": (
			0
			if sources_before == next_state.get("sources", {})
			else -1
		),
		"state": next_state,
	}


static func prebind_card_mode(
	state: Dictionary,
	request: Dictionary,
	raw_definition: Dictionary
) -> Dictionary:
	var state_error := _state_error(state)
	var definition := normalize_definition(raw_definition)
	if state_error != "":
		return _bind_failure(state_error)
	if definition.is_empty() or not _is_pure_data(request):
		return _bind_failure("monster_card_definition_invalid")
	for field_name in [
		"request_id",
		"card_instance_id",
		"card_definition_id",
		"owner_player_id",
	]:
		if not _stable_id(request.get(field_name)):
			return _bind_failure("monster_card_request_context_invalid")
	var rank_variant: Variant = request.get("card_rank")
	var mode := str(request.get("monster_card_mode", ""))
	if (
		not _positive_integer(rank_variant)
		or int(rank_variant) > MAX_MONSTER_RANK
		or not CARD_MODES.has(mode)
		or not (state.get("player_ids", []) as Array).has(
			str(request.get("owner_player_id", ""))
		)
		or (state.get("processed_cards", {}) as Dictionary).has(
			str(request.get("card_instance_id", ""))
		)
	):
		return _bind_failure("monster_card_request_context_invalid")
	var bind_context := _mode_context(
		state,
		request,
		definition,
		false
	)
	var bind_error := str(bind_context.get("reason_code", ""))
	if bind_error != "":
		return _bind_failure(bind_error)
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": ACTION_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"request_id": str(request.get("request_id", "")),
		"card_instance_id": str(
			request.get("card_instance_id", "")
		),
		"card_definition_id": str(
			request.get("card_definition_id", "")
		),
		"owner_player_id": str(
			request.get("owner_player_id", "")
		),
		"card_rank": int(request.get("card_rank", 0)),
		"monster_card_mode": mode,
		"target_source_instance_id": str(
			bind_context.get("target_source_instance_id", "")
		),
		"target_source_generation": int(
			bind_context.get("target_source_generation", 0)
		),
		"deployment_region_id": str(
			bind_context.get("deployment_region_id", "")
		),
		"bound_state_revision": int(state.get("revision", 0)),
		"definition_snapshot": definition.duplicate(true),
		"prebound": true,
		"mode_auto_conversion_allowed": false,
	}
	var action := _seal(unsealed, "action_fingerprint")
	if _action_error(action) != "":
		return _bind_failure("monster_card_prebound_action_invalid")
	return {
		"accepted": true,
		"reason_code": "monster_card_mode_prebound",
		"action": action,
		"state_mutation_count": 0,
		"mode_auto_conversion_count": 0,
	}


static func resolve_prebound_card(
	state: Dictionary,
	action: Dictionary
) -> Dictionary:
	var state_error := _state_error(state)
	if state_error != "":
		return _failure(state, state_error)
	var action_error := _action_error(action)
	if action_error != "":
		return _failure(state, action_error)
	var card_instance_id := str(action.get("card_instance_id", ""))
	var processed := state.get("processed_cards", {}) as Dictionary
	if processed.has(card_instance_id):
		var stored := processed.get(card_instance_id, {}) as Dictionary
		if (
			str(stored.get("action_fingerprint", ""))
			!= str(action.get("action_fingerprint", ""))
		):
			return _failure(state, "monster_card_instance_already_consumed")
		return {
			"accepted": true,
			"reason_code": "monster_card_resolution_idempotent_replay",
			"state": state.duplicate(true),
			"receipt": stored.duplicate(true),
			"idempotent_replay": true,
		}
	var resolution_context := _mode_context(
		state,
		_action_as_request(action),
		action.get("definition_snapshot", {}) as Dictionary,
		true
	)
	var resolution_error := str(
		resolution_context.get("reason_code", "")
	)
	if resolution_error != "":
		return _commit_resolution(
			state,
			action,
			{},
			false,
			resolution_error
		)
	var transition := {}
	match str(action.get("monster_card_mode", "")):
		MODE_DEPLOY_NEW:
			transition = _resolve_deploy(state, action)
		MODE_REFRESH_EXISTING:
			transition = _resolve_refresh(state, action)
		MODE_UPGRADE_EXISTING:
			transition = _resolve_upgrade(state, action)
		MODE_REPLACE_EXISTING:
			transition = _resolve_replace(state, action)
	if transition.is_empty():
		return _failure(state, "monster_card_transition_invalid")
	return _commit_resolution(
		transition.get("state", {}) as Dictionary,
		action,
		transition.get("effect", {}) as Dictionary,
		true,
		"monster_card_mode_resolved",
		int(state.get("revision", 0))
	)


static func controlled_sources_for_player(
	state: Dictionary,
	player_id: String
) -> Array:
	var result: Array = []
	if _state_error(state) != "" or not _stable_id(player_id):
		return result
	for source_variant in (
		state.get("sources", {}) as Dictionary
	).values():
		var source := source_variant as Dictionary
		if (
			str(source.get("owner_player_id", "")) == player_id
			and CONTROLLED_STATUSES.has(str(source.get("status", "")))
		):
			result.append(source.duplicate(true))
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left.get("source_instance_id", "")) < str(
			right.get("source_instance_id", "")
		)
	)
	return result


static func controlled_source_count(
	state: Dictionary,
	player_id: String
) -> int:
	return controlled_sources_for_player(state, player_id).size()


static func capacity_for_player(
	state: Dictionary,
	player_id: String
) -> int:
	if _state_error(state) != "":
		return -1
	var semantic := (
		state.get("character_capacity_semantics", {}) as Dictionary
	).get(player_id, {}) as Dictionary
	return CapacityPort.effective_capacity(semantic)


static func source_snapshot(
	state: Dictionary,
	source_instance_id: String
) -> Dictionary:
	if _state_error(state) != "":
		return {}
	var source_variant: Variant = (
		state.get("sources", {}) as Dictionary
	).get(source_instance_id, {})
	return (
		(source_variant as Dictionary).duplicate(true)
		if source_variant is Dictionary
		else {}
	)


static func capture_checkpoint(
	state: Dictionary,
	checkpoint_id: String
) -> Dictionary:
	if _state_error(state) != "" or not _stable_id(checkpoint_id):
		return {}
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": CHECKPOINT_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"checkpoint_id": checkpoint_id,
		"captured_state_revision": int(state.get("revision", 0)),
		"state": state.duplicate(true),
	}
	return _seal(unsealed, "checkpoint_fingerprint")


static func restore_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if _checkpoint_error(checkpoint) != "":
		return {}
	return (
		checkpoint.get("state", {}) as Dictionary
	).duplicate(true)


static func rollback_to_checkpoint(
	current_state: Dictionary,
	checkpoint: Dictionary
) -> Dictionary:
	if _state_error(current_state) != "":
		return _failure(current_state, "rollback_current_state_invalid")
	var restored := restore_checkpoint(checkpoint)
	if restored.is_empty():
		return _failure(current_state, "monster_checkpoint_invalid")
	return {
		"accepted": true,
		"reason_code": "monster_checkpoint_rolled_back",
		"state": restored,
		"previous_state_fingerprint": str(
			current_state.get("state_fingerprint", "")
		),
		"restored_state_fingerprint": str(
			restored.get("state_fingerprint", "")
		),
		"in_place_mutation_count": 0,
	}


static func validation_report(state: Dictionary) -> Dictionary:
	var error := _state_error(state)
	return {
		"valid": error == "",
		"reason_code": "monster_source_state_valid" if error == "" else error,
		"error_count": 0 if error == "" else 1,
		"source_count": (
			(state.get("sources", {}) as Dictionary).size()
			if error == ""
			else 0
		),
	}


static func checkpoint_validation_report(
	checkpoint: Dictionary
) -> Dictionary:
	var error := _checkpoint_error(checkpoint)
	return {
		"valid": error == "",
		"reason_code": "monster_checkpoint_valid" if error == "" else error,
		"error_count": 0 if error == "" else 1,
		"pure_data": _is_pure_data(checkpoint),
	}


static func contract_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"contract_id": CORE_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"base_monster_control_capacity_per_player": (
			BASE_MONSTER_CONTROL_CAPACITY_PER_PLAYER
		),
		"character_capacity_port_contract_id": CapacityPort.CONTRACT_ID,
		"monster_card_modes": CARD_MODES.duplicate(),
		"monster_card_mode_prebound": true,
		"monster_card_mode_auto_conversion_count": 0,
		"refresh_percent_by_rank": {
			"1": 25,
			"2": 50,
			"3": 75,
			"4": 100,
		},
		"upgrade_full_heal": true,
		"upgrade_existing_cooldown_reset_count": 0,
		"replace_kill_reward_count": 0,
		"capacity_drop_forced_kill_count": 0,
		"rng_owner_count": 0,
		"ui_owner_count": 0,
		"presentation_owner_count": 0,
		"checkpoint_pure_data": true,
	}


static func _resolve_deploy(
	state: Dictionary,
	action: Dictionary
) -> Dictionary:
	var definition := (
		action.get("definition_snapshot", {}) as Dictionary
	)
	var next_state := state.duplicate(true)
	next_state.erase("state_fingerprint")
	var sequence := int(next_state.get("next_source_sequence", 1))
	var sources := next_state.get("sources", {}) as Dictionary
	while sources.has(_source_id_for_sequence(sequence)):
		sequence += 1
	var source_id := _source_id_for_sequence(sequence)
	var source := build_source_snapshot(
		definition,
		source_id,
		str(action.get("owner_player_id", "")),
		str(action.get("deployment_region_id", "")),
		int(action.get("card_rank", 0)),
		-1,
		"active",
		1,
		str(action.get("card_instance_id", ""))
	)
	if source.is_empty():
		return {}
	sources[source_id] = source
	next_state["sources"] = sources
	next_state["next_source_sequence"] = sequence + 1
	return {
		"state": next_state,
		"effect": {
			"source_instance_id": source_id,
			"source_generation": 1,
			"old_rank": 0,
			"new_rank": int(action.get("card_rank", 0)),
			"new_skill_ready_count": int(
				action.get("card_rank", 0)
			),
		},
	}


static func _resolve_refresh(
	state: Dictionary,
	action: Dictionary
) -> Dictionary:
	var source_id := str(action.get("target_source_instance_id", ""))
	var next_state := state.duplicate(true)
	next_state.erase("state_fingerprint")
	var sources := next_state.get("sources", {}) as Dictionary
	var source := (
		sources.get(source_id, {}) as Dictionary
	).duplicate(true)
	source.erase("source_fingerprint")
	var rank := int(action.get("card_rank", 0))
	var percent := int(REFRESH_PERCENT_BY_RANK.get(rank, 0))
	var max_hp := int(source.get("max_hp", 0))
	var old_hp := int(source.get("hp", 0))
	var requested := _refresh_amount(max_hp, percent)
	var applied := mini(requested, max_hp - old_hp)
	source["hp"] = old_hp + applied
	if (
		str(source.get("status", "")) == "downed"
		and int(source.get("hp", 0)) > 0
	):
		source["status"] = "active"
		source["skill_states"] = _restore_disabled_skill_states(
			source.get("skill_states", {}) as Dictionary
		)
	source["damage_revision"] = int(
		source.get("damage_revision", 0)
	) + 1
	var sealed_source := _seal(source, "source_fingerprint")
	if _source_error(sealed_source) != "":
		return {}
	sources[source_id] = sealed_source
	next_state["sources"] = sources
	return {
		"state": next_state,
		"effect": {
			"source_instance_id": source_id,
			"source_generation": int(
				sealed_source.get("source_generation", 0)
			),
			"old_rank": int(sealed_source.get("rank", 0)),
			"new_rank": int(sealed_source.get("rank", 0)),
			"refresh_percent": percent,
			"healing_amount_requested": requested,
			"healing_amount_applied": applied,
		},
	}


static func _resolve_upgrade(
	state: Dictionary,
	action: Dictionary
) -> Dictionary:
	var source_id := str(action.get("target_source_instance_id", ""))
	var definition := (
		action.get("definition_snapshot", {}) as Dictionary
	)
	var next_state := state.duplicate(true)
	next_state.erase("state_fingerprint")
	var sources := next_state.get("sources", {}) as Dictionary
	var source := (
		sources.get(source_id, {}) as Dictionary
	).duplicate(true)
	var old_rank := int(source.get("rank", 0))
	var new_rank := int(action.get("card_rank", 0))
	var old_skill_states := (
		source.get("skill_states", {}) as Dictionary
	).duplicate(true)
	if str(source.get("status", "")) == "downed":
		old_skill_states = _restore_disabled_skill_states(
			old_skill_states
		)
	var new_skill_states := {}
	var skill_ids := (
		definition.get("active_skill_definition_ids", []) as Array
	)
	var old_preserved_count := 0
	var new_ready_count := 0
	for index in range(skill_ids.size()):
		var skill_id := str(skill_ids[index])
		if index < old_rank and old_skill_states.has(skill_id):
			new_skill_states[skill_id] = (
				old_skill_states.get(skill_id, {}) as Dictionary
			).duplicate(true)
			old_preserved_count += 1
		elif index < new_rank:
			var prior_generation := 0
			if old_skill_states.has(skill_id):
				prior_generation = int(
					(old_skill_states.get(
						skill_id,
						{}
					) as Dictionary).get("skill_generation", 0)
				)
			new_skill_states[skill_id] = _skill_state(
				skill_id,
				SKILL_READY,
				0,
				prior_generation + 1,
				SKILL_READY
			)
			new_ready_count += 1
		else:
			new_skill_states[skill_id] = _skill_state(
				skill_id,
				SKILL_LOCKED,
				0,
				0,
				SKILL_LOCKED
			)
	source.erase("source_fingerprint")
	source["source_definition_id"] = str(
		definition.get("source_definition_id", "")
	)
	source["definition_fingerprint"] = str(
		definition.get("definition_fingerprint", "")
	)
	source["rank"] = new_rank
	source["max_hp"] = int(
		(definition.get("max_hp_by_rank", []) as Array)[new_rank - 1]
	)
	source["hp"] = int(source.get("max_hp", 0))
	source["armor"] = int(
		(definition.get("armor_by_rank", []) as Array)[new_rank - 1]
	)
	source["status"] = "active"
	source["damage_revision"] = int(
		source.get("damage_revision", 0)
	) + 1
	source["preferred_industry_color"] = str(
		definition.get("preferred_industry_color", "")
	)
	source["facility_type_preference"] = (
		definition.get("facility_type_preference", []) as Array
	).duplicate()
	source["base_detection_range_hops"] = int(
		definition.get("base_detection_range_hops", 0)
	)
	source["current_detection_range_hops"] = maxi(
		int(source.get("current_detection_range_hops", 0)),
		int(definition.get("base_detection_range_hops", 0))
	)
	source["movement_profile"] = str(
		definition.get("movement_profile", "")
	)
	source["movement_budget_milli_arc"] = int(
		(definition.get(
			"movement_budget_milli_arc_by_rank",
			[]
		) as Array)[new_rank - 1]
	)
	source["unlocked_skill_definition_ids"] = _unlocked_skill_ids(
		definition,
		new_rank
	)
	source["skill_states"] = new_skill_states
	var sealed_source := _seal(source, "source_fingerprint")
	if _source_error(sealed_source) != "":
		return {}
	sources[source_id] = sealed_source
	next_state["sources"] = sources
	return {
		"state": next_state,
		"effect": {
			"source_instance_id": source_id,
			"source_generation": int(
				sealed_source.get("source_generation", 0)
			),
			"old_rank": old_rank,
			"new_rank": new_rank,
			"upgrade_full_heal": true,
			"upgrade_cooldown_reset_count": 0,
			"old_skill_state_preserved_count": (
				old_preserved_count
			),
			"new_skill_ready_count": new_ready_count,
		},
	}


static func _resolve_replace(
	state: Dictionary,
	action: Dictionary
) -> Dictionary:
	var old_source_id := str(
		action.get("target_source_instance_id", "")
	)
	var definition := (
		action.get("definition_snapshot", {}) as Dictionary
	)
	var next_state := state.duplicate(true)
	next_state.erase("state_fingerprint")
	var sources := next_state.get("sources", {}) as Dictionary
	var old_source := (
		sources.get(old_source_id, {}) as Dictionary
	).duplicate(true)
	old_source.erase("source_fingerprint")
	old_source["status"] = "withdrawn"
	old_source["withdrawal_reason"] = "replaced"
	old_source["kill_reward_count"] = 0
	old_source["skill_states"] = _revoked_skill_states(
		old_source.get("skill_states", {}) as Dictionary
	)
	var sealed_old_source := _seal(
		old_source,
		"source_fingerprint"
	)
	if _source_error(sealed_old_source) != "":
		return {}
	sources[old_source_id] = sealed_old_source
	var sequence := int(next_state.get("next_source_sequence", 1))
	while sources.has(_source_id_for_sequence(sequence)):
		sequence += 1
	var new_source_id := _source_id_for_sequence(sequence)
	var new_source := build_source_snapshot(
		definition,
		new_source_id,
		str(action.get("owner_player_id", "")),
		str(action.get("deployment_region_id", "")),
		int(action.get("card_rank", 0)),
		-1,
		"active",
		1,
		str(action.get("card_instance_id", ""))
	)
	if new_source.is_empty():
		return {}
	sources[new_source_id] = new_source
	next_state["sources"] = sources
	next_state["next_source_sequence"] = sequence + 1
	return {
		"state": next_state,
		"effect": {
			"source_instance_id": new_source_id,
			"source_generation": 1,
			"withdrawn_source_instance_id": old_source_id,
			"old_rank": int(old_source.get("rank", 0)),
			"new_rank": int(action.get("card_rank", 0)),
			"new_skill_ready_count": int(
				action.get("card_rank", 0)
			),
			"replace_kill_reward_count": 0,
			"withdrawn_counts_as_kill": false,
		},
	}


static func _commit_resolution(
	transition_state: Dictionary,
	action: Dictionary,
	effect: Dictionary,
	resolved: bool,
	reason_code: String,
	base_revision: int = -1
) -> Dictionary:
	var next_state := transition_state.duplicate(true)
	next_state.erase("state_fingerprint")
	var previous_revision := (
		base_revision
		if base_revision >= 0
		else int(transition_state.get("revision", 0))
	)
	next_state["revision"] = previous_revision + 1
	var receipt_unsealed := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": RECEIPT_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"receipt_id": _receipt_id(action),
		"request_id": str(action.get("request_id", "")),
		"action_fingerprint": str(
			action.get("action_fingerprint", "")
		),
		"card_instance_id": str(
			action.get("card_instance_id", "")
		),
		"card_definition_id": str(
			action.get("card_definition_id", "")
		),
		"owner_player_id": str(
			action.get("owner_player_id", "")
		),
		"monster_card_mode": str(
			action.get("monster_card_mode", "")
		),
		"accepted": true,
		"outcome_id": (
			"monster_card_resolved"
			if resolved
			else "monster_card_fizzled"
		),
		"reason_code": reason_code,
		"state_revision": previous_revision + 1,
		"mode_auto_converted": false,
		"mode_auto_conversion_count": 0,
		"source_instance_id": str(
			effect.get("source_instance_id", "")
		),
		"source_generation": int(
			effect.get("source_generation", 0)
		),
		"withdrawn_source_instance_id": str(
			effect.get("withdrawn_source_instance_id", "")
		),
		"old_rank": int(effect.get("old_rank", 0)),
		"new_rank": int(effect.get("new_rank", 0)),
		"refresh_percent": int(
			effect.get("refresh_percent", 0)
		),
		"healing_amount_requested": int(
			effect.get("healing_amount_requested", 0)
		),
		"healing_amount_applied": int(
			effect.get("healing_amount_applied", 0)
		),
		"upgrade_full_heal": bool(
			effect.get("upgrade_full_heal", false)
		),
		"upgrade_cooldown_reset_count": int(
			effect.get("upgrade_cooldown_reset_count", 0)
		),
		"old_skill_state_preserved_count": int(
			effect.get("old_skill_state_preserved_count", 0)
		),
		"new_skill_ready_count": int(
			effect.get("new_skill_ready_count", 0)
		),
		"replace_kill_reward_count": int(
			effect.get("replace_kill_reward_count", 0)
		),
		"withdrawn_counts_as_kill": bool(
			effect.get("withdrawn_counts_as_kill", false)
		),
		"card_destination": "personal_discard",
		"dbg_write_count": 0,
		"exact_once": true,
	}
	var receipt := _seal(
		receipt_unsealed,
		"receipt_fingerprint"
	)
	if _receipt_error(receipt) != "":
		return _failure(
			transition_state,
			"monster_card_receipt_invalid"
		)
	var processed := (
		next_state.get("processed_cards", {}) as Dictionary
	)
	processed[str(action.get("card_instance_id", ""))] = (
		receipt.duplicate(true)
	)
	next_state["processed_cards"] = processed
	var journal := (
		next_state.get("receipt_journal", []) as Array
	).duplicate(true)
	journal.append(receipt.duplicate(true))
	next_state["receipt_journal"] = journal
	next_state = _seal(next_state, "state_fingerprint")
	if _state_error(next_state) != "":
		return _failure(
			transition_state,
			"monster_source_state_commit_invalid"
		)
	return {
		"accepted": true,
		"reason_code": reason_code,
		"state": next_state,
		"receipt": receipt,
		"idempotent_replay": false,
	}


static func _mode_context(
	state: Dictionary,
	request: Dictionary,
	definition: Dictionary,
	is_resolution: bool
) -> Dictionary:
	var mode := str(request.get("monster_card_mode", ""))
	var owner_id := str(request.get("owner_player_id", ""))
	var card_rank := int(request.get("card_rank", 0))
	var family_id := str(definition.get("monster_family_id", ""))
	var target_id := str(
		request.get("target_source_instance_id", "")
	)
	var target_region_id := str(request.get("target_region_id", ""))
	var controlled := controlled_sources_for_player(state, owner_id)
	var capacity := capacity_for_player(state, owner_id)
	var same_family_count := 0
	for source_variant in controlled:
		var controlled_source := source_variant as Dictionary
		if (
			str(controlled_source.get("monster_family_id", ""))
			== family_id
		):
			same_family_count += 1
	var target := {}
	if not target_id.is_empty():
		target = source_snapshot(state, target_id)
	if mode == MODE_DEPLOY_NEW:
		if not target_id.is_empty():
			return {"reason_code": "monster_deploy_target_source_forbidden"}
		if not _stable_id(target_region_id):
			return {"reason_code": "monster_deploy_region_invalid"}
		if controlled.size() >= capacity:
			return {"reason_code": "monster_control_capacity_reached"}
		if same_family_count > 0:
			return {"reason_code": "monster_deploy_same_family_exists"}
		return {
			"reason_code": "",
			"target_source_instance_id": "",
			"target_source_generation": 0,
			"deployment_region_id": target_region_id,
		}
	if target.is_empty():
		return {"reason_code": "monster_target_source_missing"}
	if (
		str(target.get("owner_player_id", "")) != owner_id
		or not CONTROLLED_STATUSES.has(
			str(target.get("status", ""))
		)
	):
		return {"reason_code": "monster_target_source_not_controlled"}
	if (
		is_resolution
		and int(request.get("target_source_generation", 0))
		!= int(target.get("source_generation", -1))
	):
		return {"reason_code": "monster_target_source_generation_changed"}
	if mode in [MODE_REFRESH_EXISTING, MODE_UPGRADE_EXISTING]:
		if (
			str(target.get("monster_family_id", ""))
			!= family_id
		):
			return {"reason_code": "monster_target_family_mismatch"}
	if mode == MODE_REFRESH_EXISTING:
		if card_rank > int(target.get("rank", 0)):
			return {"reason_code": "monster_refresh_rank_requires_upgrade"}
		if (
			int(target.get("hp", 0)) >= int(target.get("max_hp", 0))
			and str(target.get("status", "")) != "downed"
		):
			return {"reason_code": "monster_refresh_full_hp_illegal"}
	elif mode == MODE_UPGRADE_EXISTING:
		if card_rank <= int(target.get("rank", 0)):
			return {"reason_code": "monster_upgrade_rank_not_higher"}
	elif mode == MODE_REPLACE_EXISTING:
		if controlled.size() < capacity:
			return {"reason_code": "monster_replace_capacity_not_reached"}
		if (
			str(target.get("monster_family_id", ""))
			== family_id
		):
			return {"reason_code": "monster_replace_same_family_forbidden"}
		if not _stable_id(target_region_id):
			return {"reason_code": "monster_replace_region_invalid"}
	else:
		return {"reason_code": "monster_card_mode_unknown"}
	return {
		"reason_code": "",
		"target_source_instance_id": target_id,
		"target_source_generation": int(
			target.get("source_generation", 0)
		),
		"deployment_region_id": (
			target_region_id
			if mode == MODE_REPLACE_EXISTING
			else str(target.get("region_id", ""))
		),
	}


static func _action_as_request(action: Dictionary) -> Dictionary:
	return {
		"request_id": str(action.get("request_id", "")),
		"card_instance_id": str(
			action.get("card_instance_id", "")
		),
		"card_definition_id": str(
			action.get("card_definition_id", "")
		),
		"owner_player_id": str(
			action.get("owner_player_id", "")
		),
		"card_rank": int(action.get("card_rank", 0)),
		"monster_card_mode": str(
			action.get("monster_card_mode", "")
		),
		"target_source_instance_id": str(
			action.get("target_source_instance_id", "")
		),
		"target_source_generation": int(
			action.get("target_source_generation", 0)
		),
		"target_region_id": str(
			action.get("deployment_region_id", "")
		),
	}


static func _initial_skill_states(
	definition: Dictionary,
	rank: int,
	source_status: String
) -> Dictionary:
	var result := {}
	var skill_ids := (
		definition.get("active_skill_definition_ids", []) as Array
	)
	for index in range(skill_ids.size()):
		var skill_id := str(skill_ids[index])
		var unlocked := index < rank
		var status := SKILL_READY if unlocked else SKILL_LOCKED
		var resume_status := status
		var generation := 1 if unlocked else 0
		if source_status == "downed" and unlocked:
			status = SKILL_DISABLED
			resume_status = SKILL_READY
		result[skill_id] = _skill_state(
			skill_id,
			status,
			0,
			generation,
			resume_status
		)
	return result


static func _skill_state(
	skill_id: String,
	status: String,
	cooldown_batches_remaining: int,
	skill_generation: int,
	resume_status: String
) -> Dictionary:
	return {
		"skill_definition_id": skill_id,
		"status": status,
		"cooldown_batches_remaining": cooldown_batches_remaining,
		"skill_generation": skill_generation,
		"resume_status": resume_status,
	}


static func _normalize_skill_state(
	skill_id: String,
	value: Variant
) -> Dictionary:
	if not (value is Dictionary) or not _is_pure_data(value):
		return {}
	var source := value as Dictionary
	var status := str(source.get("status", ""))
	var cooldown := int(
		source.get("cooldown_batches_remaining", 0)
	)
	var generation := int(source.get("skill_generation", 0))
	var resume_status := str(
		source.get(
			"resume_status",
			SKILL_COOLDOWN if cooldown > 0 else SKILL_READY
		)
	)
	var result := _skill_state(
		skill_id,
		status,
		cooldown,
		generation,
		resume_status
	)
	return result if _skill_state_error(result) == "" else {}


static func _unlocked_skill_ids(
	definition: Dictionary,
	rank: int
) -> Array:
	var result: Array = []
	var skill_ids := (
		definition.get("active_skill_definition_ids", []) as Array
	)
	for index in range(mini(rank, skill_ids.size())):
		result.append(str(skill_ids[index]))
	return result


static func _revoked_skill_states(skill_states: Dictionary) -> Dictionary:
	var result := {}
	for skill_id_variant in skill_states.keys():
		var skill_id := str(skill_id_variant)
		var previous := (
			skill_states.get(skill_id, {}) as Dictionary
		)
		result[skill_id] = _skill_state(
			skill_id,
			SKILL_REVOKED,
			int(previous.get("cooldown_batches_remaining", 0)),
			int(previous.get("skill_generation", 0)) + 1,
			SKILL_REVOKED
		)
	return result


static func _restore_disabled_skill_states(
	skill_states: Dictionary
) -> Dictionary:
	var result := {}
	for skill_id_variant in skill_states.keys():
		var skill_id := str(skill_id_variant)
		var previous := (
			skill_states.get(skill_id, {}) as Dictionary
		)
		if str(previous.get("status", "")) == SKILL_DISABLED:
			var resume := str(
				previous.get("resume_status", SKILL_READY)
			)
			result[skill_id] = _skill_state(
				skill_id,
				resume,
				int(previous.get(
					"cooldown_batches_remaining",
					0
				)),
				int(previous.get("skill_generation", 0)),
				resume
			)
		else:
			result[skill_id] = previous.duplicate(true)
	return result


static func _refresh_amount(max_hp: int, percent: int) -> int:
	@warning_ignore("integer_division")
	return (max_hp * percent) / 100


static func _source_id_for_sequence(sequence: int) -> String:
	return "monster.source.%08d" % sequence


static func _receipt_id(action: Dictionary) -> String:
	var identity := "%s|%s|%s" % [
		action.get("request_id", ""),
		action.get("card_instance_id", ""),
		action.get("action_fingerprint", ""),
	]
	return "monster.receipt.%s" % identity.sha256_text().substr(0, 24)


static func _bind_failure(reason_code: String) -> Dictionary:
	return {
		"accepted": false,
		"reason_code": reason_code,
		"action": {},
		"state_mutation_count": 0,
		"mode_auto_conversion_count": 0,
	}


static func _failure(state: Dictionary, reason_code: String) -> Dictionary:
	return {
		"accepted": false,
		"reason_code": reason_code,
		"state": (
			state.duplicate(true)
			if state is Dictionary
			else {}
		),
		"receipt": {},
	}


static func _definition_error(definition: Dictionary) -> String:
	if (
		not _is_pure_data(definition)
		or not _exact_fields(definition, DEFINITION_FIELDS)
	):
		return "monster_definition_fields_invalid"
	var unsealed := definition.duplicate(true)
	var fingerprint := str(
		unsealed.get("definition_fingerprint", "")
	)
	unsealed.erase("definition_fingerprint")
	if (
		not _fingerprint_valid(fingerprint)
		or fingerprint != _fingerprint(unsealed)
	):
		return "monster_definition_fingerprint_invalid"
	var facility_preference := _string_id_array(
		definition.get("facility_type_preference", []),
		false
	)
	var movement_budgets := _integer_array(
		definition.get("movement_budget_milli_arc_by_rank", []),
		MAX_MONSTER_RANK,
		true
	)
	var max_hp_by_rank := _integer_array(
		definition.get("max_hp_by_rank", []),
		MAX_MONSTER_RANK,
		true
	)
	var armor_by_rank := _integer_array(
		definition.get("armor_by_rank", []),
		MAX_MONSTER_RANK,
		false
	)
	var skill_ids := _string_id_array(
		definition.get("active_skill_definition_ids", []),
		false
	)
	if (
		definition.get("schema_version") != SCHEMA_VERSION
		or definition.get("contract_id") != DEFINITION_CONTRACT_ID
		or definition.get("ruleset_id") != RULESET_ID
		or not _stable_id(definition.get("source_definition_id"))
		or not _stable_id(definition.get("monster_family_id"))
		or not PREFERRED_COLORS.has(
			str(definition.get("preferred_industry_color", ""))
		)
		or facility_preference.is_empty()
		or facility_preference != definition.get(
			"facility_type_preference",
			[]
		)
		or movement_budgets.size() != MAX_MONSTER_RANK
		or max_hp_by_rank.size() != MAX_MONSTER_RANK
		or armor_by_rank.size() != MAX_MONSTER_RANK
		or skill_ids.size() != MAX_MONSTER_RANK
		or not _nonnegative_integer(
			definition.get("base_detection_range_hops")
		)
		or not MOVEMENT_PROFILES.has(
			str(definition.get("movement_profile", ""))
		)
	):
		return "monster_definition_context_invalid"
	for facility_type in facility_preference:
		if not FACILITY_TYPES.has(facility_type):
			return "monster_definition_facility_preference_invalid"
	return ""


static func _source_error(source: Dictionary) -> String:
	if (
		not _is_pure_data(source)
		or not _exact_fields(source, SOURCE_FIELDS)
	):
		return "monster_source_fields_invalid"
	var unsealed := source.duplicate(true)
	var fingerprint := str(unsealed.get("source_fingerprint", ""))
	unsealed.erase("source_fingerprint")
	if (
		not _fingerprint_valid(fingerprint)
		or fingerprint != _fingerprint(unsealed)
	):
		return "monster_source_fingerprint_invalid"
	var rank := int(source.get("rank", 0))
	var status := str(source.get("status", ""))
	var hp := int(source.get("hp", -1))
	var max_hp := int(source.get("max_hp", -1))
	var unlocked := _string_id_array(
		source.get("unlocked_skill_definition_ids", []),
		true
	)
	var facility_preference := _string_id_array(
		source.get("facility_type_preference", []),
		false
	)
	if (
		source.get("schema_version") != SCHEMA_VERSION
		or source.get("contract_id") != SOURCE_CONTRACT_ID
		or source.get("ruleset_id") != RULESET_ID
		or not _stable_id(source.get("source_instance_id"))
		or not _stable_id(source.get("source_definition_id"))
		or not _fingerprint_valid(
			source.get("definition_fingerprint")
		)
		or not _stable_id(source.get("monster_family_id"))
		or not _stable_id(source.get("owner_player_id"))
		or not _stable_id(source.get("region_id"))
		or not _positive_integer(source.get("source_generation"))
		or rank < 1
		or rank > MAX_MONSTER_RANK
		or not _nonnegative_integer(source.get("hp"))
		or not _positive_integer(source.get("max_hp"))
		or hp > max_hp
		or not _nonnegative_integer(source.get("armor"))
		or not SOURCE_STATUSES.has(status)
		or not _nonnegative_integer(source.get("damage_revision"))
		or not PREFERRED_COLORS.has(
			str(source.get("preferred_industry_color", ""))
		)
		or facility_preference.is_empty()
		or not _nonnegative_integer(
			source.get("base_detection_range_hops")
		)
		or not _nonnegative_integer(
			source.get("current_detection_range_hops")
		)
		or not MOVEMENT_PROFILES.has(
			str(source.get("movement_profile", ""))
		)
		or not _positive_integer(
			source.get("movement_budget_milli_arc")
		)
		or unlocked.size() != rank
		or not _nonnegative_integer(
			source.get("batch_active_skill_use_count")
		)
		or int(source.get(
			"batch_active_skill_use_count",
			-1
		)) > 1
		or not _stable_id(
			source.get("created_from_card_instance_id")
		)
		or not _nonnegative_integer(source.get("kill_reward_count"))
		or int(source.get("kill_reward_count", -1)) != 0
	):
		return "monster_source_context_invalid"
	for facility_type in facility_preference:
		if not FACILITY_TYPES.has(facility_type):
			return "monster_source_facility_preference_invalid"
	if status == "active" and hp <= 0:
		return "monster_active_source_hp_invalid"
	if status == "downed" and hp != 0:
		return "monster_downed_source_hp_invalid"
	if (
		status == "withdrawn"
		and str(source.get("withdrawal_reason", "")) != "replaced"
	):
		return "monster_withdrawn_reason_invalid"
	if (
		status != "withdrawn"
		and not str(source.get("withdrawal_reason", "")).is_empty()
	):
		return "monster_nonwithdrawn_reason_invalid"
	var skill_states_variant: Variant = source.get("skill_states")
	if not (skill_states_variant is Dictionary):
		return "monster_skill_states_invalid"
	var skill_states := skill_states_variant as Dictionary
	if skill_states.size() != MAX_MONSTER_RANK:
		return "monster_skill_state_count_invalid"
	for skill_id_variant in skill_states.keys():
		var skill_id := str(skill_id_variant)
		var skill_state_variant: Variant = skill_states.get(skill_id)
		if (
			not _stable_id(skill_id)
			or not (skill_state_variant is Dictionary)
			or _skill_state_error(
				skill_state_variant as Dictionary
			) != ""
			or str((skill_state_variant as Dictionary).get(
				"skill_definition_id",
				""
			)) != skill_id
		):
			return "monster_skill_state_invalid"
	for skill_id in unlocked:
		if not skill_states.has(skill_id):
			return "monster_unlocked_skill_missing"
	for skill_id_variant in skill_states.keys():
		var skill_id := str(skill_id_variant)
		var skill_status := str(
			(skill_states.get(skill_id, {}) as Dictionary).get(
				"status",
				""
			)
		)
		var is_unlocked := unlocked.has(skill_id)
		if status == "active":
			if (
				is_unlocked
				and skill_status in [
					SKILL_LOCKED,
					SKILL_DISABLED,
					SKILL_REVOKED,
				]
			):
				return "monster_active_unlocked_skill_state_invalid"
			if not is_unlocked and skill_status != SKILL_LOCKED:
				return "monster_active_locked_skill_state_invalid"
		elif status == "downed":
			if is_unlocked and skill_status != SKILL_DISABLED:
				return "monster_downed_skill_not_disabled"
			if not is_unlocked and skill_status != SKILL_LOCKED:
				return "monster_downed_locked_skill_state_invalid"
		elif status in ["destroyed", "withdrawn"]:
			if skill_status != SKILL_REVOKED:
				return "monster_terminal_skill_not_revoked"
	return ""


static func _skill_state_error(skill_state: Dictionary) -> String:
	if (
		not _is_pure_data(skill_state)
		or not _exact_fields(skill_state, SKILL_STATE_FIELDS)
		or not _stable_id(skill_state.get("skill_definition_id"))
		or not SKILL_STATUSES.has(
			str(skill_state.get("status", ""))
		)
		or not _nonnegative_integer(
			skill_state.get("cooldown_batches_remaining")
		)
		or not _nonnegative_integer(
			skill_state.get("skill_generation")
		)
		or str(skill_state.get("resume_status", ""))
		not in [
			SKILL_LOCKED,
			SKILL_READY,
			SKILL_COOLDOWN,
			SKILL_REVOKED,
		]
	):
		return "monster_skill_state_context_invalid"
	var status := str(skill_state.get("status", ""))
	var cooldown := int(
		skill_state.get("cooldown_batches_remaining", 0)
	)
	if status == SKILL_COOLDOWN and cooldown <= 0:
		return "monster_skill_cooldown_value_invalid"
	if status in [SKILL_LOCKED, SKILL_READY] and cooldown != 0:
		return "monster_skill_ready_or_locked_cooldown_invalid"
	return ""


static func _action_error(action: Dictionary) -> String:
	if (
		not _is_pure_data(action)
		or not _exact_fields(action, ACTION_FIELDS)
	):
		return "monster_card_prebound_action_fields_invalid"
	var unsealed := action.duplicate(true)
	var fingerprint := str(unsealed.get("action_fingerprint", ""))
	unsealed.erase("action_fingerprint")
	if (
		not _fingerprint_valid(fingerprint)
		or fingerprint != _fingerprint(unsealed)
	):
		return "monster_card_prebound_action_fingerprint_invalid"
	var mode := str(action.get("monster_card_mode", ""))
	var target_id := str(
		action.get("target_source_instance_id", "")
	)
	var target_generation := int(
		action.get("target_source_generation", 0)
	)
	if (
		action.get("schema_version") != SCHEMA_VERSION
		or action.get("contract_id") != ACTION_CONTRACT_ID
		or action.get("ruleset_id") != RULESET_ID
		or not _stable_id(action.get("request_id"))
		or not _stable_id(action.get("card_instance_id"))
		or not _stable_id(action.get("card_definition_id"))
		or not _stable_id(action.get("owner_player_id"))
		or not _positive_integer(action.get("card_rank"))
		or int(action.get("card_rank", 0)) > MAX_MONSTER_RANK
		or not CARD_MODES.has(mode)
		or not _positive_integer(action.get("bound_state_revision"))
		or not (action.get("definition_snapshot") is Dictionary)
		or _definition_error(
			action.get("definition_snapshot") as Dictionary
		) != ""
		or action.get("prebound") != true
		or action.get("mode_auto_conversion_allowed") != false
	):
		return "monster_card_prebound_action_context_invalid"
	if mode == MODE_DEPLOY_NEW:
		if (
			not target_id.is_empty()
			or target_generation != 0
			or not _stable_id(action.get("deployment_region_id"))
		):
			return "monster_deploy_prebound_target_invalid"
	else:
		if (
			not _stable_id(target_id)
			or target_generation <= 0
			or not _stable_id(action.get("deployment_region_id"))
		):
			return "monster_existing_prebound_target_invalid"
	return ""


static func _receipt_error(receipt: Dictionary) -> String:
	if (
		not _is_pure_data(receipt)
		or not _exact_fields(receipt, RECEIPT_FIELDS)
	):
		return "monster_card_receipt_fields_invalid"
	var unsealed := receipt.duplicate(true)
	var fingerprint := str(unsealed.get("receipt_fingerprint", ""))
	unsealed.erase("receipt_fingerprint")
	if (
		not _fingerprint_valid(fingerprint)
		or fingerprint != _fingerprint(unsealed)
	):
		return "monster_card_receipt_fingerprint_invalid"
	var mode := str(receipt.get("monster_card_mode", ""))
	var outcome := str(receipt.get("outcome_id", ""))
	if (
		receipt.get("schema_version") != SCHEMA_VERSION
		or receipt.get("contract_id") != RECEIPT_CONTRACT_ID
		or receipt.get("ruleset_id") != RULESET_ID
		or not _stable_id(receipt.get("receipt_id"))
		or not _stable_id(receipt.get("request_id"))
		or not _fingerprint_valid(receipt.get("action_fingerprint"))
		or not _stable_id(receipt.get("card_instance_id"))
		or not _stable_id(receipt.get("card_definition_id"))
		or not _stable_id(receipt.get("owner_player_id"))
		or not CARD_MODES.has(mode)
		or receipt.get("accepted") != true
		or outcome not in [
			"monster_card_resolved",
			"monster_card_fizzled",
		]
		or not _positive_integer(receipt.get("state_revision"))
		or receipt.get("mode_auto_converted") != false
		or int(receipt.get("mode_auto_conversion_count", -1)) != 0
		or not _nonnegative_integer(
			receipt.get("source_generation")
		)
		or not _nonnegative_integer(receipt.get("old_rank"))
		or not _nonnegative_integer(receipt.get("new_rank"))
		or not _nonnegative_integer(receipt.get("refresh_percent"))
		or not _nonnegative_integer(
			receipt.get("healing_amount_requested")
		)
		or not _nonnegative_integer(
			receipt.get("healing_amount_applied")
		)
		or not (receipt.get("upgrade_full_heal") is bool)
		or int(receipt.get(
			"upgrade_cooldown_reset_count",
			-1
		)) != 0
		or not _nonnegative_integer(
			receipt.get("old_skill_state_preserved_count")
		)
		or not _nonnegative_integer(
			receipt.get("new_skill_ready_count")
		)
		or int(receipt.get("replace_kill_reward_count", -1)) != 0
		or receipt.get("withdrawn_counts_as_kill") != false
		or receipt.get("card_destination") != "personal_discard"
		or int(receipt.get("dbg_write_count", -1)) != 0
		or receipt.get("exact_once") != true
	):
		return "monster_card_receipt_context_invalid"
	if outcome == "monster_card_fizzled":
		if (
			not str(receipt.get("source_instance_id", "")).is_empty()
			or int(receipt.get("source_generation", -1)) != 0
			or not str(receipt.get(
				"withdrawn_source_instance_id",
				""
			)).is_empty()
		):
			return "monster_card_fizzle_effect_invalid"
		return ""
	if not _stable_id(receipt.get("source_instance_id")):
		return "monster_card_resolved_source_invalid"
	if mode == MODE_REFRESH_EXISTING:
		if (
			not REFRESH_PERCENT_BY_RANK.values().has(
				int(receipt.get("refresh_percent", 0))
			)
			or int(receipt.get("healing_amount_applied", 0))
			> int(receipt.get("healing_amount_requested", 0))
		):
			return "monster_refresh_receipt_invalid"
	elif mode == MODE_UPGRADE_EXISTING:
		if (
			receipt.get("upgrade_full_heal") != true
			or int(receipt.get("new_rank", 0))
			<= int(receipt.get("old_rank", 0))
		):
			return "monster_upgrade_receipt_invalid"
	elif mode == MODE_REPLACE_EXISTING:
		if not _stable_id(
			receipt.get("withdrawn_source_instance_id")
		):
			return "monster_replace_receipt_invalid"
	return ""


static func _state_error(state: Dictionary) -> String:
	if (
		not _is_pure_data(state)
		or not _exact_fields(state, STATE_FIELDS)
	):
		return "monster_source_state_fields_invalid"
	var unsealed := state.duplicate(true)
	var fingerprint := str(unsealed.get("state_fingerprint", ""))
	unsealed.erase("state_fingerprint")
	if (
		not _fingerprint_valid(fingerprint)
		or fingerprint != _fingerprint(unsealed)
	):
		return "monster_source_state_fingerprint_invalid"
	var player_ids := _string_id_array(
		state.get("player_ids", []),
		false
	)
	var sorted_players := player_ids.duplicate()
	sorted_players.sort()
	if (
		state.get("schema_version") != SCHEMA_VERSION
		or state.get("contract_id") != STATE_CONTRACT_ID
		or state.get("ruleset_id") != RULESET_ID
		or not _positive_integer(state.get("revision"))
		or player_ids.is_empty()
		or player_ids != sorted_players
		or not _positive_integer(state.get("next_source_sequence"))
	):
		return "monster_source_state_context_invalid"
	var semantics_variant: Variant = state.get(
		"character_capacity_semantics"
	)
	if not (semantics_variant is Dictionary):
		return "monster_capacity_semantics_invalid"
	var semantics := semantics_variant as Dictionary
	if semantics.size() != player_ids.size():
		return "monster_capacity_semantics_count_invalid"
	for player_id in player_ids:
		var semantic_variant: Variant = semantics.get(player_id)
		if (
			not (semantic_variant is Dictionary)
			or not bool(CapacityPort.capacity_receipt(
				semantic_variant as Dictionary
			).get("accepted", false))
			or str((semantic_variant as Dictionary).get(
				"player_id",
				""
			)) != player_id
		):
			return "monster_capacity_semantic_invalid"
	var sources_variant: Variant = state.get("sources")
	if not (sources_variant is Dictionary):
		return "monster_sources_invalid"
	var family_owner_keys := {}
	for source_id_variant in (sources_variant as Dictionary).keys():
		var source_id := str(source_id_variant)
		var source_variant: Variant = (
			sources_variant as Dictionary
		).get(source_id)
		if (
			not (source_variant is Dictionary)
			or _source_error(source_variant as Dictionary) != ""
			or str((source_variant as Dictionary).get(
				"source_instance_id",
				""
			)) != source_id
			or not player_ids.has(str(
				(source_variant as Dictionary).get(
					"owner_player_id",
					""
				)
			))
		):
			return "monster_source_entry_invalid"
		var source := source_variant as Dictionary
		if CONTROLLED_STATUSES.has(str(source.get("status", ""))):
			var family_owner_key := "%s|%s" % [
				source.get("owner_player_id", ""),
				source.get("monster_family_id", ""),
			]
			if family_owner_keys.has(family_owner_key):
				return "monster_controlled_family_duplicate"
			family_owner_keys[family_owner_key] = true
	var processed_variant: Variant = state.get("processed_cards")
	var journal_variant: Variant = state.get("receipt_journal")
	if (
		not (processed_variant is Dictionary)
		or not (journal_variant is Array)
		or (processed_variant as Dictionary).size()
		!= (journal_variant as Array).size()
	):
		return "monster_receipt_journal_invalid"
	for card_id_variant in (processed_variant as Dictionary).keys():
		var card_id := str(card_id_variant)
		var receipt_variant: Variant = (
			processed_variant as Dictionary
		).get(card_id)
		if (
			not _stable_id(card_id)
			or not (receipt_variant is Dictionary)
			or _receipt_error(receipt_variant as Dictionary) != ""
			or str((receipt_variant as Dictionary).get(
				"card_instance_id",
				""
			)) != card_id
		):
			return "monster_processed_card_invalid"
	for receipt_variant in journal_variant as Array:
		if (
			not (receipt_variant is Dictionary)
			or _receipt_error(receipt_variant as Dictionary) != ""
			or (processed_variant as Dictionary).get(str(
				(receipt_variant as Dictionary).get(
					"card_instance_id",
					""
				)
			)) != receipt_variant
		):
			return "monster_receipt_journal_entry_invalid"
	return ""


static func _checkpoint_error(checkpoint: Dictionary) -> String:
	if (
		not _is_pure_data(checkpoint)
		or not _exact_fields(checkpoint, CHECKPOINT_FIELDS)
	):
		return "monster_checkpoint_fields_invalid"
	var unsealed := checkpoint.duplicate(true)
	var fingerprint := str(
		unsealed.get("checkpoint_fingerprint", "")
	)
	unsealed.erase("checkpoint_fingerprint")
	if (
		not _fingerprint_valid(fingerprint)
		or fingerprint != _fingerprint(unsealed)
	):
		return "monster_checkpoint_fingerprint_invalid"
	var state_variant: Variant = checkpoint.get("state")
	if (
		checkpoint.get("schema_version") != SCHEMA_VERSION
		or checkpoint.get("contract_id") != CHECKPOINT_CONTRACT_ID
		or checkpoint.get("ruleset_id") != RULESET_ID
		or not _stable_id(checkpoint.get("checkpoint_id"))
		or not _positive_integer(
			checkpoint.get("captured_state_revision")
		)
		or not (state_variant is Dictionary)
		or _state_error(state_variant as Dictionary) != ""
		or int(checkpoint.get("captured_state_revision", 0))
		!= int((state_variant as Dictionary).get("revision", -1))
	):
		return "monster_checkpoint_context_invalid"
	return ""


static func _seal(
	unsealed: Dictionary,
	fingerprint_field: String
) -> Dictionary:
	if (
		not _is_pure_data(unsealed)
		or unsealed.has(fingerprint_field)
	):
		return {}
	var sealed := unsealed.duplicate(true)
	sealed[fingerprint_field] = _fingerprint(unsealed)
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
		var items: Array[String] = []
		for item_variant in value as Array:
			items.append(_canonical_json(item_variant))
		return "[" + ",".join(items) + "]"
	var source := value as Dictionary
	var keys: Array[String] = []
	for key_variant in source.keys():
		keys.append(str(key_variant))
	keys.sort()
	var members: Array[String] = []
	for key in keys:
		members.append(
			JSON.stringify(key) + ":" + _canonical_json(source.get(key))
		)
	return "{" + ",".join(members) + "}"


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
			if (
				not (key_variant is String)
				or not _is_pure_data(
					(value as Dictionary).get(key_variant),
					depth + 1
				)
			):
				return false
		return true
	return false


static func _integer_array(
	value: Variant,
	expected_size: int,
	positive: bool
) -> Array:
	var result: Array = []
	if not (value is Array) or (value as Array).size() != expected_size:
		return result
	for item_variant in value as Array:
		if (
			(positive and not _positive_integer(item_variant))
			or (not positive and not _nonnegative_integer(item_variant))
		):
			return []
		result.append(int(item_variant))
	return result


static func _string_id_array(
	value: Variant,
	allow_empty: bool
) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for item_variant in value as Array:
		if (
			not _stable_id(item_variant)
			or result.has(str(item_variant))
		):
			return []
		result.append(str(item_variant))
	if not allow_empty and result.is_empty():
		return []
	return result


static func _exact_fields(
	value: Dictionary,
	fields: Array
) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


static func _safe_integer(value: Variant) -> bool:
	return (
		value is int
		and int(value) >= -MAX_SAFE_INTEGER
		and int(value) <= MAX_SAFE_INTEGER
	)


static func _nonnegative_integer(value: Variant) -> bool:
	return _safe_integer(value) and int(value) >= 0


static func _positive_integer(value: Variant) -> bool:
	return _safe_integer(value) and int(value) > 0


static func _fingerprint_valid(value: Variant) -> bool:
	if not (value is String) or str(value).length() != 64:
		return false
	for index in range(str(value).length()):
		var code := str(value).unicode_at(index)
		if not (
			(code >= 48 and code <= 57)
			or (code >= 97 and code <= 102)
		):
			return false
	return true


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
