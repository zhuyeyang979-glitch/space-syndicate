extends SceneTree

## Focused Phase 7 sound, motion, settings and performance gate.
##
## FIXTURE_CLASS=PRESENTATION_FIXTURE
## NATURAL_GAMEPLAY=false
## HUMAN_GREEN=false
##
## This fixture instantiates the production main scene and consumes only
## presentation APIs.  It does not start a match, author a gameplay receipt,
## advance Tick, draw rules RNG, or mutate card/facility/map authority.

const FIXTURE_CLASS := "PRESENTATION_FIXTURE"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const CUE_CATALOG_PATH := (
	"res://data/presentation/v076_animation_cue_catalog.json"
)
const SOUND_ROUTE_PATH := (
	"res://data/presentation/v076_sound_cue_routes.json"
)
const AUDIO_CONTRACT_PATH := (
	"res://resources/audio/commercial/commercial_audio_event_map.json"
)
const MARKER_SCENE_PATH := "res://scenes/ui/map/PlanetCityMarker.tscn"
const MAP_EFFECT_SCENE_PATH := "res://scenes/ui/map/PlanetMapEventEffect.tscn"

const MASTER_SOUND_CUE_IDS := [
	"CARD_ACQUIRE_SFX",
	"CARD_ENTER_DECK_SFX",
	"DECK_SHUFFLE_SFX",
	"CARD_DRAW_SFX",
	"CARD_PLAY_SFX",
	"CARD_RESOLVE_SFX",
	"CARD_FIZZLE_SFX",
	"FACILITY_BUILD_SFX",
	"MONSTER_ATTACK_SFX",
	"MONSTER_HIT_SFX",
	"MILITARY_ARRIVE_SFX",
	"MILITARY_WITHDRAW_SFX",
	"TRACK_HANDOFF_SFX",
	"UI_CONFIRM_SFX",
	"UI_CANCEL_SFX",
]
const VIEWPORT_CASES := [
	{"label": "1366x768", "size": Vector2i(1366, 768)},
	{"label": "1600x960", "size": Vector2i(1600, 960)},
	{"label": "1920x1080", "size": Vector2i(1920, 1080)},
]
const FULL_FLASH_LIMIT := 0.65
const REDUCED_FLASH_LIMIT := 0.28
const IDLE_FRAME_P95_LIMIT_MS := 18.0
const ANIMATION_FRAME_P95_LIMIT_MS := 22.0
const INPUT_RESPONSE_P95_LIMIT_MS := 100.0
const OUTSIDE_LOADING_STALL_LIMIT_MS := 250.0
const PERFORMANCE_FRAME_COUNT := 180
const EXPECTED_CATALOG_SOUND_CUE_COUNT := 23
const EXPECTED_ROUTE_COUNT := 25
const EXPECTED_AUDIO_EVENT_COUNT := 17

var _checks := 0
var _failures: Array[String] = []
var _catalog: Dictionary = {}
var _route_contract: Dictionary = {}
var _audio_contract: Dictionary = {}
var _route_by_id: Dictionary = {}
var _catalog_sound_cue_ids: Array[String] = []
var _route_ids: Array[String] = []
var _director_sound_requests: Array[Dictionary] = []
var _settings_signal_snapshots: Array[Dictionary] = []
var _viewport_rows: Array[Dictionary] = []
var _zero_boundary_violations: Array[String] = []
var _performance_snapshot: Dictionary = {}

var _application: Control
var _screen: Control
var _flow: Node
var _menu_lifecycle: Node
var _director: Node
var _audio_host: Node
var _deck: Control
var _combat: Control
var _map_view: Control
var _authority_snapshot_before: Dictionary = {}
var _authority_snapshot_hash_before := ""
var _original_root_size := Vector2i.ZERO
var _original_content_scale_size := Vector2i.ZERO


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_original_root_size = root.size
	_original_content_scale_size = root.content_scale_size
	_expect(FIXTURE_CLASS == "PRESENTATION_FIXTURE", "fixture identity is explicit")
	_audit_sound_contracts()
	await _compose_production_main()
	if _screen == null or _director == null or _audio_host == null:
		await _cleanup()
		_finish()
		return
	_audit_production_audio_composition()
	_audit_runtime_sound_routes()
	_audit_director_motion_policies()
	await _audit_settings_to_screen_chain()
	await _audit_map_marker_effect_policy()
	await _audit_responsive_viewports()
	await _audit_performance_samples()
	_audit_zero_authority_boundary()
	await _cleanup()
	_finish()


