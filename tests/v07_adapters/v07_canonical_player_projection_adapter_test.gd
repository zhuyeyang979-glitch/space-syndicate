extends SceneTree

const ADAPTER := preload(
	"res://scripts/v07_adapters/v07_canonical_player_projection_adapter.gd"
)
const TRACK_CORE := preload(
	"res://scripts/v07_semantic/v07_unified_card_track_core.gd"
)
const DBG_CORE := preload("res://scripts/v07_semantic/v07_dbg_deck_core.gd")
const ASSET_BATCH_CORE := preload(
	"res://scripts/v07_semantic/v07_asset_batch_core.gd"
)
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")

const MATCH_ID := "match.canonical.player.adapter"
const MATCH_GENERATION := 3
const VIEWER_ID := "player.0"
const AUTHORIZATION_REVISION := 7
const SOURCE_REVISION := 41
const BATCH_ID := "batch.canonical.player.adapter"
const PLAYERS := ["player.0", "player.1", "player.2"]


class TrustedTimeAttestationAuthority:
	extends RefCounted

	var _attestations: Dictionary = {}

	func issue(observed_at_ms: int, sequence: int) -> Dictionary:
		var attestation := {
			"schema_version": 1,
			"interface_id": ASSET_BATCH_CORE.TIME_ATTESTATION_INTERFACE_ID,
			"attestation_id": "time.canonical.player.%d" % sequence,
			"observed_at_ms": observed_at_ms,
		}
		attestation["attestation_fingerprint"] = WIRE.fingerprint(attestation)
		_attestations[attestation.get("attestation_id")] = attestation.duplicate(true)
		return attestation

	func authoritative_time_attestation_v1(attestation_id: String) -> Dictionary:
		if not _attestations.has(attestation_id):
			return {}
		return (_attestations.get(attestation_id) as Dictionary).duplicate(true)


var _checks := 0
var _failures: Array[String] = []
var _capability: RefCounted
var _adapter: Variant
var _track_core: Variant
var _dbg_core: Variant
var _asset_batch_core := ASSET_BATCH_CORE.new()
var _asset_state: Dictionary = {}
var _sources: Dictionary = {}
var _context: Dictionary = {}
var _projection: Dictionary = {}
var _stale_track_projection: Dictionary = {}
var _stale_asset_projection: Dictionary = {}
var _stale_batch_projection: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_build_fixture()
	if _sources.is_empty() or _context.is_empty():
		_finish()
		return
	_test_canonical_happy_path()
	_test_opaque_capability_and_forged_sources()
	_test_match_authorization_and_source_staleness()
	_test_rival_projection_rejection()
	_test_track_asset_and_queue_privacy()
	_finish()


