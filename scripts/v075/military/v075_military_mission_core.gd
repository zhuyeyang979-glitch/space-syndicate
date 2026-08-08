extends RefCounted
class_name V075MilitaryMissionCore

const CombatDamageCore := preload(
	"res://scripts/v075/combat/v075_combat_damage_core.gd"
)
const FacilityDamageIntent := preload(
	"res://scripts/v075/combat/facility_combat_damage_intent_v1.gd"
)

const SCHEMA_VERSION := 1
const RULESET_ID := "v0.7.5"
const REQUEST_CONTRACT_ID := "MilitaryMissionRequestV1"
const CARD_AUTHORITY_CONTRACT_ID := "MilitaryCardAuthorityFactsV1"
const LOCK_CONTRACT_ID := "LockedMilitaryMissionV1"
const RECEIPT_CONTRACT_ID := "MilitaryMissionReceiptV1"
const WITHDRAWAL_CONTRACT_ID := "MilitaryWithdrawalIntentV1"
const DBG_LIFECYCLE_CONTRACT_ID := "NormalDbgCardZoneIntentV1"
const ASSET_SETTLEMENT_CONTRACT_ID := "ReservedAssetSettlementIntentV1"

const TASK_ASSAULT_REGION := "assault_region"
const TASK_ASSAULT_MONSTER := "assault_monster"
const TASK_KINDS := [TASK_ASSAULT_REGION, TASK_ASSAULT_MONSTER]
const FACILITY_TYPES := ["factory", "market", "warehouse"]
const MONSTER_LEGAL_STATUSES := ["active", "downed"]
const MAX_DAMAGE_BUDGET := 10000

const REQUEST_FIELDS := [
	"schema_version",
	"contract_id",
	"ruleset_id",
	"request_id",
	"mission_id",
	"task_kind",
	"owner_player_id",
	"card_instance_id",
	"action_slot_id",
	"asset_reservation_id",
	"target_region_id",
	"target_monster_source_instance_id",
	"request_fingerprint",
]
const CARD_AUTHORITY_FIELDS := [
	"schema_version",
	"contract_id",
	"ruleset_id",
	"card_definition_id",
	"card_rank",
	"region_damage_budget",
	"monster_damage",
	"source_effect_id",
	"committed_escrow_revision",
	"authority_fingerprint",
]
const LOCKED_FACILITY_FIELDS := [
	"target_facility_id",
	"expected_generation",
	"expected_owner_player_id",
	"facility_type",
	"industry_id",
]
const LOCK_FIELDS := [
	"schema_version",
	"contract_id",
	"ruleset_id",
	"request_id",
	"mission_id",
	"task_kind",
	"owner_player_id",
	"card_instance_id",
	"card_definition_id",
	"card_rank",
	"action_slot_id",
	"asset_reservation_id",
	"committed_escrow_revision",
	"source_effect_id",
	"target_region_id",
	"target_region_revision",
	"locked_facility_targets",
	"target_monster_source_instance_id",
	"target_source_generation",
	"target_monster_revision",
	"target_monster_owner_player_id",
	"public_target_region_id",
	"region_strike_damage_budget",
	"monster_damage",
	"mission_state",
	"target_reselection_allowed",
	"persistent_source_created",
	"bound_action_created",
	"lock_fingerprint",
]
const RECEIPT_FIELDS := [
	"schema_version",
	"contract_id",
	"ruleset_id",
	"combat_receipt_id",
	"mission_id",
	"task_kind",
	"owner_player_id",
	"card_instance_id",
	"outcome",
	"reason_code",
	"target_region_id",
	"public_target_region_id",
	"facility_damage_intents",
	"monster_damage_intents",
	"military_withdrawal_intent",
	"dbg_lifecycle_intent",
	"asset_settlement_intent",
	"allocated_damage_total",
	"locked_target_count",
	"resolved_target_count",
	"retarget_count",
	"persistent_source_count",
	"bound_action_count",
	"direct_facility_write_count",
	"direct_dbg_write_count",
	"mission_state_after",
	"receipt_fingerprint",
]


static func build_region_request(
	request_id: String,
	mission_id: String,
	owner_player_id: String,
	card_instance_id: String,
	action_slot_id: String,
	asset_reservation_id: String,
	target_region_id: String
) -> Dictionary:
	return _build_request(
		request_id,
		mission_id,
		TASK_ASSAULT_REGION,
		owner_player_id,
		card_instance_id,
		action_slot_id,
		asset_reservation_id,
		target_region_id,
		""
	)


static func build_monster_request(
	request_id: String,
	mission_id: String,
	owner_player_id: String,
	card_instance_id: String,
	action_slot_id: String,
	asset_reservation_id: String,
	target_monster_source_instance_id: String
) -> Dictionary:
	return _build_request(
		request_id,
		mission_id,
		TASK_ASSAULT_MONSTER,
		owner_player_id,
		card_instance_id,
		action_slot_id,
		asset_reservation_id,
		"",
		target_monster_source_instance_id
	)


