extends SceneTree

const Core := preload("res://scripts/v07_semantic/v07_asset_batch_core.gd")


class TrustedTimeAttestationAuthority:
	extends RefCounted

	var _ledger: Dictionary = {}

	func commit_attestation(attestation: Dictionary) -> void:
		_ledger[str(attestation.get("attestation_id", ""))] = attestation.duplicate(true)

	func authoritative_time_attestation_v1(attestation_id: String) -> Dictionary:
		if not _ledger.has(attestation_id):
			return {}
		return (_ledger.get(attestation_id) as Dictionary).duplicate(true)


var _checks := 0
var _failures: Array[String] = []
var _timed_core := Core.new()
var _time_authority := TrustedTimeAttestationAuthority.new()
var _time_attestation_sequence := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_timed_core.bind_time_attestation_authority(_time_authority)
	_test_frozen_constitution_contract()
	_test_v072_zero_asset_genesis()
	_test_lock_time_hidden_lead_freeze()
	_test_asset_cycle_freeze_carry_overflow()
	_test_full_queue_atomic_reservation()
	_test_one_shot_window_and_lock_immutability()
	_test_trusted_time_attestation_boundary()
	_test_anonymous_layered_round_robin()
	_test_invalid_target_policy_closure()
	_test_three_wing_projection_and_privacy()
	_test_exact_domain_contract_adapters()
	_test_receipt_adapter_cross_lineage_rejection()
	_test_projected_refresh_after_success()
	_test_save_checkpoint_and_rollback()
	_test_intent_receipt_ledger_reseal_resistance()
	_test_adversarial_atomic_reservation_matrix()
	_test_adversarial_rotation_matrix()
	_test_adversarial_lock_lineage_and_owner_anonymity()
	_test_fail_closed_shapes_and_zero_mutation()
	_finish()


func _test_frozen_constitution_contract() -> void:
	var contract: Dictionary = Core.contract_snapshot()
	var instance: Variant = Core.new()
	_expect(instance is RefCounted and not is_instance_of(instance, Node), "core is non-Node RefCounted")
	instance = null
	_expect(str(contract.get("ruleset_id", "")) == "v0.7.2", "core binds the frozen V0.7.2 target ruleset ID")
	_expect(int(contract.get("state_version", 0)) == 3, "asset and batch authority state upgrades to V0.7.2 state version three")
	_expect(
		contract.get("balance_profile_id") == "V072_STARTER_FREE_FAST"
			and contract.get("balance_profile_fingerprint")
				== "b8f684ab92b06fa44671c38d041ff08b9c1ea7c2950b094705e19192f0a70f48"
			and Core.PROFILE_FINGERPRINT_INPUT.sha256_text()
				== Core.BALANCE_PROFILE_FINGERPRINT,
		"V0.7.2 Starter profile identity is an exact machine contract"
	)
	_expect(contract.get("colors", []) == ["life", "energy", "industry", "technology", "commerce", "shipping"], "core exposes exactly six constitutional colors")
	_expect(int(contract.get("per_color_cap", 0)) == 6, "each color has the independent cap of six")
	_expect(int(contract.get("max_asset_refresh_per_color_per_batch", 0)) == 3, "V0.7.2 profile caps each color refresh at three points per batch")
	_expect(
		contract.get("invalid_target_policy_ids") == [
			"FIZZLE_FULL_ASSET_REFUND",
			"FIZZLE_NO_REFUND",
			"RESOLVE_LEGAL_REMAINDER",
			"DETERMINISTIC_FALLBACK",
		]
			and contract.get("default_invalid_target_policy_id")
				== "FIZZLE_FULL_ASSET_REFUND",
		"invalid-target policy IDs are closed and default to a full asset refund"
	)
	_expect(int(contract.get("window_duration_ms", 0)) == 30000 and bool(contract.get("one_shot", false)), "submission is a thirty-second one-shot window")
	_expect(int(contract.get("maximum_active_actions", 0)) == 5, "all active kinds share the absolute five-action maximum")
	_expect(bool(contract.get("full_queue_atomic_reservation", false)) and bool(contract.get("per_action_reservation", false)), "contract requires atomic full-queue and per-action reservations")
	_expect(not bool(contract.get("future_refresh_can_pay_current_batch", true)), "future refresh cannot fund the current batch")
	_expect(not bool(contract.get("interactive_counters", true)), "interactive counters are retired")
	_expect(str(contract.get("resolution_mode", "")) == "round_robin_by_local_action_index", "resolution layers by local action index")
	_expect(str(contract.get("player_iteration_order", "")) == "frozen_hidden_lead_order", "resolution uses the frozen hidden lead order")
	_expect(contract.get("state_contract_ids", []) == ["V072SixColorAssetState", "V072AssetCycleSnapshot", "V072AssetReservationState", "V072CardBatchState", "V072PreboundTargetState", "V072AnonymousResolutionState"], "asset and batch substate contracts have versioned V0.7.2 identities")

	var state := _state(["player.0", "player.1"], ["player.1", "player.0"], _assets(1))
	_expect(not state.is_empty() and bool(Core.validation_report(state).get("valid", false)), "valid pure authority state is accepted")
	_expect(
		state.get("state_version") == 3
			and state.get("balance_profile_id") == "V072_STARTER_FREE_FAST"
			and state.get("default_invalid_target_policy_id")
				== "FIZZLE_FULL_ASSET_REFUND",
		"authority state persists the V0.7.2 profile and default invalid-target policy"
	)
	_expect(Core.is_pure_data(state), "authority state contains pure data only")
	_expect((state.get("player_ids") as Array).size() == 2 and (state.get("players") as Dictionary).size() == 2, "authority creates one isolated asset owner per player")
	_expect((state.get("submission_hidden_lead_order") as Array) == ["player.1", "player.0"] and (state.get("frozen_hidden_lead_order") as Array).is_empty(), "batch creation stores only a mutable submission-time lead order")
	_expect((state.get("window") as Dictionary).get("deadline_ms") == 31000, "deadline is exactly thirty seconds after opening")

	var privacy: Dictionary = Core.privacy_contract()
	_expect(str(privacy.get("contract_id", "")) == "v072.asset_batch.privacy.v3", "privacy policy is an explicit V0.7.2 V3 contract")
	_expect((privacy.get("authority_secret_fields") as Array).has("submission_hidden_lead_order") and (privacy.get("authority_secret_fields") as Array).has("frozen_hidden_lead_order"), "submission and frozen hidden lead orders are authority-secret")
	_expect((privacy.get("viewer_private_fields") as Array).has("own_assets") and (privacy.get("viewer_private_fields") as Array).has("own_local_queue"), "assets and local queue are viewer-private")
	_expect(not bool(privacy.get("owner_specific_timing_audio_animation_allowed", true)), "owner-specific timing, audio, and animation leaks are forbidden")


func _test_v072_zero_asset_genesis() -> void:
	var players := ["player.0", "player.1", "player.2"]
	var state := Core.create_genesis_state(
		"batch.genesis",
		players,
		["player.1", "player.2", "player.0"],
		1000,
		1000
	)
	_expect(
		not state.is_empty()
			and bool(Core.validation_report(state).get("valid", false)),
		"V0.7.2 genesis creates a valid authority state"
	)
	for player_id in players:
		var player := (state.get("players", {}) as Dictionary).get(
			player_id,
			{}
		) as Dictionary
		_expect(
			player.get("assets") == _zero()
				and player.get("remainders_milli") == _zero(),
			"genesis creates the six-color owner with six zero balances and remainders"
		)
	var contract := Core.contract_snapshot()
	_expect(
		contract.get("initial_assets_per_color") == 0
			and contract.get("initial_remainder_milli_per_color") == 0
			and contract.get("asset_owner_created_at_genesis") == true
			and contract.get("zero_deadlock_mechanism") \
			== "zero_asset_cost_starter_cards",
		"zero assets mean initialized 0/6 pools, not an absent asset owner"
	)
	var ai := Core.asset_ai_observation(state, "player.0")
	var player_projection := Core.asset_player_projection(state, "player.0")
	_expect(
		ai.get("own_exact_assets") == _zero()
			and player_projection.get("own_exact_assets") == _zero(),
		"AI and Player projections receive only their own initialized zero balances"
	)
	var standard_intent := Core.build_lock_intent(
		"intent.genesis.standard-l1",
		"batch.genesis",
		"player.0",
		1100,
		[_action(
			"action.genesis.standard-l1",
			0,
			_cost(1, 0, 0, 0, 0, 0, 0),
			_zero(),
			"target.genesis.standard-l1"
		)]
	)
	var standard_rejection := _lock_player_queue(
		state,
		standard_intent,
		_color_map(6000, 0, 0, 0, 0, 0),
		1100
	)
	_expect(
		not bool(standard_rejection.get("accepted", true))
			and standard_rejection.get("reason_code") == "full_queue_unaffordable"
			and standard_rejection.get("state") == state,
		"zero-asset authority rejects a standard L1 cost even if future refresh is nonzero"
	)
	var starter_intent := Core.build_lock_intent(
		"intent.genesis.starter",
		"batch.genesis",
		"player.0",
		1100,
		[_action(
			"action.genesis.starter",
			0,
			_cost(0, 0, 0, 0, 0, 0, 0),
			_zero(),
			"target.genesis.starter"
		)]
	)
	var starter_lock := _lock_player_queue(
		state,
		starter_intent,
		_zero(),
		1100
	)
	_expect(
		bool(starter_lock.get("accepted", false))
			and (((starter_lock.get("state") as Dictionary).get(
				"players"
			) as Dictionary).get("player.0") as Dictionary).get(
				"reserved_totals"
			) == _zero(),
		"zero-cost Starter action locks legitimately with no asset injection or reservation"
	)


func _test_lock_time_hidden_lead_freeze() -> void:
	var players := ["player.0", "player.1", "player.2"]
	var state := _state(players, ["player.0", "player.1", "player.2"], {
		"player.0": _assets(0),
		"player.1": _assets(0),
		"player.2": _assets(0),
	})
	var opening_order := (state.get("submission_hidden_lead_order") as Array).duplicate()
	_expect(opening_order == players and (state.get("frozen_hidden_lead_order") as Array).is_empty(), "submission opens without a frozen resolution order")

	var first: Dictionary = _lock_player_queue(
		state,
		Core.build_lock_intent(
			"intent.lead-lock.0",
			"batch.test",
			"player.0",
			1100,
			[_action("action.lead-lock.0", 0, _cost(0, 0, 0, 0, 0, 0, 0), _zero(), "target.lead-lock.0")]
		),
		_zero(),
		1100,
		["player.0", "player.1", "player.2"]
	)
	_expect(bool(first.get("accepted", false)), "first local lock may atomically update the live authority order")
	state = first.get("state") as Dictionary
	var updated: Dictionary = Core.update_submission_hidden_lead_order(
		state,
		["player.2", "player.0", "player.1"],
		1200
	)
	_expect(bool(updated.get("accepted", false)), "authority may update hidden lead order while submission remains open")
	state = updated.get("state") as Dictionary
	_expect((state.get("submission_hidden_lead_order") as Array) == ["player.2", "player.0", "player.1"] and (state.get("frozen_hidden_lead_order") as Array).is_empty(), "mid-window update changes only the mutable submission order")

	state = (_lock_player_queue(
		state,
		Core.build_lock_intent(
			"intent.lead-lock.1",
			"batch.test",
			"player.1",
			1300,
			[_action("action.lead-lock.1", 0, _cost(0, 0, 0, 0, 0, 0, 0), _zero(), "target.lead-lock.1")]
		),
		_zero(),
		1300
	).get("state") as Dictionary)
	var lock_time_order := ["player.1", "player.2", "player.0"]
	var final_lock: Dictionary = _lock_player_queue(
		state,
		Core.build_lock_intent(
			"intent.lead-lock.2",
			"batch.test",
			"player.2",
			1400,
			[_action("action.lead-lock.2", 0, _cost(0, 0, 0, 0, 0, 0, 0), _zero(), "target.lead-lock.2")]
		),
		_zero(),
		1400,
		lock_time_order
	)
	_expect(bool(final_lock.get("accepted", false)), "final local lock accepts the current authoritative lead order")
	state = final_lock.get("state") as Dictionary
	lock_time_order.reverse()
	_expect((state.get("frozen_hidden_lead_order") as Array) == ["player.1", "player.2", "player.0"], "global lock freezes a detached copy of the lock-time authority order")
	var action_order: Array[String] = []
	for entry_variant in state.get("authority_queue") as Array:
		action_order.append(str((entry_variant as Dictionary).get("action_id", "")))
	_expect(action_order == ["action.lead-lock.1", "action.lead-lock.2", "action.lead-lock.0"], "anonymous resolution uses lock-time order rather than opening or mid-window order")
	var before_rejected_update := state.duplicate(true)
	var rejected_update: Dictionary = Core.update_submission_hidden_lead_order(
		state,
		["player.0", "player.1", "player.2"],
		1500
	)
	_expect(not bool(rejected_update.get("accepted", true)) and str(rejected_update.get("reason_code", "")) == "hidden_lead_order_already_frozen", "hidden lead order cannot change after global lock")
	_expect(rejected_update.get("state") == before_rejected_update and state == before_rejected_update, "post-lock lead update rejection has zero mutation")


