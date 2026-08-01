extends SceneTree

const CORE_SCRIPT := preload(
	"res://scripts/v07_semantic/v07_unified_card_track_core.gd"
)
const ACQUISITION_PORT_SCRIPT := preload(
	"res://scripts/v07_semantic/v07_track_acquisition_authority_port.gd"
)
const ROSTER := ["player.alpha", "player.beta", "player.gamma", "player.delta"]
const FIXED_SEED := 900626424

var _checks := 0
var _failures: Array[String] = []
var _acquisition_ports: Dictionary = {}


class ReferenceAcquisitionParticipant extends RefCounted:
	var authority_id: String
	var state: Dictionary

	func _init(value: String) -> void:
		authority_id = value
		state = {
			"reservations": {},
			"commits": {},
			"prepare_count": 0,
			"commit_count": 0,
		}

	func acquisition_authority_id_v1() -> String:
		return authority_id

	func capture_checkpoint_v1() -> Dictionary:
		return state.duplicate(true)

	func prepare_acquisition_v1(request: Dictionary) -> Dictionary:
		var reservation_id := "reservation.%s.%s" % [
			str(request.get("participant_role", "")),
			str(request.get("transaction_id", "")).sha256_text().left(16),
		]
		var reservations := state.get("reservations", {}) as Dictionary
		reservations[reservation_id] = request.duplicate(true)
		state["reservations"] = reservations
		state["prepare_count"] = int(state.get("prepare_count", 0)) + 1
		return _receipt({
			"accepted": true,
			"reason_code": "participant_prepared",
			"transaction_id": str(request.get("transaction_id", "")),
			"reservation_id": reservation_id,
			"authority_id": authority_id,
			"participant_role": str(request.get("participant_role", "")),
		})

	func commit_prepared_acquisition_v1(
		reservation_id: String,
		track_receipt: Dictionary
	) -> Dictionary:
		var commits := state.get("commits", {}) as Dictionary
		if commits.has(reservation_id):
			return (commits.get(reservation_id, {}) as Dictionary).duplicate(true)
		var request := (
			state.get("reservations", {}) as Dictionary
		).get(reservation_id, {}) as Dictionary
		if request.is_empty():
			return {"accepted": false, "reason_code": "reservation_missing"}
		var result := _receipt({
			"accepted": true,
			"reason_code": "participant_committed",
			"transaction_id": str(request.get("transaction_id", "")),
			"reservation_id": reservation_id,
			"authority_id": authority_id,
			"participant_role": str(request.get("participant_role", "")),
			"track_receipt_fingerprint": str(
				track_receipt.get("receipt_fingerprint", "")
			),
		})
		commits[reservation_id] = result
		state["commits"] = commits
		state["commit_count"] = int(state.get("commit_count", 0)) + 1
		return result.duplicate(true)

	func abort_prepared_acquisition_v1(
		reservation_id: String,
		_reason_code: String
	) -> Dictionary:
		var request := (
			state.get("reservations", {}) as Dictionary
		).get(reservation_id, {}) as Dictionary
		(state.get("reservations", {}) as Dictionary).erase(reservation_id)
		return _receipt({
			"accepted": true,
			"reason_code": "participant_aborted",
			"transaction_id": str(request.get("transaction_id", "")),
			"reservation_id": reservation_id,
			"authority_id": authority_id,
			"participant_role": str(request.get("participant_role", "")),
		})

	func rollback_v1(checkpoint: Dictionary) -> Dictionary:
		state = checkpoint.duplicate(true)
		return {"accepted": true, "reason_code": "participant_rolled_back"}

	func _receipt(unsealed: Dictionary) -> Dictionary:
		return CORE_SCRIPT.sealed_copy(unsealed, "receipt_fingerprint")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_non_node_contract_and_unified_track()
	_test_candidate_a_profile_fail_closed()
	_test_fixed_seed_supply_and_kind_independence()
	_test_rng_stream_adversarial_independence()
	_test_uniform_reset_and_three_six_percent_influence()
	_test_eight_player_influence_is_not_scaled()
	_test_hidden_lead_and_reverse_macro_rounds()
	_test_three_wing_same_source_and_privacy()
	_test_projection_secret_oracle_resistance()
	_test_intent_receipt_and_exact_once()
	_test_visible_acquisition_intents_and_receipts()
	_test_replacement_lock_restore_unlock_and_l1_supply()
	_test_visible_acquisition_fail_closed()
	_test_reverse_round_acquisition_lead_entry()
	_test_checkpoint_rollback_and_save_roundtrip()
	_finish()


func _test_non_node_contract_and_unified_track() -> void:
	var core := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	_expect(
		core is RefCounted and not core.has_method("add_child"),
		"core is non-Node RefCounted data authority"
	)
	_expect(core.is_configured(), "fixed roster and seed configure the authority")
	var contract: Dictionary = core.interface_contract_v1()
	_expect(
		bool(contract.get("single_unified_track", false))
			and bool(contract.get("same_core_source_required", false))
			and not bool(contract.get("production_runtime_connected", true))
			and str(contract.get("ruleset_id", "")) == "v0.7.1"
			and int(contract.get("state_version", 0)) == 4,
		"contract declares one reference-only same-source unified track"
	)
	_expect(
		str(contract.get("balance_profile_id", ""))
				== CORE_SCRIPT.BALANCE_PROFILE_ID
			and str(contract.get("balance_profile_fingerprint", ""))
				== CORE_SCRIPT.BALANCE_PROFILE_FINGERPRINT
			and int(contract.get("default_normal_card_ratio_basis_points", 0)) == 6000
			and int(contract.get("default_commodity_card_ratio_basis_points", 0)) == 4000
			and int(contract.get("default_lead_tenure_batches", 0)) == 1
			and int(contract.get("default_color_cycle_batches", 0)) == 6,
		"contract freezes the approved Candidate A track profile"
	)
	_expect(
		int(contract.get("normal_player_influence_basis_points", 0)) == 300
			and int(contract.get("lead_player_influence_basis_points", 0)) == 600,
		"contract freezes ordinary 3 percent and lead 6 percent influence"
	)
	var interfaces := contract.get("interfaces", {}) as Dictionary
	_expect(
		str(interfaces.get("core", "")) == "v071.unified_track.core_authority.v2"
			and str(interfaces.get("ai_observation", ""))
				== "v071.unified_track.ai_observation.v2"
			and str(interfaces.get("player_projection", ""))
				== "v071.unified_track.player_projection.v2"
			and str(interfaces.get("intent", ""))
				== "v071.unified_track.intent.v2"
			and str(interfaces.get("receipt", ""))
				== "v071.unified_track.authoritative_receipt.v2"
			and str(interfaces.get("save_state", ""))
				== "v071.unified_track.save_state.v2",
		"all six three-wing interfaces use the versioned V0.7.1 contract IDs"
	)
	_expect(
		contract.get("track_replacement_activates_on_next_scroll") == true
			and contract.get("track_replacement_claimable_same_tick") == false
			and int(contract.get("normal_track_spawn_level", 0)) == 1
			and int(contract.get("commodity_track_spawn_level", 0)) == 1
			and contract.get("lead_identity_not_directly_published") == true
			and contract.get(
				"lead_identity_may_be_inferred_from_public_information"
			) == true,
		"contract publishes replacement, L1-only, and soft-hidden rules"
	)
	var privacy: Dictionary = core.privacy_policy_v1()
	_expect(
		CORE_SCRIPT.is_pure_data(privacy)
			and (privacy.get("authority_secret_facts", []) as Array).has(
				"future_supply_bags"
			)
			and (privacy.get("player_private_facts", []) as Array).has(
				"own_track_segment"
			)
			and not (privacy.get("ai_private_facts", []) as Array).has(
				"self_lead_notice_without_numeric_weight"
			)
			and not bool(
				privacy.get("timing_animation_audio_identity_leak_allowed", true)
			)
			and str(privacy.get("projection_source_fingerprint_scope", ""))
				== "allowlisted_viewer_facts_only"
			and not bool(
				privacy.get("projection_source_fingerprint_commits_authority_secrets", true)
			)
			and privacy.get("lead_identity_not_directly_published") == true
			and privacy.get(
				"lead_identity_may_be_inferred_from_public_information"
			) == true,
		"privacy policy enumerates local visibility and authority secrets"
	)
	_expect(
		not bool(contract.get("gdp_affects_track_color_distribution", true))
			and not bool(contract.get("gdp_affects_track_card_type_distribution", true)),
		"GDP has no supply input in either distribution"
	)

	var authority: Dictionary = core.core_authority_v1()
	_expect(
		core.core_authority_snapshot() == authority,
		"CoreAuthorityV1 compatibility entry returns the same detached snapshot"
	)
	var state := authority.get("authority_state", {}) as Dictionary
	var track := state.get("track_state", {}) as Dictionary
	var items := track.get("items", []) as Array
	_expect(CORE_SCRIPT.is_pure_data(authority), "CoreAuthorityV1 is detached pure data")
	_expect(
		str(track.get("state_id", "")) == "V071UnifiedCardTrackState"
			and items.size() == ROSTER.size() * 5,
		"one unified state contains the complete mixed track"
	)
	var kinds: Array[String] = []
	for item_variant in items:
		var item := item_variant as Dictionary
		var kind := str(item.get("card_kind", ""))
		if not kinds.has(kind):
			kinds.append(kind)
		_expect(
			kind in ["normal_card", "commodity_card"]
				and str(item.get("primary_color", "")) in CORE_SCRIPT.COLOR_IDS
				and int(item.get("level", 0)) == 1
				and int(item.get("claimable_from_scroll_sequence", -1)) == 0,
			"every initial unified-track item is L1 and immediately claimable"
		)
	_expect(kinds.size() == 2, "normal and commodity cards coexist on the one track")
	var type_supply := state.get("type_supply_state", {}) as Dictionary
	var type_counts := _count_values(type_supply.get("bag", []) as Array)
	_expect(
		int(type_counts.get("normal_card", 0)) == 60
			and int(type_counts.get("commodity_card", 0)) == 40,
		"the independent fixed-seed type bag preserves Candidate A's 60/40 ratio"
	)
	var stream_ids := [
		str(type_supply.get("stream_id", "")),
		str((state.get("normal_supply_state", {}) as Dictionary).get("stream_id", "")),
		str((state.get("commodity_supply_state", {}) as Dictionary).get("stream_id", "")),
		str(
			((state.get("color_cycle_state", {}) as Dictionary)
				.get("color_supply_state", {}) as Dictionary).get("stream_id", "")
		),
		str(
			(state.get("hidden_lead_cycle_state", {}) as Dictionary)
				.get("stream_id", "")
		),
	]
	var unique_stream_ids: Array[String] = []
	for stream_id in stream_ids:
		if not unique_stream_ids.has(stream_id):
			unique_stream_ids.append(stream_id)
	_expect(
		unique_stream_ids.size() == 5
			and unique_stream_ids.has("unified_track_type_draw")
			and unique_stream_ids.has("unified_track_color_draw")
			and unique_stream_ids.has("unified_track_normal_card_draw")
			and unique_stream_ids.has("unified_track_commodity_draw")
			and unique_stream_ids.has("initial_hidden_lead_order"),
		"authority and SaveState retain five independently owned RNG stream IDs"
	)
	var color_cycle := state.get("color_cycle_state", {}) as Dictionary
	var weights := color_cycle.get("distribution_weight_units", {}) as Dictionary
	_expect(_all_color_values_equal(weights, 10000), "cycle one starts at an exact six-color uniform baseline")
	_expect(
		str(state.get("ruleset_id", "")) == "v0.7.1"
			and int(state.get("state_version", 0)) == 4
			and str(state.get("balance_profile_id", ""))
				== CORE_SCRIPT.BALANCE_PROFILE_ID
			and str(state.get("balance_profile_fingerprint", ""))
				== CORE_SCRIPT.BALANCE_PROFILE_FINGERPRINT
			and int(track.get("scroll_sequence", -1)) == 0
			and not state.has("normal_track")
			and not state.has("commodity_track")
			and not _contains_key_recursive(state, "gdp"),
		"state has no retired split track and no GDP supply field"
	)
	var public_facts := (
		core.player_projection_v1(ROSTER[0]).get("public_facts", {}) as Dictionary
	)
	_expect(
		public_facts.get("lead_identity_not_directly_published") == true
			and public_facts.get(
				"lead_identity_may_be_inferred_from_public_information"
			) == true
			and not _contains_key_recursive(public_facts, "current_lead_id"),
		"soft-hidden projection exposes policy flags but never direct lead identity"
	)


