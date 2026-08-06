extends RefCounted
class_name V075MonsterPrivateSkillCore

const SCHEMA_VERSION := 1
const STATE_VERSION := 1
const RULESET_ID := "v0.7.5"
const CONTRACT_ID := "V075MonsterPrivateSkillStateV1"
const EXECUTION_MODE := "private_instant_serial"
const PRIVATE_PROJECTION_ID := "V075MonsterPrivateSkillOwnerProjectionV1"
const PUBLIC_PROJECTION_ID := "V075MonsterSkillPublicProjectionV1"
const SKILL_DEFINITION_ID := "V075MonsterSkillDefinitionV1"
const SOURCE_SNAPSHOT_ID := "V075MonsterSkillSourceSnapshotV1"
const SOURCE_CORE_SNAPSHOT_ID := "v075.monster_source.v1"
const SOURCE_CORE_SCHEMA_VERSION := "1.0.0"
const REQUEST_ID := "V075MonsterPrivateSkillRequestV1"
const ASSET_RESERVATION_REQUEST_ID := "V075MonsterSkillAssetReservationRequestV1"
const ASSET_RESERVATION_RECEIPT_ID := "V075MonsterSkillAssetReservationReceiptV1"
const EXECUTION_INTENT_ID := "V075MonsterPrivateSkillExecutionIntentV1"
const EFFECT_RECEIPT_ID := "V075MonsterPrivateSkillEffectReceiptV1"
const ASSET_SETTLEMENT_INTENT_ID := "V075MonsterSkillAssetSettlementIntentV1"
const MAX_SKILL_USES_PER_SOURCE_PER_BATCH := 1
const MAX_SAFE_INTEGER := 9007199254740991

const COLORS := ["life", "energy", "industry", "technology", "commerce", "shipping"]
const SOURCE_STATUSES := ["active", "downed", "destroyed", "withdrawn"]
const SKILL_STATUSES := [
	"LOCKED_BY_RANK",
	"READY",
	"PENDING_SAFE_BOUNDARY",
	"RESOLVING",
	"COOLDOWN",
	"DISABLED",
	"REVOKED",
]
const SKILL_RESUME_STATUSES := [
	"LOCKED_BY_RANK",
	"READY",
	"COOLDOWN",
	"REVOKED",
]
const SOURCE_CORE_MOVEMENT_PROFILES := [
	"ground_trample",
	"flying_no_trample",
	"teleport_no_trample",
]
const SOURCE_CORE_FACILITY_TYPES := ["factory", "market", "warehouse"]
const SKILL_DEFINITION_FIELDS := [
	"schema_version",
	"contract_id",
	"skill_definition_id",
	"public_effect_id",
	"required_rank",
	"ultimate",
	"asset_cost_by_color",
	"target_contract",
	"range_contract",
	"cooldown_batches",
	"cooldown_on_fizzle",
	"public_presentation_key",
	"definition_fingerprint",
]
const SOURCE_SNAPSHOT_FIELDS := [
	"schema_version",
	"contract_id",
	"source_instance_id",
	"source_generation",
	"owner_player_id",
	"rank",
	"status",
	"skill_definition_ids",
	"unlocked_skill_definition_ids",
	"source_fingerprint",
]
const SOURCE_CORE_FIELDS := [
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
const SOURCE_CORE_SKILL_STATE_FIELDS := [
	"skill_definition_id",
	"status",
	"cooldown_batches_remaining",
	"skill_generation",
	"resume_status",
]
const REQUEST_PHASES := [
	"batch_active",
	"public_resolution_between_receipts",
	"maintenance_before_autonomy",
]
const TERMINAL_PHASES := ["victory_resolved", "final_settlement", "terminal"]
const PUBLIC_SOURCE_FIELDS := [
	"source_instance_id",
	"source_generation",
	"owner_player_id",
	"rank",
	"status",
	"unlocked_skill_count",
	"batch_active_skill_use_count",
]
const PUBLIC_RESULT_FIELDS := [
	"public_result_id",
	"batch_id",
	"source_instance_id",
	"source_generation",
	"outcome",
	"reason_code",
	"public_effect_id",
	"public_presentation_key",
	"public_target",
	"public_result",
]
const FORBIDDEN_PUBLIC_KEYS := [
	"skill_definition_id",
	"skill_definitions",
	"skill_cards",
	"asset_cost_by_color",
	"cooldown_batches",
	"cooldown_remaining_batches",
	"target_request",
	"pending_target_request",
	"request_id",
	"authority_receive_sequence",
	"private_queue",
	"reservation_id",
	"internal_sequence",
	"execution_intent",
]
const PUBLIC_TARGET_ALLOWLIST := [
	"target_kind",
	"target_id",
	"target_region_id",
	"source_generation",
]
const PUBLIC_RESULT_ALLOWLIST := [
	"effect_summary_key",
	"damage_amount",
	"armor_absorbed",
	"status_changes",
	"facility_damage_receipt_ids",
	"combat_receipt_id",
]


static func contract_snapshot() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"ruleset_id": RULESET_ID,
		"contract_id": CONTRACT_ID,
		"execution_mode": EXECUTION_MODE,
		"queue_order": [
			"authority_receive_sequence",
			"owner_player_id",
			"request_id",
		],
		"public_batch_queue_member": false,
		"normal_card_zone_member": false,
		"maximum_uses_per_source_per_batch": 1,
		"immediate_without_atomic_transaction": true,
		"next_safe_boundary_after_receipt": true,
		"atomic_reentry_allowed": false,
		"interactive_counters_enabled": false,
		"asset_port_mode": "typed_reservation_request_receipt",
		"asset_balance_state_owned": false,
		"direct_asset_write_count": 0,
		"reserved_public_asset_debit_count": 0,
		"fizzle_full_reservation_release": true,
		"fizzle_cooldown_start_count": 0,
		"fizzle_batch_use_consumed": true,
		"public_skill_card_disclosure_count": 0,
		"future_skill_target_disclosure_count": 0,
		"rng_draw_count": 0,
	}


static func build_skill_definition(
	skill_definition_id: String,
	public_effect_id: String,
	required_rank: int,
	ultimate: bool,
	asset_cost_by_color: Dictionary,
	target_contract: Dictionary,
	range_contract: Dictionary,
	cooldown_batches: int,
	public_presentation_key: String,
	cooldown_on_fizzle: bool = false
) -> Dictionary:
	var definition := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": SKILL_DEFINITION_ID,
		"skill_definition_id": skill_definition_id,
		"public_effect_id": public_effect_id,
		"required_rank": required_rank,
		"ultimate": ultimate,
		"asset_cost_by_color": asset_cost_by_color.duplicate(true),
		"target_contract": target_contract.duplicate(true),
		"range_contract": range_contract.duplicate(true),
		"cooldown_batches": cooldown_batches,
		"cooldown_on_fizzle": cooldown_on_fizzle,
		"public_presentation_key": public_presentation_key,
	}
	if (
		not _stable_id(skill_definition_id)
		or not _stable_id(public_effect_id)
		or required_rank < 1
		or required_rank > 4
		or ultimate != (required_rank == 4)
		or not _asset_map_valid(asset_cost_by_color)
		or not _target_contract_valid(target_contract)
		or not _is_pure_data(range_contract)
		or cooldown_batches < 0
		or cooldown_on_fizzle
		or not _stable_id(public_presentation_key)
	):
		return {}
	return _seal(definition, "definition_fingerprint")


static func build_source_snapshot(
	source_instance_id: String,
	source_generation: int,
	owner_player_id: String,
	rank: int,
	status: String,
	skill_definition_ids: Array,
	unlocked_skill_definition_ids: Array
) -> Dictionary:
	var all_ids := _id_array(skill_definition_ids, false)
	var unlocked_ids := _id_array(unlocked_skill_definition_ids, true)
	if (
		not _stable_id(source_instance_id)
		or source_generation < 1
		or not _stable_id(owner_player_id)
		or rank < 1
		or rank > 4
		or not SOURCE_STATUSES.has(status)
		or all_ids.size() != skill_definition_ids.size()
		or unlocked_ids.size() != unlocked_skill_definition_ids.size()
	):
		return {}
	for skill_id in unlocked_ids:
		if not all_ids.has(skill_id):
			return {}
	return _seal({
		"schema_version": SCHEMA_VERSION,
		"contract_id": SOURCE_SNAPSHOT_ID,
		"source_instance_id": source_instance_id,
		"source_generation": source_generation,
		"owner_player_id": owner_player_id,
		"rank": rank,
		"status": status,
		"skill_definition_ids": all_ids,
		"unlocked_skill_definition_ids": unlocked_ids,
	}, "source_fingerprint")


static func build_request(
	request_id: String,
	batch_id: String,
	owner_player_id: String,
	source_instance_id: String,
	source_generation: int,
	skill_definition_id: String,
	target_request: Dictionary
) -> Dictionary:
	if (
		not _stable_id(request_id)
		or not _stable_id(batch_id)
		or not _stable_id(owner_player_id)
		or not _stable_id(source_instance_id)
		or source_generation < 1
		or not _stable_id(skill_definition_id)
		or not _target_contract_valid(target_request)
	):
		return {}
	return _seal({
		"schema_version": SCHEMA_VERSION,
		"contract_id": REQUEST_ID,
		"request_id": request_id,
		"batch_id": batch_id,
		"owner_player_id": owner_player_id,
		"source_instance_id": source_instance_id,
		"source_generation": source_generation,
		"skill_definition_id": skill_definition_id,
		"target_request": target_request.duplicate(true),
	}, "request_fingerprint")


static func create_state(
	batch_id: String,
	source_snapshots: Array,
	skill_definitions: Array,
	batch_index: int = 0
) -> Dictionary:
	if not _stable_id(batch_id) or batch_index < 0:
		return {}
	var definitions := _normalize_skill_definitions(skill_definitions)
	if definitions.is_empty():
		return {}

	var sources := {}
	for snapshot_variant in source_snapshots:
		var snapshot := _normalize_source_snapshot(
			snapshot_variant,
			definitions
		)
		if snapshot.is_empty():
			return {}
		var source_id := str(snapshot.get("source_instance_id", ""))
		if sources.has(source_id):
			return {}
		sources[source_id] = _private_source_from_snapshot(snapshot)

	var lineage_id := "combat.private.skill.%s" % _fingerprint({
		"batch_id": batch_id,
		"definition_ids": _sorted_keys(definitions),
		"source_ids": _sorted_keys(sources),
	}).substr(0, 24)
	return _reseal_state({
		"schema_version": SCHEMA_VERSION,
		"state_version": STATE_VERSION,
		"ruleset_id": RULESET_ID,
		"contract_id": CONTRACT_ID,
		"execution_mode": EXECUTION_MODE,
		"lineage_id": lineage_id,
		"revision": 0,
		"batch_id": batch_id,
		"batch_index": batch_index,
		"phase": "batch_active",
		"safe_boundary_sequence": 0,
		"next_authority_receive_sequence": 0,
		"atomic_transaction": {"inflight": false, "receipt_id": ""},
		"atomic_receipt_ledger": {},
		"resolving_request_id": "",
		"skill_definitions": definitions,
		"sources": sources,
		"private_queue": [],
		"request_ledger": {},
		"reservation_receipt_ledger": {},
		"resolution_receipt_ledger": {},
		"receipt_journal": [],
		"public_results": [],
	})


