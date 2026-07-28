extends SceneTree

const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const OFFER := preload("res://scripts/semantic/game_action_offer_v1.gd")
const INTENT := preload("res://scripts/semantic/game_action_intent_v1.gd")
const RECEIPT := preload("res://scripts/semantic/game_action_receipt_v1.gd")
const CARD_BINDING := preload("res://scripts/semantic/game_action_card_binding_v1.gd")
const AI_CAPABILITY := preload(
	"res://scripts/runtime/game_action_ai_submission_capability.gd"
)
const GLOBAL_REGISTRY_PATH := "res://docs/semantic/global_three_layer_semantic_registry.json"
const REGISTRY_REQUIRED_DOMAIN_FIELDS := [
	"domain_id", "current_runtime_version", "target_rule_version",
	"core_authority_owner", "core_rule_schema", "core_state_schema",
	"core_command_port", "core_receipt_schema", "ai_observation_schema",
	"ai_candidate_schema", "ai_intent_schema", "ai_outcome_schema",
	"ai_information_boundary", "player_public_projection",
	"player_private_projection", "player_intent_schema", "player_feedback_schema",
	"visibility_policy", "rng_policy", "save_owner", "replay_identity",
	"main_gd_dependencies", "legacy_authority", "old_write_paths",
	"core_semantics_status", "ai_semantics_status", "player_semantics_status",
	"save_replay_status", "main_free_status", "cutover_status",
	"core_semantics_ready", "ai_semantics_ready", "player_semantics_ready",
	"focused_tests", "production_scene_or_bench", "known_blockers",
	"next_atomic_boundary",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_offer_contract()
	_test_intent_contract()
	_test_session_id_contract()
	_test_offer_intent_binding()
	_test_receipt_contract()
	_test_forbidden_wire_values()
	_test_card_binding()
	_test_ai_capability_is_out_of_band()
	_test_global_three_layer_registry_contract()
	_finish()


func _test_offer_contract() -> void:
	var source := _offer_input()
	var offer := OFFER.build(source)
	_expect(not offer.is_empty(), "closed action offer builds")
	_expect(
		bool(OFFER.validation_report(offer).get("valid", false)),
		"sealed action offer validates"
	)
	_expect(WIRE.is_closed_data(offer), "action offer is closed pure data")
	_expect(
		OFFER.target_ids(offer) == {
			"card_instance_id": "card.instance.0123456789abcdef01234567",
			"hand_slot_id": "hand.slot.0",
		},
		"offer exposes only stable target bindings"
	)
	source["source_revision"] = 99
	_expect(int(offer.get("source_revision", -1)) == 7, "offer is detached from input")

	var unknown := _offer_input()
	unknown["semantic_action_id"] = "card.unknown"
	_expect(OFFER.build(unknown).is_empty(), "unknown action offer fails closed")
	var wrong_family := _offer_input()
	wrong_family["action_family_id"] = "session"
	_expect(OFFER.build(wrong_family).is_empty(), "action family mismatch fails closed")
	var disabled_without_reason := _offer_input()
	disabled_without_reason["legality_state"] = "disabled"
	_expect(
		OFFER.build(disabled_without_reason).is_empty(),
		"disabled offer requires a stable reason"
	)
	var invalid_scope := _offer_input()
	(invalid_scope["public_or_private_target_spec"] as Dictionary)[
		"visibility_scope_id"
	] = "core-private"
	_expect(OFFER.build(invalid_scope).is_empty(), "unknown target visibility fails closed")
	var extra := _offer_input()
	extra["payload"] = {}
	_expect(OFFER.build(extra).is_empty(), "offer rejects an additional payload bag")


func _test_intent_contract() -> void:
	var source := _card_play_intent_input("human", "human_click")
	var intent := INTENT.build(source)
	_expect(not intent.is_empty(), "closed human action intent builds")
	_expect(
		bool(INTENT.validation_report(intent).get("valid", false)),
		"sealed action intent validates"
	)
	_expect(WIRE.is_closed_data(intent), "action intent is closed pure data")
	_expect(
		INTENT.request_fingerprint(intent) == str(intent.get("intent_fingerprint", "")),
		"intent fingerprint is the request journal fingerprint"
	)
	_expect(
		str(INTENT.action_contract(INTENT.ACTION_CARD_PLAY).get("action_family_id", ""))
			== INTENT.FAMILY_CARD_PLAY,
		"one frozen action contract supplies family and payload schemas"
	)
	source["target_ids"] = {}
	_expect(
		str((intent.get("target_ids", {}) as Dictionary).get("hand_slot_id", ""))
			== "hand.slot.0",
		"intent is detached from mutable caller data"
	)

	var ai_intent := INTENT.build(_card_play_intent_input("ai", "ai_decision"))
	_expect(not ai_intent.is_empty(), "AI uses the same card-play intent contract")
	var system_intent := _end_turn_intent_input("system", "system_default")
	_expect(not INTENT.build(system_intent).is_empty(), "system default uses its declared source")
	for mismatch in [
		["human", "ai_decision"],
		["human", "system_default"],
		["ai", "human_click"],
		["system", "human_quick_action"],
	]:
		_expect(
			INTENT.build(_card_play_intent_input(str(mismatch[0]), str(mismatch[1]))).is_empty(),
			"actor/submission mismatch fails closed: %s/%s" % mismatch
		)

	var reorder := _base_intent_input(
		INTENT.ACTION_CARD_GROUP_REORDER,
		"human",
		"human_click"
	)
	reorder["target_ids"] = {"resolution_id": "card.resolution.17"}
	reorder["parameters"] = {"direction": -1}
	_expect(not INTENT.build(reorder).is_empty(), "group reorder accepts direction minus one")
	reorder["parameters"] = {"direction": 0}
	_expect(INTENT.build(reorder).is_empty(), "group reorder rejects zero direction")
	var quote := _base_intent_input(
		INTENT.ACTION_DISTRICT_SUPPLY_QUOTE,
		"human",
		"human_click"
	)
	quote["target_ids"] = {
		"card_id": "facility.market.energy.rank_1",
		"region_id": "region.beta",
	}
	_expect(not INTENT.build(quote).is_empty(), "district quote uses stable card and region targets")
	var purchase := quote.duplicate(true)
	purchase["request_id"] = "request.district-purchase"
	purchase["semantic_action_id"] = INTENT.ACTION_DISTRICT_SUPPLY_PURCHASE
	(purchase["target_ids"] as Dictionary)["quote_id"] = "market-quote.17"
	_expect(not INTENT.build(purchase).is_empty(), "district purchase binds the locked quote with stable card and region targets")
	var close := _base_intent_input(
		INTENT.ACTION_DISTRICT_SUPPLY_CLOSE,
		"human",
		"human_click"
	)
	_expect(not INTENT.build(close).is_empty(), "district supply close carries no hidden target payload")
	var open_payload := _card_play_intent_input("human", "human_click")
	(open_payload["parameters"] as Dictionary)["method_name"] = "queue_card"
	_expect(INTENT.build(open_payload).is_empty(), "intent rejects undeclared parameter fields")
	var unknown := _card_play_intent_input("human", "human_click")
	unknown["semantic_action_id"] = "unknown.action"
	_expect(INTENT.build(unknown).is_empty(), "unknown semantic action fails closed")


func _test_session_id_contract() -> void:
	var production_session_id := "session:full-run:900626424"
	_expect(
		WIRE.is_session_id(production_session_id),
		"production session namespace is a valid bounded session identity"
	)
	var production_intent := _card_play_intent_input("human", "human_click")
	(production_intent["actor_authorization"] as Dictionary)["session_id"] = production_session_id
	_expect(
		not INTENT.build(production_intent).is_empty(),
		"action authorization accepts the production session identity"
	)
	for invalid_session_id in [
		"",
		" session:full-run:900626424",
		"session:full run:900626424",
		"res://scripts/session.gd",
		"scripts/session.gd",
		"session.gd",
		"session\\full-run\\900626424",
		"session:full-run:900626424()",
		"session::full-run:900626424",
		"session:full-run:900626424:",
	]:
		_expect(
			not WIRE.is_session_id(invalid_session_id),
			"session identity rejects unsafe value: %s" % invalid_session_id
		)
		var invalid_intent := _card_play_intent_input("human", "human_click")
		(invalid_intent["actor_authorization"] as Dictionary)["session_id"] = invalid_session_id
		_expect(
			INTENT.build(invalid_intent).is_empty(),
			"action authorization rejects unsafe session identity"
		)
	_expect(
		not WIRE.is_session_id("session" + "a".repeat(160)),
		"session identity is length bounded"
	)


func _test_offer_intent_binding() -> void:
	var offer := OFFER.build(_offer_input())
	var intent := INTENT.build(_card_play_intent_input("human", "human_drag"))
	_expect(OFFER.accepts_intent(offer, intent), "available offer accepts matching revision intent")
	var retargeted_source := _card_play_intent_input("human", "human_drag")
	(retargeted_source["target_ids"] as Dictionary)["card_instance_id"] = "card.instance.ffffffffffffffffffffffff"
	_expect(
		not OFFER.accepts_intent(offer, INTENT.build(retargeted_source)),
		"offer rejects a rewritten required target binding"
	)
	var optional_region_source := _card_play_intent_input("human", "human_drag")
	(optional_region_source["target_ids"] as Dictionary)["region_id"] = "region.beta"
	_expect(
		OFFER.accepts_intent(offer, INTENT.build(optional_region_source)),
		"offer permits a schema-declared optional drag target while preserving required bindings"
	)
	var bound_optional_offer_source := _offer_input()
	(bound_optional_offer_source["public_or_private_target_spec"] as Dictionary)["target_bindings"].append({
		"target_role_id": "region_id",
		"target_id": "region.alpha",
	})
	var bound_optional_offer := OFFER.build(bound_optional_offer_source)
	_expect(
		not OFFER.accepts_intent(bound_optional_offer, INTENT.build(optional_region_source)),
		"offer rejects rewriting a schema-optional target once the offer has bound it"
	)
	var stale_source := _card_play_intent_input("human", "human_drag")
	stale_source["source_revision"] = 8
	_expect(
		not OFFER.accepts_intent(offer, INTENT.build(stale_source)),
		"stale offer revision fails the source binding"
	)
	var disabled_source := _offer_input()
	disabled_source["legality_state"] = "disabled"
	disabled_source["disabled_reason_id"] = "card-play-blocked"
	_expect(
		not OFFER.accepts_intent(OFFER.build(disabled_source), intent),
		"disabled offer cannot authorize an intent"
	)


func _test_receipt_contract() -> void:
	var intent := INTENT.build(_card_play_intent_input("human", "human_click"))
	var source := _receipt_input(intent)
	var receipt := RECEIPT.build(source)
	_expect(not receipt.is_empty(), "closed authoritative receipt builds")
	_expect(
		bool(RECEIPT.validation_report(receipt).get("valid", false)),
		"sealed authoritative receipt validates"
	)
	_expect(WIRE.is_closed_data(receipt), "action receipt is closed pure data")
	_expect(
		RECEIPT.request_binding_matches(receipt, intent),
		"receipt binds request id, action id, and request fingerprint"
	)
	source["authoritative_revision"] = 999
	_expect(
		int(receipt.get("authoritative_revision", -1)) == 8,
		"receipt is detached from input"
	)

	var replay := RECEIPT.replay_copy(receipt)
	_expect(
		bool(replay.get("idempotent_replay", false))
			and replay.get("committed_effect_refs") == receipt.get("committed_effect_refs")
			and str(replay.get("request_fingerprint", ""))
				== str(receipt.get("request_fingerprint", "")),
		"idempotent replay preserves the authoritative lineage without a new effect"
	)
	_expect(RECEIPT.request_binding_matches(replay, intent), "replay remains request-bound")

	var other_intent_source := _card_play_intent_input("human", "human_click")
	other_intent_source["request_id"] = "request.action.2"
	var other_intent := INTENT.build(other_intent_source)
	_expect(
		not RECEIPT.request_binding_matches(receipt, other_intent),
		"receipt cannot be rebound to a different request"
	)

	var collision := _receipt_input(intent)
	collision["accepted"] = false
	collision["reason_id"] = "request-id-collision"
	collision["committed_effect_refs"] = []
	collision["public_projection_ref"] = "none"
	collision["viewer_private_projection_ref"] = "none"
	collision["request_id_collision"] = true
	collision["refresh_scope"] = "none"
	var collision_receipt := RECEIPT.build(collision)
	_expect(not collision_receipt.is_empty(), "request collision has a closed rejection receipt")
	_expect(
		RECEIPT.replay_copy(collision_receipt).is_empty(),
		"collision receipt cannot masquerade as idempotent replay"
	)
	var replay_collision := collision.duplicate(true)
	replay_collision["idempotent_replay"] = true
	_expect(RECEIPT.build(replay_collision).is_empty(), "replay and collision are exclusive")
	var rejected_effect := collision.duplicate(true)
	rejected_effect["request_id_collision"] = false
	rejected_effect["committed_effect_refs"] = ["effect.illegal"]
	_expect(RECEIPT.build(rejected_effect).is_empty(), "rejection cannot claim committed effects")
	var missing_request_fingerprint := _receipt_input(intent)
	missing_request_fingerprint.erase("request_fingerprint")
	_expect(
		RECEIPT.build(missing_request_fingerprint).is_empty(),
		"receipt requires the request fingerprint"
	)
	var accepted_without_commit := _receipt_input(intent)
	accepted_without_commit["committed_effect_refs"] = []
	_expect(
		RECEIPT.build(accepted_without_commit).is_empty(),
		"an accepted action receipt requires explicit committed effect evidence"
	)


func _test_forbidden_wire_values() -> void:
	var runtime_node := Node.new()
	var forbidden_values: Array = [
		runtime_node,
		RefCounted.new(),
		Resource.new(),
		Callable(self, "_run"),
		NodePath("Runtime/GameScreen"),
		Vector2(10.0, 20.0),
		1.25,
	]
	for value in forbidden_values:
		var offer := _offer_input()
		(offer["cost_spec"] as Dictionary)["amount_units"] = value
		_expect(
			OFFER.build(offer).is_empty(),
			"offer rejects forbidden wire kind %s" % type_string(typeof(value))
		)
		var intent := _card_play_intent_input("human", "human_click")
		(intent["actor_authorization"] as Dictionary)["authorization_proof_ref"] = value
		_expect(
			INTENT.build(intent).is_empty(),
			"intent rejects forbidden wire kind %s" % type_string(typeof(value))
		)
		var valid_intent := INTENT.build(_card_play_intent_input("human", "human_click"))
		var receipt := _receipt_input(valid_intent)
		receipt["public_projection_ref"] = value
		_expect(
			RECEIPT.build(receipt).is_empty(),
			"receipt rejects forbidden wire kind %s" % type_string(typeof(value))
		)
	runtime_node.free()


func _test_card_binding() -> void:
	var card := {
		"runtime_instance_id": "runtime:private:card:17",
		"machine": {
			"card_id": "facility.fusion-hub.rank-1",
			"family_id": "facility.fusion-hub",
			"rank": 1,
		},
	}
	var first := CARD_BINDING.private_instance_ref(card, 0)
	var second := CARD_BINDING.private_instance_ref(card.duplicate(true), 0)
	_expect(
		WIRE.is_stable_id(first) and first == second,
		"private card binding is stable deterministic data"
	)
	_expect(
		not first.contains("runtime") and not first.contains("fusion"),
		"private binding does not disclose internal instance or card identity"
	)
	_expect(
		CARD_BINDING.matches_private_instance_ref(card, 0, first),
		"authoritative source can revalidate the private binding"
	)
	_expect(
		CARD_BINDING.private_instance_ref(card, 1) != first,
		"hand-slot change produces a different binding"
	)
	_expect(
		CARD_BINDING.hand_slot_ref(0) == "hand.slot.0"
			and CARD_BINDING.resolution_ref(17) == "card.resolution.17",
		"numeric presentation inputs become stable semantic references"
	)
	var integral_float_rank := card.duplicate(true)
	(integral_float_rank["machine"] as Dictionary)["rank"] = 1.0
	_expect(
		CARD_BINDING.private_instance_ref(integral_float_rank, 0) == first,
		"integral JSON card rank normalizes to the same closed integer binding"
	)
	var invalid_rank := card.duplicate(true)
	(invalid_rank["machine"] as Dictionary)["rank"] = 1.5
	_expect(
		CARD_BINDING.private_instance_ref(invalid_rank, 0).is_empty(),
		"card binding refuses fractional gameplay identity"
	)
	var runtime_object := card.duplicate(true)
	(runtime_object["machine"] as Dictionary)["card_id"] = RefCounted.new()
	_expect(
		CARD_BINDING.private_instance_ref(runtime_object, 0).is_empty(),
		"card binding refuses runtime object identity"
	)


func _test_ai_capability_is_out_of_band() -> void:
	var capability := AI_CAPABILITY.new()
	_expect(not WIRE.is_closed_data(capability), "opaque AI capability cannot enter action wire")
	_expect(not capability.has_method("to_dictionary"), "AI capability has no serialization API")
	_expect(capability.bind_owner_nonce(77), "composition owner binds capability exactly once")
	_expect(capability.is_bound() and capability.matches_owner_nonce(77), "bound owner validates capability")
	_expect(not capability.bind_owner_nonce(88), "capability cannot be rebound")
	_expect(not capability.matches_owner_nonce(88), "wrong owner nonce is rejected")
	var forged := AI_CAPABILITY.new()
	_expect(forged != capability and not forged.matches_owner_nonce(77), "new object cannot forge bound capability")


func _test_global_three_layer_registry_contract() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GLOBAL_REGISTRY_PATH))
	var registry: Dictionary = parsed if parsed is Dictionary else {}
	_expect(not registry.is_empty(), "global three-layer semantic registry is valid JSON")
	_expect(str(registry.get("registry_id", "")) == "global_three_layer_semantic_registry", "one canonical global semantic registry is identified")
	_expect(str(registry.get("current_production_runtime_ruleset", "")) == "V0.6" and str(registry.get("target_development_constitution", "")) == "V0.7" and not bool(registry.get("full_v0_7_runtime_cutover", true)), "registry separates current V0.6 runtime from target V0.7 constitution")
	var vocabulary: Array = registry.get("status_vocabulary", []) if registry.get("status_vocabulary", []) is Array else []
	var domains: Array = registry.get("domains", []) if registry.get("domains", []) is Array else []
	var domain_ids: Array[String] = []
	var complete_domain_count := 0
	var core_ready_count := 0
	var card_group_domain: Dictionary = {}
	var fields_complete := true
	var statuses_valid := true
	var ready_flags_consistent := true
	for domain_variant in domains:
		if not (domain_variant is Dictionary):
			fields_complete = false
			continue
		var domain := domain_variant as Dictionary
		var domain_id := str(domain.get("domain_id", ""))
		if domain_id.is_empty() or domain_ids.has(domain_id):
			fields_complete = false
		domain_ids.append(domain_id)
		if domain_id == "card_group_resolution":
			card_group_domain = domain
		for field in REGISTRY_REQUIRED_DOMAIN_FIELDS:
			fields_complete = fields_complete and domain.has(field)
		for status_field in ["core_semantics_status", "ai_semantics_status", "player_semantics_status", "save_replay_status", "main_free_status", "cutover_status"]:
			statuses_valid = statuses_valid and vocabulary.has(str(domain.get(status_field, "")))
		var all_layers_ready := bool(domain.get("core_semantics_ready", false)) and bool(domain.get("ai_semantics_ready", false)) and bool(domain.get("player_semantics_ready", false))
		ready_flags_consistent = ready_flags_consistent and (str(domain.get("core_semantics_status", "")) == "THREE_LAYER_READY") == all_layers_ready
		if all_layers_ready:
			complete_domain_count += 1
		if bool(domain.get("core_semantics_ready", false)):
			core_ready_count += 1
	var summary: Dictionary = registry.get("summary", {}) if registry.get("summary", {}) is Dictionary else {}
	_expect(domains.size() == 31 and int(summary.get("registered_domain_count", -1)) == domains.size(), "registry inventories exactly 31 required semantic domains")
	_expect(fields_complete and domain_ids.size() == domains.size(), "every semantic domain has the closed required field set and a unique identity")
	_expect(statuses_valid, "every semantic status uses the one approved vocabulary")
	_expect(ready_flags_consistent, "THREE_LAYER_READY is claimed only when core, AI, and player readiness are all true")
	_expect(core_ready_count == int(summary.get("core_ready_domain_count", -1)) and complete_domain_count == int(summary.get("global_three_layer_ready_domain_count", -1)), "registry summary readiness counts are derived from domain truth")
	_expect(complete_domain_count == 2 and domain_ids.has("player_action_routing") and domain_ids.has("card_group_resolution") and not bool(summary.get("global_three_layer_complete", true)), "player-action production routing and card-batch reference semantics are three-layer ready; global completion remains false")
	_expect(str(card_group_domain.get("current_runtime_version", "")) == "V0.6" and not bool(registry.get("full_v0_7_runtime_cutover", true)), "card-batch reference readiness does not replace the V0.6 production runtime")
	_expect(str(card_group_domain.get("legacy_authority", "")).contains("V0.6") and str(card_group_domain.get("known_blockers", [])).contains("V0.6 Counter"), "card-batch registry keeps the V0.6 Counter production blocker explicit")