static func build_card_authority(
	card_definition_id: String,
	card_rank: int,
	region_damage_budget: int,
	monster_damage: int,
	source_effect_id: String,
	committed_escrow_revision: int
) -> Dictionary:
	var facts := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": CARD_AUTHORITY_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"card_definition_id": card_definition_id,
		"card_rank": card_rank,
		"region_damage_budget": region_damage_budget,
		"monster_damage": monster_damage,
		"source_effect_id": source_effect_id,
		"committed_escrow_revision": committed_escrow_revision,
		"authority_fingerprint": "",
	}
	facts["authority_fingerprint"] = _fingerprint_without(
		facts, "authority_fingerprint"
	)
	return facts 		if bool(card_authority_validation_report(facts).get("valid", false)) 		else {}


static func request_validation_report(value: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not (value is Dictionary) or not _closed_data(value):
		errors.append("military_mission_request_not_closed_data")
		return _report(errors, "military_mission_request_valid")
	var request := value as Dictionary
	if not _exact_fields(request, REQUEST_FIELDS):
		errors.append("military_mission_request_fields_invalid")
		return _report(errors, "military_mission_request_valid")
	if int(request.get("schema_version", -1)) != SCHEMA_VERSION 			or str(request.get("contract_id", "")) != REQUEST_CONTRACT_ID 			or str(request.get("ruleset_id", "")) != RULESET_ID:
		errors.append("military_mission_request_header_invalid")
	for field in [
		"request_id",
		"mission_id",
		"owner_player_id",
		"card_instance_id",
		"action_slot_id",
		"asset_reservation_id",
	]:
		if not _stable_id(request.get(field)):
			errors.append("military_mission_request_%s_invalid" % field)
	var task_kind := str(request.get("task_kind", ""))
	if task_kind not in TASK_KINDS:
		errors.append("military_mission_task_kind_invalid")
	var region_id := str(request.get("target_region_id", ""))
	var monster_id := str(
		request.get("target_monster_source_instance_id", "")
	)
	if task_kind == TASK_ASSAULT_REGION:
		if not _stable_id(region_id) or not monster_id.is_empty():
			errors.append("military_region_request_target_invalid")
	elif task_kind == TASK_ASSAULT_MONSTER:
		if not region_id.is_empty() or not _stable_id(monster_id):
			errors.append("military_monster_request_target_invalid")
	var fingerprint := str(request.get("request_fingerprint", ""))
	if not _fingerprint_valid(fingerprint) 			or fingerprint != _fingerprint_without(
				request, "request_fingerprint"
			):
		errors.append("military_mission_request_fingerprint_invalid")
	return _report(errors, "military_mission_request_valid")


static func card_authority_validation_report(value: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not (value is Dictionary) or not _closed_data(value):
		errors.append("military_card_authority_not_closed_data")
		return _report(errors, "military_card_authority_valid")
	var facts := value as Dictionary
	if not _exact_fields(facts, CARD_AUTHORITY_FIELDS):
		errors.append("military_card_authority_fields_invalid")
		return _report(errors, "military_card_authority_valid")
	if int(facts.get("schema_version", -1)) != SCHEMA_VERSION 			or str(facts.get("contract_id", "")) 			!= CARD_AUTHORITY_CONTRACT_ID 			or str(facts.get("ruleset_id", "")) != RULESET_ID:
		errors.append("military_card_authority_header_invalid")
	if not _stable_id(facts.get("card_definition_id")) 			or not _stable_id(facts.get("source_effect_id")):
		errors.append("military_card_authority_identity_invalid")
	if not _positive_integer(facts.get("card_rank")) 			or int(facts.get("card_rank", 0)) > 4:
		errors.append("military_card_authority_rank_invalid")
	for field in ["region_damage_budget", "monster_damage"]:
		if not _positive_integer(facts.get(field)) 			or int(facts.get(field, 0)) > MAX_DAMAGE_BUDGET:
			errors.append("military_card_authority_%s_invalid" % field)
	if not _nonnegative_integer(
		facts.get("committed_escrow_revision")
	):
		errors.append("military_card_authority_escrow_revision_invalid")
	var fingerprint := str(facts.get("authority_fingerprint", ""))
	if not _fingerprint_valid(fingerprint) 			or fingerprint != _fingerprint_without(
				facts, "authority_fingerprint"
			):
		errors.append("military_card_authority_fingerprint_invalid")
	return _report(errors, "military_card_authority_valid")


static func lock_region_assault(
	request: Dictionary,
	card_authority: Dictionary,
	target_region_revision: int,
	public_facilities: Array
) -> Dictionary:
	if not bool(request_validation_report(request).get("valid", false)) 			or str(request.get("task_kind", "")) != TASK_ASSAULT_REGION:
		return _lock_failure("military_region_request_invalid")
	if not bool(
		card_authority_validation_report(card_authority).get("valid", false)
	):
		return _lock_failure("military_card_authority_invalid")
	if not _nonnegative_integer(target_region_revision):
		return _lock_failure("military_target_region_revision_invalid")
	var target_region_id := str(request.get("target_region_id", ""))
	var owner_player_id := str(request.get("owner_player_id", ""))
	var candidates: Array = []
	var seen_ids := {}
	for facility_variant in public_facilities:
		var facility := _public_facility_view(facility_variant)
		if facility.is_empty() 				or str(facility.get("region_id", "")) != target_region_id 				or str(facility.get("owner_player_id", "")) 				== owner_player_id 				or not _facility_status_legal(
					str(facility.get("status", ""))
				):
			continue
		var facility_id := str(facility.get("facility_id", ""))
		if seen_ids.has(facility_id):
			return _lock_failure("military_region_duplicate_facility_id")
		seen_ids[facility_id] = true
		candidates.append({
			"target_facility_id": facility_id,
			"expected_generation": int(
				facility.get("facility_generation", 0)
			),
			"expected_owner_player_id": str(
				facility.get("owner_player_id", "")
			),
			"facility_type": str(facility.get("facility_type", "")),
			"industry_id": str(facility.get("industry_id", "")),
		})
	candidates.sort_custom(_sort_locked_facility)
	if candidates.is_empty():
		return _lock_failure("military_region_has_no_enemy_facility")
	return _build_lock(
		request,
		card_authority,
		target_region_revision,
		candidates,
		{}
	)


static func lock_monster_assault(
	request: Dictionary,
	card_authority: Dictionary,
	public_monsters: Array
) -> Dictionary:
	if not bool(request_validation_report(request).get("valid", false)) 			or str(request.get("task_kind", "")) != TASK_ASSAULT_MONSTER:
		return _lock_failure("military_monster_request_invalid")
	if not bool(
		card_authority_validation_report(card_authority).get("valid", false)
	):
		return _lock_failure("military_card_authority_invalid")
	var requested_id := str(
		request.get("target_monster_source_instance_id", "")
	)
	var target := {}
	for monster_variant in public_monsters:
		var monster := _public_monster_view(monster_variant)
		if monster.is_empty() 				or str(monster.get("source_instance_id", "")) 				!= requested_id:
			continue
		target = monster
		break
	if target.is_empty() 			or str(target.get("owner_player_id", "")) 			== str(request.get("owner_player_id", "")) 			or str(target.get("status", "")) not in MONSTER_LEGAL_STATUSES:
		return _lock_failure("military_monster_target_invalid")
	return _build_lock(request, card_authority, -1, [], target)


static func mission_lock_validation_report(value: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not (value is Dictionary) or not _closed_data(value):
		errors.append("military_mission_lock_not_closed_data")
		return _report(errors, "military_mission_lock_valid")
	var locked := value as Dictionary
	if not _exact_fields(locked, LOCK_FIELDS):
		errors.append("military_mission_lock_fields_invalid")
		return _report(errors, "military_mission_lock_valid")
	if int(locked.get("schema_version", -1)) != SCHEMA_VERSION 			or str(locked.get("contract_id", "")) != LOCK_CONTRACT_ID 			or str(locked.get("ruleset_id", "")) != RULESET_ID:
		errors.append("military_mission_lock_header_invalid")
	for field in [
		"request_id",
		"mission_id",
		"owner_player_id",
		"card_instance_id",
		"card_definition_id",
		"action_slot_id",
		"asset_reservation_id",
		"source_effect_id",
	]:
		if not _stable_id(locked.get(field)):
			errors.append("military_mission_lock_%s_invalid" % field)
	if str(locked.get("task_kind", "")) not in TASK_KINDS 			or str(locked.get("mission_state", "")) != "locked":
		errors.append("military_mission_lock_state_invalid")
	if bool(locked.get("target_reselection_allowed", true)) 			or bool(locked.get("persistent_source_created", true)) 			or bool(locked.get("bound_action_created", true)):
		errors.append("military_mission_lock_forbidden_capability")
	var task_kind := str(locked.get("task_kind", ""))
	var targets := locked.get("locked_facility_targets", []) as Array
	if task_kind == TASK_ASSAULT_REGION:
		if not _stable_id(locked.get("target_region_id")) 				or not _nonnegative_integer(
					locked.get("target_region_revision")
				) 				or targets.is_empty():
			errors.append("military_region_lock_target_invalid")
		for target_variant in targets:
			if not _locked_facility_valid(target_variant):
				errors.append("military_region_lock_facility_invalid")
	elif task_kind == TASK_ASSAULT_MONSTER:
		if not targets.is_empty() 				or not _stable_id(
					locked.get(
						"target_monster_source_instance_id"
					)
				) 				or not _positive_integer(
					locked.get("target_source_generation")
				) 				or not _nonnegative_integer(
					locked.get("target_monster_revision")
				) 				or not _stable_id(
					locked.get("public_target_region_id")
				):
			errors.append("military_monster_lock_target_invalid")
	var fingerprint := str(locked.get("lock_fingerprint", ""))
	if not _fingerprint_valid(fingerprint) 			or fingerprint != _fingerprint_without(
				locked, "lock_fingerprint"
			):
		errors.append("military_mission_lock_fingerprint_invalid")
	return _report(errors, "military_mission_lock_valid")

static func resolve_region_assault(
	locked: Dictionary,
	current_public_facilities: Array
) -> Dictionary:
	if not bool(
		mission_lock_validation_report(locked).get("valid", false)
	) or str(locked.get("task_kind", "")) != TASK_ASSAULT_REGION:
		return _resolution_failure("military_region_lock_invalid")
	var current_by_id := {}
	for facility_variant in current_public_facilities:
		var facility := _public_facility_view(facility_variant)
		if facility.is_empty():
			continue
		var facility_id := str(facility.get("facility_id", ""))
		if not current_by_id.has(facility_id):
			current_by_id[facility_id] = facility
	var legal_targets: Array = []
	for target_variant in locked.get("locked_facility_targets", []) as Array:
		var target := target_variant as Dictionary
		var target_id := str(target.get("target_facility_id", ""))
		var current := current_by_id.get(target_id, {}) as Dictionary
		if current.is_empty() 				or int(current.get("facility_generation", -1)) 				!= int(target.get("expected_generation", -2)) 				or str(current.get("region_id", "")) 				!= str(locked.get("target_region_id", "")) 				or str(current.get("owner_player_id", "")) 				!= str(target.get("expected_owner_player_id", "")) 				or str(current.get("facility_type", "")) 				!= str(target.get("facility_type", "")) 				or not _facility_status_legal(
					str(current.get("status", ""))
				):
			continue
		legal_targets.append(target.duplicate(true))
	if legal_targets.is_empty():
		return _build_receipt(
			locked,
			"fizzled",
			"all_locked_facilities_invalid",
			[],
			[],
			0,
			0,
			str(locked.get("target_region_id", ""))
		)
	var damage_by_id := {}
	for target_variant in legal_targets:
		damage_by_id[str(
			(target_variant as Dictionary).get("target_facility_id", "")
		)] = 0
	var remaining := int(locked.get("region_strike_damage_budget", 0))
	while remaining > 0:
		for target_variant in legal_targets:
			if remaining <= 0:
				break
			var target_id := str(
				(target_variant as Dictionary).get(
					"target_facility_id", ""
				)
			)
			damage_by_id[target_id] = int(
				damage_by_id.get(target_id, 0)
			) + 1
			remaining -= 1
	var allocations: Array = []
	for target_variant in legal_targets:
		var target := target_variant as Dictionary
		var target_id := str(target.get("target_facility_id", ""))
		allocations.append({
			"target_facility_id": target_id,
			"expected_generation": int(
				target.get("expected_generation", 0)
			),
			"damage_amount": int(damage_by_id.get(target_id, 0)),
		})
	var combat_receipt_id := _combat_receipt_id(locked)
	var damage_batch := CombatDamageCore.build_facility_damage_batch(
		str(locked.get("source_effect_id", "")),
		combat_receipt_id,
		"military_region_assault",
		allocations
	)
	if not bool(damage_batch.get("accepted", false)):
		return _build_receipt(
			locked,
			"fizzled",
			"facility_damage_intent_build_failed",
			[],
			[],
			0,
			0,
			str(locked.get("target_region_id", ""))
		)
	return _build_receipt(
		locked,
		"resolved",
		"military_region_assault_resolved",
		damage_batch.get("intents", []) as Array,
		[],
		int(damage_batch.get("total_damage", 0)),
		legal_targets.size(),
		str(locked.get("target_region_id", ""))
	)


static func resolve_monster_assault(
	locked: Dictionary,
	current_public_monsters: Array
) -> Dictionary:
	if not bool(
		mission_lock_validation_report(locked).get("valid", false)
	) or str(locked.get("task_kind", "")) != TASK_ASSAULT_MONSTER:
		return _resolution_failure("military_monster_lock_invalid")
	var target_id := str(
		locked.get("target_monster_source_instance_id", "")
	)
	var current := {}
	for monster_variant in current_public_monsters:
		var monster := _public_monster_view(monster_variant)
		if monster.is_empty() 				or str(monster.get("source_instance_id", "")) 				!= target_id:
			continue
		current = monster
		break
	var target_valid := not current.is_empty() 		and int(current.get("source_generation", -1)) 		== int(locked.get("target_source_generation", -2)) 		and int(current.get("source_revision", -1)) 		>= int(locked.get("target_monster_revision", 0)) 		and str(current.get("owner_player_id", "")) 		== str(locked.get("target_monster_owner_player_id", "")) 		and str(current.get("owner_player_id", "")) 		!= str(locked.get("owner_player_id", "")) 		and str(current.get("status", "")) in MONSTER_LEGAL_STATUSES 		and _stable_id(current.get("region_id"))
	if not target_valid:
		return _build_receipt(
			locked,
			"fizzled",
			"locked_monster_target_invalid",
			[],
			[],
			0,
			0,
			str(locked.get("public_target_region_id", ""))
		)
	var current_region_id := str(current.get("region_id", ""))
	var damage_intent := CombatDamageCore.build_monster_damage_intent(
		str(locked.get("source_effect_id", "")),
		target_id,
		int(locked.get("target_source_generation", 0)),
		int(current.get("source_revision", 0)),
		int(locked.get("monster_damage", 0)),
		current_region_id,
		_combat_receipt_id(locked)
	)
	if damage_intent.is_empty():
		return _build_receipt(
			locked,
			"fizzled",
			"monster_damage_intent_build_failed",
			[],
			[],
			0,
			0,
			current_region_id
		)
	return _build_receipt(
		locked,
		"resolved",
		"military_monster_assault_resolved",
		[],
		[damage_intent],
		int(locked.get("monster_damage", 0)),
		1,
		current_region_id
	)


static func receipt_validation_report(value: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not (value is Dictionary) or not _closed_data(value):
		errors.append("military_mission_receipt_not_closed_data")
		return _report(errors, "military_mission_receipt_valid")
	var receipt := value as Dictionary
	if not _exact_fields(receipt, RECEIPT_FIELDS):
		errors.append("military_mission_receipt_fields_invalid")
		return _report(errors, "military_mission_receipt_valid")
	if int(receipt.get("schema_version", -1)) != SCHEMA_VERSION 			or str(receipt.get("contract_id", "")) 			!= RECEIPT_CONTRACT_ID 			or str(receipt.get("ruleset_id", "")) != RULESET_ID:
		errors.append("military_mission_receipt_header_invalid")
	for field in [
		"combat_receipt_id",
		"mission_id",
		"owner_player_id",
		"card_instance_id",
		"reason_code",
	]:
		if not _stable_id(receipt.get(field)):
			errors.append("military_mission_receipt_%s_invalid" % field)
	if str(receipt.get("task_kind", "")) not in TASK_KINDS 			or str(receipt.get("outcome", "")) not in [
				"resolved", "fizzled"
			] 			or str(receipt.get("mission_state_after", "")) 			!= "withdrawn":
		errors.append("military_mission_receipt_state_invalid")
	for field in [
		"allocated_damage_total",
		"locked_target_count",
		"resolved_target_count",
		"retarget_count",
		"persistent_source_count",
		"bound_action_count",
		"direct_facility_write_count",
		"direct_dbg_write_count",
	]:
		if not _nonnegative_integer(receipt.get(field)):
			errors.append("military_mission_receipt_%s_invalid" % field)
	if int(receipt.get("retarget_count", -1)) != 0 			or int(receipt.get("persistent_source_count", -1)) != 0 			or int(receipt.get("bound_action_count", -1)) != 0 			or int(receipt.get("direct_facility_write_count", -1)) != 0 			or int(receipt.get("direct_dbg_write_count", -1)) != 0:
		errors.append("military_mission_receipt_forbidden_side_effect")
	for intent_variant in receipt.get("facility_damage_intents", []) as Array:
		if not bool(
			FacilityDamageIntent.validation_report(intent_variant).get(
				"valid", false
			)
		):
			errors.append("military_mission_receipt_facility_intent_invalid")
	for intent_variant in receipt.get("monster_damage_intents", []) as Array:
		if not bool(
			CombatDamageCore.monster_damage_validation_report(
				intent_variant
			).get("valid", false)
		):
			errors.append("military_mission_receipt_monster_intent_invalid")
	if not bool(
		lifecycle_intents_validation_report(receipt).get("valid", false)
	):
		errors.append("military_mission_receipt_lifecycle_invalid")
	var fingerprint := str(receipt.get("receipt_fingerprint", ""))
	if not _fingerprint_valid(fingerprint) 			or fingerprint != _fingerprint_without(
				receipt, "receipt_fingerprint"
			):
		errors.append("military_mission_receipt_fingerprint_invalid")
	return _report(errors, "military_mission_receipt_valid")


static func lifecycle_intents_validation_report(
	receipt: Dictionary
) -> Dictionary:
	var errors: Array[String] = []
	var withdrawal := receipt.get(
		"military_withdrawal_intent", {}
	) as Dictionary
	var dbg := receipt.get("dbg_lifecycle_intent", {}) as Dictionary
	var asset := receipt.get("asset_settlement_intent", {}) as Dictionary
	if str(withdrawal.get("contract_id", "")) 		!= WITHDRAWAL_CONTRACT_ID 			or str(withdrawal.get("mission_id", "")) 			!= str(receipt.get("mission_id", "")) 			or str(withdrawal.get("state_after", "")) != "withdrawn" 			or bool(withdrawal.get("persistent_source_created", true)) 			or bool(withdrawal.get("bound_action_created", true)):
		errors.append("military_withdrawal_intent_invalid")
	if str(dbg.get("contract_id", "")) != DBG_LIFECYCLE_CONTRACT_ID 			or str(dbg.get("intent_kind", "")) 			!= "complete_mission_to_personal_discard" 			or str(dbg.get("expected_zone", "")) 			!= "military_mission_resolving" 			or str(dbg.get("destination_zone", "")) 			!= "personal_discard" 			or not bool(dbg.get("normal_dbg_member", false)) 			or not bool(dbg.get("reshuffle_eligible", false)) 			or bool(dbg.get("direct_mutation_allowed", true)):
		errors.append("military_dbg_lifecycle_intent_invalid")
	if str(asset.get("contract_id", "")) 		!= ASSET_SETTLEMENT_CONTRACT_ID 			or str(asset.get("policy_id", "")) not in [
				"existing_normal_action_success",
				"existing_normal_action_fizzle",
			] 			or bool(asset.get("action_slot_refunded", true)) 			or bool(asset.get("direct_mutation_allowed", true)):
		errors.append("military_asset_settlement_intent_invalid")
	return _report(errors, "military_lifecycle_intents_valid")


static func contract_report() -> Dictionary:
	return {
		"ruleset_id": RULESET_ID,
		"military_task_kinds": TASK_KINDS.duplicate(),
		"military_task_button_count": 2,
		"military_guard_task_count": 0,
		"military_bound_action_count": 0,
		"military_persistent_source_count": 0,
		"military_card_normal_dbg_member": true,
		"military_card_lifecycle": [
			"normal_hand",
			"committed_escrow",
			"military_mission_resolving",
			"withdrawn",
			"personal_discard",
			"normal_reshuffle",
			"future_draw",
		],
		"post_resolution_intent_order": [
			"military_withdrawal",
			"personal_discard",
		],
		"military_card_destination_after_mission": "personal_discard",
		"military_card_reshuffle_eligible": true,
		"target_reselection_allowed": false,
		"region_damage_distribution": "stable_round_robin_total_budget",
		"facility_damage_typed_port": true,
		"direct_facility_write_count": 0,
		"direct_dbg_write_count": 0,
	}

static func _build_request(
	request_id: String,
	mission_id: String,
	task_kind: String,
	owner_player_id: String,
	card_instance_id: String,
	action_slot_id: String,
	asset_reservation_id: String,
	target_region_id: String,
	target_monster_source_instance_id: String
) -> Dictionary:
	var request := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": REQUEST_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"request_id": request_id,
		"mission_id": mission_id,
		"task_kind": task_kind,
		"owner_player_id": owner_player_id,
		"card_instance_id": card_instance_id,
		"action_slot_id": action_slot_id,
		"asset_reservation_id": asset_reservation_id,
		"target_region_id": target_region_id,
		"target_monster_source_instance_id": (
			target_monster_source_instance_id
		),
		"request_fingerprint": "",
	}
	request["request_fingerprint"] = _fingerprint_without(
		request, "request_fingerprint"
	)
	return request 		if bool(request_validation_report(request).get("valid", false)) 		else {}


static func _build_lock(
	request: Dictionary,
	card_authority: Dictionary,
	target_region_revision: int,
	locked_facilities: Array,
	target_monster: Dictionary
) -> Dictionary:
	var task_kind := str(request.get("task_kind", ""))
	var is_region := task_kind == TASK_ASSAULT_REGION
	var locked := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": LOCK_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"request_id": str(request.get("request_id", "")),
		"mission_id": str(request.get("mission_id", "")),
		"task_kind": task_kind,
		"owner_player_id": str(request.get("owner_player_id", "")),
		"card_instance_id": str(request.get("card_instance_id", "")),
		"card_definition_id": str(
			card_authority.get("card_definition_id", "")
		),
		"card_rank": int(card_authority.get("card_rank", 0)),
		"action_slot_id": str(request.get("action_slot_id", "")),
		"asset_reservation_id": str(
			request.get("asset_reservation_id", "")
		),
		"committed_escrow_revision": int(
			card_authority.get("committed_escrow_revision", 0)
		),
		"source_effect_id": str(
			card_authority.get("source_effect_id", "")
		),
		"target_region_id": (
			str(request.get("target_region_id", "")) if is_region else ""
		),
		"target_region_revision": (
			target_region_revision if is_region else -1
		),
		"locked_facility_targets": (
			locked_facilities.duplicate(true) if is_region else []
		),
		"target_monster_source_instance_id": (
			""
			if is_region
			else str(target_monster.get("source_instance_id", ""))
		),
		"target_source_generation": (
			0
			if is_region
			else int(target_monster.get("source_generation", 0))
		),
		"target_monster_revision": (
			-1
			if is_region
			else int(target_monster.get("source_revision", -1))
		),
		"target_monster_owner_player_id": (
			""
			if is_region
			else str(target_monster.get("owner_player_id", ""))
		),
		"public_target_region_id": (
			""
			if is_region
			else str(target_monster.get("region_id", ""))
		),
		"region_strike_damage_budget": (
			int(card_authority.get("region_damage_budget", 0))
			if is_region
			else 0
		),
		"monster_damage": (
			0
			if is_region
			else int(card_authority.get("monster_damage", 0))
		),
		"mission_state": "locked",
		"target_reselection_allowed": false,
		"persistent_source_created": false,
		"bound_action_created": false,
		"lock_fingerprint": "",
	}
	locked["lock_fingerprint"] = _fingerprint_without(
		locked, "lock_fingerprint"
	)
	return locked 		if bool(mission_lock_validation_report(locked).get("valid", false)) 		else _lock_failure("military_mission_lock_build_failed")


static func _build_receipt(
	locked: Dictionary,
	outcome: String,
	reason_code: String,
	facility_damage_intents: Array,
	monster_damage_intents: Array,
	allocated_damage_total: int,
	resolved_target_count: int,
	public_target_region_id: String
) -> Dictionary:
	var combat_receipt_id := _combat_receipt_id(locked)
	var withdrawal := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": WITHDRAWAL_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"mission_id": str(locked.get("mission_id", "")),
		"owner_player_id": str(locked.get("owner_player_id", "")),
		"card_instance_id": str(locked.get("card_instance_id", "")),
		"task_kind": str(locked.get("task_kind", "")),
		"state_before": "military_mission_resolving",
		"state_after": "withdrawn",
		"reason_code": reason_code,
		"combat_receipt_id": combat_receipt_id,
		"persistent_source_created": false,
		"bound_action_created": false,
	}
	var dbg_lifecycle := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": DBG_LIFECYCLE_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"intent_kind": "complete_mission_to_personal_discard",
		"owner_player_id": str(locked.get("owner_player_id", "")),
		"card_instance_id": str(locked.get("card_instance_id", "")),
		"expected_zone": "military_mission_resolving",
		"destination_zone": "personal_discard",
		"normal_dbg_member": true,
		"reshuffle_eligible": true,
		"combat_receipt_id": combat_receipt_id,
		"direct_mutation_allowed": false,
	}
	var asset_settlement := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": ASSET_SETTLEMENT_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"reservation_id": str(
			locked.get("asset_reservation_id", "")
		),
		"policy_id": (
			"existing_normal_action_success"
			if outcome == "resolved"
			else "existing_normal_action_fizzle"
		),
		"action_slot_id": str(locked.get("action_slot_id", "")),
		"action_slot_refunded": false,
		"combat_receipt_id": combat_receipt_id,
		"direct_mutation_allowed": false,
	}
	var locked_target_count := (
		(locked.get("locked_facility_targets", []) as Array).size()
		if str(locked.get("task_kind", "")) == TASK_ASSAULT_REGION
		else 1
	)
	var receipt := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": RECEIPT_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"combat_receipt_id": combat_receipt_id,
		"mission_id": str(locked.get("mission_id", "")),
		"task_kind": str(locked.get("task_kind", "")),
		"owner_player_id": str(locked.get("owner_player_id", "")),
		"card_instance_id": str(locked.get("card_instance_id", "")),
		"outcome": outcome,
		"reason_code": reason_code,
		"target_region_id": str(locked.get("target_region_id", "")),
		"public_target_region_id": public_target_region_id,
		"facility_damage_intents": facility_damage_intents.duplicate(true),
		"monster_damage_intents": monster_damage_intents.duplicate(true),
		"military_withdrawal_intent": withdrawal,
		"dbg_lifecycle_intent": dbg_lifecycle,
		"asset_settlement_intent": asset_settlement,
		"allocated_damage_total": allocated_damage_total,
		"locked_target_count": locked_target_count,
		"resolved_target_count": resolved_target_count,
		"retarget_count": 0,
		"persistent_source_count": 0,
		"bound_action_count": 0,
		"direct_facility_write_count": 0,
		"direct_dbg_write_count": 0,
		"mission_state_after": "withdrawn",
		"receipt_fingerprint": "",
	}
	receipt["receipt_fingerprint"] = _fingerprint_without(
		receipt, "receipt_fingerprint"
	)
	return receipt 		if bool(receipt_validation_report(receipt).get("valid", false)) 		else _resolution_failure("military_mission_receipt_build_failed")