static func register_source_snapshot(
	state: Dictionary,
	snapshot_variant: Variant
) -> Dictionary:
	if _state_error(state) != "":
		return _failure(state, "state_invalid")
	var snapshot := _normalize_source_snapshot(
		snapshot_variant,
		state.get("skill_definitions") as Dictionary
	)
	if snapshot.is_empty():
		return _failure(state, "source_snapshot_invalid")
	var source_id := str(snapshot.get("source_instance_id", ""))
	var sources := state.get("sources") as Dictionary
	if sources.has(source_id):
		var existing := sources.get(source_id) as Dictionary
		if str(existing.get(
			"registration_source_fingerprint",
			""
		)) == str(snapshot.get("source_fingerprint", "")):
			return {
				"accepted": true,
				"replayed": true,
				"reason_code": "source_snapshot_already_registered",
				"state": state.duplicate(true),
				"receipt": {},
			}
		return _failure(state, "source_registration_collision")

	var next := state.duplicate(true)
	(next.get("sources") as Dictionary)[source_id] = (
		_private_source_from_snapshot(snapshot)
	)
	_increment_revision(next)
	var receipt := _operation_receipt(
		next,
		"register_source_snapshot",
		source_id,
		true,
		"source_snapshot_registered",
		{
			"source_instance_id": source_id,
			"source_generation": snapshot.get("source_generation"),
			"source_contract_id": snapshot.get("source_contract_id"),
			"source_fingerprint": snapshot.get("source_fingerprint"),
		}
	)
	_append_receipt(next, receipt)
	return {
		"accepted": true,
		"replayed": false,
		"reason_code": "source_snapshot_registered",
		"state": _reseal_state(next),
		"receipt": receipt,
	}


static func sync_source_snapshot(
	state: Dictionary,
	snapshot_variant: Variant
) -> Dictionary:
	if _state_error(state) != "":
		return _failure(state, "state_invalid")
	var snapshot := _normalize_source_snapshot(
		snapshot_variant,
		state.get("skill_definitions") as Dictionary
	)
	if snapshot.is_empty():
		return _failure(state, "source_snapshot_invalid")
	var source_id := str(snapshot.get("source_instance_id", ""))
	var sources := state.get("sources") as Dictionary
	if not sources.has(source_id):
		return _failure(state, "source_not_registered")
	var current := sources.get(source_id) as Dictionary
	var incoming_fingerprint := str(snapshot.get("source_fingerprint", ""))
	if (
		str(current.get("last_source_snapshot_fingerprint", ""))
		== incoming_fingerprint
		and str(current.get("last_source_snapshot_contract_id", ""))
		== str(snapshot.get("source_contract_id", ""))
		and _private_source_matches_snapshot(current, snapshot)
	):
		return {
			"accepted": true,
			"replayed": true,
			"reason_code": "source_snapshot_already_synchronized",
			"state": state.duplicate(true),
			"receipt": {},
			"newly_ready_skill_definition_ids": [],
			"existing_cooldown_reset_count": 0,
		}

	var current_generation := int(current.get("source_generation", 0))
	var incoming_generation := int(snapshot.get("source_generation", 0))
	if incoming_generation < current_generation:
		return _failure(state, "source_snapshot_generation_stale")
	if str(current.get("owner_player_id", "")) != str(
		snapshot.get("owner_player_id", "")
	):
		return _failure(state, "source_snapshot_owner_changed")

	var transition := {}
	if incoming_generation > current_generation:
		var replacement := _private_source_from_snapshot(snapshot)
		replacement["registration_source_fingerprint"] = current.get(
			"registration_source_fingerprint",
			""
		)
		transition = {
			"accepted": true,
			"reason_code": "source_generation_synchronized",
			"source": replacement,
			"newly_ready_skill_definition_ids": (
				replacement.get("unlocked_skill_definition_ids") as Array
			).duplicate(),
			"existing_cooldown_reset_count": 0,
			"generation_replaced": true,
		}
	else:
		transition = _same_generation_source_transition(current, snapshot)
		if not bool(transition.get("accepted", false)):
			return _failure(
				state,
				str(transition.get(
					"reason_code",
					"source_snapshot_transition_invalid"
				))
			)

	var next := state.duplicate(true)
	(next.get("sources") as Dictionary)[source_id] = (
		transition.get("source") as Dictionary
	).duplicate(true)
	_increment_revision(next)
	var reason_code := str(transition.get(
		"reason_code",
		"source_snapshot_synchronized"
	))
	var receipt := _operation_receipt(
		next,
		"sync_source_snapshot",
		source_id,
		true,
		reason_code,
		{
			"source_instance_id": source_id,
			"previous_source_generation": current_generation,
			"source_generation": incoming_generation,
			"source_contract_id": snapshot.get("source_contract_id"),
			"source_fingerprint": incoming_fingerprint,
			"generation_replaced": transition.get(
				"generation_replaced",
				false
			),
			"newly_ready_skill_definition_ids": transition.get(
				"newly_ready_skill_definition_ids",
				[]
			),
			"existing_cooldown_reset_count": transition.get(
				"existing_cooldown_reset_count",
				0
			),
		}
	)
	_append_receipt(next, receipt)
	return {
		"accepted": true,
		"replayed": false,
		"reason_code": reason_code,
		"state": _reseal_state(next),
		"receipt": receipt,
		"generation_replaced": transition.get(
			"generation_replaced",
			false
		),
		"newly_ready_skill_definition_ids": transition.get(
			"newly_ready_skill_definition_ids",
			[]
		),
		"existing_cooldown_reset_count": transition.get(
			"existing_cooldown_reset_count",
			0
		),
	}


static func set_phase(state: Dictionary, phase: String) -> Dictionary:
	if _state_error(state) != "":
		return _failure(state, "state_invalid")
	if not REQUEST_PHASES.has(phase) and not TERMINAL_PHASES.has(phase):
		return _failure(state, "phase_invalid")
	var next := state.duplicate(true)
	next["phase"] = phase
	_increment_revision(next)
	return _success(next, "phase_updated")


static func submit_request(
	state: Dictionary,
	request: Dictionary,
	owner_asset_view: Dictionary
) -> Dictionary:
	if _state_error(state) != "":
		return _failure(state, "state_invalid")
	if not _sealed_contract_valid(
		request,
		REQUEST_ID,
		"request_fingerprint"
	):
		return _failure(state, "request_invalid")
	var request_id := str(request.get("request_id", ""))
	var request_fingerprint := str(request.get("request_fingerprint", ""))
	var request_ledger := state.get("request_ledger") as Dictionary
	if request_ledger.has(request_id):
		var existing := request_ledger.get(request_id) as Dictionary
		if str(existing.get("request_fingerprint", "")) != request_fingerprint:
			return _failure(state, "request_id_collision")
		return {
			"accepted": bool(existing.get("accepted", false)),
			"replayed": true,
			"reason_code": str(existing.get("reason_code", "")),
			"state": state.duplicate(true),
			"receipt": _copy(existing.get("receipt", {})),
			"asset_reservation_request": {},
		}

	var next := state.duplicate(true)
	var receive_sequence := int(
		next.get("next_authority_receive_sequence", 0)
	)
	next["next_authority_receive_sequence"] = receive_sequence + 1
	var reason_code := _preaccept_reason(next, request, owner_asset_view)
	if reason_code != "":
		_increment_revision(next)
		var rejected_receipt := _operation_receipt(
			next,
			"request",
			request_id,
			false,
			reason_code,
			{
				"request_id": request_id,
				"owner_player_id": request.get("owner_player_id"),
				"source_instance_id": request.get("source_instance_id"),
				"skill_definition_id": request.get("skill_definition_id"),
				"authority_receive_sequence": receive_sequence,
				"asset_reservation_created": false,
				"batch_use_consumed": false,
			}
		)
		(next.get("request_ledger") as Dictionary)[request_id] = {
			"request_fingerprint": request_fingerprint,
			"accepted": false,
			"reason_code": reason_code,
			"stage": "REJECTED_PREACCEPT",
			"receipt": rejected_receipt.duplicate(true),
			"asset_reservation_request": {},
		}
		_append_receipt(next, rejected_receipt)
		return {
			"accepted": false,
			"replayed": false,
			"reason_code": reason_code,
			"state": _reseal_state(next),
			"receipt": rejected_receipt,
			"asset_reservation_request": {},
		}

	var source_id := str(request.get("source_instance_id", ""))
	var skill_id := str(request.get("skill_definition_id", ""))
	var source := (next.get("sources") as Dictionary).get(source_id) as Dictionary
	var skill_state := (source.get("skill_states") as Dictionary).get(
		skill_id
	) as Dictionary
	var definition := (next.get("skill_definitions") as Dictionary).get(
		skill_id
	) as Dictionary
	var reservation_id := "reservation.monster.skill.%s" % (
		"%s|%s|%s" % [
			next.get("lineage_id"),
			request_id,
			request_fingerprint,
		]
	).sha256_text().substr(0, 24)
	var atomic := next.get("atomic_transaction") as Dictionary
	var required_boundary := int(next.get("safe_boundary_sequence", 0))
	var blocked_by_receipt_id := ""
	if bool(atomic.get("inflight", false)):
		required_boundary += 1
		blocked_by_receipt_id = str(atomic.get("receipt_id", ""))
	var asset_request := _seal({
		"schema_version": SCHEMA_VERSION,
		"contract_id": ASSET_RESERVATION_REQUEST_ID,
		"reservation_id": reservation_id,
		"request_id": request_id,
		"owner_player_id": request.get("owner_player_id"),
		"source_instance_id": source_id,
		"source_generation": request.get("source_generation"),
		"asset_snapshot_revision": owner_asset_view.get("state_revision"),
		"asset_cost_by_color": _copy(
			definition.get("asset_cost_by_color")
		),
		"purpose": "monster_private_instant_skill",
		"request_fingerprint": request_fingerprint,
	}, "reservation_request_fingerprint")
	var queue_entry := {
		"request_id": request_id,
		"request_fingerprint": request_fingerprint,
		"owner_player_id": request.get("owner_player_id"),
		"source_instance_id": source_id,
		"source_generation": request.get("source_generation"),
		"source_action_generation": source.get("action_generation"),
		"skill_definition_id": skill_id,
		"target_request": _copy(request.get("target_request")),
		"authority_receive_sequence": receive_sequence,
		"stage": "AWAITING_ASSET_RESERVATION",
		"reservation_id": reservation_id,
		"asset_reservation_accepted": false,
		"required_safe_boundary_sequence": required_boundary,
		"blocked_by_receipt_id": blocked_by_receipt_id,
		"execution_intent": {},
	}
	(next.get("private_queue") as Array).append(queue_entry)
	next["private_queue"] = stable_queue_order(
		next.get("private_queue") as Array
	)
	source["pending_batch_use_request_id"] = request_id
	skill_state["last_request_id"] = request_id
	_increment_revision(next)
	var accepted_receipt := _operation_receipt(
		next,
		"request",
		request_id,
		true,
		"asset_reservation_requested",
		{
			"request_id": request_id,
			"owner_player_id": request.get("owner_player_id"),
			"source_instance_id": source_id,
			"skill_definition_id": skill_id,
			"authority_receive_sequence": receive_sequence,
			"asset_reservation_created": true,
			"batch_use_consumed": false,
		}
	)
	(next.get("request_ledger") as Dictionary)[request_id] = {
		"request_fingerprint": request_fingerprint,
		"accepted": true,
		"reason_code": "asset_reservation_requested",
		"stage": "AWAITING_ASSET_RESERVATION",
		"receipt": accepted_receipt.duplicate(true),
		"asset_reservation_request": asset_request.duplicate(true),
	}
	_append_receipt(next, accepted_receipt)
	return {
		"accepted": true,
		"replayed": false,
		"reason_code": "asset_reservation_requested",
		"state": _reseal_state(next),
		"receipt": accepted_receipt,
		"asset_reservation_request": asset_request,
		"execution_timing": (
			"first_safe_boundary_after_receipt"
			if blocked_by_receipt_id != ""
			else "immediate_after_asset_reservation"
		),
	}


