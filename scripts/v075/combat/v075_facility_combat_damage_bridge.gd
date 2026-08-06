extends RefCounted
class_name V075FacilityCombatDamageBridge

const DamageIntent := preload(
	"res://scripts/v075/combat/facility_combat_damage_intent_v1.gd"
)
const FacilityCore := preload(
	"res://scripts/v074/facility/v074_facility_runtime_core.gd"
)

const SCHEMA_VERSION := 1
const RULESET_ID := "v0.7.5"
const STATE_CONTRACT_ID := "V075FacilityCombatDamageBridgeStateV1"
const RECEIPT_CONTRACT_ID := "V075FacilityCombatDamageBridgeReceiptV1"
const FACILITY_TYPES := ["factory", "market", "warehouse"]
const FACILITY_MAX_HP_BY_RANK := {
	1: 4,
	2: 8,
	3: 12,
	4: 16,
}
const MAX_SAFE_INTEGER := 9007199254740991

const STATE_FIELDS := [
	"schema_version",
	"contract_id",
	"ruleset_id",
	"bridge_revision",
	"facility_state",
	"facility_slots",
	"processed_intent_fingerprints",
	"effect_bindings",
	"receipt_journal",
	"combat_direct_facility_write_count",
	"gameplay_owner_count",
	"state_fingerprint",
]
const RECEIPT_FIELDS := [
	"schema_version",
	"contract_id",
	"ruleset_id",
	"receipt_id",
	"accepted",
	"reason_code",
	"intent_fingerprint",
	"source_effect_id",
	"combat_receipt_id",
	"damage_kind",
	"target_facility_id",
	"facility_type",
	"industry_id",
	"region_id",
	"expected_generation",
	"facility_generation_before",
	"facility_generation_after",
	"requested_damage",
	"applied_damage",
	"damage_points_before",
	"damage_points_after",
	"facility_max_hp",
	"facility_destroyed",
	"damage_revision_before",
	"damage_revision_after",
	"slot_generation_before",
	"slot_generation_after",
	"region_revision_before",
	"region_revision_after",
	"bridge_revision_before",
	"bridge_revision_after",
	"facility_state_fingerprint_before",
	"facility_state_fingerprint_after",
	"facility_slots_fingerprint_before",
	"facility_slots_fingerprint_after",
	"effect_application_count",
	"combat_direct_facility_write_count",
	"warehouse_private_stock_disclosure_count",
	"receipt_fingerprint",
]
const FORBIDDEN_PRIVATE_FIELDS := [
	"warehouse_stock",
	"private_stock",
	"inventory",
	"inventory_items",
	"private_logistics",
	"logistics_plan",
	"future_production",
	"owner_assets",
]


static func create_state(facility_state: Dictionary) -> Dictionary:
	if not bool(
		FacilityCore.validation_report(facility_state).get("valid", false)
	):
		return {}
	if str(facility_state.get("status", "")) != "resolved":
		return {}
	var slots := _sorted_facility_slots(facility_state)
	if _contains_private_field(slots):
		return {}
	var state := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": STATE_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"bridge_revision": 0,
		"facility_state": facility_state.duplicate(true),
		"facility_slots": slots,
		"processed_intent_fingerprints": [],
		"effect_bindings": {},
		"receipt_journal": {},
		"combat_direct_facility_write_count": 0,
		"gameplay_owner_count": 0,
		"state_fingerprint": "",
	}
	state["state_fingerprint"] = _fingerprint_without(
		state,
		"state_fingerprint"
	)
	return state if bool(validation_report(state).get("valid", false)) else {}


static func rebase_state(
	state: Dictionary,
	facility_state: Dictionary
) -> Dictionary:
	if not bool(validation_report(state).get("valid", false)):
		return {}
	if not bool(
		FacilityCore.validation_report(facility_state).get("valid", false)
	):
		return {}
	if str(facility_state.get("status", "")) != "resolved":
		return {}
	var slots := _sorted_facility_slots(facility_state)
	if _contains_private_field(slots):
		return {}
	if (
		facility_state == state.get("facility_state", {})
		and slots == state.get("facility_slots", [])
	):
		return state.duplicate(true)
	var next := state.duplicate(true)
	next["facility_state"] = facility_state.duplicate(true)
	next["facility_slots"] = slots
	next.erase("state_fingerprint")
	next["state_fingerprint"] = _fingerprint_without(
		next,
		"state_fingerprint"
	)
	return next if bool(validation_report(next).get("valid", false)) else {}


