extends SceneTree

const Core := preload(
	"res://scripts/v075/military/v075_military_mission_core.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var contract := Core.contract_report()
	_expect(
		Core.TASK_KINDS == ["assault_region", "assault_monster"],
		"task registry contains exactly the two assault missions"
	)
	_expect(
		contract.get("military_task_kinds") == Core.TASK_KINDS
			and int(contract.get("military_task_button_count", -1)) == 2,
		"public task contract exposes exactly two choices"
	)
	var region := Core.build_region_request(
		"request.region",
		"mission.region",
		"player.one",
		"card.military.one",
		"slot.one",
		"reservation.one",
		"region.004"
	)
	var monster := Core.build_monster_request(
		"request.monster",
		"mission.monster",
		"player.one",
		"card.military.two",
		"slot.two",
		"reservation.two",
		"monster.source.004"
	)
	_expect(
		bool(Core.request_validation_report(region).get("valid", false))
			and bool(
				Core.request_validation_report(monster).get("valid", false)
			),
		"both request shapes validate"
	)
	_expect(
		not region.has("region_damage_budget")
			and not region.has("card_rank")
			and not region.has("target_region_revision")
			and not monster.has("target_source_generation"),
		"player requests select targets without authority facts"
	)
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	print(
		"V075_MILITARY_TWO_TASK_CONTRACT_TEST|status=%s|checks=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)