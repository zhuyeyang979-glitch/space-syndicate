extends SceneTree

const Core := preload(
	"res://scripts/v07_semantic/v073_fixed_order_facility_contention_core.gd"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_contract_identity_and_detachment()
	_test_layered_round_robin_matrix()
	_test_empty_queue_skip_and_single_player_tail()
	_test_unique_slot_identity()
	_test_explicit_locked_modes_and_closed_none()
	_test_authoritative_typed_revalidation()
	_test_build_contention_fizzle_exact_once()
	_test_starter_zero_cost_contention_fizzle()
	_test_save_restore_order_and_exact_once()
	_test_anonymous_public_and_private_viewer_boundaries()
	_test_no_auction_runtime_contracts()
	_finish()


func _test_contract_identity_and_detachment() -> void:
	var contract := Core.contract_snapshot()
	var instance: Variant = Core.new()
	_expect(instance is RefCounted and not is_instance_of(instance, Node), "Core is a detached non-Node RefCounted")
	instance = null
	_expect(
		contract.get("ruleset_id") == "v0.7.3"
			and contract.get("balance_profile_id")
				== "V073_STARTER_FREE_FIXED_ORDER_CONTENTION",
		"Core targets the frozen V0.7.3 profile"
	)
	_expect(
		contract.get("resolution_order_mode") == "fixed_hidden_round_robin"
			and contract.get("resolution_order_source")
				== "frozen_hidden_lead_order_at_batch_lock"
			and contract.get("resolution_order_writer") == "lock_batch"
			and contract.get("resolution_order_writer_count") == 1
			and contract.get("resolution_order_modifier_count") == 0,
		"batch lock is the sole fixed resolution-order writer"
	)
	_expect(
		contract.get("resolution_order_mutation_after_batch_lock") == false
			and contract.get("maximum_actions_per_player") == 5
			and contract.get("layered_round_robin") == true,
		"locked order is immutable and queues are bounded to five actions"
	)
	_expect(
		contract.get("facility_slot_key_fields")
			== ["region_id", "facility_type", "industry_id"]
			and contract.get("facility_action_modes")
				== ["BUILD_NEW", "UPGRADE_OWN", "REPAIR_OWN"],
		"slot identity and explicit facility modes are closed contracts"
	)
	_expect(
		contract.get("production_runtime_connection_count") == 0
			and contract.get("v06_mutation_count") == 0
			and contract.get("dual_write_count") == 0
			and contract.get("detached") == true,
		"V0.7.3 Core has no production connection, V0.6 mutation, or dual write"
	)
	var source := FileAccess.get_file_as_string(
		"res://scripts/v07_semantic/v073_fixed_order_facility_contention_core.gd"
	)
	_expect(
		not source.contains("res://scenes/")
			and not source.contains("scripts/main.gd")
			and not source.contains("main.tscn")
			and not source.contains("RandomNumberGenerator")
			and not source.contains("V06SaveOwnerRegistry"),
		"Core source has no scene, Main, RNG, or production Save Owner dependency"
	)


func _test_layered_round_robin_matrix() -> void:
	for player_count in [3, 4, 6, 8]:
		var players: Array[String] = []
		for player_index in range(player_count):
			players.append("player.%d" % player_index)
		var frozen_order := players.duplicate()
		frozen_order.reverse()
		var queues := {}
		var slots: Array = []
		for player_index in range(player_count):
			var player_id := players[player_index]
			var action_count := player_index % 6
			var queue: Array = []
			for local_index in range(action_count):
				var tag := "matrix_%d_%d_%d" % [player_count, player_index, local_index]
				queue.append(_build_action(player_id, local_index, tag, slots))
			queues[player_id] = queue
		var state := Core.lock_batch(
			"batch.matrix_%d" % player_count,
			players,
			frozen_order,
			queues,
			slots
		)
		_expect(
			not state.is_empty() and Core.validation_report(state).get("valid") == true,
			"%d-player layered state validates" % player_count
		)
		var expected_action_ids: Array[String] = []
		for local_index in range(5):
			for player_id in frozen_order:
				var queue := queues.get(player_id) as Array
				if local_index < queue.size():
					expected_action_ids.append(
						str((queue[local_index] as Dictionary).get("action_id", ""))
					)
		var observed_action_ids: Array[String] = []
		for row_variant in state.get("authority_queue") as Array:
			observed_action_ids.append(str((row_variant as Dictionary).get("action_id", "")))
		_expect(
			observed_action_ids == expected_action_ids,
			"%d-player queue layers one action per player in frozen order" % player_count
		)
		var public := Core.public_projection(state)
		_expect(
			(public.get("anonymous_global_queue") as Array).size()
				== observed_action_ids.size()
				and not public.has("frozen_hidden_lead_order_at_batch_lock"),
			"%d-player public queue preserves order length without exposing the source" % player_count
		)
		var proposed := frozen_order.duplicate()
		proposed.reverse()
		var rejected := Core.attempt_resolution_order_mutation(state, proposed, "cash")
		_expect(
			rejected.get("accepted") == false
				and rejected.get("reason_code")
					== "resolution_order_immutable_after_batch_lock"
				and rejected.get("state") == state,
			"%d-player order rejects cash modification with zero mutation" % player_count
		)


func _test_empty_queue_skip_and_single_player_tail() -> void:
	var players := ["player.a", "player.b", "player.c"]
	var slots: Array = []
	var queues := {
		"player.a": [],
		"player.b": [],
		"player.c": [],
	}
	queues["player.b"] = [_build_action("player.b", 0, "tail_b_0", slots)]
	for local_index in range(5):
		(queues["player.a"] as Array).append(
			_build_action("player.a", local_index, "tail_a_%d" % local_index, slots)
		)
	var state := Core.lock_batch(
		"batch.tail",
		players,
		["player.b", "player.a", "player.c"],
		queues,
		slots
	)
	var observed: Array[String] = []
	for row_variant in state.get("authority_queue") as Array:
		observed.append(str((row_variant as Dictionary).get("action_id", "")))
	_expect(
		observed == [
			"action.tail_b_0",
			"action.tail_a_0",
			"action.tail_a_1",
			"action.tail_a_2",
			"action.tail_a_3",
			"action.tail_a_4",
		],
		"empty players are skipped and the sole remaining player's tail is consecutive"
	)
	var empty_state := Core.lock_batch(
		"batch.empty",
		players,
		["player.b", "player.a", "player.c"],
		{"player.a": [], "player.b": [], "player.c": []},
		[]
	)
	_expect(
		empty_state.get("status") == "resolved"
			and (empty_state.get("authority_queue") as Array).is_empty()
			and Core.validation_report(empty_state).get("valid") == true,
		"zero-action queues lock as an already resolved valid batch"
	)
	var too_many_slots: Array = []
	var too_many: Array = []
	for index in range(6):
		var slot := Core.build_empty_slot(
			"region.too_many_%d" % index,
			0,
			"factory",
			"life",
			0
		)
		too_many_slots.append(slot)
		if index < 5:
			too_many.append(
				Core.build_new_action(
					"action.too_many_%d" % index,
					"source.too_many_%d" % index,
					"player.a",
					index,
					slot,
					_assets(0)
				)
			)
		else:
			var overflow := (too_many[0] as Dictionary).duplicate(true)
			overflow["action_id"] = "action.too_many_5"
			overflow["local_action_index"] = 5
			too_many.append(overflow)
	_expect(
		Core.lock_batch(
			"batch.too_many",
			["player.a"],
			["player.a"],
			{"player.a": too_many},
			too_many_slots
		).is_empty(),
		"six actions for one player fail closed"
	)


func _test_unique_slot_identity() -> void:
	var life_factory := Core.build_empty_slot("region.alpha", 4, "factory", "life", 7)
	var energy_factory := Core.build_empty_slot("region.alpha", 4, "factory", "energy", 0)
	var life_market := Core.build_empty_slot("region.alpha", 4, "market", "life", 0)
	var other_region := Core.build_empty_slot("region.beta", 1, "factory", "life", 0)
	_expect(
		life_factory.get("slot_id") == "slot.region.alpha.factory.life"
			and energy_factory.get("slot_id") == "slot.region.alpha.factory.energy"
			and life_market.get("slot_id") == "slot.region.alpha.market.life"
			and other_region.get("slot_id") == "slot.region.beta.factory.life",
		"region, facility type, and industry form the exact unique slot identity"
	)
	var action := Core.build_new_action(
		"action.unique",
		"source.unique",
		"player.a",
		0,
		life_factory,
		_assets(1)
	)
	_expect(
		Core.lock_batch(
			"batch.duplicate_slot",
			["player.a"],
			["player.a"],
			{"player.a": [action]},
			[life_factory, life_factory.duplicate(true)]
		).is_empty(),
		"a duplicate region/type/industry slot is rejected"
	)
	var state := Core.lock_batch(
		"batch.unique_slots",
		["player.a"],
		["player.a"],
		{"player.a": [action]},
		[life_factory, energy_factory, life_market, other_region]
	)
	_expect(
		not state.is_empty()
			and (state.get("facility_slots") as Dictionary).size() == 4,
		"distinct slot identities coexist without a second slot entity"
	)


func _test_explicit_locked_modes_and_closed_none() -> void:
	var empty_slot := Core.build_empty_slot("region.mode_build", 2, "factory", "life", 3)
	var upgrade_slot := Core.build_occupied_slot(
		"region.mode_upgrade",
		5,
		"market",
		"energy",
		8,
		"facility.mode_upgrade",
		2,
		"player.a",
		2,
		0,
		0
	)
	var repair_slot := Core.build_occupied_slot(
		"region.mode_repair",
		6,
		"factory",
		"industry",
		9,
		"facility.mode_repair",
		3,
		"player.a",
		1,
		4,
		2
	)
	var build := Core.build_new_action(
		"action.mode_build",
		"source.mode_build",
		"player.a",
		0,
		empty_slot,
		_assets(1)
	)
	var upgrade := Core.build_upgrade_action(
		"action.mode_upgrade",
		"source.mode_upgrade",
		"player.a",
		1,
		upgrade_slot,
		_assets(2, "energy")
	)
	var repair := Core.build_repair_action(
		"action.mode_repair",
		"source.mode_repair",
		"player.a",
		2,
		repair_slot,
		_assets(1, "industry")
	)
	_expect(
		build.get("facility_action_mode") == "BUILD_NEW"
			and build.get("expected_occupancy") == "empty"
			and build.get("expected_facility_id") == null
			and build.get("expected_facility_generation") == null
			and build.get("expected_owner_id") == null
			and build.get("expected_rank") == null
			and build.get("expected_damage_revision") == null,
		"BUILD_NEW locks an empty slot and all inapplicable fields as closed none"
	)
	_expect(
		upgrade.get("facility_action_mode") == "UPGRADE_OWN"
			and upgrade.get("expected_owner_id") == "player.a"
			and upgrade.get("expected_rank") == 2
			and upgrade.get("expected_damage_revision") == null,
		"UPGRADE_OWN locks exact own facility identity, generation, owner, and rank"
	)
	_expect(
		repair.get("facility_action_mode") == "REPAIR_OWN"
			and repair.get("expected_owner_id") == "player.a"
			and repair.get("expected_rank") == null
			and repair.get("expected_damage_revision") == 4,
		"REPAIR_OWN locks exact own facility and damage revision"
	)
	_expect(
		Core.build_upgrade_action(
			"action.foreign_upgrade",
			"source.foreign_upgrade",
			"player.b",
			0,
			upgrade_slot,
			_assets(1)
		).is_empty()
			and Core.build_repair_action(
				"action.foreign_repair",
				"source.foreign_repair",
				"player.b",
				0,
				repair_slot,
				_assets(1)
			).is_empty(),
		"upgrade and repair cannot bind a rival facility"
	)
	var state := Core.lock_batch(
		"batch.modes",
		["player.a"],
		["player.a"],
		{"player.a": [build, upgrade, repair]},
		[empty_slot, upgrade_slot, repair_slot]
	)
	_expect(Core.validation_report(state).get("valid") == true, "all three explicit modes lock in one valid queue")
	var tampered_build := build.duplicate(true)
	tampered_build["facility_action_mode"] = "UPGRADE_OWN"
	_expect(
		Core.lock_batch(
			"batch.mode_tamper",
			["player.a"],
			["player.a"],
			{"player.a": [tampered_build]},
			[empty_slot]
		).is_empty(),
		"locked mode mutation fails the action fingerprint and cannot auto-convert"
	)


func _test_authoritative_typed_revalidation() -> void:
	var empty_slot := Core.build_empty_slot("region.revalidate_build", 1, "factory", "life", 2)
	var build := Core.build_new_action(
		"action.revalidate_build",
		"source.revalidate_build",
		"player.a",
		0,
		empty_slot,
		_assets(1)
	)
	var occupied_slot := Core.build_occupied_slot(
		"region.revalidate_build",
		2,
		"factory",
		"life",
		3,
		"facility.earlier_build",
		1,
		"player.b",
		1,
		0,
		0
	)
	_expect(
		Core.revalidate_facility_action(build, occupied_slot).get("reason_code")
			== "facility_target_invalid_slot_occupied",
		"BUILD_NEW reports occupied slot before any mode conversion"
	)
	var generation_changed := empty_slot.duplicate(true)
	generation_changed["slot_generation"] = 3
	_expect(
		Core.revalidate_facility_action(build, generation_changed).get("reason_code")
			== "facility_target_invalid_generation_changed",
		"slot generation drift has a typed invalid result"
	)
	var owned_slot := Core.build_occupied_slot(
		"region.revalidate_owned",
		4,
		"market",
		"energy",
		5,
		"facility.revalidate_owned",
		6,
		"player.a",
		2,
		7,
		3
	)
	var upgrade := Core.build_upgrade_action(
		"action.revalidate_upgrade",
		"source.revalidate_upgrade",
		"player.a",
		0,
		owned_slot,
		_assets(2, "energy")
	)
	var owner_changed := owned_slot.duplicate(true)
	owner_changed["owner_id"] = "player.b"
	_expect(
		Core.revalidate_facility_action(upgrade, owner_changed).get("reason_code")
			== "facility_target_invalid_owner_changed",
		"owner drift has a typed invalid result"
	)
	var rank_changed := owned_slot.duplicate(true)
	rank_changed["rank"] = 3
	_expect(
		Core.revalidate_facility_action(upgrade, rank_changed).get("reason_code")
			== "facility_target_invalid_rank_changed",
		"rank drift has a typed invalid result"
	)
	var repair := Core.build_repair_action(
		"action.revalidate_repair",
		"source.revalidate_repair",
		"player.a",
		0,
		owned_slot,
		_assets(1, "energy")
	)
	var damage_changed := owned_slot.duplicate(true)
	damage_changed["damage_revision"] = 8
	_expect(
		Core.revalidate_facility_action(repair, damage_changed).get("reason_code")
			== "facility_target_invalid_damage_changed",
		"damage revision drift has a typed invalid result"
	)
	_expect(
		Core.revalidate_facility_action(upgrade, owned_slot)
			== {"valid": true, "reason_code": "facility_action_resolved"},
		"unchanged authoritative target validates for resolution"
	)


func _test_build_contention_fizzle_exact_once() -> void:
	var slot := Core.build_empty_slot("region.alpha", 10, "factory", "life", 12)
	var action_b := Core.build_new_action(
		"action.b_build",
		"source.b_build",
		"player.b",
		0,
		slot,
		_assets(1)
	)
	var action_a := Core.build_new_action(
		"action.a_build",
		"source.a_build",
		"player.a",
		0,
		slot,
		_assets(1)
	)
	var state := Core.lock_batch(
		"batch.contention",
		["player.a", "player.b"],
		["player.b", "player.a"],
		{"player.a": [action_a], "player.b": [action_b]},
		[slot]
	)
	var first := Core.resolve_next(state)
	_expect(
		first.get("accepted") == true
			and (first.get("receipt") as Dictionary).get("reason_code")
				== "facility_action_resolved"
			and (first.get("receipt") as Dictionary).get("facility_created") == true,
		"earlier player builds the unique life-factory slot"
	)
	state = first.get("state") as Dictionary
	var occupied_after_first := (
		state.get("facility_slots") as Dictionary
	).get("slot.region.alpha.factory.life") as Dictionary
	_expect(
		occupied_after_first.get("owner_id") == "player.b"
			and occupied_after_first.get("slot_generation") == 13,
		"successful build atomically occupies and advances the slot generation"
	)
	var second := Core.resolve_next(state)
	var fizzle := second.get("receipt") as Dictionary
	_expect(
		second.get("accepted") == true
			and fizzle.get("outcome_id") == "facility_action_fizzled"
			and fizzle.get("reason_code")
				== "facility_target_invalid_slot_occupied",
		"later BUILD_NEW Fizzles on authoritative occupied-slot revalidation"
	)
	_expect(
		fizzle.get("asset_reservation_released") == true
			and fizzle.get("asset_reservation_consumed") == false
			and (fizzle.get("asset_release_amount") as Dictionary).get("life") == 1
			and fizzle.get("normal_card_destination") == "discard"
			and fizzle.get("action_slot_refunded") == false
			and fizzle.get("target_reselected") == false,
		"contention Fizzle releases all assets, discards, consumes the action slot, and never reselects"
	)
	_expect(
		fizzle.get("facility_created") == false
			and fizzle.get("facility_upgraded") == false
			and fizzle.get("facility_repaired") == false
			and fizzle.get("exact_once") == true,
		"contention cannot convert BUILD_NEW into upgrade or repair and receipts exact once"
	)
	state = second.get("state") as Dictionary
	var slot_after_fizzle := (
		state.get("facility_slots") as Dictionary
	).get("slot.region.alpha.factory.life") as Dictionary
	_expect(
		slot_after_fizzle == occupied_after_first,
		"failed BUILD_NEW does not mutate the earlier facility"
	)
	var duplicate := Core.resolve_next(state)
	_expect(
		duplicate.get("accepted") == false
			and duplicate.get("reason_code") == "resolution_not_active"
			and duplicate.get("state") == state
			and (state.get("resolution_receipts") as Array).size() == 2,
		"resolved action cannot Fizzle, refund, or discard twice"
	)


func _test_starter_zero_cost_contention_fizzle() -> void:
	var slot := Core.build_empty_slot("region.starter", 0, "market", "commerce", 0)
	var standard := Core.build_new_action(
		"action.standard_first",
		"source.standard_first",
		"player.b",
		0,
		slot,
		_assets(1, "commerce")
	)
	var starter := Core.build_new_action(
		"action.starter_late",
		"source.starter_late",
		"player.a",
		0,
		slot,
		_assets(0),
		"starter_bootstrap"
	)
	var state := Core.lock_batch(
		"batch.starter_contention",
		["player.a", "player.b"],
		["player.b", "player.a"],
		{"player.a": [starter], "player.b": [standard]},
		[slot]
	)
	state = (Core.resolve_next(state).get("state") as Dictionary)
	var result := Core.resolve_next(state)
	var receipt := result.get("receipt") as Dictionary
	_expect(
		receipt.get("reason_code") == "facility_target_invalid_slot_occupied"
			and receipt.get("asset_reservation_released") == true
			and receipt.get("asset_release_amount") == _assets(0)
			and receipt.get("normal_card_destination") == "discard"
			and receipt.get("action_slot_refunded") == false,
		"zero-cost Starter Fizzle releases zero, discards the card, and consumes its action slot"
	)
	_expect(
		Core.build_new_action(
			"action.bad_starter",
			"source.bad_starter",
			"player.a",
			0,
			slot,
			_assets(1),
			"starter_bootstrap"
		).is_empty(),
		"Starter origin cannot carry a nonzero asset reservation"
	)


func _test_save_restore_order_and_exact_once() -> void:
	var slot := Core.build_empty_slot("region.restore", 3, "factory", "technology", 4)
	var action_b := Core.build_new_action(
		"action.restore_b",
		"source.restore_b",
		"player.b",
		0,
		slot,
		_assets(1, "technology")
	)
	var action_a := Core.build_new_action(
		"action.restore_a",
		"source.restore_a",
		"player.a",
		0,
		slot,
		_assets(1, "technology")
	)
	var state := Core.lock_batch(
		"batch.restore",
		["player.a", "player.b"],
		["player.b", "player.a"],
		{"player.a": [action_a], "player.b": [action_b]},
		[slot]
	)
	state = (Core.resolve_next(state).get("state") as Dictionary)
	var save_state := Core.to_save_state(state)
	var restored := Core.restore_save_state(save_state)
	var restored_state := restored.get("state") as Dictionary
	_expect(
		restored.get("restored") == true
			and restored_state.get("frozen_hidden_lead_order_at_batch_lock")
				== ["player.b", "player.a"]
			and restored_state.get("resolution_cursor") == 1,
		"Save/Restore preserves the exact frozen order and resolution cursor"
	)
	var direct_result := Core.resolve_next(state)
	var restored_result := Core.resolve_next(restored_state)
	_expect(
		(restored_result.get("receipt") as Dictionary).get("reason_code")
			== "facility_target_invalid_slot_occupied"
			and restored_result.get("state") == direct_result.get("state"),
		"restored contention produces the same Fizzle without reordering or reselection"
	)
	var resolved_state := restored_result.get("state") as Dictionary
	var resolved_save := Core.to_save_state(resolved_state)
	var resolved_restore := Core.restore_save_state(resolved_save)
	var replay_attempt := Core.resolve_next(resolved_restore.get("state") as Dictionary)
	_expect(
		replay_attempt.get("accepted") == false
			and replay_attempt.get("reason_code") == "resolution_not_active"
			and ((resolved_restore.get("state") as Dictionary).get("resolution_receipts") as Array).size() == 2,
		"Restore cannot repeat facility creation, Fizzle, asset release, or discard"
	)
	var tampered := save_state.duplicate(true)
	(tampered.get("state") as Dictionary)["resolution_cursor"] = 0
	_expect(
		Core.restore_save_state(tampered).get("restored") == false,
		"tampered cursor fails the closed Save fingerprint"
	)


func _test_anonymous_public_and_private_viewer_boundaries() -> void:
	var slots: Array = []
	var action_a := _build_action("player.a", 0, "privacy_a", slots)
	var action_b := _build_action("player.b", 0, "privacy_b", slots)
	var state := Core.lock_batch(
		"batch.privacy",
		["player.a", "player.b"],
		["player.b", "player.a"],
		{"player.a": [action_a], "player.b": [action_b]},
		slots
	)
	var public := Core.public_projection(state)
	_expect(
		not _contains_key_recursive(public, [
			"actor_id",
			"owner_id",
			"source_card_instance_id",
			"target_slot_id",
			"frozen_hidden_lead_order_at_batch_lock",
			"player_local_queues",
		])
			and not _contains_value(public, "player.a")
			and not _contains_value(public, "player.b"),
		"public queue and slot projection directly disclose no owner, target, or full order"
	)
	var ai_a := Core.ai_observation(state, "player.a")
	var player_a := Core.player_projection(state, "player.a")
	_expect(
		(ai_a.get("own_local_queue") as Array).size() == 1
			and (player_a.get("own_local_queue") as Array).size() == 1
			and not _contains_value(ai_a, "action.privacy_b")
			and not _contains_value(player_a, "action.privacy_b"),
		"AI and Player receive their own prebound target but not the rival queue"
	)
	_expect(
		not ai_a.has("frozen_hidden_lead_order_at_batch_lock")
			and not player_a.has("frozen_hidden_lead_order_at_batch_lock")
			and ai_a.get("complete_hidden_order_disclosed") == false
			and player_a.get("complete_hidden_order_disclosed") == false,
		"viewer projections do not expose the complete hidden turn order"
	)
	_expect(
		Core.ai_observation(state, "player.unknown").is_empty()
			and Core.player_projection(state, "player.unknown").is_empty(),
		"unknown viewers fail closed"
	)


func _test_no_auction_runtime_contracts() -> void:
	var contract := Core.contract_snapshot()
	_expect(
		contract.get("initiative_auction_enabled") == false
			and contract.get("resolution_order_bidding_enabled") == false
			and contract.get("cash_can_change_resolution_order") == false,
		"auction and cash order mutation are constitutionally disabled"
	)
	_expect(
		contract.get("initiative_auction_core_count") == 0
			and contract.get("initiative_bid_intent_count") == 0
			and contract.get("initiative_bid_save_field_count") == 0
			and contract.get("initiative_bid_ui_surface_count") == 0
			and contract.get("ai_initiative_bid_policy_count") == 0,
		"Core, Intent, Save, UI, and AI auction contract counts are all zero"
	)
	var slots: Array = []
	var action := _build_action("player.a", 0, "no_auction", slots)
	var state := Core.lock_batch(
		"batch.no_auction",
		["player.a"],
		["player.a"],
		{"player.a": [action]},
		slots
	)
	var save_state := Core.to_save_state(state)
	var ai := Core.ai_observation(state, "player.a")
	var player := Core.player_projection(state, "player.a")
	var public := Core.public_projection(state)
	for runtime_contract in [action, state, save_state, ai, player, public]:
		_expect(
			not _contains_forbidden_runtime_key(runtime_contract),
			"runtime pure-data contract has no auction, bid, or tiebreak field"
		)
	var source := FileAccess.get_file_as_string(
		"res://scripts/v07_semantic/v073_fixed_order_facility_contention_core.gd"
	)
	for rejected_identifier in [
		"class_name V073InitiativeAuctionCore",
		"InitiativeBidIntent",
		"InitiativeBidReservation",
		"InitiativeAuctionReceipt",
		"ResolutionPriorityBidOrder",
	]:
		_expect(
			not source.contains(rejected_identifier),
			"rejected auction identifier %s is absent" % rejected_identifier
		)


func _build_action(
	actor_id: String,
	local_index: int,
	tag: String,
	slots: Array
) -> Dictionary:
	var slot := Core.build_empty_slot(
		"region.%s" % tag,
		0,
		"factory",
		Core.INDUSTRIES[local_index % Core.INDUSTRIES.size()],
		0
	)
	slots.append(slot)
	return Core.build_new_action(
		"action.%s" % tag,
		"source.%s" % tag,
		actor_id,
		local_index,
		slot,
		_assets(0)
	)


func _assets(amount: int, color: String = "life") -> Dictionary:
	var result := {}
	for color_id in Core.COLORS:
		result[color_id] = amount if color_id == color else 0
	return result


func _contains_key_recursive(value: Variant, forbidden: Array) -> bool:
	if value is Array:
		for item_variant in value as Array:
			if _contains_key_recursive(item_variant, forbidden):
				return true
		return false
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if forbidden.has(str(key_variant)) \
					or _contains_key_recursive((value as Dictionary).get(key_variant), forbidden):
				return true
	return false


func _contains_value(value: Variant, forbidden: Variant) -> bool:
	if typeof(value) == typeof(forbidden) and value == forbidden:
		return true
	if value is Array:
		for item_variant in value as Array:
			if _contains_value(item_variant, forbidden):
				return true
	if value is Dictionary:
		for item_variant in (value as Dictionary).values():
			if _contains_value(item_variant, forbidden):
				return true
	return false


func _contains_forbidden_runtime_key(value: Variant) -> bool:
	var exact := [
		"initiative_bid",
		"bid_cash",
		"bid_reservation",
		"bid_rank",
		"bid_histogram",
		"auction_status",
		"auction_receipt",
		"public_tiebreak_cursor",
		"resolution_priority_bid_order",
	]
	if value is Array:
		for item_variant in value as Array:
			if _contains_forbidden_runtime_key(item_variant):
				return true
		return false
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			if exact.has(key) or key.begins_with("initiative_bid_") \
					or key.begins_with("auction_"):
				return true
			if _contains_forbidden_runtime_key((value as Dictionary).get(key_variant)):
				return true
	return false


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"V073_FIXED_ORDER_FACILITY_CONTENTION_CORE_TEST|status=PASS|checks=%d|failures=0"
				% _checks
		)
		quit(0)
		return
	for failure in _failures:
		push_error("V073_FIXED_ORDER_FACILITY_CONTENTION_CORE_TEST|%s" % failure)
	push_error(
		"V073_FIXED_ORDER_FACILITY_CONTENTION_CORE_TEST|status=FAIL|checks=%d|failures=%d"
			% [_checks, _failures.size()]
	)
	quit(1)
