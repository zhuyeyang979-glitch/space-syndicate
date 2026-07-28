extends SceneTree

const OBSERVATION = preload("res://scripts/semantic/ai_card_batch_observation_v1.gd")
const TARGET = preload("res://scripts/semantic/card_batch_prebound_target_spec_v1.gd")
const INVENTORY = preload("res://scripts/semantic/card_batch_inventory_state_v1.gd")
const SOURCE_OWNER = preload("res://scripts/runtime/ai_card_batch_observation_source_owner.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_hostile_private_payloads_fail_closed()
	_test_inventory_and_candidate_authorization()
	_test_authority_and_fingerprint_tamper()
	_test_source_owner_identity_binding()
	_test_runtime_references_fail_closed()
	_test_public_receipt_allowlist()
	_finish()


func _test_hostile_private_payloads_fail_closed() -> void:
	var owner := _owner()
	var hostile_keys := [
		"opponent_hand",
		"other_player_inventory",
		"hidden_owner",
		"unrevealed_submission",
		"unrevealed_target",
		"future_rack",
		"future_resolution_order",
		"hidden_lead",
		"other_ai_plan",
		"learning_metadata",
		"decision_samples",
		"counter_window",
		"counter_stack",
		"pending_counter_decision",
	]
	for hostile_key in hostile_keys:
		var source := _source()
		var candidate := (source["legal_candidates"] as Array)[0] as Dictionary
		var option := (candidate["legal_target_options"] as Array)[0] as Dictionary
		var binding := option["target_binding"] as Dictionary
		(binding["authored_parameters"] as Dictionary)[hostile_key] = ["private.value"]
		_expect(
			owner.issue_observation(source).is_empty(),
			"hostile payload key is rejected: %s" % hostile_key
		)
	var hidden_value_source := _source()
	var receipt := _public_receipt()
	receipt["outcome_code"] = "hidden-owner:ai.player.5"
	hidden_value_source["public_resolution_receipts"] = [receipt]
	_expect(
		owner.issue_observation(hidden_value_source).is_empty(),
		"hidden owner encoded in an allowed value is rejected"
	)
	var disguised_payload_source := _source()
	var disguised_candidate := (
		(disguised_payload_source["legal_candidates"] as Array)[0] as Dictionary
	)
	var disguised_option := (
		(disguised_candidate["legal_target_options"] as Array)[0] as Dictionary
	)
	var disguised_binding := disguised_option["target_binding"] as Dictionary
	(disguised_binding["authored_parameters"] as Dictionary)["payload"] = [
		"card.ai.player.5.secret.1",
	]
	_expect(
		owner.issue_observation(disguised_payload_source).is_empty(),
		"non-allowlisted parameter bag cannot disguise rival private data"
	)
	var disguised_inventory_source := _source()
	var normal_card := (
		((disguised_inventory_source["own_inventory"] as Dictionary)[
			"normal_cards"
		] as Array)[0] as Dictionary
	)
	normal_card["payload"] = ["card.ai.player.5.secret.1"]
	_expect(
		owner.issue_observation(disguised_inventory_source).is_empty(),
		"own-inventory projection rejects undeclared private payload bags"
	)
	owner.free()


func _test_inventory_and_candidate_authorization() -> void:
	var owner := _owner()
	var actor_mismatch := _source()
	(actor_mismatch["own_inventory"] as Dictionary)["actor_id"] = "ai.player.5"
	_expect(owner.issue_observation(actor_mismatch).is_empty(), "rival inventory cannot masquerade as own inventory")
	var foreign_card := _source()
	var candidate := (foreign_card["legal_candidates"] as Array)[0] as Dictionary
	candidate["card_instance_id"] = "card.ai.player.5.private.1"
	_expect(owner.issue_observation(foreign_card).is_empty(), "unowned card candidate is rejected")
	var wrong_pool := _source()
	var wrong_pool_candidate := (wrong_pool["legal_candidates"] as Array)[0] as Dictionary
	wrong_pool_candidate["source_pool"] = "commodity_inventory"
	wrong_pool_candidate["action_class"] = "commodity_card"
	_expect(owner.issue_observation(wrong_pool).is_empty(), "candidate cannot cross private inventory pools")
	var passive_candidate := _source()
	var passive := (passive_candidate["legal_candidates"] as Array)[0] as Dictionary
	passive["source_pool"] = "bound_action_inventory"
	passive["card_instance_id"] = "bound-passive.ai.2.monster.1"
	passive["card_semantic_id"] = "v07.bound.passive-armor"
	passive["action_class"] = "passive_source_ability"
	_expect(owner.issue_observation(passive_candidate).is_empty(), "passive source ability is never an AI submission candidate")
	var unavailable_bound := _source()
	var inventory := unavailable_bound["own_inventory"] as Dictionary
	var bound := (inventory["bound_actions"] as Array)[0] as Dictionary
	bound["cooldown_remaining_phase_time_usec"] = 1
	var bound_candidate := (unavailable_bound["legal_candidates"] as Array)[0] as Dictionary
	bound_candidate["source_pool"] = "bound_action_inventory"
	bound_candidate["card_instance_id"] = "bound-action.ai.2.monster.1"
	bound_candidate["card_semantic_id"] = "v07.bound.monster-roar"
	bound_candidate["action_class"] = "batch_action"
	_expect(owner.issue_observation(unavailable_bound).is_empty(), "cooling-down bound action is not a legal candidate")
	owner.free()


func _test_authority_and_fingerprint_tamper() -> void:
	var owner := _owner()
	var observation := owner.issue_observation(_source())
	_expect(not observation.is_empty(), "privacy fixture starts with a valid authorized observation")
	var actor_tamper := observation.duplicate(true)
	actor_tamper["viewer_actor_id"] = "ai.player.5"
	_expect(not bool(OBSERVATION.validate(actor_tamper).get("valid", false)), "viewer tamper invalidates authority binding")
	var owner_tamper := observation.duplicate(true)
	(owner_tamper["authority_receipt"] as Dictionary)["authority_owner_id"] = "fake.owner"
	_expect(not bool(OBSERVATION.validate(owner_tamper).get("valid", false)), "forged source owner is rejected")
	var source_tamper := observation.duplicate(true)
	var inventory := source_tamper["own_inventory"] as Dictionary
	(inventory["normal_cards"] as Array).clear()
	_expect(not bool(OBSERVATION.validate(source_tamper).get("valid", false)), "authorized source payload cannot be rewritten")
	var fingerprint_tamper := observation.duplicate(true)
	fingerprint_tamper["observation_fingerprint"] = "0".repeat(64)
	_expect(not bool(OBSERVATION.validate(fingerprint_tamper).get("valid", false)), "observation fingerprint tamper is rejected")
	var public_scope := _source()
	public_scope["visibility_scope_id"] = "public"
	_expect(owner.issue_observation(public_scope).is_empty(), "AI observation cannot be downgraded to a public payload")
	owner.free()


func _test_runtime_references_fail_closed() -> void:
	var owner := _owner()
	var node_source := _source()
	var node_candidate := (node_source["legal_candidates"] as Array)[0] as Dictionary
	var node_option := (node_candidate["legal_target_options"] as Array)[0] as Dictionary
	var node_binding := node_option["target_binding"] as Dictionary
	var hostile_node := Node.new()
	(node_binding["authored_parameters"] as Dictionary)["payload"] = hostile_node
	_expect(owner.issue_observation(node_source).is_empty(), "Node reference is rejected")
	(node_binding["authored_parameters"] as Dictionary).erase("payload")
	hostile_node.free()
	var callable_source := _source()
	var callable_candidate := (callable_source["legal_candidates"] as Array)[0] as Dictionary
	var callable_option := (callable_candidate["legal_target_options"] as Array)[0] as Dictionary
	var callable_binding := callable_option["target_binding"] as Dictionary
	(callable_binding["authored_parameters"] as Dictionary)["payload"] = Callable(self, "_source")
	_expect(owner.issue_observation(callable_source).is_empty(), "Callable reference is rejected")
	owner.free()


func _test_source_owner_identity_binding() -> void:
	var owner := _owner()
	var cross_viewer := _source()
	cross_viewer["viewer_actor_id"] = "ai.player.5"
	_expect(owner.issue_observation(cross_viewer).is_empty(), "source owner rejects cross-viewer forgery")
	var cross_seat := _source()
	cross_seat["viewer_seat_index"] = 5
	_expect(owner.issue_observation(cross_seat).is_empty(), "source owner rejects cross-seat forgery")
	var stale_revision := _source()
	stale_revision["source_revision"] = 24
	_expect(owner.issue_observation(stale_revision).is_empty(), "source owner rejects a stale or foreign source revision")
	_expect(
		not owner.configure_authorized_actor("ai.player.5", 5, 23),
		"source-owner actor binding is immutable after composition"
	)
	_expect(not owner.issue_observation(_source()).is_empty(), "failed rebind leaves the original viewer authorization intact")
	var audit := owner.debug_snapshot()
	_expect(
		int(audit.get("rejected_observation_count", -1)) == 3
			and int(audit.get("issued_observation_count", -1)) == 1,
		"source owner audits cross-viewer and revision rejection without storing payloads"
	)
	owner.free()


func _test_public_receipt_allowlist() -> void:
	var owner := _owner()
	var resolution_source := _source()
	resolution_source["phase"] = "CARD_RESOLUTION_ACTIVE"
	resolution_source["window_remaining_phase_time_usec"] = 0
	resolution_source["own_inventory"] = {}
	resolution_source["legal_candidates"] = []
	resolution_source["public_resolution_receipts"] = [_public_receipt()]
	_expect(not owner.issue_observation(resolution_source).is_empty(), "allowlisted public outcome is readable during resolution")
	var extra_field := resolution_source.duplicate(true)
	var receipt := (extra_field["public_resolution_receipts"] as Array)[0] as Dictionary
	receipt["actor_id"] = "ai.player.5"
	_expect(owner.issue_observation(extra_field).is_empty(), "public receipt rejects an undeclared actor field")
	var private_targets := resolution_source.duplicate(true)
	var private_receipt := (private_targets["public_resolution_receipts"] as Array)[0] as Dictionary
	private_receipt["public_target_ids"] = ["opponent-inventory.ai.player.5"]
	_expect(owner.issue_observation(private_targets).is_empty(), "public receipt target IDs cannot encode rival inventory")
	owner.free()


func _source() -> Dictionary:
	return {
		"schema_version": OBSERVATION.SCHEMA_VERSION,
		"ruleset_id": OBSERVATION.RULESET_ID,
		"viewer_actor_id": "ai.player.2",
		"viewer_seat_index": 2,
		"visibility_scope_id": OBSERVATION.VISIBILITY_SCOPE_ID,
		"batch_id": "card-batch.4",
		"batch_revision": 11,
		"window_id": "card-window.7",
		"window_remaining_phase_time_usec": 18_000_000,
		"source_revision": 23,
		"phase": OBSERVATION.PHASE_CARD_WINDOW_OPEN,
		"own_inventory": _inventory(),
		"legal_candidates": [_candidate()],
		"public_resolution_receipts": [],
	}


func _inventory() -> Dictionary:
	var inventory := INVENTORY.empty("ai.player.2")
	inventory["normal_cards"] = [{
		"card_instance_id": "card.ai.2.defense.1",
		"card_semantic_id": "v07.card.proactive-shield",
		"source_revision": 23,
	}]
	inventory["bound_actions"] = [
		{
			"bound_action_id": "bound-action.ai.2.monster.1",
			"card_semantic_id": "v07.bound.monster-roar",
			"action_kind": "batch_action",
			"source_kind": "monster",
			"source_id": "monster.ai.2.1",
			"source_revision": 23,
			"cooldown_remaining_phase_time_usec": 0,
			"charges": 2,
		},
		{
			"bound_action_id": "bound-passive.ai.2.monster.1",
			"card_semantic_id": "v07.bound.passive-armor",
			"action_kind": "passive_source_ability",
			"source_kind": "monster",
			"source_id": "monster.ai.2.1",
			"source_revision": 23,
			"cooldown_remaining_phase_time_usec": 0,
			"charges": 1,
		},
	]
	return inventory


func _candidate() -> Dictionary:
	return {
		"card_instance_id": "card.ai.2.defense.1",
		"card_semantic_id": "v07.card.proactive-shield",
		"source_pool": "normal_hand",
		"source_revision": 23,
		"action_class": "proactive_defense",
		"order_priority": 10,
		"submission_sequence": 0,
		"base_utility": 2,
		"urgency": 3,
		"legal_target_options": [{
			"visibility_scope_id": "actor_private",
			"target_binding": TARGET.build(
				"facility",
				["facility.ai.player.2.alpha"],
				12,
				"shield-slot.1",
				"protect",
				1,
				{"defense_kind": "shield"}
			),
			"target_value": 3,
			"threat_level": 8,
			"synergy_value": 2,
		}],
	}


func _public_receipt() -> Dictionary:
	return {
		"receipt_id": "card-resolution-receipt.public.1",
		"result_kind": "effect_committed",
		"public_target_ids": ["region.public.gamma"],
		"outcome_code": "damage_reduced",
		"batch_revision": 11,
	}


func _owner(source_revision: int = 23) -> AiCardBatchObservationSourceOwner:
	var owner := SOURCE_OWNER.new() as AiCardBatchObservationSourceOwner
	if not owner.configure_authorized_actor("ai.player.2", 2, source_revision):
		owner.free()
		return null
	return owner


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AI_CARD_BATCH_PRIVACY_TEST_PASS checks=%d" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("AI_CARD_BATCH_PRIVACY_TEST_FAIL: %s" % failure)
	print("AI_CARD_BATCH_PRIVACY_TEST_FAIL checks=%d failures=%d" % [_checks, _failures.size()])
	quit(1)