static func build_asset_reservation_receipt(
	reservation_request: Dictionary,
	accepted: bool,
	reason_code: String,
	committed_asset_revision: int
) -> Dictionary:
	if (
		not _sealed_contract_valid(
			reservation_request,
			ASSET_RESERVATION_REQUEST_ID,
			"reservation_request_fingerprint"
		)
		or not _stable_id(reason_code)
		or committed_asset_revision < 0
	):
		return {}
	var receipt_id := "receipt.asset.monster.skill.%s" % (
		"%s|%s|%s|%d" % [
			reservation_request.get("reservation_id"),
			"accepted" if accepted else "rejected",
			reason_code,
			committed_asset_revision,
		]
	).sha256_text().substr(0, 24)
	return _seal({
		"schema_version": SCHEMA_VERSION,
		"contract_id": ASSET_RESERVATION_RECEIPT_ID,
		"receipt_id": receipt_id,
		"reservation_id": reservation_request.get("reservation_id"),
		"request_id": reservation_request.get("request_id"),
		"owner_player_id": reservation_request.get("owner_player_id"),
		"accepted": accepted,
		"reason_code": reason_code,
		"committed_asset_revision": committed_asset_revision,
		"reserved_asset_cost_by_color": _copy(
			reservation_request.get("asset_cost_by_color")
		),
		"reservation_request_fingerprint": reservation_request.get(
			"reservation_request_fingerprint"
		),
	}, "receipt_fingerprint")


static func apply_asset_reservation_receipt(
	state: Dictionary,
	asset_receipt: Dictionary
) -> Dictionary:
	if _state_error(state) != "":
		return _failure(state, "state_invalid")
	if not _sealed_contract_valid(
		asset_receipt,
		ASSET_RESERVATION_RECEIPT_ID,
		"receipt_fingerprint"
	):
		return _failure(state, "asset_reservation_receipt_invalid")
	var reservation_id := str(asset_receipt.get("reservation_id", ""))
	var input_fingerprint := str(asset_receipt.get("receipt_fingerprint", ""))
	var reservation_ledger := state.get(
		"reservation_receipt_ledger"
	) as Dictionary
	if reservation_ledger.has(reservation_id):
		var existing := reservation_ledger.get(reservation_id) as Dictionary
		if str(existing.get("input_fingerprint", "")) != input_fingerprint:
			return _failure(state, "reservation_receipt_collision")
		return {
			"accepted": bool(existing.get("accepted", false)),
			"replayed": true,
			"reason_code": str(existing.get("reason_code", "")),
			"state": state.duplicate(true),
			"receipt": _copy(existing.get("receipt", {})),
			"execution_due": false,
		}

	var queue_index := _queue_index_by(
		state.get("private_queue") as Array,
		"reservation_id",
		reservation_id
	)
	if queue_index < 0:
		return _failure(state, "reservation_request_not_found")
	var entry := (
		(state.get("private_queue") as Array)[queue_index] as Dictionary
	)
	var request_record := (state.get("request_ledger") as Dictionary).get(
		entry.get("request_id"),
		{}
	) as Dictionary
	var expected_request := request_record.get(
		"asset_reservation_request",
		{}
	) as Dictionary
	if (
		str(entry.get("stage", "")) != "AWAITING_ASSET_RESERVATION"
		or str(entry.get("request_id", ""))
		!= str(asset_receipt.get("request_id", ""))
		or str(entry.get("owner_player_id", ""))
		!= str(asset_receipt.get("owner_player_id", ""))
		or str(expected_request.get(
			"reservation_request_fingerprint",
			""
		)) != str(asset_receipt.get(
			"reservation_request_fingerprint",
			""
		))
		or expected_request.get("asset_cost_by_color")
		!= asset_receipt.get("reserved_asset_cost_by_color")
	):
		return _failure(state, "reservation_receipt_binding_invalid")

	var next := state.duplicate(true)
	var next_queue := next.get("private_queue") as Array
	var next_entry := next_queue[queue_index] as Dictionary
	var source := (next.get("sources") as Dictionary).get(
		next_entry.get("source_instance_id"),
		{}
	) as Dictionary
	var generation_matches := (
		int(source.get("source_generation", -1))
		== int(next_entry.get("source_generation", -2))
		and int(source.get("action_generation", -1))
		== int(next_entry.get("source_action_generation", -2))
	)
	var skill_state := {}
	if generation_matches:
		skill_state = (source.get("skill_states") as Dictionary).get(
			next_entry.get("skill_definition_id"),
			{}
		) as Dictionary
	var request_id := str(next_entry.get("request_id", ""))
	var accepted := bool(asset_receipt.get("accepted", false))
	var reason_code := str(asset_receipt.get("reason_code", ""))
	if accepted:
		next_entry["stage"] = "PENDING_SAFE_BOUNDARY"
		next_entry["asset_reservation_accepted"] = true
		if generation_matches:
			source["pending_batch_use_request_id"] = ""
			source["batch_active_skill_use_count"] = 1
			source["last_batch_use_id"] = str(next.get("batch_id", ""))
			if (
				str(source.get("status", "")) == "active"
				and not skill_state.is_empty()
			):
				skill_state["status"] = "PENDING_SAFE_BOUNDARY"
				skill_state["resume_status"] = "READY"
		(next.get("request_ledger") as Dictionary)[request_id]["stage"] = (
			"PENDING_SAFE_BOUNDARY"
		)
		(next.get("request_ledger") as Dictionary)[request_id]["reason_code"] = (
			"asset_reservation_accepted"
		)
	else:
		next_queue.remove_at(queue_index)
		if (
			generation_matches
			and str(source.get("pending_batch_use_request_id", ""))
			== request_id
		):
			source["pending_batch_use_request_id"] = ""
		(next.get("request_ledger") as Dictionary)[request_id]["stage"] = (
			"REJECTED_ASSET_RESERVATION"
		)
		(next.get("request_ledger") as Dictionary)[request_id]["reason_code"] = (
			reason_code
		)
	_increment_revision(next)
	var operation_receipt := _operation_receipt(
		next,
		"asset_reservation",
		reservation_id,
		accepted,
		"asset_reservation_accepted" if accepted else reason_code,
		{
			"request_id": request_id,
			"owner_player_id": next_entry.get("owner_player_id"),
			"source_instance_id": next_entry.get("source_instance_id"),
			"skill_definition_id": next_entry.get("skill_definition_id"),
			"reservation_id": reservation_id,
			"asset_mutation_count": 0,
			"batch_use_consumed": accepted,
		}
	)
	(next.get("reservation_receipt_ledger") as Dictionary)[reservation_id] = {
		"input_fingerprint": input_fingerprint,
		"accepted": accepted,
		"reason_code": (
			"asset_reservation_accepted" if accepted else reason_code
		),
		"receipt": operation_receipt.duplicate(true),
	}
	_append_receipt(next, operation_receipt)
	var execution_due := accepted and _has_due_request(next)
	return {
		"accepted": accepted,
		"replayed": false,
		"reason_code": (
			"asset_reservation_accepted" if accepted else reason_code
		),
		"state": _reseal_state(next),
		"receipt": operation_receipt,
		"execution_due": execution_due,
		"execution_timing": (
			"immediate"
			if execution_due
			else "first_safe_boundary_after_receipt"
			if accepted
			else "none"
		),
	}


static func begin_atomic_receipt(
	state: Dictionary,
	receipt_id: String
) -> Dictionary:
	if _state_error(state) != "":
		return _failure(state, "state_invalid")
	if not _stable_id(receipt_id):
		return _failure(state, "atomic_receipt_id_invalid")
	if str(state.get("resolving_request_id", "")) != "":
		return _failure(state, "private_skill_resolution_inflight")
	var atomic := state.get("atomic_transaction") as Dictionary
	if bool(atomic.get("inflight", false)):
		if str(atomic.get("receipt_id", "")) == receipt_id:
			return {
				"accepted": true,
				"replayed": true,
				"reason_code": "atomic_receipt_already_inflight",
				"state": state.duplicate(true),
			}
		return _failure(state, "atomic_transaction_reentry_forbidden")
	if _has_due_request(state):
		return _failure(state, "private_safe_boundary_required")
	if (state.get("atomic_receipt_ledger") as Dictionary).has(receipt_id):
		return _failure(state, "atomic_receipt_already_completed")
	var next := state.duplicate(true)
	next["atomic_transaction"] = {
		"inflight": true,
		"receipt_id": receipt_id,
	}
	(next.get("atomic_receipt_ledger") as Dictionary)[receipt_id] = "inflight"
	_increment_revision(next)
	return _success(next, "atomic_receipt_started")


static func complete_atomic_receipt(
	state: Dictionary,
	receipt_id: String
) -> Dictionary:
	if _state_error(state) != "":
		return _failure(state, "state_invalid")
	if not _stable_id(receipt_id):
		return _failure(state, "atomic_receipt_id_invalid")
	var ledger := state.get("atomic_receipt_ledger") as Dictionary
	if str(ledger.get(receipt_id, "")) == "completed":
		return {
			"accepted": true,
			"replayed": true,
			"reason_code": "atomic_receipt_already_completed",
			"state": state.duplicate(true),
			"execution_due": _has_due_request(state),
		}
	var atomic := state.get("atomic_transaction") as Dictionary
	if (
		not bool(atomic.get("inflight", false))
		or str(atomic.get("receipt_id", "")) != receipt_id
	):
		return _failure(state, "atomic_receipt_binding_invalid")
	var next := state.duplicate(true)
	next["atomic_transaction"] = {"inflight": false, "receipt_id": ""}
	(next.get("atomic_receipt_ledger") as Dictionary)[receipt_id] = "completed"
	next["safe_boundary_sequence"] = int(
		next.get("safe_boundary_sequence", 0)
	) + 1
	_increment_revision(next)
	var execution_due := _has_due_request(next)
	return {
		"accepted": true,
		"replayed": false,
		"reason_code": "atomic_receipt_completed",
		"state": _reseal_state(next),
		"execution_due": execution_due,
		"safe_boundary_sequence": next.get("safe_boundary_sequence"),
	}


static func take_next_ready_request(state: Dictionary) -> Dictionary:
	if _state_error(state) != "":
		return _failure(state, "state_invalid")
	if bool((state.get("atomic_transaction") as Dictionary).get(
		"inflight",
		false
	)):
		return _failure(state, "atomic_transaction_inflight")
	if str(state.get("resolving_request_id", "")) != "":
		return _failure(state, "private_skill_resolution_inflight")
	var ready_entry: Dictionary = {}
	for entry_variant in stable_queue_order(
		state.get("private_queue") as Array
	):
		var entry := entry_variant as Dictionary
		if (
			str(entry.get("stage", "")) == "PENDING_SAFE_BOUNDARY"
			and int(entry.get("required_safe_boundary_sequence", -1))
			<= int(state.get("safe_boundary_sequence", 0))
		):
			ready_entry = entry
			break
	if ready_entry.is_empty():
		return _failure(state, "no_private_skill_ready_at_boundary")

	var next := state.duplicate(true)
	var queue_index := _queue_index_by(
		next.get("private_queue") as Array,
		"request_id",
		str(ready_entry.get("request_id", ""))
	)
	if queue_index < 0:
		return _failure(state, "private_queue_binding_invalid")
	var next_entry := (
		(next.get("private_queue") as Array)[queue_index] as Dictionary
	)
	var source := (next.get("sources") as Dictionary).get(
		next_entry.get("source_instance_id"),
		{}
	) as Dictionary
	var generation_matches := (
		int(source.get("source_generation", -1))
		== int(next_entry.get("source_generation", -2))
		and int(source.get("action_generation", -1))
		== int(next_entry.get("source_action_generation", -2))
	)
	var skill_state := {}
	if generation_matches:
		skill_state = (source.get("skill_states") as Dictionary).get(
			next_entry.get("skill_definition_id"),
			{}
		) as Dictionary
	var definition := (next.get("skill_definitions") as Dictionary).get(
		next_entry.get("skill_definition_id")
	) as Dictionary
	var execution_id := "execution.monster.skill.%s" % (
		"%s|%s|%d" % [
			next.get("lineage_id"),
			next_entry.get("request_id"),
			next_entry.get("authority_receive_sequence"),
		]
	).sha256_text().substr(0, 24)
	var must_fizzle_reason := _source_execution_reason(source, next_entry)
	var execution_intent := _seal({
		"schema_version": SCHEMA_VERSION,
		"contract_id": EXECUTION_INTENT_ID,
		"execution_id": execution_id,
		"request_id": next_entry.get("request_id"),
		"batch_id": next.get("batch_id"),
		"owner_player_id": next_entry.get("owner_player_id"),
		"source_instance_id": next_entry.get("source_instance_id"),
		"source_generation": next_entry.get("source_generation"),
		"source_action_generation": next_entry.get(
			"source_action_generation"
		),
		"skill_definition_id": next_entry.get("skill_definition_id"),
		"public_effect_id": definition.get("public_effect_id"),
		"public_presentation_key": definition.get(
			"public_presentation_key"
		),
		"target_request": _copy(next_entry.get("target_request")),
		"target_contract": _copy(definition.get("target_contract")),
		"range_contract": _copy(definition.get("range_contract")),
		"reservation_id": next_entry.get("reservation_id"),
		"asset_cost_by_color": _copy(
			definition.get("asset_cost_by_color")
		),
		"must_fizzle_reason": must_fizzle_reason,
	}, "execution_fingerprint")
	next_entry["stage"] = "RESOLVING"
	next_entry["execution_intent"] = execution_intent.duplicate(true)
	next["resolving_request_id"] = next_entry.get("request_id")
	if (
		generation_matches
		and str(source.get("status", "")) == "active"
		and not skill_state.is_empty()
	):
		skill_state["status"] = "RESOLVING"
	_increment_revision(next)
	return {
		"accepted": true,
		"replayed": false,
		"reason_code": (
			"private_skill_execution_ready"
			if must_fizzle_reason == ""
			else must_fizzle_reason
		),
		"state": _reseal_state(next),
		"execution_intent": execution_intent,
	}


