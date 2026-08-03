extends SceneTree

const ADAPTER := preload(
	"res://scripts/v07_adapters/v07_canonical_ai_observation_adapter.gd"
)
const CODEC := preload(
	"res://scripts/v07_adapters/v07_canonical_data_codec.gd"
)
const TRACK_CORE := preload(
	"res://scripts/v07_semantic/v07_unified_card_track_core.gd"
)
const DBG_CORE := preload("res://scripts/v07_semantic/v07_dbg_deck_core.gd")
const ASSET_BATCH_CORE := preload(
	"res://scripts/v07_semantic/v07_asset_batch_core.gd"
)
const SOLAR_CORE := preload(
	"res://scripts/v07_semantic/v07_solar_victory_core.gd"
)

const MATCH_ID := "match.canonical.ai.reference"
const MATCH_GENERATION := 4
const VIEWER_ID := "player.0"
const RIVAL_ID := "player.1"
const THIRD_ID := "player.2"
const PLAYERS := [VIEWER_ID, RIVAL_ID, THIRD_ID]
const AUTHORIZATION_REVISION := 11
const SOURCE_REVISION := 41
const BATCH_ID := "batch.canonical.ai.reference"

var _checks := 0
var _failures: Array[String] = []
var _track_core: Variant
var _dbg_core: Variant
var _rival_dbg_core: Variant
var _asset_state: Dictionary = {}
var _solar_state: Dictionary = {}
var _sources: Dictionary = {}
var _context: Dictionary = {}
var _stale_track_observation: Dictionary = {}
var _rival_track_observation: Dictionary = {}
var _rival_dbg_observation: Dictionary = {}
var _capability: RefCounted
var _adapter: Variant
var _observation: Dictionary = {}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_build_fixture()
	if _sources.is_empty() or _context.is_empty():
		_finish()
		return
	_test_canonical_happy_path()
	_test_opaque_capability_and_forged_sources()
	_test_stale_match_authorization_and_sources()
	_test_rival_observation_rejection()
	_test_recursive_privacy_boundary()
	_finish()


func _build_fixture() -> void:
	_track_core = TRACK_CORE.new()
	var track_started: Dictionary = _track_core.start_match(
		PLAYERS,
		1701,
		{"match_instance_id": MATCH_ID}
	)
	_expect(
		bool(track_started.get("accepted", false)),
		"track fixture starts one explicit match"
	)
	_stale_track_observation = _track_core.ai_observation_v1(VIEWER_ID)
	var stance_intent: Dictionary = _track_core.build_intent_v1(
		"request.canonical.ai.stance",
		VIEWER_ID,
		TRACK_CORE.ACTION_SET_STANCE,
		{"increase_color": "life", "decrease_color": "shipping"}
	)
	var stance_receipt: Dictionary = _track_core.apply_intent_v1(stance_intent)
	_expect(
		bool(stance_receipt.get("accepted", false)),
		"track fixture advances the authorized source revision"
	)
	var track_observation: Dictionary = _track_core.ai_observation_v1(VIEWER_ID)
	_rival_track_observation = _track_core.ai_observation_v1(RIVAL_ID)

	_dbg_core = DBG_CORE.new()
	var dbg_started: Dictionary = _dbg_core.initialize(VIEWER_ID, 99173)
	_expect(
		bool(dbg_started.get("initialized", false)),
		"DBG fixture initializes the authorized private Core"
	)
	var dbg_observation: Dictionary = _dbg_ai_observation(_dbg_core, VIEWER_ID)
	_rival_dbg_core = DBG_CORE.new()
	var rival_dbg_started: Dictionary = _rival_dbg_core.initialize(
		RIVAL_ID,
		99173
	)
	_expect(
		bool(rival_dbg_started.get("initialized", false)),
		"rival DBG fixture initializes independently"
	)
	_rival_dbg_observation = _dbg_ai_observation(_rival_dbg_core, RIVAL_ID)

	var initial_assets := {
		VIEWER_ID: _assets(3),
		RIVAL_ID: _assets(5),
		THIRD_ID: _assets(1),
	}
	_asset_state = ASSET_BATCH_CORE.create_state(
		BATCH_ID,
		PLAYERS,
		[THIRD_ID, VIEWER_ID, RIVAL_ID],
		initial_assets,
		{},
		1000,
		1000
	)
	_expect(
		bool(ASSET_BATCH_CORE.validation_report(_asset_state).get(
			"valid",
			false
		)),
		"Asset/Batch fixture is valid shared Core data"
	)
	var asset_observation := ASSET_BATCH_CORE.asset_ai_observation(
		_asset_state,
		VIEWER_ID
	)
	var batch_observation := ASSET_BATCH_CORE.batch_ai_observation(
		_asset_state,
		VIEWER_ID
	)
	_solar_state = SOLAR_CORE.create_state(true, 3, MATCH_ID)
	_expect(
		SOLAR_CORE.is_valid_state(_solar_state),
		"Solar/Victory fixture is valid Core data"
	)
	var solar_observation := SOLAR_CORE.ai_observation(_solar_state)
	var contention_observation := _contention_observation(
		"v073.facility_contention.ai_observation.v1", VIEWER_ID
	)

	_sources = {
		"unified_track": track_observation,
		"personal_dbg": dbg_observation,
		"six_color_assets": asset_observation,
		"card_batch": batch_observation,
		"facility_contention": contention_observation,
		"solar_victory": solar_observation,
	}
	_context = ADAPTER.build_authorization_context(
		MATCH_ID,
		MATCH_GENERATION,
		VIEWER_ID,
		AUTHORIZATION_REVISION,
		SOURCE_REVISION,
		track_observation,
		dbg_observation,
		asset_observation,
		batch_observation,
		contention_observation,
		solar_observation
	)
	_expect(
		not _context.is_empty(),
		"adapter builds an exact six-source authorization context"
	)
	_capability = ADAPTER.issue_capability()
	_adapter = ADAPTER.new(_capability)
	_expect(
		_adapter.bind_authorization(_capability, _context),
		"exact opaque capability binds the current authorization"
	)


