extends SceneTree

const OBSERVATION = preload("res://scripts/semantic/ai_card_batch_observation_v1.gd")
const PLAN = preload("res://scripts/semantic/ai_card_batch_plan_v1.gd")
const TARGET = preload("res://scripts/semantic/card_batch_prebound_target_spec_v1.gd")
const SUBMISSION = preload("res://scripts/semantic/card_batch_submission_v1.gd")
const AUTHORED_RULE = preload("res://scripts/semantic/card_batch_authored_rule_v1.gd")
const INVENTORY = preload("res://scripts/semantic/card_batch_inventory_state_v1.gd")
const PURE = preload("res://scripts/semantic/card_batch_pure_data.gd")
const SOURCE_OWNER = preload("res://scripts/runtime/ai_card_batch_observation_source_owner.gd")
const REFERENCE_RUNTIME = preload("res://scripts/runtime/card_batch_reference_runtime.gd")
const PLANNER = preload("res://scripts/ai/ai_card_batch_planner_v1.gd")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_owner_authorized_observation()
	_test_deterministic_proactive_defense_plan()
	_test_shared_core_submission_and_lock_path()
	_test_three_inventory_pools()
	_test_resolution_phases_are_input_silent()
	_test_empty_window_plan()
	_test_plan_contract_rejects_bypass_and_rng()
	_test_source_has_no_random_entrypoint()
	_test_reference_boundary_is_not_production_wired()
	_finish()


func _test_owner_authorized_observation() -> void:
	var owner := _owner()
	var source := _source(OBSERVATION.PHASE_CARD_WINDOW_OPEN, _all_candidates())
	var observation := owner.issue_observation(source)
	_expect(not observation.is_empty(), "source owner issues an authorized observation")
	_expect(
		bool(OBSERVATION.validate(observation).get("valid", false)),
		"owner-issued observation validates"
	)
	_expect(PURE.is_pure_json_data(observation), "observation contains pure serializable data")
	_expect(
		str(observation.get("visibility_scope_id", "")) == "actor_private",
		"observation is actor-private"
	)
	var authority := observation.get("authority_receipt", {}) as Dictionary
	_expect(
		str(authority.get("authority_owner_id", "")) == OBSERVATION.AUTHORITY_OWNER_ID,
		"observation carries the dedicated source-owner authority"
	)
	var original_fingerprint := str(observation.get("observation_fingerprint", ""))
	(source["own_inventory"] as Dictionary)["actor_id"] = "ai.tampered"
	(source["legal_candidates"] as Array).clear()
	_expect(
		str(observation.get("viewer_actor_id", "")) == "ai.player.2"
			and str(observation.get("observation_fingerprint", "")) == original_fingerprint,
		"issued observation is detached from caller mutation"
	)
	var audit := owner.debug_snapshot()
	_expect(int(audit.get("issued_observation_count", 0)) == 1, "owner audits one issuance")
	_expect(int(audit.get("rng_consumption_count", -1)) == 0, "observation owner consumes no RNG")
	_expect(not bool(audit.get("stores_observation_payloads", true)), "owner stores no private payload")
	owner.free()


