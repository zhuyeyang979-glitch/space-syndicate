extends SceneTree

const Port := preload(
	"res://scripts/v075/monster/v075_character_monster_capacity_port.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var contract := Port.contract_snapshot()
	_expect(
		contract.get("base_monster_control_capacity_per_player") == 1
		and contract.get("character_semantic_port_count") == 1
		and contract.get("ui_capacity_exception_count") == 0
		and contract.get("player_index_capacity_exception_count") == 0
		and contract.get("character_name_capacity_exception_count") == 0,
		"capacity has one base value and no identity or UI exceptions"
	)
	var base := Port.build_semantic("player.alpha", 0)
	var base_receipt := Port.capacity_receipt(base)
	_expect(
		base_receipt.get("accepted") == true
		and base_receipt.get("base_capacity") == 1
		and base_receipt.get("modifier") == 0
		and base_receipt.get("effective_capacity") == 1,
		"zero modifier preserves base capacity one"
	)
	var expanded := Port.build_semantic("player.alpha", 5, 2)
	_expect(
		Port.effective_capacity(expanded) == 6,
		"typed character modifier is the only capacity extension"
	)
	_expect(
		expanded == Port.build_semantic("player.alpha", 5, 2),
		"capacity semantic construction is deterministic"
	)
	var forged_index := expanded.duplicate(true)
	forged_index["player_index"] = 0
	_expect(
		Port.validation_report(forged_index).get("valid") == false
		and Port.effective_capacity(forged_index) == -1,
		"closed contract rejects player-index exceptions"
	)
	var forged_name := expanded.duplicate(true)
	forged_name["character_name"] = "special"
	_expect(
		Port.validation_report(forged_name).get("valid") == false,
		"closed contract rejects character-name exceptions"
	)
	var tampered := expanded.duplicate(true)
	tampered["monster_control_capacity_modifier"] = 7
	_expect(
		Port.capacity_receipt(tampered).get("accepted") == false,
		"fingerprint rejects modifier tampering"
	)
	_expect(
		Port.build_semantic("player.alpha", -1).is_empty()
		and Port.effective_capacity(
			Port.build_semantic("player.alpha", 30)
		) == 31,
		"port rejects negative modifiers without inventing a balance cap"
	)
	_expect(
		contract.get("capacity_drop_forced_kill_allowed") == false,
		"typed port forbids forced kills on capacity drop"
	)
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	for failure in _failures:
		push_error(
			"V075_CHARACTER_MONSTER_CAPACITY_PORT_TEST|FAIL|%s"
			% failure
		)
	print(
		"V075_CHARACTER_MONSTER_CAPACITY_PORT_TEST|%s|checks=%d|failures=%d"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks,
			_failures.size(),
		]
	)
	quit(0 if _failures.is_empty() else 1)