static func build_effect_receipt(
	execution_intent: Dictionary,
	committed: bool,
	reason_code: String,
	public_target: Dictionary,
	public_result: Dictionary
) -> Dictionary:
	if (
		not _sealed_contract_valid(
			execution_intent,
			EXECUTION_INTENT_ID,
			"execution_fingerprint"
		)
		or not _stable_id(reason_code)
		or not _is_pure_data(public_target)
		or not _is_pure_data(public_result)
	):
		return {}
	var target := _allowlisted(public_target, PUBLIC_TARGET_ALLOWLIST)
	var result := _allowlisted(public_result, PUBLIC_RESULT_ALLOWLIST)
	return _seal({
		"schema_version": SCHEMA_VERSION,
		"contract_id": EFFECT_RECEIPT_ID,
		"effect_receipt_id": "receipt.effect.monster.skill.%s" % (
			"%s|%s|%s|%s" % [
				execution_intent.get("execution_id"),
				"committed" if committed else "fizzled",
				reason_code,
				_fingerprint([target, result]),
			]
		).sha256_text().substr(0, 24),
		"execution_id": execution_intent.get("execution_id"),
		"execution_fingerprint": execution_intent.get(
			"execution_fingerprint"
		),
		"request_id": execution_intent.get("request_id"),
		"source_instance_id": execution_intent.get("source_instance_id"),
		"source_generation": execution_intent.get("source_generation"),
		"committed": committed,
		"reason_code": reason_code,
		"public_target": target,
		"public_result": result,
	}, "receipt_fingerprint")


static func resolve_current(
	state: Dictionary,
	effect_receipt: Dictionary
) -> Dictionary:
	if _state_error(state) != "":
		return _failure(state, "state_invalid")
	if not _sealed_contract_valid(
		effect_receipt,
		EFFECT_RECEIPT_ID,
		"receipt_fingerprint"
	):
		return _failure(state, "effect_receipt_invalid")
	var effect_receipt_id := str(
		effect_receipt.get("effect_receipt_id", "")
	)
	var input_fingerprint := str(effect_receipt.get("receipt_fingerprint", ""))
	var resolution_ledger := state.get(
		"resolution_receipt_ledger"
	) as Dictionary
	if resolution_ledger.has(effect_receipt_id):
		var existing := resolution_ledger.get(effect_receipt_id) as Dictionary
		if str(existing.get("input_fingerprint", "")) != input_fingerprint:
			return _failure(state, "effect_receipt_id_collision")
		return {
			"accepted": true,
			"replayed": true,
			"reason_code": str(existing.get("reason_code", "")),
			"state": state.duplicate(true),
			"receipt": _copy(existing.get("receipt", {})),
			"asset_settlement_intent": {},
			"public_result": {},
		}
	var request_id := str(effect_receipt.get("request_id", ""))
	if str(state.get("resolving_request_id", "")) != request_id:
		return _failure(state, "resolving_request_binding_invalid")
	var queue_index := _queue_index_by(
		state.get("private_queue") as Array,
		"request_id",
		request_id
	)
	if queue_index < 0:
		return _failure(state, "resolving_request_not_found")
	var entry := (
		(state.get("private_queue") as Array)[queue_index] as Dictionary
	)
	var execution_intent := entry.get("execution_intent") as Dictionary
	if (
		str(entry.get("stage", "")) != "RESOLVING"
		or str(execution_intent.get("execution_id", ""))
		!= str(effect_receipt.get("execution_id", ""))
		or str(execution_intent.get("execution_fingerprint", ""))
		!= str(effect_receipt.get("execution_fingerprint", ""))
	):
		return _failure(state, "effect_receipt_execution_binding_invalid")

	var next := state.duplicate(true)
	var next_queue := next.get("private_queue") as Array
	var next_entry := next_queue[queue_index] as Dictionary
	var source := (next.get("sources") as Dictionary).get(
		next_entry.get("source_instance_id"),
		{}
	) as Dictionary
	var skill_id := str(next_entry.get("skill_definition_id", ""))
	var generation_matches := (
		int(source.get("source_generation", -1))
		== int(next_entry.get("source_generation", -2))
		and int(source.get("action_generation", -1))
		== int(next_entry.get("source_action_generation", -2))
	)
	var skill_state := {}
	if generation_matches:
		skill_state = (source.get("skill_states") as Dictionary).get(
			skill_id,
			{}
		) as Dictionary
	var definition := (next.get("skill_definitions") as Dictionary).get(
		skill_id
	) as Dictionary
	var source_reason := _source_execution_reason(source, next_entry)
	var committed := bool(effect_receipt.get("committed", false))
	var reason_code := str(effect_receipt.get("reason_code", ""))
	if source_reason != "":
		committed = false
		reason_code = source_reason
	if generation_matches and str(skill_state.get(
		"status",
		""
	)) != "RESOLVING":
		committed = false
		if reason_code == "resolved":
			reason_code = "skill_state_invalid_at_boundary"

	var settlement_action := "release"
	if committed and generation_matches:
		settlement_action = "commit"
		var cooldown := int(definition.get("cooldown_batches", 0))
		skill_state["cooldown_remaining_batches"] = cooldown
		skill_state["status"] = "COOLDOWN" if cooldown > 0 else "READY"
		skill_state["resume_status"] = skill_state.get("status")
	elif generation_matches:
		skill_state["cooldown_remaining_batches"] = 0
		match str(source.get("status", "")):
			"active":
				skill_state["status"] = "READY"
				skill_state["resume_status"] = "READY"
			"downed":
				skill_state["status"] = "DISABLED"
				skill_state["resume_status"] = "READY"
			_:
				skill_state["status"] = "REVOKED"
				skill_state["resume_status"] = "REVOKED"

	var public_result_id := "public.monster.skill.%s" % (
		effect_receipt_id.sha256_text().substr(0, 24)
	)
	var public_result := {
		"public_result_id": public_result_id,
		"batch_id": next.get("batch_id"),
		"source_instance_id": next_entry.get("source_instance_id"),
		"source_generation": next_entry.get("source_generation"),
		"outcome": "resolved" if committed else "fizzled",
		"reason_code": (
			reason_code if committed else "private_skill_fizzled"
		),
		"public_effect_id": (
			definition.get("public_effect_id") if committed else ""
		),
		"public_presentation_key": (
			definition.get("public_presentation_key")
			if committed
			else "monster.skill.fizzled"
		),
		"public_target": _allowlisted(
			effect_receipt.get("public_target") as Dictionary,
			PUBLIC_TARGET_ALLOWLIST
		),
		"public_result": _allowlisted(
			effect_receipt.get("public_result") as Dictionary,
			PUBLIC_RESULT_ALLOWLIST
		),
	}
	var asset_settlement_intent := _seal({
		"schema_version": SCHEMA_VERSION,
		"contract_id": ASSET_SETTLEMENT_INTENT_ID,
		"settlement_intent_id": "asset.settlement.%s" % (
			effect_receipt_id.sha256_text().substr(0, 24)
		),
		"reservation_id": next_entry.get("reservation_id"),
		"request_id": request_id,
		"owner_player_id": next_entry.get("owner_player_id"),
		"source_instance_id": next_entry.get("source_instance_id"),
		"action": settlement_action,
		"asset_cost_by_color": _copy(
			definition.get("asset_cost_by_color")
		),
		"full_reservation_release": not committed,
		"effect_receipt_id": effect_receipt_id,
	}, "settlement_fingerprint")
	next_queue.remove_at(queue_index)
	next["resolving_request_id"] = ""
	(next.get("public_results") as Array).append(public_result)
	(next.get("request_ledger") as Dictionary)[request_id]["stage"] = (
		"RESOLVED" if committed else "FIZZLED"
	)
	(next.get("request_ledger") as Dictionary)[request_id]["reason_code"] = (
		reason_code
	)
	_increment_revision(next)
	var operation_receipt := _operation_receipt(
		next,
		"resolve",
		effect_receipt_id,
		true,
		reason_code,
		{
			"request_id": request_id,
			"owner_player_id": next_entry.get("owner_player_id"),
			"source_instance_id": next_entry.get("source_instance_id"),
			"skill_definition_id": skill_id,
			"effect_committed": committed,
			"asset_settlement_action": settlement_action,
			"cooldown_started": (
				committed and int(definition.get("cooldown_batches", 0)) > 0
			),
			"batch_use_consumed": true,
			"public_result_id": public_result_id,
		}
	)
	(next.get("resolution_receipt_ledger") as Dictionary)[
		effect_receipt_id
	] = {
		"input_fingerprint": input_fingerprint,
		"reason_code": reason_code,
		"receipt": operation_receipt.duplicate(true),
	}
	_append_receipt(next, operation_receipt)
	return {
		"accepted": true,
		"replayed": false,
		"reason_code": reason_code,
		"committed": committed,
		"state": _reseal_state(next),
		"receipt": operation_receipt,
		"asset_settlement_intent": asset_settlement_intent,
		"public_result": public_result,
	}


static func advance_batch(
	state: Dictionary,
	next_batch_id: String
) -> Dictionary:
	if _state_error(state) != "":
		return _failure(state, "state_invalid")
	if not _stable_id(next_batch_id) or next_batch_id == state.get("batch_id"):
		return _failure(state, "next_batch_id_invalid")
	if (
		not (state.get("private_queue") as Array).is_empty()
		or str(state.get("resolving_request_id", "")) != ""
		or bool((state.get("atomic_transaction") as Dictionary).get(
			"inflight",
			false
		))
	):
		return _failure(state, "batch_advance_not_quiescent")
	var next := state.duplicate(true)
	var recovered_count := 0
	for source_variant in (next.get("sources") as Dictionary).values():
		var source := source_variant as Dictionary
		source["batch_active_skill_use_count"] = 0
		source["pending_batch_use_request_id"] = ""
		source["last_batch_use_id"] = ""
		for skill_variant in (source.get("skill_states") as Dictionary).values():
			var skill_state := skill_variant as Dictionary
			var cooldown := int(
				skill_state.get("cooldown_remaining_batches", 0)
			)
			if cooldown <= 0:
				continue
			cooldown -= 1
			skill_state["cooldown_remaining_batches"] = cooldown
			if cooldown == 0:
				recovered_count += 1
				if str(skill_state.get("status", "")) == "COOLDOWN":
					skill_state["status"] = "READY"
					skill_state["resume_status"] = "READY"
				elif str(skill_state.get("status", "")) == "DISABLED":
					skill_state["resume_status"] = "READY"
	next["batch_id"] = next_batch_id
	next["batch_index"] = int(next.get("batch_index", 0)) + 1
	next["phase"] = "batch_active"
	_increment_revision(next)
	return {
		"accepted": true,
		"replayed": false,
		"reason_code": "batch_advanced",
		"state": _reseal_state(next),
		"cooldown_recovered_count": recovered_count,
	}