static func apply_intent(
	state: Dictionary,
	intent: Dictionary
) -> Dictionary:
	var state_error := _state_error(state)
	if not state_error.is_empty():
		return _failure_result(
			state,
			intent,
			"facility_combat_bridge_state_invalid",
			{}
		)
	var intent_report := DamageIntent.validation_report(intent)
	if not bool(intent_report.get("valid", false)):
		return _failure_result(
			state,
			intent,
			str(intent_report.get(
				"reason_code",
				"facility_combat_damage_intent_invalid"
			)),
			{}
		)

	var intent_fingerprint := str(intent.get("intent_fingerprint", ""))
	var journal := state.get("receipt_journal", {}) as Dictionary
	if journal.has(intent_fingerprint):
		var saved_receipt := (
			journal.get(intent_fingerprint, {}) as Dictionary
		).duplicate(true)
		return _result(
			true,
			true,
			"facility_combat_damage_exact_once_replay",
			state,
			saved_receipt
		)

	var effect_key := _effect_key(intent)
	var bindings := state.get("effect_bindings", {}) as Dictionary
	if (
		bindings.has(effect_key)
		and str(bindings.get(effect_key, "")) != intent_fingerprint
	):
		return _failure_result(
			state,
			intent,
			"facility_combat_damage_effect_collision",
			{}
		)

	var slot := _slot_by_facility_id(
		state.get("facility_slots", []) as Array,
		str(intent.get("target_facility_id", ""))
	)
	if slot.is_empty():
		return _failure_result(
			state,
			intent,
			"facility_combat_damage_target_missing",
			{}
		)
	if str(slot.get("occupancy", "")) != "occupied":
		return _failure_result(
			state,
			intent,
			"facility_combat_damage_target_not_occupied",
			slot
		)
	if str(slot.get("facility_type", "")) not in FACILITY_TYPES:
		return _failure_result(
			state,
			intent,
			"facility_combat_damage_target_type_invalid",
			slot
		)
	if (
		int(slot.get("facility_generation", -1))
		!= int(intent.get("expected_generation", -2))
	):
		return _failure_result(
			state,
			intent,
			"facility_combat_damage_generation_stale",
			slot
		)
	if not _damage_sum_safe(
		int(slot.get("damage_points", 0)),
		int(intent.get("damage_amount", 0))
	):
		return _failure_result(
			state,
			intent,
			"facility_combat_damage_overflow",
			slot
		)

	var transition := _build_v074_transition(state, intent, slot)
	if transition.is_empty():
		return _failure_result(
			state,
			intent,
			"facility_combat_damage_v074_transition_failed",
			slot
		)
	var next_facility_state := (
		transition.get("facility_state", {}) as Dictionary
	)
	var next_slots := transition.get("facility_slots", []) as Array
	var next_slot := transition.get("target_slot", {}) as Dictionary
	var receipt := _build_receipt(
		state,
		intent,
		slot,
		next_slot,
		next_facility_state,
		next_slots,
		true,
		"facility_combat_damage_applied"
	)
	if not bool(receipt_validation_report(receipt).get("valid", false)):
		return _failure_result(
			state,
			intent,
			"facility_combat_damage_receipt_invalid",
			slot
		)

	var next := state.duplicate(true)
	next["bridge_revision"] = int(state.get("bridge_revision", 0)) + 1
	next["facility_state"] = next_facility_state.duplicate(true)
	next["facility_slots"] = next_slots.duplicate(true)
	var processed := (
		state.get("processed_intent_fingerprints", []) as Array
	).duplicate()
	processed.append(intent_fingerprint)
	next["processed_intent_fingerprints"] = processed
	var next_bindings := (
		state.get("effect_bindings", {}) as Dictionary
	).duplicate(true)
	next_bindings[effect_key] = intent_fingerprint
	next["effect_bindings"] = next_bindings
	var next_journal := journal.duplicate(true)
	next_journal[intent_fingerprint] = receipt.duplicate(true)
	next["receipt_journal"] = next_journal
	next["combat_direct_facility_write_count"] = 0
	next["gameplay_owner_count"] = 0
	next.erase("state_fingerprint")
	next["state_fingerprint"] = _fingerprint_without(
		next,
		"state_fingerprint"
	)
	if not bool(validation_report(next).get("valid", false)):
		return _failure_result(
			state,
			intent,
			"facility_combat_damage_postcondition_invalid",
			slot
		)
	return _result(
		true,
		false,
		"facility_combat_damage_applied",
		next,
		receipt
	)


