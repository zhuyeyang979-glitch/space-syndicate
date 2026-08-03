extends SceneTree

const CORE := preload("res://scripts/v07_semantic/v07_unified_card_track_core.gd")
const BATCH_CORE := preload("res://scripts/v07_semantic/v07_asset_batch_core.gd")
const ADAPTER := preload(
	"res://scripts/v07_adapters/v07_canonical_ai_observation_adapter.gd"
)
const ROSTER := ["player.alpha", "player.beta", "player.gamma", "player.delta"]

var _checks := 0
var _failures: Array[String] = []


class TestTimeAuthority extends RefCounted:
	var _attestations: Dictionary = {}

	func issue(attestation_id: String, observed_at_ms: int) -> Dictionary:
		var attestation := CORE.sealed_copy({
			"schema_version": BATCH_CORE.SCHEMA_VERSION,
			"interface_id": BATCH_CORE.TIME_ATTESTATION_INTERFACE_ID,
			"attestation_id": attestation_id,
			"observed_at_ms": observed_at_ms,
		}, "attestation_fingerprint")
		_attestations[attestation_id] = attestation
		return attestation.duplicate(true)

	func authoritative_time_attestation_v1(attestation_id: String) -> Dictionary:
		return (
			_attestations.get(attestation_id, {}) as Dictionary
		).duplicate(true)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var core := CORE.new(
		ROSTER,
		900626424,
		{"lead_tenure_batches": 1, "color_cycle_batches": 6}
	)
	var initial_lead := _lead_id(core)
	_test_each_ai_sees_only_own_lead_fact(core, initial_lead)
	_test_adapter_rejects_identity_and_inconsistent_self_fact(core, initial_lead)
	var boundary_receipt := _commit_batch(core, 1)
	var next_lead := _lead_id(core)
	_expect(
		bool(boundary_receipt.get("accepted", false)) and next_lead != initial_lead,
		"one completed batch advances Candidate A's one-batch lead tenure"
	)
	_test_each_ai_sees_only_own_lead_fact(core, next_lead)
	var old_lead_facts := (
		(core.ai_observation_v1(initial_lead) as Dictionary).get(
			"viewer_private_facts",
			{}
		) as Dictionary
	)
	_expect(
		old_lead_facts.get("self_is_current_lead") == false
			and str(old_lead_facts.get("self_influence_class", "")) == "normal",
		"the outgoing lead loses only its own private double-influence fact"
	)
	_finish()


func _test_each_ai_sees_only_own_lead_fact(core: RefCounted, lead_id: String) -> void:
	for actor_id in ROSTER:
		var viewer_id := str(actor_id)
		var observation := core.call("ai_observation_v1", viewer_id) as Dictionary
		var private_facts := observation.get("viewer_private_facts", {}) as Dictionary
		var expected_is_lead: bool = viewer_id == lead_id
		_expect(
			private_facts.get("self_is_current_lead") == expected_is_lead
				and str(private_facts.get("self_influence_class", ""))
					== ("double" if expected_is_lead else "normal"),
			"%s receives the correct self-only lead influence fact" % viewer_id
		)
		var player_private := (
			(core.call("player_projection_v1", viewer_id) as Dictionary).get(
				"viewer_private_facts",
				{}
			) as Dictionary
		)
		_expect(
			bool(player_private.get("self_lead_notice", false)) == expected_is_lead,
			"Player and AI have semantically equal permission for their own lead fact"
		)
		_expect(
			str(ADAPTER._track_observation_reason(observation, viewer_id)).is_empty(),
			"canonical AI adapter accepts %s self-lead observation" % viewer_id
		)
		for forbidden_key in [
			"current_lead_id",
			"fixed_order",
			"round_order",
			"completed_lead_ids",
			"next_lead_id",
		]:
			_expect(
				not _contains_key_recursive(observation, forbidden_key),
				"AI observation excludes hidden key %s" % forbidden_key
			)