func _test_canonical_happy_path() -> void:
	var track_before: Dictionary = _track_core.core_authority_v1()
	var dbg_before: Dictionary = _dbg_core.core_authority_snapshot()
	var assets_before := _asset_state.duplicate(true)
	var solar_before := _solar_state.duplicate(true)
	_observation = _adapter.adapt_ai_observation(
		_capability,
		_context,
		_sources
	)
	_expect(
		not _observation.is_empty(),
		"authorized PR79 AI observations adapt into one canonical envelope"
	)
	_expect(
		bool(ADAPTER.validation_report(_observation).get("valid", false)),
		"canonical AI observation validates as detached pure data"
	)
	_expect(
		ADAPTER.matches_authorization(
			_observation,
			MATCH_ID,
			MATCH_GENERATION,
			VIEWER_ID,
			AUTHORIZATION_REVISION,
			SOURCE_REVISION
		),
		"canonical observation binds match, generation, viewer, and revisions"
	)
	_expect(
		_observation.get("unified_track") == _sources.get("unified_track")
			and _observation.get("personal_dbg") == _sources.get("personal_dbg")
			and _observation.get("six_color_assets") \
				== _sources.get("six_color_assets")
			and _observation.get("card_batch") == _sources.get("card_batch")
			and _observation.get("facility_contention") \
				== _sources.get("facility_contention")
			and _observation.get("solar_victory") \
				== _sources.get("solar_victory"),
		"adapter wraps all six observations without recomputation"
	)
	var dbg_facts := (
		_observation.get("personal_dbg", {}) as Dictionary
	).get("facts", {}) as Dictionary
	var owned_cards_ready := true
	for card_variant in dbg_facts.get("hand", []) as Array:
		var card := card_variant as Dictionary
		owned_cards_ready = owned_cards_ready \
			and card.has("definition_id") \
			and card.has("origin_class") \
			and card.has("asset_cost") \
			and card.has("merge_family_id") \
			and card.has("level") \
			and (card.get("legal_targets", []) as Array).size() == 1
	_expect(
		owned_cards_ready
			and (_observation.get("personal_dbg", {}) as Dictionary).get(
				"legal_target_authority_id"
			) == "v072.map.legal_target_authority.detached",
		"canonical AI preserves authority-attested legal targets for owned cards"
	)
	_expect(
		_track_core.core_authority_v1() == track_before
			and _dbg_core.core_authority_snapshot() == dbg_before
			and _asset_state == assets_before
			and _solar_state == solar_before,
		"adaptation mutates no shared Core facts"
	)
	var duplicate: Dictionary = _adapter.adapt_ai_observation(
		_capability,
		_context,
		_sources
	)
	_expect(
		duplicate == _observation
			and _adapter.last_reason_code() == "observation_duplicate",
		"same authorized source is deterministic and idempotent"
	)
	var detached := ADAPTER.detached_copy(_observation)
	(detached.get("component_source_revisions") as Dictionary)[
		"unified_track"
	] = 999
	_expect(
		int((_observation.get("component_source_revisions") as Dictionary).get(
			"unified_track",
			-1
		)) != 999,
		"canonical copies are deeply detached"
	)
	var debug: Dictionary = _adapter.debug_snapshot()
	_expect(
		CODEC.is_pure_data(debug)
			and not bool(debug.get("mutates_core", true))
			and not bool(debug.get("consumes_rng", true))
			and not bool(debug.get("stores_observation_payloads", true)),
		"debug state is metadata-only and owns no Core or RNG channel"
	)