static func validation_report(value: Variant) -> Dictionary:
	var reason_code := _state_error(value)
	return {
		"valid": reason_code.is_empty(),
		"error_count": 0 if reason_code.is_empty() else 1,
		"errors": [] if reason_code.is_empty() else [reason_code],
		"reason_code": (
			"facility_combat_damage_bridge_state_valid"
			if reason_code.is_empty()
			else reason_code
		),
	}


static func receipt_validation_report(value: Variant) -> Dictionary:
	var reason_code := _receipt_error(value)
	return {
		"valid": reason_code.is_empty(),
		"error_count": 0 if reason_code.is_empty() else 1,
		"errors": [] if reason_code.is_empty() else [reason_code],
		"reason_code": (
			"facility_combat_damage_bridge_receipt_valid"
			if reason_code.is_empty()
			else reason_code
		),
	}


static func contract_report() -> Dictionary:
	return {
		"ruleset_id": RULESET_ID,
		"state_contract_id": STATE_CONTRACT_ID,
		"receipt_contract_id": RECEIPT_CONTRACT_ID,
		"facility_types": FACILITY_TYPES.duplicate(),
		"facility_max_hp_by_rank": FACILITY_MAX_HP_BY_RANK.duplicate(true),
		"typed_intent_contract_id": DamageIntent.CONTRACT_ID,
		"v074_direct_facility_damage_method_count": 0,
		"v074_legal_transition_api": [
			"build_occupied_slot",
			"slot_validation_report",
			"lock_batch",
		],
		"resolved_safe_boundary_required": true,
		"generation_lock_required": true,
		"exact_once_journal": true,
		"rebase_preserves_exact_once_journal": true,
		"legacy_region_hp_damage_bridge_connected": false,
		"combat_direct_facility_write_count": 0,
		"warehouse_private_stock_reader_count": 0,
		"warehouse_private_stock_disclosure_count": 0,
		"gameplay_owner_count": 0,
		"rng_owner_count": 0,
	}


static func _build_v074_transition(
	state: Dictionary,
	intent: Dictionary,
	slot: Dictionary
) -> Dictionary:
	var solar_state := str(slot.get("solar_efficiency_state", "dark"))
	if solar_state not in ["dark", "sunlit"]:
		solar_state = "dark"
	var rank := int(slot.get("rank", 0))
	var max_hp := int(FACILITY_MAX_HP_BY_RANK.get(rank, 0))
	if max_hp <= 0:
		return {}
	var damage_after := (
		int(slot.get("damage_points", 0))
		+ int(intent.get("damage_amount", 0))
	)
	var destroyed := damage_after >= max_hp
	var updated_slot := (
		FacilityCore.build_empty_slot(
			str(slot.get("region_id", "")),
			int(slot.get("region_revision", 0)) + 1,
			str(slot.get("facility_type", "")),
			str(slot.get("industry_id", "")),
			int(slot.get("slot_generation", 0)) + 1
		)
		if destroyed
		else FacilityCore.build_occupied_slot(
			str(slot.get("region_id", "")),
			int(slot.get("region_revision", 0)) + 1,
			str(slot.get("facility_type", "")),
			str(slot.get("industry_id", "")),
			int(slot.get("slot_generation", 0)) + 1,
			str(slot.get("facility_id", "")),
			int(slot.get("facility_generation", 0)),
			str(slot.get("owner_id", "")),
			rank,
			int(slot.get("damage_revision", 0)) + 1,
			damage_after,
			solar_state
		)
	)
	if updated_slot.is_empty():
		return {}
	if not bool(
		FacilityCore.slot_validation_report(updated_slot).get(
			"valid",
			false
		)
	):
		return {}

	var updated_slots := (
		state.get("facility_slots", []) as Array
	).duplicate(true)
	var replaced := false
	for index in range(updated_slots.size()):
		var candidate := updated_slots[index] as Dictionary
		if (
			str(candidate.get("facility_id", ""))
			== str(slot.get("facility_id", ""))
		):
			updated_slots[index] = updated_slot.duplicate(true)
			replaced = true
			break
	if not replaced:
		return {}
	updated_slots = _sort_slots(updated_slots)

	var current_facility_state := (
		state.get("facility_state", {}) as Dictionary
	)
	if str(current_facility_state.get("status", "")) != "resolved":
		return {}
	var players := (
		current_facility_state.get("player_ids", []) as Array
	).duplicate()
	var hidden_order := (
		current_facility_state.get(
			"frozen_hidden_lead_order_at_batch_lock",
			[]
		) as Array
	).duplicate()
	var empty_queues := {}
	for player_id_variant in players:
		empty_queues[str(player_id_variant)] = []
	var next_facility_state := FacilityCore.lock_batch(
		"batch.facility.combat.%s" % str(
			intent.get("intent_fingerprint", "")
		).left(24),
		players,
		hidden_order,
		empty_queues,
		updated_slots,
		bool(current_facility_state.get(
			"production_runtime_connected",
			false
		))
	)
	if not bool(
		FacilityCore.validation_report(next_facility_state).get(
			"valid",
			false
		)
	):
		return {}
	if str(next_facility_state.get("status", "")) != "resolved":
		return {}
	var canonical_slots := _sorted_facility_slots(next_facility_state)
	if canonical_slots != updated_slots:
		return {}
	return {
		"facility_state": next_facility_state,
		"facility_slots": canonical_slots,
		"target_slot": updated_slot,
	}