func _audit_sound_contracts() -> void:
	_catalog = _read_json_dictionary(CUE_CATALOG_PATH)
	_route_contract = _read_json_dictionary(SOUND_ROUTE_PATH)
	_audio_contract = _read_json_dictionary(AUDIO_CONTRACT_PATH)
	_expect(not _catalog.is_empty(), "animation cue catalog parses")
	_expect(not _route_contract.is_empty(), "V076 sound route contract parses")
	_expect(not _audio_contract.is_empty(), "commercial audio contract parses")

	var audio_event_ids: Dictionary = {}
	for event_variant: Variant in _audio_contract.get("events", []) as Array:
		if not (event_variant is Dictionary):
			continue
		var event: Dictionary = event_variant as Dictionary
		var event_id := str(event.get("event_id", "")).strip_edges()
		if not event_id.is_empty():
			audio_event_ids[event_id] = true
	_expect(
		audio_event_ids.size() == EXPECTED_AUDIO_EVENT_COUNT,
		"commercial audio contract retains all 17 canonical events"
	)
	_expect(
		str(_route_contract.get("contract_id", ""))
			== "space_syndicate.v076.sound_cue_routes.v1",
		"sound route contract identity is stable"
	)
	_expect(
		bool(_route_contract.get("presentation_only", false))
			and not bool(_route_contract.get("randomize", true))
			and int(_route_contract.get("rules_rng_draw_count", -1)) == 0
			and int(_route_contract.get("gameplay_mutation_count", -1)) == 0,
		"sound route contract is deterministic presentation-only data"
	)
	var silent_placeholder := (
		_route_contract.get("silent_placeholder", {}) as Dictionary
	)
	_expect(
		str(_route_contract.get("unknown_route_policy", ""))
			== "SILENT_REGISTERED_PLACEHOLDER"
			and bool(silent_placeholder.get("registered", false))
			and str(silent_placeholder.get("route_mode", ""))
				== "SILENT_REGISTERED_PLACEHOLDER",
		"unknown Sound Cue has one explicit registered silent placeholder"
	)

	_route_by_id.clear()
	for route_variant: Variant in _route_contract.get("routes", []) as Array:
		_expect(route_variant is Dictionary, "every sound route row is typed")
		if not (route_variant is Dictionary):
			continue
		var route: Dictionary = route_variant as Dictionary
		var sound_cue_id := str(route.get("sound_cue_id", "")).strip_edges()
		var route_mode := str(route.get("route_mode", ""))
		_expect(
			not sound_cue_id.is_empty()
				and sound_cue_id == sound_cue_id.to_upper()
				and sound_cue_id.ends_with("_SFX")
				and not _route_by_id.has(sound_cue_id),
			"sound route id is unique uppercase SFX: %s" % sound_cue_id
		)
		_expect(
			["CANONICAL_EVENT", "SILENT_REGISTERED_PLACEHOLDER"].has(
				route_mode
			),
			"sound route mode is registered: %s" % sound_cue_id
		)
		if route_mode == "CANONICAL_EVENT":
			var canonical_event_id := str(route.get(
				"canonical_event_id",
				""
			)).strip_edges()
			_expect(
				audio_event_ids.has(canonical_event_id),
				"canonical audio event exists for %s" % sound_cue_id
			)
			var selector_routes := (
				route.get("canonical_event_by_selector", {}) as Dictionary
			)
			for selector_event_variant: Variant in selector_routes.values():
				_expect(
					audio_event_ids.has(str(selector_event_variant)),
					"selector audio event exists for %s" % sound_cue_id
				)
		else:
			_expect(
				bool(route.get("registered", false)),
				"silent sound route is explicitly registered: %s" % sound_cue_id
			)
		_route_by_id[sound_cue_id] = route.duplicate(true)
	_route_ids.clear()
	for route_id_variant: Variant in _route_by_id.keys():
		_route_ids.append(str(route_id_variant))
	_route_ids.sort()
	_expect(
		_route_by_id.size() == EXPECTED_ROUTE_COUNT
			and int(_route_contract.get("registered_route_count", 0))
				== EXPECTED_ROUTE_COUNT,
		"all 25 Sound Cue routes are registered exactly once"
	)

	var required_ids := _route_contract.get(
		"required_sound_cue_ids",
		[]
	) as Array
	_expect(
		required_ids.size() == MASTER_SOUND_CUE_IDS.size(),
		"master Sound Cue list contains exactly 15 ids"
	)
	for master_id_variant: Variant in MASTER_SOUND_CUE_IDS:
		var master_id := str(master_id_variant)
		_expect(
			_array_has_string(required_ids, master_id)
				and _route_by_id.has(master_id),
			"master Sound Cue route is covered: %s" % master_id
		)

	var catalog_distinct: Dictionary = {}
	for cue_variant: Variant in _catalog.get("cues", []) as Array:
		_expect(cue_variant is Dictionary, "every animation cue row is typed")
		if not (cue_variant is Dictionary):
			continue
		var cue: Dictionary = cue_variant as Dictionary
		var sound_cue_id := str(cue.get("sound_cue_id", "")).strip_edges()
		if not sound_cue_id.is_empty():
			catalog_distinct[sound_cue_id] = true
	_catalog_sound_cue_ids.clear()
	for sound_id_variant: Variant in catalog_distinct.keys():
		_catalog_sound_cue_ids.append(str(sound_id_variant))
	_catalog_sound_cue_ids.sort()
	_expect(
		_catalog_sound_cue_ids.size() == EXPECTED_CATALOG_SOUND_CUE_COUNT
			and int(_route_contract.get("catalog_sound_cue_count", 0))
				== EXPECTED_CATALOG_SOUND_CUE_COUNT,
		"catalog exposes the expected 23 distinct Sound Cue ids"
	)
	for catalog_sound_id in _catalog_sound_cue_ids:
		_expect(
			_route_by_id.has(catalog_sound_id),
			"catalog Sound Cue has a canonical or registered silent route: %s"
				% catalog_sound_id
		)


