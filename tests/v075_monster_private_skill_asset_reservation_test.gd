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
	var state := Fixture.state(3)
	var blocked_view := {
		"viewer_id": "player.0",
		"state_revision": 4,
		"own_exact_assets": Fixture.cost(6),
		"own_reservations": {"action.public.001": Fixture.cost(5)},
		"own_available_assets": Fixture.cost(1),
	}
	var blocked_before := blocked_view.duplicate(true)
	var blocked_request := Fixture.request(
		state,
		"request.asset.blocked",
		"skill.owner.3"
	)
	var blocked := Core.submit_request(state, blocked_request, blocked_view)
	state = blocked.get("state") as Dictionary
	_expect(
		not bool(blocked.get("accepted", true))
		and blocked.get("reason_code")
		== "available_unreserved_assets_insufficient",
		"skill cannot consume assets reserved by public actions"
	)
	_expect(
		(blocked.get("asset_reservation_request") as Dictionary).is_empty()
		and blocked_view == blocked_before,
		"preaccept failure is free and does not mutate asset projection"
	)
	var available_view := blocked_view.duplicate(true)
	available_view["state_revision"] = 5
	available_view["own_available_assets"] = Fixture.cost(2)
	var available_before := available_view.duplicate(true)
	var legal_request := Fixture.request(
		state,
		"request.asset.legal",
		"skill.owner.3"
	)
	var submitted := Core.submit_request(state, legal_request, available_view)
	state = submitted.get("state") as Dictionary
	var reservation_request := submitted.get(
		"asset_reservation_request"
	) as Dictionary
	_expect(
		bool(submitted.get("accepted", false))
		and reservation_request.get("contract_id")
		== Core.ASSET_RESERVATION_REQUEST_ID
		and reservation_request.get("asset_cost_by_color")
		== Fixture.cost(2),
		"legal request emits exact typed cost reservation"
	)
	_expect(
		available_view == available_before,
		"combat core never mutates owner asset view"
	)
	var receipt := Core.build_asset_reservation_receipt(
		reservation_request,
		true,
		"reservation_committed",
		6
	)
	var applied := Core.apply_asset_reservation_receipt(state, receipt)
	state = applied.get("state") as Dictionary
	var resolved := Fixture.resolve(state, true, "resolved")
	state = resolved.get("state") as Dictionary
	_expect(
		(resolved.get("asset_settlement_intent") as Dictionary).get(
			"action"
		) == "commit",
		"successful resolution emits commit intent"
	)
	var state_text := JSON.stringify(state)
	_expect(
		not state_text.contains("own_exact_assets")
		and not state_text.contains("own_available_assets")
		and int(Core.debug_snapshot(state).get(
			"direct_asset_write_count",
			-1
		)) == 0,
		"skill authority stores no asset balances and performs zero writes"
	)
	_finish()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("V075_MONSTER_PRIVATE_SKILL_ASSET_RESERVATION_TEST|%s|%d/%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
	])
	quit(0 if _failures.is_empty() else 1)