static func _build_receipt(
	state: Dictionary,
	intent: Dictionary,
	slot_before: Dictionary,
	slot_after: Dictionary,
	facility_state_after: Dictionary,
	facility_slots_after: Array,
	accepted: bool,
	reason_code: String
) -> Dictionary:
	var facility_state_before := (
		state.get("facility_state", {}) as Dictionary
	)
	var facility_slots_before := (
		state.get("facility_slots", []) as Array
	)
	var intent_fingerprint := _intent_fingerprint(intent)
	var applied_damage := (
		int(intent.get("damage_amount", 0)) if accepted else 0
	)
	var facility_max_hp := int(FACILITY_MAX_HP_BY_RANK.get(
		int(slot_before.get("rank", 0)),
		0
	))
	var damage_points_before := maxi(
		0,
		int(slot_before.get("damage_points", 0))
	)
	var damage_points_after := (
		mini(damage_points_before + applied_damage, facility_max_hp)
		if accepted and facility_max_hp > 0
		else damage_points_before
	)
	var facility_destroyed := (
		accepted
		and facility_max_hp > 0
		and damage_points_before + applied_damage >= facility_max_hp
	)
	var receipt := {
		"schema_version": SCHEMA_VERSION,
		"contract_id": RECEIPT_CONTRACT_ID,
		"ruleset_id": RULESET_ID,
		"receipt_id": "receipt.facility.combat.%s" % intent_fingerprint.left(24),
		"accepted": accepted,
		"reason_code": reason_code,
		"intent_fingerprint": intent_fingerprint,
		"source_effect_id": _safe_id(
			intent.get("source_effect_id"),
			"effect.invalid"
		),
		"combat_receipt_id": _safe_id(
			intent.get("combat_receipt_id"),
			"combat.receipt.invalid"
		),
		"damage_kind": _safe_id(
			intent.get("damage_kind"),
			"damage.invalid"
		),
		"target_facility_id": _safe_id(
			intent.get("target_facility_id"),
			"facility.invalid"
		),
		"facility_type": _safe_id(
			slot_before.get("facility_type"),
			"unknown"
		),
		"industry_id": _safe_id(
			slot_before.get("industry_id"),
			"unknown"
		),
		"region_id": _safe_id(
			slot_before.get("region_id"),
			"unknown"
		),
		"expected_generation": maxi(
			0,
			int(intent.get("expected_generation", 0))
		),
		"facility_generation_before": maxi(
			0,
			int(slot_before.get("facility_generation", 0))
		),
		"facility_generation_after": maxi(
			0,
			_int_or_fallback(
				slot_after.get("facility_generation"),
				int(slot_before.get("facility_generation", 0))
			)
		),
		"requested_damage": maxi(
			0,
			int(intent.get("damage_amount", 0))
		),
		"applied_damage": applied_damage,
		"damage_points_before": damage_points_before,
		"damage_points_after": damage_points_after,
		"facility_max_hp": facility_max_hp,
		"facility_destroyed": facility_destroyed,
		"damage_revision_before": maxi(
			0,
			int(slot_before.get("damage_revision", 0))
		),
		"damage_revision_after": (
			maxi(0, int(slot_before.get("damage_revision", 0))) + 1
			if accepted
			else maxi(0, int(slot_before.get("damage_revision", 0)))
		),
		"slot_generation_before": maxi(
			0,
			int(slot_before.get("slot_generation", 0))
		),
		"slot_generation_after": maxi(
			0,
			int(slot_after.get(
				"slot_generation",
				slot_before.get("slot_generation", 0)
			))
		),
		"region_revision_before": maxi(
			0,
			int(slot_before.get("region_revision", 0))
		),
		"region_revision_after": maxi(
			0,
			int(slot_after.get(
				"region_revision",
				slot_before.get("region_revision", 0)
			))
		),
		"bridge_revision_before": maxi(
			0,
			int(state.get("bridge_revision", 0))
		),
		"bridge_revision_after": (
			maxi(0, int(state.get("bridge_revision", 0))) + 1
			if accepted
			else maxi(0, int(state.get("bridge_revision", 0)))
		),
		"facility_state_fingerprint_before": _fingerprint_or_fallback(
			facility_state_before.get("state_fingerprint"),
			facility_state_before
		),
		"facility_state_fingerprint_after": _fingerprint_or_fallback(
			facility_state_after.get("state_fingerprint"),
			facility_state_after
		),
		"facility_slots_fingerprint_before": _fingerprint(
			facility_slots_before
		),
		"facility_slots_fingerprint_after": _fingerprint(
			facility_slots_after
		),
		"effect_application_count": 1 if accepted else 0,
		"combat_direct_facility_write_count": 0,
		"warehouse_private_stock_disclosure_count": 0,
		"receipt_fingerprint": "",
	}
	receipt["receipt_fingerprint"] = _fingerprint_without(
		receipt,
		"receipt_fingerprint"
	)
	return receipt