func _build_fixture() -> void:
	_track_core = TRACK_CORE.new()
	var started: Dictionary = _track_core.start_match(
		PLAYERS,
		1701,
		{"match_instance_id": MATCH_ID}
	)
	_expect(bool(started.get("accepted", false)), "track fixture starts an explicit match")
	_stale_track_projection = _track_core.player_projection_v1(VIEWER_ID)
	var stance_intent: Dictionary = _track_core.build_intent_v1(
		"request.canonical.player.stance",
		VIEWER_ID,
		TRACK_CORE.ACTION_SET_STANCE,
		{"increase_color": "life", "decrease_color": "shipping"}
	)
	var stance_receipt: Dictionary = _track_core.apply_intent_v1(stance_intent)
	_expect(
		bool(stance_receipt.get("accepted", false)),
		"track fixture advances the viewer source revision"
	)
	var track_projection: Dictionary = _track_core.player_projection_v1(VIEWER_ID)
	_dbg_core = DBG_CORE.new()
	var dbg_started: Dictionary = _dbg_core.initialize(VIEWER_ID, 1701)
	_expect(bool(dbg_started.get("initialized", false)), "DBG fixture initializes the viewer-owned deck")
	var dbg_projection: Dictionary = _dbg_core.player_projection(VIEWER_ID)

	var assets := {
		"player.0": _assets(3),
		"player.1": _assets(5),
		"player.2": _assets(1),
	}
	var initial_state := ASSET_BATCH_CORE.create_state(
		BATCH_ID,
		PLAYERS,
		["player.2", "player.0", "player.1"],
		assets,
		{},
		1000,
		1000
	)
	_expect(
		bool(ASSET_BATCH_CORE.validation_report(initial_state).get("valid", false)),
		"asset/batch fixture begins as valid PR79 authority data"
	)
	_stale_asset_projection = ASSET_BATCH_CORE.asset_player_projection(
		initial_state,
		VIEWER_ID
	)
	_stale_batch_projection = ASSET_BATCH_CORE.batch_player_projection(
		initial_state,
		VIEWER_ID
	)
	var time_authority := TrustedTimeAttestationAuthority.new()
	var bound := _asset_batch_core.bind_time_attestation_authority(time_authority)
	_expect(bool(bound.get("bound", false)), "fixture binds trusted monotonic time")
	_asset_state = initial_state
	for player_index in range(PLAYERS.size()):
		var player_id := str(PLAYERS[player_index])
		var action := _action_for_player(player_index)
		var submitted_at_ms := 1100 + player_index
		var intent := ASSET_BATCH_CORE.build_lock_intent(
			"intent.canonical.player.%d" % player_index,
			BATCH_ID,
			player_id,
			submitted_at_ms,
			[action]
		)
		var outcome := _asset_batch_core.lock_player_queue(
			_asset_state,
			intent,
			_zero_assets(),
			time_authority.issue(submitted_at_ms, player_index + 1)
		)
		_expect(
			bool(outcome.get("accepted", false)),
			"fixture locks %s local queue (reason=%s)" % [
				player_id,
				str(outcome.get("reason_code", "missing")),
			]
		)
		_asset_state = outcome.get("state", {}) as Dictionary
	_expect(
		str((_asset_state.get("window", {}) as Dictionary).get("status", ""))
			== "resolution_ready",
		"fixture reaches a populated anonymous round-robin queue"
	)
	var asset_projection := ASSET_BATCH_CORE.asset_player_projection(
		_asset_state,
		VIEWER_ID
	)
	var batch_projection := ASSET_BATCH_CORE.batch_player_projection(
		_asset_state,
		VIEWER_ID
	)
	_sources = {
		"unified_track": track_projection,
		"personal_dbg": dbg_projection,
		"six_color_assets": asset_projection,
		"card_batch": batch_projection,
	}
	_context = ADAPTER.build_authorization_context(
		MATCH_ID,
		MATCH_GENERATION,
		VIEWER_ID,
		AUTHORIZATION_REVISION,
		SOURCE_REVISION,
		track_projection,
		dbg_projection,
		asset_projection,
		batch_projection
	)
	_expect(not _context.is_empty(), "adapter builds a closed current-source authorization")
	_capability = ADAPTER.issue_capability()
	_adapter = ADAPTER.new(_capability)
	_expect(
		_adapter.bind_authorization(_capability, _context),
		"opaque capability binds the authorized viewer and exact source set"
	)