func _test_opaque_capability_and_forged_sources() -> void:
	var forged_capability := ADAPTER.issue_capability()
	_expect(
		_adapter.adapt_ai_observation(
			forged_capability,
			_context,
			_sources
		).is_empty()
			and _adapter.last_reason_code() == "capability_rejected",
		"same-type forged capability fails exact object identity"
	)
	_expect(
		_adapter.adapt_ai_observation(
			RefCounted.new(),
			_context,
			_sources
		).is_empty(),
		"generic RefCounted cannot substitute for the issued capability"
	)
	_expect(
		not CODEC.is_pure_data(_capability)
			and not _capability.has_method("to_dictionary"),
		"opaque capability has no wire representation"
	)

	var resealed_track := (
		_sources.get("unified_track", {}) as Dictionary
	).duplicate(true)
	var track_public := resealed_track.get("public_facts", {}) as Dictionary
	track_public["unified_track_item_count"] = int(
		track_public.get("unified_track_item_count", 0)
	) + 1
	_reseal_track_observation(resealed_track)
	var forged_track_sources := _sources.duplicate(true)
	forged_track_sources["unified_track"] = resealed_track
	_expect(
		_adapter.adapt_ai_observation(
			_capability,
			_context,
			forged_track_sources
		).is_empty()
			and _adapter.last_reason_code() == "track_observation_forged",
		"fully resealed Track facts miss the authorized source fingerprint"
	)

	var resealed_dbg := (
		_sources.get("personal_dbg", {}) as Dictionary
	).duplicate(true)
	var dbg_facts := resealed_dbg.get("facts", {}) as Dictionary
	dbg_facts["draw_pile_count"] = int(dbg_facts.get("draw_pile_count", 0)) + 1
	resealed_dbg["facts_fingerprint"] = DBG_CORE._fingerprint(dbg_facts)
	var forged_dbg_sources := _sources.duplicate(true)
	forged_dbg_sources["personal_dbg"] = resealed_dbg
	_expect(
		_adapter.adapt_ai_observation(
			_capability,
			_context,
			forged_dbg_sources
		).is_empty()
			and _adapter.last_reason_code() == "dbg_observation_invalid",
		"fully resealed inconsistent DBG counts fail semantic validation first"
	)

	var resealed_assets := (
		_sources.get("six_color_assets", {}) as Dictionary
	).duplicate(true)
	(resealed_assets.get("own_exact_assets") as Dictionary)["life"] = int(
		(resealed_assets.get("own_exact_assets") as Dictionary).get("life", 0)
	) + 1
	(resealed_assets.get("own_available_assets") as Dictionary)["life"] = int(
		(resealed_assets.get("own_available_assets") as Dictionary).get(
			"life",
			0
		)
	) + 1
	_reseal_domain_observation(resealed_assets)
	var forged_asset_sources := _sources.duplicate(true)
	forged_asset_sources["six_color_assets"] = resealed_assets
	_expect(
		_adapter.adapt_ai_observation(
			_capability,
			_context,
			forged_asset_sources
		).is_empty()
			and _adapter.last_reason_code() == "asset_observation_forged",
		"fully resealed Asset facts miss the authorized projection fingerprint"
	)

	var forged_solar := (
		_sources.get("solar_victory", {}) as Dictionary
	).duplicate(true)
	forged_solar["victory_pending"] = not bool(
		forged_solar.get("victory_pending", false)
	)
	var forged_solar_sources := _sources.duplicate(true)
	forged_solar_sources["solar_victory"] = forged_solar
	_expect(
		_adapter.adapt_ai_observation(
			_capability,
			_context,
			forged_solar_sources
		).is_empty()
			and _adapter.last_reason_code() == "solar_observation_forged",
		"shape-valid Solar fact substitution misses its authorization digest"
	)