func _compose_production_main() -> void:
	var baseline := Vector2i(1600, 960)
	root.content_scale_size = baseline
	root.size = baseline
	var packed := load(MAIN_SCENE_PATH) as PackedScene
	_expect(packed != null, "production main.tscn loads")
	if packed == null:
		return
	_application = packed.instantiate() as Control
	_expect(_application != null, "production main.tscn instantiates")
	if _application == null:
		return
	root.add_child(_application)
	_screen = _application.get_node_or_null("V075GameScreen") as Control
	_flow = _application.get_node_or_null("V075RuntimeComposition") as Node
	_menu_lifecycle = _application.get_node_or_null(
		"CommercialMenuLifecycleApplicationFlowController"
	) as Node
	if _screen != null:
		_director = _screen.get_node_or_null(
			"V076PresentationAnimationDirector"
		) as Node
		_audio_host = _screen.get_node_or_null(
			"CommercialAudioPresentationHost"
		) as Node
		_deck = _screen.find_child(
			"V076DeckLifecyclePresentation",
			true,
			false
		) as Control
		_combat = _screen.find_child("CombatSurface", true, false) as Control
		_map_view = _screen.find_child("PlanetMapView", true, false) as Control
	if _director != null and _director.has_method("set_loading_active"):
		# Startup, settings composition and viewport rearrangement are explicitly
		# loading/setup work. They must not create outside-loading stall evidence.
		_director.call("set_loading_active", true)
	await _frames(12)
	_expect(_screen != null, "production V075 GameScreen is composed")
	_expect(_flow != null, "production V075 RuntimeComposition is composed")
	_expect(_menu_lifecycle != null, "production MenuLifecycle is composed")
	_expect(_director != null, "one production animation Director is composed")
	_expect(_audio_host != null, "one production commercial Audio Host is composed")
	_expect(_deck != null, "production Deck lifecycle consumer is composed")
	_expect(_combat != null, "production Combat presentation consumer is composed")
	_expect(_map_view != null, "production Planet Map presentation consumer is composed")
	if _flow != null and _flow.has_method("local_snapshot"):
		_authority_snapshot_before = (
			_flow.call("local_snapshot") as Dictionary
		).duplicate(true)
		_authority_snapshot_hash_before = _variant_hash(
			_authority_snapshot_before
		)


func _audit_production_audio_composition() -> void:
	_expect(_director.has_signal("sound_cue_requested"), "Director exposes the typed Sound Cue signal")
	var callback := Callable(self, "_on_director_sound_cue_requested")
	if (
		_director.has_signal("sound_cue_requested")
		and not _director.is_connected("sound_cue_requested", callback)
	):
		_director.connect("sound_cue_requested", callback)
	var route_snapshot := _audio_host.call(
		"sound_cue_route_snapshot"
	) as Dictionary
	var audio_debug := _audio_host.call("debug_snapshot") as Dictionary
	_expect(bool(route_snapshot.get("ready", false)), "production Audio Host loads the Sound Cue contract")
	_expect(str(route_snapshot.get("failure_reason", "")) == "", "production Sound Cue contract has no failure")
	_expect((route_snapshot.get("route_ids", []) as Array).size() == EXPECTED_ROUTE_COUNT, "production Audio Host exposes 25 registered routes")
	_expect((route_snapshot.get("required_sound_cue_ids", []) as Array).size() == MASTER_SOUND_CUE_IDS.size(), "production Audio Host exposes all 15 master routes")
	_expect(bool(route_snapshot.get("silent_placeholder_registered", false)), "production Audio Host keeps the silent placeholder registered")
	_expect(bool(audio_debug.get("animation_director_bound", false)), "production Audio Host is bound to the unique Director")
	_expect(str(audio_debug.get("animation_director_signal", "")) == "sound_cue_requested", "Audio Host consumes Director sound_cue_requested")
	_expect(float(audio_debug.get("required_sound_cue_coverage_percent", 0.0)) == 100.0, "production master Sound Cue coverage is 100 percent")
	_expect(int(audio_debug.get("sound_cue_route_count", 0)) == EXPECTED_ROUTE_COUNT, "production Audio Host has no parallel or missing route")
	var sfx_debug := audio_debug.get("sfx", {}) as Dictionary
	_expect(bool(sfx_debug.get("service_ready", false)), "commercial SFX service and registry are ready")
	_expect(int(sfx_debug.get("voice_pool_size", 0)) == 4, "commercial SFX uses the bounded four-voice pool")
	_expect(bool(sfx_debug.get("sfx_bus_present", false)) and bool(audio_debug.get("music_bus_present", false)), "Music and SFX buses are present")
	_expect(bool(audio_debug.get("presentation_only", false)) and not bool(audio_debug.get("mutates_gameplay", true)), "production Audio Host remains presentation-only")


func _audit_runtime_sound_routes() -> void:
	var routed_before := int((_audio_host.call("debug_snapshot") as Dictionary).get(
		"sound_cue_request_count",
		0
	))
	for index in range(_route_ids.size()):
		var sound_cue_id := _route_ids[index]
		var result := _audio_host.call("route_sound_cue", sound_cue_id, {
			"receipt_id": "phase7.fixture.route.%03d" % index,
			"cue_id": "PHASE7_ROUTE_PROBE",
			"facility_type": "factory",
			"projection": {"facility_type": "factory"},
		}) as Dictionary
		_expect(bool(result.get("accepted", false)), "runtime route accepts or explicitly silences %s" % sound_cue_id)
		_expect(["CANONICAL_EVENT", "SILENT_REGISTERED_PLACEHOLDER"].has(str(result.get("route_mode", ""))), "runtime route mode is bounded for %s" % sound_cue_id)
		_expect(bool(result.get("presentation_only", false)), "runtime route remains presentation-only for %s" % sound_cue_id)
		_expect(int(result.get("rules_rng_draw_count", -1)) == 0 and int(result.get("gameplay_mutation_count", -1)) == 0, "runtime route has zero RNG/gameplay mutation for %s" % sound_cue_id)

	var facility_expected := {
		"factory": "facility.factory_build",
		"market": "facility.market_build",
		"warehouse": "facility.warehouse_build",
	}
	for facility_type_variant: Variant in facility_expected.keys():
		var facility_type := str(facility_type_variant)
		var result := _audio_host.call("route_sound_cue", "FACILITY_BUILD_SFX", {
			"receipt_id": "phase7.fixture.facility.%s" % facility_type,
			"cue_id": "FACILITY_BUILD",
			"projection": {"facility_type": facility_type},
		}) as Dictionary
		_expect(bool(result.get("accepted", false)) and str(result.get("canonical_event_id", "")) == str(facility_expected.get(facility_type, "")), "facility Sound Cue selects the registered %s event" % facility_type)

	var unknown := _audio_host.call("route_sound_cue", "PHASE7_UNKNOWN_SFX", {
		"receipt_id": "phase7.fixture.unknown",
		"cue_id": "PHASE7_UNKNOWN",
	}) as Dictionary
	_expect(bool(unknown.get("accepted", false)) and bool(unknown.get("silent", false)), "unknown Sound Cue fails closed through registered silence")
	_expect(str(unknown.get("route_mode", "")) == "SILENT_REGISTERED_PLACEHOLDER" and bool(unknown.get("registered_placeholder", false)), "unknown Sound Cue cannot invent an audio event")
	var after := _audio_host.call("debug_snapshot") as Dictionary
	_expect(int(after.get("sound_cue_request_count", 0)) >= routed_before + EXPECTED_ROUTE_COUNT + 4, "production Audio Host records every route probe")
	_expect(int(after.get("sound_cue_rejection_count", 0)) == 0, "registered runtime Sound Cue routes produce no rejection")