func _test_canonical_happy_path() -> void:
	var track_before := str(
		_track_core.core_authority_v1().get("core_fingerprint", "")
	)
	var asset_before := ASSET_BATCH_CORE._fingerprint(_asset_state)
	_projection = _adapter.adapt_player_projection(
		_capability,
		_context,
		_sources
	)
	_expect(not _projection.is_empty(), "authorized PR79 Player projections adapt")
	_expect(
		bool(ADAPTER.validation_report(_projection).get("valid", false)),
		"canonical Player projection validates as detached closed data"
	)
	_expect(
		ADAPTER.matches_authorization(
			_projection,
			MATCH_ID,
			MATCH_GENERATION,
			VIEWER_ID,
			AUTHORIZATION_REVISION,
			SOURCE_REVISION
		),
		"canonical projection binds match, generation, viewer, and revisions"
	)
	_expect(
		_projection.get("unified_track") == _sources.get("unified_track")
			and _projection.get("personal_dbg") == _sources.get("personal_dbg")
			and _projection.get("six_color_assets") \
				== _sources.get("six_color_assets")
			and _projection.get("card_batch") == _sources.get("card_batch")
			and _projection.get("presentation_assets") \
				== ADAPTER.presentation_asset_contract(),
		"adapter preserves Core surfaces and projects only stable presentation asset keys"
	)
	_expect(
		ADAPTER.presentation_asset_contract().has({"asset_key": "card.badge.starter"}),
		"canonical Player presentation publishes the stable Starter badge key"
	)
	_expect(
		str(_track_core.core_authority_v1().get("core_fingerprint", ""))
			== track_before
			and ASSET_BATCH_CORE._fingerprint(_asset_state) == asset_before,
		"projection adaptation does not mutate either Core source"
	)
	var duplicate: Dictionary = _adapter.adapt_player_projection(
		_capability,
		_context,
		_sources
	)
	_expect(
		duplicate == _projection
			and str(_adapter.last_reason_code()) == "projection_duplicate",
		"same authorized source is idempotent"
	)
	var detached := ADAPTER.detached_copy(_projection)
	(detached.get("component_source_revisions") as Dictionary)["unified_track"] = 999
	_expect(
		int((_projection.get("component_source_revisions") as Dictionary).get(
			"unified_track",
			-1
		)) != 999,
		"returned and copied projections are deeply detached"
	)


func _test_opaque_capability_and_forged_sources() -> void:
	var rival_capability := ADAPTER.issue_capability()
	_expect(
		_adapter.adapt_player_projection(
			rival_capability,
			_context,
			_sources
		).is_empty()
			and _adapter.last_reason_code() == "capability_rejected",
		"a same-type forged capability fails object-identity authorization"
	)
	_expect(
		not WIRE.is_closed_data(_capability),
		"opaque capability cannot enter a pure-data projection"
	)

	var resealed_track := (
		_sources.get("unified_track", {}) as Dictionary
	).duplicate(true)
	var private_facts := resealed_track.get("viewer_private_facts") as Dictionary
	private_facts["self_lead_notice"] = not bool(
		private_facts.get("self_lead_notice", false)
	)
	private_facts["self_lead_notice_token"] = (
		"v072.lead.double_influence"
		if bool(private_facts.get("self_lead_notice", false))
		else "none"
	)
	_reseal_track_projection(resealed_track)
	var forged_track_sources := _sources.duplicate(true)
	forged_track_sources["unified_track"] = resealed_track
	_expect(
		_adapter.adapt_player_projection(
			_capability,
			_context,
			forged_track_sources
		).is_empty()
			and _adapter.last_reason_code() == "track_projection_forged",
		"a structurally valid same-revision track reseal misses the authorized fingerprint"
	)

	var resealed_assets := (
		_sources.get("six_color_assets", {}) as Dictionary
	).duplicate(true)
	(resealed_assets.get("own_exact_assets") as Dictionary)["life"] = int(
		(resealed_assets.get("own_exact_assets") as Dictionary).get("life", 0)
	) + 1
	(resealed_assets.get("own_available_assets") as Dictionary)["life"] = int(
		(resealed_assets.get("own_available_assets") as Dictionary).get("life", 0)
	) + 1
	_reseal_projection(resealed_assets)
	var forged_asset_sources := _sources.duplicate(true)
	forged_asset_sources["six_color_assets"] = resealed_assets
	_expect(
		_adapter.adapt_player_projection(
			_capability,
			_context,
			forged_asset_sources
		).is_empty()
			and _adapter.last_reason_code() == "asset_projection_forged",
		"a semantically valid same-revision asset reseal misses the authorized fingerprint"
	)

	var observation_sources := _sources.duplicate(true)
	observation_sources["unified_track"] = _track_core.ai_observation_v1(VIEWER_ID)
	_expect(
		_adapter.adapt_player_projection(
			_capability,
			_context,
			observation_sources
		).is_empty(),
		"an AI observation cannot substitute for a Player projection"
	)
	var extra_source := _sources.duplicate(true)
	extra_source["ai_plan"] = {"next_action": "private"}
	_expect(
		_adapter.adapt_player_projection(
			_capability,
			_context,
			extra_source
		).is_empty(),
		"undeclared AI plan data fails the exact source bundle"
	)


