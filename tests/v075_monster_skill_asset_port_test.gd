extends SceneTree

const AssetCore := preload(
	"res://scripts/v07_semantic/v07_asset_batch_core.gd"
)
const SkillCore := preload(
	"res://scripts/v075/monster/v075_monster_private_skill_core.gd"
)
const Catalog := preload(
	"res://scripts/v075/combat/v075_combat_catalog.gd"
)

class TimeAuthority:
	extends RefCounted
	var records: Dictionary = {}

	func authoritative_time_attestation_v1(attestation_id: String) -> Dictionary:
		return (records.get(attestation_id, {}) as Dictionary).duplicate(true)

var checks := 0
var failures: Array[String] = []
var time_authority := TimeAuthority.new()
var time_sequence := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var player_id := "player.0"
	var source_id := "monster.source.001"
	var family_id := Catalog.monster_family_ids()[0]
	var family := Catalog.monster_family(family_id)
	var source_definition := Catalog.monster_source_definition(family_id)
	var all_skill_definitions := Catalog.monster_skill_definitions()
	var skill_ids: Array[String] = []
	for skill_variant in family.get("skill_definitions", []) as Array:
		skill_ids.append(str((skill_variant as Dictionary).get(
			"skill_definition_id",
			""
		)))
	var skill_definition := _first_costed_skill(all_skill_definitions)
	var skill_id := str(skill_definition.get("skill_definition_id", ""))
	var target_kind := str((skill_definition.get(
		"target_contract",
		{}
	) as Dictionary).get("target_kind", "facility"))
	var source_snapshot := SkillCore.build_source_snapshot(
		source_id,
		1,
		player_id,
		1,
		"active",
		skill_ids,
		skill_ids.slice(0, 1)
	)
	_expect(not source_snapshot.is_empty(), "source snapshot is valid")
	var skill_state := SkillCore.create_state(
		"batch.skill.asset.001",
		[source_snapshot],
		all_skill_definitions,
		0
	)
	_expect(bool(SkillCore.validation_report(skill_state).get(
		"valid",
		false
	)), "private skill authority accepts source fixture")
	var assets := _all_six(6)
	var asset_state := AssetCore.create_state(
		"batch.asset.skill.001",
		[player_id],
		[player_id],
		{player_id: assets},
		{},
		0,
		1000
	)
	_expect(bool(AssetCore.validation_report(asset_state).get(
		"valid",
		false
	)), "asset authority accepts six-color fixture")
	var view := AssetCore.monster_skill_available_asset_view(
		asset_state,
		player_id
	)
	var request := SkillCore.build_request(
		"request.skill.asset.001",
		"batch.skill.asset.001",
		player_id,
		source_id,
		1,
		skill_id,
		{"target_kind": target_kind}
	)
	var submitted := SkillCore.submit_request(skill_state, request, view)
	_expect(bool(submitted.get("accepted", false)), "skill request is accepted against available assets")
	var reservation_request := submitted.get(
		"asset_reservation_request",
		{}
	) as Dictionary
	var prepared := AssetCore.prepare_monster_skill_asset_reservation(
		asset_state,
		reservation_request
	)
	_expect(bool(prepared.get("accepted", false)), "asset owner prepares typed private reservation")
	asset_state = prepared.get("state") as Dictionary
	var cost := skill_definition.get("asset_cost_by_color") as Dictionary
	var available_after_reserve := AssetCore.monster_skill_available_asset_view(
		asset_state,
		player_id
	).get("own_available_assets") as Dictionary
	for color in AssetCore.COLORS:
		_expect(
			int(available_after_reserve.get(color, -1))
			== int(assets.get(color, 0)) - int(cost.get(color, 0)),
			"private reservation reduces only available %s" % color
		)
	var replay_prepare := AssetCore.prepare_monster_skill_asset_reservation(
		asset_state,
		reservation_request
	)
	_expect(bool(replay_prepare.get("replayed", false))
		and replay_prepare.get("state") == asset_state,
		"duplicate private reservation is exact-once replay")
	var public_cost := available_after_reserve.duplicate(true)
	public_cost["any"] = 0
	var public_action := AssetCore.build_prebound_action(
		"action.after.private.reserve.001",
		"normal_card",
		"source.after.private.reserve.001",
		0,
		"card.after.private.reserve.001",
		AssetCore.build_target_binding(
			"binding.after.private.reserve.001",
			["target.after.private.reserve.001"],
			1
		),
		"effect.after.private.reserve.001",
		public_cost,
		_all_six(0)
	)
	var timed := AssetCore.new()
	timed.bind_time_attestation_authority(time_authority)
	var lock_probe := timed.lock_player_queue(
		asset_state,
		AssetCore.build_lock_intent(
			"intent.after.private.reserve.001",
			"batch.asset.skill.001",
			player_id,
			1000,
			[public_action]
		),
		_all_six(0),
		_attestation(1000),
		[player_id]
	)
	_expect(bool(lock_probe.get("accepted", false)),
		"public queue locks against assets left after private reservation")
	var lock_probe_player := (((lock_probe.get("state") as Dictionary).get(
		"players"
	) as Dictionary).get(player_id) as Dictionary)
	_expect(
		(lock_probe_player.get("reservations") as Dictionary).has(
			reservation_request.get("reservation_id")
		),
		"public lock preserves the private reservation identity"
	)
	_expect(lock_probe_player.get("reserved_totals") == _all_six(6),
		"public and private reservations share one exact owner total")
	_expect(bool(AssetCore.validation_report(
		lock_probe.get("state") as Dictionary
	).get("valid", false)), "mixed reservation state validates")
	var asset_receipt := SkillCore.build_asset_reservation_receipt(
		reservation_request,
		true,
		"asset_reservation_accepted",
		int(asset_state.get("revision", 0))
	)
	var applied := SkillCore.apply_asset_reservation_receipt(
		submitted.get("state") as Dictionary,
		asset_receipt
	)
	skill_state = applied.get("state") as Dictionary
	var ready := SkillCore.take_next_ready_request(skill_state)
	_expect(bool(ready.get("accepted", false)), "reserved skill reaches safe boundary")
	skill_state = ready.get("state") as Dictionary
	var effect_receipt := SkillCore.build_effect_receipt(
		ready.get("execution_intent") as Dictionary,
		true,
		"resolved",
		{"target_kind": target_kind, "target_id": "facility.enemy.001"},
		{"damage_amount": 1}
	)
	var resolved := SkillCore.resolve_current(skill_state, effect_receipt)
	_expect(bool(resolved.get("accepted", false)), "skill resolution emits settlement intent")
	skill_state = resolved.get("state") as Dictionary
	var settlement_intent := resolved.get("asset_settlement_intent") as Dictionary
	var settled := AssetCore.commit_monster_skill_asset_reservation(
		asset_state,
		settlement_intent
	)
	_expect(bool(settled.get("accepted", false)), "successful skill commits typed asset settlement")
	asset_state = settled.get("state") as Dictionary
	var expected_assets := assets.duplicate(true)
	for color in AssetCore.COLORS:
		expected_assets[color] = int(expected_assets.get(color, 0)) - int(cost.get(color, 0))
	_expect(
		((asset_state.get("players") as Dictionary).get(player_id) as Dictionary).get(
			"assets"
		) == expected_assets,
		"successful skill debits exactly its authored cost"
	)
	_expect(
		((asset_state.get("players") as Dictionary).get(player_id) as Dictionary).get(
			"reserved_totals"
		) == _all_six(0),
		"successful settlement releases the reservation ledger"
	)
	var replay_settle := AssetCore.commit_monster_skill_asset_reservation(
		asset_state,
		settlement_intent
	)
	_expect(bool(replay_settle.get("replayed", false))
		and replay_settle.get("state") == asset_state,
		"duplicate settlement has no second debit")

	_test_public_reservation_blocks_skill(
		all_skill_definitions,
		family,
		skill_definition,
		skill_id,
		source_id,
		target_kind
	)
	_test_fizzle_releases(
		asset_state,
		all_skill_definitions,
		family,
		skill_definition,
		skill_id,
		source_id,
		target_kind
	)
	_expect(bool(AssetCore.validation_report(asset_state).get(
		"valid",
		false
	)), "settled asset state remains valid")
	_finish()

