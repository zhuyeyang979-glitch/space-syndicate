extends SceneTree

const Core := preload("res://scripts/v07_semantic/v07_dbg_deck_core.gd")
const TrackCore := preload("res://scripts/v07_semantic/v07_unified_card_track_core.gd")
const AcquisitionPort := preload(
	"res://scripts/v07_semantic/v07_track_acquisition_authority_port.gd"
)

const OWNER_ID := "player.alpha"
const OTHER_PLAYER_ID := "player.beta"
const FIXED_SEED := 900626424
const TRACK_ROSTER := [OWNER_ID, OTHER_PLAYER_ID, "player.gamma", "player.delta"]

var _checks := 0
var _failures: Array[String] = []


class PassiveAcquisitionParticipant extends RefCounted:
	var authority_id: String
	var state := {"reservations": {}, "commits": {}}

	func _init(value: String) -> void:
		authority_id = value

	func acquisition_authority_id_v1() -> String:
		return authority_id

	func prepare_acquisition_v1(request: Dictionary) -> Dictionary:
		var reservation_id := "reservation.passive.%s" % str(
			request.get("transaction_id", "")
		).sha256_text().left(24)
		(state.get("reservations", {}) as Dictionary)[reservation_id] = (
			request.duplicate(true)
		)
		return {
			"accepted": true,
			"reason_code": "passive_participant_prepared",
			"reservation_id": reservation_id,
		}

	func commit_prepared_acquisition_v1(
		reservation_id: String,
		track_receipt: Dictionary
	) -> Dictionary:
		if not (state.get("reservations", {}) as Dictionary).has(reservation_id):
			return {"accepted": false, "reason_code": "reservation_missing"}
		var result := {
			"accepted": true,
			"reason_code": "passive_participant_committed",
			"reservation_id": reservation_id,
			"track_receipt_fingerprint": str(track_receipt.get(
				"receipt_fingerprint", ""
			)),
		}
		(state.get("commits", {}) as Dictionary)[reservation_id] = result
		(state.get("reservations", {}) as Dictionary).erase(reservation_id)
		return result.duplicate(true)

	func abort_prepared_acquisition_v1(
		reservation_id: String,
		_reason_code: String
	) -> Dictionary:
		(state.get("reservations", {}) as Dictionary).erase(reservation_id)
		return {"accepted": true, "reason_code": "passive_participant_aborted"}

	func capture_checkpoint_v1() -> Dictionary:
		return state.duplicate(true)

	func rollback_v1(checkpoint: Dictionary) -> Dictionary:
		state = checkpoint.duplicate(true)
		return {"accepted": true, "reason_code": "passive_participant_rolled_back"}