func _test_match_authorization_and_source_staleness() -> void:
	var stale_match := _context.duplicate(true)
	stale_match["match_instance_id"] = "match.previous.player.adapter"
	_expect(
		_adapter.adapt_player_projection(
			_capability,
			stale_match,
			_sources
		).is_empty()
			and _adapter.last_reason_code() == "match_instance_mismatch",
		"projection from another match fails closed"
	)
	var stale_generation := _context.duplicate(true)
	stale_generation["match_generation"] = MATCH_GENERATION - 1
	_expect(
		_adapter.adapt_player_projection(
			_capability,
			stale_generation,
			_sources
		).is_empty()
			and _adapter.last_reason_code() == "match_generation_stale",
		"older match generation fails closed"
	)
	var stale_authorization := _context.duplicate(true)
	stale_authorization["authorization_revision"] = AUTHORIZATION_REVISION - 1
	_expect(
		_adapter.adapt_player_projection(
			_capability,
			stale_authorization,
			_sources
		).is_empty()
			and _adapter.last_reason_code() == "authorization_revision_stale",
		"stale viewer authorization fails closed"
	)
	var stale_source_context := _context.duplicate(true)
	stale_source_context["source_revision"] = SOURCE_REVISION - 1
	_expect(
		_adapter.adapt_player_projection(
			_capability,
			stale_source_context,
			_sources
		).is_empty()
			and _adapter.last_reason_code() == "source_revision_stale",
		"stale aggregate source revision fails closed"
	)

	var stale_track_sources := _sources.duplicate(true)
	stale_track_sources["unified_track"] = _stale_track_projection
	_expect(
		_adapter.adapt_player_projection(
			_capability,
			_context,
			stale_track_sources
		).is_empty()
			and _adapter.last_reason_code() == "track_source_revision_stale",
		"old but internally valid track projection fails current source binding"
	)
	var stale_asset_sources := _sources.duplicate(true)
	stale_asset_sources["six_color_assets"] = _stale_asset_projection
	stale_asset_sources["card_batch"] = _stale_batch_projection
	_expect(
		_adapter.adapt_player_projection(
			_capability,
			_context,
			stale_asset_sources
		).is_empty()
			and _adapter.last_reason_code() == "asset_source_revision_stale",
		"old but paired asset/batch projections fail current source binding"
	)

	var next_context := ADAPTER.build_authorization_context(
		MATCH_ID,
		MATCH_GENERATION,
		VIEWER_ID,
		AUTHORIZATION_REVISION + 1,
		SOURCE_REVISION + 1,
		_sources.get("unified_track") as Dictionary,
		_sources.get("personal_dbg") as Dictionary,
		_sources.get("six_color_assets") as Dictionary,
		_sources.get("card_batch") as Dictionary
	)
	_expect(
		_adapter.bind_authorization(_capability, next_context),
		"authorization and aggregate source revisions rotate monotonically"
	)
	_expect(
		_adapter.adapt_player_projection(
			_capability,
			_context,
			_sources
		).is_empty(),
		"previous context remains stale after authorization rotation"
	)
	_expect(
		not _adapter.bind_authorization(_capability, _context)
			and _adapter.last_reason_code() == "authorization_revision_stale",
		"adapter cannot be rebound to an older authorization"
	)
	_context = next_context
	_projection = _adapter.adapt_player_projection(
		_capability,
		_context,
		_sources
	)
	_expect(not _projection.is_empty(), "current rotated authorization adapts")