static func set_source_status(
	state: Dictionary,
	source_instance_id: String,
	expected_generation: int,
	status: String
) -> Dictionary:
	if _state_error(state) != "":
		return _failure(state, "state_invalid")
	var normalized_status := "withdrawn" if status == "replaced" else status
	if (
		not SOURCE_STATUSES.has(normalized_status)
		or not (state.get("sources") as Dictionary).has(source_instance_id)
	):
		return _failure(state, "source_status_request_invalid")
	var current_source := (state.get("sources") as Dictionary).get(
		source_instance_id
	) as Dictionary
	if int(current_source.get("source_generation", -1)) != expected_generation:
		return _failure(state, "source_generation_changed")
	var next := state.duplicate(true)
	var source := (next.get("sources") as Dictionary).get(
		source_instance_id
	) as Dictionary
	source["status"] = normalized_status
	for skill_variant in (source.get("skill_states") as Dictionary).values():
		var skill_state := skill_variant as Dictionary
		var skill_status := str(skill_state.get("status", ""))
		if skill_status == "LOCKED_BY_RANK":
			continue
		match normalized_status:
			"active":
				if skill_status == "DISABLED":
					var cooldown := int(
						skill_state.get("cooldown_remaining_batches", 0)
					)
					skill_state["status"] = (
						"COOLDOWN" if cooldown > 0 else "READY"
					)
					skill_state["resume_status"] = skill_state.get("status")
			"downed":
				if skill_status != "REVOKED":
					skill_state["resume_status"] = (
						"COOLDOWN"
						if int(skill_state.get(
							"cooldown_remaining_batches",
							0
						)) > 0
						else "READY"
					)
					skill_state["status"] = "DISABLED"
			_:
				skill_state["status"] = "REVOKED"
				skill_state["resume_status"] = "REVOKED"
	_increment_revision(next)
	return {
		"accepted": true,
		"replayed": false,
		"reason_code": "source_status_updated",
		"state": _reseal_state(next),
		"skills_revoked": ["destroyed", "withdrawn"].has(normalized_status),
	}


static func upgrade_source_skills(
	state: Dictionary,
	source_instance_id: String,
	expected_generation: int,
	new_rank: int,
	unlocked_skill_definition_ids: Array
) -> Dictionary:
	if _state_error(state) != "":
		return _failure(state, "state_invalid")
	if (
		new_rank < 1
		or new_rank > 4
		or not (state.get("sources") as Dictionary).has(source_instance_id)
	):
		return _failure(state, "source_upgrade_request_invalid")
	var current := (state.get("sources") as Dictionary).get(
		source_instance_id
	) as Dictionary
	if (
		int(current.get("source_generation", -1)) != expected_generation
		or new_rank <= int(current.get("rank", 0))
	):
		return _failure(state, "source_upgrade_binding_invalid")
	var unlock_ids := _id_array(unlocked_skill_definition_ids, false)
	if unlock_ids.size() != unlocked_skill_definition_ids.size():
		return _failure(state, "source_upgrade_skill_set_invalid")
	var all_ids := current.get("skill_definition_ids") as Array
	var definitions := state.get("skill_definitions") as Dictionary
	for skill_id in unlock_ids:
		if (
			not all_ids.has(skill_id)
			or not definitions.has(skill_id)
			or int((definitions.get(skill_id) as Dictionary).get(
				"required_rank",
				0
			)) > new_rank
		):
			return _failure(state, "source_upgrade_skill_set_invalid")
	for old_id_variant in current.get(
		"unlocked_skill_definition_ids"
	) as Array:
		if not unlock_ids.has(str(old_id_variant)):
			return _failure(state, "source_upgrade_cannot_relock_skill")

	var next := state.duplicate(true)
	var source := (next.get("sources") as Dictionary).get(
		source_instance_id
	) as Dictionary
	var newly_ready: Array[String] = []
	var cooldowns_before := {}
	for old_id_variant in source.get(
		"unlocked_skill_definition_ids"
	) as Array:
		var old_id := str(old_id_variant)
		cooldowns_before[old_id] = int(
			((source.get("skill_states") as Dictionary).get(
				old_id
			) as Dictionary).get("cooldown_remaining_batches", 0)
		)
	for skill_id in unlock_ids:
		var skill_state := (source.get("skill_states") as Dictionary).get(
			skill_id
		) as Dictionary
		if str(skill_state.get("status", "")) == "LOCKED_BY_RANK":
			newly_ready.append(skill_id)
			match str(source.get("status", "")):
				"active":
					skill_state["status"] = "READY"
					skill_state["resume_status"] = "READY"
				"downed":
					skill_state["status"] = "DISABLED"
					skill_state["resume_status"] = "READY"
				_:
					skill_state["status"] = "REVOKED"
					skill_state["resume_status"] = "REVOKED"
	source["rank"] = new_rank
	source["unlocked_skill_definition_ids"] = unlock_ids
	var cooldown_reset_count := 0
	for old_id_variant in cooldowns_before.keys():
		var old_id := str(old_id_variant)
		var after := int(
			((source.get("skill_states") as Dictionary).get(
				old_id
			) as Dictionary).get("cooldown_remaining_batches", 0)
		)
		if after != int(cooldowns_before.get(old_id)):
			cooldown_reset_count += 1
	_increment_revision(next)
	return {
		"accepted": true,
		"replayed": false,
		"reason_code": "source_skills_upgraded",
		"state": _reseal_state(next),
		"newly_ready_skill_definition_ids": newly_ready,
		"existing_cooldown_reset_count": cooldown_reset_count,
	}


static func owner_private_projection(
	state: Dictionary,
	viewer_player_id: String
) -> Dictionary:
	if _state_error(state) != "" or not _stable_id(viewer_player_id):
		return {}
	var projected_sources: Array = []
	for source_id in _sorted_keys(state.get("sources") as Dictionary):
		var source := (state.get("sources") as Dictionary).get(
			source_id
		) as Dictionary
		if (
			str(source.get("owner_player_id", "")) != viewer_player_id
			or ["destroyed", "withdrawn"].has(
				str(source.get("status", ""))
			)
		):
			continue
		var cards: Array = []
		for skill_id_variant in source.get(
			"unlocked_skill_definition_ids"
		) as Array:
			var skill_id := str(skill_id_variant)
			var skill_state := (source.get("skill_states") as Dictionary).get(
				skill_id
			) as Dictionary
			if str(skill_state.get("status", "")) == "REVOKED":
				continue
			var definition := (state.get(
				"skill_definitions"
			) as Dictionary).get(skill_id) as Dictionary
			cards.append({
				"skill_definition_id": skill_id,
				"public_effect_id": definition.get("public_effect_id"),
				"required_rank": definition.get("required_rank"),
				"ultimate": definition.get("ultimate"),
				"asset_cost_by_color": _copy(
					definition.get("asset_cost_by_color")
				),
				"target_contract": _copy(
					definition.get("target_contract")
				),
				"range_contract": _copy(definition.get("range_contract")),
				"cooldown_batches": definition.get("cooldown_batches"),
				"status": skill_state.get("status"),
				"cooldown_remaining_batches": skill_state.get(
					"cooldown_remaining_batches"
				),
			})
		var pending_target := {}
		for entry_variant in state.get("private_queue") as Array:
			var entry := entry_variant as Dictionary
			if (
				str(entry.get("source_instance_id", "")) == source_id
				and int(entry.get("source_generation", -1))
				== int(source.get("source_generation", -2))
				and int(entry.get("source_action_generation", -1))
				== int(source.get("action_generation", -2))
				and str(entry.get("owner_player_id", ""))
				== viewer_player_id
			):
				pending_target = {
					"request_id": entry.get("request_id"),
					"stage": entry.get("stage"),
					"skill_definition_id": entry.get(
						"skill_definition_id"
					),
					"target_request": _copy(entry.get("target_request")),
				}
				break
		projected_sources.append({
			"source_instance_id": source_id,
			"source_generation": source.get("source_generation"),
			"owner_player_id": viewer_player_id,
			"rank": source.get("rank"),
			"status": source.get("status"),
			"batch_active_skill_use_count": source.get(
				"batch_active_skill_use_count"
			),
			"skill_cards": cards,
			"pending_target_request": pending_target,
		})
	return _seal({
		"schema_version": SCHEMA_VERSION,
		"contract_id": PRIVATE_PROJECTION_ID,
		"ruleset_id": RULESET_ID,
		"viewer_player_id": viewer_player_id,
		"batch_id": state.get("batch_id"),
		"state_revision": state.get("revision"),
		"sources": projected_sources,
	}, "projection_fingerprint")


static func public_projection(state: Dictionary) -> Dictionary:
	if _state_error(state) != "":
		return {}
	var public_used_sources := {}
	for result_variant in state.get("public_results") as Array:
		var result := result_variant as Dictionary
		if result.get("batch_id") == state.get("batch_id"):
			public_used_sources[str(result.get(
				"source_instance_id",
				""
			))] = true
	var summaries: Array = []
	for source_id in _sorted_keys(state.get("sources") as Dictionary):
		var source := (state.get("sources") as Dictionary).get(
			source_id
		) as Dictionary
		summaries.append({
			"source_instance_id": source_id,
			"source_generation": source.get("source_generation"),
			"owner_player_id": source.get("owner_player_id"),
			"rank": source.get("rank"),
			"status": source.get("status"),
			"unlocked_skill_count": (
				source.get("unlocked_skill_definition_ids") as Array
			).size(),
			"batch_active_skill_use_count": (
				1 if public_used_sources.has(source_id) else 0
			),
		})
	var results: Array = []
	for result_variant in state.get("public_results") as Array:
		var source_result := result_variant as Dictionary
		var projected := {}
		for field in PUBLIC_RESULT_FIELDS:
			projected[field] = _copy(source_result.get(field))
		results.append(projected)
	return _seal({
		"schema_version": SCHEMA_VERSION,
		"contract_id": PUBLIC_PROJECTION_ID,
		"ruleset_id": RULESET_ID,
		"batch_id": state.get("batch_id"),
		"state_revision": state.get("revision"),
		"sources": summaries,
		"public_results": results,
	}, "projection_fingerprint")


static func public_projection_privacy_report(
	projection: Dictionary
) -> Dictionary:
	var counts := {}
	for key in FORBIDDEN_PUBLIC_KEYS:
		counts[key] = 0
	_count_forbidden(projection, counts)
	var disclosure_count := 0
	for count_variant in counts.values():
		disclosure_count += int(count_variant)
	var source_shape_violations := 0
	if projection.get("sources") is Array:
		for source_variant in projection.get("sources") as Array:
			if (
				not (source_variant is Dictionary)
				or not _exact_fields(
					source_variant as Dictionary,
					PUBLIC_SOURCE_FIELDS
				)
			):
				source_shape_violations += 1
	var result_shape_violations := 0
	if projection.get("public_results") is Array:
		for result_variant in projection.get("public_results") as Array:
			if (
				not (result_variant is Dictionary)
				or not _exact_fields(
					result_variant as Dictionary,
					PUBLIC_RESULT_FIELDS
				)
			):
				result_shape_violations += 1
	return {
		"valid": (
			disclosure_count == 0
			and source_shape_violations == 0
			and result_shape_violations == 0
		),
		"public_skill_card_disclosure_count": disclosure_count,
		"future_skill_target_disclosure_count": (
			int(counts.get("target_request", 0))
			+ int(counts.get("pending_target_request", 0))
		),
		"internal_sequence_disclosure_count": (
			int(counts.get("authority_receive_sequence", 0))
			+ int(counts.get("internal_sequence", 0))
		),
		"source_shape_violation_count": source_shape_violations,
		"result_shape_violation_count": result_shape_violations,
		"forbidden_key_counts": counts,
	}