class MaliciousTrackAuthorityWrapper extends RefCounted:
	var forged_receipt: Dictionary = {}

	func authoritative_receipt_v1(_request_id: String) -> Dictionary:
		return forged_receipt.duplicate(true)

	func bind_acquisition_authority_port_v1(_port: RefCounted) -> Dictionary:
		return {"accepted": true}

	func prepare_visible_acquisition_v1(_intent: Dictionary) -> Dictionary:
		return {"accepted": true}

	func commit_prepared_acquisition_v1(
		_transaction_id: String,
		_port: RefCounted
	) -> Dictionary:
		return forged_receipt.duplicate(true)

	func rollback_acquisition_transaction_v1(
		_transaction_id: String,
		_port: RefCounted
	) -> Dictionary:
		return {"accepted": true}

	func finalize_acquisition_transaction_v1(
		_transaction_id: String,
		_port: RefCounted
	) -> Dictionary:
		return {"accepted": true}

	func core_authority_v1() -> Dictionary:
		return {}

	func ai_observation_v1(_actor_id: String) -> Dictionary:
		return {}

	func save_state_v1() -> Dictionary:
		return {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_starter_deck_and_fixed_seed()
	_test_typed_state_contract_mapping()
	_test_play_purchase_and_batch_refill()
	_test_discard_reshuffle()
	_test_optional_merge_and_rejections()
	_test_minimum_normal_deck_size_gate()
	_test_real_unified_track_claim_bridge()
	_test_track_claim_adversarial_binding()
	_test_commodity_claim_inventory_and_merge()
	_test_commodity_batch_availability_and_roundtrip()
	_test_commodity_checkpoint_save_exact_once_and_privacy()
	_test_checkpoint_rollback_and_exact_once()
	_test_three_wing_projection_intent_receipt_and_privacy()
	_test_six_contract_fact_binding_and_alias_rejection()
	_test_save_roundtrip_and_rng_continuity()
	_test_save_and_rng_fail_closed()
	_test_reference_boundary()
	_finish()


func _test_starter_deck_and_fixed_seed() -> void:
	var core := _new_core(FIXED_SEED)
	var same_seed := _new_core(FIXED_SEED)
	var other_seed := _new_core(FIXED_SEED + 1)
	var other_owner := _new_core_for_owner(OTHER_PLAYER_ID, FIXED_SEED)
	_expect(
		core is RefCounted and not core.has_method("get_tree") and not core.has_method("add_child"),
		"DBG authority is a non-Node RefCounted core"
	)
	var specs: Array = Core.starter_card_specs()
	_expect(specs.size() == 12, "starter deck has exactly twelve cards")
	var composition := {}
	for spec_variant in specs:
		var spec := spec_variant as Dictionary
		var key := "%s:%s:L%d" % [
			str(spec.get("primary_color", "")),
			str(spec.get("card_type", "")),
			int(spec.get("level", 0)),
		]
		composition[key] = int(composition.get(key, 0)) + 1
	for color_variant in Core.COLORS:
		var color := str(color_variant)
		_expect(
			int(composition.get("%s:factory:L1" % color, 0)) == 1,
			"starter deck has one %s L1 factory" % color
		)
		_expect(
			int(composition.get("%s:market:L1" % color, 0)) == 1,
			"starter deck has one %s L1 market" % color
		)
	var state := _state(core)
	_expect(
		Core.SCHEMA_VERSION == 2
		and Core.STATE_VERSION == 2
		and Core.RULESET_ID == "v0.7.1"
		and state.get("schema_version") == 2
		and state.get("state_version") == 2
		and state.get("ruleset_id") == "v0.7.1",
		"DBG interfaces and authority state identify frozen V0.7.1 version 2"
	)
	_expect(
		state.get("balance_profile_id") == Core.BALANCE_PROFILE_ID
		and state.get("balance_profile_fingerprint") \
		== Core.BALANCE_PROFILE_FINGERPRINT
		and Core.BALANCE_PROFILE_ID == "V071_CANDIDATE_A_FAST"
		and Core.BALANCE_PROFILE_FINGERPRINT \
		== "8d8de8d406ca2f7d5123ecc951a606a0a08b56282bc3d6a40e0cd4d5ff50f19a",
		"authority state is pinned to the approved Candidate A profile"
	)
	_expect((state.get("hand", []) as Array).size() == 5, "fixed-seed starter deal draws five")
	_expect((state.get("draw_pile", []) as Array).size() == 7, "seven starter cards remain in draw pile")
	_expect((state.get("discard", []) as Array).is_empty(), "starter discard begins empty")
	_expect(_all_cards(state).size() == 12, "all twelve starter instances remain in personal DBG zones")
	_expect(_unique_instance_count(state) == 12, "starter card instances are unique")
	_expect(
		_semantic_order(state.get("hand", []) as Array)
		== _semantic_order((_state(same_seed).get("hand", []) as Array)),
		"identical fixed seeds deal the identical hand order"
	)
	_expect(
		_semantic_order(state.get("draw_pile", []) as Array)
		== _semantic_order((_state(same_seed).get("draw_pile", []) as Array)),
		"identical fixed seeds preserve the identical remaining draw order"
	)
	_expect(
		_semantic_order(state.get("hand", []) as Array)
		!= _semantic_order((_state(other_seed).get("hand", []) as Array)),
		"a different seed changes the unforced random opening hand"
	)
	var starter_rng := state.get("starter_rng", {}) as Dictionary
	var reshuffle_rng := state.get("reshuffle_rng", {}) as Dictionary
	_expect(
		str(starter_rng.get("stream_id", "")) == "starter_deck_shuffle"
		and _tagged_value(starter_rng.get("cursor")) == 11
		and _tagged_value(starter_rng.get("stream_revision")) == 11,
		"starter Fisher-Yates shuffle owns exactly eleven starter-stream draws"
	)
	_expect(
		str(reshuffle_rng.get("stream_id", "")) == "normal_deck_reshuffle_by_player"
		and _tagged_value(reshuffle_rng.get("cursor")) == 0
		and _tagged_value(reshuffle_rng.get("stream_revision")) == 0,
		"personal reshuffle stream remains untouched during the starter deal"
	)
	_expect(
		_has_exact_fields(starter_rng, Core.RNG_FIELDS)
		and starter_rng.get("stream_instance_id") == OWNER_ID
		and starter_rng.get("authoritative_owner_id") == Core.RNG_AUTHORITY_OWNER_ID
		and starter_rng.get("algorithm_id") == Core.RNG_ALGORITHM_ID
		and _is_tagged_int64(starter_rng.get("seed"), false)
		and _is_tagged_int64(starter_rng.get("cursor"), true)
		and _is_tagged_int64(starter_rng.get("stream_revision"), true)
		and str(starter_rng.get("state_fingerprint", "")).length() == 64,
		"starter RNG closes the documented nine-field identity, owner, algorithm, seed, cursor, revision, and fingerprint wire contract"
	)
	var other_owner_state := _state(other_owner)
	_expect(
		starter_rng != other_owner_state.get("starter_rng", {})
		and reshuffle_rng != other_owner_state.get("reshuffle_rng", {})
		and (starter_rng.get("seed", {}) as Dictionary)
		!= ((other_owner_state.get("starter_rng", {}) as Dictionary).get("seed", {}) as Dictionary),
		"the same root seed derives distinct starter and reshuffle streams for different owner_player_id values"
	)
	_expect(
		starter_rng.get("seed", {}) != reshuffle_rng.get("seed", {})
		and starter_rng.get("stream_instance_id") == reshuffle_rng.get("stream_instance_id"),
		"starter and reshuffle streams are independently derived inside one player partition"
	)
	_expect(
		_is_tagged_int64(state.get("root_seed"), false)
		and _tagged_value(state.get("root_seed")) == FIXED_SEED,
		"root match seed is persisted as strict tagged Int64 without JSON-number coercion"
	)
	_expect(Core.is_pure_data(core.core_authority_snapshot()), "authority snapshot is closed pure data")
	var contract: Dictionary = Core.three_wing_contract()
	_expect(
		str(contract.get("core_authority_schema_id", "")) == "v071.personal_dbg.core_authority.v2"
		and str(contract.get("ai_observation_schema_id", "")) == "v071.personal_dbg.ai_observation.v2"
		and str(contract.get("player_projection_schema_id", "")) == "v071.personal_dbg.player_projection.v2",
		"DBG publishes one Core authority and both three-wing projection schemas"
	)
	_expect(
		not bool(contract.get("automatic_merge_allowed", true))
		and not bool(contract.get("mid_batch_refill_allowed", true))
		and not bool(contract.get("save_is_second_authority", true)),
		"contract freezes optional merge, no mid-batch refill, and non-authoritative Save"
	)


func _test_typed_state_contract_mapping() -> void:
	var expected := {
		"normal_deck_state": "V071NormalDeckState",
		"normal_hand_state": "V071NormalHandState",
		"normal_discard_state": "V071NormalDiscardState",
		"normal_merge_state": "V071NormalMergeState",
		"commodity_inventory_state": "V071CommodityInventoryState",
		"bound_source_state": "V071BoundSourceLifecycleState",
		"local_queue_state": "V071LocalQueueState",
	}
	_expect(
		Core.NORMAL_DECK_STATE_CONTRACT_ID == "V071NormalDeckState"
		and Core.NORMAL_HAND_STATE_CONTRACT_ID == "V071NormalHandState"
		and Core.NORMAL_DISCARD_STATE_CONTRACT_ID == "V071NormalDiscardState"
		and Core.NORMAL_MERGE_STATE_CONTRACT_ID == "V071NormalMergeState"
		and Core.COMMODITY_INVENTORY_STATE_CONTRACT_ID == "V071CommodityInventoryState"
		and Core.BOUND_SOURCE_STATE_CONTRACT_ID == "V071BoundSourceLifecycleState"
		and Core.LOCAL_QUEUE_STATE_CONTRACT_ID == "V071LocalQueueState",
		"Prompt-required DBG state contract IDs are explicit stable constants"
	)
	var mapping: Dictionary = Core.typed_state_contracts()
	_expect(
		mapping == expected and Core.validate_typed_state_contracts(mapping).is_empty(),
		"typed state contract map has seven closed DBG, commodity, bound-source, and local-queue entries"
	)
	_expect(
		Core.is_pure_data(mapping)
		and mapping.get("commodity_inventory_state") == "V071CommodityInventoryState"
		and mapping.get("bound_source_state") == "V071BoundSourceLifecycleState"
		and mapping.get("local_queue_state") == "V071LocalQueueState",
		"typed map is pure data and names the implemented commodity state plus an honest bound-source lifecycle contract"
	)
	var extra_mapping := mapping.duplicate(true)
	extra_mapping["undeclared_state"] = "V07UndeclaredState"
	_expect(
		Core.validate_typed_state_contracts(extra_mapping)
		== "typed_state_contract_fields_invalid",
		"typed map rejects undeclared state contracts"
	)
	var missing_mapping := mapping.duplicate(true)
	missing_mapping.erase("normal_discard_state")
	_expect(
		Core.validate_typed_state_contracts(missing_mapping)
		== "typed_state_contract_fields_invalid",
		"typed map rejects a missing required state contract"
	)
	var wrong_mapping := mapping.duplicate(true)
	wrong_mapping["normal_merge_state"] = "V07AutomaticMergeState"
	_expect(
		Core.validate_typed_state_contracts(wrong_mapping)
		== "typed_state_contract_identity_invalid",
		"typed map rejects an altered state contract identity"
	)
	mapping["normal_deck_state"] = "mutated.by.caller"
	_expect(
		Core.typed_state_contracts() == expected,
		"typed state contract mapping is returned as a defensive fresh value"
	)

	var contract: Dictionary = Core.three_wing_contract()
	_expect(
		Core.validate_three_wing_contract(contract).is_empty()
		and contract.get("typed_state_contracts", {}) == expected,
		"three-wing contract carries and validates the exact typed state mapping"
	)
	var extra_contract := contract.duplicate(true)
	extra_contract["unversioned_state"] = "forbidden"
	_expect(
		Core.validate_three_wing_contract(extra_contract)
		== "three_wing_contract_fields_invalid",
		"three-wing contract rejects undeclared top-level fields"
	)
	var wrong_contract := contract.duplicate(true)
	(wrong_contract.get("typed_state_contracts", {}) as Dictionary)[
		"normal_hand_state"
	] = "V07UnboundedHandState"
	_expect(
		Core.validate_three_wing_contract(wrong_contract)
		== "three_wing_contract_typed_state_contract_identity_invalid",
		"three-wing contract rejects a modified nested state identity"
	)

	var core := _new_core(FIXED_SEED)
	var authority: Dictionary = core.core_authority_snapshot()
	var save_state: Dictionary = core.to_save_state()
	_expect(
		authority.get("typed_state_contracts", {}) == expected
		and save_state.get("typed_state_contracts", {}) == expected
		and authority.get("typed_state_contracts", {})
		== contract.get("typed_state_contracts", {}),
		"three-wing, CoreAuthority, and SaveState expose one identical state map"
	)
	_expect(
		Core.validate_core_authority_snapshot(authority).is_empty()
		and Core.validate_save_state(save_state).is_empty(),
		"CoreAuthority and SaveState validate their typed state mappings"
	)
	var extra_authority := authority.duplicate(true)
	(extra_authority.get("typed_state_contracts", {}) as Dictionary)[
		"normal_inventory_alias"
	] = "V07NormalInventoryAlias"
	_expect(
		Core.validate_core_authority_snapshot(extra_authority)
		== "core_authority_typed_state_contracts_invalid",
		"CoreAuthority rejects an extra typed state mapping field"
	)
	var missing_save_mapping := save_state.duplicate(true)
	(missing_save_mapping.get("typed_state_contracts", {}) as Dictionary).erase(
		"normal_merge_state"
	)
	_expect(
		Core.validate_save_state(missing_save_mapping)
		== "save_state_typed_state_contracts_invalid",
		"SaveState rejects a missing typed state mapping without defaulting it"
	)


func _test_play_purchase_and_batch_refill() -> void:
	var core := _new_core(FIXED_SEED)
	var state_before := _state(core)
	var hand_before := state_before.get("hand", []) as Array
	var played_id := str((hand_before[0] as Dictionary).get("instance_id", ""))
	var starter_rng_before := (state_before.get("starter_rng", {}) as Dictionary).duplicate(true)
	var reshuffle_rng_before := (state_before.get("reshuffle_rng", {}) as Dictionary).duplicate(true)
	var play_intent: Dictionary = core.create_intent(
		"request.play.1", OWNER_ID, Core.ACTION_PLAY_CARD, {"instance_id": played_id}
	)
	var play_receipt: Dictionary = core.apply_intent(play_intent)
	var after_play := _state(core)
	_expect(
		bool(play_receipt.get("success", false))
		and str(play_receipt.get("destination_zone", "")) == "discard",
		"played normal card resolves into personal discard"
	)
	_expect(
		(after_play.get("hand", []) as Array).size() == 4
		and (after_play.get("draw_pile", []) as Array).size() == 7
		and _zone_has(after_play.get("discard", []) as Array, played_id),
		"play removes one hand card without a mid-batch replacement draw"
	)
	_expect(
		after_play.get("starter_rng", {}) == starter_rng_before
		and after_play.get("reshuffle_rng", {}) == reshuffle_rng_before,
		"play consumes no deck RNG"
	)

	var purchased_spec := (Core.starter_card_specs()[0] as Dictionary).duplicate(true)
	var purchase_intent: Dictionary = core.create_authority_intent(
		"request.purchase.1",
		Core.ACTION_ACCEPT_PURCHASE,
		{"purchase_receipt_id": "track.purchase.1", "card_spec": purchased_spec}
	)
	var purchase_receipt: Dictionary = core.apply_intent(purchase_intent)
	var purchased_id := str(purchase_receipt.get("created_instance_id", ""))
	var after_purchase := _state(core)
	_expect(
		bool(purchase_receipt.get("success", false))
		and str(purchase_receipt.get("reason_code", "")) == "purchased_card_entered_discard",
		"authoritative purchase produces a typed success receipt"
	)
	_expect(
		(after_purchase.get("hand", []) as Array).size() == 4
		and (after_purchase.get("draw_pile", []) as Array).size() == 7
		and _zone_has(after_purchase.get("discard", []) as Array, purchased_id),
		"purchased card enters discard and is not immediately usable"
	)
	_expect(
		after_purchase.get("starter_rng", {}) == starter_rng_before
		and after_purchase.get("reshuffle_rng", {}) == reshuffle_rng_before,
		"purchase consumes no personal deck RNG"
	)

	var complete_intent: Dictionary = core.create_authority_intent(
		"request.batch.complete.1", Core.ACTION_COMPLETE_BATCH
	)
	var complete_receipt: Dictionary = core.apply_intent(complete_intent)
	var after_complete := _state(core)
	_expect(
		bool(complete_receipt.get("success", false))
		and int(complete_receipt.get("refill_count", -1)) == 1,
		"batch completion refills the four-card hand by exactly one"
	)
	_expect(
		(after_complete.get("hand", []) as Array).size() == 5
		and (after_complete.get("draw_pile", []) as Array).size() == 6
		and str(after_complete.get("phase", "")) == Core.PHASE_MAINTENANCE,
		"hand reaches five only after the batch enters maintenance"
	)
	_expect(
		_zone_has(after_complete.get("discard", []) as Array, played_id)
		and _zone_has(after_complete.get("discard", []) as Array, purchased_id),
		"existing draw pile is consumed before played or purchased discard can reshuffle"
	)


func _test_discard_reshuffle() -> void:
	var core := _new_core(FIXED_SEED)
	var saw_reshuffle := false
	for batch_number in range(1, 5):
		var state_before := _state(core)
		var draw_count_before := _tagged_value(
			(state_before.get("reshuffle_rng", {}) as Dictionary).get("cursor")
		)
		var draw_size_before := (state_before.get("draw_pile", []) as Array).size()
		var ids: Array[String] = []
		for card_variant in state_before.get("hand", []) as Array:
			ids.append(str((card_variant as Dictionary).get("instance_id", "")))
		for card_id in ids:
			var receipt: Dictionary = core.apply_intent(core.create_intent(
				"request.reshuffle.play.%d.%s" % [batch_number, card_id],
				OWNER_ID,
				Core.ACTION_PLAY_CARD,
				{"instance_id": card_id}
			))
			_expect(bool(receipt.get("success", false)), "batch %d play enters discard" % batch_number)
		var before_complete := _state(core)
		_expect(
			(before_complete.get("hand", []) as Array).is_empty()
			and (before_complete.get("draw_pile", []) as Array).size() == draw_size_before
			and _tagged_value(
				(before_complete.get("reshuffle_rng", {}) as Dictionary).get("cursor")
			) == draw_count_before,
			"batch %d performs neither refill nor reshuffle during play" % batch_number
		)
		var complete_receipt: Dictionary = core.apply_intent(core.create_authority_intent(
			"request.reshuffle.complete.%d" % batch_number,
			Core.ACTION_COMPLETE_BATCH
		))
		var after_complete := _state(core)
		_expect(
			bool(complete_receipt.get("success", false))
			and (after_complete.get("hand", []) as Array).size() == 5,
			"batch %d maintenance draws back to five" % batch_number
		)
		if int(complete_receipt.get("reshuffle_count", 0)) > 0:
			saw_reshuffle = true
			_expect(
				_tagged_value(
					(after_complete.get("reshuffle_rng", {}) as Dictionary).get("cursor")
				) > draw_count_before,
				"insufficient draw pile advances only the dedicated reshuffle stream"
			)
			break
		var end_receipt: Dictionary = core.apply_intent(core.create_intent(
			"request.reshuffle.end.%d" % batch_number,
			OWNER_ID,
			Core.ACTION_END_MAINTENANCE
		))
		_expect(bool(end_receipt.get("success", false)), "batch %d maintenance ends explicitly" % batch_number)
	_expect(saw_reshuffle, "discard is authoritatively reshuffled when draw pile cannot satisfy refill")

	var parity_a := _new_core(FIXED_SEED)
	var parity_b := _new_core(FIXED_SEED)
	_drive_two_full_batches(parity_a, "parity.a")
	_drive_two_full_batches(parity_b, "parity.a")
	_expect(
		str(parity_a.core_authority_snapshot().get("state_fingerprint", ""))
		== str(parity_b.core_authority_snapshot().get("state_fingerprint", "")),
		"fixed seed and identical intents reproduce the exact post-reshuffle authority state"
	)


func _test_optional_merge_and_rejections() -> void:
	var rejection_core := _new_core(FIXED_SEED)
	var complete_receipt: Dictionary = rejection_core.apply_intent(
		rejection_core.create_authority_intent("request.reject.complete", Core.ACTION_COMPLETE_BATCH)
	)
	_expect(bool(complete_receipt.get("success", false)), "full opening hand can enter maintenance without drawing")
	var rejection_state := _state(rejection_core)
	var different_colors := _different_color_pair(rejection_state.get("hand", []) as Array)
	_expect(different_colors.size() == 2, "opening hand necessarily contains a cross-color pair")
	var before_rejection := str(rejection_core.core_authority_snapshot().get("state_fingerprint", ""))
	var cross_color_receipt: Dictionary = rejection_core.apply_intent(rejection_core.create_intent(
		"request.merge.cross_color",
		OWNER_ID,
		Core.ACTION_MERGE_CARDS,
		{"left_instance_id": different_colors[0], "right_instance_id": different_colors[1]}
	))
	_expect(
		not bool(cross_color_receipt.get("success", true))
		and str(cross_color_receipt.get("reason_code", "")) == "merge_primary_color_mismatch",
		"different-color normal cards are rejected before merge"
	)
	_expect(
		str(rejection_core.core_authority_snapshot().get("state_fingerprint", "")) == before_rejection,
		"rejected cross-color merge leaves authority state unchanged"
	)
	var auto_intent: Dictionary = rejection_core.create_intent(
		"request.merge.automatic",
		OWNER_ID,
		Core.ACTION_MERGE_CARDS,
		{"left_instance_id": different_colors[0], "right_instance_id": different_colors[1]},
		Core.DECISION_AUTOMATIC
	)
	var auto_receipt: Dictionary = rejection_core.apply_intent(auto_intent)
	_expect(
		not bool(auto_receipt.get("success", true))
		and str(auto_receipt.get("reason_code", "")) == "automatic_merge_forbidden",
		"automatic normal-card merge is explicitly rejected"
	)
	_expect(
		str(rejection_core.core_authority_snapshot().get("state_fingerprint", "")) == before_rejection,
		"automatic merge rejection performs zero state mutation"
	)

	var core := _new_core(FIXED_SEED)
	var target_spec := (Core.starter_card_specs()[0] as Dictionary).duplicate(true)
	for purchase_index in range(2):
		var receipt: Dictionary = core.apply_intent(core.create_authority_intent(
			"request.merge.purchase.%d" % purchase_index,
			Core.ACTION_ACCEPT_PURCHASE,
			{
				"purchase_receipt_id": "track.merge.purchase.%d" % purchase_index,
				"card_spec": target_spec,
			}
		))
		_expect(bool(receipt.get("success", false)), "duplicate merge fixture is acquired through purchase %d" % purchase_index)
	var pair := _bring_matching_pair_to_maintenance(core, str(target_spec.get("semantic_id", "")))
	_expect(pair.size() == 2, "real DBG cycles bring two purchased-family cards into maintenance hand")
	var pair_state := _state(core)
	var hand_before := (pair_state.get("hand", []) as Array).size()
	var merge_history_before := (pair_state.get("merge_history", []) as Array).size()
	_expect(
		_count_semantic(pair_state.get("hand", []) as Array, str(target_spec.get("semantic_id", ""))) >= 2,
		"eligible duplicates remain unmerged until player choice"
	)
	var merge_receipt: Dictionary = core.apply_intent(core.create_intent(
		"request.merge.explicit",
		OWNER_ID,
		Core.ACTION_MERGE_CARDS,
		{"left_instance_id": pair[0], "right_instance_id": pair[1]}
	))
	var after_merge := _state(core)
	var result_id := str(merge_receipt.get("created_instance_id", ""))
	var result_card := _find_card(after_merge.get("hand", []) as Array, result_id)
	_expect(
		bool(merge_receipt.get("success", false))
		and str(merge_receipt.get("reason_code", "")) == "normal_cards_merged",
		"explicit player merge returns an authoritative receipt"
	)
	_expect(
		int(result_card.get("level", 0)) == 2
		and str(result_card.get("primary_color", "")) == str(target_spec.get("primary_color", ""))
		and str(result_card.get("card_type", "")) == str(target_spec.get("card_type", ""))
		and str(result_card.get("merge_family_id", "")) == str(target_spec.get("merge_family_id", "")),
		"same-color/type/family L1 pair creates a new L2 identity"
	)
	_expect(
		not _any_zone_has(after_merge, str(pair[0]))
		and not _any_zone_has(after_merge, str(pair[1]))
		and _any_zone_has(after_merge, result_id),
		"merge consumes both source identities exactly once and retains only the result"
	)
	_expect(
		(after_merge.get("hand", []) as Array).size() == hand_before
		and int(merge_receipt.get("refill_count", -1)) == 1,
		"accepted merge immediately refills the one newly open hand slot"
	)
	_expect(
		(after_merge.get("merge_history", []) as Array).size() == merge_history_before + 1,
		"merge lineage is persisted as authority state"
	)


func _test_minimum_normal_deck_size_gate() -> void:
	var minimum_core := _normal_merge_count_fixture(5, FIXED_SEED + 301)
	var minimum_state := _state(minimum_core)
	var minimum_hand := minimum_state.get("hand", []) as Array
	var minimum_before: Dictionary = minimum_core.core_authority_snapshot()
	var minimum_projection: Dictionary = minimum_core.player_projection(OWNER_ID)
	var minimum_receipt: Dictionary = minimum_core.apply_intent(
		minimum_core.create_intent(
			"request.merge.minimum_five",
			OWNER_ID,
			Core.ACTION_MERGE_CARDS,
			{
				"left_instance_id": str((minimum_hand[0] as Dictionary).get(
					"instance_id", ""
				)),
				"right_instance_id": str((minimum_hand[1] as Dictionary).get(
					"instance_id", ""
				)),
			}
		)
	)
	_expect(
		not bool(minimum_receipt.get("success", true))
		and minimum_receipt.get("reason_code") \
		== "minimum_normal_deck_size_violation"
		and minimum_core.core_authority_snapshot() == minimum_before,
		"normal merge at five total cards fails closed before identity allocation or mutation"
	)
	_expect(
		((minimum_projection.get("facts", {}) as Dictionary).get(
			"eligible_merge_pairs", []
		) as Array).is_empty(),
		"minimum-five projection does not advertise a merge the authority must reject"
	)

	var six_core := _normal_merge_count_fixture(6, FIXED_SEED + 302)
	var six_hand := _state(six_core).get("hand", []) as Array
	var six_receipt: Dictionary = six_core.apply_intent(six_core.create_intent(
		"request.merge.minimum_six",
		OWNER_ID,
		Core.ACTION_MERGE_CARDS,
		{
			"left_instance_id": str((six_hand[0] as Dictionary).get("instance_id", "")),
			"right_instance_id": str((six_hand[1] as Dictionary).get("instance_id", "")),
		}
	))
	_expect(
		bool(six_receipt.get("success", false))
		and _all_cards(_state(six_core)).size() \
		== Core.NORMAL_DECK_MINIMUM_TOTAL_CARD_COUNT,
		"normal merge from six total cards succeeds and terminates exactly at five"
	)


func _test_real_unified_track_claim_bridge() -> void:
	var proof := _real_track_claim_proof(1)
	_expect(not proof.is_empty(), "Unified Track fixed seed produces an uncommitted commodity intent")
	if proof.is_empty():
		return
	var actor_id := str(proof.get("actor_id", ""))
	var track_authority := proof.get("authority") as RefCounted
	var track_intent := proof.get("track_intent", {}) as Dictionary
	var observation := proof.get("track_ai_observation", {}) as Dictionary
	var core := _new_core_for_owner(actor_id, FIXED_SEED)
	_expect(
		_bind_track_authority(core, proof),
		"DBG pins the exact issuing Unified Track script, match, and lineage"
	)
	var bound_state := _state(core).get("bound_source_state", {}) as Dictionary
	_expect(
		bound_state.get("runtime_binding_supported") == true
		and (bound_state.get("entries", []) as Array).size() == 1
		and Core.is_pure_data(bound_state),
		"binding persists one pure match-instance and lineage pin"
	)
	var port := _new_acquisition_port(core, track_authority)
	_expect(port.call("is_configured"), "stable acquisition port accepts DBG as commodity-slot participant")
	var track_before := track_authority.call("core_authority_v1") as Dictionary
	var dbg_before: Dictionary = core.core_authority_snapshot()
	var prepared: Dictionary = port.call("prepare_v1", track_intent)
	_expect(
		bool(prepared.get("accepted", false))
		and bool(prepared.get("prepared", false))
		and track_authority.call("core_authority_v1") == track_before
		and core.core_authority_snapshot() == dbg_before,
		"prepare reserves one DBG commodity slot with byte-identical Track and DBG authority state"
	)
	var reserved_lock: Dictionary = core.apply_intent(core.create_authority_intent(
		"request.local_queue.lock.while_reserved",
		Core.ACTION_LOCK_LOCAL_QUEUE,
		{"batch_id": 1}
	))
	_expect(
		not bool(reserved_lock.get("success", true))
		and reserved_lock.get("reason_code") \
		== "local_queue_lock_blocked_by_acquisition_transaction"
		and core.core_authority_snapshot() == dbg_before,
		"queue lock cannot race an in-flight commodity acquisition reservation"
	)
	var transaction_id := str(prepared.get("transaction_id", ""))
	var composite: Dictionary = port.call("commit_v1", transaction_id)
	var track_receipt := composite.get("track_receipt", {}) as Dictionary
	var source_identity := track_intent.get("source_identity", {}) as Dictionary
	var projected_item := proof.get("item", {}) as Dictionary
	var inventory := _state(core).get("commodity_inventory", []) as Array
	var commodity: Dictionary = {}
	if not inventory.is_empty():
		commodity = inventory[0] as Dictionary
	_expect(
		bool(composite.get("accepted", false))
		and composite.get("external_participants_finalized") == true
		and Core.validate_track_claim_receipt(
			track_receipt, track_intent, observation
		).is_empty()
		and commodity.get("commodity_id") == source_identity.get("source_definition_id")
		and commodity.get("primary_color") == projected_item.get("primary_color")
		and commodity.get("level") == 1,
		"two-phase commit consumes the exact authoritative Track receipt into one L1 commodity"
	)
	var track_after := track_authority.call("core_authority_v1") as Dictionary
	var dbg_after: Dictionary = core.core_authority_snapshot()
	var replay: Dictionary = port.call("commit_v1", transaction_id)
	_expect(
		replay == composite
		and track_authority.call("core_authority_v1") == track_after
		and core.core_authority_snapshot() == dbg_after
		and (_state(core).get("commodity_inventory", []) as Array).size() == 1,
		"composite finalize replay returns the exact receipt without a second Track or DBG mutation"
	)
	var participant_rows := composite.get("participant_commits", []) as Array
	var participant_row: Dictionary = {}
	if not participant_rows.is_empty():
		participant_row = participant_rows[0] as Dictionary
	var reservation_id := str(participant_row.get("reservation_id", ""))
	var participant_replay: Dictionary = core.commit_prepared_acquisition_v1(
		reservation_id,
		track_receipt
	)
	_expect(
		bool(participant_replay.get("accepted", false))
		and core.commit_prepared_acquisition_v1(reservation_id, track_receipt)
		== participant_replay
		and core.core_authority_snapshot() == dbg_after,
		"participant finalize replay is exact and cannot allocate a second commodity"
	)


func _test_track_claim_adversarial_binding() -> void:
	var base := _track_claim_arguments(
		90, "commodity.adversarial", "commerce", OWNER_ID
	)
	_expect(
		Core.validate_track_claim_receipt(
			base.get("track_claim_receipt", {}) as Dictionary,
			base.get("track_claim_intent", {}) as Dictionary,
			base.get("track_ai_observation", {}) as Dictionary
		).is_empty(),
		"closed synthetic Track proof fixture matches the real three-contract shape"
	)
	var fully_resealed := _fully_reseal_track_definition(
		base,
		"commodity_card.reference.forged"
	)
	_expect(
		not fully_resealed.is_empty()
		and Core.validate_track_claim_receipt(
			fully_resealed.get("track_claim_receipt", {}) as Dictionary,
			fully_resealed.get("track_claim_intent", {}) as Dictionary,
			fully_resealed.get("track_ai_observation", {}) as Dictionary
		).is_empty(),
		"fully resealed synthetic Track triples still pass the separate static shape validator"
	)
	var stale_receipt := fully_resealed.get("track_claim_receipt", {}) as Dictionary
	stale_receipt["receipt_id"] = "receipt.forged.stale"
	_expect(
		Core.validate_track_claim_receipt(
			stale_receipt,
			fully_resealed.get("track_claim_intent", {}) as Dictionary,
			fully_resealed.get("track_ai_observation", {}) as Dictionary
		) == "track_claim_receipt_fingerprint_invalid",
		"static validator remains a separate closed-shape and fingerprint gate"
	)

	var core := _new_core(FIXED_SEED)
	var malicious := MaliciousTrackAuthorityWrapper.new()
	malicious.forged_receipt = fully_resealed.get("track_claim_receipt", {}) as Dictionary
	var before_malicious: Dictionary = core.core_authority_snapshot()
	var malicious_bind: Dictionary = core.bind_unified_track_receipt_authority(malicious)
	_expect(
		not bool(malicious_bind.get("bound", true))
		and str(malicious_bind.get("reason_code", ""))
		== "track_receipt_authority_script_invalid"
		and core.core_authority_snapshot() == before_malicious,
		"method-complete malicious wrapper cannot impersonate exact Unified Track script identity"
	)

	var shared_request_id := "request.track.authority.collision.shared"
	var proof := _real_track_claim_proof(90, "", "", OWNER_ID, shared_request_id)
	_expect(not proof.is_empty(), "adversarial fixture exposes a live uncommitted Track intent")
	if proof.is_empty():
		return
	var track := proof.get("authority") as RefCounted
	_expect(_bind_track_authority(core, proof), "DBG binds the trusted issuing Track authority")
	var pinned: Dictionary = core.core_authority_snapshot()
	var invalid_bind: Dictionary = core.bind_unified_track_receipt_authority(RefCounted.new())
	var same_rebind: Dictionary = core.bind_unified_track_receipt_authority(track)
	_expect(
		not bool(invalid_bind.get("bound", true))
		and str(invalid_bind.get("reason_code", ""))
		== "track_receipt_authority_script_invalid"
		and bool(same_rebind.get("bound", false))
		and str(same_rebind.get("reason_code", ""))
		== "track_receipt_authority_already_bound"
		and core.core_authority_snapshot() == pinned,
		"invalid replacement preserves the current authority and same-object rebind is idempotent"
	)
	var track_save := track.call("save_state_v1") as Dictionary
	var same_lineage_clone := TrackCore.new()
	_expect(
		bool(same_lineage_clone.restore_save_state_v1(track_save).get("accepted", false)),
		"same-lineage clone restores for object-identity replacement probe"
	)
	var clone_bind: Dictionary = core.bind_unified_track_receipt_authority(same_lineage_clone)
	_expect(
		not bool(clone_bind.get("bound", true))
		and str(clone_bind.get("reason_code", ""))
		== "track_receipt_authority_live_replacement_forbidden"
		and core.core_authority_snapshot() == pinned,
		"a live valid authority cannot be replaced even by a different exact-script object with identical lineage"
	)

	var second_proof := _track_claim_proof_from_authority(
		track,
		shared_request_id,
		OWNER_ID,
		"",
		"",
		[str((proof.get("item", {}) as Dictionary).get("instance_id", ""))]
	)
	_expect(not second_proof.is_empty(), "request-collision fixture binds a distinct visible source")
	var port := _new_acquisition_port(core, track)
	var first_composite: Dictionary = port.call(
		"transact_v1",
		proof.get("track_intent", {}) as Dictionary
	)
	var track_after_first := track.call("core_authority_v1") as Dictionary
	var dbg_after_first: Dictionary = core.core_authority_snapshot()
	var collision: Dictionary = port.call(
		"prepare_v1",
		second_proof.get("track_intent", {}) as Dictionary
	)
	_expect(
		bool(first_composite.get("accepted", false))
		and not bool(collision.get("accepted", true))
		and str(collision.get("reason_code", "")) == "request_id_collision"
		and track.call("core_authority_v1") == track_after_first
		and core.core_authority_snapshot() == dbg_after_first,
		"same Track request ID with a different intent fails closed across both authorities"
	)

	var dbg_save: Dictionary = core.to_save_state()
	var restored_dbg := Core.new()
	_expect(
		bool(restored_dbg.apply_save_state(dbg_save).get("applied", false)),
		"DBG Save restores the pinned Track lineage with no live object reference"
	)
	var wrong_match := _real_track_claim_proof(91)
	var wrong_bind: Dictionary = restored_dbg.bind_unified_track_receipt_authority(
		wrong_match.get("authority") as RefCounted
	)
	_expect(
		not bool(wrong_bind.get("bound", true))
		and str(wrong_bind.get("reason_code", ""))
		== "track_receipt_authority_lineage_mismatch",
		"post-Save rebind rejects an exact Unified Track object from the wrong match lineage"
	)
	var restored_track := TrackCore.new()
	_expect(
		bool(restored_track.restore_save_state_v1(
			track.call("save_state_v1") as Dictionary
		).get("accepted", false))
		and bool(restored_dbg.bind_unified_track_receipt_authority(
			restored_track
		).get("bound", false)),
		"post-Save rebind accepts a new exact-script object only after matching Track restore"
	)
	var restored_projection := restored_dbg.player_projection(OWNER_ID)
	_expect(
		Core.is_pure_data(dbg_save)
		and Core.is_pure_data(restored_projection)
		and not _contains_exact_key(dbg_save, "track_receipt_authority")
		and not _contains_exact_key(restored_projection, "track_receipt_authority"),
		"Save and projection retain only pure match-lineage facts and never serialize authority objects"
	)


func _test_commodity_claim_inventory_and_merge() -> void:
	var core := _new_core(FIXED_SEED)
	var first_proof := _real_track_group_proof(100, 3)
	_expect(not first_proof.is_empty(), "one real Track match exposes a three-card merge family")
	if first_proof.is_empty():
		return
	var track := first_proof.get("authority") as RefCounted
	_expect(_bind_track_authority(core, first_proof), "commodity participant pins one Track match")
	var port := _new_acquisition_port(core, track)
	_expect(port.call("is_configured"), "commodity participant session configures the stable port")
	var normal_before := _state(core)
	var target_definition := str(first_proof.get("target_definition_id", ""))
	var target_color := str(first_proof.get("target_color", ""))
	var commodity_ids: Array[String] = []
	var first_track_intent := first_proof.get("track_intent", {}) as Dictionary
	var first_composite: Dictionary = {}
	for index in range(5):
		var track_proof := first_proof if index == 0 else (
			_track_claim_proof_from_authority(
				track,
				"request.track.commodity.session.%d" % index,
				OWNER_ID,
				target_definition if index < 3 else "",
				target_color if index < 3 else ""
			)
		)
		_expect(not track_proof.is_empty(), "same Track match exposes claim %d" % (index + 1))
		if track_proof.is_empty():
			return
		var composite: Dictionary = port.call(
			"transact_v1",
			track_proof.get("track_intent", {}) as Dictionary
		)
		if index == 0:
			first_composite = composite.duplicate(true)
		var inventory := _state(core).get("commodity_inventory", []) as Array
		if not inventory.is_empty():
			commodity_ids.append(str((inventory.back() as Dictionary).get(
				"instance_id", ""
			)))
		_expect(
			bool(composite.get("accepted", false))
			and inventory.size() == index + 1,
			"two-phase Track claim %d finalizes exactly one reserved commodity slot" % (index + 1)
		)
	var full_state := _state(core)
	var full_track := track.call("core_authority_v1") as Dictionary
	var full_dbg: Dictionary = core.core_authority_snapshot()
	_expect(
		port.call("transact_v1", first_track_intent) == first_composite
		and track.call("core_authority_v1") == full_track
		and core.core_authority_snapshot() == full_dbg,
		"replaying a finalized Track intent returns the exact composite receipt without mutation"
	)
	_expect(
		(full_state.get("commodity_inventory", []) as Array).size() == 5
		and full_state.get("hand", []) == normal_before.get("hand", [])
		and full_state.get("draw_pile", []) == normal_before.get("draw_pile", [])
		and full_state.get("starter_rng", {}) == normal_before.get("starter_rng", {})
		and full_state.get("reshuffle_rng", {}) == normal_before.get("reshuffle_rng", {}),
		"five Track commits leave normal DBG zones and both personal RNG streams byte-identical"
	)
	var sixth_proof := _track_claim_proof_from_authority(
		track,
		"request.track.commodity.capacity.full"
	)
	_expect(not sixth_proof.is_empty(), "full-capacity probe identifies an uncommitted sixth Track source")
	if sixth_proof.is_empty():
		return
	var capacity_track_before := track.call("core_authority_v1") as Dictionary
	var capacity_dbg_before: Dictionary = core.core_authority_snapshot()
	var capacity_rejection: Dictionary = port.call(
		"prepare_v1",
		sixth_proof.get("track_intent", {}) as Dictionary
	)
	_expect(
		not bool(capacity_rejection.get("accepted", true))
		and str(capacity_rejection.get("reason_code", "")).contains(
			"commodity_inventory_full"
		)
		and track.call("core_authority_v1") == capacity_track_before
		and core.core_authority_snapshot() == capacity_dbg_before,
		"full inventory fails during prepare while Track and DBG remain byte-identical"
	)

	if commodity_ids.size() < 3:
		_expect(false, "three committed commodity identities are available for merge")
		return
	var l2: Dictionary = core.apply_intent(core.create_intent(
		"request.commodity.merge.l2",
		OWNER_ID,
		Core.ACTION_MERGE_COMMODITIES,
		{"left_instance_id": commodity_ids[0], "right_instance_id": commodity_ids[1]}
	))
	var l3: Dictionary = core.apply_intent(core.create_intent(
		"request.commodity.merge.l3",
		OWNER_ID,
		Core.ACTION_MERGE_COMMODITIES,
		{
			"left_instance_id": str(l2.get("created_instance_id", "")),
			"right_instance_id": commodity_ids[2],
		}
	))
	var l3_card := _find_commodity(
		_state(core).get("commodity_inventory", []) as Array,
		str(l3.get("created_instance_id", ""))
	)
	_expect(
		bool(l2.get("success", false))
		and bool(l3.get("success", false))
		and int(l3_card.get("level", 0)) == 3
		and (l3_card.get("source_track_instance_ids", []) as Array).size() == 3
		and (l3_card.get("claim_receipt_ids", []) as Array).size() == 3,
		"three real port-finalized claims retain exact lineage through optional L2 and L3 merges"
	)

	var abort_core := _new_core(FIXED_SEED + 1)
	var abort_proof := _real_track_claim_proof(106)
	_expect(
		not abort_proof.is_empty() and _bind_track_authority(abort_core, abort_proof),
		"abort fixture pins a separate real Track match"
	)
	if abort_proof.is_empty():
		return
	var abort_track := abort_proof.get("authority") as RefCounted
	var abort_port := _new_acquisition_port(abort_core, abort_track)
	var abort_track_before := abort_track.call("core_authority_v1") as Dictionary
	var abort_dbg_before: Dictionary = abort_core.core_authority_snapshot()
	var prepared: Dictionary = abort_port.call(
		"prepare_v1",
		abort_proof.get("track_intent", {}) as Dictionary
	)
	var aborted: Dictionary = abort_port.call(
		"abort_v1",
		str(prepared.get("transaction_id", "")),
		"focused_abort"
	)
	_expect(
		bool(prepared.get("accepted", false))
		and bool(aborted.get("accepted", false))
		and abort_track.call("core_authority_v1") == abort_track_before
		and abort_core.core_authority_snapshot() == abort_dbg_before,
		"abort releases the reserved slot and restores both authority fingerprints exactly"
	)
	var after_abort: Dictionary = abort_port.call(
		"transact_v1",
		abort_proof.get("track_intent", {}) as Dictionary
	)
	_expect(
		bool(after_abort.get("accepted", false))
		and (_state(abort_core).get("commodity_inventory", []) as Array).size() == 1,
		"the same acquisition can prepare and finalize once after explicit abort"
	)
	var wrong_actor_proof := _track_claim_proof_from_authority(
		abort_track,
		"request.track.commodity.wrong_actor",
		OTHER_PLAYER_ID
	)
	_expect(not wrong_actor_proof.is_empty(), "wrong-actor Track intent is valid before DBG participation")
	if wrong_actor_proof.is_empty():
		return
	var wrong_actor_track_before := abort_track.call("core_authority_v1") as Dictionary
	var wrong_actor_dbg_before: Dictionary = abort_core.core_authority_snapshot()
	var wrong_actor_result: Dictionary = abort_port.call(
		"prepare_v1",
		wrong_actor_proof.get("track_intent", {}) as Dictionary
	)
	_expect(
		not bool(wrong_actor_result.get("accepted", true))
		and str(wrong_actor_result.get("reason_code", "")).contains(
			"acquisition_participant_request_binding_invalid"
		)
		and abort_track.call("core_authority_v1") == wrong_actor_track_before
		and abort_core.core_authority_snapshot() == wrong_actor_dbg_before,
		"wrong actor fails in participant prepare before either authority mutates"
	)


func _test_commodity_batch_availability_and_roundtrip() -> void:
	var first_proof := _real_track_group_proof(112, 3)
	_expect(
		not first_proof.is_empty(),
		"availability fixture exposes two matching Candidate A commodities"
	)
	if first_proof.is_empty():
		return
	var core := _new_core(FIXED_SEED + 112)
	var track := first_proof.get("authority") as RefCounted
	_expect(_bind_track_authority(core, first_proof), "availability fixture pins Track lineage")
	var port := _new_acquisition_port(core, track)
	var first_commit: Dictionary = port.call(
		"transact_v1",
		first_proof.get("track_intent", {}) as Dictionary
	)
	var after_first := _state(core)
	var first_inventory := after_first.get("commodity_inventory", []) as Array
	var first_id := str((first_inventory[0] as Dictionary).get("instance_id", "")) \
		if not first_inventory.is_empty() else ""
	var first_available_batch := int((first_inventory[0] as Dictionary).get(
		"available_from_batch_id", 0
	)) if not first_inventory.is_empty() else 0
	_expect(
		bool(first_commit.get("accepted", false))
		and first_available_batch == 1,
		"commodity claimed before queue lock is available in the current batch"
	)

	var second_proof := _track_claim_proof_from_authority(
		track,
		"request.track.availability.locked",
		OWNER_ID,
		str(first_proof.get("target_definition_id", "")),
		str(first_proof.get("target_color", ""))
	)
	_expect(not second_proof.is_empty(), "locked availability fixture exposes its second source")
	if second_proof.is_empty():
		return
	var lock_receipt: Dictionary = core.apply_intent(core.create_authority_intent(
		"request.local_queue.lock.batch_1",
		Core.ACTION_LOCK_LOCAL_QUEUE,
		{"batch_id": 1}
	))
	_expect(
		bool(lock_receipt.get("success", false))
		and bool((_state(core).get("local_queue_state", {}) as Dictionary).get(
			"locked", false
		)),
		"authority locks the saved local queue for batch one"
	)
	var second_commit: Dictionary = port.call(
		"transact_v1",
		second_proof.get("track_intent", {}) as Dictionary
	)
	var locked_state := _state(core)
	var locked_inventory := locked_state.get("commodity_inventory", []) as Array
	var second_id := str((locked_inventory[1] as Dictionary).get("instance_id", "")) \
		if locked_inventory.size() > 1 else ""
	var second_available_batch := int((locked_inventory[1] as Dictionary).get(
		"available_from_batch_id", 0
	)) if locked_inventory.size() > 1 else 0
	_expect(
		bool(second_commit.get("accepted", false))
		and second_available_batch == 2,
		"commodity claimed after queue lock is available only from the next batch"
	)
	var unavailable_before: Dictionary = core.core_authority_snapshot()
	var unavailable_merge: Dictionary = core.apply_intent(core.create_intent(
		"request.commodity.merge.before_available",
		OWNER_ID,
		Core.ACTION_MERGE_COMMODITIES,
		{"left_instance_id": first_id, "right_instance_id": second_id}
	))
	_expect(
		not bool(unavailable_merge.get("success", true))
		and unavailable_merge.get("reason_code") \
		== "commodity_not_available_in_current_batch"
		and core.core_authority_snapshot() == unavailable_before,
		"next-batch commodity cannot merge into the immutable current queue state"
	)

	var locked_save: Dictionary = core.to_save_state()
	var restored := Core.new()
	_expect(
		bool(restored.apply_save_state(
			JSON.parse_string(JSON.stringify(locked_save)) as Dictionary
		).get("applied", false))
		and _state(restored) == locked_state,
		"Save/Restore preserves local queue lock, batch, and both availability values"
	)
	for candidate in [core, restored]:
		var candidate_core := candidate as RefCounted
		candidate_core.apply_intent(candidate_core.create_authority_intent(
			"request.availability.complete.batch_1",
			Core.ACTION_COMPLETE_BATCH
		))
		candidate_core.apply_intent(candidate_core.create_intent(
			"request.availability.end.maintenance_1",
			OWNER_ID,
			Core.ACTION_END_MAINTENANCE
		))
	var advanced_state := _state(core)
	_expect(
		advanced_state.get("batch_index") == 2
		and not bool((advanced_state.get("local_queue_state", {}) as Dictionary).get(
			"locked", true
		))
		and _state(restored) == advanced_state,
		"next batch resets only the queue lock while preserving deterministic availability"
	)
	var merged_original: Dictionary = core.apply_intent(core.create_intent(
		"request.commodity.merge.available.batch_2",
		OWNER_ID,
		Core.ACTION_MERGE_COMMODITIES,
		{"left_instance_id": first_id, "right_instance_id": second_id}
	))
	var merged_restored: Dictionary = restored.apply_intent(restored.create_intent(
		"request.commodity.merge.available.batch_2",
		OWNER_ID,
		Core.ACTION_MERGE_COMMODITIES,
		{"left_instance_id": first_id, "right_instance_id": second_id}
	))
	var result_commodity := _find_commodity(
		_state(core).get("commodity_inventory", []) as Array,
		str(merged_original.get("created_instance_id", ""))
	)
	_expect(
		bool(merged_original.get("success", false))
		and merged_original == merged_restored
		and _state(core) == _state(restored)
		and int(result_commodity.get("available_from_batch_id", 0)) == 2,
		"commodity merge and restored replay preserve the latest source availability batch"
	)

	var wrong_profile: Dictionary = locked_save.duplicate(true)
	wrong_profile["balance_profile_fingerprint"] = "0".repeat(64)
	_expect(
		Core.validate_save_state(wrong_profile) == "save_state_schema_invalid",
		"Save header rejects a wrong Candidate A profile fingerprint before restore"
	)
	var wrong_nested_profile: Dictionary = locked_save.duplicate(true)
	(wrong_nested_profile.get("state", {}) as Dictionary)[
		"balance_profile_id"
	] = "BASELINE_V07"
	_reseal_save(wrong_nested_profile)
	_expect(
		Core.validate_save_state(wrong_nested_profile) == "save_state_invariant_invalid",
		"resealed authority state cannot silently substitute another balance profile"
	)
func _test_commodity_checkpoint_save_exact_once_and_privacy() -> void:
	var core := _new_core(FIXED_SEED)
	var first_proof := _real_track_group_proof(120, 3)
	_expect(not first_proof.is_empty(), "Save fixture exposes three matching commodities in one Track lineage")
	if first_proof.is_empty():
		return
	var track := first_proof.get("authority") as RefCounted
	_expect(_bind_track_authority(core, first_proof), "Save fixture pins its exact Track lineage")
	var port := _new_acquisition_port(core, track)
	var target_definition := str(first_proof.get("target_definition_id", ""))
	var target_color := str(first_proof.get("target_color", ""))
	var claimed_ids: Array[String] = []
	var first_intent := first_proof.get("track_intent", {}) as Dictionary
	var first_composite: Dictionary = {}
	for index in range(3):
		var proof := first_proof if index == 0 else _track_claim_proof_from_authority(
			track,
			"request.track.roundtrip.claim.%d" % index,
			OWNER_ID,
			target_definition,
			target_color
		)
		_expect(not proof.is_empty(), "roundtrip claim %d remains in one Track match" % index)
		if proof.is_empty():
			return
		var composite: Dictionary = port.call(
			"transact_v1",
			proof.get("track_intent", {}) as Dictionary
		)
		if index == 0:
			first_composite = composite.duplicate(true)
		var inventory := _state(core).get("commodity_inventory", []) as Array
		if not inventory.is_empty():
			claimed_ids.append(str((inventory.back() as Dictionary).get(
				"instance_id", ""
			)))
		_expect(
			bool(composite.get("accepted", false)) and inventory.size() == index + 1,
			"roundtrip claim %d commits through the acquisition port" % index
		)
	if claimed_ids.size() < 3:
		return
	var level_two: Dictionary = core.apply_intent(core.create_intent(
		"request.commodity.roundtrip.l2",
		OWNER_ID,
		Core.ACTION_MERGE_COMMODITIES,
		{"left_instance_id": claimed_ids[0], "right_instance_id": claimed_ids[1]}
	))
	var checkpoint: Dictionary = core.capture_checkpoint()
	var level_three_intent: Dictionary = core.create_intent(
		"request.commodity.roundtrip.l3",
		OWNER_ID,
		Core.ACTION_MERGE_COMMODITIES,
		{
			"left_instance_id": str(level_two.get("created_instance_id", "")),
			"right_instance_id": claimed_ids[2]
		}
	)
	var level_three_receipt: Dictionary = core.apply_intent(level_three_intent)
	var level_three_state := _state(core)
	var level_three_fingerprint := str(
		core.core_authority_snapshot().get("state_fingerprint", "")
	)
	_expect(
		core.apply_intent(level_three_intent) == level_three_receipt
		and str(core.core_authority_snapshot().get("state_fingerprint", ""))
		== level_three_fingerprint,
		"commodity merge remains exact-once after port-finalized claims"
	)
	_expect(
		bool(core.rollback_to_checkpoint(checkpoint).get("rolled_back", false))
		and core.apply_intent(level_three_intent) == level_three_receipt
		and _state(core) == level_three_state,
		"checkpoint rollback and deterministic replay preserve port claim lineage"
	)
	var before_first_replay: Dictionary = core.core_authority_snapshot()
	_expect(
		port.call("transact_v1", first_intent) == first_composite
		and core.core_authority_snapshot() == before_first_replay,
		"an earlier finalized acquisition remains exact-once after later merges"
	)

	var save_state: Dictionary = core.to_save_state()
	var track_save: Dictionary = track.call("save_state_v1")
	var document := save_state.get("document_section", {}) as Dictionary
	var document_player := ((document.get("players", []) as Array)[0]) as Dictionary
	var bound_state := document_player.get("bound_source_state", {}) as Dictionary
	_expect(
		_has_exact_fields(document, Core.DOCUMENT_SECTION_FIELDS)
		and _has_exact_fields(document_player, Core.DOCUMENT_PLAYER_FIELDS)
		and document.get("section_id") == "personal_dbg_and_merge"
		and (document_player.get("commodity_inventory", []) as Array).size() == 1
		and _is_tagged_int64(document.get("merge_instance_allocator_cursor"), true)
		and (document.get("rng_stream_states", []) as Array).size() == 2,
		"Save exposes the merged commodity, allocator, journal, and both RNG streams"
	)
	_expect(
		bound_state.get("runtime_binding_supported") == true
		and (bound_state.get("entries", []) as Array).size() == 1
		and Core.is_pure_data(bound_state),
		"Save persists one pure expected Track match and lineage without an object reference"
	)
	var decoded: Variant = JSON.parse_string(JSON.stringify(save_state))
	var restored := Core.new()
	var restored_track := TrackCore.new()
	_expect(
		bool(restored.apply_save_state(decoded as Dictionary).get("applied", false))
		and bool(restored_track.restore_save_state_v1(track_save).get("accepted", false))
		and _state(restored) == _state(core),
		"DBG and Track Save sections restore their exact paired authority states"
	)
	var restored_port := _new_acquisition_port(restored, restored_track)
	var next_restored_proof := _track_claim_proof_from_authority(
		restored_track,
		"request.track.roundtrip.next"
	)
	var unbound_track_before := restored_track.call("core_authority_v1") as Dictionary
	var unbound_dbg_before: Dictionary = restored.core_authority_snapshot()
	var unbound_prepare: Dictionary = restored_port.call(
		"prepare_v1",
		next_restored_proof.get("track_intent", {}) as Dictionary
	)
	_expect(
		not bool(unbound_prepare.get("accepted", true))
		and str(unbound_prepare.get("reason_code", "")).contains(
			"track_receipt_authority_unbound"
		)
		and restored_track.call("core_authority_v1") == unbound_track_before
		and restored.core_authority_snapshot() == unbound_dbg_before,
		"Save restore clears the transient object binding and fails before Track mutation"
	)
	_expect(
		bool(restored.bind_unified_track_receipt_authority(
			restored_track
		).get("bound", false)),
		"paired Track restore satisfies the persisted match-lineage rebind"
	)
	var next_original_proof := _track_claim_proof_from_authority(
		track,
		"request.track.roundtrip.next"
	)
	_expect(
		next_original_proof.get("track_intent", {})
		== next_restored_proof.get("track_intent", {}),
		"uninterrupted and restored Track authorities build the identical next intent"
	)
	var next_original: Dictionary = port.call(
		"transact_v1",
		next_original_proof.get("track_intent", {}) as Dictionary
	)
	var next_restored: Dictionary = restored_port.call(
		"transact_v1",
		next_restored_proof.get("track_intent", {}) as Dictionary
	)
	_expect(
		next_original == next_restored
		and _state(core) == _state(restored)
		and track.call("core_authority_v1")
		== restored_track.call("core_authority_v1"),
		"paired cold continuation produces identical next Track and DBG authority states"
	)
	var ai: Dictionary = restored.ai_observation(OWNER_ID)
	var player: Dictionary = restored.player_projection(OWNER_ID)
	_expect(
		Core.is_pure_data(save_state)
		and Core.is_pure_data(ai)
		and Core.is_pure_data(player)
		and not _contains_exact_key(save_state, "track_receipt_authority")
		and not _contains_exact_key(ai, "track_receipt_authority")
		and not _contains_exact_key(player, "track_receipt_authority")
		and restored.player_projection(OTHER_PLAYER_ID).is_empty(),
		"Save and both owner projections contain pure lineage facts but no authority object or rival data"
	)
	var forged_bound_checkpoint: Dictionary = restored.capture_checkpoint()
	var forged_bound_state := forged_bound_checkpoint.get("state", {}) as Dictionary
	var entries := (
		forged_bound_state.get("bound_source_state", {}) as Dictionary
	).get("entries", []) as Array
	if not entries.is_empty():
		(entries[0] as Dictionary)["lineage_fingerprint"] = "0".repeat(64)
	_reseal_checkpoint(forged_bound_checkpoint)
	var before_forged: Dictionary = restored.core_authority_snapshot()
	_expect(
		not bool(restored.rollback_to_checkpoint(
			forged_bound_checkpoint
		).get("rolled_back", true))
		and restored.core_authority_snapshot() == before_forged,
		"resealed wrong Track lineage fails checkpoint validation without partial restore"
	)
	var missing_allocator := save_state.duplicate(true)
	(missing_allocator.get("state", {}) as Dictionary).erase(
		"next_commodity_instance_sequence"
	)
	_reseal_save(missing_allocator)
	_expect(
		Core.validate_save_state(missing_allocator) == "save_state_invariant_invalid",
		"commodity allocator cursor cannot be silently defaulted during Save preflight"
	)
func _test_checkpoint_rollback_and_exact_once() -> void:
	var core := _new_core(FIXED_SEED)
	var checkpoint: Dictionary = core.capture_checkpoint()
	var checkpoint_fingerprint := str(checkpoint.get("state_fingerprint", ""))
	var hand := (_state(core).get("hand", []) as Array)
	var card_id := str((hand[0] as Dictionary).get("instance_id", ""))
	var intent: Dictionary = core.create_intent(
		"request.exact_once.play", OWNER_ID, Core.ACTION_PLAY_CARD, {"instance_id": card_id}
	)
	var receipt: Dictionary = core.apply_intent(intent)
	var state_after_first := str(core.core_authority_snapshot().get("state_fingerprint", ""))
	var repeated_receipt: Dictionary = core.apply_intent(intent)
	_expect(receipt == repeated_receipt, "repeated request returns the exact stored authoritative receipt")
	_expect(
		str(core.core_authority_snapshot().get("state_fingerprint", "")) == state_after_first,
		"repeated request performs no second mutation"
	)
	var collision := intent.duplicate(true)
	collision["arguments"] = {"instance_id": str((hand[1] as Dictionary).get("instance_id", ""))}
	collision.erase("intent_fingerprint")
	collision["intent_fingerprint"] = _test_fingerprint(collision)
	var collision_receipt: Dictionary = core.apply_intent(collision)
	_expect(
		not bool(collision_receipt.get("success", true))
		and str(collision_receipt.get("reason_code", "")) == "request_id_collision",
		"same request identity with different intent fingerprint fails closed"
	)
	_expect(
		str(core.core_authority_snapshot().get("state_fingerprint", "")) == state_after_first,
		"request collision preserves state"
	)
	var rollback_receipt: Dictionary = core.rollback_to_checkpoint(checkpoint)
	_expect(
		bool(rollback_receipt.get("rolled_back", false))
		and str(core.core_authority_snapshot().get("state_fingerprint", "")) == checkpoint_fingerprint,
		"checkpoint rollback restores the exact pre-action state"
	)
	var corrupt_checkpoint := checkpoint.duplicate(true)
	(corrupt_checkpoint.get("state", {}) as Dictionary)["revision"] = 99
	var before_corrupt := str(core.core_authority_snapshot().get("state_fingerprint", ""))
	var rejected: Dictionary = core.rollback(corrupt_checkpoint)
	_expect(
		not bool(rejected.get("rolled_back", true))
		and str(core.core_authority_snapshot().get("state_fingerprint", "")) == before_corrupt,
		"fingerprint-mismatched checkpoint is rejected without mutation"
	)


func _test_three_wing_projection_intent_receipt_and_privacy() -> void:
	var core := _new_core(FIXED_SEED)
	var ai: Dictionary = core.ai_observation(OWNER_ID)
	var player: Dictionary = core.player_projection(OWNER_ID)
	_expect(
		str(ai.get("schema_id", "")) == "v071.personal_dbg.ai_observation.v2"
		and str(player.get("schema_id", "")) == "v071.personal_dbg.player_projection.v2",
		"AI and Player wings have distinct typed projection identities"
	)
	_expect(
		ai.get("facts", {}) == player.get("facts", {})
		and ai.get("facts_fingerprint", "") == player.get("facts_fingerprint", ""),
		"AI and Player wings project the same authoritative DBG facts"
	)
	_expect(
		core.ai_observation(OTHER_PLAYER_ID).is_empty()
		and core.player_projection(OTHER_PLAYER_ID).is_empty(),
		"non-owner AI and player viewers fail closed instead of seeing another hand"
	)
	_expect(
		Core.projection_is_private_safe(ai)
		and Core.projection_is_private_safe(player),
		"three-wing projections contain no deck order, discard order, RNG, Save, or journal secrets"
	)
	_expect(
		not _contains_exact_key(ai, "owner_player_id")
		and not _contains_exact_key(ai, "draw_pile")
		and not _contains_exact_key(ai, "starter_rng")
		and not _contains_exact_key(ai, "receipt_journal"),
		"AI observation exposes no owner, draw-order, RNG, or receipt-ledger secrets"
	)
	var projected_hand := ((player.get("facts", {}) as Dictionary).get("hand", []) as Array)
	var card_id := str((projected_hand[0] as Dictionary).get("instance_id", ""))
	projected_hand.clear()
	_expect(
		((_state(core).get("hand", []) as Array).size() == 5),
		"mutating a detached player projection cannot mutate Core authority"
	)
	var intent: Dictionary = core.create_intent(
		"request.three_wing.play", OWNER_ID, Core.ACTION_PLAY_CARD, {"instance_id": card_id}
	)
	_expect(
		str(intent.get("schema_id", "")) == "v071.personal_dbg.intent.v2"
		and Core.is_pure_data(intent)
		and str(intent.get("intent_fingerprint", "")).length() == 64,
		"player command is a typed, fingerprinted, pure-data IntentV1"
	)
	var receipt: Dictionary = core.apply_intent(intent)
	_expect(
		str(receipt.get("schema_id", "")) == "v071.personal_dbg.authoritative_receipt.v2"
		and bool(receipt.get("success", false))
		and str(receipt.get("receipt_fingerprint", "")).length() == 64,
		"Core returns a typed, fingerprinted AuthoritativeReceiptV1"
	)
	_expect(
		Core.receipt_is_private_safe(receipt)
		and not _contains_exact_key(receipt, "actor_player_id")
		and not _contains_exact_key(receipt, "card_spec"),
		"receipt proves the transition without exposing player identity or authority payload"
	)
	var post_play_facts := (
		core.player_projection(OWNER_ID).get("facts", {}) as Dictionary
	)
	_expect(
		(post_play_facts.get("discard", []) as Array).size() == 1
		and str(((post_play_facts.get("discard", []) as Array)[0] as Dictionary).get(
			"instance_id", ""
		)) == card_id,
		"owner projection can inspect its own discard while non-owner projection remains closed"
	)
	var save_state: Dictionary = core.to_save_state()
	_expect(
		_contains_exact_key(save_state, "owner_player_id")
		and _contains_exact_key(save_state, "starter_rng")
		and _contains_exact_key(save_state, "draw_pile"),
		"full Save state retains required secrets only on the authority-side contract"
	)


func _test_six_contract_fact_binding_and_alias_rejection() -> void:
	var core := _new_core(FIXED_SEED)
	var authority: Dictionary = core.core_authority_snapshot()
	var ai: Dictionary = core.ai_observation(OWNER_ID)
	var player: Dictionary = core.player_projection(OWNER_ID)
	var hand := ((player.get("facts", {}) as Dictionary).get("hand", []) as Array)
	var card_id := str((hand[0] as Dictionary).get("instance_id", ""))
	var intent: Dictionary = core.create_intent(
		"request.fact_binding.play",
		OWNER_ID,
		Core.ACTION_PLAY_CARD,
		{"instance_id": card_id}
	)
	var source_core_fingerprint := str(authority.get("core_fingerprint", ""))
	_expect(
		Core.validate_core_authority_snapshot(authority).is_empty(),
		"CoreAuthorityV1 validates as a closed authority-secret contract"
	)
	_expect(
		Core.projection_is_private_safe(ai) and Core.projection_is_private_safe(player),
		"AiObservationV1 and PlayerProjectionV1 validate against closed allowlists"
	)
	_expect(
		Core.validate_intent(intent).is_empty(),
		"IntentV1 validates as a closed actor-to-authority contract"
	)
	_expect(
		source_core_fingerprint.length() == 64
		and ai.get("core_fingerprint", "") == source_core_fingerprint
		and player.get("core_fingerprint", "") == source_core_fingerprint
		and intent.get("source_core_fingerprint", "") == source_core_fingerprint,
		"Core, AI, Player, and Intent bind the identical pre-action fact fingerprint"
	)

	var aliased_ai := ai.duplicate(true)
	aliased_ai["opponent_hand_alias"] = ["private.card"]
	_expect(
		not Core.projection_is_private_safe(aliased_ai),
		"AI projection rejects an undeclared top-level privacy alias"
	)
	var aliased_player := player.duplicate(true)
	(aliased_player.get("facts", {}) as Dictionary)["future_draw_alias"] = "private.card"
	aliased_player["facts_fingerprint"] = _test_fingerprint(
		aliased_player.get("facts", {})
	)
	_expect(
		not Core.projection_is_private_safe(aliased_player),
		"Player projection rejects a resealed undeclared nested privacy alias"
	)
	var inconsistent_counts := player.duplicate(true)
	(inconsistent_counts.get("facts", {}) as Dictionary)["hand_count"] = 99
	inconsistent_counts["facts_fingerprint"] = _test_fingerprint(
		inconsistent_counts.get("facts", {})
	)
	_expect(
		not Core.projection_is_private_safe(inconsistent_counts),
		"projection rejects resealed facts whose counts disagree with allowlisted zones"
	)
	var aliased_intent := intent.duplicate(true)
	aliased_intent["forced_shuffle_order"] = [card_id]
	aliased_intent.erase("intent_fingerprint")
	aliased_intent["intent_fingerprint"] = _test_fingerprint(aliased_intent)
	_expect(
		not Core.validate_intent(aliased_intent).is_empty(),
		"IntentV1 rejects an undeclared forced-shuffle field even when resealed"
	)

	var other_seed_core := _new_core(FIXED_SEED + 97)
	var other_before := str(other_seed_core.core_authority_snapshot().get(
		"state_fingerprint", ""
	))
	var cross_core_receipt: Dictionary = other_seed_core.apply_intent(intent)
	_expect(
		not bool(cross_core_receipt.get("success", true))
		and str(cross_core_receipt.get("reason_code", ""))
		== "source_core_fingerprint_mismatch",
		"same owner and revision cannot replay an Intent against a different seeded Core"
	)
	_expect(
		str(other_seed_core.core_authority_snapshot().get("state_fingerprint", ""))
		== other_before,
		"cross-Core Intent rejection performs zero mutation"
	)

	var receipt: Dictionary = core.apply_intent(intent)
	var authority_after: Dictionary = core.core_authority_snapshot()
	var save_state: Dictionary = core.to_save_state()
	_expect(
		Core.validate_receipt(receipt).is_empty()
		and Core.receipt_is_private_safe(receipt),
		"AuthoritativeReceiptV1 is closed, fingerprinted, and actor-private"
	)
	_expect(
		receipt.get("source_core_fingerprint", "") == source_core_fingerprint
		and receipt.get("result_core_fingerprint", "")
		== authority_after.get("core_fingerprint", ""),
		"receipt binds both exact pre-action and post-action Core facts"
	)
	_expect(
		Core.validate_core_authority_snapshot(authority_after).is_empty()
		and Core.validate_save_state(save_state).is_empty(),
		"post-action CoreAuthorityV1 and SaveStateV1 both validate"
	)
	_expect(
		save_state.get("core_fingerprint", "")
		== authority_after.get("core_fingerprint", "")
		and save_state.get("state_fingerprint", "")
		== authority_after.get("state_fingerprint", ""),
		"SaveStateV1 captures the same Core facts plus the exact full authority state"
	)
	var aliased_receipt := receipt.duplicate(true)
	aliased_receipt["owner_player_id"] = OWNER_ID
	aliased_receipt.erase("receipt_fingerprint")
	aliased_receipt["receipt_fingerprint"] = _test_fingerprint(aliased_receipt)
	_expect(
		not Core.receipt_is_private_safe(aliased_receipt),
		"receipt rejects a resealed undeclared owner field"
	)


func _test_save_roundtrip_and_rng_continuity() -> void:
	var original := _new_core(FIXED_SEED)
	var first_card := str((((_state(original).get("hand", []) as Array)[0]) as Dictionary).get("instance_id", ""))
	_expect(bool(original.apply_intent(original.create_intent(
		"request.save.play", OWNER_ID, Core.ACTION_PLAY_CARD, {"instance_id": first_card}
	)).get("success", false)), "Save fixture includes a played card")
	var purchase_spec := (Core.starter_card_specs()[3] as Dictionary).duplicate(true)
	_expect(bool(original.apply_intent(original.create_authority_intent(
		"request.save.purchase",
		Core.ACTION_ACCEPT_PURCHASE,
		{"purchase_receipt_id": "track.save.purchase", "card_spec": purchase_spec}
	)).get("success", false)), "Save fixture includes a purchased discard card")
	_expect(bool(original.apply_intent(original.create_authority_intent(
		"request.save.complete", Core.ACTION_COMPLETE_BATCH
	)).get("success", false)), "Save fixture reaches between-batch maintenance")
	var save_state: Dictionary = original.to_save_state()
	var encoded := JSON.stringify(save_state)
	var decoded_variant: Variant = JSON.parse_string(encoded)
	_expect(decoded_variant is Dictionary, "SaveStateV1 survives JSON encoding and decoding")
	var restored := Core.new()
	var apply_receipt: Dictionary = restored.apply_save_state(decoded_variant as Dictionary)
	_expect(bool(apply_receipt.get("applied", false)), "decoded SaveStateV1 applies to a fresh pure Core")
	_expect(
		str(original.core_authority_snapshot().get("state_fingerprint", ""))
		== str(restored.core_authority_snapshot().get("state_fingerprint", "")),
		"Save roundtrip restores exact zone order, lineage, identity cursor, and RNG cursors"
	)
	_expect(
		original.player_projection(OWNER_ID) == restored.player_projection(OWNER_ID)
		and original.ai_observation(OWNER_ID) == restored.ai_observation(OWNER_ID),
		"restored Core reproduces both three-wing projections exactly"
	)
	var original_end: Dictionary = original.create_intent(
		"request.save.continue", OWNER_ID, Core.ACTION_END_MAINTENANCE
	)
	var restored_end: Dictionary = restored.create_intent(
		"request.save.continue", OWNER_ID, Core.ACTION_END_MAINTENANCE
	)
	_expect(original_end == restored_end, "restored state creates the identical next typed intent")
	_expect(
		original.apply_intent(original_end) == restored.apply_intent(restored_end),
		"restored state creates the identical next authoritative receipt"
	)
	_expect(
		str(original.core_authority_snapshot().get("state_fingerprint", ""))
		== str(restored.core_authority_snapshot().get("state_fingerprint", "")),
		"uninterrupted and restored Core remain bit-exact after continuation"
	)
	var corrupt := save_state.duplicate(true)
	(corrupt.get("state", {}) as Dictionary)["draw_pile"] = []
	var untouched := Core.new()
	var corrupt_receipt: Dictionary = untouched.apply_save_data(corrupt)
	_expect(
		not bool(corrupt_receipt.get("applied", true)) and not untouched.is_ready(),
		"tampered Save payload fails closed before creating partial state"
	)
	var detached := save_state.duplicate(true)
	var defensive := Core.new()
	_expect(bool(defensive.apply_save_data(detached).get("applied", false)), "valid detached Save applies")
	var defensive_fingerprint := str(defensive.core_authority_snapshot().get("state_fingerprint", ""))
	(detached.get("state", {}) as Dictionary)["hand"] = []
	_expect(
		str(defensive.core_authority_snapshot().get("state_fingerprint", "")) == defensive_fingerprint,
		"mutating caller-owned Save data cannot mutate restored Core"
	)


func _test_save_and_rng_fail_closed() -> void:
	var core := _new_core(FIXED_SEED)
	var state_before := _state(core)
	var starter_rng_before := (state_before.get("starter_rng", {}) as Dictionary).duplicate(true)
	var reshuffle_rng_before := (state_before.get("reshuffle_rng", {}) as Dictionary).duplicate(true)
	var projection: Dictionary = core.player_projection(OWNER_ID)
	var card_id := str((((projection.get("facts", {}) as Dictionary).get(
		"hand", []
	) as Array)[0] as Dictionary).get("instance_id", ""))
	var unused_intent: Dictionary = core.create_intent(
		"request.rng.no_draw", OWNER_ID, Core.ACTION_PLAY_CARD, {"instance_id": card_id}
	)
	var save_state: Dictionary = core.to_save_state()
	_expect(Core.validate_intent(unused_intent).is_empty(), "intent capture validates without execution")
	_expect(Core.validate_save_state(save_state).is_empty(), "untampered SaveStateV1 passes strict preflight")
	var state_after_capture := _state(core)
	_expect(
		state_after_capture.get("starter_rng", {}) == starter_rng_before
		and state_after_capture.get("reshuffle_rng", {}) == reshuffle_rng_before,
		"AI/Player projection, Intent creation, Save capture, and preflight consume zero RNG"
	)
	_expect(
		_has_exact_fields(starter_rng_before, Core.RNG_FIELDS)
		and _has_exact_fields(reshuffle_rng_before, Core.RNG_FIELDS)
		and starter_rng_before.get("state_fingerprint")
		== _test_fingerprint_without(starter_rng_before, "state_fingerprint")
		and reshuffle_rng_before.get("state_fingerprint")
		== _test_fingerprint_without(reshuffle_rng_before, "state_fingerprint"),
		"both Saveable RNG streams carry exact closed wire fields and canonical state fingerprints"
	)

	var missing_root := save_state.duplicate(true)
	missing_root.erase("core_fingerprint")
	_expect(
		Core.validate_save_state(missing_root) == "save_state_fields_invalid",
		"SaveStateV1 rejects a missing root fact binding without a default"
	)
	for stream_field in Core.RNG_FIELDS:
		var missing_cursor_field := save_state.duplicate(true)
		var missing_state := missing_cursor_field.get("state", {}) as Dictionary
		(missing_state.get("starter_rng", {}) as Dictionary).erase(stream_field)
		_reseal_save(missing_cursor_field)
		_expect(
			Core.validate_save_state(missing_cursor_field) == "save_state_invariant_invalid",
			"starter RNG rejects missing %s without reconstruction or default" % stream_field
		)
	for stream_field in Core.RNG_FIELDS:
		var missing_cursor_field := save_state.duplicate(true)
		var missing_state := missing_cursor_field.get("state", {}) as Dictionary
		(missing_state.get("reshuffle_rng", {}) as Dictionary).erase(stream_field)
		_reseal_save(missing_cursor_field)
		_expect(
			Core.validate_save_state(missing_cursor_field) == "save_state_invariant_invalid",
			"reshuffle RNG rejects missing %s without reconstruction or default" % stream_field
		)
	var wrong_stream := save_state.duplicate(true)
	var wrong_stream_rng := ((wrong_stream.get("state", {}) as Dictionary).get(
		"reshuffle_rng", {}
	) as Dictionary)
	wrong_stream_rng["stream_id"] = "starter_deck_shuffle"
	_reseal_rng(wrong_stream_rng)
	_reseal_save(wrong_stream)
	_expect(
		Core.validate_save_state(wrong_stream) == "save_state_invariant_invalid",
		"Save preflight rejects an aliased RNG owner stream"
	)
	var negative_cursor := save_state.duplicate(true)
	var negative_rng := ((negative_cursor.get("state", {}) as Dictionary).get(
		"reshuffle_rng", {}
	) as Dictionary)
	negative_rng["cursor"] = {"type": "int64", "decimal": "-1"}
	negative_rng["stream_revision"] = {"type": "int64", "decimal": "-1"}
	_reseal_rng(negative_rng)
	_reseal_save(negative_cursor)
	_expect(
		Core.validate_save_state(negative_cursor) == "save_state_invariant_invalid",
		"Save preflight rejects a negative tagged RNG cursor and revision"
	)
	var forged_nonzero_cursor := save_state.duplicate(true)
	var forged_rng := ((forged_nonzero_cursor.get("state", {}) as Dictionary).get(
		"starter_rng", {}
	) as Dictionary)
	forged_rng["cursor"] = {
		"type": "int64",
		"decimal": str(_tagged_value(forged_rng.get("cursor")) + 1),
	}
	_reseal_save(forged_nonzero_cursor)
	_expect(
		Core.validate_save_state(forged_nonzero_cursor) == "save_state_invariant_invalid",
		"outer Save reseal cannot hide a stale inner RNG state fingerprint"
	)
	var rewound_starter := save_state.duplicate(true)
	var rewound_rng := ((rewound_starter.get("state", {}) as Dictionary).get(
		"starter_rng", {}
	) as Dictionary)
	rewound_rng["cursor"] = {"type": "int64", "decimal": "0"}
	rewound_rng["stream_revision"] = {"type": "int64", "decimal": "0"}
	_reseal_rng(rewound_rng)
	_reseal_save(rewound_starter)
	_expect(
		Core.validate_save_state(rewound_starter) == "save_state_invariant_invalid",
		"starter stream cannot silently rewind its mandatory eleven-draw shuffle"
	)
	var detached_reshuffle_seed := save_state.duplicate(true)
	var detached_rng := ((detached_reshuffle_seed.get("state", {}) as Dictionary).get(
		"reshuffle_rng", {}
	) as Dictionary)
	detached_rng["seed"] = {
		"type": "int64",
		"decimal": str(_tagged_value(detached_rng.get("seed")) + 1),
	}
	_reseal_rng(detached_rng)
	_reseal_save(detached_reshuffle_seed)
	_expect(
		Core.validate_save_state(detached_reshuffle_seed) == "save_state_invariant_invalid",
		"reshuffle stream rejects a valid-looking seed detached from owner-bound root derivation"
	)
	var wrong_instance := save_state.duplicate(true)
	var wrong_instance_rng := ((wrong_instance.get("state", {}) as Dictionary).get(
		"starter_rng", {}
	) as Dictionary)
	wrong_instance_rng["stream_instance_id"] = OTHER_PLAYER_ID
	_reseal_rng(wrong_instance_rng)
	_reseal_save(wrong_instance)
	_expect(
		Core.validate_save_state(wrong_instance) == "save_state_invariant_invalid",
		"RNG stream instance identity must equal the owning player partition"
	)
	var wrong_authority := save_state.duplicate(true)
	var wrong_authority_rng := ((wrong_authority.get("state", {}) as Dictionary).get(
		"starter_rng", {}
	) as Dictionary)
	wrong_authority_rng["authoritative_owner_id"] = "v07.other.core"
	_reseal_rng(wrong_authority_rng)
	_reseal_save(wrong_authority)
	_expect(
		Core.validate_save_state(wrong_authority) == "save_state_invariant_invalid",
		"RNG state rejects an aliased authoritative owner even when independently resealed"
	)
	var wrong_algorithm := save_state.duplicate(true)
	var wrong_algorithm_rng := ((wrong_algorithm.get("state", {}) as Dictionary).get(
		"starter_rng", {}
	) as Dictionary)
	wrong_algorithm_rng["algorithm_id"] = "rng.unspecified"
	_reseal_rng(wrong_algorithm_rng)
	_reseal_save(wrong_algorithm)
	_expect(
		Core.validate_save_state(wrong_algorithm) == "save_state_invariant_invalid",
		"RNG state rejects silent algorithm substitution"
	)
	var malformed_tag := save_state.duplicate(true)
	var malformed_rng := ((malformed_tag.get("state", {}) as Dictionary).get(
		"starter_rng", {}
	) as Dictionary)
	malformed_rng["cursor"] = {"type": "int64", "decimal": "011"}
	_reseal_rng(malformed_rng)
	_reseal_save(malformed_tag)
	_expect(
		Core.validate_save_state(malformed_tag) == "save_state_invariant_invalid",
		"tagged Int64 rejects noncanonical leading-zero cursor text"
	)
	var missing_root_decimal := save_state.duplicate(true)
	((missing_root_decimal.get("state", {}) as Dictionary).get(
		"root_seed", {}
	) as Dictionary).erase("decimal")
	_reseal_save(missing_root_decimal)
	_expect(
		Core.validate_save_state(missing_root_decimal) == "save_state_invariant_invalid",
		"root RNG seed cannot be reconstructed or defaulted when tagged decimal is absent"
	)

	var failed_target := Core.new()
	var failed_apply: Dictionary = failed_target.apply_save_state(negative_cursor)
	_expect(
		not bool(failed_apply.get("applied", true)) and not failed_target.is_ready(),
		"invalid RNG Save cannot leave partial restored Core state"
	)
	var restored := Core.new()
	var restored_receipt: Dictionary = restored.apply_save_state(save_state)
	var restored_state := _state(restored)
	_expect(
		bool(restored_receipt.get("applied", false))
		and restored_state.get("starter_rng", {}) == starter_rng_before
		and restored_state.get("reshuffle_rng", {}) == reshuffle_rng_before,
		"valid restore preserves both RNG streams exactly without consuming a draw"
	)
	var json_roundtrip: Variant = JSON.parse_string(JSON.stringify(save_state))
	var json_state := (json_roundtrip as Dictionary).get("state", {}) as Dictionary
	_expect(
		(json_state.get("root_seed", {}) as Dictionary).get("decimal") == str(FIXED_SEED)
		and ((json_state.get("starter_rng", {}) as Dictionary).get(
			"seed", {}
		) as Dictionary).get("decimal")
		== (starter_rng_before.get("seed", {}) as Dictionary).get("decimal")
		and Core.validate_save_state(json_roundtrip as Dictionary).is_empty(),
		"JSON Save roundtrip preserves root and derived Int64 seed text without a silent numeric default"
	)
	var wrong_owner := Core.new()
	_expect(
		bool(wrong_owner.initialize(OTHER_PLAYER_ID, FIXED_SEED).get("initialized", false)),
		"cross-owner Save fixture initializes independently"
	)
	var wrong_owner_before := str(wrong_owner.core_authority_snapshot().get(
		"state_fingerprint", ""
	))
	var owner_rejection: Dictionary = wrong_owner.apply_save_state(save_state)
	_expect(
		not bool(owner_rejection.get("applied", true))
		and str(owner_rejection.get("reason_code", "")) == "save_state_owner_mismatch"
		and str(wrong_owner.core_authority_snapshot().get("state_fingerprint", ""))
		== wrong_owner_before,
		"initialized player partition rejects another player's Save without mutation"
	)


func _test_reference_boundary() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/v07_semantic/v07_dbg_deck_core.gd")
	_expect(source.begins_with("extends RefCounted"), "source declares the non-Node reference boundary")
	for forbidden in [
		"extends Node",
		"res://scripts/main.gd",
		"GameRuntimeCoordinator",
		"V06SaveOwnerRegistry",
		"RunRngService",
		"get_tree()",
		"get_node(",
	]:
		_expect(not source.contains(forbidden), "DBG Core has no forbidden production dependency: %s" % forbidden)
	_expect(
		not source.contains("docs/rules/v07_game_constitution")
		and not source.contains("v06_save"),
		"reference Core does not mutate or load V0.7 freeze files or V0.6 Save owners"
	)


func _normal_merge_count_fixture(total_card_count: int, seed: int) -> RefCounted:
	var core := _new_core(seed)
	var checkpoint: Dictionary = core.capture_checkpoint()
	var candidate := checkpoint.get("state", {}) as Dictionary
	var cards := _all_cards(candidate)
	var left := (cards[0] as Dictionary).duplicate(true)
	var right := (cards[1] as Dictionary).duplicate(true)
	for field in [
		"semantic_id", "primary_color", "card_type", "merge_family_id", "level",
	]:
		right[field] = left.get(field)
	var hand: Array = [left, right]
	for index in range(2, 5):
		hand.append((cards[index] as Dictionary).duplicate(true))
	candidate["draw_pile"] = []
	candidate["hand"] = hand
	candidate["committed_escrow"] = []
	candidate["discard"] = [] if total_card_count == 5 else [
		(cards[5] as Dictionary).duplicate(true),
	]
	candidate["phase"] = Core.PHASE_MAINTENANCE
	checkpoint["state"] = candidate
	_reseal_checkpoint(checkpoint)
	_expect(
		bool(core.rollback_to_checkpoint(checkpoint).get("rolled_back", false)),
		"minimum-deck fixture installs exactly %d valid normal-card instances" \
		% total_card_count
	)
	return core


func _bring_matching_pair_to_maintenance(core: RefCounted, semantic_id: String) -> Array:
	for cycle in range(1, 25):
		var state := _state(core)
		if str(state.get("phase", "")) == Core.PHASE_BATCH:
			var disposable_ids: Array[String] = []
			for card_variant in state.get("hand", []) as Array:
				var card := card_variant as Dictionary
				if str(card.get("semantic_id", "")) != semantic_id:
					disposable_ids.append(str(card.get("instance_id", "")))
			for card_id in disposable_ids:
				var play_receipt: Dictionary = core.apply_intent(core.create_intent(
					"request.pair.play.%d.%s" % [cycle, card_id],
					OWNER_ID,
					Core.ACTION_PLAY_CARD,
					{"instance_id": card_id}
				))
				if not bool(play_receipt.get("success", false)):
					return []
			var complete_receipt: Dictionary = core.apply_intent(core.create_authority_intent(
				"request.pair.complete.%d" % cycle,
				Core.ACTION_COMPLETE_BATCH
			))
			if not bool(complete_receipt.get("success", false)):
				return []
		state = _state(core)
		var matches: Array = []
		for card_variant in state.get("hand", []) as Array:
			var card := card_variant as Dictionary
			if str(card.get("semantic_id", "")) == semantic_id:
				matches.append(str(card.get("instance_id", "")))
		if matches.size() >= 2:
			return [matches[0], matches[1]]
		var end_receipt: Dictionary = core.apply_intent(core.create_intent(
			"request.pair.end.%d" % cycle,
			OWNER_ID,
			Core.ACTION_END_MAINTENANCE
		))
		if not bool(end_receipt.get("success", false)):
			return []
	return []


func _drive_two_full_batches(core: RefCounted, request_prefix: String) -> void:
	for batch_number in range(1, 3):
		var state := _state(core)
		var card_ids: Array[String] = []
		for card_variant in state.get("hand", []) as Array:
			card_ids.append(str((card_variant as Dictionary).get("instance_id", "")))
		for card_id in card_ids:
			core.apply_intent(core.create_intent(
				"%s.play.%d.%s" % [request_prefix, batch_number, card_id],
				OWNER_ID,
				Core.ACTION_PLAY_CARD,
				{"instance_id": card_id}
			))
		core.apply_intent(core.create_authority_intent(
			"%s.complete.%d" % [request_prefix, batch_number], Core.ACTION_COMPLETE_BATCH
		))
		if batch_number < 2:
			core.apply_intent(core.create_intent(
				"%s.end.%d" % [request_prefix, batch_number],
				OWNER_ID,
				Core.ACTION_END_MAINTENANCE
			))


func _new_core(seed_value: int) -> RefCounted:
	return _new_core_for_owner(OWNER_ID, seed_value)


func _new_core_for_owner(owner_player_id: String, seed_value: int) -> RefCounted:
	var core := Core.new()
	var result: Dictionary = core.initialize(owner_player_id, seed_value)
	_expect(
		bool(result.get("initialized", false))
		and int(result.get("card_count", 0)) == 12
		and int(result.get("hand_count", 0)) == 5,
		"pure DBG fixture initializes from frozen starter rules"
	)
	return core


func _track_claim_arguments(
	sequence: int,
	commodity_id: String,
	primary_color: String,
	actor_player_id: String = OWNER_ID
) -> Dictionary:
	var track_revision := sequence + 100
	var source_revision := sequence + 10
	var item := {
		"instance_id": "track.card.%08d" % sequence,
		"card_definition_id": commodity_id,
		"card_kind": "commodity_card",
		"level": 1,
		"primary_color": primary_color,
		"local_slot_index": 0,
		"track_revision": track_revision,
		"claimable_from_scroll_sequence": 0,
		"claimable": true,
		"claimability_state": "claimable",
	}
	var public_facts := {
		"single_unified_track": true,
		"allowed_card_kinds": ["normal_card", "commodity_card"],
		"track_revision": track_revision,
		"scroll_sequence": 1,
		"unified_track_item_count": 1,
		"balance_profile_id": TrackCore.BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": TrackCore.BALANCE_PROFILE_FINGERPRINT,
		"card_kind_ratio_basis_points": {
			"normal_card": 6000,
			"commodity_card": 4000,
		},
		"color_cycle_number": 1,
		"color_distribution_basis_points": {
			"life": 1667,
			"energy": 1667,
			"industry": 1667,
			"technology": 1667,
			"commerce": 1666,
			"shipping": 1666,
		},
		"revealed_stances": [],
		"completed_batch_count": 0,
		"lead_batch_cursor": 0,
		"lead_tenure_batches": 1,
		"color_cycle_batch_cursor": 0,
		"color_cycle_batches": 6,
		"lead_identity_not_directly_published": true,
		"lead_identity_may_be_inferred_from_public_information": true,
	}
	var private_facts := {
		"own_segment_items": [item],
		"own_pending_stance": {},
		"self_is_current_lead": false,
		"self_influence_class": "normal",
	}
	var source_facts := {
		"schema_version": TrackCore.SCHEMA_VERSION,
		"domain_id": Core.TRACK_DOMAIN_ID,
		"source_revision": source_revision,
		"viewer_actor_id": actor_player_id,
		"public_facts": public_facts,
		"viewer_private_facts": private_facts,
	}
	var observation := {
		"schema_version": TrackCore.SCHEMA_VERSION,
		"interface_id": Core.TRACK_AI_OBSERVATION_SCHEMA_ID,
		"ruleset_id": TrackCore.RULESET_ID,
		"state_version": TrackCore.STATE_VERSION,
		"balance_profile_id": TrackCore.BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": TrackCore.BALANCE_PROFILE_FINGERPRINT,
		"domain_id": Core.TRACK_DOMAIN_ID,
		"source_revision": source_revision,
		"source_core_fingerprint": _test_fingerprint(source_facts),
		"viewer_actor_id": actor_player_id,
		"public_facts": public_facts,
		"viewer_private_facts": private_facts,
	}
	_reseal_external(observation, "projection_fingerprint")
	var source_identity := {
		"schema_version": TrackCore.SCHEMA_VERSION,
		"source_identity_id": "track.source.%s.r%d" % [
			str(item.get("instance_id", "")), track_revision,
		],
		"source_instance_id": str(item.get("instance_id", "")),
		"source_definition_id": commodity_id,
		"source_kind": "commodity_card",
		"source_track_revision": track_revision,
		"segment_owner_id": actor_player_id,
	}
	_reseal_external(source_identity, "identity_fingerprint")
	var authorization := {
		"schema_version": TrackCore.SCHEMA_VERSION,
		"capability_id": "capability.track.claim.%03d" % sequence,
		"authorization_id": "authorization.track.claim.%03d" % sequence,
		"authorization_authority_id": "authority.track.reference",
		"authorized_actor_id": actor_player_id,
		"authorized_source_identity_id": source_identity.get("source_identity_id"),
		"authorized_source_instance_id": source_identity.get("source_instance_id"),
		"authorized_segment_owner_id": actor_player_id,
		"source_track_revision": track_revision,
		"inventory_authority_id": Core.RNG_AUTHORITY_OWNER_ID,
		"cash_authority_id": "authority.none",
	}
	_reseal_external(authorization, "authorization_fingerprint")
	var track_request_id := "request.track.claim.%03d" % sequence
	var track_intent := {
		"schema_version": TrackCore.SCHEMA_VERSION,
		"interface_id": Core.TRACK_CLAIM_INTENT_SCHEMA_ID,
		"domain_id": Core.TRACK_DOMAIN_ID,
		"request_id": track_request_id,
		"intent_id": track_request_id,
		"actor_id": actor_player_id,
		"action_id": Core.TRACK_CLAIM_ACTION_ID,
		"source_revision": source_revision,
		"expected_core_revision": source_revision,
		"source_core_fingerprint": observation.get("source_core_fingerprint"),
		"source_identity": source_identity,
		"viewer_segment_authorization": authorization,
		"parameters": {},
	}
	_reseal_external(track_intent, "intent_fingerprint")
	var receipt := {
		"schema_version": TrackCore.SCHEMA_VERSION,
		"interface_id": Core.TRACK_CLAIM_RECEIPT_SCHEMA_ID,
		"domain_id": Core.TRACK_DOMAIN_ID,
		"request_id": track_request_id,
		"receipt_id": "receipt.track.claim.%03d" % sequence,
		"intent_id": track_request_id,
		"action_id": Core.TRACK_CLAIM_ACTION_ID,
		"intent_fingerprint": track_intent.get("intent_fingerprint"),
		"accepted": true,
		"reason_code": "accepted",
		"source_revision": source_revision,
		"result_revision": source_revision + 1,
		"committed_core_revision": sequence + 1,
		"destination_zone": "commodity_inventory",
		"cash_delta": {
			"mode": "none",
			"track_core_committed": false,
			"amount_known": true,
			"amount_decimal": "0",
			"external_authority_id": "authority.none",
		},
		"inventory_commit": {
			"track_core_committed": false,
			"external_authority_id": Core.RNG_AUTHORITY_OWNER_ID,
			"destination_zone": "commodity_inventory",
		},
		"external_authority_commit_required": true,
		"public_facts": {
			"track_item_removed": true,
			"replacement_count": 1,
			"track_revision": track_revision + 1,
		},
	}
	_reseal_external(receipt, "receipt_fingerprint")
	return {
		"track_claim_receipt": receipt,
		"track_claim_intent": track_intent,
		"track_ai_observation": observation,
	}


func _real_track_group_proof(sequence: int, required_count: int) -> Dictionary:
	for seed_offset in range(256):
		var track_core := TrackCore.new()
		var fixture_seed := FIXED_SEED + sequence * 1009 + seed_offset
		var start_result: Dictionary = track_core.start_match(
			TRACK_ROSTER,
			fixture_seed,
			{
				"balance_profile_id": TrackCore.BALANCE_PROFILE_ID,
				"balance_profile_fingerprint": TrackCore.BALANCE_PROFILE_FINGERPRINT,
				"normal_card_ratio_basis_points": 6000,
				"commodity_card_ratio_basis_points": 4000,
				"local_visible_slot_count": 20,
				"match_instance_id": "match.dbg.group.%03d.%03d" % [
					sequence,
					seed_offset,
				],
			}
		)
		if not bool(start_result.get("accepted", false)):
			continue
		var authority: Dictionary = track_core.core_authority_v1()
		var authority_state := authority.get("authority_state", {}) as Dictionary
		var track_state := authority_state.get("track_state", {}) as Dictionary
		var groups: Dictionary = {}
		for item_variant in track_state.get("items", []) as Array:
			var item := item_variant as Dictionary
			if item.get("card_kind") != "commodity_card":
				continue
			var key := "%s|%s" % [
				str(item.get("card_definition_id", "")),
				str(item.get("primary_color", "")),
			]
			if not groups.has(key):
				groups[key] = []
			(groups.get(key, []) as Array).append(item)
		for key_variant in groups.keys():
			var rows := groups.get(key_variant, []) as Array
			if rows.size() < required_count:
				continue
			var first := rows[0] as Dictionary
			var proof := _track_claim_proof_from_authority(
				track_core,
				"request.track.real_dbg_group.%03d.%03d" % [
					sequence,
					seed_offset,
				],
				OWNER_ID,
				str(first.get("card_definition_id", "")),
				str(first.get("primary_color", ""))
			)
			if proof.is_empty():
				continue
			proof["target_definition_id"] = str(first.get("card_definition_id", ""))
			proof["target_color"] = str(first.get("primary_color", ""))
			return proof
	return {}


func _real_track_claim_proof(
	sequence: int = 1,
	required_definition_id: String = "",
	required_color: String = "",
	actor_id: String = OWNER_ID,
	track_request_id: String = ""
) -> Dictionary:
	if not TRACK_ROSTER.has(actor_id):
		return {}
	for seed_offset in range(128):
		var fixture_seed := FIXED_SEED + sequence * 1009 + seed_offset
		var track_core := TrackCore.new()
		var start_result: Dictionary = track_core.start_match(
			TRACK_ROSTER,
			fixture_seed,
			{
				"balance_profile_id": TrackCore.BALANCE_PROFILE_ID,
				"balance_profile_fingerprint": TrackCore.BALANCE_PROFILE_FINGERPRINT,
				"normal_card_ratio_basis_points": 6000,
				"commodity_card_ratio_basis_points": 4000,
				"local_visible_slot_count": 20,
				"match_instance_id": "match.dbg.claim.%03d.%03d" % [
					sequence,
					seed_offset,
				],
			}
		)
		if not bool(start_result.get("accepted", false)):
			continue
		var effective_request_id := track_request_id
		if effective_request_id.is_empty():
			effective_request_id = "request.track.real_dbg_claim.%03d.%03d" % [
				sequence,
				seed_offset,
			]
		var proof := _track_claim_proof_from_authority(
			track_core,
			effective_request_id,
			actor_id,
			required_definition_id,
			required_color
		)
		if not proof.is_empty():
			return proof
	return {}


func _track_claim_proof_from_authority(
	track_core: RefCounted,
	request_id: String,
	actor_id: String = OWNER_ID,
	required_definition_id: String = "",
	required_color: String = "",
	excluded_instance_ids: Array = []
) -> Dictionary:
	var search_limit := 0
	if not required_definition_id.is_empty() or not required_color.is_empty():
		var authority := track_core.call("core_authority_v1") as Dictionary
		var authority_state := authority.get("authority_state", {}) as Dictionary
		var track_state := authority_state.get("track_state", {}) as Dictionary
		search_limit = int(track_state.get("capacity", 0)) + 1
	for search_step in range(search_limit + 1):
		var observation: Dictionary = track_core.call("ai_observation_v1", actor_id)
		var private_facts := observation.get("viewer_private_facts", {}) as Dictionary
		for item_variant in private_facts.get("own_segment_items", []) as Array:
			var item := item_variant as Dictionary
			if item.get("card_kind") != "commodity_card" \
					or not bool(item.get("claimable", false)) \
					or excluded_instance_ids.has(str(item.get("instance_id", ""))):
				continue
			if not required_definition_id.is_empty() \
					and item.get("card_definition_id") != required_definition_id:
				continue
			if not required_color.is_empty() \
					and item.get("primary_color") != required_color:
				continue
			var source: Dictionary = track_core.call(
				"visible_source_identity_v1",
				actor_id,
				str(item.get("instance_id", ""))
			)
			var suffix := request_id.sha256_text().left(24)
			var authorization: Dictionary = TrackCore.seal_viewer_segment_authorization_v1({
				"schema_version": TrackCore.SCHEMA_VERSION,
				"capability_id": "capability.dbg.real_claim.%s" % suffix,
				"authorization_id": "authorization.dbg.real_claim.%s" % suffix,
				"authorization_authority_id": "authority.track.reference",
				"authorized_actor_id": actor_id,
				"authorized_source_identity_id": source.get("source_identity_id"),
				"authorized_source_instance_id": source.get("source_instance_id"),
				"authorized_segment_owner_id": actor_id,
				"source_track_revision": source.get("source_track_revision"),
				"inventory_authority_id": Core.RNG_AUTHORITY_OWNER_ID,
				"cash_authority_id": "authority.none",
			})
			var intent: Dictionary = track_core.call(
				"build_visible_acquisition_intent_v1",
				request_id,
				actor_id,
				TrackCore.ACTION_CLAIM_VISIBLE_COMMODITY,
				source,
				authorization
			)
			if intent.is_empty():
				continue
			return {
				"authority": track_core,
				"actor_id": actor_id,
				"item": item.duplicate(true),
				"track_intent": intent,
				"track_ai_observation": observation,
			}
		if search_step >= search_limit:
			break
		var advance_intent: Dictionary = track_core.call(
			"build_intent_v1",
			"request.track.dbg_search.%s.%03d" % [
				request_id.sha256_text().left(16),
				search_step,
			],
			"system",
			TrackCore.ACTION_ADVANCE_TRACK,
			{"steps": 1}
		)
		var advance_receipt: Dictionary = track_core.call(
			"apply_intent_v1", advance_intent
		)
		if not bool(advance_receipt.get("accepted", false)):
			return {}
	return {}


func _bind_track_authority(core: RefCounted, proof: Dictionary) -> bool:
	var authority_variant: Variant = proof.get("authority")
	if not (authority_variant is RefCounted):
		return false
	var result: Dictionary = core.bind_unified_track_receipt_authority(
		authority_variant as RefCounted
	)
	return bool(result.get("bound", false)) \
		and str(result.get("reason_code", "")) in [
			"track_receipt_authority_bound",
			"track_receipt_authority_already_bound",
		] \
		and Core.is_pure_data(result)


func _new_acquisition_port(core: RefCounted, track_authority: RefCounted) -> RefCounted:
	var cash := PassiveAcquisitionParticipant.new("authority.cash.test")
	var personal_discard := PassiveAcquisitionParticipant.new(
		"authority.personal_discard.test"
	)
	var port := AcquisitionPort.new(track_authority, {
		"cash": cash,
		"personal_discard": personal_discard,
		"commodity_slot": core,
	})
	return port


func _fully_reseal_track_definition(
	arguments: Dictionary,
	forged_definition_id: String
) -> Dictionary:
	var forged := arguments.duplicate(true)
	var observation := forged.get("track_ai_observation", {}) as Dictionary
	var track_intent := forged.get("track_claim_intent", {}) as Dictionary
	var source_identity := track_intent.get("source_identity", {}) as Dictionary
	var source_instance_id := str(source_identity.get("source_instance_id", ""))
	var private_facts := observation.get("viewer_private_facts", {}) as Dictionary
	var item_found := false
	for item_variant in private_facts.get("own_segment_items", []) as Array:
		var item := item_variant as Dictionary
		if str(item.get("instance_id", "")) == source_instance_id:
			item["card_definition_id"] = forged_definition_id
			item_found = true
			break
	if not item_found:
		return {}
	source_identity["source_definition_id"] = forged_definition_id
	_reseal_external(source_identity, "identity_fingerprint")
	var source_facts := {
		"schema_version": int(observation.get("schema_version", 0)),
		"domain_id": str(observation.get("domain_id", "")),
		"source_revision": int(observation.get("source_revision", 0)),
		"viewer_actor_id": str(observation.get("viewer_actor_id", "")),
		"public_facts": (
			observation.get("public_facts", {}) as Dictionary
		).duplicate(true),
		"viewer_private_facts": private_facts.duplicate(true),
	}
	observation["source_core_fingerprint"] = _test_fingerprint(source_facts)
	_reseal_external(observation, "projection_fingerprint")
	track_intent["source_core_fingerprint"] = observation.get(
		"source_core_fingerprint"
	)
	_reseal_external(track_intent, "intent_fingerprint")
	var receipt := forged.get("track_claim_receipt", {}) as Dictionary
	receipt["intent_fingerprint"] = track_intent.get("intent_fingerprint")
	_reseal_external(receipt, "receipt_fingerprint")
	return forged


func _expect_claim_rejection(
	core: RefCounted,
	request_id: String,
	arguments: Dictionary,
	expected_reason: String,
	message: String
) -> void:
	var before := str(core.core_authority_snapshot().get("state_fingerprint", ""))
	var receipt: Dictionary = core.apply_intent(core.create_authority_intent(
		request_id,
		Core.ACTION_ACCEPT_COMMODITY_CLAIM,
		arguments
	))
	_expect(
		not bool(receipt.get("success", true))
		and str(receipt.get("reason_code", "")) == expected_reason
		and str(core.core_authority_snapshot().get("state_fingerprint", "")) == before,
		message
	)


func _reseal_external(value: Dictionary, fingerprint_field: String) -> void:
	value[fingerprint_field] = _test_fingerprint_without(
		value, fingerprint_field
	)


func _state(core: RefCounted) -> Dictionary:
	return (core.core_authority_snapshot().get("state", {}) as Dictionary).duplicate(true)


func _all_cards(state: Dictionary) -> Array:
	var cards: Array = []
	for zone in ["draw_pile", "hand", "committed_escrow", "discard"]:
		for card_variant in state.get(zone, []) as Array:
			cards.append((card_variant as Dictionary).duplicate(true))
	return cards


func _unique_instance_count(state: Dictionary) -> int:
	var ids: Array[String] = []
	for card_variant in _all_cards(state):
		var instance_id := str((card_variant as Dictionary).get("instance_id", ""))
		if not ids.has(instance_id):
			ids.append(instance_id)
	return ids.size()


func _semantic_order(cards: Array) -> Array[String]:
	var result: Array[String] = []
	for card_variant in cards:
		result.append(str((card_variant as Dictionary).get("semantic_id", "")))
	return result


func _zone_has(cards: Array, instance_id: String) -> bool:
	return not _find_card(cards, instance_id).is_empty()


func _any_zone_has(state: Dictionary, instance_id: String) -> bool:
	for card_variant in _all_cards(state):
		if str((card_variant as Dictionary).get("instance_id", "")) == instance_id:
			return true
	return false


func _find_card(cards: Array, instance_id: String) -> Dictionary:
	for card_variant in cards:
		var card := card_variant as Dictionary
		if str(card.get("instance_id", "")) == instance_id:
			return card.duplicate(true)
	return {}


func _find_commodity(commodities: Array, instance_id: String) -> Dictionary:
	for commodity_variant in commodities:
		var commodity := commodity_variant as Dictionary
		if str(commodity.get("instance_id", "")) == instance_id:
			return commodity.duplicate(true)
	return {}


func _count_semantic(cards: Array, semantic_id: String) -> int:
	var count := 0
	for card_variant in cards:
		if str((card_variant as Dictionary).get("semantic_id", "")) == semantic_id:
			count += 1
	return count


func _different_color_pair(cards: Array) -> Array:
	for left_index in range(cards.size()):
		for right_index in range(left_index + 1, cards.size()):
			var left := cards[left_index] as Dictionary
			var right := cards[right_index] as Dictionary
			if str(left.get("primary_color", "")) != str(right.get("primary_color", "")):
				return [
					str(left.get("instance_id", "")),
					str(right.get("instance_id", "")),
				]
	return []


func _contains_exact_key(value: Variant, key: String) -> bool:
	if value is Array:
		for item_variant in value as Array:
			if _contains_exact_key(item_variant, key):
				return true
	if value is Dictionary:
		if (value as Dictionary).has(key):
			return true
		for nested_variant in (value as Dictionary).values():
			if _contains_exact_key(nested_variant, key):
				return true
	return false


func _reseal_save(save_state: Dictionary) -> void:
	var state := save_state.get("state", {}) as Dictionary
	save_state["state_fingerprint"] = _test_fingerprint(state)
	var core_facts := state.duplicate(true)
	core_facts.erase("receipt_journal")
	save_state["core_fingerprint"] = _test_fingerprint(core_facts)


func _reseal_checkpoint(checkpoint: Dictionary) -> void:
	checkpoint["state_fingerprint"] = _test_fingerprint(
		checkpoint.get("state", {})
	)


func _reseal_rng(rng_state: Dictionary) -> void:
	rng_state["state_fingerprint"] = _test_fingerprint_without(
		rng_state, "state_fingerprint"
	)


func _has_exact_fields(value: Dictionary, fields: Array) -> bool:
	if value.size() != fields.size():
		return false
	for field_variant in fields:
		if not value.has(str(field_variant)):
			return false
	return true


func _is_tagged_int64(value: Variant, require_nonnegative: bool) -> bool:
	if not (value is Dictionary) \
			or not _has_exact_fields(value as Dictionary, ["type", "decimal"]):
		return false
	var tagged := value as Dictionary
	if tagged.get("type") != "int64" or not (tagged.get("decimal") is String):
		return false
	var decimal := str(tagged.get("decimal", ""))
	if decimal.is_empty() or not decimal.is_valid_int() \
			or str(decimal.to_int()) != decimal:
		return false
	return not require_nonnegative or decimal.to_int() >= 0


func _tagged_value(value: Variant) -> int:
	return str((value as Dictionary).get("decimal", "0")).to_int() \
		if value is Dictionary else 0


func _test_fingerprint(value: Variant) -> String:
	return _test_canonical(value).sha256_text()


func _test_fingerprint_without(value: Dictionary, excluded_field: String) -> String:
	var copy := value.duplicate(true)
	copy.erase(excluded_field)
	return _test_fingerprint(copy)


func _test_canonical(value: Variant) -> String:
	if value == null:
		return "null"
	if value is bool:
		return "true" if bool(value) else "false"
	if value is int or value is float:
		return str(value)
	if value is String or value is StringName:
		return JSON.stringify(str(value))
	if value is Array:
		var rows: Array[String] = []
		for item_variant in value as Array:
			rows.append(_test_canonical(item_variant))
		return "[%s]" % ",".join(rows)
	if value is Dictionary:
		var keys: Array[String] = []
		for key_variant in (value as Dictionary).keys():
			keys.append(str(key_variant))
		keys.sort()
		var pairs: Array[String] = []
		for key in keys:
			pairs.append("%s:%s" % [JSON.stringify(key), _test_canonical((value as Dictionary).get(key))])
		return "{%s}" % ",".join(pairs)
	return "<invalid>"


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("PASS: %s" % message)
		return
	_failures.append(message)
	push_error("V07 DBG DECK CORE: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("V0.7.1 DBG deck core test passed. checks=%d" % _checks)
		quit(0)
		return
	push_error("V0.7.1 DBG deck core test failed:\n- %s" % "\n- ".join(_failures))
	quit(1)