func _test_candidate_a_profile_fail_closed() -> void:
	var wrong_id_core := CORE_SCRIPT.new()
	var wrong_id := wrong_id_core.start_match(ROSTER, FIXED_SEED, {
		"balance_profile_id": "BASELINE_V07",
		"balance_profile_fingerprint": CORE_SCRIPT.BALANCE_PROFILE_FINGERPRINT,
	})
	_expect(
		not bool(wrong_id.get("accepted", true))
			and str(wrong_id.get("reason_code", "")) == "balance_profile_id_invalid"
			and not wrong_id_core.is_configured(),
		"a non-approved balance profile ID fails before match creation"
	)
	var wrong_fingerprint_core := CORE_SCRIPT.new()
	var wrong_fingerprint := wrong_fingerprint_core.start_match(ROSTER, FIXED_SEED, {
		"balance_profile_id": CORE_SCRIPT.BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": "0".repeat(64),
	})
	_expect(
		not bool(wrong_fingerprint.get("accepted", true))
			and str(wrong_fingerprint.get("reason_code", ""))
				== "balance_profile_fingerprint_invalid"
			and not wrong_fingerprint_core.is_configured(),
		"a wrong Candidate A fingerprint fails before match creation"
	)
	var wrong_ratio_core := CORE_SCRIPT.new()
	var wrong_ratio := wrong_ratio_core.start_match(ROSTER, FIXED_SEED, {
		"normal_card_ratio_basis_points": 7000,
		"commodity_card_ratio_basis_points": 3000,
	})
	_expect(
		not bool(wrong_ratio.get("accepted", true))
			and str(wrong_ratio.get("reason_code", ""))
				== "candidate_a_card_kind_ratio_required"
			and not wrong_ratio_core.is_configured(),
		"profile identity cannot be paired with legacy 70/30 values"
	)


func _test_fixed_seed_supply_and_kind_independence() -> void:
	var first := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	var second := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	var different := CORE_SCRIPT.new(ROSTER, FIXED_SEED + 1)
	_expect(
		first.core_authority_v1() == second.core_authority_v1(),
		"identical fixed seeds create byte-identical authority state"
	)
	_expect(
		first.core_authority_v1() != different.core_authority_v1(),
		"a different seed changes an authority-secret supply or lead fact"
	)

	var influenced := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	var neutral := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	var lead_id := _lead_id(influenced)
	var stance := influenced.build_intent_v1(
		"request.kind.independence.stance",
		lead_id,
		CORE_SCRIPT.ACTION_SET_STANCE,
		{"increase_color": "life", "decrease_color": "energy"}
	)
	_expect(bool(influenced.apply_intent_v1(stance).get("accepted", false)), "influence fixture records a legal stance")
	var influenced_commit := influenced.build_intent_v1(
		"request.kind.independence.commit",
		"system",
		CORE_SCRIPT.ACTION_COMMIT_COLOR_CYCLE,
		{}
	)
	var neutral_commit := neutral.build_intent_v1(
		"request.kind.independence.commit",
		"system",
		CORE_SCRIPT.ACTION_COMMIT_COLOR_CYCLE,
		{}
	)
	_expect(
		bool(influenced.apply_intent_v1(influenced_commit).get("accepted", false))
			and bool(neutral.apply_intent_v1(neutral_commit).get("accepted", false)),
		"influenced and neutral cycle boundaries both commit"
	)
	var influenced_state := _authority_state(influenced)
	var neutral_state := _authority_state(neutral)
	_expect(
		influenced_state.get("type_supply_state", {})
			== neutral_state.get("type_supply_state", {}),
		"color stances neither reset nor mutate the card-kind bag"
	)

	var influenced_kinds: Array[String] = []
	var neutral_kinds: Array[String] = []
	for index in range(40):
		_advance_once(influenced, "request.kind.influenced.%02d" % index)
		_advance_once(neutral, "request.kind.neutral.%02d" % index)
		influenced_kinds.append(_incoming_kind(influenced))
		neutral_kinds.append(_incoming_kind(neutral))
	_expect(
		influenced_kinds == neutral_kinds,
		"kind sequence stays identical while the color cycle differs"
	)
	_expect(
		_authority_state(influenced).get("normal_supply_state", {})
			== _authority_state(neutral).get("normal_supply_state", {})
			and _authority_state(influenced).get("commodity_supply_state", {})
				== _authority_state(neutral).get("commodity_supply_state", {}),
		"kind-specific definition bags also stay independent of color influence"
	)


func _test_rng_stream_adversarial_independence() -> void:
	var refill_core := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	for index in range(80):
		_advance_once(refill_core, "request.rng.type.prefill.%03d" % index)
	var before_refill := _authority_state(refill_core)
	var type_before := before_refill.get("type_supply_state", {}) as Dictionary
	var color_before := (
		(before_refill.get("color_cycle_state", {}) as Dictionary)
			.get("color_supply_state", {}) as Dictionary
	)
	_expect(
		int(type_before.get("cursor", -1)) == 100
			and int(color_before.get("cursor", -1)) == 100,
		"adversarial fixture parks both supply cursors before the type-only refill"
	)
	_advance_once(refill_core, "request.rng.type.refill")
	var after_refill := _authority_state(refill_core)
	var type_after := after_refill.get("type_supply_state", {}) as Dictionary
	var color_after := (
		(after_refill.get("color_cycle_state", {}) as Dictionary)
			.get("color_supply_state", {}) as Dictionary
	)
	var refilled_type_counts := _count_values(type_after.get("bag", []) as Array)
	_expect(
		int(refilled_type_counts.get("normal_card", 0)) == 60
			and int(refilled_type_counts.get("commodity_card", 0)) == 40,
		"every refilled type bag preserves exact Candidate A 60/40 composition"
	)
	_expect(
		int(type_after.get("rng_draw_count", 0))
			- int(type_before.get("rng_draw_count", 0)) == 99
			and int(type_after.get("bag_cycle", 0))
				== int(type_before.get("bag_cycle", 0)) + 1,
		"crossing the 100-entry type boundary advances only its 99-step shuffle"
	)
	_expect(
		int(color_after.get("rng_draw_count", -1))
			== int(color_before.get("rng_draw_count", -2))
			and int(color_after.get("rng_state", -1))
				== int(color_before.get("rng_state", -2))
			and int(color_after.get("cursor", -1))
				== int(color_before.get("cursor", -1)) + 1,
		"type refill cannot consume or reseed the color RNG stream"
	)

	var color_reset_core := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	var reset_before := _authority_state(color_reset_core)
	var reset_type_before := (
		reset_before.get("type_supply_state", {}) as Dictionary
	).duplicate(true)
	var reset_color_before := (
		(reset_before.get("color_cycle_state", {}) as Dictionary)
			.get("color_supply_state", {}) as Dictionary
	).duplicate(true)
	_commit_cycle(color_reset_core, "request.rng.color.refill")
	var reset_after := _authority_state(color_reset_core)
	var reset_color_after := (
		(reset_after.get("color_cycle_state", {}) as Dictionary)
			.get("color_supply_state", {}) as Dictionary
	)
	_expect(
		reset_after.get("type_supply_state", {}) == reset_type_before,
		"color-cycle bag rebuild leaves the complete type stream byte-identical"
	)
	_expect(
		int(reset_color_after.get("rng_draw_count", 0))
			- int(reset_color_before.get("rng_draw_count", 0)) == 599
			and int(reset_color_after.get("bag_cycle", 0))
				== int(reset_color_before.get("bag_cycle", 0)) + 1,
		"color reset consumes exactly its own 600-entry shuffle"
	)

	var definition_core := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	var definition_before := _authority_state(definition_core)
	var normal_before := (
		definition_before.get("normal_supply_state", {}) as Dictionary
	).duplicate(true)
	var commodity_before := (
		definition_before.get("commodity_supply_state", {}) as Dictionary
	).duplicate(true)
	_advance_once(definition_core, "request.rng.definition.single")
	var incoming_kind := _incoming_kind(definition_core)
	var definition_after := _authority_state(definition_core)
	if incoming_kind == "normal_card":
		_expect(
			definition_after.get("commodity_supply_state", {}) == commodity_before
				and definition_after.get("normal_supply_state", {}) != normal_before,
			"normal draw advances no commodity-definition RNG state"
		)
	else:
		_expect(
			definition_after.get("normal_supply_state", {}) == normal_before
				and definition_after.get("commodity_supply_state", {}) != commodity_before,
			"commodity draw advances no normal-definition RNG state"
		)


func _test_uniform_reset_and_three_six_percent_influence() -> void:
	var core := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	var lead_id := _lead_id(core)
	var normal_id := ""
	for actor_id in ROSTER:
		if actor_id != lead_id:
			normal_id = actor_id
			break
	_expect(not normal_id.is_empty(), "fixture identifies a non-lead participant from authority state")
	_apply_stance(core, "request.influence.lead", lead_id, "life", "energy")
	_apply_stance(core, "request.influence.normal", normal_id, "industry", "technology")
	var type_before := (
		_authority_state(core).get("type_supply_state", {}) as Dictionary
	).duplicate(true)
	var receipt := _commit_cycle(core, "request.influence.commit")
	_expect(bool(receipt.get("accepted", false)), "mixed 3/6 percent boundary commits")
	var state := _authority_state(core)
	var color_cycle := state.get("color_cycle_state", {}) as Dictionary
	var weights := color_cycle.get("distribution_weight_units", {}) as Dictionary
	_expect(
		int(weights.get("life", 0)) == 13600
			and int(weights.get("energy", 0)) == 6400,
		"boundary lead contributes exactly plus/minus 6 percent"
	)
	_expect(
		int(weights.get("industry", 0)) == 11800
			and int(weights.get("technology", 0)) == 8200,
		"ordinary participant contributes exactly plus/minus 3 percent"
	)
	_expect(
		int(weights.get("commerce", 0)) == 10000
			and int(weights.get("shipping", 0)) == 10000
			and _dictionary_total(weights) == 60000,
		"untouched colors remain uniform and the distribution remains normalized"
	)
	_expect(
		state.get("type_supply_state", {}) == type_before,
		"cycle commit changes color supply without touching the independent type ratio"
	)
	var revealed := color_cycle.get("revealed_stances", []) as Array
	_expect(
		revealed.size() == 2
			and (revealed[0] as Dictionary).has("actor_id")
			and not _contains_key_recursive(revealed, "weight"),
		"reveal links directions to actors while hiding effective weights"
	)

	var next_lead := _lead_id(core)
	var next_normal := ""
	for actor_id in ROSTER:
		if actor_id != next_lead:
			next_normal = actor_id
			break
	_apply_stance(core, "request.reset.normal", next_normal, "commerce", "shipping")
	_commit_cycle(core, "request.reset.commit")
	var reset_weights := (
		(_authority_state(core).get("color_cycle_state", {}) as Dictionary)
			.get("distribution_weight_units", {}) as Dictionary
	)
	_expect(
		int(reset_weights.get("commerce", 0)) == 11800
			and int(reset_weights.get("shipping", 0)) == 8200
			and int(reset_weights.get("life", 0)) == 10000
			and int(reset_weights.get("energy", 0)) == 10000,
		"next cycle resets to uniform before applying its own ordinary 3 percent stance"
	)
	_commit_cycle(core, "request.reset.neutral")
	var neutral_weights := (
		(_authority_state(core).get("color_cycle_state", {}) as Dictionary)
			.get("distribution_weight_units", {}) as Dictionary
	)
	_expect(
		_all_color_values_equal(neutral_weights, 10000),
		"a boundary with no legal stances returns to the exact uniform baseline"
	)


func _test_eight_player_influence_is_not_scaled() -> void:
	var roster := [
		"player.alpha",
		"player.beta",
		"player.gamma",
		"player.delta",
		"player.epsilon",
		"player.zeta",
		"player.eta",
		"player.theta",
	]
	var core := CORE_SCRIPT.new(roster, FIXED_SEED)
	var lead_id := _lead_id(core)
	var normal_id := ""
	for actor_id in roster:
		if actor_id != lead_id:
			normal_id = actor_id
			break
	_apply_stance(core, "request.eight.lead", lead_id, "life", "energy")
	_apply_stance(core, "request.eight.normal", normal_id, "industry", "technology")
	_commit_cycle(core, "request.eight.commit")
	var color_cycle := (
		_authority_state(core).get("color_cycle_state", {}) as Dictionary
	)
	var weights := color_cycle.get("distribution_weight_units", {}) as Dictionary
	_expect(
		int(weights.get("life", 0)) == 13600
			and int(weights.get("energy", 0)) == 6400
			and int(weights.get("industry", 0)) == 11800
			and int(weights.get("technology", 0)) == 8200,
		"8-player roster keeps constitutional 6/3 percent influence without scaling"
	)
	var color_bag := (
		color_cycle.get("color_supply_state", {}) as Dictionary
	).get("bag", []) as Array
	var color_counts := _count_values(color_bag)
	_expect(
		int(color_counts.get("life", 0)) == 136
			and int(color_counts.get("energy", 0)) == 64
			and int(color_counts.get("industry", 0)) == 118
			and int(color_counts.get("technology", 0)) == 82
			and int(color_counts.get("commerce", 0)) == 100
			and int(color_counts.get("shipping", 0)) == 100,
		"committed distribution rebuilds the deterministic 600-entry color bag exactly"
	)