static func stable_queue_order(entries: Array) -> Array:
	var ordered := entries.duplicate(true)
	for index in range(1, ordered.size()):
		var current: Dictionary = ordered[index] as Dictionary
		var cursor := index - 1
		while (
			cursor >= 0
			and _queue_entry_less(
				current as Dictionary,
				ordered[cursor] as Dictionary
			)
		):
			ordered[cursor + 1] = ordered[cursor]
			cursor -= 1
		ordered[cursor + 1] = current
	return ordered


static func validation_report(state: Variant) -> Dictionary:
	var reason_code := _state_error(state)
	return {
		"valid": reason_code == "",
		"reason_code": "none" if reason_code == "" else reason_code,
	}


static func is_pure_data(value: Variant) -> bool:
	return _is_pure_data(value)


static func debug_snapshot(state: Dictionary) -> Dictionary:
	if _state_error(state) != "":
		return {"valid": false}
	var pending_count := 0
	for entry_variant in state.get("private_queue") as Array:
		if str((entry_variant as Dictionary).get("stage", "")) == (
			"PENDING_SAFE_BOUNDARY"
		):
			pending_count += 1
	return {
		"valid": true,
		"ruleset_id": RULESET_ID,
		"execution_mode": EXECUTION_MODE,
		"revision": state.get("revision"),
		"batch_index": state.get("batch_index"),
		"source_count": (state.get("sources") as Dictionary).size(),
		"private_queue_count": (state.get("private_queue") as Array).size(),
		"pending_safe_boundary_count": pending_count,
		"resolving_count": (
			0 if str(state.get("resolving_request_id", "")) == "" else 1
		),
		"request_receipt_count": (
			state.get("request_ledger") as Dictionary
		).size(),
		"public_result_count": (
			state.get("public_results") as Array
		).size(),
		"direct_asset_write_count": 0,
		"rng_draw_count": 0,
	}


static func _normalize_skill_definitions(
	skill_definitions: Array
) -> Dictionary:
	var definitions := {}
	for definition_variant in skill_definitions:
		if not (definition_variant is Dictionary):
			return {}
		var definition := definition_variant as Dictionary
		if not _skill_definition_valid(definition):
			return {}
		var skill_id := str(definition.get("skill_definition_id", ""))
		if definitions.has(skill_id):
			return {}
		definitions[skill_id] = definition.duplicate(true)
	return definitions


static func _skill_definition_valid(definition: Dictionary) -> bool:
	if (
		not _exact_fields(definition, SKILL_DEFINITION_FIELDS)
		or not _sealed_contract_valid(
			definition,
			SKILL_DEFINITION_ID,
			"definition_fingerprint"
		)
	):
		return false
	var rank := int(definition.get("required_rank", 0))
	return (
		_stable_id(definition.get("skill_definition_id"))
		and _stable_id(definition.get("public_effect_id"))
		and rank >= 1
		and rank <= 4
		and definition.get("ultimate") is bool
		and bool(definition.get("ultimate", false)) == (rank == 4)
		and _asset_map_valid(definition.get("asset_cost_by_color"))
		and _target_contract_valid(definition.get("target_contract"))
		and definition.get("range_contract") is Dictionary
		and _is_pure_data(definition.get("range_contract"))
		and _nonnegative_integer(definition.get("cooldown_batches"))
		and definition.get("cooldown_on_fizzle") == false
		and _stable_id(definition.get("public_presentation_key"))
	)


static func _normalize_source_snapshot(
	value: Variant,
	definitions: Dictionary
) -> Dictionary:
	if not (value is Dictionary) or not _is_pure_data(value):
		return {}
	var snapshot := value as Dictionary
	var normalized := {}
	match str(snapshot.get("contract_id", "")):
		SOURCE_SNAPSHOT_ID:
			normalized = _normalize_lightweight_source_snapshot(snapshot)
		SOURCE_CORE_SNAPSHOT_ID:
			normalized = _normalize_source_core_snapshot(snapshot)
		_:
			return {}
	if (
		normalized.is_empty()
		or not _normalized_source_context_valid(normalized, definitions)
	):
		return {}
	return normalized


static func _normalize_lightweight_source_snapshot(
	snapshot: Dictionary
) -> Dictionary:
	if (
		not _exact_fields(snapshot, SOURCE_SNAPSHOT_FIELDS)
		or not _sealed_contract_valid(
			snapshot,
			SOURCE_SNAPSHOT_ID,
			"source_fingerprint"
		)
	):
		return {}
	var all_ids := _id_array(snapshot.get("skill_definition_ids"), false)
	var unlocked_ids := _id_array(
		snapshot.get("unlocked_skill_definition_ids"),
		true
	)
	if (
		not (snapshot.get("skill_definition_ids") is Array)
		or all_ids.size()
		!= (snapshot.get("skill_definition_ids") as Array).size()
		or not (snapshot.get("unlocked_skill_definition_ids") is Array)
		or unlocked_ids.size()
		!= (snapshot.get("unlocked_skill_definition_ids") as Array).size()
	):
		return {}
	return {
		"source_contract_id": SOURCE_SNAPSHOT_ID,
		"source_fingerprint": snapshot.get("source_fingerprint"),
		"source_instance_id": snapshot.get("source_instance_id"),
		"source_generation": snapshot.get("source_generation"),
		"source_definition_id": "",
		"monster_family_id": "",
		"owner_player_id": snapshot.get("owner_player_id"),
		"rank": snapshot.get("rank"),
		"status": snapshot.get("status"),
		"skill_definition_ids": all_ids,
		"unlocked_skill_definition_ids": unlocked_ids,
	}


static func _normalize_source_core_snapshot(
	snapshot: Dictionary
) -> Dictionary:
	if not _source_core_snapshot_valid(snapshot):
		return {}
	var skill_states := snapshot.get("skill_states") as Dictionary
	return {
		"source_contract_id": SOURCE_CORE_SNAPSHOT_ID,
		"source_fingerprint": snapshot.get("source_fingerprint"),
		"source_instance_id": snapshot.get("source_instance_id"),
		"source_generation": snapshot.get("source_generation"),
		"source_definition_id": snapshot.get("source_definition_id"),
		"monster_family_id": snapshot.get("monster_family_id"),
		"owner_player_id": snapshot.get("owner_player_id"),
		"rank": snapshot.get("rank"),
		"status": snapshot.get("status"),
		"skill_definition_ids": _id_array(skill_states.keys(), false),
		"unlocked_skill_definition_ids": _id_array(
			snapshot.get("unlocked_skill_definition_ids"),
			true
		),
	}


static func _normalized_source_context_valid(
	snapshot: Dictionary,
	definitions: Dictionary
) -> bool:
	var all_ids := snapshot.get("skill_definition_ids") as Array
	var unlocked_ids := snapshot.get(
		"unlocked_skill_definition_ids"
	) as Array
	var rank := int(snapshot.get("rank", 0))
	if (
		not _stable_id(snapshot.get("source_instance_id"))
		or not _positive_integer(snapshot.get("source_generation"))
		or not _stable_id(snapshot.get("owner_player_id"))
		or rank < 1
		or rank > 4
		or not SOURCE_STATUSES.has(str(snapshot.get("status", "")))
		or all_ids.is_empty()
	):
		return false
	for unlocked_id_variant in unlocked_ids:
		if not all_ids.has(str(unlocked_id_variant)):
			return false
	for skill_id_variant in all_ids:
		var skill_id := str(skill_id_variant)
		if not definitions.has(skill_id):
			return false
		var definition := definitions.get(skill_id) as Dictionary
		var should_be_unlocked := int(definition.get(
			"required_rank",
			0
		)) <= rank
		if unlocked_ids.has(skill_id) != should_be_unlocked:
			return false
	return true


static func _source_core_snapshot_valid(snapshot: Dictionary) -> bool:
	if (
		not _exact_fields(snapshot, SOURCE_CORE_FIELDS)
		or snapshot.get("schema_version") != SOURCE_CORE_SCHEMA_VERSION
		or snapshot.get("contract_id") != SOURCE_CORE_SNAPSHOT_ID
		or snapshot.get("ruleset_id") != RULESET_ID
	):
		return false
	var fingerprint := str(snapshot.get("source_fingerprint", ""))
	var unsealed := snapshot.duplicate(true)
	unsealed.erase("source_fingerprint")
	if (
		not _fingerprint_valid(fingerprint)
		or _fingerprint(unsealed) != fingerprint
	):
		return false
	var rank := int(snapshot.get("rank", 0))
	var status := str(snapshot.get("status", ""))
	var hp := int(snapshot.get("hp", -1))
	var max_hp := int(snapshot.get("max_hp", -1))
	var unlocked := _id_array(
		snapshot.get("unlocked_skill_definition_ids"),
		true
	)
	var facilities := _id_array(
		snapshot.get("facility_type_preference"),
		false
	)
	if (
		not _stable_id(snapshot.get("source_instance_id"))
		or not _stable_id(snapshot.get("source_definition_id"))
		or not _fingerprint_valid(snapshot.get("definition_fingerprint"))
		or not _stable_id(snapshot.get("monster_family_id"))
		or not _stable_id(snapshot.get("owner_player_id"))
		or not _stable_id(snapshot.get("region_id"))
		or not _positive_integer(snapshot.get("source_generation"))
		or rank < 1
		or rank > 4
		or not _nonnegative_integer(snapshot.get("hp"))
		or not _positive_integer(snapshot.get("max_hp"))
		or hp > max_hp
		or not _nonnegative_integer(snapshot.get("armor"))
		or not SOURCE_STATUSES.has(status)
		or not _nonnegative_integer(snapshot.get("damage_revision"))
		or not COLORS.has(str(snapshot.get(
			"preferred_industry_color",
			""
		)))
		or not (snapshot.get("facility_type_preference") is Array)
		or facilities.size()
		!= (snapshot.get("facility_type_preference") as Array).size()
		or not _nonnegative_integer(snapshot.get(
			"base_detection_range_hops"
		))
		or not _nonnegative_integer(snapshot.get(
			"current_detection_range_hops"
		))
		or not SOURCE_CORE_MOVEMENT_PROFILES.has(str(snapshot.get(
			"movement_profile",
			""
		)))
		or not _positive_integer(snapshot.get("movement_budget_milli_arc"))
		or not (snapshot.get("unlocked_skill_definition_ids") is Array)
		or unlocked.size()
		!= (snapshot.get("unlocked_skill_definition_ids") as Array).size()
		or unlocked.size() != rank
		or not _nonnegative_integer(snapshot.get(
			"batch_active_skill_use_count"
		))
		or int(snapshot.get("batch_active_skill_use_count", -1)) > 1
		or not _stable_id(snapshot.get("created_from_card_instance_id"))
		or not _nonnegative_integer(snapshot.get("kill_reward_count"))
		or int(snapshot.get("kill_reward_count", -1)) != 0
	):
		return false
	for facility_type in facilities:
		if not SOURCE_CORE_FACILITY_TYPES.has(facility_type):
			return false
	if status == "active" and hp <= 0:
		return false
	if status == "downed" and hp != 0:
		return false
	if (
		status == "withdrawn"
		and str(snapshot.get("withdrawal_reason", "")) != "replaced"
	):
		return false
	if (
		status != "withdrawn"
		and not str(snapshot.get("withdrawal_reason", "")).is_empty()
	):
		return false
	if not (snapshot.get("skill_states") is Dictionary):
		return false
	var skill_states := snapshot.get("skill_states") as Dictionary
	if skill_states.is_empty():
		return false
	for skill_id_variant in skill_states.keys():
		var skill_id := str(skill_id_variant)
		var skill_state_variant: Variant = skill_states.get(skill_id)
		if (
			not _stable_id(skill_id)
			or not (skill_state_variant is Dictionary)
			or not _source_core_skill_state_valid(
				skill_state_variant as Dictionary,
				skill_id
			)
		):
			return false
		var skill_status := str((skill_state_variant as Dictionary).get(
			"status",
			""
		))
		var is_unlocked := unlocked.has(skill_id)
		if status == "active":
			if (
				is_unlocked
				and ["LOCKED_BY_RANK", "DISABLED", "REVOKED"].has(
					skill_status
				)
			):
				return false
			if not is_unlocked and skill_status != "LOCKED_BY_RANK":
				return false
		elif status == "downed":
			if is_unlocked and skill_status != "DISABLED":
				return false
			if not is_unlocked and skill_status != "LOCKED_BY_RANK":
				return false
		elif skill_status != "REVOKED":
			return false
	return true