func _test_asset_cycle_freeze_carry_overflow() -> void:
	var initial := {
		"player.0": _color_map(5, 1, 6, 0, 2, 0),
		"player.1": _color_map(0, 0, 0, 0, 0, 0),
	}
	var remainders := {
		"player.0": _color_map(500, 250, 0, 900, 100, 0),
		"player.1": _zero(),
	}
	var state: Dictionary = Core.create_state(
		"batch.asset-cycle",
		["player.0", "player.1"],
		["player.0", "player.1"],
		initial,
		remainders,
		0,
		1000
	)
	var snapshot_0 := _color_map(2000, 750, 1000, 200, 0, 7500)
	var lock_0: Dictionary = _lock_player_queue(
		state,
		Core.build_lock_intent("intent.asset.0", "batch.asset-cycle", "player.0", 100, []),
		snapshot_0,
		100
	)
	_expect(bool(lock_0.get("accepted", false)), "empty local queue may lock and freeze GDP")
	state = lock_0.get("state") as Dictionary
	snapshot_0["shipping"] = 0
	var frozen_0 := ((state.get("players") as Dictionary).get("player.0") as Dictionary).get("frozen_gdp_milli") as Dictionary
	_expect(int(frozen_0.get("shipping", 0)) == 7500, "GDP snapshot is detached and frozen at local lock")
	_expect(
		int((Core.asset_player_projection(state, "player.0").get(
			"own_projected_refresh"
		) as Dictionary).get("shipping", 0)) == 3,
		"viewer projection applies the V0.7.2 three-point refresh cap"
	)

	var snapshot_1 := _color_map(1000, 0, 0, 0, 0, 0)
	var lock_1: Dictionary = _lock_player_queue(
		state,
		Core.build_lock_intent("intent.asset.1", "batch.asset-cycle", "player.1", 101, []),
		snapshot_1,
		101
	)
	_expect(bool(lock_1.get("accepted", false)), "second player freezes an independent own-GDP snapshot")
	state = lock_1.get("state") as Dictionary
	_expect(str((state.get("window") as Dictionary).get("status", "")) == "batch_resolved", "all-empty batch resolves without inventing actions")

	var refreshed: Dictionary = Core.refresh_assets_after_batch(state)
	_expect(bool(refreshed.get("accepted", false)), "frozen snapshots apply once after the whole batch resolves")
	var refreshed_state := refreshed.get("state") as Dictionary
	var player_0 := (refreshed_state.get("players") as Dictionary).get("player.0") as Dictionary
	var player_1 := (refreshed_state.get("players") as Dictionary).get("player.1") as Dictionary
	var assets_0 := player_0.get("assets") as Dictionary
	var remainder_0 := player_0.get("remainders_milli") as Dictionary
	var overflow_0 := player_0.get("refresh_overflow") as Dictionary
	_expect(int(assets_0.get("life", 0)) == 6 and int(overflow_0.get("life", 0)) == 1, "life top-up caps at six and records discarded overflow")
	_expect(int(remainder_0.get("life", 0)) == 500, "fractional life remainder survives overflow")
	_expect(int(assets_0.get("energy", 0)) == 2 and int(remainder_0.get("energy", 0)) == 0, "carry plus frozen GDP creates one energy asset")
	_expect(int(assets_0.get("industry", 0)) == 6 and int(overflow_0.get("industry", 0)) == 1, "full color pool discards whole-unit overflow")
	_expect(int(assets_0.get("technology", 0)) == 1 and int(remainder_0.get("technology", 0)) == 100, "fixed-point remainder combines with the frozen snapshot")
	_expect(int(assets_0.get("commerce", 0)) == 2 and int(remainder_0.get("commerce", 0)) == 100, "unused assets carry over when no whole top-up is earned")
	_expect(int(assets_0.get("shipping", 0)) == 3 and int(remainder_0.get("shipping", 0)) == 500, "post-lock source mutation cannot change the capped shipping refresh")
	_expect(int(overflow_0.get("shipping", 0)) == 4, "whole refresh units above the per-batch cap are recorded as overflow")
	_expect(int((player_1.get("assets") as Dictionary).get("life", 0)) == 1, "one player's GDP refreshes only that player's same-color pool")
	_expect(str((refreshed_state.get("window") as Dictionary).get("status", "")) == "assets_refreshed", "asset refresh has a terminal one-shot state")

	var replay: Dictionary = Core.refresh_assets_after_batch(refreshed_state)
	_expect(not bool(replay.get("accepted", true)) and str(replay.get("reason_code", "")) == "refresh_already_applied", "asset refresh cannot apply twice")
	_expect(replay.get("state") == refreshed_state, "duplicate refresh rejection has zero state mutation")

	var invalid_initial := initial.duplicate(true)
	(invalid_initial.get("player.0") as Dictionary)["life"] = 7
	_expect(Core.create_state("batch.cap-invalid", ["player.0", "player.1"], ["player.0", "player.1"], invalid_initial).is_empty(), "initial assets above six fail closed")


func _test_full_queue_atomic_reservation() -> void:
	var initial := {
		"player.0": _color_map(3, 3, 1, 1, 1, 1),
		"player.1": _assets(0),
	}
	var state := _state(["player.0", "player.1"], ["player.0", "player.1"], initial)
	var action_second := _action("action.atomic.1", 1, _cost(1, 0, 0, 0, 0, 0, 1), _color_map(0, 1, 0, 0, 0, 0), "target.second")
	var action_first := _action("action.atomic.0", 0, _cost(1, 1, 0, 0, 0, 0, 0), _zero(), "target.first")
	var intent := Core.build_lock_intent(
		"intent.atomic.success",
		"batch.test",
		"player.0",
		1000,
		[action_second, action_first]
	)
	var locked: Dictionary = _lock_player_queue(state, intent, _zero(), 1000)
	_expect(bool(locked.get("accepted", false)), "affordable full queue locks atomically")
	var locked_state := locked.get("state") as Dictionary
	var player := (locked_state.get("players") as Dictionary).get("player.0") as Dictionary
	var queue := player.get("local_queue") as Array
	_expect(str((queue[0] as Dictionary).get("action_id", "")) == "action.atomic.0" and str((queue[1] as Dictionary).get("action_id", "")) == "action.atomic.1", "authority sorts the local queue by chosen local order")
	_expect((player.get("reservations") as Dictionary).size() == 2, "each queued action owns an independent reservation")
	_expect((player.get("reservations") as Dictionary).get("action.atomic.0") == _color_map(1, 1, 0, 0, 0, 0), "first action reservation is exact")
	_expect((player.get("reservations") as Dictionary).get("action.atomic.1") == _color_map(1, 1, 0, 0, 0, 0), "any-color payment is bound into the second exact reservation")
	_expect(player.get("reserved_totals") == _color_map(2, 2, 0, 0, 0, 0), "full queue publishes exact private reserved totals")
	_expect(player.get("assets") == initial.get("player.0"), "reservation does not consume assets before authoritative resolution")

	var poor_state := _state(
		["player.0", "player.1"],
		["player.0", "player.1"],
		{"player.0": _color_map(1, 0, 0, 0, 0, 0), "player.1": _assets(0)}
	)
	var poor_intent := Core.build_lock_intent(
		"intent.atomic.failure",
		"batch.test",
		"player.0",
		1000,
		[
			_action("action.poor.0", 0, _cost(1, 0, 0, 0, 0, 0, 0), _zero(), "target.poor.0"),
			_action("action.poor.1", 1, _cost(1, 0, 0, 0, 0, 0, 0), _zero(), "target.poor.1"),
		]
	)
	var poor_before := poor_state.duplicate(true)
	var rejected: Dictionary = _lock_player_queue(poor_state, poor_intent, _color_map(6000, 0, 0, 0, 0, 0), 1000)
	_expect(not bool(rejected.get("accepted", true)) and str(rejected.get("reason_code", "")) == "full_queue_unaffordable", "second-action shortfall rejects the entire queue")
	_expect(rejected.get("state") == poor_before and poor_state == poor_before, "failed full-queue reservation leaves no first-action residue")
	_expect((((rejected.get("state") as Dictionary).get("players") as Dictionary).get("player.0") as Dictionary).get("reservations") == {}, "atomic failure creates no per-action reservation")
	_expect(((rejected.get("state") as Dictionary).get("seen_intent_ids") as Array).is_empty(), "failed lock does not consume the intent identity")
	_expect(str((((rejected.get("state") as Dictionary).get("players") as Dictionary).get("player.0") as Dictionary).get("queue_status", "")) == "open", "failed lock leaves the local queue open")
	var zero_state := _state(
		["player.0"],
		["player.0"],
		{"player.0": _assets(0)}
	)
	_expect(not bool(_lock_player_queue(zero_state, Core.build_lock_intent("intent.future", "batch.test", "player.0", 1000, [_action("action.future", 0, _cost(1, 0, 0, 0, 0, 0, 0), _zero(), "target.future")]), _color_map(6000, 0, 0, 0, 0, 0), 1000).get("accepted", true)), "future six-asset refresh cannot pay one current life cost")

	var wrong_any := Core.build_prebound_action(
		"action.any.invalid",
		"normal_card",
		"source.any.invalid",
		0,
		"card.any.invalid",
		Core.build_target_binding("binding.any.invalid", ["target.any.invalid"], 1),
		"effect.any.invalid",
		_cost(0, 0, 0, 0, 0, 0, 2),
		_color_map(1, 0, 0, 0, 0, 0)
	)
	_expect(wrong_any.is_empty(), "any is a six-pool payment constraint and must be paid exactly")

	var six_actions: Array = []
	for index in range(6):
		six_actions.append(_action("action.six.%d" % index, index, _cost(0, 0, 0, 0, 0, 0, 0), _zero(), "target.six.%d" % index))
	_expect(Core.build_lock_intent("intent.six", "batch.test", "player.0", 1000, six_actions).is_empty(), "a sixth active action is rejected before reservation")


func _test_one_shot_window_and_lock_immutability() -> void:
	var state := _state(
		["player.0", "player.1"],
		["player.1", "player.0"],
		{"player.0": _assets(6), "player.1": _assets(6)}
	)
	var target := Core.build_target_binding("binding.locked", ["region.alpha"], 7)
	var action := Core.build_prebound_action(
		"action.locked",
		"normal_card",
		"source.locked",
		0,
		"card.locked",
		target,
		"effect.locked",
		_cost(1, 0, 0, 0, 0, 0, 0),
		_zero()
	)
	var intent := Core.build_lock_intent("intent.deadline", "batch.test", "player.0", 31000, [action])
	var locked: Dictionary = _lock_player_queue(state, intent, _zero(), 31000)
	_expect(bool(locked.get("accepted", false)), "submission exactly at the thirty-second deadline is accepted")
	var locked_state := locked.get("state") as Dictionary
	var locked_copy := locked_state.duplicate(true)
	(action.get("target_binding") as Dictionary)["target_ids"] = ["region.changed"]
	action["local_order"] = 4
	(intent.get("actions") as Array).clear()
	_expect(locked_state == locked_copy, "locked cards, targets, and local order are detached from caller mutation")
	var stored_action := ((((locked_state.get("players") as Dictionary).get("player.0") as Dictionary).get("local_queue") as Array)[0]) as Dictionary
	_expect(((stored_action.get("target_binding") as Dictionary).get("target_ids") as Array) == ["region.alpha"] and int(stored_action.get("local_order", -1)) == 0, "prebound target and local order remain immutable after lock")

	var duplicate: Dictionary = _lock_player_queue(
		locked_state,
		Core.build_lock_intent("intent.deadline", "batch.test", "player.0", 31000, [stored_action]),
		_zero(),
		31000
	)
	_expect(
		bool(duplicate.get("accepted", false))
			and duplicate.get("receipt") == locked.get("receipt"),
		"identical duplicate intent returns the exact original receipt"
	)
	_expect(duplicate.get("state") == locked_state, "duplicate intent replay has zero mutation")
	var collision: Dictionary = _lock_player_queue(
		locked_state,
		Core.build_lock_intent("intent.deadline", "batch.test", "player.0", 30999, []),
		_zero(),
		31000
	)
	_expect(
		not bool(collision.get("accepted", true))
			and str(collision.get("reason_code", "")) == "intent_id_collision"
			and collision.get("state") == locked_state,
		"same intent identity with a different payload collision-fails without mutation"
	)

	var late_state := _state(["player.0"], ["player.0"], {"player.0": _assets(6)})
	var late_before := late_state.duplicate(true)
	var late: Dictionary = _lock_player_queue(
		late_state,
		Core.build_lock_intent("intent.late", "batch.test", "player.0", 30000, []),
		_zero(),
		31001
	)
	_expect(not bool(late.get("accepted", true)) and str(late.get("reason_code", "")) == "submission_deadline_elapsed", "late authority observation rejects a backdated intent")
	_expect(late.get("state") == late_before and late_state == late_before, "late observed backdated intent has zero mutation")
	var future_dated: Dictionary = _lock_player_queue(
		late_state,
		Core.build_lock_intent("intent.future-dated", "batch.test", "player.0", 2000, []),
		_zero(),
		1999
	)
	_expect(not bool(future_dated.get("accepted", true)) and str(future_dated.get("reason_code", "")) == "submission_after_authority_observation", "submitted time cannot be later than authority observation")
	_expect(future_dated.get("state") == late_before and late_state == late_before, "future-dated intent rejection has zero mutation")
	var negative_observed: Dictionary = _lock_player_queue(
		late_state,
		Core.build_lock_intent("intent.negative-observed", "batch.test", "player.0", 100, []),
		_zero(),
		-1
	)
	_expect(
		not bool(negative_observed.get("accepted", true))
			and str(negative_observed.get("reason_code", ""))
				== "time_attestation_schema_invalid"
			and negative_observed.get("state") == late_before
			and late_state == late_before,
		"negative authority observation fails closed with zero mutation"
	)
	var before_open_observed: Dictionary = _lock_player_queue(
		late_state,
		Core.build_lock_intent("intent.before-open-observed", "batch.test", "player.0", 100, []),
		_zero(),
		999
	)
	_expect(
		not bool(before_open_observed.get("accepted", true))
			and str(before_open_observed.get("reason_code", ""))
				== "authority_observation_time_invalid"
			and before_open_observed.get("state") == late_before
			and late_state == late_before,
		"authority observation before window open fails closed with zero mutation"
	)

	var early_close: Dictionary = _close_expired_window(late_state, 30999, {"player.0": _zero()})
	_expect(not bool(early_close.get("accepted", true)) and str(early_close.get("reason_code", "")) == "submission_window_still_open", "authority cannot expire a live one-shot window early")
	var invalid_close: Dictionary = _close_expired_window(late_state, 31001, {})
	_expect(not bool(invalid_close.get("accepted", true)) and invalid_close.get("state") == late_state, "deadline close validates all GDP snapshots before any auto-lock")
	var closed: Dictionary = _close_expired_window(late_state, 31001, {"player.0": _color_map(0, 0, 1000, 0, 0, 0)})
	_expect(bool(closed.get("accepted", false)), "trusted observation after the deadline auto-locks a missing player")
	_expect(str((((closed.get("state") as Dictionary).get("window") as Dictionary).get("status", ""))) == "batch_resolved", "single empty queue naturally completes the batch")
	var close_replay: Dictionary = _close_expired_window(closed.get("state"), 32000, {"player.0": _zero()})
	_expect(not bool(close_replay.get("accepted", true)) and str(close_replay.get("reason_code", "")) == "one_shot_window_closed", "closed one-shot window never reopens")