func _test_hidden_lead_and_reverse_macro_rounds() -> void:
	var core := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	var initial := _authority_state(core)
	var hidden := initial.get("hidden_lead_cycle_state", {}) as Dictionary
	var fixed_order := (hidden.get("fixed_order", []) as Array).duplicate(true)
	_expect(
		hidden.get("round_order", []) == fixed_order
			and str(hidden.get("direction", "")) == "forward",
		"macro round one follows the fixed hidden order"
	)
	for index in range(ROSTER.size() * CORE_SCRIPT.DEFAULT_LEAD_TENURE_BATCHES):
		_commit_completed_batch(
			core,
			"request.reverse.forward.%02d" % index,
			index + 1
		)
	var second_round := (
		_authority_state(core).get("hidden_lead_cycle_state", {}) as Dictionary
	)
	var reversed := fixed_order.duplicate()
	reversed.reverse()
	_expect(
		int(second_round.get("macro_round_number", 0)) == 2
			and str(second_round.get("direction", "")) == "reverse"
			and second_round.get("round_order", []) == reversed,
		"macro round two is the exact reverse of the fixed order"
	)
	_expect(
		second_round.get("fixed_order", []) == fixed_order,
		"the authority-secret base order never reshuffles between macro rounds"
	)
	for index in range(ROSTER.size() * CORE_SCRIPT.DEFAULT_LEAD_TENURE_BATCHES):
		_commit_completed_batch(
			core,
			"request.reverse.backward.%02d" % index,
			100 + index
		)
	var third_round := (
		_authority_state(core).get("hidden_lead_cycle_state", {}) as Dictionary
	)
	_expect(
		int(third_round.get("macro_round_number", 0)) == 3
			and str(third_round.get("direction", "")) == "forward"
			and third_round.get("round_order", []) == fixed_order,
		"later macro rounds continue alternating forward and reverse"
	)


func _test_three_wing_same_source_and_privacy() -> void:
	var core := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	var lead_id := _lead_id(core)
	var other_id := ROSTER[0] if ROSTER[0] != lead_id else ROSTER[1]
	var ai: Dictionary = core.ai_observation_v1(lead_id)
	var player: Dictionary = core.player_projection_v1(lead_id)
	_expect(
		int(ai.get("source_revision", 0))
				== int(player.get("source_revision", -1)),
		"AI and player wings project the same authoritative source revision"
	)
	var lead_intent := core.build_intent_v1(
		"request.privacy.lead.intent.token",
		lead_id,
		CORE_SCRIPT.ACTION_SET_STANCE,
		{"increase_color": "life", "decrease_color": "energy"}
	)
	_expect(
		str(lead_intent.get("source_core_fingerprint", ""))
				== str(ai.get("source_core_fingerprint", ""))
			and str(lead_intent.get("source_core_fingerprint", ""))
				!= str(player.get("source_core_fingerprint", ""))
			and not _contains_key_recursive(lead_intent, "self_lead_notice"),
		"Intent source token is derived from AI-safe facts, never Player-only lead notice"
	)
	_expect(
		ai.get("public_facts", {}) == player.get("public_facts", {})
			and (ai.get("viewer_private_facts", {}) as Dictionary).get(
				"own_segment_items", []
			) == (player.get("viewer_private_facts", {}) as Dictionary).get(
				"own_segment_items", []
			),
		"AI and player consume shared allowlisted Core facts without copied rules"
	)
	_expect(
		(ai.get("viewer_private_facts", {}) as Dictionary).get(
			"self_is_current_lead",
			false
		) == true
			and str((ai.get("viewer_private_facts", {}) as Dictionary).get(
				"self_influence_class",
				""
			)) == "double"
			and not (ai.get("viewer_private_facts", {}) as Dictionary).has(
				"self_lead_notice"
			),
		"AI receives only its own semantically equivalent private lead fact"
	)
	var other := core.player_projection_v1(other_id)
	_expect(
		not bool((other.get("viewer_private_facts", {}) as Dictionary).get("self_lead_notice", true)),
		"a non-lead viewer receives no lead identity hint"
	)
	var own_items := (
		(player.get("viewer_private_facts", {}) as Dictionary)
			.get("own_segment_items", []) as Array
	)
	_expect(
		bool((player.get("viewer_private_facts", {}) as Dictionary).get(
			"self_lead_notice", false
		)),
		"Player keeps its private self notice while AI receives an equivalent fact"
	)
	_expect(own_items.size() == 5, "player projection exposes only the viewer's local five-card segment")
	for item_variant in own_items:
		var item := item_variant as Dictionary
		_expect(
			not item.has("segment_owner_id")
				and not item.has("path_origin_index")
				and not item.has("supply_draw_index"),
			"local item projection strips authority routing and future-supply facts"
		)
	for projection in [ai, player, other]:
		_expect(CORE_SCRIPT.is_pure_data(projection), "three-wing projection remains pure data")
		for forbidden_key in [
			"authority_state",
			"fixed_order",
			"round_order",
			"current_lead_id",
			"rng_state",
			"bag",
			"processed_requests",
			"match_seed",
			"effective_weight",
			"pre_normalization_contribution",
			"segment_owner_id",
			"path_origin_index",
		]:
			_expect(
				not _contains_key_recursive(projection, forbidden_key),
				"projection excludes secret field %s" % forbidden_key
			)
	var detached := core.player_projection_v1(lead_id)
	(detached.get("public_facts", {}) as Dictionary)["single_unified_track"] = false
	_expect(
		bool((core.player_projection_v1(lead_id).get("public_facts", {}) as Dictionary).get("single_unified_track", false)),
		"mutating a projection cannot mutate Core authority"
	)
	_expect(core.player_projection_v1("player.unknown").is_empty(), "unknown viewers fail closed")


func _test_projection_secret_oracle_resistance() -> void:
	var private_core := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	var viewer_id := ROSTER[0]
	var hidden_actor_id := ROSTER[1]
	var player_before := private_core.player_projection_v1(viewer_id)
	var ai_before := private_core.ai_observation_v1(viewer_id)
	var hidden_actor_before := private_core.player_projection_v1(hidden_actor_id)
	_apply_stance(
		private_core,
		"request.privacy.other.stance",
		hidden_actor_id,
		"life",
		"energy"
	)
	_expect(
		private_core.player_projection_v1(viewer_id) == player_before
			and private_core.ai_observation_v1(viewer_id) == ai_before,
		"another actor's unrevealed stance changes no viewer field, revision, or fingerprint"
	)
	_expect(
		private_core.player_projection_v1(hidden_actor_id) != hidden_actor_before,
		"the stance owner still receives its own changed private projection"
	)

	var base := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	var base_state := _authority_state(base)
	var hidden := base_state.get("hidden_lead_cycle_state", {}) as Dictionary
	var fixed_order := hidden.get("fixed_order", []) as Array
	var non_lead_viewer := str(fixed_order[2])
	var base_player := base.player_projection_v1(non_lead_viewer)
	var base_ai := base.ai_observation_v1(non_lead_viewer)
	var forged_save := base.save_state_v1()
	var forged_state := forged_save.get("authority_state", {}) as Dictionary
	var forged_type := forged_state.get("type_supply_state", {}) as Dictionary
	var forged_type_bag := forged_type.get("bag", []) as Array
	_expect(
		_swap_distinct_after_cursor(
			forged_type_bag,
			int(forged_type.get("cursor", 0))
		),
		"fixture swaps only undrawn type-bag positions"
	)
	var forged_color := (
		(forged_state.get("color_cycle_state", {}) as Dictionary)
			.get("color_supply_state", {}) as Dictionary
	)
	var forged_color_bag := forged_color.get("bag", []) as Array
	_expect(
		_swap_distinct_after_cursor(
			forged_color_bag,
			int(forged_color.get("cursor", 0))
		),
		"fixture swaps only undrawn color-bag positions"
	)
	forged_type["rng_state"] = _different_positive_rng_state(
		int(forged_type.get("rng_state", 1))
	)
	var forged_hidden := (
		forged_state.get("hidden_lead_cycle_state", {}) as Dictionary
	)
	var forged_order := (forged_hidden.get("fixed_order", []) as Array).duplicate()
	var first_actor: Variant = forged_order[0]
	forged_order[0] = forged_order[1]
	forged_order[1] = first_actor
	forged_hidden["fixed_order"] = forged_order
	forged_hidden["round_order"] = forged_order.duplicate()
	forged_hidden["current_lead_id"] = str(forged_order[0])
	forged_hidden["rng_state"] = _different_positive_rng_state(
		int(forged_hidden.get("rng_state", 1))
	)
	_refresh_forged_segment_bindings(forged_state)
	_reseal_save(forged_save)
	var secret_variant := CORE_SCRIPT.new()
	var secret_restore := secret_variant.restore_save_state_v1(forged_save)
	_expect(bool(secret_restore.get("accepted", false)), "validly resealed secret-only variant restores")
	_expect(
		str(base.core_authority_v1().get("core_fingerprint", ""))
			!= str(secret_variant.core_authority_v1().get("core_fingerprint", "")),
		"future bags, RNG cursor, and hidden lead order genuinely differ in Core"
	)
	_expect(
		secret_variant.player_projection_v1(non_lead_viewer) == base_player
			and secret_variant.ai_observation_v1(non_lead_viewer) == base_ai,
		"secret-only changes produce byte-identical non-lead Player and AI projections"
	)
	var base_intent := base.build_intent_v1(
		"request.privacy.secret.oracle.intent",
		non_lead_viewer,
		CORE_SCRIPT.ACTION_SET_STANCE,
		{"increase_color": "technology", "decrease_color": "shipping"}
	)
	var secret_variant_intent := secret_variant.build_intent_v1(
		"request.privacy.secret.oracle.intent",
		non_lead_viewer,
		CORE_SCRIPT.ACTION_SET_STANCE,
		{"increase_color": "technology", "decrease_color": "shipping"}
	)
	_expect(
		base_intent == secret_variant_intent,
		"hidden lead, future bags, and RNG cannot be inferred through Intent tokens"
	)


func _test_intent_receipt_and_exact_once() -> void:
	var core := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	var actor_id := ROSTER[0]
	var intent := core.build_intent_v1(
		"request.intent.valid",
		actor_id,
		CORE_SCRIPT.ACTION_SET_STANCE,
		{"increase_color": "life", "decrease_color": "energy"}
	)
	_expect(
		CORE_SCRIPT.is_pure_data(intent)
			and str(intent.get("interface_id", "")) == CORE_SCRIPT.INTENT_INTERFACE_ID,
		"IntentV1 is typed, sealed, and pure"
	)
	var receipt: Dictionary = core.apply_intent_v1(intent)
	_expect(
		bool(receipt.get("accepted", false))
			and str(receipt.get("interface_id", "")) == CORE_SCRIPT.RECEIPT_INTERFACE_ID,
		"authority accepts a current legal intent and emits ReceiptV1"
	)
	_expect(
		CORE_SCRIPT.fingerprint(receipt, "receipt_fingerprint")
			== str(receipt.get("receipt_fingerprint", "")),
		"authoritative receipt has a canonical fingerprint"
	)
	var revision_after := int(_authority_state(core).get("revision", 0))
	var duplicate: Dictionary = core.apply_intent_v1(intent)
	_expect(
		duplicate == receipt
			and int(_authority_state(core).get("revision", 0)) == revision_after,
		"duplicate request returns the same receipt without applying twice"
	)
	_expect(
		core.authoritative_receipt_v1("request.intent.valid") == receipt,
		"receipt interface reads the exact persisted result"
	)
	var collision := intent.duplicate(true)
	collision["parameters"] = {
		"increase_color": "industry",
		"decrease_color": "technology",
	}
	collision["intent_fingerprint"] = CORE_SCRIPT.fingerprint(
		collision,
		"intent_fingerprint"
	)
	var before_collision := core.core_authority_v1()
	var collision_receipt := core.apply_intent_v1(collision)
	_expect(
		not bool(collision_receipt.get("accepted", true))
			and str(collision_receipt.get("reason_code", ""))
				== "request_id_collision"
			and core.core_authority_v1() == before_collision,
		"same request ID with a validly resealed different payload fails without mutation"
	)
	var malformed := core.build_intent_v1(
		"request.intent.bad.fingerprint",
		actor_id,
		CORE_SCRIPT.ACTION_SET_STANCE,
		{"increase_color": "commerce", "decrease_color": "shipping"}
	)
	malformed["intent_fingerprint"] = "0".repeat(64)
	var before_malformed := core.core_authority_v1()
	var malformed_receipt := core.apply_intent_v1(malformed)
	_expect(
		not bool(malformed_receipt.get("accepted", true))
			and str(malformed_receipt.get("reason_code", ""))
				== "intent_fingerprint_invalid"
			and core.core_authority_v1() == before_malformed,
		"malformed intent fingerprint fails without consuming request identity"
	)
	var rejected_then_reusable := core.build_intent_v1(
		"request.intent.reusable.after.failure",
		actor_id,
		CORE_SCRIPT.ACTION_SET_STANCE,
		{"increase_color": "commerce", "decrease_color": "shipping"}
	)
	rejected_then_reusable["parameters"] = {
		"increase_color": "commerce",
		"decrease_color": "commerce",
	}
	rejected_then_reusable["intent_fingerprint"] = CORE_SCRIPT.fingerprint(
		rejected_then_reusable,
		"intent_fingerprint"
	)
	var before_rejected := core.core_authority_v1()
	var rejected_receipt := core.apply_intent_v1(rejected_then_reusable)
	_expect(
		not bool(rejected_receipt.get("accepted", true))
			and str(rejected_receipt.get("reason_code", ""))
				== "stance.colors_must_differ"
			and core.core_authority_v1() == before_rejected,
		"well-sealed illegal intent fails without reserving its exact-once identity"
	)
	var corrected_reuse := core.build_intent_v1(
		"request.intent.reusable.after.failure",
		actor_id,
		CORE_SCRIPT.ACTION_SET_STANCE,
		{"increase_color": "commerce", "decrease_color": "shipping"}
	)
	_expect(
		bool(core.apply_intent_v1(corrected_reuse).get("accepted", false)),
		"corrected legal intent may use an identity rejected before commit"
	)

	var stale := core.build_intent_v1(
		"request.intent.stale",
		actor_id,
		CORE_SCRIPT.ACTION_SET_STANCE,
		{"increase_color": "industry", "decrease_color": "commerce"}
	)
	_advance_once(core, "request.intent.advance")
	var before_stale := core.core_authority_v1()
	var stale_receipt := core.apply_intent_v1(stale)
	_expect(
		not bool(stale_receipt.get("accepted", true))
			and str(stale_receipt.get("reason_code", "")) == "source_state_stale"
			and core.core_authority_v1() == before_stale,
		"stale same-source intent fails without mutation"
	)
	var before_late_duplicate := core.core_authority_v1()
	_expect(
		core.apply_intent_v1(intent) == receipt
			and core.core_authority_v1() == before_late_duplicate,
		"accepted request remains exact-once after unrelated later revisions"
	)
	var exact_once_save := core.save_state_v1()
	var exact_once_restored := CORE_SCRIPT.new()
	_expect(
		bool(exact_once_restored.restore_save_state_v1(exact_once_save).get("accepted", false)),
		"exact-once journal restores with SaveState"
	)
	var restored_before_duplicate := exact_once_restored.core_authority_v1()
	_expect(
		exact_once_restored.apply_intent_v1(intent) == receipt
			and exact_once_restored.core_authority_v1()
				== restored_before_duplicate,
		"restored exact-once journal rejects reapplication with the original receipt"
	)
	var invalid := core.build_intent_v1(
		"request.intent.invalid",
		actor_id,
		CORE_SCRIPT.ACTION_SET_STANCE,
		{"increase_color": "life", "decrease_color": "life"}
	)
	_expect(invalid.is_empty(), "IntentV1 refuses a same-color up/down stance")
	var unauthorized := core.build_intent_v1(
		"request.intent.unauthorized",
		"player.unknown",
		CORE_SCRIPT.ACTION_SET_STANCE,
		{"increase_color": "life", "decrease_color": "energy"}
	)
	_expect(unauthorized.is_empty(), "IntentV1 rejects actors outside the frozen roster")
	for forbidden_key in ["current_lead_id", "fixed_order", "rng_state", "bag", "authority_state"]:
		_expect(
			not _contains_key_recursive(receipt, forbidden_key),
			"ReceiptV1 excludes secret field %s" % forbidden_key
		)