static func _failure_result(
	state: Dictionary,
	intent: Dictionary,
	reason_code: String,
	slot: Dictionary
) -> Dictionary:
	var safe_state := state.duplicate(true)
	var facility_state := (
		safe_state.get("facility_state", {}) as Dictionary
	)
	var facility_slots := (
		safe_state.get("facility_slots", []) as Array
	)
	var receipt := _build_receipt(
		safe_state,
		intent,
		slot,
		slot,
		facility_state,
		facility_slots,
		false,
		reason_code
	)
	return _result(false, false, reason_code, safe_state, receipt)


static func _result(
	accepted: bool,
	duplicate: bool,
	reason_code: String,
	state: Dictionary,
	receipt: Dictionary
) -> Dictionary:
	return {
		"accepted": accepted,
		"duplicate": duplicate,
		"reason_code": reason_code,
		"state": state.duplicate(true),
		"facility_state": (
			state.get("facility_state", {}) as Dictionary
		).duplicate(true),
		"facility_slots": (
			state.get("facility_slots", []) as Array
		).duplicate(true),
		"receipt": receipt.duplicate(true),
		"combat_direct_facility_write_count": 0,
	}


static func _state_error(value: Variant) -> String:
	if not (value is Dictionary) or not _closed_data(value):
		return "facility_combat_bridge_state_not_closed_data"
	var state := value as Dictionary
	if not _exact_fields(state, STATE_FIELDS):
		return "facility_combat_bridge_state_fields_invalid"
	if (
		int(state.get("schema_version", -1)) != SCHEMA_VERSION
		or str(state.get("contract_id", "")) != STATE_CONTRACT_ID
		or str(state.get("ruleset_id", "")) != RULESET_ID
		or not _nonnegative_integer(state.get("bridge_revision"))
		or int(state.get("combat_direct_facility_write_count", -1)) != 0
		or int(state.get("gameplay_owner_count", -1)) != 0
	):
		return "facility_combat_bridge_state_header_invalid"
	var fingerprint := str(state.get("state_fingerprint", ""))
	if (
		not _fingerprint_valid(fingerprint)
		or fingerprint
			!= _fingerprint_without(state, "state_fingerprint")
	):
		return "facility_combat_bridge_state_fingerprint_invalid"
	var facility_state_variant: Variant = state.get("facility_state")
	if not (facility_state_variant is Dictionary):
		return "facility_combat_bridge_facility_state_invalid"
	var facility_state := facility_state_variant as Dictionary
	if not bool(
		FacilityCore.validation_report(facility_state).get("valid", false)
	):
		return "facility_combat_bridge_facility_state_invalid"
	if str(facility_state.get("status", "")) != "resolved":
		return "facility_combat_bridge_not_at_safe_boundary"
	var slots_variant: Variant = state.get("facility_slots")
	if not (slots_variant is Array):
		return "facility_combat_bridge_slots_invalid"
	var slots := slots_variant as Array
	if slots != _sorted_facility_slots(facility_state):
		return "facility_combat_bridge_slot_parity_invalid"
	if _contains_private_field(state):
		return "facility_combat_bridge_private_field_present"
	var processed_variant: Variant = state.get(
		"processed_intent_fingerprints"
	)
	var bindings_variant: Variant = state.get("effect_bindings")
	var journal_variant: Variant = state.get("receipt_journal")
	if (
		not (processed_variant is Array)
		or not (bindings_variant is Dictionary)
		or not (journal_variant is Dictionary)
	):
		return "facility_combat_bridge_journal_invalid"
	var processed: Array[String] = []
	for fingerprint_variant in processed_variant as Array:
		var processed_fingerprint := str(fingerprint_variant)
		if (
			not _fingerprint_valid(processed_fingerprint)
			or processed.has(processed_fingerprint)
		):
			return "facility_combat_bridge_processed_intent_invalid"
		processed.append(processed_fingerprint)
	if int(state.get("bridge_revision", -1)) != processed.size():
		return "facility_combat_bridge_revision_invalid"
	var journal := journal_variant as Dictionary
	if journal.size() != processed.size():
		return "facility_combat_bridge_receipt_journal_invalid"
	for processed_fingerprint in processed:
		if not journal.has(processed_fingerprint):
			return "facility_combat_bridge_receipt_missing"
		var receipt := journal.get(
			processed_fingerprint,
			{}
		) as Dictionary
		if (
			not bool(receipt_validation_report(receipt).get("valid", false))
			or not bool(receipt.get("accepted", false))
			or str(receipt.get("intent_fingerprint", ""))
				!= processed_fingerprint
		):
			return "facility_combat_bridge_receipt_invalid"
	var bindings := bindings_variant as Dictionary
	if bindings.size() != processed.size():
		return "facility_combat_bridge_effect_binding_count_invalid"
	var bound_fingerprints: Array[String] = []
	for effect_key_variant in bindings.keys():
		var effect_key := str(effect_key_variant)
		var bound_fingerprint := str(bindings.get(effect_key_variant, ""))
		if (
			not _fingerprint_valid(effect_key)
			or not processed.has(bound_fingerprint)
			or bound_fingerprints.has(bound_fingerprint)
		):
			return "facility_combat_bridge_effect_binding_invalid"
		bound_fingerprints.append(bound_fingerprint)
	for processed_fingerprint in processed:
		if not bound_fingerprints.has(processed_fingerprint):
			return "facility_combat_bridge_effect_binding_missing"
	return ""