func _test_public_reservation_blocks_skill(
	all_skill_definitions: Array,
	family: Dictionary,
	skill_definition: Dictionary,
	skill_id: String,
	source_id: String,
	target_kind: String
) -> void:
	var player_id := "player.0"
	var asset_state := AssetCore.create_state(
		"batch.asset.public-reservation.001",
		[player_id],
		[player_id],
		{player_id: _all_six(6)},
		{},
		0,
		1000
	)
	var chosen_color := ""
	for color in AssetCore.COLORS:
		if int((skill_definition.get("asset_cost_by_color") as Dictionary).get(color, 0)) > 0:
			chosen_color = color
			break
	if chosen_color.is_empty():
		_expect(false, "fixture skill has a positive authored color cost")
		return
	var public_cost := _all_six(0)
	public_cost["any"] = 0
	public_cost[chosen_color] = 6
	var action := AssetCore.build_prebound_action(
		"action.public.reserve.001",
		"normal_card",
		"source.public.reserve.001",
		0,
		"card.public.reserve.001",
		AssetCore.build_target_binding(
			"binding.public.reserve.001",
			["target.public.reserve.001"],
			1
		),
		"effect.public.reserve.001",
		public_cost,
		_all_six(0)
	)
	var timed := AssetCore.new()
	timed.bind_time_attestation_authority(time_authority)
	var attestation := _attestation(1000)
	var locked := timed.lock_player_queue(
		asset_state,
		AssetCore.build_lock_intent(
			"intent.public.reserve.001",
			"batch.asset.public-reservation.001",
			player_id,
			1000,
			[action]
		),
		_all_six(0),
		attestation,
		[player_id]
	)
	_expect(bool(locked.get("accepted", false)), "public action reservation locks")
	asset_state = locked.get("state") as Dictionary
	var family_id := str(family.get("monster_family_id", ""))
	var skill_ids: Array[String] = []
	for row_variant in family.get("skill_definitions", []) as Array:
		skill_ids.append(str((row_variant as Dictionary).get(
			"skill_definition_id",
			""
		)))
	var snapshot := SkillCore.build_source_snapshot(
		source_id,
		1,
		player_id,
		1,
		"active",
		skill_ids,
		skill_ids.slice(0, 1)
	)
	var skill_state := SkillCore.create_state(
		"batch.skill.public-reservation.001",
		[snapshot],
		all_skill_definitions,
		0
	)
	var view := AssetCore.monster_skill_available_asset_view(asset_state, player_id)
	_expect(
		int((view.get("own_available_assets") as Dictionary).get(
			chosen_color,
			-1
		)) == 0,
		"public reservation is excluded from the private available view"
	)
	var adversarial_view := view.duplicate(true)
	(adversarial_view.get("own_available_assets") as Dictionary)[
		chosen_color
	] = 6
	var request := SkillCore.build_request(
		"request.skill.public-reservation.001",
		"batch.skill.public-reservation.001",
		player_id,
		source_id,
		1,
		skill_id,
		{"target_kind": target_kind}
	)
	var submitted := SkillCore.submit_request(
		skill_state,
		request,
		adversarial_view
	)
	var reservation_request := submitted.get("asset_reservation_request", {}) as Dictionary
	var prepared := AssetCore.prepare_monster_skill_asset_reservation(
		asset_state,
		reservation_request
	)
	_expect(not bool(prepared.get("accepted", true))
		and prepared.get("reason_code") == "available_unreserved_assets_insufficient",
		"private skill cannot consume public reserved assets")