func _test_visible_acquisition_intents_and_receipts() -> void:
	var commodity_core := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	var commodity_fixture := _visible_item_of_kind(
		commodity_core,
		"commodity_card"
	)
	_expect(not commodity_fixture.is_empty(), "fixed seed exposes a commodity acquisition fixture")
	if commodity_fixture.is_empty():
		return
	var commodity_actor_id := str(commodity_fixture.get("actor_id", ""))
	var commodity_item := commodity_fixture.get("item", {}) as Dictionary
	var commodity_source := commodity_core.visible_source_identity_v1(
		commodity_actor_id,
		str(commodity_item.get("instance_id", ""))
	)
	var commodity_authorization := _acquisition_authorization(
		commodity_actor_id,
		commodity_source,
		"commodity.success",
		"authority.none"
	)
	var commodity_intent := commodity_core.build_visible_acquisition_intent_v1(
		"request.acquisition.commodity.success",
		commodity_actor_id,
		CORE_SCRIPT.ACTION_CLAIM_VISIBLE_COMMODITY,
		commodity_source,
		commodity_authorization
	)
	_expect(
		not commodity_intent.is_empty()
			and commodity_intent.get("intent_id")
				== commodity_intent.get("request_id")
			and commodity_intent.get("expected_core_revision")
				== commodity_intent.get("source_revision")
			and commodity_intent.get("source_identity") == commodity_source
			and commodity_intent.get("viewer_segment_authorization")
				== commodity_authorization,
		"commodity Intent carries exact source and viewer authorization identities"
	)
	var commodity_before := _authority_state(commodity_core)
	var commodity_before_track := (
		commodity_before.get("track_state", {}) as Dictionary
	)
	var commodity_before_ids := _track_instance_ids(commodity_before)
	var before_direct_apply := commodity_core.core_authority_v1()
	var direct_apply_receipt := commodity_core.apply_intent_v1(commodity_intent)
	_expect(
		not bool(direct_apply_receipt.get("accepted", true))
			and str(direct_apply_receipt.get("reason_code", ""))
				== "acquisition_authority_port_required"
			and commodity_core.core_authority_v1() == before_direct_apply,
		"a valid caller intent cannot bypass participant preparation"
	)
	var commodity_receipt := _transact_track_acquisition(
		commodity_core,
		commodity_intent
	)
	var commodity_after := _authority_state(commodity_core)
	var commodity_after_track := commodity_after.get("track_state", {}) as Dictionary
	var commodity_after_ids := _track_instance_ids(commodity_after)
	var commodity_cash := commodity_receipt.get("cash_delta", {}) as Dictionary
	var commodity_inventory := (
		commodity_receipt.get("inventory_commit", {}) as Dictionary
	)
	_expect(
		bool(commodity_receipt.get("accepted", false))
			and str(commodity_receipt.get("destination_zone", ""))
				== "commodity_inventory"
			and bool(commodity_receipt.get(
				"external_authority_commit_required", false
			)),
		"commodity claim emits the constitutional destination semantic"
	)
	_expect(
		commodity_cash.get("track_core_committed") == false
			and commodity_cash.get("amount_known") == true
			and str(commodity_cash.get("amount_decimal", "")) == "0"
			and str(commodity_cash.get("external_authority_id", ""))
				== "authority.none"
			and commodity_inventory.get("track_core_committed") == false
			and str(commodity_inventory.get("external_authority_id", ""))
				== "authority.inventory.reference",
		"commodity receipt does not fabricate cash or inventory commits"
	)
	_expect(
		commodity_before_ids.has(str(commodity_item.get("instance_id", "")))
			and not commodity_after_ids.has(str(commodity_item.get("instance_id", "")))
			and commodity_before_ids.size() == commodity_after_ids.size()
			and _shared_string_count(commodity_before_ids, commodity_after_ids)
				== commodity_before_ids.size() - 1
			and int(commodity_after_track.get("next_instance_sequence", 0))
				== int(commodity_before_track.get("next_instance_sequence", 0)) + 1
			and int(commodity_after_track.get("revision", 0))
				== int(commodity_before_track.get("revision", 0)) + 1,
		"commodity success removes exactly its source and draws exactly one replacement"
	)
	_expect_acquisition_movement(
		commodity_before,
		commodity_after,
		str(commodity_item.get("instance_id", "")),
		commodity_receipt,
		"commodity"
	)
	var commodity_public := commodity_receipt.get("public_facts", {}) as Dictionary
	_expect(
		_same_string_set(
			commodity_public.keys(),
			["track_item_removed", "replacement_count", "track_revision"]
		)
			and commodity_public.get("track_item_removed") == true
			and commodity_public.get("replacement_count") == 1
			and not commodity_receipt.has("consumed_capability_id")
			and not commodity_receipt.has("consumed_authorization_id"),
		"commodity public facts are exact and private capability identities stay sealed"
	)
	var commodity_committed := commodity_core.core_authority_v1()
	var commodity_duplicate := commodity_core.apply_intent_v1(commodity_intent)
	_expect(
		commodity_duplicate == commodity_receipt
			and commodity_core.core_authority_v1() == commodity_committed,
		"commodity acquisition is exact-once"
	)
	var commodity_restored := CORE_SCRIPT.new()
	_expect(
		bool(commodity_restored.restore_save_state_v1(
			commodity_core.save_state_v1()
		).get("accepted", false)),
		"commodity acquisition journal survives SaveState roundtrip"
	)
	var restored_before_duplicate := commodity_restored.core_authority_v1()
	_expect(
		commodity_restored.apply_intent_v1(commodity_intent) == commodity_receipt
			and commodity_restored.core_authority_v1() == restored_before_duplicate,
		"restored commodity acquisition remains exact-once"
	)
	var restored_capability_reuse := commodity_intent.duplicate(true)
	restored_capability_reuse["request_id"] = (
		"request.acquisition.commodity.restored.capability.reuse"
	)
	restored_capability_reuse["intent_id"] = (
		"request.acquisition.commodity.restored.capability.reuse"
	)
	_refresh_intent_source(
		commodity_restored,
		restored_capability_reuse,
		commodity_actor_id
	)
	_reseal_intent(restored_capability_reuse)
	var restored_before_capability_reuse := commodity_restored.core_authority_v1()
	var restored_capability_reuse_receipt := commodity_restored.apply_intent_v1(
		restored_capability_reuse
	)
	_expect(
		not bool(restored_capability_reuse_receipt.get("accepted", true))
			and str(restored_capability_reuse_receipt.get("reason_code", ""))
				== "capability_already_consumed"
			and commodity_restored.core_authority_v1()
				== restored_before_capability_reuse,
		"Save roundtrip preserves capability consumption across a fresh request ID"
	)

	var normal_core := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	var normal_fixture := _visible_item_of_kind(normal_core, "normal_card")
	_expect(not normal_fixture.is_empty(), "fixed seed exposes a normal purchase fixture")
	if normal_fixture.is_empty():
		return
	var normal_actor_id := str(normal_fixture.get("actor_id", ""))
	var normal_item := normal_fixture.get("item", {}) as Dictionary
	var normal_source := normal_core.visible_source_identity_v1(
		normal_actor_id,
		str(normal_item.get("instance_id", ""))
	)
	var normal_authorization := _acquisition_authorization(
		normal_actor_id,
		normal_source,
		"normal.success",
		"authority.cash.reference"
	)
	var normal_intent := normal_core.build_visible_acquisition_intent_v1(
		"request.acquisition.normal.success",
		normal_actor_id,
		CORE_SCRIPT.ACTION_PURCHASE_VISIBLE_NORMAL_CARD,
		normal_source,
		normal_authorization
	)
	var normal_before := _authority_state(normal_core)
	var normal_before_ids := _track_instance_ids(normal_before)
	var normal_receipt := _transact_track_acquisition(normal_core, normal_intent)
	var normal_after := _authority_state(normal_core)
	var normal_after_ids := _track_instance_ids(normal_after)
	var normal_cash := normal_receipt.get("cash_delta", {}) as Dictionary
	var normal_inventory := normal_receipt.get("inventory_commit", {}) as Dictionary
	_expect(
		bool(normal_receipt.get("accepted", false))
			and str(normal_receipt.get("destination_zone", "")) == "personal_discard"
			and normal_cash.get("track_core_committed") == false
			and normal_cash.get("amount_known") == false
			and str(normal_cash.get("amount_decimal", "")) == "not_owned"
			and str(normal_cash.get("external_authority_id", ""))
				== "authority.cash.reference"
			and normal_inventory.get("track_core_committed") == false
			and str(normal_inventory.get("external_authority_id", ""))
				== "authority.inventory.reference",
		"normal purchase delegates cash and discard inventory commits to named authorities"
	)
	_expect(
		not normal_after_ids.has(str(normal_item.get("instance_id", "")))
			and normal_after_ids.size() == normal_before_ids.size()
			and _shared_string_count(normal_before_ids, normal_after_ids)
				== normal_before_ids.size() - 1,
		"normal purchase removes exactly its source and replenishes one unified-track slot"
	)
	_expect_acquisition_movement(
		normal_before,
		normal_after,
		str(normal_item.get("instance_id", "")),
		normal_receipt,
		"normal"
	)
	_expect(
		_same_string_set(normal_receipt.keys(), CORE_SCRIPT.RECEIPT_FIELDS)
			and str(normal_receipt.get("intent_id", ""))
				== str(normal_intent.get("intent_id", ""))
			and int(normal_receipt.get("committed_core_revision", 0))
				== int(normal_after.get("revision", -1)),
		"normal purchase Receipt implements the exact registry-facing contract"
	)


