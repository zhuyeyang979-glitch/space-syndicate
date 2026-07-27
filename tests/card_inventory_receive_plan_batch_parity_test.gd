extends SceneTree

const SESSION_DRIVER := preload("res://tests/support/production_session_start_driver.gd")
const QA_SAVE_PATH := "user://test_runs/card_inventory_receive_plan_batch_parity.save"
const REQUESTED_CARD_IDS := [
	"facility.factory.life.rank_1",
	"commodity.star_dew_berry.rank_1",
	"facility.factory.life.rank_1",
	"interaction.phase_veto.rank_1",
]
const UNIQUE_CARD_IDS := [
	"facility.factory.life.rank_1",
	"commodity.star_dew_berry.rank_1",
	"interaction.phase_veto.rank_1",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var start: Dictionary = await SESSION_DRIVER.start_configured_session(
		self,
		{
			"player_count": 3,
			"ai_player_count": 2,
			"challenge_depth": 1,
			"role_indices": [0, 1, 2],
			"starter_monster_indices": [0, 1, 2],
		},
		QA_SAVE_PATH,
		"card-inventory-receive-plan-batch-parity"
	)
	var app_root := start.get("main_root") as Node
	var coordinator := start.get("coordinator") as GameRuntimeCoordinator
	_expect(
		bool(start.get("started", false)) and coordinator != null,
		"production session starts with the card inventory query composition"
	)
	if coordinator == null:
		await _finish(app_root)
		return

	coordinator.pause_session()
	await process_frame
	var query := coordinator.district_supply_runtime_query_port()
	var inventory := coordinator.commodity_card_inventory_runtime_controller()
	var region_supply := coordinator.get_node_or_null(
		"RegionSupplyRuntimeController"
	) as RegionSupplyRuntimeController
	var ai := coordinator.get_node_or_null("AiRuntimeController") as AiRuntimeController
	var rng := coordinator.get_node_or_null("RunRngService") as RunRngService
	var world := coordinator.world_session_state()
	_expect(
		query != null and inventory != null and region_supply != null
			and ai != null and rng != null and world != null,
		"production owners and the capability-bound query port are composed"
	)
	if query == null or inventory == null or region_supply == null \
			or ai == null or rng == null or world == null:
		await _finish(app_root)
		return

	var capability_variant: Variant = ai.get(
		"_district_supply_ai_query_capability"
	)
	var capability := capability_variant as DistrictSupplyAiQueryCapability
	_expect(capability != null, "AI owns the opaque production query capability")
	if capability == null:
		await _finish(app_root)
		return

	var inventory_before := inventory.to_save_data()
	var supply_before := region_supply.to_save_data()
	var rng_before := rng.capture_plan_checkpoint()
	var actor_before := inventory.player_snapshot("player.1")
	var world_before := JSON.stringify(world.to_save_data())

	var scalar_plans: Dictionary = {}
	for card_id in UNIQUE_CARD_IDS:
		scalar_plans[card_id] = query.private_inventory_plan_for_actor(
			capability,
			1,
			card_id
		)
	var batch := query.private_inventory_plans_for_actor(
		capability,
		1,
		REQUESTED_CARD_IDS
	)
	var batch_card_ids: Array = batch.get("card_ids", []) \
		if batch.get("card_ids", []) is Array else []
	var batch_plans: Dictionary = batch.get("plans_by_card_id", {}) \
		if batch.get("plans_by_card_id", {}) is Dictionary else {}
	_expect(
		bool(batch.get("accepted", false))
			and str(batch.get("reason_code", ""))
				== "region_supply_receive_previews_ready",
		"authorized batch preview is accepted"
	)
	_expect(
		batch_card_ids == UNIQUE_CARD_IDS,
		"batch preserves first-seen card order and removes duplicate IDs"
	)
	_expect(
		batch_plans.keys() == UNIQUE_CARD_IDS,
		"plan dictionary order matches the normalized card ID order"
	)
	if batch_plans != scalar_plans:
		print(
			"CARD_INVENTORY_BATCH_PARITY_DIAG|%s"
			% JSON.stringify(_plan_shape_mismatches(scalar_plans, batch_plans))
		)
	_expect(
		batch_plans == scalar_plans,
		"every batched receive plan exactly matches its scalar projection"
	)
	_expect(
		int(batch.get("player_revision", -1))
			== int(actor_before.get("revision", -2)),
		"batch binds every plan to the same authoritative player revision"
	)

	var null_capability := query.private_inventory_plans_for_actor(
		null,
		1,
		UNIQUE_CARD_IDS
	)
	var forged_capability := query.private_inventory_plans_for_actor(
		DistrictSupplyAiQueryCapability.new(),
		1,
		UNIQUE_CARD_IDS
	)
	var wrong_actor := query.private_inventory_plans_for_actor(
		capability,
		0,
		UNIQUE_CARD_IDS
	)
	var invalid_actor := query.private_inventory_plans_for_actor(
		capability,
		99,
		UNIQUE_CARD_IDS
	)
	_expect(null_capability.is_empty(), "null capability fails closed")
	_expect(forged_capability.is_empty(), "forged capability fails closed")
	_expect(
		wrong_actor.is_empty(),
		"the production capability cannot read the human actor inventory"
	)
	_expect(invalid_actor.is_empty(), "out-of-roster actor fails closed")

	if not batch_plans.is_empty():
		var first_plan_variant: Variant = batch_plans.get(UNIQUE_CARD_IDS[0], {})
		if first_plan_variant is Dictionary:
			(first_plan_variant as Dictionary)["ready"] = not bool(
				(first_plan_variant as Dictionary).get("ready", false)
			)
	var scalar_after_output_mutation := query.private_inventory_plan_for_actor(
		capability,
		1,
		UNIQUE_CARD_IDS[0]
	)
	_expect(
		scalar_after_output_mutation == scalar_plans.get(UNIQUE_CARD_IDS[0], {}),
		"returned batch plans are detached from the inventory owner"
	)

	_expect(
		JSON.stringify(world.to_save_data()) == world_before,
		"scalar, batch, and hostile previews do not mutate WorldSessionState"
	)
	_expect(
		inventory.to_save_data() == inventory_before
			and inventory.player_snapshot("player.1") == actor_before,
		"scalar, batch, and hostile previews do not mutate the inventory owner"
	)
	_expect(
		region_supply.to_save_data() == supply_before,
		"inventory previews do not refill or mutate RegionSupply"
	)
	_expect(
		rng.capture_plan_checkpoint() == rng_before,
		"scalar, batch, and hostile previews consume zero RunRngService draws"
	)

	await _finish(app_root)


func _plan_shape_mismatches(scalar_plans: Dictionary, batch_plans: Dictionary) -> Array:
	var result: Array = []
	for card_id in UNIQUE_CARD_IDS:
		var scalar_variant: Variant = scalar_plans.get(card_id, {})
		var batch_variant: Variant = batch_plans.get(card_id, {})
		var scalar: Dictionary = scalar_variant as Dictionary \
			if scalar_variant is Dictionary else {}
		var batched: Dictionary = batch_variant as Dictionary \
			if batch_variant is Dictionary else {}
		if scalar == batched:
			continue
		result.append({
			"card_id": card_id,
			"scalar_keys": scalar.keys(),
			"batch_keys": batched.keys(),
		})
	return result


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % label)
		return
	_failures.append(label)
	push_error("FAIL: %s" % label)


func _finish(app_root: Node) -> void:
	if app_root != null:
		app_root.queue_free()
	await process_frame
	if _failures.is_empty():
		print(
			"CARD_INVENTORY_RECEIVE_PLAN_BATCH_PARITY_TEST|status=PASS|checks=%d|failures=0"
			% _checks
		)
		quit(0)
		return
	print(
		"CARD_INVENTORY_RECEIVE_PLAN_BATCH_PARITY_TEST|status=FAIL|checks=%d|failures=%d|details=%s"
		% [_checks, _failures.size(), JSON.stringify(_failures)]
	)
	quit(1)