func _test_rival_projection_rejection() -> void:
	var rival_dbg := DBG_CORE.new()
	var rival_dbg_started: Dictionary = rival_dbg.initialize("player.1", 1701)
	_expect(bool(rival_dbg_started.get("initialized", false)), "rival DBG fixture initializes")
	var rival_sources := {
		"unified_track": _track_core.player_projection_v1("player.1"),
		"personal_dbg": rival_dbg.player_projection("player.1"),
		"six_color_assets": ASSET_BATCH_CORE.asset_player_projection(
			_asset_state,
			"player.1"
		),
		"card_batch": ASSET_BATCH_CORE.batch_player_projection(
			_asset_state,
			"player.1"
		),
	}
	_expect(
		_adapter.adapt_player_projection(
			_capability,
			_context,
			rival_sources
		).is_empty(),
		"complete rival Player projection bundle is unauthorized"
	)
	var mixed_assets := _sources.duplicate(true)
	mixed_assets["six_color_assets"] = rival_sources.get("six_color_assets")
	_expect(
		_adapter.adapt_player_projection(
			_capability,
			_context,
			mixed_assets
		).is_empty(),
		"rival six-color assets cannot be mixed into the viewer bundle"
	)
	var mixed_queue := _sources.duplicate(true)
	mixed_queue["card_batch"] = rival_sources.get("card_batch")
	_expect(
		_adapter.adapt_player_projection(
			_capability,
			_context,
			mixed_queue
		).is_empty(),
		"rival local queue cannot be mixed into the viewer bundle"
	)


func _test_track_asset_and_queue_privacy() -> void:
	var canonical_json := WIRE.canonical_json(_projection)
	_expect(
		WIRE.is_closed_data(_projection)
			and not canonical_json.contains("capability")
			and not canonical_json.contains("ai_plan")
			and not canonical_json.contains("ai_score"),
		"canonical projection contains only serializable Player facts"
	)
	var track_private := (
		(_projection.get("unified_track") as Dictionary)
			.get("viewer_private_facts") as Dictionary
	)
	var track_items := track_private.get("own_segment_items") as Array
	_expect(not track_items.is_empty(), "viewer receives a concrete own track segment")
	var track_item_keys_safe := true
	for item_variant in track_items:
		var item := item_variant as Dictionary
		if item.has("segment_owner_id") \
				or item.has("path_position") \
				or item.has("future_sequence"):
			track_item_keys_safe = false
	_expect(track_item_keys_safe, "track projection excludes owner routing and future order")

	var projected_assets := (
		_projection.get("six_color_assets") as Dictionary
	).get("own_exact_assets") as Dictionary
	_expect(
		projected_assets == _assets(3) and projected_assets != _assets(5),
		"six-color projection contains the viewer balance, not the rival balance"
	)
	var viewer_queue := (
		_projection.get("card_batch") as Dictionary
	).get("own_local_queue") as Array
	_expect(
		viewer_queue.size() == 1
			and str((viewer_queue[0] as Dictionary).get("action_id", ""))
				== "action.canonical.player.0",
		"local queue is partitioned to the authorized viewer"
	)
	var anonymous_queue := (
		_projection.get("card_batch") as Dictionary
	).get("anonymous_public_queue") as Array
	var anonymous_fields_safe := anonymous_queue.size() == PLAYERS.size()
	for entry_variant in anonymous_queue:
		if not (entry_variant is Dictionary) or not WIRE.exact_fields(
			entry_variant as Dictionary,
			ASSET_BATCH_CORE.PUBLIC_QUEUE_FIELDS
		):
			anonymous_fields_safe = false
	_expect(
		anonymous_fields_safe,
		"anonymous queue exposes the exact V0.7.1 causal-history allowlist"
	)

	var owner_leak := (
		_sources.get("card_batch", {}) as Dictionary
	).duplicate(true)
	var leaked_queue := owner_leak.get("anonymous_public_queue") as Array
	if not leaked_queue.is_empty():
		(leaked_queue[0] as Dictionary)["actor_id"] = "player.2"
		_reseal_projection(owner_leak)
		var owner_leak_sources := _sources.duplicate(true)
		owner_leak_sources["card_batch"] = owner_leak
		_expect(
			_adapter.adapt_player_projection(
				_capability,
				_context,
				owner_leak_sources
			).is_empty(),
			"resealed anonymous queue owner identity fails the closed PR79 contract"
		)
	var rival_asset_leak := (
		_sources.get("six_color_assets", {}) as Dictionary
	).duplicate(true)
	rival_asset_leak["other_exact_assets"] = {"player.1": _assets(5)}
	_reseal_projection(rival_asset_leak)
	var rival_asset_leak_sources := _sources.duplicate(true)
	rival_asset_leak_sources["six_color_assets"] = rival_asset_leak
	_expect(
		_adapter.adapt_player_projection(
			_capability,
			_context,
			rival_asset_leak_sources
		).is_empty(),
		"resealed rival exact assets fail the closed PR79 contract"
	)
	var debug: Dictionary = _adapter.debug_snapshot()
	_expect(
		debug.get("mutates_core") == false
			and debug.get("consumes_rng") == false
			and debug.get("capability_is_projection_data") == false,
		"adapter owns no Core mutation, RNG, or serialized capability"
	)