func _test_trusted_time_attestation_boundary() -> void:
	var core := Core.new()
	var state := _state(
		["player.0", "player.1"],
		["player.0", "player.1"],
		{"player.0": _assets(1), "player.1": _assets(1)}
	)
	var first_intent := Core.build_lock_intent(
		"intent.time.first",
		"batch.test",
		"player.0",
		1500,
		[]
	)
	var first_attestation := _issue_time_attestation(2000)
	var before := state.duplicate(true)
	var unbound: Dictionary = core.lock_player_queue(
		state,
		first_intent,
		_zero(),
		first_attestation
	)
	_expect(
		not bool(unbound.get("accepted", true))
			and str(unbound.get("reason_code", ""))
				== "time_attestation_authority_unbound"
			and unbound.get("state") == before,
		"unbound time authority rejects a valid attestation without mutation"
	)
	var invalid_binding: Dictionary = core.bind_time_attestation_authority(
		RefCounted.new()
	)
	_expect(
		not bool(invalid_binding.get("bound", true))
			and str(invalid_binding.get("reason_code", ""))
				== "time_attestation_authority_port_invalid",
		"time binding rejects a RefCounted without the authoritative lookup port"
	)

	var wrong_authority := TrustedTimeAttestationAuthority.new()
	var wrong_record := first_attestation.duplicate(true)
	wrong_record["observed_at_ms"] = 2001
	_reseal_domain_contract(wrong_record, "attestation_fingerprint")
	wrong_authority.commit_attestation(wrong_record)
	core.bind_time_attestation_authority(wrong_authority)
	var wrong_port: Dictionary = core.lock_player_queue(
		state,
		first_intent,
		_zero(),
		first_attestation
	)
	_expect(
		not bool(wrong_port.get("accepted", true))
			and str(wrong_port.get("reason_code", ""))
				== "time_attestation_authoritative_record_mismatch"
			and wrong_port.get("state") == before,
		"wrong authority record cannot satisfy exact attestation matching"
	)

	core.bind_time_attestation_authority(_time_authority)
	var forged_attestation := first_attestation.duplicate(true)
	forged_attestation["observed_at_ms"] = 2500
	_reseal_domain_contract(forged_attestation, "attestation_fingerprint")
	var forged: Dictionary = core.lock_player_queue(
		state,
		first_intent,
		_zero(),
		forged_attestation
	)
	_expect(
		not bool(forged.get("accepted", true))
			and str(forged.get("reason_code", ""))
				== "time_attestation_authoritative_record_mismatch"
			and forged.get("state") == before,
		"fully resealed synthetic attestation differs from the exact issued record"
	)
	var foreign_attestation := _issue_time_attestation(
		2100,
		wrong_authority,
		"time.foreign"
	)
	var missing: Dictionary = core.lock_player_queue(
		state,
		first_intent,
		_zero(),
		foreign_attestation
	)
	_expect(
		not bool(missing.get("accepted", true))
			and str(missing.get("reason_code", ""))
				== "time_attestation_authoritative_record_missing"
			and missing.get("state") == before,
		"attestation absent from the bound authority fails closed"
	)

	var first_lock: Dictionary = core.lock_player_queue(
		state,
		first_intent,
		_zero(),
		first_attestation
	)
	var first_state := first_lock.get("state") as Dictionary
	_expect(
		bool(first_lock.get("accepted", false))
			and int((first_state.get("window") as Dictionary).get(
				"time_observation_watermark_ms", -1
			)) == 2000,
		"trusted lock persists its observed time as the authority watermark"
	)
	var stale_attestation := _issue_time_attestation(1999)
	var second_intent := Core.build_lock_intent(
		"intent.time.second",
		"batch.test",
		"player.1",
		1900,
		[]
	)
	var stale_before := first_state.duplicate(true)
	var stale: Dictionary = core.lock_player_queue(
		first_state,
		second_intent,
		_zero(),
		stale_attestation
	)
	_expect(
		not bool(stale.get("accepted", true))
			and str(stale.get("reason_code", "")) == "time_observation_regressed"
			and stale.get("state") == stale_before,
		"trusted but older observation cannot move the persisted watermark backward"
	)
	var second_lock: Dictionary = core.lock_player_queue(
		first_state,
		second_intent,
		_zero(),
		_issue_time_attestation(2500)
	)
	_expect(
		bool(second_lock.get("accepted", false))
			and int(((second_lock.get("state") as Dictionary).get(
				"window"
			) as Dictionary).get("time_observation_watermark_ms", -1)) == 2500,
		"later trusted lock advances the watermark monotonically"
	)

	var close_state := _state(["player.0"], ["player.0"], {"player.0": _assets(0)})
	var at_deadline: Dictionary = core.close_expired_window(
		close_state,
		_issue_time_attestation(31000),
		{"player.0": _zero()}
	)
	_expect(
		not bool(at_deadline.get("accepted", true))
			and str(at_deadline.get("reason_code", ""))
				== "submission_window_still_open",
		"close requires trusted observed time strictly after the deadline"
	)
	var closed: Dictionary = core.close_expired_window(
		close_state,
		_issue_time_attestation(31001),
		{"player.0": _zero()}
	)
	_expect(
		bool(closed.get("accepted", false))
			and int(((closed.get("state") as Dictionary).get(
				"window"
			) as Dictionary).get("time_observation_watermark_ms", -1)) == 31001,
		"trusted post-deadline close persists its exact observation watermark"
	)


func _test_anonymous_layered_round_robin() -> void:
	var players := ["player.0", "player.1", "player.2"]
	var state := _state(players, ["player.2", "player.0", "player.1"], {
		"player.0": _assets(6),
		"player.1": _assets(6),
		"player.2": _assets(6),
	})
	var actions_0 := [
		_action("action.p0.0", 0, _cost(1, 0, 0, 0, 0, 0, 0), _zero(), "target.p0.0"),
		_action("action.p0.1", 1, _cost(0, 1, 0, 0, 0, 0, 0), _zero(), "target.p0.1"),
		_action("action.p0.2", 2, _cost(0, 0, 1, 0, 0, 0, 0), _zero(), "target.p0.2"),
	]
	var actions_2 := [
		_action("action.p2.0", 0, _cost(0, 0, 0, 1, 0, 0, 0), _zero(), "target.p2.0"),
		_action("action.p2.1", 1, _cost(0, 0, 0, 0, 1, 0, 0), _zero(), "target.p2.1"),
	]
	state = (_lock_player_queue(state, Core.build_lock_intent("intent.p0", "batch.test", "player.0", 100, actions_0), _zero(), 1000).get("state") as Dictionary)
	state = (_lock_player_queue(state, Core.build_lock_intent("intent.p1", "batch.test", "player.1", 100, []), _zero(), 1000).get("state") as Dictionary)
	state = (_lock_player_queue(state, Core.build_lock_intent("intent.p2", "batch.test", "player.2", 100, actions_2), _zero(), 1000).get("state") as Dictionary)
	_expect(str((state.get("window") as Dictionary).get("status", "")) == "resolution_ready", "nonempty locked queues enter resolution-ready state")
	var authority_queue := state.get("authority_queue") as Array
	var authority_order: Array[String] = []
	for entry_variant in authority_queue:
		authority_order.append(str((entry_variant as Dictionary).get("action_id", "")))
	_expect(authority_order == ["action.p2.0", "action.p0.0", "action.p2.1", "action.p0.1", "action.p0.2"], "global queue rotates by local layer through frozen hidden lead order")
	_expect(not authority_order.has("player.1"), "empty player queue contributes no skip entry")
	_expect(authority_order.slice(2) == ["action.p2.1", "action.p0.1", "action.p0.2"], "when one player remains its tail resolves consecutively without a special path")

	var public: Dictionary = Core.public_projection(state)
	var anonymous_queue := public.get("anonymous_queue") as Array
	_expect(anonymous_queue.size() == authority_queue.size(), "public queue preserves authoritative resolution length")
	for entry_variant in anonymous_queue:
		var entry := entry_variant as Dictionary
		_expect(_same_string_set(entry.keys(), Core.PUBLIC_QUEUE_FIELDS), "public queue entry uses the V0.7.2 causal-history allowlist")
		_expect(not _contains_key_recursive(entry, ["actor_id", "player_name", "player_color", "avatar", "seat", "player_skip", "source_id", "action_id"]), "public queue entry contains no owner or source clue")
	_expect(not _contains_value(public, "player.2") and not _contains_value(public, "player.0"), "anonymous public queue does not reveal hidden iteration order")
	_expect(not bool(public.get("interactive_counters", true)) and not bool(public.get("new_resolution_input_allowed", true)), "resolution opens neither counters nor new input")

	var wrong_order: Dictionary = Core.settle_next_action(state, "action.p0.0", "success")
	_expect(not bool(wrong_order.get("accepted", true)) and str(wrong_order.get("reason_code", "")) == "resolution_order_mismatch", "only the current anonymous queue entry may settle")
	_expect(wrong_order.get("state") == state, "out-of-order settlement has zero mutation")
	var bad_outcome: Dictionary = Core.settle_next_action(state, "action.p2.0", "countered")
	_expect(not bool(bad_outcome.get("accepted", true)) and str(bad_outcome.get("reason_code", "")) == "resolution_outcome_invalid", "retired Counter cannot appear as a settlement outcome")
	var new_input: Dictionary = Core.reject_resolution_input(state, "counter_request")
	_expect(not bool(new_input.get("accepted", true)) and str(new_input.get("reason_code", "")) == "resolution_accepts_no_new_input", "card-by-card resolution rejects new gameplay input")

	var outcomes := ["success", "rule_allowed_refundable_failure", "success", "success", "success"]
	for index in range(authority_order.size()):
		var settled: Dictionary = Core.settle_next_action(state, authority_order[index], outcomes[index])
		_expect(bool(settled.get("accepted", false)), "queue action %d settles in exact order" % index)
		state = settled.get("state") as Dictionary
	var player_0 := (state.get("players") as Dictionary).get("player.0") as Dictionary
	var player_2 := (state.get("players") as Dictionary).get("player.2") as Dictionary
	_expect(int((player_2.get("assets") as Dictionary).get("technology", 0)) == 5, "successful action consumes only its own reservation")
	_expect(int((player_0.get("assets") as Dictionary).get("life", 0)) == 6, "refundable failure releases only its own reservation")
	_expect(int((player_0.get("assets") as Dictionary).get("energy", 0)) == 5 and int((player_0.get("assets") as Dictionary).get("industry", 0)) == 5, "later successful actions consume their independent reservations")
	_expect((player_0.get("reservations") as Dictionary).is_empty() and (player_2.get("reservations") as Dictionary).is_empty(), "all per-action reservations settle before refresh")
	_expect(str((state.get("window") as Dictionary).get("status", "")) == "batch_resolved", "last queue receipt closes resolution exactly once")