func _test_deterministic_proactive_defense_plan() -> void:
	var source := _source(OBSERVATION.PHASE_CARD_WINDOW_OPEN, _all_candidates())
	var defense_candidate := (source["legal_candidates"] as Array)[3] as Dictionary
	(defense_candidate["legal_target_options"] as Array).append(
		_target_option(
			"actor_private",
			TARGET.build(
				"facility",
				["facility.ai.player.2.beta"],
				13,
				"shield-slot.2",
				"protect",
				1,
				{"defense_kind": "shield", "duration_batches": 1}
			),
			1,
			1,
			1
		)
	)
	var owner := _owner()
	var observation_a := owner.issue_observation(source)
	var reordered := source.duplicate(true)
	(reordered["legal_candidates"] as Array).reverse()
	for candidate_variant in reordered["legal_candidates"] as Array:
		(candidate_variant as Dictionary)["legal_target_options"] = (
			(candidate_variant as Dictionary).get("legal_target_options", []) as Array
		).duplicate(true)
		((candidate_variant as Dictionary)["legal_target_options"] as Array).reverse()
	(reordered["own_inventory"] as Dictionary)["normal_cards"] = (
		(reordered["own_inventory"] as Dictionary).get("normal_cards", []) as Array
	).duplicate(true)
	((reordered["own_inventory"] as Dictionary)["normal_cards"] as Array).reverse()
	var observation_b := owner.issue_observation(reordered)
	_expect(
		str(observation_a.get("observation_fingerprint", ""))
			== str(observation_b.get("observation_fingerprint", "")),
		"candidate and inventory input order canonicalize deterministically"
	)
	var planner := PLANNER.new() as AiCardBatchPlannerV1
	var plan_a := planner.plan_submission_draft(observation_a)
	var plan_b := planner.plan_submission_draft(observation_b)
	_expect(bool(PLAN.validate(plan_a, observation_a).get("valid", false)), "AI draft plan validates")
	_expect(
		str(plan_a.get("decision_fingerprint", "")) == str(plan_b.get("decision_fingerprint", "")),
		"same authorized facts produce the same deterministic plan"
	)
	_expect(
		str(plan_a.get("decision_status", "")) == PLAN.STATUS_SUBMISSION_DRAFT_READY,
		"open window produces one shared submission draft"
	)
	var submission := plan_a.get("submission_draft", {}) as Dictionary
	_expect(
		bool(SUBMISSION.validate(submission, false).get("valid", false))
			and str(submission.get("locked_at_window_id", "")).is_empty(),
		"AI output is the shared Core-acceptable CardBatchSubmission draft"
	)
	_expect(
		str(submission.get("action_class", "")) == "proactive_defense",
		"visible threat causes proactive defense during the card window"
	)
	_expect(
		str(plan_a.get("requested_window_id", "")) == "card-window.7",
		"AI requests locking for the observed one-shot window"
	)
	var binding := submission.get("target_binding", {}) as Dictionary
	_expect(str(binding.get("mode_id", "")) == "protect", "AI prebinds the defense mode")
	_expect(int(binding.get("quantity", 0)) == 2, "AI prebinds the defense quantity")
	_expect(
		(binding.get("target_ids", []) as Array) == ["facility.ai.player.2.alpha"],
		"AI prebinds the selected target before resolution"
	)
	_expect(
		str(binding.get("target_invalidation_policy", "")) == "FIZZLE_NO_EFFECT",
		"AI uses the shared default target invalidation policy"
	)
	_expect(
		str(plan_a.get("lock_timing_id", "")) == PLAN.LOCK_TIMING_IMMEDIATE
			and int(plan_a.get("lock_remaining_phase_time_usec", -1)) == 18_000_000,
		"AI chooses and records an in-window lock timing"
	)
	_expect((plan_a.get("gameplay_intents", []) as Array).is_empty(), "planner creates no parallel intent contract")
	_expect(int(plan_a.get("rng_consumption_count", -1)) == 0, "deterministic planning consumes zero RNG")
	owner.free()


