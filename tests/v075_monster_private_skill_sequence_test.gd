extends SceneTree

const Core := preload(
	"res://scripts/v075/monster/v075_monster_private_skill_core.gd"
)
const Bench := preload(
	"res://scripts/tools/v075/v075_monster_private_skill_bench.gd"
)
const Fixture := Bench.TestFixture

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var ordered := Core.stable_queue_order([
		{"authority_receive_sequence": 5, "owner_player_id": "player.2", "request_id": "request.c"},
		{"authority_receive_sequence": 4, "owner_player_id": "player.9", "request_id": "request.z"},
		{"authority_receive_sequence": 5, "owner_player_id": "player.1", "request_id": "request.b"},
		{"authority_receive_sequence": 5, "owner_player_id": "player.1", "request_id": "request.a"},
	])
	var ordered_ids: Array[String] = []
	for entry_variant in ordered:
		ordered_ids.append(str((entry_variant as Dictionary).get("request_id", "")))
	_expect(
		ordered_ids == ["request.z", "request.a", "request.b", "request.c"],
		"stable order is sequence then player_id then request_id"
	)

	var state := Fixture.state()
	var request := Fixture.request(state, "request.sequence.001")
	var first := Core.submit_request(state, request, Fixture.asset_view())
	state = first.get("state") as Dictionary
	_expect(
		int((first.get("receipt") as Dictionary).get(
			"authority_receive_sequence",
			-1
		)) == 0,
		"authority assigns first receive sequence"
	)
	var before_replay := state.duplicate(true)
	var duplicate := Core.submit_request(state, request, Fixture.asset_view())
	_expect(
		bool(duplicate.get("replayed", false))
		and duplicate.get("state") == before_replay
		and (duplicate.get("asset_reservation_request") as Dictionary).is_empty(),
		"duplicate request replays without duplicate asset request"
	)
	var colliding := Fixture.request(
		state,
		"request.sequence.001",
		"skill.owner.1",
		"enemy_facility",
		"facility.target.changed"
	)
	var collision := Core.submit_request(state, colliding, Fixture.asset_view())
	_expect(
		not bool(collision.get("accepted", true))
		and collision.get("reason_code") == "request_id_collision"
		and collision.get("state") == state,
		"same request id with new fingerprint is rejected"
	)
	var reservation := first.get("asset_reservation_request") as Dictionary
	var receipt := Core.build_asset_reservation_receipt(
		reservation,
		true,
		"reservation_committed",
		2
	)
	var applied := Core.apply_asset_reservation_receipt(state, receipt)
	state = applied.get("state") as Dictionary
	var before_receipt_replay := state.duplicate(true)
	var replayed_receipt := Core.apply_asset_reservation_receipt(state, receipt)
	_expect(
		bool(replayed_receipt.get("replayed", false))
		and replayed_receipt.get("state") == before_receipt_replay
		and not bool(replayed_receipt.get("execution_due", true)),
		"reservation receipt is exact-once"
	)
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("V075_MONSTER_PRIVATE_SKILL_SEQUENCE_TEST|%s|%d/%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
	])
	quit(0 if _failures.is_empty() else 1)
