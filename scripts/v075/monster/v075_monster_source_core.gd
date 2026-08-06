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
const TRANSITION_OPERATION_CONTRACT_ID := (
	"v075.monster_source_runtime_transition_operation.v1"
)
const TRANSITION_RECEIPT_CONTRACT_ID := (
	"v075.monster_source_runtime_transition_receipt.v1"
)
const BASE_MONSTER_CONTROL_CAPACITY_PER_PLAYER := (
	CapacityPort.BASE_MONSTER_CONTROL_CAPACITY_PER_PLAYER
)
const MAX_MONSTER_RANK := 4
const MAX_SAFE_INTEGER := 9007199254740991

const MODE_DEPLOY_NEW := "DEPLOY_NEW"
const MODE_REFRESH_EXISTING := "REFRESH_EXISTING"
const MODE_UPGRADE_EXISTING := "UPGRADE_EXISTING"
const MODE_REPLACE_EXISTING := "REPLACE_EXISTING"
const TRANSITION_MOVE_REGION := "MOVE_REGION"
const TRANSITION_DETECTION_RANGE := "DETECTION_RANGE"
const TRANSITION_COMBAT_DAMAGE := "COMBAT_DAMAGE"
const TRANSITION_DESTROY_SOURCE := "DESTROY_SOURCE"
const TRANSITION_KINDS := [
	TRANSITION_MOVE_REGION,
	TRANSITION_DETECTION_RANGE,
	TRANSITION_COMBAT_DAMAGE,
	TRANSITION_DESTROY_SOURCE,
]
const DETECTION_PREFERRED_COLOR_HIT := "PREFERRED_COLOR_HIT"
const DETECTION_NO_TARGET_GROWTH := "NO_TARGET_GROWTH"
const DETECTION_HUNGRY_PLAN := "HUNGRY_PLAN"
const DETECTION_TRANSITION_KINDS := [
	DETECTION_PREFERRED_COLOR_HIT,
	DETECTION_NO_TARGET_GROWTH,
	DETECTION_HUNGRY_PLAN,
]
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
const TRANSITION_OPERATION_FIELDS := [
	"schema_version",
	"contract_id",
	"ruleset_id",
	"operation_id",
	"operation_kind",
	"source_instance_id",
	"expected_source_generation",
	"destination_region_id",
	"detection_transition_kind",
	"full_map_detection_range_hops",
	"damage_amount",
	"destroy_reason_id",
	"operation_fingerprint",
]
const TRANSITION_RECEIPT_FIELDS := [
	"schema_version",
	"contract_id",
	"ruleset_id",
	"receipt_id",
	"operation_id",
	"operation_fingerprint",
	"operation_kind",
	"source_instance_id",
	"source_generation",
	"committed",
	"state_revision",
	"reason_code",
	"previous_region_id",
	"current_region_id",
	"previous_detection_range_hops",
	"current_detection_range_hops",
	"detection_transition_kind",
	"hungry_after_transition",
	"destroy_reason_id",
	"incoming_damage",
	"armor_before",
	"armor_absorbed",
	"armor_after",
	"hp_before",
	"hp_damage",
	"hp_after",
	"damage_revision_before",
	"damage_revision_after",
	"status_before",
	"status_after",
	"animation_authority_count",
	"frame_position_mutation_count",
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
	"processed_transitions",
	"transition_receipt_journal",
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
		"processed_transitions": {},
		"transition_receipt_journal": [],
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


static func build_movement_transition_operation(
	operation_id: String,
	source_instance_id: String,
	expected_source_generation: int,
	destination_region_id: String
) -> Dictionary:
	return _build_transition_operation(
		operation_id,
		TRANSITION_MOVE_REGION,
		source_instance_id,
		expected_source_generation,
		destination_region_id,
		null,
		null,
		null,
		null
	)


static func build_detection_range_transition_operation(
	operation_id: String,
	source_instance_id: String,
	expected_source_generation: int,
	detection_transition_kind: String,
	full_map_detection_range_hops: int = 0
) -> Dictionary:
	return _build_transition_operation(
		operation_id,
		TRANSITION_DETECTION_RANGE,
		source_instance_id,
		expected_source_generation,
		null,
		detection_transition_kind,
		(
			null
			if detection_transition_kind
			== DETECTION_PREFERRED_COLOR_HIT
			else full_map_detection_range_hops
		),
		null,
		null
	)


static func build_combat_damage_transition_operation(
	operation_id: String,
	source_instance_id: String,
	expected_source_generation: int,
	damage_amount: int
) -> Dictionary:
	return _build_transition_operation(
		operation_id,
		TRANSITION_COMBAT_DAMAGE,
		source_instance_id,
		expected_source_generation,
		null,
		null,
		null,
		damage_amount,
		null
	)


static func build_destroy_transition_operation(
	operation_id: String,
	source_instance_id: String,
	expected_source_generation: int,
	destroy_reason_id: String
) -> Dictionary:
	return _build_transition_operation(
		operation_id,
		TRANSITION_DESTROY_SOURCE,
		source_instance_id,
		expected_source_generation,
		null,
		null,
		null,
		null,
		destroy_reason_id
	)


static func commit_authoritative_movement(
	state: Dictionary,
	operation_id: String,
	source_instance_id: String,
	expected_source_generation: int,
	destination_region_id: String
) -> Dictionary:
	var operation := build_movement_transition_operation(
		operation_id,
		source_instance_id,
		expected_source_generation,
		destination_region_id
	)
	if operation.is_empty():
		return _failure(state, "monster_movement_operation_invalid")
	return commit_runtime_transition(state, operation)


static func commit_detection_range_transition(
	state: Dictionary,
	operation_id: String,
	source_instance_id: String,
	expected_source_generation: int,
	detection_transition_kind: String,
	full_map_detection_range_hops: int = 0
) -> Dictionary:
	var operation := build_detection_range_transition_operation(
		operation_id,
		source_instance_id,
		expected_source_generation,
		detection_transition_kind,
		full_map_detection_range_hops
	)
	if operation.is_empty():
		return _failure(state, "monster_detection_operation_invalid")
	return commit_runtime_transition(state, operation)


static func commit_combat_damage(
	state: Dictionary,
	operation_id: String,
	source_instance_id: String,
	expected_source_generation: int,
	damage_amount: int
) -> Dictionary:
	var operation := build_combat_damage_transition_operation(
		operation_id,
		source_instance_id,
		expected_source_generation,
		damage_amount
	)
	if operation.is_empty():
		return _failure(state, "monster_damage_operation_invalid")
	return commit_runtime_transition(state, operation)


static func commit_destroy_transition(
	state: Dictionary,
	operation_id: String,
	source_instance_id: String,
	expected_source_generation: int,
	destroy_reason_id: String
) -> Dictionary:
	var operation := build_destroy_transition_operation(
		operation_id,
		source_instance_id,
		expected_source_generation,
		destroy_reason_id
	)
	if operation.is_empty():
		return _failure(state, "monster_destroy_operation_invalid")
	return commit_runtime_transition(state, operation)


static func commit_runtime_transition(
	state: Dictionary,
	operation: Dictionary
) -> Dictionary:
	var state_error := _state_error(state)
	if state_error != "":
		return _failure(state, state_error)
	var operation_error := _transition_operation_error(operation)
	if operation_error != "":
		return _failure(state, operation_error)
	var operation_id := str(operation.get("operation_id", ""))
	var processed := (
		state.get("processed_transitions", {}) as Dictionary
	)
	if processed.has(operation_id):
		var stored := (
			processed.get(operation_id, {}) as Dictionary
		)
		if (
			str(stored.get("operation_fingerprint", ""))
			!= str(operation.get("operation_fingerprint", ""))
		):
			return _failure(
				state,
				"monster_transition_operation_id_conflict"
			)
		return {
			"accepted": true,
			"reason_code": (
				"monster_runtime_transition_idempotent_replay"
			),
			"state": state.duplicate(true),
			"receipt": stored.duplicate(true),
			"idempotent_replay": true,
		}
	var source_id := str(operation.get("source_instance_id", ""))
	var source := source_snapshot(state, source_id)
	if source.is_empty():
		return _failure(state, "monster_transition_source_missing")
	if (
		int(operation.get("expected_source_generation", 0))
		!= int(source.get("source_generation", -1))
	):
		return _failure(
			state,
			"monster_transition_source_generation_mismatch"
		)
	var transition := _apply_runtime_transition(
		state,
		operation,
		source
	)
	if not bool(transition.get("accepted", false)):
		return _failure(
			state,
			str(transition.get(
				"reason_code",
				"monster_runtime_transition_rejected"
			))
		)
	var next_state := (
		transition.get("state", {}) as Dictionary
	).duplicate(true)
	next_state.erase("state_fingerprint")
	var next_revision := int(state.get("revision", 0)) + 1
	next_state["revision"] = next_revision
	var receipt := _build_transition_receipt(
		operation,
		transition.get("effect", {}) as Dictionary,
		next_revision
	)
	if _transition_receipt_error(receipt) != "":
		return _failure(
			state,
			"monster_runtime_transition_receipt_invalid"
		)
	var next_processed := (
		next_state.get(
			"processed_transitions",
			{}
		) as Dictionary
	)
	next_processed[operation_id] = receipt.duplicate(true)
	next_state["processed_transitions"] = next_processed
	var journal := (
		next_state.get(
			"transition_receipt_journal",
			[]
		) as Array
	).duplicate(true)
	journal.append(receipt.duplicate(true))
	next_state["transition_receipt_journal"] = journal
	next_state = _seal(next_state, "state_fingerprint")
	if _state_error(next_state) != "":
		return _failure(
			state,
			"monster_runtime_transition_state_invalid"
		)
	return {
		"accepted": true,
		"reason_code": str(receipt.get("reason_code", "")),
		"state": next_state,
		"receipt": receipt,
		"idempotent_replay": false,
	}


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
		"runtime_transition_operation_contract_id": (
			TRANSITION_OPERATION_CONTRACT_ID
		),
		"runtime_transition_receipt_contract_id": (
			TRANSITION_RECEIPT_CONTRACT_ID
		),
		"runtime_transition_kinds": TRANSITION_KINDS.duplicate(),
		"detection_transition_kinds": (
			DETECTION_TRANSITION_KINDS.duplicate()
		),
		"runtime_transition_exact_once": true,
		"runtime_owner_direct_sealed_state_write_allowed": false,
		"movement_animation_authority_count": 0,
		"movement_frame_position_mutation_count": 0,
	}