func _test_shared_core_submission_and_lock_path() -> void:
	var runtime := REFERENCE_RUNTIME.new() as CardBatchReferenceRuntime
	var actor_ids := ["human.player.0", "human.player.1", "ai.player.2"]
	var inventories := {
		"human.player.0": INVENTORY.empty("human.player.0"),
		"human.player.1": INVENTORY.empty("human.player.1"),
		"ai.player.2": _inventory(),
	}
	var begin := runtime.begin_initial_window(actor_ids, inventories, 0)
	_expect(bool(begin.get("accepted", false)), "shared Core opens the AI integration window")
	var state := runtime.state_snapshot()
	var source := _source(
		OBSERVATION.PHASE_CARD_WINDOW_OPEN,
		[_proactive_defense_candidate()]
	)
	source["batch_id"] = str(state.get("batch_id", ""))
	source["batch_revision"] = int(state.get("batch_revision", 0))
	source["window_id"] = str(state.get("window_id", ""))
	source["window_remaining_phase_time_usec"] = int(
		state.get("window_remaining_phase_time_usec", 0)
	)
	var owner := _owner(int(source.get("source_revision", 23)))
	var observation := owner.issue_observation(source)
	var planner := PLANNER.new() as AiCardBatchPlannerV1
	var plan := planner.plan_submission_draft(observation)
	var draft := plan.get("submission_draft", {}) as Dictionary
	var authored_rules := {
		str(draft.get("card_semantic_id", "")): AUTHORED_RULE.from_submission(draft),
	}
	var configure_rules := runtime.configure_authoritative_card_rules(authored_rules)
	_expect(
		bool(configure_rules.get("accepted", false)),
		"shared Core binds the same trusted authored rule selected by AI"
	)
	var submit := runtime.submit_or_replace_draft(draft)
	_expect(bool(submit.get("accepted", false)), "AI draft enters the exact shared Core submission port")
	var submitted_state := runtime.state_snapshot()
	_expect(
		(submitted_state.get("submissions_by_actor", {}) as Dictionary).get(
			"ai.player.2",
			{}
		) == draft,
		"shared Core owns the submitted AI draft without a parallel path"
	)
	var lock := runtime.lock_window()
	_expect(bool(lock.get("accepted", false)), "shared Core, not AI, locks the one-shot window")
	var locked_state := runtime.state_snapshot()
	var locked_ids := locked_state.get("locked_submission_ids", []) as Array
	var locked_by_id := locked_state.get("locked_submissions_by_id", {}) as Dictionary
	var locked := (
		locked_by_id.get(str(locked_ids[0]), {}) as Dictionary
		if not locked_ids.is_empty()
		else {}
	)
	_expect(
		bool(SUBMISSION.validate(locked, true).get("valid", false))
			and str(locked.get("submission_id", "")) == str(draft.get("submission_id", ""))
			and str(locked.get("locked_at_window_id", "")) == str(source.get("window_id", "")),
		"Core lock produces the authoritative locked copy of the exact AI draft"
	)
	_expect(
		not bool(runtime.submit_or_replace_draft(draft).get("accepted", true)),
		"the same shared Core port rejects AI input after window lock"
	)
	owner.free()
	runtime.free()


func _test_three_inventory_pools() -> void:
	var owner := _owner()
	var planner := PLANNER.new() as AiCardBatchPlannerV1
	var expected := [
		["normal_hand", _normal_attack_candidate()],
		["commodity_inventory", _commodity_candidate()],
		["bound_action_inventory", _bound_action_candidate()],
	]
	for row in expected:
		var source := _source(
			OBSERVATION.PHASE_CARD_WINDOW_OPEN,
			[(row as Array)[1]]
		)
		var observation := owner.issue_observation(source)
		var plan := planner.plan_submission_draft(observation)
		var submission := plan.get("submission_draft", {}) as Dictionary
		_expect(not observation.is_empty(), "%s candidate is owner-authorized" % str((row as Array)[0]))
		_expect(
			str(plan.get("selected_source_pool", "")) == str((row as Array)[0]),
			"planner understands %s" % str((row as Array)[0])
		)
		_expect(
			str(submission.get("source_pool", "")) == str((row as Array)[0])
				and bool(SUBMISSION.validate(submission, false).get("valid", false)),
			"%s emits the shared Core draft shape" % str((row as Array)[0])
		)
	_expect(
		int((planner.audit_snapshot()).get("rng_consumption_count", -1)) == 0,
		"three-pool planning remains RNG-free"
	)
	owner.free()


func _test_resolution_phases_are_input_silent() -> void:
	var owner := _owner()
	var planner := PLANNER.new() as AiCardBatchPlannerV1
	for phase in OBSERVATION.PHASES:
		if phase == OBSERVATION.PHASE_CARD_WINDOW_OPEN:
			continue
		var source := _source(phase, [])
		if phase in [
			"RESOLUTION_ORDER_REVEAL",
			"CARD_RESOLUTION_ACTIVE",
			"CARD_EFFECT_COMMIT",
			"CARD_AFTERMATH",
			"BATCH_AFTERMATH",
			"BATCH_COMPLETE",
		]:
			source["public_resolution_receipts"] = [_public_receipt()]
		var observation := owner.issue_observation(source)
		var plan := planner.plan_submission_draft(observation)
		_expect(not observation.is_empty(), "%s observation remains readable" % phase)
		_expect(
			(observation.get("own_inventory", {}) as Dictionary).is_empty(),
			"%s exposes no private inventory outside the decision window" % phase
		)
		_expect(
			str(plan.get("decision_status", "")) == PLAN.STATUS_GAMEPLAY_INPUT_DISABLED,
			"%s disables AI gameplay decisions" % phase
		)
		_expect(
			(plan.get("submission_draft", {}) as Dictionary).is_empty(),
			"%s emits zero card submissions" % phase
		)
		_expect(
			(plan.get("gameplay_intents", []) as Array).is_empty(),
			"%s emits zero gameplay intents" % phase
		)
		_expect(
			int(plan.get("rng_consumption_count", -1)) == 0,
			"%s consumes zero RNG" % phase
		)
	var hostile_resolution_source := _source(
		"CARD_RESOLUTION_ACTIVE",
		[_proactive_defense_candidate()]
	)
	_expect(
		owner.issue_observation(hostile_resolution_source).is_empty(),
		"source owner refuses legal candidates during resolution"
	)
	var private_resolution_source := _source("CARD_RESOLUTION_ACTIVE", [])
	private_resolution_source["own_inventory"] = _inventory()
	_expect(
		owner.issue_observation(private_resolution_source).is_empty(),
		"resolution observation refuses even the viewer's private inventory"
	)
	owner.free()