static func _receipt_error(value: Variant) -> String:
	if not (value is Dictionary) or not _closed_data(value):
		return "facility_combat_bridge_receipt_not_closed_data"
	var receipt := value as Dictionary
	if not _exact_fields(receipt, RECEIPT_FIELDS):
		return "facility_combat_bridge_receipt_fields_invalid"
	if (
		int(receipt.get("schema_version", -1)) != SCHEMA_VERSION
		or str(receipt.get("contract_id", "")) != RECEIPT_CONTRACT_ID
		or str(receipt.get("ruleset_id", "")) != RULESET_ID
		or not (receipt.get("accepted") is bool)
		or not _stable_id(receipt.get("receipt_id"))
		or not _stable_id(receipt.get("reason_code"))
		or not _stable_id(receipt.get("source_effect_id"))
		or not _stable_id(receipt.get("combat_receipt_id"))
		or not _stable_id(receipt.get("damage_kind"))
		or not _stable_id(receipt.get("target_facility_id"))
		or not _stable_id(receipt.get("facility_type"))
		or not _stable_id(receipt.get("industry_id"))
		or not _stable_id(receipt.get("region_id"))
	):
		return "facility_combat_bridge_receipt_header_invalid"
	if _contains_private_field(receipt):
		return "facility_combat_bridge_receipt_private_field_present"
	for field_name in [
		"expected_generation",
		"facility_generation_before",
		"facility_generation_after",
		"requested_damage",
		"applied_damage",
		"damage_points_before",
		"damage_points_after",
		"facility_max_hp",
		"damage_revision_before",
		"damage_revision_after",
		"slot_generation_before",
		"slot_generation_after",
		"region_revision_before",
		"region_revision_after",
		"bridge_revision_before",
		"bridge_revision_after",
		"effect_application_count",
		"combat_direct_facility_write_count",
		"warehouse_private_stock_disclosure_count",
	]:
		if not _nonnegative_integer(receipt.get(field_name)):
			return "facility_combat_bridge_receipt_integer_invalid"
	for fingerprint_name in [
		"intent_fingerprint",
		"facility_state_fingerprint_before",
		"facility_state_fingerprint_after",
		"facility_slots_fingerprint_before",
		"facility_slots_fingerprint_after",
		"receipt_fingerprint",
	]:
		if not _fingerprint_valid(str(receipt.get(fingerprint_name, ""))):
			return "facility_combat_bridge_receipt_fingerprint_invalid"
	if (
		int(receipt.get("combat_direct_facility_write_count", -1)) != 0
		or int(
			receipt.get(
				"warehouse_private_stock_disclosure_count",
				-1
			)
		) != 0
	):
		return "facility_combat_bridge_receipt_forbidden_side_effect"
	if not (receipt.get("facility_destroyed") is bool):
		return "facility_combat_bridge_destroyed_flag_invalid"
	if bool(receipt.get("accepted", false)):
		if (
			str(receipt.get("facility_type", "")) not in FACILITY_TYPES
			or str(receipt.get("damage_kind", ""))
				not in DamageIntent.DAMAGE_KINDS
			or int(receipt.get("expected_generation", 0)) <= 0
			or int(receipt.get("expected_generation", -1))
				!= int(receipt.get("facility_generation_before", -2))
			or int(receipt.get("facility_generation_after", -1))
				!= int(receipt.get("facility_generation_before", -2))
			or int(receipt.get("requested_damage", 0)) <= 0
			or int(receipt.get("facility_max_hp", 0)) <= 0
			or int(receipt.get("applied_damage", 0))
				!= int(receipt.get("requested_damage", -1))
			or int(receipt.get("damage_points_after", -1))
				!= mini(
					int(receipt.get("damage_points_before", 0))
						+ int(receipt.get("applied_damage", 0)),
					int(receipt.get("facility_max_hp", 0))
				)
			or bool(receipt.get("facility_destroyed", false))
				!= (
					int(receipt.get("damage_points_before", 0))
						+ int(receipt.get("applied_damage", 0))
						>= int(receipt.get("facility_max_hp", 0))
				)
			or int(receipt.get("damage_revision_after", -1))
				!= int(receipt.get("damage_revision_before", 0)) + 1
			or int(receipt.get("slot_generation_after", -1))
				!= int(receipt.get("slot_generation_before", 0)) + 1
			or int(receipt.get("region_revision_after", -1))
				!= int(receipt.get("region_revision_before", 0)) + 1
			or int(receipt.get("bridge_revision_after", -1))
				!= int(receipt.get("bridge_revision_before", 0)) + 1
			or int(receipt.get("effect_application_count", -1)) != 1
		):
			return "facility_combat_bridge_success_receipt_invalid"
	else:
		if (
			int(receipt.get("applied_damage", -1)) != 0
			or int(receipt.get("damage_points_after", -1))
				!= int(receipt.get("damage_points_before", -2))
			or int(receipt.get("damage_revision_after", -1))
				!= int(receipt.get("damage_revision_before", -2))
			or int(receipt.get("slot_generation_after", -1))
				!= int(receipt.get("slot_generation_before", -2))
			or int(receipt.get("region_revision_after", -1))
				!= int(receipt.get("region_revision_before", -2))
			or int(receipt.get("bridge_revision_after", -1))
				!= int(receipt.get("bridge_revision_before", -2))
			or str(receipt.get("facility_state_fingerprint_after", ""))
				!= str(
					receipt.get(
						"facility_state_fingerprint_before",
						""
					)
				)
			or str(receipt.get("facility_slots_fingerprint_after", ""))
				!= str(
					receipt.get(
						"facility_slots_fingerprint_before",
						""
					)
				)
			or int(receipt.get("effect_application_count", -1)) != 0
			or bool(receipt.get("facility_destroyed", true))
		):
			return "facility_combat_bridge_failure_receipt_invalid"
	var receipt_fingerprint := str(
		receipt.get("receipt_fingerprint", "")
	)
	if (
		receipt_fingerprint
		!= _fingerprint_without(receipt, "receipt_fingerprint")
	):
		return "facility_combat_bridge_receipt_fingerprint_invalid"
	return ""