func _test_invalid_target_policy_closure() -> void:
	var expected_outcome_by_policy := {
		"FIZZLE_FULL_ASSET_REFUND": "invalid_target_fizzle_full_asset_refund",
		"FIZZLE_NO_REFUND": "invalid_target_fizzle_no_refund",
		"RESOLVE_LEGAL_REMAINDER": "invalid_target_resolve_legal_remainder",
		"DETERMINISTIC_FALLBACK": "invalid_target_deterministic_fallback",
	}
	var policy_index := 0
	for policy_id_variant in expected_outcome_by_policy.keys():
		var policy_id := str(policy_id_variant)
		var action_id := "action.invalid-target.%d" % policy_index
		var state := _state(
			["player.0"],
			["player.0"],
			{"player.0": _assets(4)}
		)
		var action := _action(
			action_id,
			0,
			_cost(2, 0, 0, 0, 0, 0, 0),
			_zero(),
			"target.invalid-target.%d" % policy_index
		) if policy_id == Core.DEFAULT_INVALID_TARGET_POLICY_ID else _action(
			action_id,
			0,
			_cost(2, 0, 0, 0, 0, 0, 0),
			_zero(),
			"target.invalid-target.%d" % policy_index,
			policy_id
		)
		if policy_id == Core.DEFAULT_INVALID_TARGET_POLICY_ID:
			_expect(
				action.get("invalid_target_policy_id")
					== "FIZZLE_FULL_ASSET_REFUND",
				"an omitted action policy binds the frozen full-refund default"
			)
		state = (_lock_player_queue(
			state,
			Core.build_lock_intent(
				"intent.invalid-target.%d" % policy_index,
				"batch.test",
				"player.0",
				1100,
				[action]
			),
			_zero(),
			1100,
			["player.0"]
		).get("state") as Dictionary)
		var before_bad_reason := state.duplicate(true)
		var bad_reason := Core.settle_invalid_target(state, action_id, "pending")
		_expect(
			not bool(bad_reason.get("accepted", true))
				and bad_reason.get("reason_code") == "invalid_target_reason_invalid"
				and bad_reason.get("state") == before_bad_reason,
			"invalid-target settlement requires a typed public causal reason"
		)

		var settled := Core.settle_invalid_target(
			state,
			action_id,
			"prebound_target_unavailable"
		)
		_expect(bool(settled.get("accepted", false)), "%s closes invalid-target resolution" % policy_id)
		state = settled.get("state") as Dictionary
		var player := (state.get("players") as Dictionary).get("player.0") as Dictionary
		var expected_refund := policy_id == "FIZZLE_FULL_ASSET_REFUND"
		_expect(
			int((player.get("assets") as Dictionary).get("life", -1))
				== (4 if expected_refund else 2)
				and (player.get("reservations") as Dictionary).is_empty(),
			"%s applies its exact reservation refund semantics" % policy_id
		)
		var result_record := (player.get("action_results") as Dictionary).get(
			action_id
		) as Dictionary
		_expect(
			result_record.get("outcome_id")
				== expected_outcome_by_policy.get(policy_id)
				and result_record.get("invalid_target_policy_id") == policy_id
				and result_record.get("reason_code")
					== "prebound_target_unavailable"
				and result_record.get("asset_refund_applied") == expected_refund
				and result_record.get("normal_card_destination") == "discard"
				and result_record.get("action_slot_refunded") == false,
			"%s records refund, discard, no-slot-refund, and public reason facts" % policy_id
		)
		var receipt := settled.get("receipt") as Dictionary
		_expect(
			receipt.get("reason_code") == "invalid_target_resolved"
				and receipt.get("public_history_reason_code")
					== "prebound_target_unavailable"
				and receipt.get("invalid_target_policy_id") == policy_id
				and receipt.get("normal_card_destination") == "discard"
				and receipt.get("action_slot_refunded") == false,
			"%s emits an explicit authoritative invalid-target receipt" % policy_id
		)
		var public_entry := (
			(Core.public_projection(state).get("anonymous_queue") as Array)[0]
		) as Dictionary
		_expect(
			public_entry.get("reason_code") == "prebound_target_unavailable"
				and public_entry.get("invalid_target_policy_id") == policy_id
				and public_entry.get("asset_refund_applied") == expected_refund
				and public_entry.get("normal_card_destination") == "discard"
				and public_entry.get("action_slot_refunded") == false,
			"%s publishes anonymous causal history without refund ambiguity" % policy_id
		)
		var saved := Core.to_save_state(state)
		var restored := Core.restore_save_state(saved)
		_expect(
			bool(restored.get("restored", false))
				and restored.get("state") == state,
			"%s policy and invalid-target outcome survive exact Save restore" % policy_id
		)
		policy_index += 1

	var invalid_policy_action := _action(
		"action.invalid-target-policy",
		0,
		_cost(0, 0, 0, 0, 0, 0, 0),
		_zero(),
		"target.invalid-target-policy",
		"FIZZLE_REFUND_CARD_AND_SLOT"
	)
	_expect(invalid_policy_action.is_empty(), "undeclared invalid-target policy fails the closed action schema")


func _test_three_wing_projection_and_privacy() -> void:
	var state := _state(
		["player.0", "player.1"],
		["player.1", "player.0"],
		{
			"player.0": _color_map(6, 5, 4, 3, 2, 1),
			"player.1": _color_map(1, 2, 3, 4, 5, 6),
		}
	)
	var private_source_action := Core.build_prebound_action(
		"action.private-source",
		"monster_action",
		"private-source-sentinel",
		0,
		"card.public",
		Core.build_target_binding("binding.private", ["region.public"], 1),
		"effect.public",
		_cost(1, 0, 0, 0, 0, 0, 0),
		_zero()
	)
	state = (_lock_player_queue(state, Core.build_lock_intent("intent.private.0", "batch.test", "player.0", 100, [private_source_action]), _color_map(1000, 0, 0, 0, 0, 0), 1000).get("state") as Dictionary)
	state = (_lock_player_queue(state, Core.build_lock_intent("intent.private.1", "batch.test", "player.1", 100, []), _zero(), 1000).get("state") as Dictionary)
	var authority: Dictionary = Core.core_authority(state)
	var ai_0: Dictionary = Core.ai_observation(state, "player.0")
	var ai_1: Dictionary = Core.ai_observation(state, "player.1")
	var player_0: Dictionary = Core.player_projection(state, "player.0")
	var player_1: Dictionary = Core.player_projection(state, "player.1")
	var public: Dictionary = Core.public_projection(state)
	_expect(not authority.is_empty() and not ai_0.is_empty() and not player_0.is_empty(), "Core, AI, and Player contracts project from one valid authority state")
	_expect(ai_0.get("anonymous_queue") == player_0.get("anonymous_queue") and player_0.get("anonymous_queue") == public.get("anonymous_queue"), "all three wings share the same anonymous queue facts")
	_expect(ai_0.get("own_assets") == _color_map(6, 5, 4, 3, 2, 1) and ai_1.get("own_assets") == _color_map(1, 2, 3, 4, 5, 6), "AI observation receives only its own exact assets")
	_expect(player_0.get("own_assets") == ai_0.get("own_assets") and player_1.get("own_assets") == ai_1.get("own_assets"), "AI and player own-asset facts have one authority")
	_expect(_contains_value(ai_0, "private-source-sentinel"), "owner observation may inspect its own bound source")
	_expect(not _contains_value(ai_1, "private-source-sentinel") and not _contains_value(player_1, "private-source-sentinel"), "rival projection cannot inspect another local queue source")
	_expect(not _contains_key_recursive(ai_0, ["submission_hidden_lead_order", "frozen_hidden_lead_order", "authority_queue", "receipts", "save_payload"]), "AI projection excludes authority-secret state containers")
	_expect(not _contains_key_recursive(player_0, ["submission_hidden_lead_order", "frozen_hidden_lead_order", "authority_queue", "receipts", "save_payload"]), "player projection excludes authority-secret state containers")
	_expect(not _contains_key_recursive(ai_0, ["lineage_fingerprint", "lock_fingerprint"]) and not _contains_key_recursive(player_0, ["lineage_fingerprint", "lock_fingerprint"]), "AI and player projections exclude authority integrity fingerprints")
	_expect(not _contains_value(ai_0, "player.1") and not _contains_value(player_0, "player.1"), "viewer projections do not reveal hidden lead or rival identity")
	_expect(not _contains_key_recursive(public, ["viewer_id", "own_assets", "own_reserved_totals", "own_local_queue", "own_frozen_gdp_milli"]), "public projection excludes all viewer-private asset facts")
	_expect(not _contains_value(public, "private-source-sentinel"), "public projection strips private source identity")
	_expect((player_0.get("own_frozen_gdp_milli") as Dictionary).get("life") == 1000, "viewer-private projection may show its own frozen refresh basis")
	_expect((player_0.get("own_projected_refresh") as Dictionary).get("life") == 6, "viewer-private projection derives capped refresh from the same core fact")

	var player_copy := player_0.duplicate(true)
	(player_copy.get("own_assets") as Dictionary)["life"] = 0
	_expect((((state.get("players") as Dictionary).get("player.0") as Dictionary).get("assets") as Dictionary).get("life") == 6, "projection mutation cannot mutate authority state")
	var authority_copy := authority.duplicate(true)
	((authority_copy.get("state") as Dictionary).get("frozen_hidden_lead_order") as Array).reverse()
	_expect((state.get("frozen_hidden_lead_order") as Array) == ["player.1", "player.0"], "authority envelope is also a detached snapshot")

	var last_receipt := (state.get("receipts") as Array).back() as Dictionary
	_expect(str(last_receipt.get("contract_id", "")) == "internal.v072.asset_batch.authoritative_receipt.v3", "internal transition emits a typed V0.7.2 non-public receipt")
	_expect(not _contains_key_recursive(last_receipt, ["assets", "remainders_milli", "reservations", "frozen_gdp_milli", "submission_hidden_lead_order", "frozen_hidden_lead_order"]), "receipt carries no raw private asset or lead payload")
	_expect(Core.is_pure_data(ai_0) and Core.is_pure_data(player_0) and Core.is_pure_data(public) and Core.is_pure_data(last_receipt), "projections and receipts remain pure data")


func _test_exact_domain_contract_adapters() -> void:
	var initial_state := _state(
		["player.0", "player.1"],
		["player.0", "player.1"],
		{"player.0": _assets(3), "player.1": _assets(3)}
	)
	var action := _action(
		"action.domain-contract",
		0,
		_cost(1, 0, 0, 0, 0, 0, 0),
		_zero(),
		"target.domain-contract"
	)
	var internal_intent := Core.build_lock_intent(
		"intent.domain-contract",
		"batch.test",
		"player.0",
		1100,
		[action]
	)
	var asset_intent: Dictionary = Core.asset_intent_adapter(internal_intent, 0, 7)
	var batch_intent: Dictionary = Core.batch_intent_adapter(internal_intent, 0)
	var first_lock: Dictionary = _lock_player_queue(
		initial_state,
		internal_intent,
		_color_map(1000, 0, 0, 0, 0, 0),
		1100,
		["player.1", "player.0"]
	)
	var after_first := first_lock.get("state") as Dictionary
	var internal_receipt := first_lock.get("receipt") as Dictionary
	var asset_receipt: Dictionary = Core.asset_receipt_adapter(
		internal_receipt,
		internal_intent,
		initial_state,
		after_first
	)
	var batch_receipt: Dictionary = Core.batch_receipt_adapter(
		internal_receipt,
		internal_intent,
		initial_state,
		after_first
	)
	var final_state := (_lock_player_queue(
		after_first,
		Core.build_lock_intent(
			"intent.domain-contract.second",
			"batch.test",
			"player.1",
			1200,
			[]
		),
		_zero(),
		1200,
		["player.1", "player.0"]
	).get("state") as Dictionary)

	var contracts := {
		"v072.six_color_assets.core_authority.v3": Core.asset_core_authority(final_state),
		"v072.six_color_assets.ai_observation.v3": Core.asset_ai_observation(final_state, "player.0"),
		"v072.six_color_assets.player_projection.v3": Core.asset_player_projection(final_state, "player.0"),
		"v072.six_color_assets.intent.v3": asset_intent,
		"v072.six_color_assets.authoritative_receipt.v3": asset_receipt,
		"v072.six_color_assets.save_state.v3": Core.to_asset_save_state(final_state),
		"v072.card_batch.core_authority.v3": Core.batch_core_authority(final_state),
		"v072.card_batch.ai_observation.v3": Core.batch_ai_observation(final_state, "player.0"),
		"v072.card_batch.player_projection.v3": Core.batch_player_projection(final_state, "player.0"),
		"v072.card_batch.intent.v3": batch_intent,
		"v072.card_batch.authoritative_receipt.v3": batch_receipt,
		"v072.card_batch.save_state.v3": Core.to_batch_save_state(final_state),
	}
	var valid_count := 0
	for contract_id_variant in contracts.keys():
		var contract_id := str(contract_id_variant)
		var value := contracts.get(contract_id) as Dictionary
		if str(value.get("contract_id", "")) == contract_id \
				and bool(Core.domain_contract_validation_report(value, contract_id).get("valid", false)):
			valid_count += 1
	_expect(valid_count == 12 and contracts.size() == 12, "asset and batch expose all twelve exact registry contract IDs with strict fingerprints")

	var snapshot: Dictionary = Core.contract_snapshot()
	var asset_domain := snapshot.get("asset_domain") as Dictionary
	var batch_domain := snapshot.get("batch_domain") as Dictionary
	_expect(asset_domain.get("CoreAuthorityV3") == "v072.six_color_assets.core_authority.v3" and asset_domain.get("SaveStateV3") == "v072.six_color_assets.save_state.v3", "asset contract registry snapshot exposes its V0.7.2 six-color domain IDs")
	_expect(batch_domain.get("CoreAuthorityV3") == "v072.card_batch.core_authority.v3" and batch_domain.get("SaveStateV3") == "v072.card_batch.save_state.v3", "batch contract registry snapshot exposes its V0.7.2 card-batch domain IDs")
	_expect(int(asset_intent.get("expected_core_revision", -1)) == 0 and int(asset_intent.get("asset_snapshot_revision", -1)) == 7 and (asset_intent.get("reservation_ids") as Array) == ["reservation.action.domain-contract"], "asset Intent adapter closes revision, snapshot, cost, and reservation semantics")
	_expect(int(batch_intent.get("expected_core_revision", -1)) == 0 and batch_intent.get("window_id") == "batch.test" and (batch_intent.get("local_action_index") as Array) == [0], "batch Intent adapter closes window, local index, source, target, and reservation semantics")
	_expect(asset_receipt.get("intent_id") == "intent.domain-contract" and asset_receipt.get("asset_delta_by_color") == _zero() and (asset_receipt.get("reservation_ids") as Array).size() == 1, "asset Receipt adapter binds intent, reservation IDs, committed revision, and exact asset delta")
	_expect(batch_receipt.get("intent_id") == "intent.domain-contract" and batch_receipt.get("anonymous_action_id") == "action.domain-contract" and batch_receipt.get("window_id") == "batch.test", "batch Receipt adapter binds intent, anonymous action, window, and resolution status")
	var asset_save := contracts.get("v072.six_color_assets.save_state.v3") as Dictionary
	var batch_save := contracts.get("v072.card_batch.save_state.v3") as Dictionary
	_expect(asset_save.get("section_id") == "six_color_assets_and_reservations" and asset_save.has("gdp_cycle_snapshot") and asset_save.has("reservation_journal") and asset_save.has("shared_authority_state"), "asset Save adapter has the exact independent section and shared-state semantics")
	_expect(batch_save.get("section_id") == "card_batch_and_anonymous_resolution" and batch_save.has("private_owner_bindings") and batch_save.has("round_robin_cursor") and batch_save.has("shared_authority_state"), "batch Save adapter has the exact independent queue and shared-state semantics")
	var tampered_asset_save := asset_save.duplicate(true)
	(tampered_asset_save.get("per_player_assets_by_color") as Dictionary).erase("player.1")
	_expect(not bool(Core.domain_contract_validation_report(tampered_asset_save, "v072.six_color_assets.save_state.v3").get("valid", true)), "strict domain Save adapter rejects fingerprint-breaking payload mutation")

	var wrong_type_intent := asset_intent.duplicate(true)
	wrong_type_intent["expected_core_revision"] = "zero"
	_reseal_domain_contract(wrong_type_intent, "intent_fingerprint")
	var wrong_type_report: Dictionary = Core.domain_contract_validation_report(
		wrong_type_intent,
		"v072.six_color_assets.intent.v3"
	)
	_expect(
		_domain_fingerprint_matches(wrong_type_intent, "intent_fingerprint")
			and not bool(wrong_type_report.get("valid", true))
			and str(wrong_type_report.get("reason_code", ""))
				== "asset_intent_binding_invalid",
		"strict asset Intent adapter rejects a valid-fingerprint wrong-type revision"
	)

	var out_of_range_save := asset_save.duplicate(true)
	(((out_of_range_save.get("per_player_assets_by_color") as Dictionary).get(
		"player.0"
	) as Dictionary))["life"] = 7
	(((((out_of_range_save.get("shared_authority_state") as Dictionary).get(
		"players"
	) as Dictionary).get("player.0") as Dictionary).get(
		"assets"
	) as Dictionary))["life"] = 7
	_reseal_domain_contract(out_of_range_save, "save_fingerprint")
	var out_of_range_report: Dictionary = Core.domain_contract_validation_report(
		out_of_range_save,
		"v072.six_color_assets.save_state.v3"
	)
	_expect(
		_domain_fingerprint_matches(out_of_range_save, "save_fingerprint")
			and not bool(out_of_range_report.get("valid", true))
			and str(out_of_range_report.get("reason_code", ""))
				== "domain_save_shared_state_player_asset_state_invalid",
		"strict asset Save rejects a valid-fingerprint balance above the color cap"
	)

	var inconsistent_journal_save := asset_save.duplicate(true)
	(((inconsistent_journal_save.get("reservation_journal") as Dictionary).get(
		"player.0"
	) as Dictionary))["action.domain-contract"] = "success"
	(((((inconsistent_journal_save.get("shared_authority_state") as Dictionary).get(
		"players"
	) as Dictionary).get("player.0") as Dictionary).get(
		"action_results"
	) as Dictionary))["action.domain-contract"] = "success"
	_reseal_domain_contract(inconsistent_journal_save, "save_fingerprint")
	var inconsistent_journal_report: Dictionary = Core.domain_contract_validation_report(
		inconsistent_journal_save,
		"v072.six_color_assets.save_state.v3"
	)
	_expect(
		_domain_fingerprint_matches(inconsistent_journal_save, "save_fingerprint")
			and not bool(inconsistent_journal_report.get("valid", true))
			and str(inconsistent_journal_report.get("reason_code", ""))
				== "domain_save_shared_state_player_reservations_invalid",
		"strict asset Save rejects a valid-fingerprint action that is both reserved and journaled"
	)
	var asset_player := contracts.get("v072.six_color_assets.player_projection.v3") as Dictionary
	var batch_player := contracts.get("v072.card_batch.player_projection.v3") as Dictionary
	_expect(not _contains_key_recursive(asset_player, ["anonymous_global_queue", "private_owner_bindings", "frozen_hidden_lead_order"]) and not _contains_key_recursive(batch_player, ["own_exact_assets", "gdp_cycle_snapshot", "lineage_fingerprint"]), "domain projections expose only their own allowlisted facts")
	var source := FileAccess.get_file_as_string("res://scripts/v07_semantic/v07_asset_batch_core.gd")
	_expect(not source.contains("\"v07.asset_batch.core_authority.v1\"") and not source.contains("\"v07.asset_batch.ai_observation.v1\"") and not source.contains("\"v07.asset_batch.save_state.v1\""), "shared asset_batch IDs no longer masquerade as domain contracts")