static func _build_transition_operation(
	operation_id: String,
	operation_kind: String,
	source_instance_id: String,
	expected_source_generation: int,
	destination_region_id: Variant,
	detection_transition_kind: Variant,
	full_map_detection_range_hops: Variant,
	damage_amount: Variant,
	destroy_reason_id: Variant
) -> Dictionary:
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": TRANSITION_OPERATION_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"operation_id": operation_id,
		"operation_kind": operation_kind,
		"source_instance_id": source_instance_id,
		"expected_source_generation": expected_source_generation,
		"destination_region_id": destination_region_id,
		"detection_transition_kind": detection_transition_kind,
		"full_map_detection_range_hops": (
			full_map_detection_range_hops
		),
		"damage_amount": damage_amount,
		"destroy_reason_id": destroy_reason_id,
	}
	var operation := _seal(
		unsealed,
		"operation_fingerprint"
	)
	return (
		operation
		if _transition_operation_error(operation) == ""
		else {}
	)


static func _apply_runtime_transition(
	state: Dictionary,
	operation: Dictionary,
	source: Dictionary
) -> Dictionary:
	match str(operation.get("operation_kind", "")):
		TRANSITION_MOVE_REGION:
			return _apply_movement_transition(
				state,
				operation,
				source
			)
		TRANSITION_DETECTION_RANGE:
			return _apply_detection_transition(
				state,
				operation,
				source
			)
		TRANSITION_COMBAT_DAMAGE:
			return _apply_damage_transition(
				state,
				operation,
				source
			)
		TRANSITION_DESTROY_SOURCE:
			return _apply_destroy_transition(
				state,
				operation,
				source
			)
	return {
		"accepted": false,
		"reason_code": "monster_runtime_transition_kind_unknown",
	}