static func _source_core_skill_state_valid(
	skill_state: Dictionary,
	skill_id: String
) -> bool:
	if (
		not _exact_fields(skill_state, SOURCE_CORE_SKILL_STATE_FIELDS)
		or str(skill_state.get("skill_definition_id", "")) != skill_id
		or not SKILL_STATUSES.has(str(skill_state.get("status", "")))
		or not _nonnegative_integer(skill_state.get(
			"cooldown_batches_remaining"
		))
		or not _nonnegative_integer(skill_state.get("skill_generation"))
		or not SKILL_RESUME_STATUSES.has(str(skill_state.get(
			"resume_status",
			""
		)))
	):
		return false
	var status := str(skill_state.get("status", ""))
	var cooldown := int(skill_state.get("cooldown_batches_remaining", 0))
	if status == "COOLDOWN" and cooldown <= 0:
		return false
	if ["LOCKED_BY_RANK", "READY"].has(status) and cooldown != 0:
		return false
	return true


static func _private_source_from_snapshot(snapshot: Dictionary) -> Dictionary:
	var all_ids := snapshot.get("skill_definition_ids") as Array
	var unlocked_ids := snapshot.get(
		"unlocked_skill_definition_ids"
	) as Array
	var source_status := str(snapshot.get("status", ""))
	var generation := int(snapshot.get("source_generation", 0))
	var skill_states := {}
	for skill_id_variant in all_ids:
		var skill_id := str(skill_id_variant)
		var status := "LOCKED_BY_RANK"
		var resume_status := "LOCKED_BY_RANK"
		if ["destroyed", "withdrawn"].has(source_status):
			status = "REVOKED"
			resume_status = "REVOKED"
		elif unlocked_ids.has(skill_id):
			if source_status == "active":
				status = "READY"
				resume_status = "READY"
			else:
				status = "DISABLED"
				resume_status = "READY"
		skill_states[skill_id] = {
			"skill_definition_id": skill_id,
			"status": status,
			"resume_status": resume_status,
			"cooldown_remaining_batches": 0,
			"last_request_id": "",
		}
	return {
		"source_instance_id": snapshot.get("source_instance_id"),
		"source_generation": generation,
		"action_generation": generation,
		"source_definition_id": snapshot.get("source_definition_id", ""),
		"monster_family_id": snapshot.get("monster_family_id", ""),
		"owner_player_id": snapshot.get("owner_player_id"),
		"rank": snapshot.get("rank"),
		"status": source_status,
		"skill_definition_ids": all_ids.duplicate(),
		"unlocked_skill_definition_ids": unlocked_ids.duplicate(),
		"skill_states": skill_states,
		"batch_active_skill_use_count": 0,
		"pending_batch_use_request_id": "",
		"last_batch_use_id": "",
		"registration_source_fingerprint": snapshot.get(
			"source_fingerprint"
		),
		"last_source_snapshot_contract_id": snapshot.get(
			"source_contract_id"
		),
		"last_source_snapshot_fingerprint": snapshot.get(
			"source_fingerprint"
		),
	}


static func _same_generation_source_transition(
	current: Dictionary,
	snapshot: Dictionary
) -> Dictionary:
	var all_ids := snapshot.get("skill_definition_ids") as Array
	var unlocked_ids := snapshot.get(
		"unlocked_skill_definition_ids"
	) as Array
	var old_unlocked := current.get(
		"unlocked_skill_definition_ids"
	) as Array
	var old_status := str(current.get("status", ""))
	var new_status := str(snapshot.get("status", ""))
	if current.get("skill_definition_ids") != all_ids:
		return {
			"accepted": false,
			"reason_code": "source_snapshot_skill_identity_changed",
		}
	if int(snapshot.get("rank", 0)) < int(current.get("rank", 0)):
		return {
			"accepted": false,
			"reason_code": "source_snapshot_rank_regressed",
		}
	for old_id_variant in old_unlocked:
		if not unlocked_ids.has(str(old_id_variant)):
			return {
				"accepted": false,
				"reason_code": "source_snapshot_skill_relocked",
			}
	if (
		["destroyed", "withdrawn"].has(old_status)
		and new_status != old_status
	):
		return {
			"accepted": false,
			"reason_code": "source_snapshot_terminal_transition_invalid",
		}
	for identity_field in ["source_definition_id", "monster_family_id"]:
		var old_identity := str(current.get(identity_field, ""))
		var new_identity := str(snapshot.get(identity_field, ""))
		if (
			not old_identity.is_empty()
			and not new_identity.is_empty()
			and old_identity != new_identity
		):
			return {
				"accepted": false,
				"reason_code": "source_snapshot_semantic_identity_changed",
			}

	var next := current.duplicate(true)
	var next_skill_states := next.get("skill_states") as Dictionary
	var cooldowns_before := {}
	for old_id_variant in old_unlocked:
		var old_id := str(old_id_variant)
		cooldowns_before[old_id] = int(
			(next_skill_states.get(old_id) as Dictionary).get(
				"cooldown_remaining_batches",
				0
			)
		)
	var newly_ready: Array[String] = []
	for skill_id_variant in all_ids:
		var skill_id := str(skill_id_variant)
		var previously_unlocked := old_unlocked.has(skill_id)
		var skill_state := next_skill_states.get(skill_id) as Dictionary
		if ["destroyed", "withdrawn"].has(new_status):
			skill_state["status"] = "REVOKED"
			skill_state["resume_status"] = "REVOKED"
			continue
		if not unlocked_ids.has(skill_id):
			skill_state["status"] = "LOCKED_BY_RANK"
			skill_state["resume_status"] = "LOCKED_BY_RANK"
			skill_state["cooldown_remaining_batches"] = 0
			continue
		if not previously_unlocked:
			skill_state = {
				"skill_definition_id": skill_id,
				"status": "READY" if new_status == "active" else "DISABLED",
				"resume_status": "READY",
				"cooldown_remaining_batches": 0,
				"last_request_id": "",
			}
			next_skill_states[skill_id] = skill_state
			if new_status == "active":
				newly_ready.append(skill_id)
			continue
		var cooldown := int(skill_state.get(
			"cooldown_remaining_batches",
			0
		))
		if new_status == "downed":
			skill_state["status"] = "DISABLED"
			skill_state["resume_status"] = (
				"COOLDOWN" if cooldown > 0 else "READY"
			)
		elif str(skill_state.get("status", "")) == "DISABLED":
			skill_state["status"] = "COOLDOWN" if cooldown > 0 else "READY"
			skill_state["resume_status"] = skill_state.get("status")

	next["rank"] = snapshot.get("rank")
	next["status"] = new_status
	next["unlocked_skill_definition_ids"] = unlocked_ids.duplicate()
	if not str(snapshot.get("source_definition_id", "")).is_empty():
		next["source_definition_id"] = snapshot.get("source_definition_id")
	if not str(snapshot.get("monster_family_id", "")).is_empty():
		next["monster_family_id"] = snapshot.get("monster_family_id")
	next["last_source_snapshot_contract_id"] = snapshot.get(
		"source_contract_id"
	)
	next["last_source_snapshot_fingerprint"] = snapshot.get(
		"source_fingerprint"
	)
	var cooldown_reset_count := 0
	for old_id_variant in cooldowns_before.keys():
		var old_id := str(old_id_variant)
		if int((next_skill_states.get(old_id) as Dictionary).get(
			"cooldown_remaining_batches",
			0
		)) != int(cooldowns_before.get(old_id)):
			cooldown_reset_count += 1
	var reason_code := "source_snapshot_synchronized"
	if ["destroyed", "withdrawn"].has(new_status):
		reason_code = "source_snapshot_revoked"
	elif int(snapshot.get("rank", 0)) > int(current.get("rank", 0)):
		reason_code = "source_snapshot_upgraded"
	elif old_status == "downed" and new_status == "active":
		reason_code = "source_snapshot_refreshed"
	return {
		"accepted": true,
		"reason_code": reason_code,
		"source": next,
		"newly_ready_skill_definition_ids": newly_ready,
		"existing_cooldown_reset_count": cooldown_reset_count,
		"generation_replaced": false,
	}


static func _private_source_matches_snapshot(
	current: Dictionary,
	snapshot: Dictionary
) -> bool:
	if (
		int(current.get("source_generation", -1))
		!= int(snapshot.get("source_generation", -2))
		or int(current.get("rank", -1))
		!= int(snapshot.get("rank", -2))
		or str(current.get("status", ""))
		!= str(snapshot.get("status", ""))
		or current.get("skill_definition_ids")
		!= snapshot.get("skill_definition_ids")
		or current.get("unlocked_skill_definition_ids")
		!= snapshot.get("unlocked_skill_definition_ids")
	):
		return false
	for identity_field in ["source_definition_id", "monster_family_id"]:
		var incoming_identity := str(snapshot.get(identity_field, ""))
		var current_identity := str(current.get(identity_field, ""))
		if (
			not incoming_identity.is_empty()
			and not current_identity.is_empty()
			and incoming_identity != current_identity
		):
			return false
	return true


static func _preaccept_reason(
	state: Dictionary,
	request: Dictionary,
	asset_view: Dictionary
) -> String:
	if str(request.get("batch_id", "")) != str(state.get("batch_id", "")):
		return "request_batch_changed"
	var phase := str(state.get("phase", ""))
	if TERMINAL_PHASES.has(phase):
		return "terminal_combat_request_forbidden"
	if not REQUEST_PHASES.has(phase):
		return "request_phase_forbidden"
	var owner_id := str(request.get("owner_player_id", ""))
	if (
		str(asset_view.get("viewer_id", "")) != owner_id
		or not _nonnegative_integer(asset_view.get("state_revision"))
		or not _asset_map_valid(asset_view.get("own_available_assets"))
	):
		return "owner_available_unreserved_asset_view_invalid"
	for forbidden in [
		"opponent_assets",
		"opponent_reservations",
		"all_player_assets",
	]:
		if asset_view.has(forbidden):
			return "opponent_private_asset_view_forbidden"
	var source_id := str(request.get("source_instance_id", ""))
	if not (state.get("sources") as Dictionary).has(source_id):
		return "source_not_found"
	var source := (state.get("sources") as Dictionary).get(
		source_id
	) as Dictionary
	if str(source.get("owner_player_id", "")) != owner_id:
		return "source_not_owned_by_requester"
	if int(source.get("source_generation", -1)) != int(
		request.get("source_generation", -2)
	):
		return "source_generation_changed"
	if str(source.get("status", "")) != "active":
		return "source_not_active"
	if int(source.get("batch_active_skill_use_count", 0)) >= (
		MAX_SKILL_USES_PER_SOURCE_PER_BATCH
	):
		return "source_batch_skill_use_exhausted"
	if str(source.get("pending_batch_use_request_id", "")) != "":
		return "source_batch_skill_request_pending"
	var skill_id := str(request.get("skill_definition_id", ""))
	if not (source.get("unlocked_skill_definition_ids") as Array).has(
		skill_id
	):
		return "skill_locked_by_rank"
	var skill_state := (source.get("skill_states") as Dictionary).get(
		skill_id,
		{}
	) as Dictionary
	if str(skill_state.get("status", "")) != "READY":
		return "skill_not_ready"
	var definition := (state.get("skill_definitions") as Dictionary).get(
		skill_id,
		{}
	) as Dictionary
	if definition.is_empty():
		return "skill_definition_missing"
	if str((request.get("target_request") as Dictionary).get(
		"target_kind",
		""
	)) != str((definition.get("target_contract") as Dictionary).get(
		"target_kind",
		""
	)):
		return "target_contract_mismatch"
	var available := asset_view.get("own_available_assets") as Dictionary
	var cost := definition.get("asset_cost_by_color") as Dictionary
	for color in COLORS:
		if int(cost.get(color, 0)) > int(available.get(color, 0)):
			return "available_unreserved_assets_insufficient"
	return ""


