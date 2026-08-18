extends SceneTree

const Core := preload(
	"res://scripts/v075/military/v075_military_mission_core.gd"
)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var contract := Core.contract_report()
	_expect(
		not Core.TASK_KINDS.has("guard_region")
			and not Core.TASK_KINDS.has("protect_region")
			and not Core.TASK_KINDS.has("defend_region")
			and not Core.TASK_KINDS.has("intercept_region"),
		"retired defensive tasks are absent"
	)
	_expect(
		int(contract.get("military_guard_task_count", -1)) == 0,
		"contract reports zero guard tasks"
	)
	var request := Core.build_region_request(
		"request.guard.negative",
		"mission.guard.negative",
		"player.one",
		"card.military.one",
		"slot.one",
		"reservation.one",
		"region.001"
	)
	request["task_kind"] = "guard_region"
	_expect(
		not bool(
			Core.request_validation_report(request).get("valid", true)
		),
		"guard request cannot cross the authority boundary"
	)
	print(
		"V075_MILITARY_NO_GUARD_TEST|status=%s|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)