static func _apply_movement_transition(
	state: Dictionary,
	operation: Dictionary,
	source: Dictionary
) -> Dictionary:
	var status := str(source.get("status", ""))
	if status == "downed":
		return {
			"accepted": false,
			"reason_code": "monster_movement_source_downed",
		}
	if status != "active":
		return {
			"accepted": false,
			"reason_code": "monster_movement_source_not_active",
		}
	var destination := str(
		operation.get("destination_region_id", "")
	)
	var previous_region := str(source.get("region_id", ""))
	if destination == previous_region:
		return {
			"accepted": false,
			"reason_code": "monster_movement_destination_unchanged",
		}
	var next_source := source.duplicate(true)
	next_source.erase("source_fingerprint")
	next_source["region_id"] = destination
	next_source = _seal(next_source, "source_fingerprint")
	if _source_error(next_source) != "":
		return {
			"accepted": false,
			"reason_code": "monster_movement_source_commit_invalid",
		}
	var effect := _base_transition_effect(source)
	effect["reason_code"] = "monster_authoritative_movement_committed"
	effect["current_region_id"] = destination
	return {
		"accepted": true,
		"state": _transition_state_with_source(
			state,
			next_source
		),
		"effect": effect,
	}


static func _apply_detection_transition(
	state: Dictionary,
	operation: Dictionary,
	source: Dictionary
) -> Dictionary:
	var status := str(source.get("status", ""))
	if status == "downed":
		return {
			"accepted": false,
			"reason_code": "monster_detection_source_downed",
		}
	if status != "active":
		return {
			"accepted": false,
			"reason_code": "monster_detection_source_not_active",
		}
	var transition_kind := str(
		operation.get("detection_transition_kind", "")
	)
	var base_range := int(
		source.get("base_detection_range_hops", 0)
	)
	var current_range := int(
		source.get("current_detection_range_hops", 0)
	)
	var next_range := current_range
	var hungry_after := false
	var reason_code := ""
	if transition_kind == DETECTION_PREFERRED_COLOR_HIT:
		next_range = base_range
		reason_code = "monster_detection_preferred_color_restored"
	elif transition_kind == DETECTION_NO_TARGET_GROWTH:
		var full_map_range := int(
			operation.get("full_map_detection_range_hops", 0)
		)
		if full_map_range < base_range:
			return {
				"accepted": false,
				"reason_code": "monster_detection_full_map_range_invalid",
			}
		if current_range >= full_map_range:
			return {
				"accepted": false,
				"reason_code": (
					"monster_detection_requires_hungry_plan"
				),
			}
		next_range = mini(current_range + 1, full_map_range)
		reason_code = "monster_detection_no_target_expanded"
	elif transition_kind == DETECTION_HUNGRY_PLAN:
		var full_map_range := int(
			operation.get("full_map_detection_range_hops", 0)
		)
		if full_map_range < base_range:
			return {
				"accepted": false,
				"reason_code": "monster_detection_full_map_range_invalid",
			}
		if current_range < full_map_range:
			return {
				"accepted": false,
				"reason_code": (
					"monster_detection_hungry_before_full_map"
				),
			}
		next_range = full_map_range
		hungry_after = true
		reason_code = "monster_detection_hungry_plan_committed"
	else:
		return {
			"accepted": false,
			"reason_code": "monster_detection_transition_kind_invalid",
		}
	var next_source := source.duplicate(true)
	next_source.erase("source_fingerprint")
	next_source["current_detection_range_hops"] = next_range
	next_source = _seal(next_source, "source_fingerprint")
	if _source_error(next_source) != "":
		return {
			"accepted": false,
			"reason_code": "monster_detection_source_commit_invalid",
		}
	var effect := _base_transition_effect(source)
	effect["reason_code"] = reason_code
	effect["current_detection_range_hops"] = next_range
	effect["detection_transition_kind"] = transition_kind
	effect["hungry_after_transition"] = hungry_after
	return {
		"accepted": true,
		"state": _transition_state_with_source(
			state,
			next_source
		),
		"effect": effect,
	}