func _test_receipt_adapter_cross_lineage_rejection() -> void:
	var before_a := _state(
		["player.0", "player.1"],
		["player.0", "player.1"],
		{"player.0": _assets(2), "player.1": _assets(2)}
	)
	var intent_a := Core.build_lock_intent(
		"intent.adapter.a",
		"batch.test",
		"player.0",
		100,
		[]
	)
	var transition_a: Dictionary = _lock_player_queue(
		before_a,
		intent_a,
		_zero(),
		1000
	)
	var after_a := transition_a.get("state") as Dictionary

	var before_b := Core.create_state(
		"batch.adapter.foreign",
		["player.0", "player.1"],
		["player.0", "player.1"],
		{"player.0": _assets(2), "player.1": _assets(2)},
		{},
		1000,
		1000
	)
	var intent_b := Core.build_lock_intent(
		"intent.adapter.b",
		"batch.adapter.foreign",
		"player.0",
		100,
		[]
	)
	var transition_b: Dictionary = _lock_player_queue(
		before_b,
		intent_b,
		_zero(),
		1000
	)
	var foreign_receipt := transition_b.get("receipt") as Dictionary
	_expect(
		Core.asset_receipt_adapter(
			foreign_receipt,
			intent_a,
			before_a,
			after_a
		).is_empty(),
		"asset receipt adapter rejects a valid receipt from another batch lineage"
	)
	_expect(
		Core.batch_receipt_adapter(
			foreign_receipt,
			intent_a,
			before_a,
			after_a
		).is_empty(),
		"batch receipt adapter rejects a valid receipt from another batch lineage"
	)

	var same_batch_foreign_before := Core.create_state(
		"batch.test",
		["player.0", "player.1"],
		["player.0", "player.1"],
		{"player.0": _assets(3), "player.1": _assets(2)},
		{},
		1000,
		1000
	)
	var same_batch_intent := Core.build_lock_intent(
		"intent.adapter.same-batch-foreign",
		"batch.test",
		"player.0",
		100,
		[]
	)
	var same_batch_transition: Dictionary = _lock_player_queue(
		same_batch_foreign_before,
		same_batch_intent,
		_zero(),
		1000
	)
	_expect(
		Core.asset_receipt_adapter(
			same_batch_transition.get("receipt") as Dictionary,
			intent_a,
			before_a,
			after_a
		).is_empty()
			and Core.batch_receipt_adapter(
				same_batch_transition.get("receipt") as Dictionary,
				intent_a,
				before_a,
				after_a
			).is_empty(),
		"both receipt adapters reject same-batch receipts from another genesis lineage"
	)
	_expect(
		Core.asset_receipt_adapter(
			transition_a.get("receipt") as Dictionary,
			intent_a,
			before_b,
			after_a
		).is_empty(),
		"receipt adapter rejects non-adjacent before and after authority states"
	)


func _test_projected_refresh_after_success() -> void:
	var state := _state(
		["player.0"],
		["player.0"],
		{"player.0": _color_map(6, 0, 0, 0, 0, 0)}
	)
	var locked: Dictionary = _lock_player_queue(
		state,
		Core.build_lock_intent(
			"intent.projected-refresh",
			"batch.test",
			"player.0",
			1100,
			[_action("action.projected-refresh", 0, _cost(6, 0, 0, 0, 0, 0, 0), _zero(), "target.projected-refresh")]
		),
		_color_map(2000, 0, 0, 0, 0, 0),
		1100,
		["player.0"]
	)
	state = locked.get("state") as Dictionary
	var generic_projection := Core.player_projection(state, "player.0")
	var asset_projection := Core.asset_player_projection(state, "player.0")
	_expect(int((generic_projection.get("own_projected_refresh") as Dictionary).get("life", -1)) == 2 and int((asset_projection.get("own_projected_refresh") as Dictionary).get("life", -1)) == 2, "projected refresh subtracts all successful reservations before applying frozen GDP top-up")
	_expect(int((asset_projection.get("own_available_assets") as Dictionary).get("life", -1)) == 0, "asset projection distinguishes current, reserved, and available balances")
	state = (Core.settle_next_action(state, "action.projected-refresh", "success").get("state") as Dictionary)
	state = (Core.refresh_assets_after_batch(state).get("state") as Dictionary)
	_expect(int((((state.get("players") as Dictionary).get("player.0") as Dictionary).get("assets") as Dictionary).get("life", -1)) == 2, "successful settlement and actual refresh match the pre-resolution projection exactly")

	var mixed_state := _state(
		["player.0"],
		["player.0"],
		{"player.0": _color_map(5, 4, 2, 3, 0, 1)}
	)
	var mixed_actions := [
		_action(
			"action.projected-mixed.success-a",
			0,
			_cost(2, 1, 0, 0, 0, 0, 0),
			_zero(),
			"target.projected-mixed.success-a"
		),
		_action(
			"action.projected-mixed.refund",
			1,
			_cost(1, 0, 1, 0, 0, 0, 0),
			_zero(),
			"target.projected-mixed.refund"
		),
		_action(
			"action.projected-mixed.success-b",
			2,
			_cost(0, 0, 0, 2, 0, 1, 0),
			_zero(),
			"target.projected-mixed.success-b"
		),
	]
	var mixed_lock: Dictionary = _lock_player_queue(
		mixed_state,
		Core.build_lock_intent(
			"intent.projected-mixed",
			"batch.test",
			"player.0",
			1100,
			mixed_actions
		),
		_color_map(1000, 2000, 1000, 1000, 2000, 0),
		1100,
		["player.0"]
	)
	_expect(bool(mixed_lock.get("accepted", false)), "mixed projection fixture reserves all three actions atomically")
	mixed_state = mixed_lock.get("state") as Dictionary
	var all_success_projection := (
		Core.asset_player_projection(mixed_state, "player.0").get(
			"own_projected_refresh"
		) as Dictionary
	)
	_expect(
		all_success_projection == _color_map(3, 5, 2, 2, 2, 0),
		"mixed-color projection initially assumes every reserved action succeeds"
	)

	mixed_state = (Core.settle_next_action(
		mixed_state,
		"action.projected-mixed.success-a",
		"success"
	).get("state") as Dictionary)
	_expect(
		(Core.asset_player_projection(mixed_state, "player.0").get(
			"own_projected_refresh"
		) as Dictionary) == all_success_projection,
		"consuming one successful reservation preserves the all-success projection"
	)

	mixed_state = (Core.settle_next_action(
		mixed_state,
		"action.projected-mixed.refund",
		"rule_allowed_refundable_failure"
	).get("state") as Dictionary)
	var after_refund_projection := (
		Core.asset_player_projection(mixed_state, "player.0").get(
			"own_projected_refresh"
		) as Dictionary
	)
	_expect(
		after_refund_projection == _color_map(4, 5, 3, 2, 2, 0),
		"refundable failure releases its life and industry reservation into projected refresh"
	)

	mixed_state = (Core.settle_next_action(
		mixed_state,
		"action.projected-mixed.success-b",
		"success"
	).get("state") as Dictionary)
	_expect(
		(Core.asset_player_projection(mixed_state, "player.0").get(
			"own_projected_refresh"
		) as Dictionary) == after_refund_projection,
		"later multi-color success consumes exactly its remaining reservation before top-up"
	)
	mixed_state = (Core.refresh_assets_after_batch(mixed_state).get("state") as Dictionary)
	_expect(
		((((mixed_state.get("players") as Dictionary).get(
			"player.0"
		) as Dictionary).get("assets") as Dictionary)) == after_refund_projection,
		"mixed success and refund projection matches the final six-color refreshed assets"
	)