func _audit_director_motion_policies() -> void:
	_expect(_director.has_method("apply_presentation_policy"), "Director exposes presentation policy input")
	_expect(_director.has_method("presentation_policy_snapshot"), "Director exposes presentation policy evidence")
	var full_result := _director.call("apply_presentation_policy", {
		"reduced_motion": false,
		"screen_shake": true,
	}, false) as Dictionary
	_expect(bool(full_result.get("accepted", false)), "Director accepts full-motion production policy")
	var full_policy := _director.call("presentation_policy_snapshot") as Dictionary
	_expect(str(full_policy.get("motion_mode", "")) == "FULL_MOTION", "Director enters full-motion mode")
	_expect(not bool(full_policy.get("reduced_motion", true)) and not bool(full_policy.get("instant_test_mode", true)), "full-motion policy is neither reduced nor instant")

	var sound_count_before := _director_sound_requests.size()
	var cue_rows := _catalog.get("cues", []) as Array
	for cue_index in range(cue_rows.size()):
		var cue := cue_rows[cue_index] as Dictionary
		var queued := _queue_policy_probe(cue, "full", cue_index)
		var cue_id := str(cue.get("cue_id", ""))
		_expect(not queued.is_empty(), "full-motion Director queues %s" % cue_id)
		if queued.is_empty():
			continue
		_expect(int(queued.get("duration_ms", -1)) == int(cue.get("duration_ms", -2)), "full-motion duration matches catalog for %s" % cue_id)
		_expect(str(queued.get("effective_motion_path", "")) == str(cue.get("motion_path", "")), "full-motion path matches catalog for %s" % cue_id)
		_expect(str(queued.get("effective_screen_shake_profile", "")) == str(cue.get("screen_shake_profile", "none")), "full-motion shake matches catalog for %s" % cue_id)
		_expect(int(queued.get("effective_hit_stop_ms", -1)) == int(cue.get("hit_stop_ms", 0)), "full-motion hit stop matches catalog for %s" % cue_id)
		_expect(float(queued.get("effective_flash_intensity", -1.0)) <= FULL_FLASH_LIMIT, "full-motion flash remains bounded for %s" % cue_id)
		_expect(bool(_director.call(
			"finish_receipt",
			str(queued.get("receipt_id", ""))
		)), "full-motion Director finishes %s exactly once" % cue_id)
	_expect(_director_sound_requests.size() == sound_count_before + cue_rows.size(), "every catalog cue emits one typed Sound Cue request in full motion")

	var reduced_result := _director.call("apply_presentation_policy", {
		"reduced_motion": true,
		"screen_shake": true,
	}, false) as Dictionary
	_expect(bool(reduced_result.get("accepted", false)), "Director accepts reduced-motion production policy")
	var reduced_policy := _director.call("presentation_policy_snapshot") as Dictionary
	_expect(str(reduced_policy.get("motion_mode", "")) == "REDUCED_MOTION", "Director enters reduced-motion mode")
	_expect(not bool(reduced_policy.get("screen_shake_enabled", true)), "reduced motion disables screen shake")
	for cue_index in range(cue_rows.size()):
		var cue := cue_rows[cue_index] as Dictionary
		var queued := _queue_policy_probe(cue, "reduced", cue_index)
		var cue_id := str(cue.get("cue_id", ""))
		_expect(not queued.is_empty(), "reduced-motion Director queues %s" % cue_id)
		if queued.is_empty():
			continue
		_expect(int(queued.get("duration_ms", -1)) == int(cue.get("reduced_motion_duration_ms", -2)), "reduced duration matches catalog for %s" % cue_id)
		_expect(str(queued.get("effective_motion_path", "")) == "reduced_fade_pulse", "reduced motion removes large travel for %s" % cue_id)
		_expect(str(queued.get("effective_screen_shake_profile", "invalid")) == "none", "reduced motion removes shake for %s" % cue_id)
		_expect(int(queued.get("effective_hit_stop_ms", -1)) == 0, "reduced motion removes hit stop for %s" % cue_id)
		_expect(float(queued.get("effective_flash_intensity", -1.0)) <= REDUCED_FLASH_LIMIT, "reduced flash remains bounded for %s" % cue_id)
		_expect(bool(_director.call(
			"finish_receipt",
			str(queued.get("receipt_id", ""))
		)), "reduced-motion Director finishes %s exactly once" % cue_id)
	_expect(_director_sound_requests.size() == sound_count_before + cue_rows.size() * 2, "every catalog cue emits one typed Sound Cue request in both policies")

	var rejected_instant := _director.call("apply_presentation_policy", {
		"reduced_motion": false,
		"screen_shake": true,
		"instant_test_mode": true,
	}, false) as Dictionary
	_expect(not bool(rejected_instant.get("accepted", true)) and str(rejected_instant.get("reason_code", "")) == "instant_test_mode_production_unreachable", "Director rejects Instant Test Mode from production callers")
	var fixture_instant := _director.call("apply_presentation_policy", {
		"reduced_motion": false,
		"screen_shake": false,
		"instant_test_mode": true,
	}, true) as Dictionary
	_expect(bool(fixture_instant.get("accepted", false)) and str((fixture_instant.get("policy", {}) as Dictionary).get("motion_mode", "")) == "INSTANT_TEST_MODE", "only an explicit fixture caller can enter Instant Test Mode")
	_director.call("apply_presentation_policy", {
		"reduced_motion": true,
		"screen_shake": true,
	}, false)
	var debug := _director.call("animation_debug_snapshot") as Dictionary
	_expect(int(debug.get("queued_cue_count", -1)) == 0, "Director queue drains after policy probes")
	_expect(int(debug.get("animation_gameplay_mutation_count", -1)) == 0 and int(debug.get("animation_rng_draw_delta", -1)) == 0 and int(debug.get("animation_authority_sequence_delta", -1)) == 0, "Director policy probes have zero gameplay/RNG/authority delta")