static func _source_execution_reason(
	source: Dictionary,
	entry: Dictionary
) -> String:
	if (
		int(source.get("source_generation", -1))
		!= int(entry.get("source_generation", -2))
		or int(source.get("action_generation", -1))
		!= int(entry.get("source_action_generation", -2))
	):
		return "source_generation_changed_at_boundary"
	match str(source.get("status", "")):
		"active":
			return ""
		"downed":
			return "source_downed_at_boundary"
		"destroyed":
			return "source_destroyed_at_boundary"
		"withdrawn":
			return "source_withdrawn_at_boundary"
	return "source_invalid_at_boundary"


static func _has_due_request(state: Dictionary) -> bool:
	if bool((state.get("atomic_transaction") as Dictionary).get(
		"inflight",
		false
	)):
		return false
	var boundary := int(state.get("safe_boundary_sequence", 0))
	for entry_variant in state.get("private_queue") as Array:
		var entry := entry_variant as Dictionary
		if (
			str(entry.get("stage", "")) == "PENDING_SAFE_BOUNDARY"
			and int(entry.get("required_safe_boundary_sequence", -1))
			<= boundary
		):
			return true
	return false


static func _queue_entry_less(
	left: Dictionary,
	right: Dictionary
) -> bool:
	var left_sequence := int(left.get("authority_receive_sequence", 0))
	var right_sequence := int(right.get("authority_receive_sequence", 0))
	if left_sequence != right_sequence:
		return left_sequence < right_sequence
	var left_player := str(left.get("owner_player_id", ""))
	var right_player := str(right.get("owner_player_id", ""))
	if left_player != right_player:
		return left_player < right_player
	return str(left.get("request_id", "")) < str(
		right.get("request_id", "")
	)


static func _queue_index_by(
	queue: Array,
	field: String,
	value: String
) -> int:
	for index in range(queue.size()):
		if str((queue[index] as Dictionary).get(field, "")) == value:
			return index
	return -1


static func _state_error(value: Variant) -> String:
	if not (value is Dictionary) or not _is_pure_data(value):
		return "state_not_pure_dictionary"
	var state := value as Dictionary
	if (
		state.get("schema_version") != SCHEMA_VERSION
		or state.get("state_version") != STATE_VERSION
		or state.get("ruleset_id") != RULESET_ID
		or state.get("contract_id") != CONTRACT_ID
		or state.get("execution_mode") != EXECUTION_MODE
		or not _stable_id(state.get("lineage_id"))
		or not _nonnegative_integer(state.get("revision"))
		or not _stable_id(state.get("batch_id"))
		or not _nonnegative_integer(state.get("batch_index"))
		or (
			not REQUEST_PHASES.has(str(state.get("phase", "")))
			and not TERMINAL_PHASES.has(str(state.get("phase", "")))
		)
		or not _nonnegative_integer(state.get("safe_boundary_sequence"))
		or not _nonnegative_integer(
			state.get("next_authority_receive_sequence")
		)
		or not (state.get("atomic_transaction") is Dictionary)
		or not (state.get("atomic_receipt_ledger") is Dictionary)
		or not (state.get("resolving_request_id") is String)
		or not (state.get("skill_definitions") is Dictionary)
		or not (state.get("sources") is Dictionary)
		or not (state.get("private_queue") is Array)
		or not (state.get("request_ledger") is Dictionary)
		or not (state.get("reservation_receipt_ledger") is Dictionary)
		or not (state.get("resolution_receipt_ledger") is Dictionary)
		or not (state.get("receipt_journal") is Array)
		or not (state.get("public_results") is Array)
	):
		return "state_contract_invalid"
	var atomic := state.get("atomic_transaction") as Dictionary
	if (
		not (atomic.get("inflight") is bool)
		or not (atomic.get("receipt_id") is String)
		or (
			bool(atomic.get("inflight", false))
			and not _stable_id(atomic.get("receipt_id"))
		)
	):
		return "atomic_transaction_contract_invalid"
	var fingerprint := str(state.get("state_fingerprint", ""))
	var unsealed := state.duplicate(true)
	unsealed.erase("state_fingerprint")
	if (
		not _fingerprint_valid(fingerprint)
		or _fingerprint(unsealed) != fingerprint
	):
		return "state_fingerprint_invalid"
	return ""


static func _operation_receipt(
	state: Dictionary,
	operation_id: String,
	identity: String,
	accepted: bool,
	reason_code: String,
	private_fields: Dictionary
) -> Dictionary:
	var receipt := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": "V075MonsterPrivateSkillOperationReceiptV1",
		"receipt_id": "receipt.monster.private.skill.%s" % (
			"%s|%s|%s|%d" % [
				state.get("lineage_id"),
				operation_id,
				identity,
				state.get("revision"),
			]
		).sha256_text().substr(0, 24),
		"operation_id": operation_id,
		"accepted": accepted,
		"reason_code": reason_code,
		"state_revision": state.get("revision"),
		"batch_id": state.get("batch_id"),
	}
	for key_variant in private_fields.keys():
		receipt[str(key_variant)] = _copy(private_fields.get(key_variant))
	return _seal(receipt, "receipt_fingerprint")


static func _append_receipt(
	state: Dictionary,
	receipt: Dictionary
) -> void:
	(state.get("receipt_journal") as Array).append(
		receipt.duplicate(true)
	)


static func _increment_revision(state: Dictionary) -> void:
	state["revision"] = int(state.get("revision", 0)) + 1


static func _reseal_state(state: Dictionary) -> Dictionary:
	var next := state.duplicate(true)
	next.erase("state_fingerprint")
	next["state_fingerprint"] = _fingerprint(next)
	return next


static func _success(
	state: Dictionary,
	reason_code: String
) -> Dictionary:
	return {
		"accepted": true,
		"replayed": false,
		"reason_code": reason_code,
		"state": _reseal_state(state),
	}


static func _failure(
	state: Variant,
	reason_code: String
) -> Dictionary:
	return {
		"accepted": false,
		"replayed": false,
		"reason_code": reason_code,
		"state": (
			(state as Dictionary).duplicate(true)
			if state is Dictionary
			else {}
		),
		"receipt": {},
	}


static func _sealed_contract_valid(
	value: Variant,
	contract_id: String,
	fingerprint_field: String
) -> bool:
	if not (value is Dictionary) or not _is_pure_data(value):
		return false
	var data := value as Dictionary
	if (
		data.get("schema_version") != SCHEMA_VERSION
		or data.get("contract_id") != contract_id
	):
		return false
	var fingerprint := str(data.get(fingerprint_field, ""))
	var unsealed := data.duplicate(true)
	unsealed.erase(fingerprint_field)
	return (
		_fingerprint_valid(fingerprint)
		and _fingerprint(unsealed) == fingerprint
	)


static func _allowlisted(
	source: Dictionary,
	allowlist: Array
) -> Dictionary:
	var result := {}
	for key_variant in allowlist:
		var key := str(key_variant)
		if source.has(key) and _is_pure_data(source.get(key)):
			result[key] = _copy(source.get(key))
	return result


static func _count_forbidden(
	value: Variant,
	counts: Dictionary
) -> void:
	if value is Array:
		for item_variant in value as Array:
			_count_forbidden(item_variant, counts)
		return
	if not (value is Dictionary):
		return
	for key_variant in (value as Dictionary).keys():
		var key := str(key_variant)
		if counts.has(key):
			counts[key] = int(counts.get(key, 0)) + 1
		_count_forbidden((value as Dictionary).get(key_variant), counts)


static func _asset_map_valid(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var assets := value as Dictionary
	if not _exact_fields(assets, COLORS):
		return false
	for color in COLORS:
		if (
			not _nonnegative_integer(assets.get(color))
			or int(assets.get(color, 0)) > 6
		):
			return false
	return true


static func _target_contract_valid(value: Variant) -> bool:
	return (
		value is Dictionary
		and _is_pure_data(value)
		and _stable_id((value as Dictionary).get("target_kind"))
	)


static func _stable_id(value: Variant) -> bool:
	if not (value is String):
		return false
	var text := str(value)
	if text.is_empty() or text.length() > 192:
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


static func _nonnegative_integer(value: Variant) -> bool:
	return (
		value is int
		and int(value) >= 0
		and int(value) <= MAX_SAFE_INTEGER
	)


static func _positive_integer(value: Variant) -> bool:
	return _nonnegative_integer(value) and int(value) > 0


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


static func _id_array(
	value: Variant,
	allow_empty: bool
) -> Array[String]:
	if not (value is Array):
		return []
	var result: Array[String] = []
	for item_variant in value as Array:
		if not _stable_id(item_variant) or result.has(str(item_variant)):
			return []
		result.append(str(item_variant))
	result.sort()
	if not allow_empty and result.is_empty():
		return []
	return result


static func _sorted_keys(value: Dictionary) -> Array[String]:
	var keys: Array[String] = []
	for key_variant in value.keys():
		keys.append(str(key_variant))
	keys.sort()
	return keys


static func _seal(
	unsealed: Dictionary,
	fingerprint_field: String
) -> Dictionary:
	if unsealed.has(fingerprint_field) or not _is_pure_data(unsealed):
		return {}
	var sealed := unsealed.duplicate(true)
	sealed[fingerprint_field] = _fingerprint(sealed)
	return sealed


static func _fingerprint(value: Variant) -> String:
	var canonical := _canonical_json(value)
	return canonical.sha256_text().to_lower() if canonical != "" else ""


static func _canonical_json(value: Variant) -> String:
	if not _is_pure_data(value):
		return ""
	if (
		value == null
		or value is String
		or value is bool
		or value is int
	):
		return JSON.stringify(value)
	if value is Array:
		var parts: Array[String] = []
		for item_variant in value as Array:
			parts.append(_canonical_json(item_variant))
		return "[" + ",".join(parts) + "]"
	var dictionary := value as Dictionary
	var members: Array[String] = []
	for key in _sorted_keys(dictionary):
		members.append(
			JSON.stringify(key)
			+ ":"
			+ _canonical_json(dictionary.get(key))
		)
	return "{" + ",".join(members) + "}"


static func _is_pure_data(
	value: Variant,
	depth: int = 0
) -> bool:
	if depth > 64:
		return false
	if (
		value == null
		or value is String
		or value is bool
		or value is int
	):
		return (
			not (value is int)
			or (
				int(value) >= -MAX_SAFE_INTEGER
				and int(value) <= MAX_SAFE_INTEGER
			)
		)
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


static func _copy(value: Variant) -> Variant:
	if value is Dictionary or value is Array:
		return value.duplicate(true)
	return value