func _test_adapter_rejects_identity_and_inconsistent_self_fact(
	core: RefCounted,
	lead_id: String
) -> void:
	var source := core.call("ai_observation_v1", lead_id) as Dictionary
	var leaked := source.duplicate(true)
	var leaked_private := leaked.get("viewer_private_facts", {}) as Dictionary
	leaked_private["current_lead_id"] = lead_id
	_reseal_track_observation(leaked)
	_expect(
		str(ADAPTER._track_observation_reason(leaked, lead_id))
			== "track_private_facts_invalid",
		"canonical AI adapter rejects another lead identity field even when resealed"
	)
	var inconsistent := source.duplicate(true)
	var inconsistent_private := (
		inconsistent.get("viewer_private_facts", {}) as Dictionary
	)
	inconsistent_private["self_is_current_lead"] = true
	inconsistent_private["self_influence_class"] = "normal"
	_reseal_track_observation(inconsistent)
	_expect(
		str(ADAPTER._track_observation_reason(inconsistent, lead_id))
			== "track_self_lead_facts_inconsistent",
		"canonical AI adapter fail-closes contradictory self lead facts"
	)


func _commit_batch(core: RefCounted, sequence: int) -> Dictionary:
	var batch_id := "batch.v071.ai.%03d" % sequence
	var initial_assets: Dictionary = {}
	var completed_gdp: Dictionary = {}
	for actor_id in ROSTER:
		initial_assets[str(actor_id)] = _zero_color_map()
		completed_gdp[str(actor_id)] = _zero_color_map()
	var state := BATCH_CORE.create_state(
		batch_id,
		ROSTER,
		ROSTER,
		initial_assets
	) as Dictionary
	var authority := TestTimeAuthority.new()
	var batch_core := BATCH_CORE.new()
	batch_core.bind_time_attestation_authority(authority)
	var attestation := authority.issue("attestation.v071.ai.%03d" % sequence, 30001)
	var closed := batch_core.close_expired_window(
		state,
		attestation,
		completed_gdp,
		ROSTER
	) as Dictionary
	var refreshed := BATCH_CORE.refresh_assets_after_batch(
		closed.get("state", {}) as Dictionary
	) as Dictionary
	var completed_receipt := (
		refreshed.get("receipt", {}) as Dictionary
	).duplicate(true)
	var intent := core.call(
		"build_intent_v1",
		"request.v071.ai.batch.%03d" % sequence,
		"system",
		CORE.ACTION_COMMIT_BATCH_BOUNDARY,
		{"completed_batch_receipt": completed_receipt}
	) as Dictionary
	return core.call("apply_intent_v1", intent) as Dictionary


func _zero_color_map() -> Dictionary:
	return {
		"life": 0,
		"energy": 0,
		"industry": 0,
		"technology": 0,
		"commerce": 0,
		"shipping": 0,
	}


func _reseal_track_observation(observation: Dictionary) -> void:
	var source_facts := {
		"schema_version": observation.get("schema_version"),
		"domain_id": observation.get("domain_id"),
		"source_revision": observation.get("source_revision"),
		"viewer_actor_id": observation.get("viewer_actor_id"),
		"public_facts": observation.get("public_facts"),
		"viewer_private_facts": observation.get("viewer_private_facts"),
	}
	observation["source_core_fingerprint"] = CORE.fingerprint(source_facts)
	observation["projection_fingerprint"] = CORE.fingerprint(
		observation,
		"projection_fingerprint"
	)


func _lead_id(core: RefCounted) -> String:
	var authority := core.call("core_authority_v1") as Dictionary
	var state := authority.get("authority_state", {}) as Dictionary
	return str(
		(state.get("hidden_lead_cycle_state", {}) as Dictionary).get(
			"current_lead_id",
			""
		)
	)


func _contains_key_recursive(value: Variant, needle: String) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant) == needle \
				or _contains_key_recursive((value as Dictionary).get(key_variant), needle):
				return true
	elif value is Array:
		for item_variant in value as Array:
			if _contains_key_recursive(item_variant, needle):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"V071_AI_SELF_LEAD_OBSERVATION_TEST|status=PASS|checks=%d|failures=0"
			% _checks
		)
		quit(0)
		return
	push_error("V0.7.1 AI self-lead test failed:\n- %s" % "\n- ".join(_failures))
	print(
		"V071_AI_SELF_LEAD_OBSERVATION_TEST|status=FAIL|checks=%d|failures=%d"
		% [_checks, _failures.size()]
	)
	quit(1)