func _queue_policy_probe(cue: Dictionary, mode: String, index: int) -> Dictionary:
	var cue_id := str(cue.get("cue_id", ""))
	var expected_sound := str(cue.get("sound_cue_id", ""))
	var signal_count_before := _director_sound_requests.size()
	var queued := _director.call("enqueue_receipt", {
		"receipt_id": "phase7.fixture.policy.%s.%03d" % [mode, index],
		"receipt_kind": str(cue.get("receipt_kind", "phase7_fixture")),
		"cue_id": cue_id,
		"presentation_only": true,
	}, {
		"current_player_authorized": true,
		"public_label": "Phase 7 presentation fixture",
	}) as Dictionary
	_expect(_director_sound_requests.size() == signal_count_before + 1, "%s emits one sound signal" % cue_id)
	if _director_sound_requests.size() > signal_count_before:
		var observed := _director_sound_requests[-1]
		_expect(str(observed.get("sound_cue_id", "")) == expected_sound and str(observed.get("cue_id", "")) == cue_id, "%s sound signal preserves its catalog identity" % cue_id)
	return queued


func _audit_settings_to_screen_chain() -> void:
	_expect(_menu_lifecycle.has_signal("presentation_settings_changed"), "MenuLifecycle exposes the session settings signal")
	var settings_callback := Callable(self, "_on_presentation_settings_changed")
	if (
		_menu_lifecycle.has_signal("presentation_settings_changed")
		and not _menu_lifecycle.is_connected(
			"presentation_settings_changed",
			settings_callback
		)
	):
		_menu_lifecycle.connect(
			"presentation_settings_changed",
			settings_callback
		)
	var signal_count_before := _settings_signal_snapshots.size()
	var started_usec := Time.get_ticks_usec()
	_menu_lifecycle.call("_open_settings")
	await _frames(4)
	var settings_surface := _menu_lifecycle.get("_settings_surface") as Control
	_expect(settings_surface != null, "production MenuLifecycle opens the real Settings surface")
	if settings_surface == null:
		return
	var reduced_toggle := settings_surface.find_child(
		"ReducedMotion",
		true,
		false
	) as CheckButton
	var shake_toggle := settings_surface.find_child(
		"ScreenShake",
		true,
		false
	) as CheckButton
	var master_volume := settings_surface.find_child(
		"MasterVolume",
		true,
		false
	) as Range
	var music_volume := settings_surface.find_child(
		"MusicVolume",
		true,
		false
	) as Range
	var sfx_volume := settings_surface.find_child(
		"SfxVolume",
		true,
		false
	) as Range
	var apply_button := settings_surface.find_child(
		"ApplySettingsButton",
		true,
		false
	) as Button
	_expect(reduced_toggle != null and shake_toggle != null and master_volume != null and music_volume != null and sfx_volume != null and apply_button != null, "production Settings controls are reachable")
	if apply_button == null or reduced_toggle == null or shake_toggle == null:
		return
	reduced_toggle.button_pressed = true
	shake_toggle.button_pressed = true
	if master_volume != null:
		master_volume.value = 91.0
	if music_volume != null:
		music_volume.value = 67.0
	if sfx_volume != null:
		sfx_volume.value = 73.0
	apply_button.pressed.emit()
	var menu_elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	await _frames(4)
	_screen.call("record_presentation_input_response", "menu", menu_elapsed_ms)
	_expect(_settings_signal_snapshots.size() == signal_count_before + 1, "Settings emits one session snapshot through MenuLifecycle")

	var menu_debug := _menu_lifecycle.call("debug_snapshot") as Dictionary
	var screen_debug := _screen.call("combat_debug_snapshot") as Dictionary
	var settings_debug := settings_surface.call("debug_snapshot") as Dictionary
	var consumers := screen_debug.get(
		"presentation_settings_consumers",
		{}
	) as Dictionary
	_expect(int(menu_debug.get("presentation_settings_owner_count", 0)) == 1 and bool(menu_debug.get("presentation_settings_session_only", false)), "MenuLifecycle remains the single session settings owner")
	_expect(int(screen_debug.get("presentation_settings_owner_count", -1)) == 0, "production Screen consumes settings without becoming an owner")
	_expect(int(screen_debug.get("presentation_settings_consumer_count", 0)) == 6, "production Screen propagates settings to all six presentation consumers")
	for consumer_id in ["director", "deck", "combat", "facility_map", "track", "audio"]:
		_expect(bool(consumers.get(consumer_id, false)), "Settings reaches production %s consumer" % consumer_id)
	_expect(bool(settings_debug.get("presentation_only", false)) and not bool(settings_debug.get("owns_gameplay_state", true)) and not bool(settings_debug.get("owns_rng", true)) and not bool(settings_debug.get("owns_save_data", true)), "Settings surface owns no gameplay, RNG or save state")

	var director_policy := _director.call("presentation_policy_snapshot") as Dictionary
	var deck_debug := _deck.call("debug_snapshot") as Dictionary
	var combat_debug := _combat.call("debug_snapshot") as Dictionary
	var combat_policy := combat_debug.get("presentation_motion_policy", {}) as Dictionary
	var map_policy := _map_view.call("presentation_motion_policy_snapshot") as Dictionary
	var track_policy := _screen.call("track_presentation_policy_snapshot") as Dictionary
	var audio_debug := _audio_host.call("debug_snapshot") as Dictionary
	print("V076_PHASE7_SETTINGS_CHAIN_DEBUG %s" % JSON.stringify({
		"menu": menu_debug.get("presentation_settings", {}),
		"screen": screen_debug.get("presentation_settings", {}),
		"consumers": consumers,
		"director": director_policy,
		"deck_reduced": deck_debug.get("reduced_motion", null),
		"combat": combat_policy,
		"map": map_policy,
		"track": track_policy,
		"audio": audio_debug.get("last_audio_settings", {}),
	}))
	_expect(bool(director_policy.get("reduced_motion", false)) and not bool(director_policy.get("instant_test_mode", true)), "Settings applies reduced motion to Director")
	_expect(bool(deck_debug.get("reduced_motion", false)) and not bool(deck_debug.get("instant_test_mode", true)), "Settings applies reduced motion to Deck")
	_expect(bool(combat_policy.get("reduced_motion", false)) and not bool(combat_policy.get("screen_shake_enabled", true)), "Settings applies reduced motion/no shake to Combat")
	_expect(bool(map_policy.get("reduced_motion", false)) and not bool(map_policy.get("screen_shake_enabled", true)) and not bool(map_policy.get("instant_test_mode", true)), "Settings applies reduced motion/no shake to Facility Map")
	_expect(bool(track_policy.get("reduced_motion", false)) and not bool(track_policy.get("instant_test_mode", true)), "Settings applies reduced motion to Track")
	var audio_settings := audio_debug.get("last_audio_settings", {}) as Dictionary
	_expect(is_equal_approx(float(audio_settings.get("master_volume", -1.0)), 0.91) and is_equal_approx(float(audio_settings.get("music_volume", -1.0)), 0.67) and is_equal_approx(float(audio_settings.get("sfx_volume", -1.0)), 0.73), "Settings applies Master/Music/SFX values to Audio Host")

	var surface_reject := settings_surface.call("load_settings_snapshot", {
		"instant_test_mode": true,
	}) as Dictionary
	_expect(not bool(surface_reject.get("accepted", true)) and str(surface_reject.get("reason_code", "")) == "instant_test_mode_production_unreachable", "Settings surface rejects Instant Test Mode")
	var menu_revision_before := int(menu_debug.get("presentation_settings_revision", 0))
	_menu_lifecycle.call("_on_commercial_settings_changed", {
		"instant_test_mode": true,
	})
	var menu_after_reject := _menu_lifecycle.call("debug_snapshot") as Dictionary
	_expect(int(menu_after_reject.get("presentation_settings_revision", -1)) == menu_revision_before and str(menu_after_reject.get("last_presentation_settings_reason", "")) == "instant_test_mode_production_unreachable", "MenuLifecycle rejects Instant Test Mode without revising session settings")
	var screen_reject := _screen.call("apply_presentation_settings", {
		"instant_test_mode": true,
	}) as Dictionary
	_expect(not bool(screen_reject.get("accepted", true)) and str(screen_reject.get("reason_code", "")) == "instant_test_mode_production_unreachable", "production Screen rejects Instant Test Mode")
	var audio_reject := _audio_host.call("apply_presentation_settings", {
		"instant_test_mode": true,
	}) as Dictionary
	_expect(not bool(audio_reject.get("accepted", true)) and str(audio_reject.get("reason_code", "")) == "instant_test_mode_production_unreachable", "production Audio Host rejects Instant Test Mode")
	_expect(_instant_control_count(settings_surface) == 0, "production Settings UI exposes no Instant Test control")
	_expect(not bool(settings_debug.get("instant_test_mode_production_ui_reachable", true)) and not bool(menu_after_reject.get("instant_test_mode_production_ui_reachable", true)) and not bool(screen_debug.get("production_ui_instant_test_mode_reachable", true)), "all production settings surfaces report Instant Test unreachable")