func _test_replacement_lock_restore_unlock_and_l1_supply() -> void:
	var core := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	var fixture := _visible_item_of_kind(core, "commodity_card")
	_expect(not fixture.is_empty(), "replacement-lock acquisition fixture exists")
	if fixture.is_empty():
		return
	var actor_id := str(fixture.get("actor_id", ""))
	var source_item := fixture.get("item", {}) as Dictionary
	var source_id := str(source_item.get("instance_id", ""))
	var source := core.visible_source_identity_v1(actor_id, source_id)
	var authorization := _acquisition_authorization(
		actor_id,
		source,
		"replacement.lock.source",
		"authority.none"
	)
	var intent := core.build_visible_acquisition_intent_v1(
		"request.replacement.lock.source",
		actor_id,
		CORE_SCRIPT.ACTION_CLAIM_VISIBLE_COMMODITY,
		source,
		authorization
	)
	var before := _authority_state(core)
	var receipt := _transact_track_acquisition(core, intent)
	var after := _authority_state(core)
	_expect(bool(receipt.get("accepted", false)), "source claim creates a replacement")
	var before_ids := _track_instance_ids(before)
	var replacement_id := ""
	for candidate_id in _track_instance_ids(after):
		if not before_ids.has(candidate_id):
			replacement_id = candidate_id
			break
	var after_track := after.get("track_state", {}) as Dictionary
	var replacement := _track_item_by_id(
		after_track.get("items", []) as Array,
		replacement_id
	)
	var replacement_owner := str(replacement.get("segment_owner_id", ""))
	var projected_locked := _projected_item_by_id(
		core,
		replacement_owner,
		replacement_id
	)
	_expect(
		not replacement_id.is_empty()
			and int(after_track.get("scroll_sequence", -1)) == 0
			and int(replacement.get("level", 0)) == 1
			and int(replacement.get("claimable_from_scroll_sequence", -1)) == 1
			and projected_locked.get("claimable") == false
			and str(projected_locked.get("claimability_state", ""))
				== "incoming_locked",
		"replacement is L1 and projects incoming_locked in the claim tick"
	)

	var locked_source := core.visible_source_identity_v1(
		replacement_owner,
		replacement_id
	)
	var locked_action := CORE_SCRIPT.ACTION_CLAIM_VISIBLE_COMMODITY \
		if str(replacement.get("card_kind", "")) == "commodity_card" \
		else CORE_SCRIPT.ACTION_PURCHASE_VISIBLE_NORMAL_CARD
	var locked_authorization := _acquisition_authorization(
		replacement_owner,
		locked_source,
		"replacement.lock.same.tick",
		"authority.none" if locked_action == CORE_SCRIPT.ACTION_CLAIM_VISIBLE_COMMODITY \
		else "authority.cash.reference"
	)
	var locked_intent := core.build_visible_acquisition_intent_v1(
		"request.replacement.lock.same.tick",
		replacement_owner,
		locked_action,
		locked_source,
		locked_authorization
	)
	var before_same_tick := core.core_authority_v1()
	var same_tick_result := _transact_track_acquisition(core, locked_intent)
	_expect(
		not bool(same_tick_result.get("accepted", true))
			and str(same_tick_result.get("reason_code", ""))
				== "track_replacement_locked_until_next_scroll"
			and core.core_authority_v1() == before_same_tick,
		"same-tick replacement claim fails closed without Core mutation"
	)

	var restored := CORE_SCRIPT.new()
	var restore_result := restored.restore_save_state_v1(core.save_state_v1())
	var restored_locked := _projected_item_by_id(
		restored,
		replacement_owner,
		replacement_id
	)
	_expect(
		bool(restore_result.get("accepted", false))
			and restored_locked.get("claimable") == false
			and str(restored_locked.get("claimability_state", ""))
				== "incoming_locked"
			and int(restored_locked.get("claimable_from_scroll_sequence", -1)) == 1,
		"Save/Restore preserves the replacement unlock sequence"
	)
	var restored_source := restored.visible_source_identity_v1(
		replacement_owner,
		replacement_id
	)
	var restored_authorization := _acquisition_authorization(
		replacement_owner,
		restored_source,
		"replacement.lock.restored",
		"authority.none" if locked_action == CORE_SCRIPT.ACTION_CLAIM_VISIBLE_COMMODITY \
		else "authority.cash.reference"
	)
	var restored_intent := restored.build_visible_acquisition_intent_v1(
		"request.replacement.lock.restored",
		replacement_owner,
		locked_action,
		restored_source,
		restored_authorization
	)
	var restored_before_reject := restored.core_authority_v1()
	var restored_reject := _transact_track_acquisition(restored, restored_intent)
	_expect(
		not bool(restored_reject.get("accepted", true))
			and str(restored_reject.get("reason_code", ""))
				== "track_replacement_locked_until_next_scroll"
			and restored.core_authority_v1() == restored_before_reject,
		"restored replacement remains unclaimable before the next scroll"
	)

	_advance_once(restored, "request.replacement.unlock.scroll")
	var unlocked_state := _authority_state(restored)
	var unlocked_track := unlocked_state.get("track_state", {}) as Dictionary
	var unlocked_item := _track_item_by_id(
		unlocked_track.get("items", []) as Array,
		replacement_id
	)
	var unlocked_owner := str(unlocked_item.get("segment_owner_id", ""))
	var projected_unlocked := _projected_item_by_id(
		restored,
		unlocked_owner,
		replacement_id
	)
	_expect(
		int(unlocked_track.get("scroll_sequence", -1)) == 1
			and projected_unlocked.get("claimable") == true
			and str(projected_unlocked.get("claimability_state", "")) == "claimable",
		"the next authoritative scroll unlocks the exact replacement instance"
	)
	var unlocked_source := restored.visible_source_identity_v1(
		unlocked_owner,
		replacement_id
	)
	var unlocked_authorization := _acquisition_authorization(
		unlocked_owner,
		unlocked_source,
		"replacement.unlocked",
		"authority.none" if locked_action == CORE_SCRIPT.ACTION_CLAIM_VISIBLE_COMMODITY \
		else "authority.cash.reference"
	)
	var unlocked_intent := restored.build_visible_acquisition_intent_v1(
		"request.replacement.unlocked",
		unlocked_owner,
		locked_action,
		unlocked_source,
		unlocked_authorization
	)
	var unlocked_receipt := _transact_track_acquisition(restored, unlocked_intent)
	_expect(
		bool(unlocked_receipt.get("accepted", false)),
		"replacement becomes legally claimable after one authoritative scroll"
	)

	var l1_core := CORE_SCRIPT.new(ROSTER, FIXED_SEED + 17)
	var high_level_spawn_count := 0
	for item_variant in (
		(_authority_state(l1_core).get("track_state", {}) as Dictionary)
			.get("items", []) as Array
	):
		if int((item_variant as Dictionary).get("level", 0)) > 1:
			high_level_spawn_count += 1
	for sequence in range(120):
		_advance_once(l1_core, "request.l1.only.%03d" % sequence)
		var incoming := _track_item_at_position(_authority_state(l1_core), 0)
		if int(incoming.get("level", 0)) > 1:
			high_level_spawn_count += 1
	_expect(
		high_level_spawn_count == 0,
		"initial and 120 deterministic replacement draws spawn only L1 cards"
	)
	var forged_level_save := l1_core.save_state_v1()
	var forged_level_state := (
		forged_level_save.get("authority_state", {}) as Dictionary
	)
	var forged_items := (
		forged_level_state.get("track_state", {}) as Dictionary
	).get("items", []) as Array
	(forged_items[0] as Dictionary)["level"] = 2
	_reseal_save(forged_level_save)
	var forged_level_target := CORE_SCRIPT.new()
	_expect(
		not bool(
			forged_level_target.restore_save_state_v1(forged_level_save)
				.get("accepted", true)
		)
			and not forged_level_target.is_configured(),
		"a validly resealed higher-level track spawn fails closed on restore"
	)


func _test_visible_acquisition_fail_closed() -> void:
	var segment_core := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	var segment_fixture := _visible_item_of_kind(segment_core, "commodity_card")
	_expect(not segment_fixture.is_empty(), "segment failure fixture exists")
	if segment_fixture.is_empty():
		return
	var source_actor_id := str(segment_fixture.get("actor_id", ""))
	var source_item := segment_fixture.get("item", {}) as Dictionary
	var source_identity := segment_core.visible_source_identity_v1(
		source_actor_id,
		str(source_item.get("instance_id", ""))
	)
	var authorization := _acquisition_authorization(
		source_actor_id,
		source_identity,
		"failure.segment",
		"authority.none"
	)
	var valid_intent := segment_core.build_visible_acquisition_intent_v1(
		"request.acquisition.failure.segment",
		source_actor_id,
		CORE_SCRIPT.ACTION_CLAIM_VISIBLE_COMMODITY,
		source_identity,
		authorization
	)
	var wrong_actor_id := ROSTER[0] if ROSTER[0] != source_actor_id else ROSTER[1]
	var wrong_segment := valid_intent.duplicate(true)
	var wrong_actor_ai := segment_core.ai_observation_v1(wrong_actor_id)
	wrong_segment["actor_id"] = wrong_actor_id
	wrong_segment["source_revision"] = int(wrong_actor_ai.get("source_revision", 0))
	wrong_segment["expected_core_revision"] = int(
		wrong_actor_ai.get("source_revision", 0)
	)
	wrong_segment["source_core_fingerprint"] = str(
		wrong_actor_ai.get("source_core_fingerprint", "")
	)
	_reseal_intent(wrong_segment)
	var before_wrong_segment := segment_core.core_authority_v1()
	var wrong_segment_receipt := segment_core.apply_intent_v1(wrong_segment)
	_expect(
		not bool(wrong_segment_receipt.get("accepted", true))
			and str(wrong_segment_receipt.get("reason_code", ""))
				== "actor_segment_identity_mismatch"
			and segment_core.core_authority_v1() == before_wrong_segment,
		"wrong-segment acquisition fails without removing or replacing a card"
	)

	var wrong_kind := valid_intent.duplicate(true)
	wrong_kind["action_id"] = CORE_SCRIPT.ACTION_PURCHASE_VISIBLE_NORMAL_CARD
	_reseal_intent(wrong_kind)
	var before_wrong_kind := segment_core.core_authority_v1()
	var wrong_kind_receipt := segment_core.apply_intent_v1(wrong_kind)
	_expect(
		not bool(wrong_kind_receipt.get("accepted", true))
			and str(wrong_kind_receipt.get("reason_code", ""))
				== "source_kind_action_mismatch"
			and segment_core.core_authority_v1() == before_wrong_kind,
		"wrong card kind fails without track mutation"
	)

	var forged_source := valid_intent.duplicate(true)
	var forged_source_identity := (
		forged_source.get("source_identity", {}) as Dictionary
	)
	forged_source_identity["source_definition_id"] = "commodity_card.reference.forged"
	forged_source_identity["identity_fingerprint"] = CORE_SCRIPT.fingerprint(
		forged_source_identity,
		"identity_fingerprint"
	)
	_reseal_intent(forged_source)
	var before_forged_source := segment_core.core_authority_v1()
	var forged_source_receipt := segment_core.apply_intent_v1(forged_source)
	_expect(
		not bool(forged_source_receipt.get("accepted", true))
			and str(forged_source_receipt.get("reason_code", ""))
				== "source_identity_live_mismatch"
			and segment_core.core_authority_v1() == before_forged_source,
		"resealed source identity cannot substitute a different visible definition"
	)

	var tampered_capability := valid_intent.duplicate(true)
	var tampered_authorization := (
		tampered_capability.get("viewer_segment_authorization", {}) as Dictionary
	)
	tampered_authorization["capability_id"] = "capability.forged"
	_reseal_intent(tampered_capability)
	var before_tampered_capability := segment_core.core_authority_v1()
	var tampered_capability_receipt := segment_core.apply_intent_v1(
		tampered_capability
	)
	_expect(
		not bool(tampered_capability_receipt.get("accepted", true))
			and str(tampered_capability_receipt.get("reason_code", ""))
				== "viewer_authorization.fingerprint_invalid"
			and segment_core.core_authority_v1() == before_tampered_capability,
		"tampered capability identity fails closed"
	)

	var stale_core := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	var stale_fixture := _visible_item_of_kind(stale_core, "normal_card")
	var stale_actor_id := str(stale_fixture.get("actor_id", ""))
	var stale_item := stale_fixture.get("item", {}) as Dictionary
	var stale_source := stale_core.visible_source_identity_v1(
		stale_actor_id,
		str(stale_item.get("instance_id", ""))
	)
	var stale_authorization := _acquisition_authorization(
		stale_actor_id,
		stale_source,
		"failure.stale",
		"authority.cash.reference"
	)
	var stale_intent := stale_core.build_visible_acquisition_intent_v1(
		"request.acquisition.failure.stale",
		stale_actor_id,
		CORE_SCRIPT.ACTION_PURCHASE_VISIBLE_NORMAL_CARD,
		stale_source,
		stale_authorization
	)
	_advance_once(stale_core, "request.acquisition.failure.stale.advance")
	var before_stale := stale_core.core_authority_v1()
	var stale_receipt := stale_core.apply_intent_v1(stale_intent)
	_expect(
		not bool(stale_receipt.get("accepted", true))
			and str(stale_receipt.get("reason_code", "")) == "source_state_stale"
			and stale_core.core_authority_v1() == before_stale,
		"stale source revision fails without a second track change"
	)

	var reuse_core := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	var reuse_fixture := _visible_item_of_kind(reuse_core, "commodity_card")
	var reuse_actor_id := str(reuse_fixture.get("actor_id", ""))
	var reuse_item := reuse_fixture.get("item", {}) as Dictionary
	var reuse_source := reuse_core.visible_source_identity_v1(
		reuse_actor_id,
		str(reuse_item.get("instance_id", ""))
	)
	var reuse_authorization := _acquisition_authorization(
		reuse_actor_id,
		reuse_source,
		"failure.reuse",
		"authority.none"
	)
	var first_intent := reuse_core.build_visible_acquisition_intent_v1(
		"request.acquisition.reuse.first",
		reuse_actor_id,
		CORE_SCRIPT.ACTION_CLAIM_VISIBLE_COMMODITY,
		reuse_source,
		reuse_authorization
	)
	_expect(
		bool(_transact_track_acquisition(
			reuse_core,
			first_intent
		).get("accepted", false)),
		"authorization reuse fixture commits once"
	)
	var reused_capability_intent := first_intent.duplicate(true)
	reused_capability_intent["request_id"] = "request.acquisition.reuse.capability"
	reused_capability_intent["intent_id"] = "request.acquisition.reuse.capability"
	_refresh_intent_source(reuse_core, reused_capability_intent, reuse_actor_id)
	_reseal_intent(reused_capability_intent)
	var before_reused_capability := reuse_core.core_authority_v1()
	var reused_capability_receipt := reuse_core.apply_intent_v1(
		reused_capability_intent
	)
	_expect(
		not bool(reused_capability_receipt.get("accepted", true))
			and str(reused_capability_receipt.get("reason_code", ""))
				== "capability_already_consumed"
			and reuse_core.core_authority_v1() == before_reused_capability,
		"consumed capability cannot remove a second card"
	)
	var reused_authorization_intent := first_intent.duplicate(true)
	reused_authorization_intent["request_id"] = "request.acquisition.reuse.authorization"
	reused_authorization_intent["intent_id"] = "request.acquisition.reuse.authorization"
	var reused_authorization := (
		reused_authorization_intent.get(
			"viewer_segment_authorization", {}
		) as Dictionary
	).duplicate(true)
	reused_authorization.erase("authorization_fingerprint")
	reused_authorization["capability_id"] = "capability.failure.reuse.second"
	reused_authorization_intent["viewer_segment_authorization"] = (
		CORE_SCRIPT.seal_viewer_segment_authorization_v1(reused_authorization)
	)
	_refresh_intent_source(reuse_core, reused_authorization_intent, reuse_actor_id)
	_reseal_intent(reused_authorization_intent)
	var before_reused_authorization := reuse_core.core_authority_v1()
	var reused_authorization_receipt := reuse_core.apply_intent_v1(
		reused_authorization_intent
	)
	_expect(
		not bool(reused_authorization_receipt.get("accepted", true))
			and str(reused_authorization_receipt.get("reason_code", ""))
				== "authorization_already_consumed"
			and reuse_core.core_authority_v1() == before_reused_authorization,
		"consumed authorization identity cannot be paired with a fresh capability"
	)