static func _public_facility_view(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source := value as Dictionary
	if source.has("occupancy") and str(source.get(
		"occupancy",
		""
	)) != "occupied":
		return {}
	var facility_id := str(source.get("facility_id", ""))
	var generation_value: Variant = source.get(
		"facility_generation",
		source.get("generation", 0)
	)
	if not _positive_integer(generation_value):
		return {}
	var generation := int(generation_value)
	var owner_player_id := str(source.get(
		"owner_player_id",
		source.get("owner_id", "")
	))
	var region_id := str(source.get("region_id", ""))
	var facility_type := str(source.get("facility_type", ""))
	var industry_id := str(source.get("industry_id", ""))
	var status := str(source.get("status", "active"))
	if bool(source.get("destroyed", false)):
		status = "destroyed"
	if not _stable_id(facility_id) 			or not _positive_integer(generation) 			or not _stable_id(owner_player_id) 			or not _stable_id(region_id) 			or facility_type not in FACILITY_TYPES 			or not _stable_id(industry_id):
		return {}
	return {
		"facility_id": facility_id,
		"facility_generation": generation,
		"owner_player_id": owner_player_id,
		"region_id": region_id,
		"facility_type": facility_type,
		"industry_id": industry_id,
		"status": status,
	}


static func _public_monster_view(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var source := value as Dictionary
	var source_instance_id := str(source.get("source_instance_id", ""))
	var source_generation := int(source.get("source_generation", 0))
	var source_revision := int(source.get(
		"source_revision",
		source.get(
			"damage_revision",
			source.get("revision", -1)
		)
	))
	var owner_player_id := str(source.get("owner_player_id", ""))
	var region_id := str(source.get("region_id", ""))
	var status := str(source.get("status", ""))
	if not _stable_id(source_instance_id) 			or not _positive_integer(source_generation) 			or not _nonnegative_integer(source_revision) 			or not _stable_id(owner_player_id) 			or not _stable_id(region_id) 			or status not in [
				"active", "downed", "destroyed", "withdrawn"
			]:
		return {}
	return {
		"source_instance_id": source_instance_id,
		"source_generation": source_generation,
		"source_revision": source_revision,
		"owner_player_id": owner_player_id,
		"region_id": region_id,
		"status": status,
	}


static func _locked_facility_valid(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var target := value as Dictionary
	return _exact_fields(target, LOCKED_FACILITY_FIELDS) 		and _stable_id(target.get("target_facility_id")) 		and _positive_integer(target.get("expected_generation")) 		and _stable_id(target.get("expected_owner_player_id")) 		and str(target.get("facility_type", "")) in FACILITY_TYPES 		and _stable_id(target.get("industry_id"))


static func _facility_status_legal(status: String) -> bool:
	return status not in ["destroyed", "withdrawn", "ruined"]


static func _sort_locked_facility(left: Variant, right: Variant) -> bool:
	return str((left as Dictionary).get("target_facility_id", "")) 		< str((right as Dictionary).get("target_facility_id", ""))


static func _combat_receipt_id(locked: Dictionary) -> String:
	return "combat.%s.resolution" % str(locked.get("mission_id", ""))


static func _lock_failure(reason_code: String) -> Dictionary:
	return {
		"accepted": false,
		"contract_id": LOCK_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"reason_code": reason_code,
	}


static func _resolution_failure(reason_code: String) -> Dictionary:
	return {
		"accepted": false,
		"contract_id": RECEIPT_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"reason_code": reason_code,
	}


static func _report(
	errors: Array[String], success_reason: String
) -> Dictionary:
	return {
		"valid": errors.is_empty(),
		"error_count": errors.size(),
		"errors": errors.duplicate(),
		"reason_code": success_reason if errors.is_empty() else errors[0],
	}


static func _exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


static func _stable_id(value: Variant) -> bool:
	if not (value is String or value is StringName):
		return false
	var text := str(value)
	if text.is_empty() or text.length() > 160 or text.strip_edges() != text:
		return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		var allowed := (code >= 48 and code <= 57) 			or (code >= 65 and code <= 90) 			or (code >= 97 and code <= 122) 			or code in [45, 46, 58, 95]
		if not allowed:
			return false
	return true


static func _positive_integer(value: Variant) -> bool:
	return value is int and int(value) > 0


static func _nonnegative_integer(value: Variant) -> bool:
	return value is int and int(value) >= 0


static func _fingerprint_valid(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true


static func _fingerprint_without(
	value: Dictionary, excluded_field: String
) -> String:
	var copy := value.duplicate(true)
	copy.erase(excluded_field)
	return _canonical(copy).sha256_text()


static func _canonical(value: Variant) -> String:
	if value == null:
		return "null"
	if value is bool:
		return "true" if bool(value) else "false"
	if value is int:
		return str(value)
	if value is float:
		return str(float(value))
	if value is String or value is StringName:
		return JSON.stringify(str(value))
	if value is Array:
		var rows: Array[String] = []
		for item_variant in value as Array:
			rows.append(_canonical(item_variant))
		return "[%s]" % ",".join(rows)
	if value is Dictionary:
		var keys: Array[String] = []
		for key_variant in (value as Dictionary).keys():
			keys.append(str(key_variant))
		keys.sort()
		var pairs: Array[String] = []
		for key in keys:
			pairs.append(
				"%s:%s" % [
					JSON.stringify(key),
					_canonical((value as Dictionary).get(key)),
				]
			)
		return "{%s}" % ",".join(pairs)
	return "<invalid>"


static func _closed_data(value: Variant, depth: int = 0) -> bool:
	if depth > 48:
		return false
	if value == null or value is bool or value is int 			or value is String or value is StringName:
		return true
	if value is float:
		return is_finite(float(value))
	if value is Array:
		for item_variant in value as Array:
			if not _closed_data(item_variant, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if not (key_variant is String or key_variant is StringName):
				return false
			if not _closed_data(
				(value as Dictionary).get(key_variant), depth + 1
			):
				return false
		return true
	return false