func _audit_map_marker_effect_policy() -> void:
	var marker_packed := load(MARKER_SCENE_PATH) as PackedScene
	var effect_packed := load(MAP_EFFECT_SCENE_PATH) as PackedScene
	_expect(marker_packed != null, "production Facility marker scene loads")
	_expect(effect_packed != null, "production Map event effect scene loads")
	var marker := marker_packed.instantiate() as Control if marker_packed != null else null
	var effect := effect_packed.instantiate() as Control if effect_packed != null else null
	if marker != null:
		root.add_child(marker)
	if effect != null:
		root.add_child(effect)
	await _frames(2)
	if marker != null:
		marker.call("set_presentation_motion_policy", true, true, false)
		var marker_debug := marker.call("debug_snapshot") as Dictionary
		var marker_policy := marker_debug.get("presentation_motion_policy", {}) as Dictionary
		_expect(bool(marker_policy.get("reduced_motion", false)) and not bool(marker_policy.get("instant_test_mode", true)) and not bool(marker_policy.get("screen_shake_enabled", true)), "Facility marker consumes reduced-motion/no-shake policy")
		_collect_zero_boundary_violations(marker_debug, "marker")
	if effect != null:
		effect.call("set_presentation_motion_policy", true, true, false)
		var effect_debug := effect.call("debug_snapshot") as Dictionary
		_expect(bool(effect_debug.get("reduced_motion", false)) and not bool(effect_debug.get("instant_test_mode", true)) and str(effect_debug.get("screen_shake_profile", "invalid")) == "none", "Map event effect consumes reduced-motion/no-shake policy")
		_collect_zero_boundary_violations(effect_debug, "map_effect")
	if marker != null:
		marker.queue_free()
	if effect != null:
		effect.queue_free()
	await _frames(2)


