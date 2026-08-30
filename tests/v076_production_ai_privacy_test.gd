extends SceneTree

const COMPOSITION_PATH := "res://scenes/runtime/V075RuntimeComposition.tscn"
const PRODUCTION_SCREEN_PATH := "res://scenes/ui/v075/V075SampleGameScreen.tscn"
const AIAdapter := preload(
	"res://scripts/v075/ai/v075_combat_ai_adapter.gd"
)

const PUBLIC_PRIVATE_KEYS := [
	"cash",
	"credits",
	"cash_balance",
	"exact_cash",
	"player_cash",
	"hand",
	"discard",
	"private_discard",
	"queued_actions",
	"ai_plan",
	"private_plan",
	"combat_private_facts",
	"combat_candidates",
	"military_task_options",
	"own_monster_skill_sources",
	"card_action_binding",
	"authority_lineage_fingerprint",
	"immutable_identity_fingerprint",
	"lifecycle_evidence_fingerprint",
	"binding_fingerprint",
]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var composition_packed := load(COMPOSITION_PATH) as PackedScene
	var screen_packed := load(PRODUCTION_SCREEN_PATH) as PackedScene
	_expect(composition_packed != null, "production V075 composition loads")
	_expect(screen_packed != null, "production V075 GameScreen loads")
	if composition_packed == null or screen_packed == null:
		_finish()
		return

	var composition := composition_packed.instantiate()
	root.add_child(composition)
	await process_frame
	await process_frame
	var screen := screen_packed.instantiate()
	root.add_child(screen)
	await process_frame
	screen.call(
		"bind_application_flow",
		composition,
		composition.call("identity_snapshot") as Dictionary,
		composition.call("capability_snapshot") as Dictionary
	)
	composition.projection_changed.connect(
		Callable(screen, "apply_snapshot")
	)

	var runtime := composition.get_node_or_null("V075RuntimeOwner")
	_expect(runtime != null, "composition exposes the existing V075 Runtime Owner")
	if runtime == null:
		composition.queue_free()
		screen.queue_free()
		await process_frame
		_finish()
		return

	var projection_events: Array[Dictionary] = []
	var queued_receipts: Array[Dictionary] = []
	var locked_receipts: Array[Dictionary] = []
	composition.projection_changed.connect(func(snapshot: Dictionary) -> void:
		projection_events.append(snapshot.duplicate(true))
	)
	runtime.connect(&"action_queued", func(receipt: Dictionary) -> void:
		queued_receipts.append(receipt.duplicate(true))
	)
	runtime.connect(&"submission_locked", func(receipt: Dictionary) -> void:
		locked_receipts.append(receipt.duplicate(true))
	)

	var started := composition.call("_start_new_game", {
		"player_count": 4,
		"seed": 901626424,
		"map_seed": 900626424,
		"region_count": 16,
		"geography_complexity": "STANDARD",
		"land_ocean_profile": "BALANCED",
	}) as Dictionary
	_expect(bool(started.get("accepted", false)), "production new game starts")
	var player_ids := runtime.call("player_ids") as Array
	var local_id := str(runtime.call("local_player_id"))
	_expect(
		player_ids.size() == 4 and local_id == "player.local",
		"production roster contains one local human and three AI actors"
	)
	if player_ids.size() != 4:
		composition.queue_free()
		screen.queue_free()
		await process_frame
		_finish()
		return
	var ai_id := str(player_ids[1])
	var rival_id := str(player_ids[2])

	var ai_hand_ids := _private_hand_ids(runtime, ai_id)
	var rival_hand_ids := _private_hand_ids(runtime, rival_id)
	_expect(not ai_hand_ids.is_empty(), "AI begins with a real owner-private hand")
	_expect(not rival_hand_ids.is_empty(), "rival AI has a distinct private hand")

	var cash_by_player := runtime.get("_cash_by_player") as Dictionary
	var ai_cash_owner: Object = cash_by_player.get(ai_id)
	var ai_cash := (
		ai_cash_owner.call("debug_snapshot") as Dictionary
		if ai_cash_owner != null
		else {}
	)
	_expect(
		int(ai_cash.get("credits", 0)) > 0
		and not str(ai_cash.get("authority_id", "")).is_empty(),
		"AI cash remains in its existing private cash authority"
	)

	var ai_observation := runtime.call("ai_observation", ai_id) as Dictionary
	var rival_observation := runtime.call("ai_observation", rival_id) as Dictionary
	var ai_private := ai_observation.get("combat_private_facts", {}) as Dictionary
	var ai_public := ai_observation.get("combat_public_facts", {}) as Dictionary
	var rival_public := (
		rival_observation.get("combat_public_facts", {}) as Dictionary
	)
	_expect(
		str(ai_observation.get("actor_id", "")) == ai_id
		and str(ai_private.get("viewer_player_id", "")) == ai_id,
		"AI observation is scoped to the acting AI identity"
	)
	_expect(
		not ai_private.is_empty()
		and not ai_public.is_empty()
		and ai_public == rival_public,
		"all AI actors consume the same detached public combat facts"
	)
	var privacy := AIAdapter.new().privacy_report(ai_private, ai_public)
	_expect(
		bool(privacy.get("valid", false))
		and int(privacy.get("hidden_info_violation_count", -1)) == 0,
		"production AI private/public inputs pass the fail-closed privacy gate"
	)
	for rival_card_id in rival_hand_ids:
		_expect(
			not _contains_string(ai_observation, str(rival_card_id)),
			"AI observation excludes rival private card %s" % rival_card_id
		)
	_expect(
		int(ai_observation.get("combat_hidden_info_violation_count", -1)) == 0,
		"candidate enumeration reports zero hidden-information violations"
	)

	# Advance the real production submission phase once. This invokes the
	# production _process_submission -> _auto_queue_and_lock path for every AI;
	# no action, hand, cash, target, or result is injected by this test.
	runtime.call("_process", 0.001)
	var queued_by_player := runtime.get("_queued_by_player") as Dictionary
	var ai_queue := (
		queued_by_player.get(ai_id, []) as Array
	).duplicate(true)
	var ai_queued_receipts := _receipts_for_actor(queued_receipts, ai_id)
	var ai_locked_receipts := _receipts_for_actor(locked_receipts, ai_id)
	_expect(
		not ai_queue.is_empty()
		and ai_queue.size() <= 5
		and ai_queued_receipts.size() == ai_queue.size(),
		"production AI queues one bounded set of real actions"
	)
	_expect(
		ai_locked_receipts.size() == 1
		and bool((ai_locked_receipts[0] as Dictionary).get("accepted", false)),
		"production AI locks its submission through the authoritative owner"
	)
	var legal_after_queue := runtime.call("legal_card_actions", ai_id) as Array
	for action_variant in ai_queue:
		var action := action_variant as Dictionary
		_expect(
			_action_has_legal_source(action, legal_after_queue),
			"queued AI action retains an authoritative legal card/target binding"
		)

	var local_snapshot := runtime.call("player_snapshot", local_id) as Dictionary
	var rival_snapshot := runtime.call("player_snapshot", rival_id) as Dictionary
	_expect(not local_snapshot.is_empty(), "local viewer projection is available")
	_expect(not rival_snapshot.is_empty(), "rival viewer projection is available")
	for private_card_id in ai_hand_ids:
		_expect(
			not _contains_string(local_snapshot, str(private_card_id)),
			"local viewer cannot read AI private card %s" % private_card_id
		)
		_expect(
			not _contains_string(rival_snapshot, str(private_card_id)),
			"rival viewer cannot read AI private card %s" % private_card_id
		)
	for action_variant in ai_queue:
		var action := action_variant as Dictionary
		for private_plan_id in [
			str(action.get("action_id", "")),
			str(action.get("card_instance_id", "")),
		]:
			if private_plan_id.is_empty():
				continue
			_expect(
				not _contains_string(local_snapshot, private_plan_id),
				"local viewer cannot read AI queued plan identity"
			)

	var combat_public_projection := (
		local_snapshot.get("v075_combat_projection", {}) as Dictionary
	).duplicate(true)
	combat_public_projection.erase("own_monster_skill_sources")
	combat_public_projection.erase("own_private_skill_source_count")
	combat_public_projection.erase("military_task_options")
	var public_surfaces := {
		"roster": local_snapshot.get("roster", []),
		"public_history": local_snapshot.get("public_history", []),
		"combat_public_history": local_snapshot.get(
			"combat_public_history", []
		),
		"combat_public_projection": combat_public_projection,
		"combat_public_facts": ai_public,
	}
	var leaked_paths: Array[String] = []
	_collect_key_paths(public_surfaces, PUBLIC_PRIVATE_KEYS, "public", leaked_paths)
	_expect(
		leaked_paths.is_empty(),
		"public surfaces omit hands, cash, plans, and private bindings: %s"
		% [leaked_paths]
	)
	_expect(
		not _contains_string(
			public_surfaces,
			str(ai_cash.get("authority_id", ""))
		),
		"public surfaces omit the AI cash authority identity"
	)

	screen.call("apply_snapshot", local_snapshot)
	var screen_snapshot := screen.get("_v075_snapshot") as Dictionary
	for private_card_id in ai_hand_ids:
		_expect(
			not _contains_string(screen_snapshot, str(private_card_id)),
			"production GameScreen stores no AI private card identity"
		)
	_expect(
		not projection_events.is_empty()
		and str((projection_events[-1] as Dictionary).get("viewer_id", ""))
			== local_id,
		"production Flow emits only the local viewer projection to GameScreen"
	)

	var runtime_debug := runtime.call("debug_snapshot") as Dictionary
	var witness_by_actor := runtime_debug.get(
		"ai_observation_witness_by_actor", {}
	) as Dictionary
	var ai_witness := witness_by_actor.get(ai_id, {}) as Dictionary
	var allowed_fields := ai_witness.get(
		"allowed_field_manifest", []
	) as Array
	var canonical_allowed_fields := ai_witness.get(
		"canonical_allowed_field_manifest", []
	) as Array
	var source_revisions := ai_witness.get(
		"component_source_revisions", {}
	) as Dictionary
	var source_fingerprints := ai_witness.get(
		"source_fingerprint_by_domain", {}
	) as Dictionary
	_expect(
		str(ai_witness.get("schema", ""))
			== "V076AIObservationAuthorityWitnessV1"
			and int(ai_witness.get("sequence", 0)) > 0
			and int(runtime_debug.get(
				"ai_observation_witness_sequence", 0
			)) >= witness_by_actor.size()
			and str(ai_witness.get("actor_id", "")) == ai_id
			and str(ai_witness.get("viewer_id", "")) == ai_id,
		"session witness binds the AI actor/viewer and monotonic sequence"
	)
	_expect(
		allowed_fields.has("canonical_observation")
			and allowed_fields.has("legal_actions")
			and allowed_fields.has("combat_private_facts")
			and allowed_fields.has("combat_public_facts")
			and canonical_allowed_fields.has("public_facility_slots")
			and canonical_allowed_fields.has("own_cards")
			and canonical_allowed_fields.has("source_revisions")
			and canonical_allowed_fields.has(
				"source_projection_fingerprints"
			),
		"AI witness seals both allowed-field manifests"
	)
	_expect(
		not source_revisions.is_empty()
			and not source_fingerprints.is_empty()
			and str(ai_witness.get(
				"canonical_observation_fingerprint", ""
			)).length() == 64
			and str(ai_witness.get(
				"outer_observation_sha256", ""
			)).length() == 64,
		"AI witness seals canonical source revisions and fingerprints"
	)
	for source_fingerprint_variant in source_fingerprints.values():
		_expect(
			str(source_fingerprint_variant).length() == 64,
			"each AI observation source domain carries one SHA-256 fingerprint"
		)
	_expect(
		int(ai_witness.get("unexpected_top_level_field_count", -1)) == 0
			and int(ai_witness.get(
				"forbidden_source_field_count", -1
			)) == 0
			and int(ai_witness.get("private_leak_field_count", -1)) == 0
			and int(ai_witness.get(
				"combat_hidden_info_violation_count", -1
			)) == 0,
		"AI witness reports zero unexpected, forbidden, private, or combat leaks"
	)
	var public_action_receipt_ids := ai_witness.get(
		"public_action_receipt_ids", []
	) as Array
	_expect(
		not public_action_receipt_ids.is_empty()
			and public_action_receipt_ids.has(str(ai_witness.get(
				"latest_public_action_receipt_id", ""
			))),
		"AI witness correlates the legal observation to its public action receipt"
	)
	for rival_card_id in rival_hand_ids:
		_expect(
			not _contains_string(ai_witness, str(rival_card_id)),
			"AI witness excludes rival hand identity %s" % rival_card_id
		)
	for action_variant in ai_queue:
		var private_action := action_variant as Dictionary
		_expect(
			not _contains_string(
				ai_witness, str(private_action.get("action_id", ""))
			)
				and not _contains_string(
					ai_witness,
					str(private_action.get("card_instance_id", ""))
				),
			"AI witness excludes owner-private plan and card identities"
		)
	_expect(
		not local_snapshot.has("ai_observation_witness_by_actor")
			and not screen_snapshot.has("ai_observation_witness_by_actor"),
		"debug-only AI witness never enters player or GameScreen snapshots"
	)
	var ai_debug := (
		(runtime.get("_combat_ai_adapter") as RefCounted).call(
			"debug_snapshot"
		) as Dictionary
	)
	_expect(
		int(runtime_debug.get("hidden_info_violation_count", -1)) == 0
		and int(runtime_debug.get("ai_combat_invalid_target_count", -1)) == 0
		and int(runtime_debug.get("canonical_ai_observation_count", 0)) > 0,
		"production Runtime reports legal AI actions and zero privacy/target faults"
	)
	_expect(
		int(ai_debug.get("hidden_info_reader_count", -1)) == 0
		and int(ai_debug.get("rng_draw_count", -1)) == 0,
		"existing AI Adapter owns no hidden reader or RNG"
	)
	var flow_debug := composition.call("debug_snapshot") as Dictionary
	_expect(
		bool(flow_debug.get("v076_production_ready", false))
		and int(flow_debug.get("v076_production_adapter_count", 0)) == 1
		and int(flow_debug.get("v076_kernel_owner_count", 0)) == 1,
		"STEP12 reuses the current production composition without a new Owner"
	)

	composition.queue_free()
	screen.queue_free()
	await process_frame
	_finish()


