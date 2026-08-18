extends SceneTree

const Bridge := preload(
	"res://scripts/v075/telemetry/v075_combat_telemetry_bridge.gd"
)
const FORBIDDEN_KEY_FRAGMENTS := [
	"skill_definition",
	"skill_card",
	"skill_target",
	"cooldown_remaining",
	"cooldown_batches",
	"instant_sequence",
	"authority_receive_sequence",
	"request_sequence",
	"internal_order",
	"warehouse_stock",
	"private_stock",
	"logistics_plan",
	"ai_plan",
	"ai_private",
	"private_plan",
	"pressure_bucket",
	"owner_player_id",
	"source_instance_id",
	"card_instance_id",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var bridge := Bridge.new()
	var emitted: Array[Dictionary] = []
	bridge.telemetry_event_ready.connect(
		func(event: Dictionary) -> void:
			emitted.append(event.duplicate(true))
	)

	var receipt := {
		"schema": "FacilityCombatReceiptV1",
		"ruleset_id": "v0.7.5",
		"combat_receipt_id": "combat.telemetry.001",
		"event_kind": "monster_private_skill_resolved",
		"batch_id": "batch.0042",
		"source_rank": 4,
		"public_effect_id": "effect.public.cataclysm",
		"target_kind": "facility",
		"damage_amount": 7,
		"private_context": {
			"skill_definition_id": "skill.hidden.ultimate",
			"skill_target": "facility.future.hidden",
			"cooldown_remaining_batches": 4,
			"monster_private_instant_sequence": 92,
			"warehouse_private_stock": {"technology": 5},
			"ai_private_plan": {"next_target": "region.hidden"},
			"owner_player_id": "player.rival",
		},
	}
	var receipt_before := receipt.duplicate(true)
	var first := bridge.consume_public_receipt(receipt)
	var first_payload := first.get("payload", {}) as Dictionary
	_expect(
		str(first.get("schema", "")) == "V075CombatTelemetryEventV1"
		and str(first.get("event_type", "")) ==
			"monster_private_skill_resolved"
		and str(first.get("batch_id", "")) == "batch.0042",
		"public receipt emits one typed telemetry event"
	)
	_expect(
		int(first_payload.get("source_rank", 0)) == 4
		and str(first_payload.get("public_effect_id", "")) ==
			"effect.public.cataclysm"
		and str(first_payload.get("target_kind", "")) == "facility"
		and int(first_payload.get("damage_amount", 0)) == 7,
		"allowed public receipt fields retain value parity"
	)
	_expect(
		not _contains_forbidden_key(first),
		"receipt event stores no private skill or planning fields"
	)
	_expect(
		JSON.stringify(receipt) == JSON.stringify(receipt_before),
		"bridge does not mutate the source receipt"
	)

	var duplicate_cue := {
		"schema": "V075CombatPresentationCueV1",
		"ruleset_id": "v0.7.5",
		"presentation_receipt_id": "combat.telemetry.001",
		"event_kind": "monster_private_skill_resolved",
		"public_payload": {
			"source_rank": 4,
			"public_effect_id": "effect.public.cataclysm",
			"target_kind": "facility",
			"damage_amount": 7,
			"skill_definition_id": "skill.hidden.ultimate",
		},
	}
	var duplicate := bridge.consume_public_cue(
		duplicate_cue,
		"batch.0042"
	)
	_expect(
		duplicate.is_empty(),
		"receipt and its presentation cue emit telemetry exactly once"
	)

	var cue := {
		"schema": "V075CombatPresentationCueV1",
		"ruleset_id": "v0.7.5",
		"presentation_receipt_id": "combat.telemetry.002",
		"event_kind": "facility_combat_damaged",
		"asset_keys": ["vfx.facility.damaged_smoke"],
		"public_payload": {
			"facility_type": "warehouse",
			"region_id": "region.08",
			"damage_amount": 3,
			"facility_damage_state": "damaged",
			"skill_target": "warehouse.hidden",
			"cooldown_remaining_batches": 2,
			"monster_private_instant_sequence": 93,
			"warehouse_private_stock": {"energy": 4},
			"ai_private_plan": {"response": "repair"},
		},
		"presentation_only": true,
	}
	var cue_before := cue.duplicate(true)
	var second := bridge.consume_public_cue(cue, "batch.0043")
	var second_payload := second.get("payload", {}) as Dictionary
	_expect(
		str(second.get("event_type", "")) ==
			"facility_combat_damaged"
		and str(second.get("batch_id", "")) == "batch.0043",
		"public presentation cue emits an allowed telemetry event"
	)
	_expect(
		str(second_payload.get("facility_type", "")) == "warehouse"
		and str(second_payload.get("region_id", "")) == "region.08"
		and int(second_payload.get("damage_amount", 0)) == 3
		and str(second_payload.get("facility_damage_state", "")) ==
			"damaged",
		"cue public payload retains facility damage parity"
	)
	_expect(
		not _contains_forbidden_key(second)
		and JSON.stringify(cue) == JSON.stringify(cue_before),
		"cue privacy filtering is read-only"
	)

	var collision := bridge.consume_public_receipt({
		"ruleset_id": "v0.7.5",
		"combat_receipt_id": "combat.telemetry.001",
		"event_kind": "monster_moved",
		"source_rank": 4,
		"start_region_id": "region.01",
		"destination_region_id": "region.02",
	})
	_expect(
		collision.is_empty(),
		"same receipt identity cannot change telemetry event kind"
	)
	var unsupported := bridge.consume_public_receipt({
		"ruleset_id": "v0.7.5",
		"combat_receipt_id": "combat.telemetry.003",
		"event_kind": "monster_damaged",
		"damage_amount": 2,
	})
	var wrong_ruleset := bridge.consume_public_receipt({
		"ruleset_id": "v0.7.6",
		"combat_receipt_id": "combat.telemetry.004",
		"event_kind": "monster_moved",
		"source_rank": 1,
	})
	_expect(
		unsupported.is_empty() and wrong_ruleset.is_empty(),
		"unsupported and mixed-ruleset inputs are rejected"
	)

	var events := bridge.recent_events()
	_expect(
		events.size() == 2
		and emitted.size() == 2
		and int(events[0].get("event_sequence", 0)) == 1
		and int(events[1].get("event_sequence", 0)) == 2,
		"bridge emits exactly two ordered public events"
	)
	var debug := bridge.debug_snapshot()
	_expect(
		int(debug.get("receipt_input_count", 0)) == 4
		and int(debug.get("cue_input_count", 0)) == 2
		and int(debug.get("emitted_event_count", 0)) == 2
		and int(debug.get("duplicate_source_count", 0)) == 1
		and int(debug.get("collision_source_count", 0)) == 1
		and int(debug.get("rejected_input_count", 0)) == 3,
		"bridge counters distinguish emit, duplicate, collision, and reject"
	)
	_expect(
		int(debug.get(
			"opponent_skill_definition_input_count",
			0
		)) > 0
		and int(debug.get(
			"opponent_skill_target_input_count",
			0
		)) > 0
		and int(debug.get(
			"opponent_skill_cooldown_input_count",
			0
		)) > 0
		and int(debug.get("instant_sequence_input_count", 0)) > 0
		and int(debug.get(
			"warehouse_private_stock_input_count",
			0
		)) > 0
		and int(debug.get("ai_private_plan_input_count", 0)) > 0,
		"all required hidden-input categories are observed and filtered"
	)
	var contract_debug := debug.get("contract", {}) as Dictionary
	_expect(
		int(debug.get("stored_hidden_field_count", -1)) == 0
		and int(contract_debug.get("stored_hidden_field_count", -1)) == 0,
		"neither bridge nor contract stores hidden fields"
	)
	_expect(
		int(debug.get("gameplay_owner_count", -1)) == 0
		and int(debug.get("rng_owner_count", -1)) == 0
		and int(debug.get("world_mutation_count", -1)) == 0
		and int(contract_debug.get("gameplay_owner_count", -1)) == 0
		and int(contract_debug.get("rng_owner_count", -1)) == 0
		and int(contract_debug.get("world_mutation_count", -1)) == 0,
		"telemetry bridge owns no gameplay, RNG, or world mutation"
	)

	bridge.reset_for_new_match()
	var reset_debug := bridge.debug_snapshot()
	_expect(
		int(reset_debug.get("emitted_event_count", -1)) == 0
		and int(reset_debug.get("source_binding_count", -1)) == 0
		and bridge.recent_events().is_empty(),
		"new-match reset discards only detached telemetry state"
	)
	_finish()


func _contains_forbidden_key(value: Variant) -> bool:
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary.keys():
			var key := str(key_variant).to_lower()
			for fragment_variant in FORBIDDEN_KEY_FRAGMENTS:
				if str(fragment_variant) in key:
					return true
			if _contains_forbidden_key(dictionary.get(key_variant)):
				return true
	elif value is Array:
		for child_variant in value as Array:
			if _contains_forbidden_key(child_variant):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print(
		"V075_COMBAT_TELEMETRY_BRIDGE_TEST|status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)