static func _apply_damage_transition(
	state: Dictionary,
	operation: Dictionary,
	source: Dictionary
) -> Dictionary:
	var status := str(source.get("status", ""))
	if status == "downed":
		return {
			"accepted": false,
			"reason_code": (
				"monster_damage_source_downed_requires_destroy"
			),
		}
	if status != "active":
		return {
			"accepted": false,
			"reason_code": "monster_damage_source_not_active",
		}
	var incoming_damage := int(operation.get("damage_amount", 0))
	var armor_before := int(source.get("armor", 0))
	var hp_before := int(source.get("hp", 0))
	var absorbed := mini(armor_before, incoming_damage)
	var hp_damage := mini(
		hp_before,
		incoming_damage - absorbed
	)
	var armor_after := armor_before - absorbed
	var hp_after := hp_before - hp_damage
	var next_status := "downed" if hp_after == 0 else "active"
	var next_source := source.duplicate(true)
	next_source.erase("source_fingerprint")
	next_source["armor"] = armor_after
	next_source["hp"] = hp_after
	next_source["status"] = next_status
	next_source["damage_revision"] = int(
		source.get("damage_revision", 0)
	) + 1
	if next_status == "downed":
		next_source["skill_states"] = _disabled_skill_states(
			next_source.get("skill_states", {}) as Dictionary
		)
	next_source = _seal(next_source, "source_fingerprint")
	if _source_error(next_source) != "":
		return {
			"accepted": false,
			"reason_code": "monster_damage_source_commit_invalid",
		}
	var effect := _base_transition_effect(source)
	effect["reason_code"] = (
		"monster_combat_damage_downed"
		if next_status == "downed"
		else "monster_combat_damage_committed"
	)
	effect["incoming_damage"] = incoming_damage
	effect["armor_absorbed"] = absorbed
	effect["armor_after"] = armor_after
	effect["hp_damage"] = hp_damage
	effect["hp_after"] = hp_after
	effect["damage_revision_after"] = int(
		next_source.get("damage_revision", 0)
	)
	effect["status_after"] = next_status
	return {
		"accepted": true,
		"state": _transition_state_with_source(
			state,
			next_source
		),
		"effect": effect,
	}