func _test_reverse_round_acquisition_lead_entry() -> void:
	var core := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	for index in range(ROSTER.size() * CORE_SCRIPT.DEFAULT_LEAD_TENURE_BATCHES):
		_commit_completed_batch(
			core,
			"request.acquisition.reverse.boundary.%02d" % index,
			200 + index
		)
	var before := _authority_state(core)
	var hidden := before.get("hidden_lead_cycle_state", {}) as Dictionary
	var fixed_order := hidden.get("fixed_order", []) as Array
	_expect(
		str(hidden.get("direction", "")) == "reverse"
			and str(hidden.get("current_lead_id", "")) == str(fixed_order[-1]),
		"reverse-round fixture freezes the reverse lead before replacement"
	)
	var fixture := _visible_item_of_kind(core, "commodity_card")
	if fixture.is_empty():
		fixture = _visible_item_of_kind(core, "normal_card")
	_expect(not fixture.is_empty(), "reverse-round acquisition fixture exists")
	if fixture.is_empty():
		return
	var actor_id := str(fixture.get("actor_id", ""))
	var item := fixture.get("item", {}) as Dictionary
	var source := core.visible_source_identity_v1(
		actor_id,
		str(item.get("instance_id", ""))
	)
	var is_commodity := str(item.get("card_kind", "")) == "commodity_card"
	var authorization := _acquisition_authorization(
		actor_id,
		source,
		"reverse.lead.entry",
		"authority.none" if is_commodity else "authority.cash.reference"
	)
	var intent := core.build_visible_acquisition_intent_v1(
		"request.acquisition.reverse.lead.entry",
		actor_id,
		CORE_SCRIPT.ACTION_CLAIM_VISIBLE_COMMODITY if is_commodity \
		else CORE_SCRIPT.ACTION_PURCHASE_VISIBLE_NORMAL_CARD,
		source,
		authorization
	)
	var receipt := _transact_track_acquisition(core, intent)
	var after := _authority_state(core)
	_expect(bool(receipt.get("accepted", false)), "reverse-round acquisition commits")
	_expect_acquisition_movement(
		before,
		after,
		str(item.get("instance_id", "")),
		receipt,
		"reverse-round"
	)