func _test_empty_window_plan() -> void:
	var owner := _owner()
	var observation := owner.issue_observation(
		_source(OBSERVATION.PHASE_CARD_WINDOW_OPEN, [])
	)
	var planner := PLANNER.new() as AiCardBatchPlannerV1
	var plan := planner.plan_submission_draft(observation)
	_expect(
		str(plan.get("decision_status", "")) == PLAN.STATUS_NO_LEGAL_SUBMISSION,
		"empty open window produces a deterministic pass"
	)
	_expect((plan.get("submission_draft", {}) as Dictionary).is_empty(), "pass submits no card")
	_expect((plan.get("gameplay_intents", []) as Array).is_empty(), "pass emits no action intent")
	owner.free()


func _test_plan_contract_rejects_bypass_and_rng() -> void:
	var owner := _owner()
	var observation := owner.issue_observation(
		_source(OBSERVATION.PHASE_CARD_WINDOW_OPEN, [_normal_attack_candidate()])
	)
	var planner := PLANNER.new() as AiCardBatchPlannerV1
	var plan := planner.plan_submission_draft(observation)
	var rng_tamper := plan.duplicate(true)
	rng_tamper["rng_consumption_count"] = 1
	_reseal_plan(rng_tamper)
	_expect(
		str(PLAN.validate(rng_tamper, observation).get("reason_code", ""))
			== "ai_card_batch_plan_rng_consumption_invalid",
		"plan contract rejects hidden RNG consumption"
	)
	var intent_tamper := plan.duplicate(true)
	intent_tamper["gameplay_intents"] = [{"semantic_action_id": "v07.parallel.gameplay-bypass"}]
	_reseal_plan(intent_tamper)
	_expect(
		str(PLAN.validate(intent_tamper, observation).get("reason_code", ""))
			== "ai_card_batch_plan_bypasses_shared_submission",
		"plan contract rejects a parallel gameplay-intent bypass"
	)
	var prelocked := plan.duplicate(true)
	(prelocked["submission_draft"] as Dictionary)["locked_at_window_id"] = "card-window.7"
	_reseal_plan(prelocked)
	_expect(
		not bool(PLAN.validate(prelocked, observation).get("valid", false)),
		"plan contract rejects AI-authored lock state"
	)
	var unobserved_card := plan.duplicate(true)
	var unobserved_draft := unobserved_card["submission_draft"] as Dictionary
	var defense_candidate := _proactive_defense_candidate()
	unobserved_draft["card_instance_id"] = defense_candidate.get("card_instance_id")
	unobserved_draft["card_semantic_id"] = defense_candidate.get("card_semantic_id")
	unobserved_draft["action_class"] = defense_candidate.get("action_class")
	unobserved_draft["target_binding"] = (
		(defense_candidate.get("legal_target_options", []) as Array)[0] as Dictionary
	).get("target_binding", {})
	unobserved_card["selected_card_instance_id"] = unobserved_draft.get("card_instance_id")
	unobserved_card["selected_source_pool"] = unobserved_draft.get("source_pool")
	unobserved_card["selected_target_binding_fingerprint"] = TARGET.fingerprint(
		unobserved_draft.get("target_binding", {})
	)
	_reseal_plan(unobserved_card)
	_expect(
		str(PLAN.validate(unobserved_card, observation).get("reason_code", ""))
			== "ai_card_batch_plan_candidate_binding_invalid",
		"re-sealed plan cannot choose an owned card absent from the observation candidates"
	)
	var unobserved_target := plan.duplicate(true)
	var target_tampered_draft := unobserved_target["submission_draft"] as Dictionary
	target_tampered_draft["target_binding"] = TARGET.build(
		"facility",
		["facility.public.unobserved"],
		44,
		"",
		"pressure",
		1,
		{"effect_kind": "market_pressure"}
	)
	unobserved_target["selected_target_binding_fingerprint"] = TARGET.fingerprint(
		target_tampered_draft.get("target_binding", {})
	)
	_reseal_plan(unobserved_target)
	_expect(
		str(PLAN.validate(unobserved_target, observation).get("reason_code", ""))
			== "ai_card_batch_plan_candidate_binding_invalid",
		"re-sealed plan cannot choose a target absent from the observed legal options"
	)
	owner.free()