func _test_stale_match_authorization_and_sources() -> void:
	var wrong_match := _context.duplicate(true)
	wrong_match["match_instance_id"] = "match.canonical.ai.other"
	_expect(
		_adapter.adapt_ai_observation(
			_capability,
			wrong_match,
			_sources
		).is_empty()
			and _adapter.last_reason_code() == "match_instance_mismatch",
		"cross-match authorization is rejected"
	)
	var stale_generation := _context.duplicate(true)
	stale_generation["match_generation"] = MATCH_GENERATION - 1
	_expect(
		_adapter.adapt_ai_observation(
			_capability,
			stale_generation,
			_sources
		).is_empty()
			and _adapter.last_reason_code() == "match_generation_stale",
		"stale match generation is rejected"
	)
	var stale_authorization := _context.duplicate(true)
	stale_authorization["authorization_revision"] = AUTHORIZATION_REVISION - 1
	_expect(
		_adapter.adapt_ai_observation(
			_capability,
			stale_authorization,
			_sources
		).is_empty()
			and _adapter.last_reason_code() == "authorization_revision_stale",
		"stale viewer authorization revision is rejected"
	)
	var stale_source := _context.duplicate(true)
	stale_source["source_revision"] = SOURCE_REVISION - 1
	_expect(
		_adapter.adapt_ai_observation(
			_capability,
			stale_source,
			_sources
		).is_empty()
			and _adapter.last_reason_code() == "source_revision_stale",
		"stale canonical source revision is rejected"
	)

	var stale_track_sources := _sources.duplicate(true)
	stale_track_sources["unified_track"] = _stale_track_observation
	_expect(
		_adapter.adapt_ai_observation(
			_capability,
			_context,
			stale_track_sources
		).is_empty()
			and _adapter.last_reason_code() == "track_source_revision_stale",
		"stale component source revision is rejected"
	)

	var local_capability := ADAPTER.issue_capability()
	var local_adapter = ADAPTER.new(local_capability)
	_expect(
		local_adapter.bind_authorization(local_capability, _context),
		"fresh adapter binds the baseline authorization"
	)
	var next_context := _context.duplicate(true)
	next_context["source_revision"] = SOURCE_REVISION + 1
	_expect(
		local_adapter.bind_authorization(local_capability, next_context),
		"monotonic source revision can rebind without Core duplication"
	)
	_expect(
		local_adapter.adapt_ai_observation(
			local_capability,
			_context,
			_sources
		).is_empty()
			and local_adapter.last_reason_code() == "source_revision_stale",
		"old context cannot replay after monotonic source rebinding"
	)
	var next_generation := next_context.duplicate(true)
	next_generation["match_generation"] = MATCH_GENERATION + 1
	next_generation["authorization_revision"] = AUTHORIZATION_REVISION + 1
	_expect(
		local_adapter.bind_authorization(local_capability, next_generation),
		"new match generation requires and accepts rotated authorization"
	)
	_expect(
		not local_adapter.bind_authorization(local_capability, next_context)
			and local_adapter.last_reason_code() == "match_generation_stale",
		"generation rollback cannot rebind"
	)