func _test_checkpoint_rollback_and_save_roundtrip() -> void:
	var match_config := {"match_instance_id": "match.checkpoint.primary"}
	var core := CORE_SCRIPT.new(ROSTER, FIXED_SEED, match_config)
	var checkpoint: Dictionary = core.capture_checkpoint_v1()
	_expect(
		not checkpoint.is_empty()
			and str(checkpoint.get("match_instance_id", ""))
				== "match.checkpoint.primary"
			and core.capture_checkpoint() == checkpoint,
		"checkpoint carries the same explicit match lineage through every entry"
	)
	var unspecified_lineage := CORE_SCRIPT.new(ROSTER, FIXED_SEED)
	_expect(
		unspecified_lineage.capture_checkpoint_v1().is_empty(),
		"checkpoint capture fails closed until match_instance_id is explicit"
	)
	var blank_checkpoint_target := CORE_SCRIPT.new()
	_expect(
		not bool(blank_checkpoint_target.rollback_v1(checkpoint).get("accepted", true))
			and not blank_checkpoint_target.is_configured(),
		"rollback refuses a checkpoint without an existing authority lineage"
	)
	var foreign_lineage := CORE_SCRIPT.new(
		ROSTER,
		FIXED_SEED + 1,
		match_config
	)
	var foreign_before := foreign_lineage.core_authority_v1()
	var foreign_result := foreign_lineage.rollback_v1(checkpoint)
	_expect(
		not bool(foreign_result.get("accepted", true))
			and str(foreign_result.get("reason_code", ""))
				== "checkpoint_lineage_mismatch"
			and foreign_lineage.core_authority_v1() == foreign_before,
		"checkpoint from another seed lineage cannot replace the current authority"
	)
	var other_match := CORE_SCRIPT.new(
		ROSTER,
		FIXED_SEED,
		{"match_instance_id": "match.checkpoint.other"}
	)
	var other_match_before := other_match.core_authority_v1()
	var other_match_result := other_match.rollback_v1(checkpoint)
	_expect(
		not bool(other_match_result.get("accepted", true))
			and str(other_match_result.get("reason_code", ""))
				== "checkpoint_lineage_mismatch"
			and other_match.core_authority_v1() == other_match_before,
		"same seed and roster cannot cross explicit match_instance_id lineage"
	)
	var forged_checkpoint := checkpoint.duplicate(true)
	var forged_checkpoint_state := (
		forged_checkpoint.get("authority_state", {}) as Dictionary
	)
	var forged_checkpoint_type := (
		forged_checkpoint_state.get("type_supply_state", {}) as Dictionary
	)
	var forged_checkpoint_bag := forged_checkpoint_type.get("bag", []) as Array
	var forged_normal_index := forged_checkpoint_bag.find("normal_card")
	forged_checkpoint_bag[forged_normal_index] = "commodity_card"
	_reseal_checkpoint(forged_checkpoint)
	var before_forged_checkpoint := core.core_authority_v1()
	_expect(
		not bool(core.rollback_v1(forged_checkpoint).get("accepted", true))
			and core.core_authority_v1() == before_forged_checkpoint,
		"validly resealed checkpoint with a corrupt type ratio fails closed"
	)
	var before := core.core_authority_v1()
	_advance_once(core, "request.checkpoint.advance")
	_expect(core.core_authority_v1() != before, "track intent changes authority after checkpoint")
	var rollback_result: Dictionary = core.rollback_v1(checkpoint)
	_expect(
		bool(rollback_result.get("accepted", false))
			and core.core_authority_v1() == before,
		"rollback restores the exact checkpoint including RNG cursors"
	)
	var corrupt_checkpoint := checkpoint.duplicate(true)
	corrupt_checkpoint["source_revision"] = int(corrupt_checkpoint.get("source_revision", 0)) + 1
	var before_corrupt := core.core_authority_v1()
	_expect(
		not bool(core.rollback_v1(corrupt_checkpoint).get("accepted", true))
			and core.core_authority_v1() == before_corrupt,
		"corrupt checkpoint fails closed without mutation"
	)
	_advance_once(core, "request.checkpoint.future")
	var future_checkpoint := core.capture_checkpoint_v1()
	_expect(
		bool(core.rollback_v1(checkpoint).get("accepted", false)),
		"future-checkpoint fixture returns to its exact ancestor"
	)
	var before_future_reject := core.core_authority_v1()
	var future_reject := core.rollback_v1(future_checkpoint)
	_expect(
		not bool(future_reject.get("accepted", true))
			and str(future_reject.get("reason_code", "")) == "checkpoint_from_future"
			and core.core_authority_v1() == before_future_reject,
		"rollback rejects a future checkpoint without mutation"
	)

	var branch_a := CORE_SCRIPT.new(ROSTER, FIXED_SEED, match_config)
	var branch_b := CORE_SCRIPT.new(ROSTER, FIXED_SEED, match_config)
	_apply_stance(branch_a, "request.checkpoint.branch.a", ROSTER[0], "life", "energy")
	_apply_stance(branch_b, "request.checkpoint.branch.b", ROSTER[0], "life", "energy")
	var divergent_checkpoint := branch_b.capture_checkpoint_v1()
	var branch_a_before := branch_a.core_authority_v1()
	var divergent_result := branch_a.rollback_v1(divergent_checkpoint)
	_expect(
		not bool(divergent_result.get("accepted", true))
			and str(divergent_result.get("reason_code", ""))
				== "checkpoint_full_state_lineage_mismatch"
			and branch_a.core_authority_v1() == branch_a_before,
		"same-match same-revision divergent request ancestry is rejected"
	)
	var full_lineage_core := CORE_SCRIPT.new(
		ROSTER,
		FIXED_SEED,
		{"match_instance_id": "match.checkpoint.full.lineage"}
	)
	_apply_stance(
		full_lineage_core,
		"request.checkpoint.full.lineage.stance",
		ROSTER[0],
		"life",
		"energy"
	)
	var validly_resealed_divergent := full_lineage_core.capture_checkpoint_v1()
	var divergent_state := (
		validly_resealed_divergent.get("authority_state", {}) as Dictionary
	)
	var divergent_pending := (
		divergent_state.get("color_cycle_state", {}) as Dictionary
	).get("pending_stances", {}) as Dictionary
	divergent_pending[ROSTER[0]] = {
		"increase_color": "industry",
		"decrease_color": "technology",
	}
	_reseal_checkpoint(validly_resealed_divergent)
	var same_revision_before := full_lineage_core.core_authority_v1()
	var same_revision_divergent := full_lineage_core.rollback_v1(
		validly_resealed_divergent
	)
	_expect(
		not bool(same_revision_divergent.get("accepted", true))
			and str(same_revision_divergent.get("reason_code", ""))
				== "checkpoint_full_state_lineage_mismatch"
			and full_lineage_core.core_authority_v1() == same_revision_before,
		"validly resealed same-revision full-state divergence is rejected"
	)
	_advance_once(full_lineage_core, "request.checkpoint.full.lineage.advance")
	var older_divergent_before := full_lineage_core.core_authority_v1()
	var older_divergent := full_lineage_core.rollback_v1(
		validly_resealed_divergent
	)
	_expect(
		not bool(older_divergent.get("accepted", true))
			and str(older_divergent.get("reason_code", ""))
				== "checkpoint_full_state_lineage_mismatch"
			and full_lineage_core.core_authority_v1() == older_divergent_before,
		"validly resealed older checkpoint requires exact full-state lineage prefix"
	)

	var acquisition_core := CORE_SCRIPT.new(
		ROSTER,
		FIXED_SEED,
		{"match_instance_id": "match.checkpoint.acquisition"}
	)
	var before_acquisition_checkpoint := acquisition_core.capture_checkpoint_v1()
	var acquisition_fixture := _visible_item_of_kind(acquisition_core, "commodity_card")
	var acquisition_actor_id := str(acquisition_fixture.get("actor_id", ""))
	var acquisition_item := acquisition_fixture.get("item", {}) as Dictionary
	var acquisition_source := acquisition_core.visible_source_identity_v1(
		acquisition_actor_id,
		str(acquisition_item.get("instance_id", ""))
	)
	var acquisition_authorization := _acquisition_authorization(
		acquisition_actor_id,
		acquisition_source,
		"checkpoint.external.commit",
		"authority.none"
	)
	var acquisition_intent := acquisition_core.build_visible_acquisition_intent_v1(
		"request.checkpoint.external.acquisition",
		acquisition_actor_id,
		CORE_SCRIPT.ACTION_CLAIM_VISIBLE_COMMODITY,
		acquisition_source,
		acquisition_authorization
	)
	_expect(
		bool(_transact_track_acquisition(
			acquisition_core,
			acquisition_intent
		).get("accepted", false)),
		"externally finalized acquisition fixture commits"
	)
	var acquisition_committed := acquisition_core.core_authority_v1()
	var acquisition_rollback := acquisition_core.rollback_v1(
		before_acquisition_checkpoint
	)
	_expect(
		not bool(acquisition_rollback.get("accepted", true))
			and str(acquisition_rollback.get("reason_code", ""))
				== "checkpoint_requires_transaction_owned_acquisition_rollback"
			and acquisition_core.core_authority_v1() == acquisition_committed,
		"public rollback cannot reopen an externally finalized acquisition"
	)

	_apply_stance(core, "request.save.stance", ROSTER[0], "shipping", "life")
	_commit_cycle(core, "request.save.commit")
	_advance_once(core, "request.save.advance")
	var save: Dictionary = core.save_state_v1()
	_expect(
		CORE_SCRIPT.is_pure_data(save)
			and str(save.get("ruleset_id", "")) == "v0.7.1"
			and int(save.get("state_version", 0)) == 4
			and str(save.get("balance_profile_id", ""))
				== CORE_SCRIPT.BALANCE_PROFILE_ID
			and str(save.get("balance_profile_fingerprint", ""))
				== CORE_SCRIPT.BALANCE_PROFILE_FINGERPRINT
			and str(save.get("interface_id", "")) == CORE_SCRIPT.SAVE_INTERFACE_ID,
		"SaveStateV1 is versioned V0.7.1 authority-secret pure data"
	)
	var missing_profile_save := save.duplicate(true)
	missing_profile_save.erase("balance_profile_id")
	missing_profile_save["save_fingerprint"] = CORE_SCRIPT.fingerprint(
		missing_profile_save,
		"save_fingerprint"
	)
	var missing_profile_target := CORE_SCRIPT.new()
	_expect(
		not bool(
			missing_profile_target.restore_save_state_v1(missing_profile_save)
				.get("accepted", true)
		)
			and not missing_profile_target.is_configured(),
		"V0.7.1 Save rejects a missing balance profile without silent default"
	)
	var wrong_profile_save := save.duplicate(true)
	wrong_profile_save["balance_profile_fingerprint"] = "f".repeat(64)
	wrong_profile_save["save_fingerprint"] = CORE_SCRIPT.fingerprint(
		wrong_profile_save,
		"save_fingerprint"
	)
	var wrong_profile_target := CORE_SCRIPT.new()
	_expect(
		not bool(
			wrong_profile_target.restore_save_state_v1(wrong_profile_save)
				.get("accepted", true)
		)
			and not wrong_profile_target.is_configured(),
		"V0.7.1 Save rejects a mismatched profile fingerprint"
	)
	var wrong_state_profile_save := save.duplicate(true)
	var wrong_state_profile := (
		wrong_state_profile_save.get("authority_state", {}) as Dictionary
	)
	wrong_state_profile["balance_profile_id"] = "BASELINE_V07"
	_reseal_save(wrong_state_profile_save)
	var wrong_state_profile_target := CORE_SCRIPT.new()
	_expect(
		not bool(
			wrong_state_profile_target.restore_save_state_v1(wrong_state_profile_save)
				.get("accepted", true)
		)
			and not wrong_state_profile_target.is_configured(),
		"a resealed authority state cannot substitute another profile"
	)
	var secret_injection_save := save.duplicate(true)
	var secret_injection_state := (
		secret_injection_save.get("authority_state", {}) as Dictionary
	)
	var secret_injection_processed := (
		secret_injection_state.get("processed_requests", {}) as Dictionary
	)
	var injected_request_id := str(secret_injection_processed.keys()[0])
	var injected_record := (
		secret_injection_processed.get(injected_request_id, {}) as Dictionary
	)
	var injected_public_facts := injected_record.get("public_facts", {}) as Dictionary
	injected_public_facts["current_lead_id"] = _lead_id(core)
	_reseal_save(secret_injection_save)
	var secret_injection_target := CORE_SCRIPT.new(
		ROSTER,
		FIXED_SEED + 7,
		{"match_instance_id": "match.secret.injection.target"}
	)
	var secret_injection_before := secret_injection_target.core_authority_v1()
	var secret_injection_result := secret_injection_target.restore_save_state_v1(
		secret_injection_save
	)
	_expect(
		not bool(secret_injection_result.get("accepted", true))
			and str(secret_injection_result.get("reason_code", "")).contains(
				"public_facts"
			)
			and secret_injection_target.core_authority_v1()
				== secret_injection_before,
		"resealed Save cannot inject hidden lead identity into exact public_facts"
	)
	var wrong_public_type_save := save.duplicate(true)
	var wrong_public_type_state := (
		wrong_public_type_save.get("authority_state", {}) as Dictionary
	)
	var wrong_public_type_processed := (
		wrong_public_type_state.get("processed_requests", {}) as Dictionary
	)
	var wrong_public_type_request_id := str(wrong_public_type_processed.keys()[0])
	(wrong_public_type_processed.get(
		wrong_public_type_request_id, {}
	) as Dictionary)["public_facts"] = []
	_reseal_save(wrong_public_type_save)
	var wrong_public_type_result := secret_injection_target.restore_save_state_v1(
		wrong_public_type_save
	)
	_expect(
		not bool(wrong_public_type_result.get("accepted", true))
			and str(wrong_public_type_result.get("reason_code", "")).contains(
				"public_facts.wrong_type"
			)
			and secret_injection_target.core_authority_v1()
				== secret_injection_before,
		"resealed Save rejects a wrong-type action fact set without partial restore"
	)
	var restored := CORE_SCRIPT.new()
	var restore_result: Dictionary = restored.restore_save_state_v1(save)
	_expect(
		bool(restore_result.get("accepted", false))
			and restored.core_authority_v1() == core.core_authority_v1(),
		"SaveStateV1 roundtrip restores exact track, bags, lead, and receipts"
	)
	_advance_once(core, "request.save.parity.next")
	_advance_once(restored, "request.save.parity.next")
	_expect(
		core.core_authority_v1() == restored.core_authority_v1(),
		"restored fixed-seed supply continues with exact next-draw parity"
	)
	var corrupt_save := save.duplicate(true)
	var corrupt_state := corrupt_save.get("authority_state", {}) as Dictionary
	var corrupt_lead := corrupt_state.get("hidden_lead_cycle_state", {}) as Dictionary
	(corrupt_lead.get("fixed_order", []) as Array).reverse()
	var blank := CORE_SCRIPT.new()
	_expect(
		not bool(blank.restore_save_state_v1(corrupt_save).get("accepted", true))
			and not blank.is_configured(),
		"tampered SaveState fingerprint is rejected before state adoption"
	)
	var forged_bag_save := save.duplicate(true)
	var forged_state := forged_bag_save.get("authority_state", {}) as Dictionary
	var forged_type_supply := forged_state.get("type_supply_state", {}) as Dictionary
	var forged_type_bag := forged_type_supply.get("bag", []) as Array
	var normal_index := forged_type_bag.find("normal_card")
	forged_type_bag[normal_index] = "commodity_card"
	forged_bag_save["source_core_fingerprint"] = CORE_SCRIPT.fingerprint(forged_state)
	forged_bag_save["save_fingerprint"] = CORE_SCRIPT.fingerprint(
		forged_bag_save,
		"save_fingerprint"
	)
	var forged_target := CORE_SCRIPT.new()
	_expect(
		not bool(
			forged_target.restore_save_state_v1(forged_bag_save).get("accepted", true)
		)
			and not forged_target.is_configured(),
		"resealed SaveState cannot replace the fixed-ratio type bag"
	)
	var bad_cursor_save := save.duplicate(true)
	var bad_cursor_state := bad_cursor_save.get("authority_state", {}) as Dictionary
	var bad_cursor_type := bad_cursor_state.get("type_supply_state", {}) as Dictionary
	bad_cursor_type["cursor"] = (bad_cursor_type.get("bag", []) as Array).size() + 1
	_reseal_save(bad_cursor_save)
	var configured_target := CORE_SCRIPT.new(ROSTER, FIXED_SEED + 2)
	var configured_before := configured_target.core_authority_v1()
	var bad_cursor_result := configured_target.restore_save_state_v1(bad_cursor_save)
	_expect(
		not bool(bad_cursor_result.get("accepted", true))
			and configured_target.core_authority_v1() == configured_before,
		"validly resealed out-of-range RNG cursor cannot partially replace a configured Core"
	)
	for stream_id in ["type", "normal", "commodity", "color", "hidden_lead"]:
		var bad_rng_save := save.duplicate(true)
		var bad_rng_state := bad_rng_save.get("authority_state", {}) as Dictionary
		match stream_id:
			"type":
				(bad_rng_state.get("type_supply_state", {}) as Dictionary)[
					"rng_state"
				] = CORE_SCRIPT.RNG_MODULUS
			"normal":
				(bad_rng_state.get("normal_supply_state", {}) as Dictionary)[
					"rng_state"
				] = CORE_SCRIPT.RNG_MODULUS
			"commodity":
				(bad_rng_state.get("commodity_supply_state", {}) as Dictionary)[
					"rng_state"
				] = CORE_SCRIPT.RNG_MODULUS
			"color":
				var bad_rng_color_cycle := (
					bad_rng_state.get("color_cycle_state", {}) as Dictionary
				)
				(bad_rng_color_cycle.get("color_supply_state", {}) as Dictionary)[
					"rng_state"
				] = CORE_SCRIPT.RNG_MODULUS
			"hidden_lead":
				(bad_rng_state.get("hidden_lead_cycle_state", {}) as Dictionary)[
					"rng_state"
				] = CORE_SCRIPT.RNG_MODULUS
		_reseal_save(bad_rng_save)
		var bad_rng_target := CORE_SCRIPT.new(
			ROSTER,
			FIXED_SEED + 8,
			{"match_instance_id": "match.bad.rng.%s" % stream_id}
		)
		var bad_rng_before := bad_rng_target.core_authority_v1()
		var bad_rng_result := bad_rng_target.restore_save_state_v1(bad_rng_save)
		_expect(
			not bool(bad_rng_result.get("accepted", true))
				and bad_rng_target.core_authority_v1() == bad_rng_before,
			"Park-Miller %s state rejects modulus upper bound without mutation"
			% stream_id
		)
	var wrong_version_save := save.duplicate(true)
	wrong_version_save["state_version"] = CORE_SCRIPT.STATE_VERSION + 1
	wrong_version_save["save_fingerprint"] = CORE_SCRIPT.fingerprint(
		wrong_version_save,
		"save_fingerprint"
	)
	var wrong_version_target := CORE_SCRIPT.new(ROSTER, FIXED_SEED + 3)
	var wrong_version_before := wrong_version_target.core_authority_v1()
	_expect(
		not bool(
			wrong_version_target.restore_save_state_v1(wrong_version_save)
				.get("accepted", true)
		)
			and wrong_version_target.core_authority_v1() == wrong_version_before,
		"wrong SaveState version is rejected without partial mutation"
	)


func _acquisition_port_for(core: RefCounted) -> RefCounted:
	var key := str(core.get_instance_id())
	if _acquisition_ports.has(key):
		return _acquisition_ports.get(key) as RefCounted
	var port := ACQUISITION_PORT_SCRIPT.new(core, {
		"cash": ReferenceAcquisitionParticipant.new("authority.cash.reference"),
		"personal_discard": ReferenceAcquisitionParticipant.new(
			"authority.inventory.reference"
		),
		"commodity_slot": ReferenceAcquisitionParticipant.new(
			"authority.inventory.reference"
		),
	})
	_expect(port.is_configured(), "reference acquisition authority port binds once")
	_acquisition_ports[key] = port
	return port


func _transact_track_acquisition(
	core: RefCounted,
	intent: Dictionary
) -> Dictionary:
	var port := _acquisition_port_for(core)
	var composite: Dictionary = port.call("transact_v1", intent)
	if not bool(composite.get("accepted", false)):
		return composite
	_expect(
		str(composite.get("interface_id", ""))
			== ACQUISITION_PORT_SCRIPT.COMPOSITE_RECEIPT_INTERFACE_ID
			and composite.get("external_participants_finalized") == true
			and composite.get("track_receipt") is Dictionary,
		"port emits a finalized composite receipt around the direct Track receipt"
	)
	return (
		composite.get("track_receipt", {}) as Dictionary
	).duplicate(true)