func _test_source_has_no_random_entrypoint() -> void:
	var source := FileAccess.get_file_as_string(
		"res://scripts/ai/ai_card_batch_planner_v1.gd"
	)
	for forbidden in [
		"RandomNumberGenerator",
		"randi(",
		"randf(",
		"rand_from_seed(",
		"RunRngService",
	]:
		_expect(not source.contains(forbidden), "planner source excludes %s" % forbidden)


func _test_reference_boundary_is_not_production_wired() -> void:
	var scoped_paths := [
		"res://scripts/semantic/ai_card_batch_observation_v1.gd",
		"res://scripts/semantic/ai_card_batch_plan_v1.gd",
		"res://scripts/runtime/ai_card_batch_observation_source_owner.gd",
		"res://scripts/ai/ai_card_batch_planner_v1.gd",
	]
	for path in scoped_paths:
		var source := FileAccess.get_file_as_string(path)
		for forbidden in [
			"scripts/main.gd",
			"scenes/main.tscn",
			"GameRuntimeCoordinator",
			"RuntimeLoop",
			"AiRuntimeController",
			"V0.6",
		]:
			_expect(
				not source.contains(forbidden),
				"%s remains detached from %s" % [path, forbidden]
			)
	var production_scene := FileAccess.get_file_as_string("res://scenes/main.tscn")
	_expect(
		not production_scene.contains("AiCardBatchReferenceBench")
			and not production_scene.contains("ai_card_batch_observation_source_owner.gd")
			and not production_scene.contains("ai_card_batch_planner_v1.gd"),
		"V0.7 reference AI is not connected to the V0.6 production scene"
	)


func _source(phase: String, candidates: Array) -> Dictionary:
	return {
		"schema_version": OBSERVATION.SCHEMA_VERSION,
		"ruleset_id": OBSERVATION.RULESET_ID,
		"viewer_actor_id": "ai.player.2",
		"viewer_seat_index": 2,
		"visibility_scope_id": OBSERVATION.VISIBILITY_SCOPE_ID,
		"batch_id": "card-batch.4",
		"batch_revision": 11,
		"window_id": "card-window.7",
		"window_remaining_phase_time_usec": 18_000_000 if phase == OBSERVATION.PHASE_CARD_WINDOW_OPEN else 0,
		"source_revision": 23,
		"phase": phase,
		"own_inventory": _inventory() if phase == OBSERVATION.PHASE_CARD_WINDOW_OPEN else {},
		"legal_candidates": candidates.duplicate(true),
		"public_resolution_receipts": [],
	}


func _inventory() -> Dictionary:
	var inventory := INVENTORY.empty("ai.player.2")
	inventory["normal_cards"] = [
		{
			"card_instance_id": "card.ai.2.attack.1",
			"card_semantic_id": "v07.card.market-interference",
			"source_revision": 23,
		},
		{
			"card_instance_id": "card.ai.2.defense.1",
			"card_semantic_id": "v07.card.proactive-shield",
			"source_revision": 23,
		},
	]
	inventory["commodity_cards"] = [
		{
			"card_instance_id": "commodity.ai.2.energy.1",
			"card_semantic_id": "v07.commodity.energy.level-2",
			"commodity_id": "energy",
			"commodity_level": 2,
			"source_revision": 23,
		},
	]
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


func _all_candidates() -> Array:
	return [
		_normal_attack_candidate(),
		_commodity_candidate(),
		_bound_action_candidate(),
		_proactive_defense_candidate(),
	]