func _test_rival_observation_rejection() -> void:
	var rival_track_sources := _sources.duplicate(true)
	rival_track_sources["unified_track"] = _rival_track_observation
	_expect(
		_adapter.adapt_ai_observation(
			_capability,
			_context,
			rival_track_sources
		).is_empty()
			and _adapter.last_reason_code() == "track_viewer_binding_invalid",
		"rival Track segment observation is rejected"
	)

	var rival_dbg_sources := _sources.duplicate(true)
	rival_dbg_sources["personal_dbg"] = _rival_dbg_observation
	_expect(
		_adapter.adapt_ai_observation(
			_capability,
			_context,
			rival_dbg_sources
		).is_empty()
			and _adapter.last_reason_code() == "dbg_rival_observation_rejected",
		"DBG instance lineage prevents relabeling a rival private hand"
	)

	var rival_asset_sources := _sources.duplicate(true)
	rival_asset_sources["six_color_assets"] = (
		ASSET_BATCH_CORE.asset_ai_observation(_asset_state, RIVAL_ID)
	)
	_expect(
		_adapter.adapt_ai_observation(
			_capability,
			_context,
			rival_asset_sources
		).is_empty()
			and _adapter.last_reason_code() == "rival_observation_rejected",
		"rival exact assets are rejected"
	)

	var rival_batch_sources := _sources.duplicate(true)
	rival_batch_sources["card_batch"] = (
		ASSET_BATCH_CORE.batch_ai_observation(_asset_state, RIVAL_ID)
	)
	_expect(
		_adapter.adapt_ai_observation(
			_capability,
			_context,
			rival_batch_sources
		).is_empty()
			and _adapter.last_reason_code() == "rival_observation_rejected",
		"rival private batch queue is rejected"
	)
	var serialized := CODEC.canonical_json(_observation)
	_expect(
		not serialized.contains("dbg.%s." % RIVAL_ID)
			and not serialized.contains(str(
				_rival_dbg_observation.get("facts_fingerprint", "")
			)),
		"canonical output contains no rival DBG identity or private digest"
	)


func _test_recursive_privacy_boundary() -> void:
	var track_leak := (
		_sources.get("unified_track", {}) as Dictionary
	).duplicate(true)
	(track_leak.get("viewer_private_facts") as Dictionary)[
		"future_supply_bags"
	] = {"private.sentinel.track": true}
	_reseal_track_observation(track_leak)
	var track_leak_sources := _sources.duplicate(true)
	track_leak_sources["unified_track"] = track_leak
	_expect(
		_adapter.adapt_ai_observation(
			_capability,
			_context,
			track_leak_sources
		).is_empty(),
		"recursive Track authority secret fails closed after resealing"
	)

	var dbg_leak := (
		_sources.get("personal_dbg", {}) as Dictionary
	).duplicate(true)
	var dbg_facts := dbg_leak.get("facts", {}) as Dictionary
	dbg_facts["other_hand"] = ["private.sentinel.dbg"]
	dbg_leak["facts_fingerprint"] = DBG_CORE._fingerprint(dbg_facts)
	var dbg_leak_sources := _sources.duplicate(true)
	dbg_leak_sources["personal_dbg"] = dbg_leak
	_expect(
		_adapter.adapt_ai_observation(
			_capability,
			_context,
			dbg_leak_sources
		).is_empty(),
		"recursive rival DBG hand fails closed after resealing"
	)

	var asset_leak := (
		_sources.get("six_color_assets", {}) as Dictionary
	).duplicate(true)
	asset_leak["other_exact_assets"] = {RIVAL_ID: _assets(6)}
	_reseal_domain_observation(asset_leak)
	var asset_leak_sources := _sources.duplicate(true)
	asset_leak_sources["six_color_assets"] = asset_leak
	_expect(
		_adapter.adapt_ai_observation(
			_capability,
			_context,
			asset_leak_sources
		).is_empty(),
		"recursive rival Asset facts fail closed after resealing"
	)

	var solar_leak := (
		_sources.get("solar_victory", {}) as Dictionary
	).duplicate(true)
	solar_leak["authority_capability"] = "private.sentinel.solar"
	var solar_leak_sources := _sources.duplicate(true)
	solar_leak_sources["solar_victory"] = solar_leak
	_expect(
		_adapter.adapt_ai_observation(
			_capability,
			_context,
			solar_leak_sources
		).is_empty(),
		"Solar proof capability can never enter canonical observation data"
	)

	var all_forbidden: Array = []
	all_forbidden.append_array(ADAPTER.SOURCE_FORBIDDEN_KEYS)
	all_forbidden.append_array(ADAPTER.TRACK_FORBIDDEN_KEYS)
	all_forbidden.append_array(ADAPTER.DBG_FORBIDDEN_KEYS)
	all_forbidden.append_array(ADAPTER.ASSET_BATCH_FORBIDDEN_KEYS)
	all_forbidden.append_array(ADAPTER.SOLAR_FORBIDDEN_KEYS)
	_expect(
		not _contains_key_recursive(_observation, all_forbidden),
		"valid canonical output recursively excludes every private deny-list key"
	)
	var serialized := CODEC.canonical_json(_observation)
	for sentinel in [
		"private.sentinel.track",
		"private.sentinel.dbg",
		"private.sentinel.solar",
	]:
		_expect(
			not serialized.contains(sentinel),
			"canonical output excludes %s" % sentinel
		)