func _action_for_player(player_index: int) -> Dictionary:
	var cost := _zero_cost()
	cost[str(ADAPTER.COLOR_IDS[player_index])] = 1
	var action_id := "action.canonical.player.%d" % player_index
	return ASSET_BATCH_CORE.build_prebound_action(
		action_id,
		"normal_card",
		"source.canonical.player.%d" % player_index,
		0,
		"card.canonical.player.%d" % player_index,
		ASSET_BATCH_CORE.build_target_binding(
			"binding.canonical.player.%d" % player_index,
			["target.public.%d" % player_index],
			1
		),
		"effect.canonical.player.%d" % player_index,
		cost,
		_zero_assets()
	)


func _reseal_track_projection(projection: Dictionary) -> void:
	projection.erase("projection_fingerprint")
	var source_facts := {
		"schema_version": projection.get("schema_version"),
		"domain_id": projection.get("domain_id"),
		"source_revision": projection.get("source_revision"),
		"viewer_actor_id": projection.get("viewer_actor_id"),
		"public_facts": projection.get("public_facts"),
		"viewer_private_facts": projection.get("viewer_private_facts"),
	}
	projection["source_core_fingerprint"] = WIRE.fingerprint(source_facts)
	projection["projection_fingerprint"] = WIRE.fingerprint(projection)


func _reseal_projection(projection: Dictionary) -> void:
	projection.erase("projection_fingerprint")
	projection["projection_fingerprint"] = WIRE.fingerprint(projection)


func _assets(amount: int) -> Dictionary:
	return {
		"life": amount,
		"energy": amount,
		"industry": amount,
		"technology": amount,
		"commerce": amount,
		"shipping": amount,
	}


func _zero_assets() -> Dictionary:
	return _assets(0)


func _zero_cost() -> Dictionary:
	var cost := _zero_assets()
	cost["any"] = 0
	return cost


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"V072_CANONICAL_PLAYER_PROJECTION_ADAPTER_READY | status=PASS | checks=%d"
			% _checks
		)
		quit(0)
		return
	for failure in _failures:
		push_error("V072_CANONICAL_PLAYER_PROJECTION_ADAPTER_FAIL: %s" % failure)
	quit(1)