func _normal_attack_candidate() -> Dictionary:
	return _candidate(
		"card.ai.2.attack.1",
		"v07.card.market-interference",
		"normal_hand",
		"batch_interference",
		3,
		1,
		_target_option(
			"public",
			TARGET.build(
				"facility",
				["facility.public.rival.alpha"],
				31,
				"",
				"pressure",
				1,
				{"effect_kind": "market_pressure"}
			),
			5,
			0,
			1
		)
	)


func _proactive_defense_candidate() -> Dictionary:
	return _candidate(
		"card.ai.2.defense.1",
		"v07.card.proactive-shield",
		"normal_hand",
		"proactive_defense",
		2,
		2,
		_target_option(
			"actor_private",
			TARGET.build(
				"facility",
				["facility.ai.player.2.alpha"],
				12,
				"shield-slot.1",
				"protect",
				2,
				{
					"defense_kind": "shield",
					"duration_batches": 1,
					"prevention_count": 2,
				}
			),
			4,
			10,
			2
		)
	)


func _commodity_candidate() -> Dictionary:
	return _candidate(
		"commodity.ai.2.energy.1",
		"v07.commodity.energy.level-2",
		"commodity_inventory",
		"commodity_card",
		4,
		1,
		_target_option(
			"actor_private",
			TARGET.build(
				"factory",
				["factory.ai.player.2.beta"],
				8,
				"commodity-slot.2",
				"install",
				2,
				{"commodity_id": "energy", "facility_kind": "factory"}
			),
			4,
			0,
			3
		)
	)


func _bound_action_candidate() -> Dictionary:
	return _candidate(
		"bound-action.ai.2.monster.1",
		"v07.bound.monster-roar",
		"bound_action_inventory",
		"batch_action",
		4,
		2,
		_target_option(
			"public",
			TARGET.build(
				"region",
				["region.public.gamma"],
				18,
				"",
				"roar",
				1,
				{"effect_kind": "monster_pressure"}
			),
			4,
			2,
			2
		)
	)


func _candidate(
	card_instance_id: String,
	card_semantic_id: String,
	source_pool: String,
	action_class: String,
	base_utility: int,
	urgency: int,
	target_option: Dictionary
) -> Dictionary:
	return {
		"card_instance_id": card_instance_id,
		"card_semantic_id": card_semantic_id,
		"source_pool": source_pool,
		"source_revision": 23,
		"action_class": action_class,
		"order_priority": 10,
		"submission_sequence": 0,
		"base_utility": base_utility,
		"urgency": urgency,
		"legal_target_options": [target_option],
	}


func _target_option(
	visibility_scope_id: String,
	target_binding: Dictionary,
	target_value: int,
	threat_level: int,
	synergy_value: int
) -> Dictionary:
	return {
		"visibility_scope_id": visibility_scope_id,
		"target_binding": target_binding,
		"target_value": target_value,
		"threat_level": threat_level,
		"synergy_value": synergy_value,
	}


func _public_receipt() -> Dictionary:
	return {
		"receipt_id": "card-resolution-receipt.public.1",
		"result_kind": "effect_committed",
		"public_target_ids": ["region.public.gamma"],
		"outcome_code": "damage_reduced",
		"batch_revision": 11,
	}


func _reseal_plan(plan: Dictionary) -> void:
	var decision_seed := {
		"observation_fingerprint": str(plan.get("observation_fingerprint", "")),
		"decision_status": str(plan.get("decision_status", "")),
		"submission_draft": plan.get("submission_draft", {}),
	}
	plan["decision_id"] = "ai-card-batch-decision:%s" % (
		PURE.stable_fingerprint(decision_seed).left(24)
	)
	var copy := plan.duplicate(true)
	copy["decision_fingerprint"] = ""
	plan["decision_fingerprint"] = PURE.stable_fingerprint(copy)


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
		print("AI_CARD_BATCH_SEMANTICS_TEST_PASS checks=%d" % _checks)
		quit(0)
		return
	for failure in _failures:
		push_error("AI_CARD_BATCH_SEMANTICS_TEST_FAIL: %s" % failure)
	print("AI_CARD_BATCH_SEMANTICS_TEST_FAIL checks=%d failures=%d" % [_checks, _failures.size()])
	quit(1)