func _test_save_checkpoint_and_rollback() -> void:
	var state := _state(
		["player.0", "player.1"],
		["player.1", "player.0"],
		{"player.0": _assets(6), "player.1": _assets(6)}
	)
	state = (_lock_player_queue(state, Core.build_lock_intent("intent.save.0", "batch.test", "player.0", 100, [_action("action.save.0", 0, _cost(2, 0, 0, 0, 0, 0, 0), _zero(), "target.save.0")]), _color_map(1500, 0, 0, 0, 0, 0), 1000).get("state") as Dictionary)
	state = (_lock_player_queue(state, Core.build_lock_intent("intent.save.1", "batch.test", "player.1", 100, []), _zero(), 1000).get("state") as Dictionary)
	var save_state: Dictionary = Core.to_save_state(state)
	_expect(str(save_state.get("schema_id", "")) == "internal.v072.asset_batch.save_state.v3", "internal combined Save has an explicitly versioned non-domain identity")
	_expect(str(save_state.get("ruleset_id", "")) == "v0.7.2", "Save binds the exact V0.7.2 ruleset ID")
	_expect(
		save_state.get("state_version") == 3
			and save_state.get("balance_profile_id") == "V072_STARTER_FREE_FAST"
			and save_state.get("balance_profile_fingerprint")
				== "b8f684ab92b06fa44671c38d041ff08b9c1ea7c2950b094705e19192f0a70f48"
			and save_state.get("default_invalid_target_policy_id")
				== "FIZZLE_FULL_ASSET_REFUND"
			and save_state.get("max_asset_refresh_per_color_per_batch") == 3,
		"combined Save explicitly persists the V0.7.2 Starter profile and policy context"
	)
	var legacy_v071_save := save_state.duplicate(true)
	legacy_v071_save["schema_id"] = "internal.v071.asset_batch.save_state.v2"
	legacy_v071_save["state_version"] = 2
	legacy_v071_save["ruleset_id"] = "v0.7.1"
	legacy_v071_save["balance_profile_id"] = "V071_CANDIDATE_A_FAST"
	legacy_v071_save["balance_profile_fingerprint"] = (
		"8d8de8d406ca2f7d5123ecc951a606a0a08b56282bc3d6a40e0cd4d5ff50f19a"
	)
	_expect(
		Core.restore_save_state(legacy_v071_save).get("reason_code") \
		== "save_schema_invalid",
		"V0.7.1 detached asset Save fails closed instead of silently resuming"
	)
	_expect(Core.is_pure_data(save_state) and str(save_state.get("save_fingerprint", "")).length() == 64, "Save state is pure data with a deterministic fingerprint")
	var restored: Dictionary = Core.restore_save_state(save_state)
	_expect(bool(restored.get("restored", false)) and restored.get("state") == state, "Save roundtrip preserves exact queue, reservation, GDP snapshot, and hidden order")
	var restored_state := restored.get("state") as Dictionary
	((restored_state.get("frozen_hidden_lead_order") as Array)).reverse()
	_expect((state.get("frozen_hidden_lead_order") as Array) == ["player.1", "player.0"], "restored Save state is detached from live authority")

	var asset_domain_save: Dictionary = Core.to_asset_save_state(state)
	var batch_domain_save: Dictionary = Core.to_batch_save_state(state)
	_expect(
		_same_string_set(asset_domain_save.keys(), Core.ASSET_SAVE_CONTRACT_FIELDS)
			and _same_string_set(batch_domain_save.keys(), Core.BATCH_SAVE_CONTRACT_FIELDS),
		"asset and batch Save adapters expose their exact strengthened field sets"
	)
	_expect(
		asset_domain_save.get("shared_batch_id") == state.get("batch_id")
			and batch_domain_save.get("shared_batch_id") == state.get("batch_id")
			and asset_domain_save.get("shared_lineage_fingerprint")
				== state.get("lineage_fingerprint")
			and batch_domain_save.get("shared_lineage_fingerprint")
				== state.get("lineage_fingerprint")
			and asset_domain_save.get("balance_profile_id")
				== "V072_STARTER_FREE_FAST"
			and batch_domain_save.get("balance_profile_fingerprint")
				== Core.BALANCE_PROFILE_FINGERPRINT
			and asset_domain_save.get("default_invalid_target_policy_id")
				== "FIZZLE_FULL_ASSET_REFUND",
		"both domain Saves bind the same batch, lineage, profile, and policy"
	)
	var asset_domain_restore: Dictionary = Core.restore_domain_save_state(
		asset_domain_save,
		"v072.six_color_assets.save_state.v3"
	)
	_expect(
		bool(asset_domain_restore.get("preflight_valid", false))
			and not bool(asset_domain_restore.get("restored", true))
			and (asset_domain_restore.get("state") as Dictionary).is_empty(),
		"asset split Save preflights without exposing an applyable partial state"
	)
	var batch_domain_restore: Dictionary = Core.restore_domain_save_state(
		batch_domain_save,
		"v072.card_batch.save_state.v3"
	)
	_expect(
		bool(batch_domain_restore.get("preflight_valid", false))
			and not bool(batch_domain_restore.get("restored", true))
			and (batch_domain_restore.get("state") as Dictionary).is_empty(),
		"batch split Save preflights without exposing an applyable partial state"
	)
	var paired_restore: Dictionary = Core.restore_domain_save_pair(
		asset_domain_save,
		batch_domain_save
	)
	_expect(
		bool(paired_restore.get("restored", false))
			and paired_restore.get("state") == state,
		"paired domain Saves restore one exact shared authority state"
	)
	var detached_domain_state := paired_restore.get("state") as Dictionary
	(detached_domain_state.get("players") as Dictionary).erase("player.1")
	_expect(
		(asset_domain_save.get("shared_authority_state") as Dictionary) == state,
		"paired domain restore returns a detached state"
	)

	var other_domain_state := Core.create_state(
		"batch.other-domain-save",
		["player.0", "player.1"],
		["player.1", "player.0"],
		{"player.0": _assets(6), "player.1": _assets(6)},
		{},
		1000,
		1000
	)
	var other_batch_save: Dictionary = Core.to_batch_save_state(other_domain_state)
	var asset_before_mix := asset_domain_save.duplicate(true)
	var other_batch_before_mix := other_batch_save.duplicate(true)
	var cross_batch: Dictionary = Core.restore_domain_save_pair(
		asset_domain_save,
		other_batch_save
	)
	_expect(
		not bool(cross_batch.get("restored", true))
			and str(cross_batch.get("reason_code", ""))
				== "domain_save_pair_batch_mismatch"
			and (cross_batch.get("state") as Dictionary).is_empty(),
		"paired restore rejects cross-batch section mixing without partial state"
	)
	_expect(
		asset_domain_save == asset_before_mix
			and other_batch_save == other_batch_before_mix,
		"cross-batch rejection does not mutate either Save input"
	)

	var same_batch_other_lineage := Core.create_state(
		"batch.test",
		["player.0", "player.1"],
		["player.1", "player.0"],
		{"player.0": _assets(5), "player.1": _assets(6)},
		{},
		1000,
		1000
	)
	var cross_lineage: Dictionary = Core.restore_domain_save_pair(
		asset_domain_save,
		Core.to_batch_save_state(same_batch_other_lineage)
	)
	_expect(
		not bool(cross_lineage.get("restored", true))
			and str(cross_lineage.get("reason_code", ""))
				== "domain_save_pair_lineage_mismatch"
			and (cross_lineage.get("state") as Dictionary).is_empty(),
		"paired restore rejects same-batch sections from different lineages"
	)

	var advanced_state := (Core.settle_next_action(
		state,
		"action.save.0",
		"success"
	).get("state") as Dictionary)
	var cross_state: Dictionary = Core.restore_domain_save_pair(
		asset_domain_save,
		Core.to_batch_save_state(advanced_state)
	)
	_expect(
		not bool(cross_state.get("restored", true))
			and str(cross_state.get("reason_code", ""))
				== "domain_save_pair_shared_state_mismatch"
			and (cross_state.get("state") as Dictionary).is_empty(),
		"paired restore rejects different revisions from one batch lineage"
	)

	var tampered_asset_domain := asset_domain_save.duplicate(true)
	((((tampered_asset_domain.get("shared_authority_state") as Dictionary).get(
		"players"
	) as Dictionary).get("player.0") as Dictionary).get(
		"assets"
	) as Dictionary)["life"] = 7
	(((tampered_asset_domain.get("per_player_assets_by_color") as Dictionary).get(
		"player.0"
	) as Dictionary))["life"] = 7
	_reseal_domain_contract(tampered_asset_domain, "save_fingerprint")
	var tampered_asset_before := tampered_asset_domain.duplicate(true)
	var tampered_asset_restore: Dictionary = Core.restore_domain_save_state(
		tampered_asset_domain,
		"v072.six_color_assets.save_state.v3"
	)
	_expect(
		_domain_fingerprint_matches(tampered_asset_domain, "save_fingerprint")
			and not bool(tampered_asset_restore.get("restored", true))
			and (tampered_asset_restore.get("state") as Dictionary).is_empty()
			and tampered_asset_domain == tampered_asset_before,
		"asset domain restore rejects a resealed nested balance violation without partial state"
	)

	var tampered_batch_domain := batch_domain_save.duplicate(true)
	(tampered_batch_domain.get("shared_authority_state") as Dictionary)[
		"resolution_cursor"
	] = 1
	tampered_batch_domain["round_robin_cursor"] = 1
	_reseal_domain_contract(tampered_batch_domain, "save_fingerprint")
	var tampered_batch_before := tampered_batch_domain.duplicate(true)
	var tampered_batch_restore: Dictionary = Core.restore_domain_save_state(
		tampered_batch_domain,
		"v072.card_batch.save_state.v3"
	)
	_expect(
		_domain_fingerprint_matches(tampered_batch_domain, "save_fingerprint")
			and not bool(tampered_batch_restore.get("restored", true))
			and (tampered_batch_restore.get("state") as Dictionary).is_empty()
			and tampered_batch_domain == tampered_batch_before,
		"batch domain restore rejects a resealed nested cursor violation without partial state"
	)
	var invalid_pair: Dictionary = Core.restore_domain_save_pair(
		tampered_asset_domain,
		batch_domain_save
	)
	_expect(
		not bool(invalid_pair.get("restored", true))
			and (invalid_pair.get("state") as Dictionary).is_empty(),
		"paired restore exposes no partial state when either domain Save is invalid"
	)

	var corrupt := save_state.duplicate(true)
	((corrupt.get("state") as Dictionary).get("players") as Dictionary).erase("player.1")
	var corrupt_result: Dictionary = Core.restore_save_state(corrupt)
	_expect(not bool(corrupt_result.get("restored", true)) and str(corrupt_result.get("reason_code", "")) == "save_fingerprint_invalid", "tampered Save fails closed before state apply")
	var wrong_schema := save_state.duplicate(true)
	wrong_schema["schema_id"] = "internal.v07.asset_batch.save_state.v1"
	_reseal_domain_contract(wrong_schema, "save_fingerprint")
	_expect(not bool(Core.restore_save_state(wrong_schema).get("restored", true)), "historical V0.7 Save cannot load silently through the V0.7.2 core")
	var wrong_profile := save_state.duplicate(true)
	wrong_profile["balance_profile_fingerprint"] = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
	_reseal_domain_contract(wrong_profile, "save_fingerprint")
	_expect(
		str(Core.restore_save_state(wrong_profile).get("reason_code", ""))
			== "save_schema_invalid",
		"resealed Save with the wrong balance profile fingerprint fails closed"
	)
	var wrong_policy := save_state.duplicate(true)
	wrong_policy["default_invalid_target_policy_id"] = "FIZZLE_NO_REFUND"
	((wrong_policy.get("state") as Dictionary))["default_invalid_target_policy_id"] = (
		"FIZZLE_NO_REFUND"
	)
	_reseal_domain_contract(wrong_policy, "save_fingerprint")
	_expect(
		str(Core.restore_save_state(wrong_policy).get("reason_code", ""))
			== "save_schema_invalid",
		"resealed Save cannot silently replace the frozen default invalid-target policy"
	)

	var saved_checkpoint: Dictionary = Core.checkpoint(state)
	_expect(str(saved_checkpoint.get("schema_id", "")) == "internal.v072.asset_batch.checkpoint.v3", "checkpoint has an independent V0.7.2 identity")
	var settled: Dictionary = Core.settle_next_action(state, "action.save.0", "success")
	_expect(bool(settled.get("accepted", false)) and settled.get("state") != state, "post-checkpoint settlement changes the authority state")
	var rolled_back: Dictionary = Core.rollback(settled.get("state"), saved_checkpoint)
	_expect(bool(rolled_back.get("rolled_back", false)) and rolled_back.get("state") == state, "rollback restores the exact checkpoint including open reservations")
	_expect(str((rolled_back.get("receipt") as Dictionary).get("outcome_id", "")) == "rolled_back", "rollback emits an authoritative receipt outside restored state")

	var other_state := Core.create_state("batch.other", ["player.0"], ["player.0"], {"player.0": _assets(0)})
	var wrong_batch: Dictionary = Core.rollback(other_state, saved_checkpoint)
	_expect(not bool(wrong_batch.get("rolled_back", true)) and str(wrong_batch.get("reason_code", "")) == "checkpoint_batch_binding_invalid", "checkpoint cannot cross batch identity")
	_expect(wrong_batch.get("state") == other_state, "cross-batch rollback rejection has zero mutation")