func _offer_input() -> Dictionary:
	return {
		"schema_version": OFFER.SCHEMA_VERSION,
		"semantic_action_id": INTENT.ACTION_CARD_PLAY,
		"action_family_id": INTENT.FAMILY_CARD_PLAY,
		"source_revision": 7,
		"actor_scope": "authorized_actor",
		"public_or_private_target_spec": {
			"visibility_scope_id": "actor_private",
			"target_kind_id": "stable-entity",
			"target_bindings": [
				{
					"target_role_id": "card_instance_id",
					"target_id": "card.instance.0123456789abcdef01234567",
				},
				{
					"target_role_id": "hand_slot_id",
					"target_id": "hand.slot.0",
				},
			],
			"requires_target": true,
		},
		"legality_state": "available",
		"disabled_reason_id": "none",
		"cost_spec": {
			"cost_kind_id": "none",
			"amount_units": 0,
			"resource_id": "none",
		},
		"requirement_spec": {
			"requirement_ids": ["card-play-authorized"],
			"source_revision_required": true,
		},
		"consequence_spec": {
			"committed_effect_refs": ["effect.card-play"],
			"refresh_scope": "full",
		},
		"presentation_token_ids": ["action.card-play"],
	}


func _card_play_intent_input(actor_kind: String, submission_kind: String) -> Dictionary:
	var result := _base_intent_input(INTENT.ACTION_CARD_PLAY, actor_kind, submission_kind)
	result["target_ids"] = {
		"card_instance_id": "card.instance.0123456789abcdef01234567",
		"hand_slot_id": "hand.slot.0",
	}
	return result