func _test_fizzle_releases(
	asset_state: Dictionary,
	all_skill_definitions: Array,
	family: Dictionary,
	skill_definition: Dictionary,
	skill_id: String,
	source_id: String,
	target_kind: String
) -> void:
	var player_id := "player.0"
	var before := asset_state.duplicate(true)
	var skill_ids: Array[String] = []
	for row_variant in family.get("skill_definitions", []) as Array:
		skill_ids.append(str((row_variant as Dictionary).get(
			"skill_definition_id",
			""
		)))
	var snapshot := SkillCore.build_source_snapshot(
		"monster.source.002",
		1,
		player_id,
		1,
		"active",
		skill_ids,
		skill_ids.slice(0, 1)
	)
	var skill_state := SkillCore.create_state(
		"batch.skill.fizzle.001",
		[snapshot],
		all_skill_definitions,
		0
	)
	var view := AssetCore.monster_skill_available_asset_view(asset_state, player_id)
	var request := SkillCore.build_request(
		"request.skill.fizzle.001",
		"batch.skill.fizzle.001",
		player_id,
		"monster.source.002",
		1,
		skill_id,
		{"target_kind": target_kind}
	)
	var submitted := SkillCore.submit_request(skill_state, request, view)
	var reservation_request := submitted.get("asset_reservation_request") as Dictionary
	var prepared := AssetCore.prepare_monster_skill_asset_reservation(
		asset_state,
		reservation_request
	)
	_expect(bool(prepared.get("accepted", false)), "fizzle fixture reserves assets")
	asset_state = prepared.get("state") as Dictionary
	var receipt := SkillCore.build_asset_reservation_receipt(
		reservation_request,
		true,
		"asset_reservation_accepted",
		int(asset_state.get("revision", 0))
	)
	skill_state = SkillCore.apply_asset_reservation_receipt(
		submitted.get("state") as Dictionary,
		receipt
	).get("state") as Dictionary
	var ready := SkillCore.take_next_ready_request(skill_state)
	skill_state = ready.get("state") as Dictionary
	var effect := SkillCore.build_effect_receipt(
		ready.get("execution_intent") as Dictionary,
		false,
		"source_destroyed_at_boundary",
		{},
		{}
	)
	var resolved := SkillCore.resolve_current(skill_state, effect)
	var settlement := resolved.get("asset_settlement_intent") as Dictionary
	var released := AssetCore.release_monster_skill_asset_reservation(
		asset_state,
		settlement
	)
	_expect(bool(released.get("accepted", false)), "fizzle releases the typed reservation")
	asset_state = released.get("state") as Dictionary
	_expect(
		((asset_state.get("players") as Dictionary).get(player_id) as Dictionary).get(
			"assets"
		) == ((before.get("players") as Dictionary).get(player_id) as Dictionary).get(
			"assets"
		),
		"fizzle refunds all reserved assets"
	)
	_expect(int(released.get("asset_debit_count", 1)) == 0,
		"fizzle has zero asset debit")