func _audit_responsive_viewports() -> void:
	for case_variant: Variant in VIEWPORT_CASES:
		var case: Dictionary = case_variant as Dictionary
		var label := str(case.get("label", "viewport"))
		var requested_size := case.get("size", Vector2i.ZERO) as Vector2i
		root.content_scale_size = requested_size
		root.size = requested_size
		await _frames(8)
		var audit := _screen.call(
			"v075_responsive_geometry_audit"
		) as Dictionary
		var runtime_size := Vector2i(_screen.get_viewport_rect().size)
		var critical_occlusion_count := int(audit.get(
			"primary_planet_occlusion_count",
			1
		)) + int(audit.get("planet_right_half_occlusion_count", 1))
		var structural_occlusion_count := int(audit.get(
			"track_panel_overlap_count",
			1
		)) + int(audit.get("dock_panel_overlap_count", 1)) + int(audit.get(
			"asset_reserve_lane_overlap_count",
			1
		))
		_expect(runtime_size == requested_size, "%s uses the requested production viewport" % label)
		_expect(str(audit.get("geometry_source", "")) == "instantiated_production_controls", "%s layout evidence comes from real Controls" % label)
		_expect(critical_occlusion_count == 0, "%s has zero critical map occlusion" % label)
		_expect(structural_occlusion_count == 0, "%s has zero Track/Dock/Asset occlusion" % label)
		_expect(int(audit.get("panel_viewport_overflow_count", 1)) == 0 and int(audit.get("panel_safe_area_overflow_count", 1)) == 0, "%s presentation panel remains inside the viewport" % label)
		_expect(int(audit.get("ui_child_collision_count", 1)) == 0 and bool(audit.get("root_scroll_disabled", false)), "%s fixed table remains collision-free without root scrolling" % label)
		_viewport_rows.append({
			"label": label,
			"runtime_size": runtime_size,
			"layout_mode": str(audit.get("layout_mode", "")),
			"critical_map_occlusion_count": critical_occlusion_count,
			"structural_occlusion_count": structural_occlusion_count,
			"ui_child_collision_count": int(audit.get(
				"ui_child_collision_count",
				-1
			)),
		})
	_expect(_viewport_rows.size() == VIEWPORT_CASES.size(), "all three commercial viewport cases are audited")


func _audit_performance_samples() -> void:
	root.content_scale_size = Vector2i(1600, 960)
	root.size = Vector2i(1600, 960)
	await _frames(8)
	_director.call("set_loading_active", false)
	await _frames(PERFORMANCE_FRAME_COUNT)
	var sound_count_before := _director_sound_requests.size()
	var started_usec := Time.get_ticks_usec()
	var animation_probe := _director.call("enqueue_receipt", {
		"receipt_id": "phase7.fixture.performance.card_select",
		"receipt_kind": "phase7_performance_probe",
		"cue_id": "CARD_SELECT",
		"presentation_only": true,
	}, {
		"current_player_authorized": true,
		"public_label": "Phase 7 performance fixture",
	}) as Dictionary
	var card_elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
	_screen.call("record_presentation_input_response", "card", card_elapsed_ms)
	_expect(not animation_probe.is_empty(), "card response probe enters the production Director")
	_expect(_director_sound_requests.size() == sound_count_before + 1, "card response probe emits one Sound Cue request")
	await _frames(PERFORMANCE_FRAME_COUNT)
	_expect(bool(_director.call(
		"finish_receipt",
		"phase7.fixture.performance.card_select"
	)), "card response performance receipt finishes exactly once")
	await _frames(30)
	var performance := _director.call("performance_snapshot") as Dictionary
	_performance_snapshot = performance.duplicate(true)
	_expect(int(performance.get("idle_frame_sample_count", 0)) >= PERFORMANCE_FRAME_COUNT, "Director records bounded idle frame samples")
	_expect(int(performance.get("animation_frame_sample_count", 0)) >= PERFORMANCE_FRAME_COUNT, "Director records bounded animation frame samples")
	_expect(int(performance.get("card_input_response_sample_count", 0)) >= 1, "Director records card response samples")
	_expect(int(performance.get("menu_input_response_sample_count", 0)) >= 1, "Director records menu response samples")
	_expect(float(performance.get("idle_frame_p95_ms", INF)) <= IDLE_FRAME_P95_LIMIT_MS, "idle frame P95 is at most 18 ms")
	_expect(float(performance.get("animation_frame_p95_ms", INF)) <= ANIMATION_FRAME_P95_LIMIT_MS, "animation frame P95 is at most 22 ms")
	_expect(float(performance.get("card_input_response_p95_ms", INF)) <= INPUT_RESPONSE_P95_LIMIT_MS, "card response P95 is at most 100 ms")
	_expect(float(performance.get("menu_input_response_p95_ms", INF)) <= INPUT_RESPONSE_P95_LIMIT_MS, "menu response P95 is at most 100 ms")
	_expect(is_equal_approx(float(performance.get("outside_loading_stall_threshold_ms", 0.0)), OUTSIDE_LOADING_STALL_LIMIT_MS) and int(performance.get("outside_loading_stall_count", -1)) == 0, "outside loading there are no frames above 250 ms")