func _test_intent_receipt_ledger_reseal_resistance() -> void:
	var initial := _state(
		["player.0", "player.1"],
		["player.0", "player.1"],
		{"player.0": _assets(2), "player.1": _assets(2)}
	)
	var intent := Core.build_lock_intent(
		"intent.ledger.original",
		"batch.test",
		"player.0",
		100,
		[]
	)
	var transition: Dictionary = _lock_player_queue(
		initial,
		intent,
		_zero(),
		1000
	)
	var state := transition.get("state") as Dictionary
	var original_receipt := transition.get("receipt") as Dictionary
	var ledger := state.get("intent_receipt_ledger") as Dictionary
	var entry := ledger.get("intent.ledger.original") as Dictionary
	_expect(
		bool(Core.validation_report(state).get("valid", false))
			and entry.get("intent_fingerprint") == intent.get("intent_fingerprint")
			and entry.get("receipt_id") == original_receipt.get("receipt_id")
			and entry.get("receipt_fingerprint")
				== original_receipt.get("receipt_fingerprint")
			and entry.get("actor_id") == "player.0"
			and entry.get("lineage_fingerprint") == state.get("lineage_fingerprint"),
		"intent ledger binds exact intent, receipt, actor, and lineage identities"
	)

	var asset_save := Core.to_asset_save_state(state)
	var batch_save := Core.to_batch_save_state(state)
	var paired: Dictionary = Core.restore_domain_save_pair(asset_save, batch_save)
	var restored_state := paired.get("state") as Dictionary
	var replay_before := restored_state.duplicate(true)
	var replay: Dictionary = _lock_player_queue(
		restored_state,
		intent,
		_zero(),
		1200
	)
	_expect(
		bool(replay.get("accepted", false))
			and replay.get("receipt") == original_receipt
			and replay.get("state") == replay_before,
		"paired Save restore replays an identical intent as the exact prior receipt"
	)
	var collision_intent := Core.build_lock_intent(
		"intent.ledger.original",
		"batch.test",
		"player.0",
		101,
		[]
	)
	var collision: Dictionary = _lock_player_queue(
		restored_state,
		collision_intent,
		_zero(),
		1200
	)
	_expect(
		not bool(collision.get("accepted", true))
			and str(collision.get("reason_code", "")) == "intent_id_collision"
			and collision.get("state") == replay_before,
		"paired Save restore collision-fails a different payload under one intent ID"
	)

	var forged_state := state.duplicate(true)
	var substituted_intent_id := "intent.ledger.substituted"
	(forged_state.get("seen_intent_ids") as Array)[0] = substituted_intent_id
	var forged_ledger := forged_state.get("intent_receipt_ledger") as Dictionary
	var forged_entry := (
		forged_ledger.get("intent.ledger.original") as Dictionary
	).duplicate(true)
	forged_ledger.erase("intent.ledger.original")
	forged_entry["intent_id"] = substituted_intent_id
	forged_ledger[substituted_intent_id] = forged_entry
	var forged_receipt := (forged_state.get("receipts") as Array)[0] as Dictionary
	forged_receipt["intent_id"] = substituted_intent_id
	_reseal_domain_contract(forged_receipt, "receipt_fingerprint")
	forged_entry["receipt_fingerprint"] = forged_receipt.get("receipt_fingerprint")
	forged_ledger[substituted_intent_id] = forged_entry
	var forged_report: Dictionary = Core.validation_report(forged_state)
	_expect(
		not bool(forged_report.get("valid", true))
			and str(forged_report.get("reason_code", ""))
				== "state_intent_receipt_reconstruction_invalid",
		"strict state rejects coordinated intent-ID, ledger, and receipt resealing"
	)

	var forged_asset_save := asset_save.duplicate(true)
	forged_asset_save["shared_authority_state"] = forged_state.duplicate(true)
	_reseal_domain_contract(forged_asset_save, "save_fingerprint")
	var forged_batch_save := batch_save.duplicate(true)
	forged_batch_save["shared_authority_state"] = forged_state.duplicate(true)
	forged_batch_save["processed_intent_ids"] = [substituted_intent_id]
	forged_batch_save["intent_receipt_ledger"] = forged_ledger.duplicate(true)
	_reseal_domain_contract(forged_batch_save, "save_fingerprint")
	var forged_pair: Dictionary = Core.restore_domain_save_pair(
		forged_asset_save,
		forged_batch_save
	)
	_expect(
		not bool(forged_pair.get("restored", true))
			and (forged_pair.get("state") as Dictionary).is_empty(),
		"paired Save preflight exposes no state for coordinated resealed history substitution"
	)


func _test_adversarial_atomic_reservation_matrix() -> void:
	var all_atomic := true
	var case_count := 0
	for balance in range(7):
		for first_cost in range(7):
			for second_cost in range(7):
				var state := _state(
					["player.0"],
					["player.0"],
					{"player.0": _color_map(balance, 0, 0, 0, 0, 0)}
				)
				var action_0 := _action(
					"action.matrix.b%d.f%d.s%d.0" % [balance, first_cost, second_cost],
					0,
					_cost(first_cost, 0, 0, 0, 0, 0, 0),
					_zero(),
					"target.matrix.0"
				)
				var action_1 := _action(
					"action.matrix.b%d.f%d.s%d.1" % [balance, first_cost, second_cost],
					1,
					_cost(second_cost, 0, 0, 0, 0, 0, 0),
					_zero(),
					"target.matrix.1"
				)
				var intent := Core.build_lock_intent(
					"intent.matrix.b%d.f%d.s%d" % [balance, first_cost, second_cost],
					"batch.test",
					"player.0",
					1000,
					[action_0, action_1]
				)
				var result: Dictionary = _lock_player_queue(
					state,
					intent,
					_color_map(6000, 0, 0, 0, 0, 0),
					1000
				)
				var should_accept := first_cost + second_cost <= balance
				if bool(result.get("accepted", false)) != should_accept:
					all_atomic = false
				elif should_accept:
					var accepted_player := ((result.get("state") as Dictionary).get("players") as Dictionary).get("player.0") as Dictionary
					if int((accepted_player.get("reserved_totals") as Dictionary).get("life", -1)) != first_cost + second_cost \
							or accepted_player.get("assets") != _color_map(balance, 0, 0, 0, 0, 0) \
							or (accepted_player.get("reservations") as Dictionary).size() != 2:
						all_atomic = false
				else:
					var rejected_state := result.get("state") as Dictionary
					var rejected_player := (rejected_state.get("players") as Dictionary).get("player.0") as Dictionary
					if rejected_state != state \
							or not (rejected_player.get("reservations") as Dictionary).is_empty() \
							or rejected_player.get("frozen_gdp_milli") != _zero() \
							or int(rejected_state.get("revision", -1)) != 0:
						all_atomic = false
				case_count += 1
	_expect(all_atomic and case_count == 343, "all 343 balance/two-action combinations commit every reservation or leave exact zero residue")

	var future_refresh_blocked := true
	var colors := ["life", "energy", "industry", "technology", "commerce", "shipping"]
	for color_index in range(colors.size()):
		var cost := _cost(0, 0, 0, 0, 0, 0, 0)
		cost[colors[color_index]] = 1
		var frozen_gdp := _zero()
		frozen_gdp[colors[color_index]] = 6000
		var state := _state(["player.0"], ["player.0"], {"player.0": _assets(0)})
		var result: Dictionary = _lock_player_queue(
			state,
			Core.build_lock_intent(
				"intent.future.%d" % color_index,
				"batch.test",
				"player.0",
				1000,
				[_action("action.future.%d" % color_index, 0, cost, _zero(), "target.future.%d" % color_index)]
			),
			frozen_gdp,
			1000
		)
		if bool(result.get("accepted", true)) or result.get("state") != state:
			future_refresh_blocked = false
	_expect(future_refresh_blocked, "all six colors reject current payment from even a cap-sized future refresh")


func _test_adversarial_rotation_matrix() -> void:
	var player_ids := ["player.0", "player.1", "player.2", "player.3"]
	var hidden_order := ["player.2", "player.0", "player.3", "player.1"]
	var patterns := [
		[0, 0, 0, 0],
		[5, 0, 0, 0],
		[0, 1, 3, 5],
		[5, 4, 3, 2],
		[1, 1, 1, 1],
		[5, 1, 1, 1],
	]
	var all_rotations_exact := true
	var saw_empty_skip := false
	var saw_single_tail := false
	for pattern_index in range(patterns.size()):
		var lengths := patterns[pattern_index] as Array
		var state := _state(player_ids, hidden_order, {
			"player.0": _assets(0),
			"player.1": _assets(0),
			"player.2": _assets(0),
			"player.3": _assets(0),
		})
		var expected: Array[String] = []
		for local_order in range(5):
			for actor_variant in hidden_order:
				var actor_id := str(actor_variant)
				var player_index := player_ids.find(actor_id)
				if local_order < int(lengths[player_index]):
					expected.append("action.rotation.%d.%d.%d" % [pattern_index, player_index, local_order])
		for player_index in range(player_ids.size()):
			var actions: Array = []
			for local_order in range(int(lengths[player_index])):
				actions.append(_action(
					"action.rotation.%d.%d.%d" % [pattern_index, player_index, local_order],
					local_order,
					_cost(0, 0, 0, 0, 0, 0, 0),
					_zero(),
					"target.rotation.%d.%d.%d" % [pattern_index, player_index, local_order]
				))
			var locked: Dictionary = _lock_player_queue(
				state,
				Core.build_lock_intent(
					"intent.rotation.%d.%d" % [pattern_index, player_index],
					"batch.test",
					str(player_ids[player_index]),
					1000,
					actions
				),
				_zero(),
				1000
			)
			if not bool(locked.get("accepted", false)):
				all_rotations_exact = false
				break
			state = locked.get("state") as Dictionary
		var actual: Array[String] = []
		for entry_variant in state.get("authority_queue") as Array:
			actual.append(str((entry_variant as Dictionary).get("action_id", "")))
		if actual != expected:
			all_rotations_exact = false
		if lengths.has(0) and actual.size() == expected.size():
			saw_empty_skip = true
		if pattern_index == 5 and actual.slice(4) == [
			"action.rotation.5.0.1",
			"action.rotation.5.0.2",
			"action.rotation.5.0.3",
			"action.rotation.5.0.4",
		]:
			saw_single_tail = true
		var public := Core.public_projection(state)
		if _contains_key_recursive(public, ["actor_id", "player_skip", "seat", "submission_hidden_lead_order", "frozen_hidden_lead_order"]):
			all_rotations_exact = false
	_expect(all_rotations_exact and patterns.size() == 6, "six adversarial queue-length patterns preserve hidden-lead local-index layering")
	_expect(saw_empty_skip, "rotation matrix skips empty players without emitting a public skip token")
	_expect(saw_single_tail, "rotation matrix leaves a sole remaining player as a natural consecutive tail")


func _test_adversarial_lock_lineage_and_owner_anonymity() -> void:
	var state := _state(
		["player.0", "player.1"],
		["player.1", "player.0"],
		{"player.0": _assets(6), "player.1": _assets(6)}
	)
	var locked_action := Core.build_prebound_action(
		"action.adversarial-lock",
		"monster_action",
		"source.private-alpha",
		0,
		"card.public-alpha",
		Core.build_target_binding("binding.private-alpha", ["region.public-alpha"], 9),
		"effect.public-alpha",
		_cost(1, 0, 0, 0, 0, 0, 0),
		_zero()
	)
	state = (_lock_player_queue(state, Core.build_lock_intent("intent.adversarial.0", "batch.test", "player.0", 100, [locked_action]), _zero(), 1000).get("state") as Dictionary)
	state = (_lock_player_queue(state, Core.build_lock_intent("intent.adversarial.1", "batch.test", "player.1", 100, []), _zero(), 1000).get("state") as Dictionary)
	var tamper_fields := ["source_id", "action_kind", "target_binding"]
	var lock_tamper_rejected := true
	for field in tamper_fields:
		var tampered := state.duplicate(true)
		var action := ((((tampered.get("players") as Dictionary).get("player.0") as Dictionary).get("local_queue") as Array)[0]) as Dictionary
		match field:
			"source_id":
				action["source_id"] = "source.private-forged"
			"action_kind":
				action["action_kind"] = "military_action"
			"target_binding":
				(action.get("target_binding") as Dictionary)["selection_revision"] = 10
		if bool(Core.validation_report(tampered).get("valid", true)) \
				or not Core.to_save_state(tampered).is_empty():
			lock_tamper_rejected = false
	_expect(lock_tamper_rejected, "lock fingerprint rejects private source, action-kind, and target-revision mutation after lock")

	var checkpoint_before := Core.checkpoint(state)
	var success_state := (Core.settle_next_action(state, "action.adversarial-lock", "success").get("state") as Dictionary)
	var refundable_state := (Core.settle_next_action(state, "action.adversarial-lock", "rule_allowed_refundable_failure").get("state") as Dictionary)
	var future_checkpoint := Core.checkpoint(success_state)
	var future_reject: Dictionary = Core.rollback(state, future_checkpoint)
	_expect(not bool(future_reject.get("rolled_back", true)) and str(future_reject.get("reason_code", "")) == "checkpoint_from_future" and future_reject.get("state") == state, "rollback rejects a checkpoint newer than the current revision without mutation")
	var branch_reject: Dictionary = Core.rollback(success_state, Core.checkpoint(refundable_state))
	_expect(not bool(branch_reject.get("rolled_back", true)) and str(branch_reject.get("reason_code", "")) == "checkpoint_not_current_lineage" and branch_reject.get("state") == success_state, "rollback rejects an equal-revision checkpoint from a different receipt lineage")
	var foreign_genesis := _state(
		["player.0", "player.1"],
		["player.1", "player.0"],
		{"player.0": _assets(5), "player.1": _assets(6)}
	)
	var genesis_reject: Dictionary = Core.rollback(success_state, Core.checkpoint(foreign_genesis))
	_expect(not bool(genesis_reject.get("rolled_back", true)) and str(genesis_reject.get("reason_code", "")) == "checkpoint_lineage_invalid" and genesis_reject.get("state") == success_state, "rollback rejects same-batch checkpoint from a different genesis state")
	var ancestor_restore: Dictionary = Core.rollback(success_state, checkpoint_before)
	_expect(bool(ancestor_restore.get("rolled_back", false)) and ancestor_restore.get("state") == state, "rollback still restores an exact ancestor checkpoint")

	var public_action_a := Core.build_prebound_action(
		"action.owner-anonymous",
		"normal_card",
		"source.owner-zero-secret",
		0,
		"card.owner-anonymous",
		Core.build_target_binding("binding.owner-zero-secret", ["region.owner-anonymous"], 1),
		"effect.owner-anonymous",
		_cost(0, 0, 0, 0, 0, 0, 0),
		_zero()
	)
	var public_action_b := Core.build_prebound_action(
		"action.owner-anonymous",
		"normal_card",
		"source.owner-one-secret",
		0,
		"card.owner-anonymous",
		Core.build_target_binding("binding.owner-one-secret", ["region.owner-anonymous"], 1),
		"effect.owner-anonymous",
		_cost(0, 0, 0, 0, 0, 0, 0),
		_zero()
	)
	var state_a := _state(["player.0", "player.1"], ["player.0", "player.1"], {"player.0": _assets(0), "player.1": _assets(0)})
	state_a = (_lock_player_queue(state_a, Core.build_lock_intent("intent.owner-a.0", "batch.test", "player.0", 100, [public_action_a]), _zero(), 1000).get("state") as Dictionary)
	state_a = (_lock_player_queue(state_a, Core.build_lock_intent("intent.owner-a.1", "batch.test", "player.1", 100, []), _zero(), 1000).get("state") as Dictionary)
	var state_b := _state(["player.0", "player.1"], ["player.1", "player.0"], {"player.0": _assets(0), "player.1": _assets(0)})
	state_b = (_lock_player_queue(state_b, Core.build_lock_intent("intent.owner-b.0", "batch.test", "player.0", 100, []), _zero(), 1000).get("state") as Dictionary)
	state_b = (_lock_player_queue(state_b, Core.build_lock_intent("intent.owner-b.1", "batch.test", "player.1", 100, [public_action_b]), _zero(), 1000).get("state") as Dictionary)
	var public_a := Core.public_projection(state_a)
	var public_b := Core.public_projection(state_b)
	_expect(public_a == public_b, "public projection and fingerprint are identical when only owner and hidden lead differ")
	_expect(not _contains_value(public_a, "source.owner-zero-secret") and not _contains_value(public_b, "source.owner-one-secret"), "owner-anonymous projection strips both private source sentinels")
	var rival_ai := Core.ai_observation(state_a, "player.1")
	var rival_player := Core.player_projection(state_a, "player.1")
	_expect(not _contains_value(rival_ai, "source.owner-zero-secret") and not _contains_value(rival_player, "source.owner-zero-secret"), "AI and player rival projections cannot recover owner-private source through the shared public fact")