func _end_turn_intent_input(actor_kind: String, submission_kind: String) -> Dictionary:
	return _base_intent_input(INTENT.ACTION_SESSION_END_TURN, actor_kind, submission_kind)


func _base_intent_input(
	action_id: String,
	actor_kind: String,
	submission_kind: String
) -> Dictionary:
	return {
		"schema_version": INTENT.SCHEMA_VERSION,
		"request_id": "request.action.1",
		"semantic_action_id": action_id,
		"source_revision": 7,
		"actor_authorization": _authorization(actor_kind),
		"target_ids": {},
		"parameters": {},
		"submission_kind": submission_kind,
	}


func _authorization(actor_kind: String) -> Dictionary:
	return {
		"schema_version": INTENT.SCHEMA_VERSION,
		"actor_kind_id": actor_kind,
		"actor_id": "actor.player-0",
		"actor_index": 0,
		"actor_revision": 3,
		"session_id": "session.test-1",
		"session_revision": 2,
		"authorization_proof_ref": "authorization.player-0.3",
		"source_surface_id": "game-screen",
	}


func _receipt_input(intent: Dictionary) -> Dictionary:
	return {
		"schema_version": RECEIPT.SCHEMA_VERSION,
		"semantic_action_id": str(intent.get("semantic_action_id", "")),
		"accepted": true,
		"reason_id": "committed",
		"request_id": str(intent.get("request_id", "")),
		"request_fingerprint": INTENT.request_fingerprint(intent),
		"authoritative_revision": 8,
		"committed_effect_refs": ["effect.card-play.8"],
		"public_projection_ref": "projection.public.action-1",
		"viewer_private_projection_ref": "projection.private.action-1",
		"idempotent_replay": false,
		"request_id_collision": false,
		"refresh_scope": "full",
	}


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"GAME_ACTION_SEMANTIC_PROTOCOL_V1_TEST|status=PASS|checks=%d|failures=0"
			% _checks
		)
		quit(0)
		return
	push_error(
		"GAME_ACTION_SEMANTIC_PROTOCOL_V1_TEST|status=FAIL|checks=%d|failures=%d|details=%s"
		% [_checks, _failures.size(), JSON.stringify(_failures)]
	)
	quit(1)
