extends SceneTree

const Bridge := preload(
	"res://scripts/v075/combat/v075_facility_combat_damage_bridge.gd"
)
const DamageIntent := preload(
	"res://scripts/v075/combat/facility_combat_damage_intent_v1.gd"
)
const FacilityCore := preload(
	"res://scripts/v074/facility/v074_facility_runtime_core.gd"
)
const WarehouseRuntime := preload(
	"res://scripts/v074/warehouse/v074_warehouse_runtime_policy.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_contract()
	var facility_state := _facility_state_fixture()
	_expect(
		bool(FacilityCore.validation_report(facility_state).get(
			"valid",
			false
		)),
		"V074 facility state fixture validates"
	)
	var bridge_state := Bridge.create_state(facility_state)
	_expect(
		bool(Bridge.validation_report(bridge_state).get("valid", false)),
		"bridge accepts a resolved V074 facility state"
	)
	if bridge_state.is_empty():
		_finish()
		return

	var private_stock := {
		"facility.warehouse.shipping": [
			"secret.stock.life.42",
			"secret.route.plan.9",
		],
	}
	var private_stock_before := private_stock.duplicate(true)
	var cases := [
		{
			"label": "factory",
			"facility_id": "facility.factory.industry",
			"damage_amount": 3,
			"damage_kind": "monster_ground_trample",
		},
		{
			"label": "market",
			"facility_id": "facility.market.commerce",
			"damage_amount": 4,
			"damage_kind": "monster_basic_attack",
		},
		{
			"label": "warehouse",
			"facility_id": "facility.warehouse.shipping",
			"damage_amount": 5,
			"damage_kind": "military_region_assault",
		},
	]
	var successful_intents := {}
	var successful_receipts := {}
	for case_variant in cases:
		var case := case_variant as Dictionary
		var label := str(case.get("label", ""))
		var facility_id := str(case.get("facility_id", ""))
		var slot_before := _slot_by_facility_id(
			bridge_state.get("facility_slots", []) as Array,
			facility_id
		)
		var intent := DamageIntent.build(
			"effect.v075.bridge.%s" % label,
			facility_id,
			int(slot_before.get("facility_generation", 0)),
			int(case.get("damage_amount", 0)),
			str(case.get("damage_kind", "")),
			"combat.receipt.v075.bridge.%s" % label
		)
		successful_intents[label] = intent.duplicate(true)
		var input_before := bridge_state.duplicate(true)
		var result := Bridge.apply_intent(bridge_state, intent)
		_expect(
			bridge_state == input_before,
			"%s transition does not mutate its input state" % label
		)
		_expect(
			bool(result.get("accepted", false))
				and not bool(result.get("duplicate", true))
				and int(
					result.get(
						"combat_direct_facility_write_count",
						-1
					)
				) == 0,
			"%s typed damage transition commits without a direct write"
				% label
		)
		var receipt := result.get("receipt", {}) as Dictionary
		successful_receipts[label] = receipt.duplicate(true)
		_expect(
			bool(
				Bridge.receipt_validation_report(receipt).get(
					"valid",
					false
				)
			),
			"%s sealed bridge receipt validates" % label
		)
		var next_state := result.get("state", {}) as Dictionary
		_expect(
			bool(Bridge.validation_report(next_state).get("valid", false)),
			"%s bridge state remains valid" % label
		)
		var next_facility_state := (
			result.get("facility_state", {}) as Dictionary
		)
		_expect(
			bool(
				FacilityCore.validation_report(next_facility_state).get(
					"valid",
					false
				)
			)
				and str(next_facility_state.get("status", ""))
					== "resolved",
			"%s returns a valid resolved V074 facility state" % label
		)
		var slot_after := _slot_by_facility_id(
			result.get("facility_slots", []) as Array,
			facility_id
		)
		_expect(
			str(slot_after.get("facility_type", "")) == label
				and int(slot_after.get("facility_generation", -1))
					== int(slot_before.get("facility_generation", -2)),
			"%s keeps exact facility identity and generation" % label
		)
		_expect(
			int(slot_after.get("damage_points", -1))
					== int(slot_before.get("damage_points", 0))
						+ int(case.get("damage_amount", 0))
				and int(slot_after.get("damage_revision", -1))
					== int(slot_before.get("damage_revision", 0)) + 1,
			"%s applies damage once and advances damage revision" % label
		)
		_expect(
			int(slot_after.get("slot_generation", -1))
					== int(slot_before.get("slot_generation", 0)) + 1
				and int(slot_after.get("region_revision", -1))
					== int(slot_before.get("region_revision", 0)) + 1,
			"%s uses the V074 slot transition generations" % label
		)
		_expect(
			_non_target_slots_unchanged(
				input_before.get("facility_slots", []) as Array,
				result.get("facility_slots", []) as Array,
				facility_id
			),
			"%s transition changes only its locked target" % label
		)
		_expect(
			str(receipt.get("target_facility_id", "")) == facility_id
				and int(receipt.get("applied_damage", -1))
					== int(case.get("damage_amount", 0))
				and int(
					receipt.get(
						"combat_direct_facility_write_count",
						-1
					)
				) == 0,
			"%s receipt binds the exact target and applied amount" % label
		)
		bridge_state = next_state

	_expect(
		int(bridge_state.get("bridge_revision", -1)) == 3
			and (
				bridge_state.get(
					"processed_intent_fingerprints",
					[]
				) as Array
			).size() == 3
			and (
				bridge_state.get("receipt_journal", {}) as Dictionary
			).size() == 3,
		"three facility kinds commit through one exact-once journal"
	)
	_test_exact_once(
		bridge_state,
		successful_intents.get("warehouse", {}) as Dictionary,
		successful_receipts.get("warehouse", {}) as Dictionary
	)
	_test_generation_and_collision_guards(
		bridge_state,
		successful_intents.get("factory", {}) as Dictionary
	)
	_test_privacy(
		bridge_state,
		successful_intents.get("warehouse", {}) as Dictionary,
		successful_receipts,
		private_stock,
		private_stock_before
	)
	_test_receipt_tamper(
		successful_receipts.get("market", {}) as Dictionary
	)
	_finish()


func _test_contract() -> void:
	var contract := Bridge.contract_report()
	_expect(
		contract.get("facility_types")
			== ["factory", "market", "warehouse"],
		"bridge contract covers factory, market, and warehouse"
	)
	_expect(
		contract.get("v074_legal_transition_api") == [
			"build_occupied_slot",
			"slot_validation_report",
			"lock_batch",
		]
			and int(
				contract.get(
					"v074_direct_facility_damage_method_count",
					-1
				)
			) == 0,
		"bridge records the audited V074 transition surface"
	)
	_expect(
		bool(contract.get("resolved_safe_boundary_required", false))
			and bool(contract.get("generation_lock_required", false))
			and bool(contract.get("exact_once_journal", false)),
		"bridge freezes safe-boundary, generation, and exact-once rules"
	)
	_expect(
		not bool(
			contract.get(
				"legacy_region_hp_damage_bridge_connected",
				true
			)
		)
			and int(
				contract.get(
					"combat_direct_facility_write_count",
					-1
				)
			) == 0
			and int(contract.get("gameplay_owner_count", -1)) == 0,
		"bridge is pure and does not connect the legacy region HP writer"
	)


func _test_exact_once(
	state: Dictionary,
	intent: Dictionary,
	first_receipt: Dictionary
) -> void:
	var before := state.duplicate(true)
	var target_before := _slot_by_facility_id(
		state.get("facility_slots", []) as Array,
		str(intent.get("target_facility_id", ""))
	)
	var replay := Bridge.apply_intent(state, intent)
	var target_after := _slot_by_facility_id(
		(replay.get("state", {}) as Dictionary).get(
			"facility_slots",
			[]
		) as Array,
		str(intent.get("target_facility_id", ""))
	)
	_expect(
		bool(replay.get("accepted", false))
			and bool(replay.get("duplicate", false))
			and str(replay.get("reason_code", ""))
				== "facility_combat_damage_exact_once_replay",
		"exact duplicate returns the journaled success"
	)
	_expect(
		replay.get("state") == before
			and replay.get("receipt") == first_receipt
			and target_after == target_before,
		"exact duplicate performs zero additional damage"
	)


func _test_generation_and_collision_guards(
	state: Dictionary,
	committed_factory_intent: Dictionary
) -> void:
	var before := state.duplicate(true)
	var factory_slot := _slot_by_facility_id(
		state.get("facility_slots", []) as Array,
		"facility.factory.industry"
	)
	var stale := DamageIntent.build(
		"effect.v075.bridge.stale",
		"facility.factory.industry",
		int(factory_slot.get("facility_generation", 0)) + 1,
		2,
		"monster_basic_attack",
		"combat.receipt.v075.bridge.stale"
	)
	var stale_result := Bridge.apply_intent(state, stale)
	_expect(
		not bool(stale_result.get("accepted", true))
			and str(stale_result.get("reason_code", ""))
				== "facility_combat_damage_generation_stale"
			and stale_result.get("state") == before,
		"stale facility generation is rejected with zero state change"
	)
	_expect(
		bool(
			Bridge.receipt_validation_report(
				stale_result.get("receipt", {})
			).get("valid", false)
		),
		"stale-generation rejection returns a sealed receipt"
	)

	var collision := DamageIntent.build(
		str(committed_factory_intent.get("source_effect_id", "")),
		str(committed_factory_intent.get("target_facility_id", "")),
		int(committed_factory_intent.get("expected_generation", 0)),
		int(committed_factory_intent.get("damage_amount", 0)) + 1,
		str(committed_factory_intent.get("damage_kind", "")),
		str(committed_factory_intent.get("combat_receipt_id", ""))
	)
	var collision_result := Bridge.apply_intent(state, collision)
	_expect(
		not bool(collision_result.get("accepted", true))
			and str(collision_result.get("reason_code", ""))
				== "facility_combat_damage_effect_collision"
			and collision_result.get("state") == before,
		"same effect identity cannot be rebound to different damage"
	)


func _test_privacy(
	state: Dictionary,
	warehouse_intent: Dictionary,
	successful_receipts: Dictionary,
	private_stock: Dictionary,
	private_stock_before: Dictionary
) -> void:
	var warehouse_slot := _slot_by_facility_id(
		state.get("facility_slots", []) as Array,
		"facility.warehouse.shipping"
	)
	var projection := FacilityCore.warehouse_public_projection(
		warehouse_slot
	)
	var privacy := WarehouseRuntime.privacy_report(projection)
	_expect(
		bool(privacy.get("valid", false))
			and int(privacy.get("hidden_info_field_count", -1)) == 0
			and not bool(projection.get("private_stock_included", true))
			and not bool(
				projection.get("private_logistics_included", true)
			),
		"damaged warehouse keeps a private-safe V074 projection"
	)
	_expect(
		private_stock == private_stock_before,
		"bridge never reads or mutates the external warehouse stock owner"
	)
	var evidence_text := JSON.stringify({
		"state": state,
		"receipts": successful_receipts,
	})
	_expect(
		not evidence_text.contains("secret.stock.life.42")
			and not evidence_text.contains("secret.route.plan.9"),
		"bridge state and receipts disclose no warehouse private payload"
	)
	for receipt_variant in successful_receipts.values():
		_expect(
			int(
				(receipt_variant as Dictionary).get(
					"warehouse_private_stock_disclosure_count",
					-1
				)
			) == 0,
			"every facility receipt reports zero warehouse disclosure"
		)

	var private_field_intent := warehouse_intent.duplicate(true)
	private_field_intent["warehouse_stock"] = ["secret.stock.life.42"]
	var before := state.duplicate(true)
	var rejected := Bridge.apply_intent(state, private_field_intent)
	_expect(
		not bool(rejected.get("accepted", true))
			and rejected.get("state") == before,
		"intent carrying private warehouse data fails closed"
	)
	var rejected_receipt := rejected.get("receipt", {}) as Dictionary
	_expect(
		bool(
			Bridge.receipt_validation_report(rejected_receipt).get(
				"valid",
				false
			)
		),
		"private-field rejection still returns a sealed safe receipt"
	)
	_expect(
		str(rejected_receipt.get("receipt_id", ""))
			!= str(
				(successful_receipts.get("warehouse", {}) as Dictionary).get(
					"receipt_id",
					""
				)
			),
		"tampered private intent cannot reuse the prior success receipt id"
	)


func _test_receipt_tamper(receipt: Dictionary) -> void:
	var tampered := receipt.duplicate(true)
	tampered["damage_points_after"] = int(
		tampered.get("damage_points_after", 0)
	) + 1
	_expect(
		not bool(
			Bridge.receipt_validation_report(tampered).get(
				"valid",
				true
			)
		),
		"receipt tampering is rejected"
	)


func _facility_state_fixture() -> Dictionary:
	var slots := [
		FacilityCore.build_occupied_slot(
			"region.factory",
			11,
			"factory",
			"industry",
			3,
			"facility.factory.industry",
			2,
			"player.alpha",
			2,
			4,
			6
		),
		FacilityCore.build_occupied_slot(
			"region.market",
			12,
			"market",
			"commerce",
			5,
			"facility.market.commerce",
			3,
			"player.beta",
			3,
			2,
			1
		),
		FacilityCore.build_occupied_slot(
			"region.warehouse",
			13,
			"warehouse",
			"shipping",
			7,
			"facility.warehouse.shipping",
			7,
			"player.beta",
			2,
			5,
			8,
			"sunlit"
		),
	]
	for slot_variant in slots:
		_expect(
			bool(
				FacilityCore.slot_validation_report(slot_variant).get(
					"valid",
					false
				)
			),
			"facility fixture slot validates"
		)
	var players := ["player.alpha", "player.beta"]
	return FacilityCore.lock_batch(
		"batch.v075.bridge.fixture",
		players,
		players,
		{
			"player.alpha": [],
			"player.beta": [],
		},
		slots,
		false
	)


func _slot_by_facility_id(
	slots: Array,
	facility_id: String
) -> Dictionary:
	for slot_variant in slots:
		var slot := slot_variant as Dictionary
		if str(slot.get("facility_id", "")) == facility_id:
			return slot.duplicate(true)
	return {}


func _non_target_slots_unchanged(
	before_slots: Array,
	after_slots: Array,
	target_facility_id: String
) -> bool:
	for before_variant in before_slots:
		var before := before_variant as Dictionary
		var facility_id := str(before.get("facility_id", ""))
		if facility_id == target_facility_id:
			continue
		if _slot_by_facility_id(after_slots, facility_id) != before:
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print(
		"V075_FACILITY_COMBAT_DAMAGE_BRIDGE_TEST|"
		+ "status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