static func _sorted_facility_slots(facility_state: Dictionary) -> Array:
	var slots_variant: Variant = facility_state.get("facility_slots")
	if not (slots_variant is Dictionary):
		return []
	var slots := slots_variant as Dictionary
	var slot_ids: Array[String] = []
	for slot_id_variant in slots.keys():
		slot_ids.append(str(slot_id_variant))
	slot_ids.sort()
	var result: Array = []
	for slot_id in slot_ids:
		var slot_variant: Variant = slots.get(slot_id)
		if not (slot_variant is Dictionary):
			return []
		result.append((slot_variant as Dictionary).duplicate(true))
	return result


static func _sort_slots(slots: Array) -> Array:
	var result := slots.duplicate(true)
	result.sort_custom(
		func(left: Variant, right: Variant) -> bool:
			return str((left as Dictionary).get("slot_id", "")) \
				< str((right as Dictionary).get("slot_id", ""))
	)
	return result


static func _slot_by_facility_id(
	slots: Array,
	facility_id: String
) -> Dictionary:
	for slot_variant in slots:
		if not (slot_variant is Dictionary):
			continue
		var slot := slot_variant as Dictionary
		if str(slot.get("facility_id", "")) == facility_id:
			return slot.duplicate(true)
	return {}


static func _damage_sum_safe(current: int, amount: int) -> bool:
	return (
		current >= 0
		and amount > 0
		and current <= MAX_SAFE_INTEGER
		and amount <= MAX_SAFE_INTEGER
		and current <= MAX_SAFE_INTEGER - amount
	)


