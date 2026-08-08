extends SceneTree

const Intent := preload(
	"res://scripts/v075/combat/facility_combat_damage_intent_v1.gd"
)
const DamageCore := preload(
	"res://scripts/v075/combat/v075_combat_damage_core.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var intent := Intent.build(
		"effect.military.region",
		"facility.warehouse.001",
		7,
		4,
		"military_region_assault",
		"combat.receipt.001"
	)
	_expect(
		bool(Intent.validation_report(intent).get("valid", false)),
		"required typed facility intent validates"
	)
	for field in [
		"source_effect_id",
		"target_facility_id",
		"expected_generation",
		"damage_amount",
		"damage_kind",
		"combat_receipt_id",
	]:
		_expect(intent.has(field), "intent includes %s" % field)
	var stale := intent.duplicate(true)
	stale["expected_generation"] = 0
	_expect(
		not bool(Intent.validation_report(stale).get("valid", true)),
		"invalid generation cannot cross typed port"
	)
	var batch := DamageCore.build_facility_damage_batch(
		"effect.military.region",
		"combat.receipt.002",
		"military_region_assault",
		[{
			"target_facility_id": "facility.factory.001",
			"expected_generation": 2,
			"damage_amount": 5,
		}]
	)
	_expect(
		bool(batch.get("accepted", false))
			and int(batch.get("direct_facility_write_count", -1)) == 0
			and int(batch.get("facility_state_payload_count", -1)) == 0,
		"combat core emits intent without facility state mutation"
	)
	_expect(
		bool(
			DamageCore.contract_report().get(
				"typed_facility_damage_port", false
			)
		),
		"combat damage contract advertises typed port"
	)
	print(
		"V075_FACILITY_COMBAT_DAMAGE_PORT_TEST|status=%s|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)