func _private_hand_ids(runtime: Node, actor_id: String) -> Array[String]:
	var result: Array[String] = []
	var projection := runtime.call("_dbg_projection", actor_id) as Dictionary
	var facts := projection.get("facts", {}) as Dictionary
	for card_variant in facts.get("hand", []) as Array:
		var card := card_variant as Dictionary
		var instance_id := str(card.get("instance_id", ""))
		if not instance_id.is_empty():
			result.append(instance_id)
	return result


func _receipts_for_actor(receipts: Array[Dictionary], actor_id: String) -> Array:
	var result: Array = []
	for receipt in receipts:
		if str(receipt.get("actor_id", "")) == actor_id:
			result.append(receipt.duplicate(true))
	return result


func _action_has_legal_source(action: Dictionary, legal: Array) -> bool:
	var card_id := str(action.get("card_instance_id", ""))
	var target_id := str(action.get("target_slot_id", ""))
	if card_id.is_empty() or target_id.is_empty():
		return false
	for option_variant in legal:
		var option := option_variant as Dictionary
		if (
			str(option.get("card_instance_id", "")) == card_id
			and str(option.get("target_slot_id", "")) == target_id
		):
			return true
	return false


func _collect_key_paths(
	value: Variant,
	forbidden_keys: Array,
	path: String,
	result: Array[String]
) -> void:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			var child_path := "%s.%s" % [path, key]
			if key in forbidden_keys:
				result.append(child_path)
			_collect_key_paths(
				(value as Dictionary).get(key_variant),
				forbidden_keys,
				child_path,
				result
			)
	elif value is Array:
		for index in range((value as Array).size()):
			_collect_key_paths(
				(value as Array)[index],
				forbidden_keys,
				"%s[%d]" % [path, index],
				result
			)


func _contains_string(value: Variant, expected: String) -> bool:
	if expected.is_empty():
		return false
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant) == expected:
				return true
			if _contains_string((value as Dictionary).get(key_variant), expected):
				return true
		return false
	if value is Array:
		for child in value as Array:
			if _contains_string(child, expected):
				return true
		return false
	return typeof(value) in [TYPE_STRING, TYPE_STRING_NAME] and str(value) == expected


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error("V076_PRODUCTION_AI_PRIVACY_TEST|FAIL|%s" % message)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print(
		"V076_PRODUCTION_AI_PRIVACY_TEST|status=%s|passed=%d|total=%d|failures=%s"
		% [
			status,
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