static func _apply_destroy_transition(
	state: Dictionary,
	operation: Dictionary,
	source: Dictionary
) -> Dictionary:
	var status := str(source.get("status", ""))
	if status != "downed":
		return {
			"accepted": false,
			"reason_code": "monster_destroy_requires_downed_source",
		}
	var next_source := source.duplicate(true)
	next_source.erase("source_fingerprint")
	next_source["status"] = "destroyed"
	next_source["damage_revision"] = int(
		source.get("damage_revision", 0)
	) + 1
	next_source["skill_states"] = _revoked_skill_states(
		next_source.get("skill_states", {}) as Dictionary
	)
	next_source = _seal(next_source, "source_fingerprint")
	if _source_error(next_source) != "":
		return {
			"accepted": false,
			"reason_code": "monster_destroy_source_commit_invalid",
		}
	var effect := _base_transition_effect(source)
	effect["reason_code"] = "monster_destroy_transition_committed"
	effect["destroy_reason_id"] = str(
		operation.get("destroy_reason_id", "")
	)
	effect["damage_revision_after"] = int(
		next_source.get("damage_revision", 0)
	)
	effect["status_after"] = "destroyed"
	return {
		"accepted": true,
		"state": _transition_state_with_source(
			state,
			next_source
		),
		"effect": effect,
	}


static func _base_transition_effect(source: Dictionary) -> Dictionary:
	return {
		"reason_code": "",
		"previous_region_id": str(source.get("region_id", "")),
		"current_region_id": str(source.get("region_id", "")),
		"previous_detection_range_hops": int(
			source.get("current_detection_range_hops", 0)
		),
		"current_detection_range_hops": int(
			source.get("current_detection_range_hops", 0)
		),
		"detection_transition_kind": "",
		"hungry_after_transition": false,
		"destroy_reason_id": "",
		"incoming_damage": 0,
		"armor_before": int(source.get("armor", 0)),
		"armor_absorbed": 0,
		"armor_after": int(source.get("armor", 0)),
		"hp_before": int(source.get("hp", 0)),
		"hp_damage": 0,
		"hp_after": int(source.get("hp", 0)),
		"damage_revision_before": int(
			source.get("damage_revision", 0)
		),
		"damage_revision_after": int(
			source.get("damage_revision", 0)
		),
		"status_before": str(source.get("status", "")),
		"status_after": str(source.get("status", "")),
	}


static func _transition_state_with_source(
	state: Dictionary,
	source: Dictionary
) -> Dictionary:
	var next_state := state.duplicate(true)
	next_state.erase("state_fingerprint")
	var sources := next_state.get("sources", {}) as Dictionary
	sources[str(source.get("source_instance_id", ""))] = (
		source.duplicate(true)
	)
	next_state["sources"] = sources
	return next_state


static func _disabled_skill_states(
	skill_states: Dictionary
) -> Dictionary:
	var result := {}
	for skill_id_variant in skill_states.keys():
		var skill_id := str(skill_id_variant)
		var previous := (
			skill_states.get(skill_id, {}) as Dictionary
		)
		var previous_status := str(previous.get("status", ""))
		if previous_status == SKILL_LOCKED:
			result[skill_id] = previous.duplicate(true)
			continue
		var resume := str(
			previous.get("resume_status", SKILL_READY)
		)
		if previous_status == SKILL_COOLDOWN:
			resume = SKILL_COOLDOWN
		if resume not in [SKILL_READY, SKILL_COOLDOWN]:
			resume = SKILL_READY
		result[skill_id] = _skill_state(
			skill_id,
			SKILL_DISABLED,
			(
				int(previous.get(
					"cooldown_batches_remaining",
					0
				))
				if resume == SKILL_COOLDOWN
				else 0
			),
			int(previous.get("skill_generation", 0)),
			resume
		)
	return result