func _first_costed_skill(definitions: Array) -> Dictionary:
	for variant in definitions:
		var definition := variant as Dictionary
		var cost := definition.get("asset_cost_by_color", {}) as Dictionary
		for color in AssetCore.COLORS:
			if int(cost.get(color, 0)) > 0:
				return definition.duplicate(true)
	return (definitions[0] as Dictionary).duplicate(true)

func _all_six(value: int) -> Dictionary:
	return {
		"life": value,
		"energy": value,
		"industry": value,
		"technology": value,
		"commerce": value,
		"shipping": value,
	}

func _attestation(observed_at_ms: int) -> Dictionary:
	time_sequence += 1
	var result := {
		"schema_version": 1,
		"interface_id": AssetCore.TIME_ATTESTATION_INTERFACE_ID,
		"attestation_id": "time.asset.%03d" % time_sequence,
		"observed_at_ms": observed_at_ms,
	}
	result["attestation_fingerprint"] = AssetCore._fingerprint(result)
	time_authority.records[result.get("attestation_id")] = result.duplicate(true)
	return result

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _finish() -> void:
	print("V075_MONSTER_SKILL_ASSET_PORT_TEST|status=%s|passed=%d|total=%d|failures=%s" % [
		"PASS" if failures.is_empty() else "FAIL",
		checks - failures.size(),
		checks,
		JSON.stringify(failures),
	])
	quit(0 if failures.is_empty() else 1)