func _audit_zero_authority_boundary() -> void:
	var authority_after: Dictionary = {}
	if _flow != null and _flow.has_method("local_snapshot"):
		authority_after = (_flow.call("local_snapshot") as Dictionary).duplicate(true)
	_expect(not _authority_snapshot_hash_before.is_empty() and _variant_hash(authority_after) == _authority_snapshot_hash_before, "Phase 7 presentation probes leave the full authority snapshot unchanged")
	_collect_zero_boundary_violations(
		_director.call("animation_debug_snapshot") as Dictionary,
		"director"
	)
	_collect_zero_boundary_violations(
		_screen.call("combat_debug_snapshot") as Dictionary,
		"screen"
	)
	_collect_zero_boundary_violations(
		_audio_host.call("debug_snapshot") as Dictionary,
		"audio"
	)
	_collect_zero_boundary_violations(
		_map_view.call("v074_planet_debug_snapshot") as Dictionary,
		"map"
	)
	_collect_zero_boundary_violations(
		_deck.call("debug_snapshot") as Dictionary,
		"deck"
	)
	_collect_zero_boundary_violations(
		_combat.call("debug_snapshot") as Dictionary,
		"combat"
	)
	_expect(_zero_boundary_violations.is_empty(), "all presentation consumers report zero gameplay/RNG/authority mutation")


func _collect_zero_boundary_violations(
	value: Variant,
	path: String
) -> void:
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant: Variant in dictionary.keys():
			var key := str(key_variant)
			var child: Variant = dictionary.get(key_variant)
			var normalized := key.to_lower()
			if _is_zero_boundary_key(normalized):
				if typeof(child) in [TYPE_INT, TYPE_FLOAT] and not is_zero_approx(float(child)):
					_zero_boundary_violations.append("%s.%s=%s" % [path, key, str(child)])
			_collect_zero_boundary_violations(child, "%s.%s" % [path, key])
	elif value is Array:
		var children := value as Array
		for index in range(children.size()):
			_collect_zero_boundary_violations(children[index], "%s[%d]" % [path, index])


func _is_zero_boundary_key(normalized: String) -> bool:
	return (
		normalized == "rules_rng_draw_count"
		or normalized.contains("gameplay_mutation_count")
		or normalized.contains("rng_draw_delta")
		or normalized.contains("authority_sequence_delta")
		or normalized.contains("deck_order_mutation_count")
		or normalized.contains("card_zone_mutation_count")
		or normalized.contains("facility_state_mutation_count")
	)


func _instant_control_count(surface: Control) -> int:
	var count := 0
	var nodes: Array[Node] = [surface]
	nodes.append_array(surface.find_children("*", "Control", true, false))
	for node in nodes:
		var searchable := str(node.name).to_lower()
		if node is Button:
			searchable += " " + (node as Button).text.to_lower()
		if node is Control:
			searchable += " " + (node as Control).tooltip_text.to_lower()
		if "instant" in searchable or "瞬时" in searchable or "瞬間" in searchable:
			count += 1
	return count


func _read_json_dictionary(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _array_has_string(values: Array, expected: String) -> bool:
	for value_variant: Variant in values:
		if str(value_variant) == expected:
			return true
	return false


func _variant_hash(value: Variant) -> String:
	return JSON.stringify(value, "", true).sha256_text()


func _on_director_sound_cue_requested(
	sound_cue_id: String,
	cue: Dictionary
) -> void:
	_director_sound_requests.append({
		"sound_cue_id": sound_cue_id,
		"cue_id": str(cue.get("cue_id", "")),
		"receipt_id": str(cue.get("receipt_id", "")),
	})


func _on_presentation_settings_changed(snapshot: Dictionary) -> void:
	_settings_signal_snapshots.append(snapshot.duplicate(true))


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _cleanup() -> void:
	root.content_scale_size = _original_content_scale_size
	root.size = _original_root_size
	if _application != null and is_instance_valid(_application):
		_application.queue_free()
	await _frames(4)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print((
		"V076_PHASE7_SOUND_MOTION_PERFORMANCE_GATE"
		+ "|status=%s|fixture_class=%s|natural_gameplay=false|human_green=false"
		+ "|checks=%d|passed=%d|catalog_sound_cues=%d|routes=%d"
		+ "|viewport_cases=%d|sound_requests=%d|zero_boundary_violations=%s"
		+ "|idle_p95_ms=%.3f|animation_p95_ms=%.3f"
		+ "|card_response_p95_ms=%.3f|menu_response_p95_ms=%.3f|stalls=%d"
		+ "|failures=%s"
		) % [
			status,
			FIXTURE_CLASS,
			_checks,
			_checks - _failures.size(),
			_catalog_sound_cue_ids.size(),
			_route_ids.size(),
			_viewport_rows.size(),
			_director_sound_requests.size(),
			JSON.stringify(_zero_boundary_violations),
			float(_performance_snapshot.get("idle_frame_p95_ms", 0.0)),
			float(_performance_snapshot.get("animation_frame_p95_ms", 0.0)),
			float(_performance_snapshot.get("card_input_response_p95_ms", 0.0)),
			float(_performance_snapshot.get("menu_input_response_p95_ms", 0.0)),
			int(_performance_snapshot.get("outside_loading_stall_count", -1)),
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