static func _build_transition_receipt(
	operation: Dictionary,
	effect: Dictionary,
	state_revision: int
) -> Dictionary:
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": TRANSITION_RECEIPT_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"receipt_id": _transition_receipt_id(operation),
		"operation_id": str(operation.get("operation_id", "")),
		"operation_fingerprint": str(
			operation.get("operation_fingerprint", "")
		),
		"operation_kind": str(operation.get("operation_kind", "")),
		"source_instance_id": str(
			operation.get("source_instance_id", "")
		),
		"source_generation": int(
			operation.get("expected_source_generation", 0)
		),
		"committed": true,
		"state_revision": state_revision,
		"reason_code": str(effect.get("reason_code", "")),
		"previous_region_id": str(
			effect.get("previous_region_id", "")
		),
		"current_region_id": str(
			effect.get("current_region_id", "")
		),
		"previous_detection_range_hops": int(
			effect.get("previous_detection_range_hops", 0)
		),
		"current_detection_range_hops": int(
			effect.get("current_detection_range_hops", 0)
		),
		"detection_transition_kind": str(
			effect.get("detection_transition_kind", "")
		),
		"hungry_after_transition": bool(
			effect.get("hungry_after_transition", false)
		),
		"destroy_reason_id": str(
			effect.get("destroy_reason_id", "")
		),
		"incoming_damage": int(effect.get("incoming_damage", 0)),
		"armor_before": int(effect.get("armor_before", 0)),
		"armor_absorbed": int(effect.get("armor_absorbed", 0)),
		"armor_after": int(effect.get("armor_after", 0)),
		"hp_before": int(effect.get("hp_before", 0)),
		"hp_damage": int(effect.get("hp_damage", 0)),
		"hp_after": int(effect.get("hp_after", 0)),
		"damage_revision_before": int(
			effect.get("damage_revision_before", 0)
		),
		"damage_revision_after": int(
			effect.get("damage_revision_after", 0)
		),
		"status_before": str(effect.get("status_before", "")),
		"status_after": str(effect.get("status_after", "")),
		"animation_authority_count": 0,
		"frame_position_mutation_count": 0,
		"exact_once": true,
	}
	return _seal(unsealed, "receipt_fingerprint")


static func _transition_receipt_id(operation: Dictionary) -> String:
	var identity := "%s|%s" % [
		operation.get("operation_id", ""),
		operation.get("operation_fingerprint", ""),
	]
	return "monster.transition.receipt.%s" % (
		identity.sha256_text().substr(0, 24)
	)


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


static func _transition_operation_error(
	operation: Dictionary
) -> String:
	if (
		not _is_pure_data(operation)
		or not _exact_fields(
			operation,
			TRANSITION_OPERATION_FIELDS
		)
	):
		return "monster_transition_operation_fields_invalid"
	var unsealed := operation.duplicate(true)
	var fingerprint := str(
		unsealed.get("operation_fingerprint", "")
	)
	unsealed.erase("operation_fingerprint")
	if (
		not _fingerprint_valid(fingerprint)
		or fingerprint != _fingerprint(unsealed)
	):
		return "monster_transition_operation_fingerprint_invalid"
	var kind := str(operation.get("operation_kind", ""))
	if (
		operation.get("schema_version") != SCHEMA_VERSION
		or operation.get("contract_id")
		!= TRANSITION_OPERATION_CONTRACT_ID
		or operation.get("ruleset_id") != RULESET_ID
		or not _stable_id(operation.get("operation_id"))
		or not TRANSITION_KINDS.has(kind)
		or not _stable_id(operation.get("source_instance_id"))
		or not _positive_integer(
			operation.get("expected_source_generation")
		)
	):
		return "monster_transition_operation_context_invalid"
	if kind == TRANSITION_MOVE_REGION:
		if (
			not _stable_id(operation.get("destination_region_id"))
			or operation.get("detection_transition_kind") != null
			or operation.get("full_map_detection_range_hops") != null
			or operation.get("damage_amount") != null
			or operation.get("destroy_reason_id") != null
		):
			return "monster_movement_operation_fields_invalid"
	elif kind == TRANSITION_DETECTION_RANGE:
		var detection_kind := str(
			operation.get("detection_transition_kind", "")
		)
		if (
			operation.get("destination_region_id") != null
			or not DETECTION_TRANSITION_KINDS.has(detection_kind)
			or operation.get("damage_amount") != null
			or operation.get("destroy_reason_id") != null
		):
			return "monster_detection_operation_fields_invalid"
		if detection_kind == DETECTION_PREFERRED_COLOR_HIT:
			if (
				operation.get("full_map_detection_range_hops")
				!= null
			):
				return "monster_detection_restore_range_field_invalid"
		elif not _positive_integer(
			operation.get("full_map_detection_range_hops")
		):
			return "monster_detection_full_map_range_invalid"
	elif kind == TRANSITION_COMBAT_DAMAGE:
		if (
			operation.get("destination_region_id") != null
			or operation.get("detection_transition_kind") != null
			or operation.get("full_map_detection_range_hops") != null
			or not _positive_integer(operation.get("damage_amount"))
			or operation.get("destroy_reason_id") != null
		):
			return "monster_damage_operation_fields_invalid"
	elif kind == TRANSITION_DESTROY_SOURCE:
		if (
			operation.get("destination_region_id") != null
			or operation.get("detection_transition_kind") != null
			or operation.get("full_map_detection_range_hops") != null
			or operation.get("damage_amount") != null
			or not _stable_id(operation.get("destroy_reason_id"))
		):
			return "monster_destroy_operation_fields_invalid"
	return ""


