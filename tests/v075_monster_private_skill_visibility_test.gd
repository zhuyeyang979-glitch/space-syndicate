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
	var state := Fixture.state(1, true)
	_expect(
		bool(Core.validation_report(state).get("valid", false)),
		"fixture state validates"
	)
	var owner := Core.owner_private_projection(state, "player.0")
	var rival := Core.owner_private_projection(state, "player.1")
	_expect(_source_ids(owner) == ["monster.owner.001"], "owner sees only own source")
	_expect(_source_ids(rival) == ["monster.rival.001"], "rival sees only rival source")
	_expect(_skill_count(owner) == 1 and _skill_count(rival) == 1, "each L1 owner sees one private card")

	var request := Fixture.request(state, "request.visibility.001")
	var submitted := Core.submit_request(
		state,
		request,
		Fixture.asset_view(6)
	)
	state = submitted.get("state") as Dictionary
	var pending_owner := Core.owner_private_projection(state, "player.0")
	var pending_rival := Core.owner_private_projection(state, "player.1")
	_expect(
		JSON.stringify(pending_owner).contains("request.visibility.001")
		and JSON.stringify(pending_owner).contains("facility.target.001"),
		"owner projection contains own pending request and target"
	)
	_expect(
		not JSON.stringify(pending_rival).contains("request.visibility.001")
		and not JSON.stringify(pending_rival).contains("facility.target.001"),
		"rival projection excludes owner request and target"
	)
	var public_projection := Core.public_projection(state)
	var privacy := Core.public_projection_privacy_report(public_projection)
	var public_text := JSON.stringify(public_projection)
	_expect(
		bool(privacy.get("valid", false))
		and int(privacy.get("public_skill_card_disclosure_count", -1)) == 0
		and int(privacy.get("future_skill_target_disclosure_count", -1)) == 0,
		"public projection privacy report is clean"
	)
	_expect(
		not public_text.contains("skill.owner.1")
		and not public_text.contains("request.visibility.001")
		and not public_text.contains("facility.target.001")
		and not public_text.contains("cooldown_remaining_batches"),
		"public projection contains no card, request, target, or cooldown detail"
	)
	var asset_receipt := Core.build_asset_reservation_receipt(
		submitted.get("asset_reservation_request") as Dictionary,
		true,
		"reservation_committed",
		2
	)
	var reserved := Core.apply_asset_reservation_receipt(
		state,
		asset_receipt
	)
	state = reserved.get("state") as Dictionary
	var pending_public_source := (
		Core.public_projection(state).get("sources") as Array
	)[0] as Dictionary
	_expect(
		int(pending_public_source.get(
			"batch_active_skill_use_count",
			-1
		)) == 0,
		"a pending private request does not disclose the batch use"
	)
	var resolved := Fixture.resolve(state)
	var resolved_public_source := (
		Core.public_projection(
			resolved.get("state") as Dictionary
		).get("sources") as Array
	)[0] as Dictionary
	_expect(
		int(resolved_public_source.get(
			"batch_active_skill_use_count",
			-1
		)) == 1,
		"the batch use becomes public only with the public result"
	)
	var leaked := public_projection.duplicate(true)
	leaked["skill_definition_id"] = "skill.owner.1"
	_expect(
		not bool(Core.public_projection_privacy_report(
			leaked
		).get("valid", true)),
		"privacy report rejects injected private skill field"
	)
	_finish()


func _source_ids(projection: Dictionary) -> Array:
	var result: Array[String] = []
	for source_variant in projection.get("sources", []) as Array:
		result.append(str((source_variant as Dictionary).get(
			"source_instance_id",
			""
		)))
	return result


func _skill_count(projection: Dictionary) -> int:
	var result := 0
	for source_variant in projection.get("sources", []) as Array:
		result += ((source_variant as Dictionary).get(
			"skill_cards",
			[]
		) as Array).size()
	return result


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print("V075_MONSTER_PRIVATE_SKILL_VISIBILITY_TEST|%s|%d/%d" % [
		"PASS" if _failures.is_empty() else "FAIL",
		_checks - _failures.size(),
		_checks,
	])
	quit(0 if _failures.is_empty() else 1)
