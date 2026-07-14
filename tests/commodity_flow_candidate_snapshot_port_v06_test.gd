extends SceneTree

const PORT_SCRIPT := preload("res://scripts/cards/v06/production/commodity_flow_candidate_snapshot_port_v06.gd")

var _checks := 0
var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted
	var snapshot := {"valid": true, "revision": 7, "candidates": [{"candidate_id": "candidate-a"}]}
	func card_effect_candidates_snapshot() -> Dictionary:
		return snapshot.duplicate(true)


class FakePlanner:
	extends RefCounted
	var revision := -1
	var candidates: Array = []
	func replace_authoritative_candidates(next_revision: int, next_candidates: Array) -> Dictionary:
		revision = next_revision
		candidates = next_candidates.duplicate(true)
		return {"configured": true, "reason_code": "configured"}


func _init() -> void:
	var port = PORT_SCRIPT.new()
	var unavailable: Dictionary = port.authoritative_snapshot()
	_expect(not bool(unavailable.get("valid", true)) and str(unavailable.get("reason_code", "")) == "candidate_snapshot_owner_unavailable", "candidate port fails closed without an authoritative owner")
	var owner := FakeOwner.new()
	_expect(bool(port.configure(owner).get("configured", false)), "candidate port accepts the explicit CommodityFlow snapshot contract")
	var planner := FakePlanner.new()
	var refreshed: Dictionary = port.refresh_planner(planner)
	_expect(bool(refreshed.get("valid", false)) and planner.revision == 7 and planner.candidates.size() == 1, "candidate port forwards authoritative revision and rows without owning a copy")
	owner.snapshot = {"valid": false, "reason_code": "world_facts_unavailable", "revision": 8, "candidates": []}
	var rejected: Dictionary = port.refresh_planner(planner)
	_expect(not bool(rejected.get("valid", true)) and str(rejected.get("reason_code", "")) == "world_facts_unavailable" and planner.revision == 7, "missing world facts leave the planner unchanged")
	if _failures.is_empty():
		print("COMMODITY_FLOW_CANDIDATE_SNAPSHOT_PORT_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("COMMODITY_FLOW_CANDIDATE_SNAPSHOT_PORT_V06_TEST|status=FAIL|checks=%d|failures=%d" % [_checks, _failures.size()])
	quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