func _reseal_track_observation(observation: Dictionary) -> void:
	var source_facts := {
		"schema_version": observation.get("schema_version"),
		"domain_id": observation.get("domain_id"),
		"source_revision": observation.get("source_revision"),
		"viewer_actor_id": observation.get("viewer_actor_id"),
		"public_facts": observation.get("public_facts"),
		"viewer_private_facts": observation.get("viewer_private_facts"),
	}
	observation["source_core_fingerprint"] = TRACK_CORE.fingerprint(source_facts)
	observation.erase("projection_fingerprint")
	observation["projection_fingerprint"] = TRACK_CORE.fingerprint(observation)


func _reseal_domain_observation(observation: Dictionary) -> void:
	observation.erase("projection_fingerprint")
	observation["projection_fingerprint"] = ASSET_BATCH_CORE._fingerprint(
		observation
	)


func _dbg_ai_observation(core: RefCounted, owner_id: String) -> Dictionary:
	var projection := core.call("player_projection", owner_id) as Dictionary
	var facts := projection.get("facts", {}) as Dictionary
	var targets := {}
	var index := 0
	for zone_name in ["hand", "discard"]:
		for card_variant in facts.get(zone_name, []) as Array:
			var instance_id := str(
				(card_variant as Dictionary).get("instance_id", "")
			)
			targets[instance_id] = ["region.adapter.%02d" % index]
			index += 1
	var input := core.call(
		"build_legal_target_input",
		owner_id,
		"v072.map.legal_target_authority.detached",
		11,
		targets
	) as Dictionary
	return core.call("ai_observation", owner_id, input) as Dictionary


func _assets(amount: int) -> Dictionary:
	return {
		"life": amount,
		"energy": amount,
		"industry": amount,
		"technology": amount,
		"commerce": amount,
		"shipping": amount,
	}


func _contention_observation(contract_id: String, viewer_id: String) -> Dictionary:
	return CODEC.seal({
		"schema_version": 1,
		"state_version": 1,
		"ruleset_id": "v0.7.3",
		"contract_id": contract_id,
		"viewer_id": viewer_id,
		"batch_id": BATCH_ID,
		"state_revision": 1,
		"own_local_queue": [],
		"anonymous_public_queue": [],
		"public_facility_slots": [],
		"resolution_cursor": 0,
		"complete_hidden_order_disclosed": false,
	}, "projection_fingerprint")


func _contains_key_recursive(value: Variant, forbidden_keys: Array) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			if str(key_variant) in forbidden_keys \
					or _contains_key_recursive(
						(value as Dictionary).get(key_variant),
						forbidden_keys
					):
				return true
	elif value is Array:
		for item_variant in value as Array:
			if _contains_key_recursive(item_variant, forbidden_keys):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print(
			"V073_CANONICAL_AI_OBSERVATION_ADAPTER_READY | passed=%d total=%d"
			% [_checks, _checks]
		)
		quit(0)
		return
	for failure in _failures:
		push_error("V073_CANONICAL_AI_OBSERVATION_ADAPTER_FAIL: %s" % failure)
	push_error(
		"V073_CANONICAL_AI_OBSERVATION_ADAPTER_FAIL | passed=%d total=%d"
		% [_checks - _failures.size(), _checks]
	)
	quit(1)