static func _effect_key(intent: Dictionary) -> String:
	return _fingerprint({
		"source_effect_id": intent.get("source_effect_id"),
		"combat_receipt_id": intent.get("combat_receipt_id"),
		"target_facility_id": intent.get("target_facility_id"),
		"damage_kind": intent.get("damage_kind"),
	})


static func _intent_fingerprint(intent: Dictionary) -> String:
	var candidate := str(intent.get("intent_fingerprint", ""))
	var report := DamageIntent.validation_report(intent)
	return candidate if bool(report.get("valid", false)) else _fingerprint(intent)


static func _fingerprint_or_fallback(
	candidate: Variant,
	value: Variant
) -> String:
	var text := str(candidate)
	return text if _fingerprint_valid(text) else _fingerprint(value)


static func _contains_private_field(value: Variant) -> bool:
	if value is Array:
		for item_variant in value as Array:
			if _contains_private_field(item_variant):
				return true
		return false
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant) in FORBIDDEN_PRIVATE_FIELDS:
				return true
			if _contains_private_field(
				(value as Dictionary).get(key_variant)
			):
				return true
	return false


static func _safe_id(value: Variant, fallback: String) -> String:
	return str(value) if _stable_id(value) else fallback


static func _int_or_fallback(value: Variant, fallback: int) -> int:
	return fallback if value == null else int(value)


static func _fingerprint_without(
	value: Dictionary,
	excluded_field: String
) -> String:
	var copy := value.duplicate(true)
	copy.erase(excluded_field)
	return _fingerprint(copy)


static func _fingerprint(value: Variant) -> String:
	return _canonical(value).sha256_text()


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
	if (
		value == null
		or value is bool
		or value is int
		or value is String
		or value is StringName
	):
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
				(value as Dictionary).get(key_variant),
				depth + 1
			):
				return false
		return true
	return false


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
	if (
		text.is_empty()
		or text.length() > 160
		or text.strip_edges() != text
	):
		return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		var allowed := (
			(code >= 48 and code <= 57)
			or (code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
			or code in [45, 46, 58, 95]
		)
		if not allowed:
			return false
	return true


static func _fingerprint_valid(value: String) -> bool:
	if value.length() != 64:
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
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