static func _transition_receipt_error(receipt: Dictionary) -> String:
	if (
		not _is_pure_data(receipt)
		or not _exact_fields(
			receipt,
			TRANSITION_RECEIPT_FIELDS
		)
	):
		return "monster_transition_receipt_fields_invalid"
	var unsealed := receipt.duplicate(true)
	var fingerprint := str(unsealed.get("receipt_fingerprint", ""))
	unsealed.erase("receipt_fingerprint")
	if (
		not _fingerprint_valid(fingerprint)
		or fingerprint != _fingerprint(unsealed)
	):
		return "monster_transition_receipt_fingerprint_invalid"
	var kind := str(receipt.get("operation_kind", ""))
	var detection_kind := str(
		receipt.get("detection_transition_kind", "")
	)
	var destroy_reason := str(receipt.get("destroy_reason_id", ""))
	if (
		receipt.get("schema_version") != SCHEMA_VERSION
		or receipt.get("contract_id")
		!= TRANSITION_RECEIPT_CONTRACT_ID
		or receipt.get("ruleset_id") != RULESET_ID
		or not _stable_id(receipt.get("receipt_id"))
		or not _stable_id(receipt.get("operation_id"))
		or not _fingerprint_valid(
			receipt.get("operation_fingerprint")
		)
		or not TRANSITION_KINDS.has(kind)
		or not _stable_id(receipt.get("source_instance_id"))
		or not _positive_integer(receipt.get("source_generation"))
		or receipt.get("committed") != true
		or not _positive_integer(receipt.get("state_revision"))
		or not _stable_id(receipt.get("reason_code"))
		or not _stable_id(receipt.get("previous_region_id"))
		or not _stable_id(receipt.get("current_region_id"))
		or not _nonnegative_integer(
			receipt.get("previous_detection_range_hops")
		)
		or not _nonnegative_integer(
			receipt.get("current_detection_range_hops")
		)
		or (
			not detection_kind.is_empty()
			and not DETECTION_TRANSITION_KINDS.has(detection_kind)
		)
		or not (receipt.get("hungry_after_transition") is bool)
		or (
			not destroy_reason.is_empty()
			and not _stable_id(destroy_reason)
		)
		or not _nonnegative_integer(receipt.get("incoming_damage"))
		or not _nonnegative_integer(receipt.get("armor_before"))
		or not _nonnegative_integer(receipt.get("armor_absorbed"))
		or not _nonnegative_integer(receipt.get("armor_after"))
		or not _nonnegative_integer(receipt.get("hp_before"))
		or not _nonnegative_integer(receipt.get("hp_damage"))
		or not _nonnegative_integer(receipt.get("hp_after"))
		or not _nonnegative_integer(
			receipt.get("damage_revision_before")
		)
		or not _nonnegative_integer(
			receipt.get("damage_revision_after")
		)
		or not SOURCE_STATUSES.has(
			str(receipt.get("status_before", ""))
		)
		or not SOURCE_STATUSES.has(
			str(receipt.get("status_after", ""))
		)
		or int(receipt.get("animation_authority_count", -1)) != 0
		or int(receipt.get("frame_position_mutation_count", -1))
		!= 0
		or receipt.get("exact_once") != true
	):
		return "monster_transition_receipt_context_invalid"
	var incoming := int(receipt.get("incoming_damage", 0))
	var absorbed := int(receipt.get("armor_absorbed", 0))
	var hp_damage := int(receipt.get("hp_damage", 0))
	if kind == TRANSITION_MOVE_REGION:
		if (
			receipt.get("previous_region_id")
			== receipt.get("current_region_id")
			or not detection_kind.is_empty()
			or receipt.get("hungry_after_transition") != false
			or incoming != 0
			or not destroy_reason.is_empty()
			or receipt.get("status_before")
			!= receipt.get("status_after")
		):
			return "monster_movement_receipt_invalid"
	elif kind == TRANSITION_DETECTION_RANGE:
		if (
			receipt.get("previous_region_id")
			!= receipt.get("current_region_id")
			or detection_kind.is_empty()
			or incoming != 0
			or not destroy_reason.is_empty()
			or receipt.get("status_before")
			!= receipt.get("status_after")
			or (
				bool(receipt.get("hungry_after_transition", false))
				!= (
					detection_kind == DETECTION_HUNGRY_PLAN
				)
			)
		):
			return "monster_detection_receipt_invalid"
	elif kind == TRANSITION_COMBAT_DAMAGE:
		if (
			receipt.get("previous_region_id")
			!= receipt.get("current_region_id")
			or not detection_kind.is_empty()
			or incoming <= 0
			or absorbed > incoming
			or hp_damage > incoming - absorbed
			or int(receipt.get("armor_after", -1))
			!= int(receipt.get("armor_before", 0)) - absorbed
			or int(receipt.get("hp_after", -1))
			!= int(receipt.get("hp_before", 0)) - hp_damage
			or int(receipt.get("damage_revision_after", -1))
			!= int(receipt.get("damage_revision_before", 0)) + 1
			or str(receipt.get("status_before", "")) != "active"
			or str(receipt.get("status_after", ""))
			not in ["active", "downed"]
			or not destroy_reason.is_empty()
		):
			return "monster_damage_receipt_invalid"
	elif kind == TRANSITION_DESTROY_SOURCE:
		if (
			receipt.get("previous_region_id")
			!= receipt.get("current_region_id")
			or not detection_kind.is_empty()
			or incoming != 0
			or not _stable_id(destroy_reason)
			or str(receipt.get("status_before", "")) != "downed"
			or str(receipt.get("status_after", "")) != "destroyed"
			or int(receipt.get("damage_revision_after", -1))
			!= int(receipt.get("damage_revision_before", 0)) + 1
		):
			return "monster_destroy_receipt_invalid"
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
	var transition_processed_variant: Variant = state.get(
		"processed_transitions"
	)
	var transition_journal_variant: Variant = state.get(
		"transition_receipt_journal"
	)
	if (
		not (transition_processed_variant is Dictionary)
		or not (transition_journal_variant is Array)
		or (transition_processed_variant as Dictionary).size()
		!= (transition_journal_variant as Array).size()
	):
		return "monster_transition_receipt_journal_invalid"
	for operation_id_variant in (
		transition_processed_variant as Dictionary
	).keys():
		var operation_id := str(operation_id_variant)
		var transition_receipt_variant: Variant = (
			transition_processed_variant as Dictionary
		).get(operation_id)
		if (
			not _stable_id(operation_id)
			or not (transition_receipt_variant is Dictionary)
			or _transition_receipt_error(
				transition_receipt_variant as Dictionary
			) != ""
			or str((transition_receipt_variant as Dictionary).get(
				"operation_id",
				""
			)) != operation_id
		):
			return "monster_processed_transition_invalid"
	for transition_receipt_variant in (
		transition_journal_variant as Array
	):
		if (
			not (transition_receipt_variant is Dictionary)
			or _transition_receipt_error(
				transition_receipt_variant as Dictionary
			) != ""
			or (transition_processed_variant as Dictionary).get(str(
				(transition_receipt_variant as Dictionary).get(
					"operation_id",
					""
				)
			)) != transition_receipt_variant
		):
			return "monster_transition_journal_entry_invalid"
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