func _test_fail_closed_shapes_and_zero_mutation() -> void:
	var state := _state(["player.0"], ["player.0"], {"player.0": _assets(6)})
	var incomplete_target := {
		"binding_id": "binding.incomplete",
		"target_ids": ["region.alpha"],
		"selection_revision": 1,
		"complete": false,
	}
	_expect(Core.build_prebound_action("action.incomplete", "normal_card", "source.incomplete", 0, "card.incomplete", incomplete_target, "effect.incomplete", _cost(0, 0, 0, 0, 0, 0, 0), _zero()).is_empty(), "incomplete target binding fails before submission")
	var empty_target := Core.build_target_binding("binding.empty", [], 1)
	_expect(empty_target.is_empty(), "active action cannot lock without a complete target set")
	var malformed_cost := _cost(0, 0, 0, 0, 0, 0, 0)
	malformed_cost.erase("shipping")
	_expect(Core.build_prebound_action("action.bad-cost", "normal_card", "source.bad-cost", 0, "card.bad-cost", Core.build_target_binding("binding.bad-cost", ["region.alpha"], 1), "effect.bad-cost", malformed_cost, _zero()).is_empty(), "six-color authored cost requires every color field")
	var counter_action := _action("action.counter", 0, _cost(0, 0, 0, 0, 0, 0, 0), _zero(), "target.counter")
	counter_action["action_kind"] = "counter"
	_expect(Core.build_lock_intent("intent.counter", "batch.test", "player.0", 100, [counter_action]).is_empty(), "Counter is not an active action kind")
	var extra_counter := _action("action.extra-counter", 0, _cost(0, 0, 0, 0, 0, 0, 0), _zero(), "target.extra-counter")
	extra_counter["counter_window"] = true
	_expect(Core.build_lock_intent("intent.extra-counter", "batch.test", "player.0", 100, [extra_counter]).is_empty(), "undeclared Counter fields fail the closed action schema")

	var duplicate_action := _action("action.duplicate", 0, _cost(0, 0, 0, 0, 0, 0, 0), _zero(), "target.duplicate")
	var duplicate_action_2 := duplicate_action.duplicate(true)
	duplicate_action_2["local_order"] = 1
	_expect(Core.build_lock_intent("intent.duplicate-actions", "batch.test", "player.0", 100, [duplicate_action, duplicate_action_2]).is_empty(), "duplicate action identities fail before lock")
	var gap_action := _action("action.gap", 1, _cost(0, 0, 0, 0, 0, 0, 0), _zero(), "target.gap")
	_expect(Core.build_lock_intent("intent.gap", "batch.test", "player.0", 100, [gap_action]).is_empty(), "local order must be contiguous from zero")

	var valid_intent := Core.build_lock_intent("intent.fingerprint", "batch.test", "player.0", 100, [])
	valid_intent["submitted_at_ms"] = 101
	var before := state.duplicate(true)
	var forged: Dictionary = _lock_player_queue(state, valid_intent, _zero(), 1000)
	_expect(not bool(forged.get("accepted", true)) and str(forged.get("reason_code", "")) == "intent_fingerprint_invalid", "intent fingerprint binds exact submission data")
	_expect(forged.get("state") == before and state == before, "forged intent rejection leaves authority unchanged")

	var malformed_state := state.duplicate(true)
	malformed_state["debug"] = true
	_expect(not bool(Core.validation_report(malformed_state).get("valid", true)), "authority state rejects undeclared debug fields")
	var bad_order := Core.create_state("batch.bad-order", ["player.0", "player.1"], ["player.0", "player.0"], {"player.0": _assets(0), "player.1": _assets(0)})
	_expect(bad_order.is_empty(), "hidden lead order must be an exact player permutation")
	var bad_assets := {"player.0": _assets(0)}
	(bad_assets.get("player.0") as Dictionary).erase("shipping")
	_expect(Core.create_state("batch.bad-assets", ["player.0"], ["player.0"], bad_assets).is_empty(), "asset state requires exactly six independent pools")

	var strict_state := _state(
		["player.0", "player.1"],
		["player.1", "player.0"],
		{"player.0": _assets(6), "player.1": _assets(6)}
	)
	strict_state = (_lock_player_queue(strict_state, Core.build_lock_intent("intent.strict.0", "batch.test", "player.0", 100, [_action("action.strict.0", 0, _cost(1, 0, 0, 0, 0, 0, 0), _zero(), "target.strict.0")]), _zero(), 1000).get("state") as Dictionary)
	strict_state = (_lock_player_queue(strict_state, Core.build_lock_intent("intent.strict.1", "batch.test", "player.1", 100, [_action("action.strict.1", 0, _cost(0, 1, 0, 0, 0, 0, 0), _zero(), "target.strict.1")]), _zero(), 1000).get("state") as Dictionary)
	var reordered := strict_state.duplicate(true)
	(reordered.get("authority_queue") as Array).reverse()
	_expect(not bool(Core.validation_report(reordered).get("valid", true)), "strict state rejects a queue that no longer follows frozen hidden-lead layering")
	var rebound_reservation := strict_state.duplicate(true)
	var rebound_player := (rebound_reservation.get("players") as Dictionary).get("player.0") as Dictionary
	((rebound_player.get("reservations") as Dictionary).get("action.strict.0") as Dictionary)["life"] = 0
	(rebound_player.get("reserved_totals") as Dictionary)["life"] = 0
	_expect(not bool(Core.validation_report(rebound_reservation).get("valid", true)), "strict state binds every reservation to its authored action cost")
	var cursor_forgery := strict_state.duplicate(true)
	cursor_forgery["resolution_cursor"] = 1
	_expect(not bool(Core.validation_report(cursor_forgery).get("valid", true)), "strict state rejects cursor advance without a matching settled result")
	var status_forgery := strict_state.duplicate(true)
	(status_forgery.get("window") as Dictionary)["status"] = "resolving"
	_expect(not bool(Core.validation_report(status_forgery).get("valid", true)), "strict state binds resolution status to cursor position")
	var public_forgery := strict_state.duplicate(true)
	(((public_forgery.get("authority_queue") as Array)[0] as Dictionary).get("public") as Dictionary)["card"] = "card.forged"
	_expect(not bool(Core.validation_report(public_forgery).get("valid", true)), "strict state rebuilds public queue facts from the locked local action")
	var receipt_gap := strict_state.duplicate(true)
	(receipt_gap.get("receipts") as Array).pop_back()
	_expect(not bool(Core.validation_report(receipt_gap).get("valid", true)), "strict state rejects revision and receipt-journal divergence")
	_expect(Core.to_save_state(reordered).is_empty() and Core.to_save_state(rebound_reservation).is_empty(), "Save refuses semantically inconsistent authority states")

	var node_probe := Node.new()
	_expect(not Core.is_pure_data(node_probe) and not Core.is_pure_data(1.5), "Node/object and floating state are excluded from pure deterministic contracts")
	node_probe.free()

	var source := FileAccess.get_file_as_string("res://scripts/v07_semantic/v07_asset_batch_core.gd")
	_expect(source.begins_with("extends RefCounted") and not source.contains("extends Node"), "source remains a non-Node semantic core")
	_expect(
		source.contains("time_attestation: Dictionary,")
			and source.contains("authoritative_time_attestation_v1")
			and not source.contains("authority_observed_at_ms: int,"),
		"lock and close require an authoritative attestation lookup instead of caller numeric time"
	)
	_expect(not source.contains("func open_counter") and not source.contains("func submit_counter") and not source.contains("counter_stack"), "source contains no interactive Counter implementation")
	_expect(not source.contains("RandomNumberGenerator") and not source.contains("randf(") and not source.contains("randi("), "asset and batch domain consumes no RNG")
	_expect(not source.contains("res://scripts/main.gd") and not source.contains("V06SaveOwnerRegistry") and not source.contains("GameRuntimeCoordinator"), "reference core has no Main or V0.6 production connection")


func _issue_time_attestation(
	observed_at_ms: int,
	authority: TrustedTimeAttestationAuthority = null,
	id_prefix: String = "time.test"
) -> Dictionary:
	var selected_authority := _time_authority if authority == null else authority
	_time_attestation_sequence += 1
	var attestation := {
		"schema_version": 1,
		"interface_id": Core.TIME_ATTESTATION_INTERFACE_ID,
		"attestation_id": "%s.%06d" % [id_prefix, _time_attestation_sequence],
		"observed_at_ms": observed_at_ms,
	}
	attestation["attestation_fingerprint"] = Core._fingerprint(attestation)
	selected_authority.commit_attestation(attestation)
	return attestation


func _lock_player_queue(
	state: Dictionary,
	intent: Dictionary,
	completed_gdp_milli: Dictionary,
	observed_at_ms: int,
	authoritative_hidden_lead_order: Array = []
) -> Dictionary:
	return _timed_core.lock_player_queue(
		state,
		intent,
		completed_gdp_milli,
		_issue_time_attestation(observed_at_ms),
		authoritative_hidden_lead_order
	)


func _close_expired_window(
	state: Dictionary,
	observed_at_ms: int,
	completed_gdp_milli_by_player: Dictionary,
	authoritative_hidden_lead_order: Array = []
) -> Dictionary:
	return _timed_core.close_expired_window(
		state,
		_issue_time_attestation(observed_at_ms),
		completed_gdp_milli_by_player,
		authoritative_hidden_lead_order
	)


func _state(player_ids: Array, hidden_order: Array, assets: Variant) -> Dictionary:
	var assets_by_player := {}
	if assets is Dictionary and _same_string_set((assets as Dictionary).keys(), player_ids):
		assets_by_player = (assets as Dictionary).duplicate(true)
	else:
		for player_id_variant in player_ids:
			assets_by_player[str(player_id_variant)] = (assets as Dictionary).duplicate(true)
	return Core.create_state("batch.test", player_ids, hidden_order, assets_by_player, {}, 1000, 1000)


func _action(
	action_id: String,
	local_order: int,
	cost: Dictionary,
	any_payment: Dictionary,
	target_id: String,
	invalid_target_policy_id: String = Core.DEFAULT_INVALID_TARGET_POLICY_ID
) -> Dictionary:
	return Core.build_prebound_action(
		action_id,
		"normal_card",
		"source.%s" % action_id,
		local_order,
		"card.%s" % action_id,
		Core.build_target_binding("binding.%s" % action_id, [target_id], 1),
		"effect.%s" % action_id,
		cost,
		any_payment,
		invalid_target_policy_id
	)


func _assets(amount: int) -> Dictionary:
	return _color_map(amount, amount, amount, amount, amount, amount)


func _zero() -> Dictionary:
	return _assets(0)


func _color_map(
	life: int,
	energy: int,
	industry: int,
	technology: int,
	commerce: int,
	shipping: int
) -> Dictionary:
	return {
		"life": life,
		"energy": energy,
		"industry": industry,
		"technology": technology,
		"commerce": commerce,
		"shipping": shipping,
	}


func _cost(
	life: int,
	energy: int,
	industry: int,
	technology: int,
	commerce: int,
	shipping: int,
	any: int
) -> Dictionary:
	var result := _color_map(life, energy, industry, technology, commerce, shipping)
	result["any"] = any
	return result


func _same_string_set(left: Array, right: Array) -> bool:
	var left_strings: Array[String] = []
	var right_strings: Array[String] = []
	for value in left:
		left_strings.append(str(value))
	for value in right:
		right_strings.append(str(value))
	left_strings.sort()
	right_strings.sort()
	return left_strings == right_strings


func _contains_key_recursive(value: Variant, keys: Array) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if keys.has(str(key_variant)) or _contains_key_recursive((value as Dictionary).get(key_variant), keys):
				return true
	elif value is Array:
		for item_variant in value as Array:
			if _contains_key_recursive(item_variant, keys):
				return true
	return false


func _contains_value(value: Variant, expected: String) -> bool:
	if value is String:
		return str(value) == expected
	if value is Dictionary:
		for item_variant in (value as Dictionary).values():
			if _contains_value(item_variant, expected):
				return true
	elif value is Array:
		for item_variant in value as Array:
			if _contains_value(item_variant, expected):
				return true
	return false


func _reseal_domain_contract(value: Dictionary, fingerprint_field: String) -> void:
	value.erase(fingerprint_field)
	value[fingerprint_field] = Core._fingerprint(value)


func _domain_fingerprint_matches(
	value: Dictionary,
	fingerprint_field: String
) -> bool:
	var observed := str(value.get(fingerprint_field, ""))
	var unsealed := value.duplicate(true)
	unsealed.erase(fingerprint_field)
	return observed.length() == 64 and observed == Core._fingerprint(unsealed)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("V07 ASSET BATCH CORE: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("V07 asset batch core test passed. checks=%d" % _checks)
		quit(0)
		return
	push_error("V07 asset batch core test failed:\n- %s" % "\n- ".join(_failures))
	quit(1)