func _expect_acquisition_movement(
	before: Dictionary,
	after: Dictionary,
	source_instance_id: String,
	receipt: Dictionary,
	label: String
) -> void:
	var before_track := before.get("track_state", {}) as Dictionary
	var after_track := after.get("track_state", {}) as Dictionary
	var before_items := before_track.get("items", []) as Array
	var after_items := after_track.get("items", []) as Array
	var removed := _track_item_by_id(before_items, source_instance_id)
	var removed_position := int(removed.get("path_position", -1))
	var before_ids := _track_instance_ids(before)
	var after_ids := _track_instance_ids(after)
	var replacement_ids: Array[String] = []
	for instance_id in after_ids:
		if not before_ids.has(instance_id):
			replacement_ids.append(instance_id)
	_expect(
		not removed.is_empty()
			and not after_ids.has(source_instance_id)
			and replacement_ids.size() == 1,
		"%s acquisition exits one instance and refills one instance" % label
	)
	for before_item_variant in before_items:
		var before_item := before_item_variant as Dictionary
		var instance_id := str(before_item.get("instance_id", ""))
		if instance_id == source_instance_id:
			continue
		var after_item := _track_item_by_id(after_items, instance_id)
		var prior_position := int(before_item.get("path_position", -1))
		var expected_position := prior_position + 1 \
			if prior_position < removed_position else prior_position
		_expect(
			not after_item.is_empty()
				and int(after_item.get("path_position", -1)) == expected_position,
			"%s survivor %s follows exact acquisition movement lineage" % [
				label,
				instance_id,
			]
		)
	if replacement_ids.size() == 1:
		var replacement := _track_item_by_id(after_items, replacement_ids[0])
		var hidden := before.get("hidden_lead_cycle_state", {}) as Dictionary
		var fixed_order := hidden.get("fixed_order", []) as Array
		var expected_origin := fixed_order.find(str(hidden.get("current_lead_id", "")))
		_expect(
			int(replacement.get("path_position", -1)) == 0
				and int(replacement.get("path_origin_index", -1)) == expected_origin
				and int(replacement.get("level", 0)) == 1
				and int(replacement.get("claimable_from_scroll_sequence", -1))
					== int(after_track.get("scroll_sequence", 0)) + 1,
			"%s replacement enters at zero from the current hidden-lead origin" % label
		)
	_expect(
		not _contains_key_recursive(receipt, "current_lead_id")
			and not _contains_key_recursive(receipt, "path_origin_index")
			and not _contains_key_recursive(receipt, "hidden_lead"),
		"%s public receipt does not leak hidden lead-entry facts" % label
	)


func _track_item_by_id(items: Array, instance_id: String) -> Dictionary:
	for item_variant in items:
		var item := item_variant as Dictionary
		if str(item.get("instance_id", "")) == instance_id:
			return item.duplicate(true)
	return {}


func _track_item_at_position(authority_state: Dictionary, position: int) -> Dictionary:
	var track := authority_state.get("track_state", {}) as Dictionary
	for item_variant in track.get("items", []) as Array:
		var item := item_variant as Dictionary
		if int(item.get("path_position", -1)) == position:
			return item.duplicate(true)
	return {}


func _projected_item_by_id(
	core: RefCounted,
	actor_id: String,
	instance_id: String
) -> Dictionary:
	var projection: Dictionary = core.call("player_projection_v1", actor_id)
	var private_facts := projection.get("viewer_private_facts", {}) as Dictionary
	for item_variant in private_facts.get("own_segment_items", []) as Array:
		var item := item_variant as Dictionary
		if str(item.get("instance_id", "")) == instance_id:
			return item.duplicate(true)
	return {}


func _apply_stance(
	core: RefCounted,
	request_id: String,
	actor_id: String,
	increase_color: String,
	decrease_color: String
) -> Dictionary:
	var intent: Dictionary = core.call(
		"build_intent_v1",
		request_id,
		actor_id,
		CORE_SCRIPT.ACTION_SET_STANCE,
		{"increase_color": increase_color, "decrease_color": decrease_color}
	)
	var receipt: Dictionary = core.call("apply_intent_v1", intent)
	_expect(bool(receipt.get("accepted", false)), "%s stance intent commits" % request_id)
	return receipt


func _commit_cycle(core: RefCounted, request_id: String) -> Dictionary:
	var intent: Dictionary = core.call(
		"build_intent_v1",
		request_id,
		"system",
		CORE_SCRIPT.ACTION_COMMIT_COLOR_CYCLE,
		{}
	)
	var receipt: Dictionary = core.call("apply_intent_v1", intent)
	_expect(bool(receipt.get("accepted", false)), "%s color boundary commits" % request_id)
	return receipt


func _commit_completed_batch(
	core: RefCounted,
	request_id: String,
	sequence: int
) -> Dictionary:
	var batch_id := "batch.core.contract.%03d" % sequence
	var completed_receipt := CORE_SCRIPT.sealed_copy({
		"schema_version": CORE_SCRIPT.COMPLETED_BATCH_RECEIPT_SCHEMA_VERSION,
		"contract_id": CORE_SCRIPT.COMPLETED_BATCH_RECEIPT_ID,
		"receipt_id": "receipt.%s" % batch_id,
		"batch_id": batch_id,
		"lineage_fingerprint": CORE_SCRIPT.fingerprint({"batch_id": batch_id}),
		"operation_id": "refresh_assets_after_batch",
		"accepted": true,
		"reason_code": "frozen_snapshot_applied",
		"state_revision": sequence,
		"actor_id": "",
		"action_id": "",
		"outcome_id": "assets_refreshed",
		"invalid_target_policy_id": "none",
		"public_history_reason_code": "none",
		"asset_refund_applied": false,
		"normal_card_destination": "none",
		"action_slot_refunded": false,
		"intent_id": "",
		"intent_fingerprint": "",
	}, "receipt_fingerprint")
	var intent: Dictionary = core.call(
		"build_intent_v1",
		request_id,
		"system",
		CORE_SCRIPT.ACTION_COMMIT_BATCH_BOUNDARY,
		{"completed_batch_receipt": completed_receipt}
	)
	var receipt: Dictionary = core.call("apply_intent_v1", intent)
	_expect(
		bool(receipt.get("accepted", false)),
		"%s completed batch boundary commits" % request_id
	)
	return receipt


func _advance_once(core: RefCounted, request_id: String) -> Dictionary:
	var intent: Dictionary = core.call(
		"build_intent_v1",
		request_id,
		"system",
		CORE_SCRIPT.ACTION_ADVANCE_TRACK,
		{"steps": 1}
	)
	var receipt: Dictionary = core.call("apply_intent_v1", intent)
	_expect(bool(receipt.get("accepted", false)), "%s track step commits" % request_id)
	return receipt


func _authority_state(core: RefCounted) -> Dictionary:
	return (
		(core.call("core_authority_v1") as Dictionary)
			.get("authority_state", {}) as Dictionary
	)


func _lead_id(core: RefCounted) -> String:
	return str(
		(_authority_state(core).get("hidden_lead_cycle_state", {}) as Dictionary)
			.get("current_lead_id", "")
	)


func _incoming_kind(core: RefCounted) -> String:
	var items := (
		(_authority_state(core).get("track_state", {}) as Dictionary)
			.get("items", []) as Array
	)
	for item_variant in items:
		var item := item_variant as Dictionary
		if int(item.get("path_position", -1)) == 0:
			return str(item.get("card_kind", ""))
	return ""


func _visible_item_of_kind(core: RefCounted, card_kind: String) -> Dictionary:
	for actor_id in ROSTER:
		var projection: Dictionary = core.call("player_projection_v1", actor_id)
		var private_facts := projection.get("viewer_private_facts", {}) as Dictionary
		for item_variant in private_facts.get("own_segment_items", []) as Array:
			var item := item_variant as Dictionary
			if str(item.get("card_kind", "")) == card_kind:
				return {
					"actor_id": actor_id,
					"item": item.duplicate(true),
				}
	return {}


func _acquisition_authorization(
	actor_id: String,
	source_identity: Dictionary,
	identity_suffix: String,
	cash_authority_id: String
) -> Dictionary:
	return CORE_SCRIPT.seal_viewer_segment_authorization_v1({
		"schema_version": CORE_SCRIPT.SCHEMA_VERSION,
		"capability_id": "capability.%s" % identity_suffix,
		"authorization_id": "authorization.%s" % identity_suffix,
		"authorization_authority_id": "authority.segment.reference",
		"authorized_actor_id": actor_id,
		"authorized_source_identity_id": str(
			source_identity.get("source_identity_id", "")
		),
		"authorized_source_instance_id": str(
			source_identity.get("source_instance_id", "")
		),
		"authorized_segment_owner_id": actor_id,
		"source_track_revision": int(
			source_identity.get("source_track_revision", 0)
		),
		"inventory_authority_id": "authority.inventory.reference",
		"cash_authority_id": cash_authority_id,
	})


func _track_instance_ids(authority_state: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var track := authority_state.get("track_state", {}) as Dictionary
	for item_variant in track.get("items", []) as Array:
		result.append(str((item_variant as Dictionary).get("instance_id", "")))
	return result


func _shared_string_count(first: Array[String], second: Array[String]) -> int:
	var count := 0
	for value in first:
		if second.has(value):
			count += 1
	return count


func _same_string_set(first: Array, second: Array) -> bool:
	if first.size() != second.size():
		return false
	var left: Array[String] = []
	var right: Array[String] = []
	for value in first:
		left.append(str(value))
	for value in second:
		right.append(str(value))
	left.sort()
	right.sort()
	return left == right


func _refresh_intent_source(
	core: RefCounted,
	intent: Dictionary,
	actor_id: String
) -> void:
	var ai: Dictionary = core.call("ai_observation_v1", actor_id)
	intent["source_revision"] = int(ai.get("source_revision", 0))
	intent["expected_core_revision"] = int(ai.get("source_revision", 0))
	intent["source_core_fingerprint"] = str(
		ai.get("source_core_fingerprint", "")
	)


func _reseal_intent(intent: Dictionary) -> void:
	intent["intent_fingerprint"] = CORE_SCRIPT.fingerprint(
		intent,
		"intent_fingerprint"
	)


func _count_values(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		var key := str(value)
		result[key] = int(result.get(key, 0)) + 1
	return result


func _all_color_values_equal(values: Dictionary, expected: int) -> bool:
	for color_id in CORE_SCRIPT.COLOR_IDS:
		if int(values.get(color_id, -1)) != expected:
			return false
	return true


func _dictionary_total(values: Dictionary) -> int:
	var total := 0
	for value in values.values():
		total += int(value)
	return total


func _contains_key_recursive(value: Variant, needle: String) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			if key == needle or key.contains(needle):
				return true
			if _contains_key_recursive((value as Dictionary).get(key_variant), needle):
				return true
	elif value is Array:
		for item in value as Array:
			if _contains_key_recursive(item, needle):
				return true
	return false


func _swap_distinct_after_cursor(values: Array, cursor: int) -> bool:
	for first_index in range(cursor, values.size()):
		for second_index in range(first_index + 1, values.size()):
			if values[first_index] == values[second_index]:
				continue
			var temporary: Variant = values[first_index]
			values[first_index] = values[second_index]
			values[second_index] = temporary
			return true
	return false


func _different_positive_rng_state(current: int) -> int:
	return 1 if current >= 2147483646 else current + 1


func _refresh_forged_segment_bindings(authority_state: Dictionary) -> void:
	var track := authority_state.get("track_state", {}) as Dictionary
	var hidden := authority_state.get("hidden_lead_cycle_state", {}) as Dictionary
	var fixed_order := hidden.get("fixed_order", []) as Array
	var local_slots := int(track.get("local_visible_slot_count", 1))
	for item_variant in track.get("items", []) as Array:
		var item := item_variant as Dictionary
		var segment_offset := int(int(item.get("path_position", 0)) / local_slots)
		var owner_index := (
			int(item.get("path_origin_index", 0)) + segment_offset
		) % fixed_order.size()
		item["segment_owner_id"] = str(fixed_order[owner_index])


func _reseal_save(save_value: Dictionary) -> void:
	var authority_state := save_value.get("authority_state", {}) as Dictionary
	_reseal_state_lineage(authority_state)
	save_value["source_revision"] = int(authority_state.get("revision", 0))
	save_value["source_core_fingerprint"] = CORE_SCRIPT.fingerprint(authority_state)
	save_value["save_fingerprint"] = CORE_SCRIPT.fingerprint(
		save_value,
		"save_fingerprint"
	)


func _reseal_checkpoint(checkpoint_value: Dictionary) -> void:
	var authority_state := (
		checkpoint_value.get("authority_state", {}) as Dictionary
	)
	_reseal_state_lineage(authority_state)
	checkpoint_value["source_revision"] = int(authority_state.get("revision", 0))
	checkpoint_value["source_core_fingerprint"] = CORE_SCRIPT.fingerprint(
		authority_state
	)
	checkpoint_value["checkpoint_fingerprint"] = CORE_SCRIPT.fingerprint(
		checkpoint_value,
		"checkpoint_fingerprint"
	)


func _reseal_state_lineage(authority_state: Dictionary) -> void:
	var history := authority_state.get("revision_lineage", []) as Array
	if history.is_empty():
		return
	var payload := authority_state.duplicate(true)
	payload["revision_lineage"] = []
	var current := history[-1] as Dictionary
	current["state_payload_fingerprint"] = CORE_SCRIPT.fingerprint(payload)
	current["lineage_hash"] = CORE_SCRIPT.fingerprint(current, "lineage_hash")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"V07_UNIFIED_CARD_TRACK_CORE_TEST|status=PASS|checks=%d|failures=0"
			% _checks
		)
		quit(0)
		return
	push_error(
		"V07 unified card track core test failed:\n- %s"
		% "\n- ".join(_failures)
	)
	print(
		"V07_UNIFIED_CARD_TRACK_CORE_TEST|status=FAIL|checks=%d|failures=%d"
		% [_checks, _failures.size()]
	)
	quit(1)
