extends SceneTree

const EVENT_CONTRACT_PATH := "res://resources/audio/commercial/commercial_audio_event_map.json"
const MUSIC_CONTRACT_PATH := "res://resources/audio/commercial/commercial_music_playlist.json"
const EVENT_MAP_PATH := "res://data/audio/audio_event_map.json"
const SFX_SCENE_PATH := "res://scenes/runtime/presentation/CommercialAudioPresentationService.tscn"
const MUSIC_SCENE_PATH := "res://scenes/runtime/presentation/CommercialMusicPresentationController.tscn"
const REGISTRY_SCRIPT := preload("res://scripts/audio/audio_event_registry.gd")
const BUS_SCRIPT := preload("res://scripts/audio/audio_event_bus.gd")
const CATALOG_RESOURCE_SCRIPT := preload("res://scripts/presentation/card_illustration_catalog_resource.gd")

const EXPECTED_ALIASES := {
	"ui_hover": "ui.hover",
	"ui_click": "ui.confirm",
	"card_pickup": "card.select",
	"card_drop_valid": "card.drop",
	"card_drop_invalid": "ui.cancel",
	"card_play": "card.drop",
	"card_reveal": "card.select",
	"bid_update": "ui.confirm",
	"monster_spawn": "monster.spawn",
	"monster_move": "monster.move",
	"monster_attack": "monster.attack",
	"city_damage": "city.damage",
	"route_damage": "route.damage",
	"cash_gain": "cash.gain",
	"gdp_delta": "gdp.delta",
	"final_countdown": "final.countdown",
}

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var event_contract := _parse_json(EVENT_CONTRACT_PATH)
	var music_contract := _parse_json(MUSIC_CONTRACT_PATH)
	var catalog := _catalog_from_contracts(event_contract, music_contract)
	_test_registry(event_contract)
	await _test_bus_and_sfx_service(catalog)
	await _test_music_controller(catalog, music_contract)
	_test_static_boundaries()
	catalog = null
	await process_frame
	_finish()


func _test_registry(event_contract: Dictionary) -> void:
	var registry: Variant = REGISTRY_SCRIPT.new()
	registry.call("load_default")
	var report: Dictionary = registry.call("validation_report")
	_expect(bool(report.get("valid", false)), "registry merges the commercial contract")
	_expect(int(report.get("commercial_event_count", 0)) == 17, "registry exposes exactly 17 commercial canonical events")
	_expect(int(report.get("legacy_alias_count", 0)) == 16, "registry preserves exactly 16 legacy aliases")
	_expect(not bool(report.get("contains_resource_paths", true)), "registry stores no resource paths")
	for alias_id in EXPECTED_ALIASES:
		var expected_canonical := str(EXPECTED_ALIASES[alias_id])
		_expect(bool(registry.call("has_event", alias_id)), "%s alias remains registered" % alias_id)
		var definition: Dictionary = registry.call("event_definition", alias_id)
		_expect(str(definition.get("canonical_id", "")) == expected_canonical, "%s resolves to %s" % [alias_id, expected_canonical])
		_expect(bool(definition.get("legacy_alias", false)), "%s is marked as a legacy alias" % alias_id)
		_expect(not JSON.stringify(definition).contains("res://"), "%s public definition has no resource path" % alias_id)
	var rows: Array = event_contract.get("events", [])
	for row_variant in rows:
		var row: Dictionary = row_variant
		var event_id := str(row.get("event_id", ""))
		var definition: Dictionary = registry.call("event_definition", event_id)
		_expect(str(definition.get("mode", "")) == "commercial", "%s is a commercial canonical event" % event_id)
		_expect(str(definition.get("asset_key", "")) == str(row.get("asset_key", "")), "%s exposes only the stable asset key" % event_id)
		_expect(is_equal_approx(float(definition.get("volume_db", 99.0)), float(row.get("gain_db", 0.0))), "%s volume comes from the commercial contract" % event_id)
		_expect(bool(definition.get("loop", true)) == bool(row.get("loop", false)), "%s loop comes from the commercial contract" % event_id)
	var silent_definition: Dictionary = registry.call("event_definition", "monster_spawn")
	_expect(str(silent_definition.get("canonical_id", "")) == "monster.spawn" and str(silent_definition.get("mode", "")) == "silent", "unselected monster spawn alias stays semantically correct and silent")
	var unknown: Dictionary = registry.call("event_definition", "private.unlisted")
	_expect(str(unknown.get("mode", "")) == "silent" and str(unknown.get("asset_key", "x")).is_empty(), "unknown event fails closed")


func _test_bus_and_sfx_service(catalog: CardIllustrationCatalogResource) -> void:
	var packed := load(SFX_SCENE_PATH) as PackedScene
	_expect(packed != null, "commercial SFX scene loads")
	if packed == null:
		return
	var service := packed.instantiate()
	root.add_child(service)
	await process_frame
	var missing_catalog_result := bool(service.call("play_event", "ui.hover"))
	var snapshot: Dictionary = service.call("debug_snapshot")
	_expect(not missing_catalog_result and str(snapshot.get("last_failure_reason", "")) == "catalog_missing", "SFX service fails closed without a Catalog")
	_expect(bool(snapshot.get("contract_ready", false)) and not bool(snapshot.get("catalog_bound", true)), "SFX service can validate its contract without pretending the Catalog exists")
	service.call("set_catalog_resource", catalog)
	_expect(bool(service.call("play_event", "ui.hover")), "SFX service resolves canonical event through Catalog generic API")
	snapshot = service.call("debug_snapshot")
	_expect(str(snapshot.get("last_asset_key", "")) == "audio.ui.hover", "SFX service reports only stable asset key")
	_expect(int(snapshot.get("play_count", 0)) == 1 and bool(snapshot.get("player_playing", false)), "SFX service plays through its editable AudioStreamPlayer")
	_expect(not JSON.stringify(snapshot).contains("res://") and not JSON.stringify(snapshot).contains("third_party"), "SFX snapshot exposes no resource or vendor path")
	_expect(not bool(snapshot.get("randomized_selection", true)) and int(snapshot.get("rules_rng_draw_count", -1)) == 0, "SFX selection is fixed and RNG-free")
	var bus: AudioEventBus = BUS_SCRIPT.new()
	root.add_child(bus)
	await process_frame
	_expect(bool(service.call("bind_event_bus", bus)), "SFX service binds the existing AudioEventBus")
	var record := bus.emit_audio_event("card_pickup", {
		"source": "public_test",
		"stream_path": "res://private/vendor.ogg",
		"nested": {"unsafe_value": "assets/third_party/private/vendor.ogg"},
	})
	_expect(str(record.get("id", "")) == "card_pickup" and str(record.get("canonical_id", "")) == "card.select", "bus preserves requested alias and emits canonical ID")
	_expect(str(record.get("asset_key", "")) == "audio.card.select" and is_equal_approx(float(record.get("volume_db", 0.0)), -8.0) and not bool(record.get("loop", true)), "bus output contains asset key, volume, and loop")
	_expect(not JSON.stringify(record).contains("res://") and not JSON.stringify(record).contains("third_party"), "bus output leaks no resource or vendor path")
	_expect(not (record.get("payload", {}) as Dictionary).has("stream_path") \
			and str(((record.get("payload", {}) as Dictionary).get("nested", {}) as Dictionary).get("unsafe_value", "")) == "[redacted]", "bus recursively redacts caller-supplied path data")
	await process_frame
	snapshot = service.call("debug_snapshot")
	_expect(int(snapshot.get("play_count", 0)) == 2 and str(snapshot.get("last_canonical_event_id", "")) == "card.select", "bound SFX service consumes canonical bus event")
	var unknown := bus.emit_audio_event("private.unlisted")
	_expect(str(unknown.get("mode", "")) == "silent" and str(unknown.get("asset_key", "x")).is_empty(), "bus fails closed for an unlisted event")
	service.call("unbind_event_bus")
	root.remove_child(bus)
	bus.free()
	root.remove_child(service)
	service.free()
	await process_frame


func _test_music_controller(catalog: CardIllustrationCatalogResource, music_contract: Dictionary) -> void:
	var packed := load(MUSIC_SCENE_PATH) as PackedScene
	_expect(packed != null, "commercial music controller scene loads")
	if packed == null:
		return
	var controller := packed.instantiate()
	root.add_child(controller)
	await process_frame
	_expect(not bool(controller.call("request_public_state", "menu")), "music controller fails closed without a Catalog")
	var snapshot: Dictionary = controller.call("debug_snapshot")
	_expect(str(snapshot.get("last_failure_reason", "")) == "catalog_missing", "music missing-Catalog rejection is typed")
	controller.call("set_catalog_resource", catalog)
	_expect(not bool(controller.call("request_public_state", "rival_hidden_pressure")), "music rejects a non-allowlisted state")
	_expect(not bool(controller.call("request_asset_key", &"music.unlisted")), "music rejects a non-allowlisted key")
	_expect(bool(controller.call("request_public_presentation_state", "menu")), "music accepts allowlisted public menu state")
	snapshot = controller.call("debug_snapshot")
	_expect(str(snapshot.get("current_public_state", "")) == "menu" and str(snapshot.get("current_asset_key", "")) == "music.menu", "menu state resolves to stable key")
	_expect(int(snapshot.get("playing_player_count", 0)) == 1 and is_equal_approx(float(snapshot.get("crossfade_seconds", 0.0)), 1.5), "first music request starts one player with exact crossfade policy")
	_expect(bool(controller.call("request_asset_key", &"music.gameplay")), "music accepts allowlisted stable key")
	snapshot = controller.call("debug_snapshot")
	_expect(bool(snapshot.get("crossfade_active", false)) and int(snapshot.get("playing_player_count", 0)) == 2, "music crossfade uses two live players")
	_expect(int(snapshot.get("crossfade_count", 0)) == 1 and str(snapshot.get("current_public_state", "")) == "gameplay", "crossfade advances only the public presentation state")
	await create_timer(0.75).timeout
	var primary := controller.get_node("PrimaryPlayer") as AudioStreamPlayer
	var secondary := controller.get_node("SecondaryPlayer") as AudioStreamPlayer
	var menu_gain := _music_gain(music_contract, "music.menu")
	var gameplay_gain := _music_gain(music_contract, "music.gameplay")
	var normalized_power := pow(db_to_linear(primary.volume_db - menu_gain), 2.0) \
			+ pow(db_to_linear(secondary.volume_db - gameplay_gain), 2.0)
	_expect(absf(normalized_power - 1.0) <= 0.08, "midpoint crossfade preserves equal cosine/sine power")
	await create_timer(0.9).timeout
	snapshot = controller.call("debug_snapshot")
	_expect(not bool(snapshot.get("crossfade_active", true)) and int(snapshot.get("playing_player_count", 0)) == 1, "completed crossfade stops the old player")
	var crossfade_count := int(snapshot.get("crossfade_count", 0))
	_expect(bool(controller.call("request_public_state", "gameplay")), "repeated public state is idempotently accepted")
	snapshot = controller.call("debug_snapshot")
	_expect(int(snapshot.get("crossfade_count", -1)) == crossfade_count, "repeated state does not restart or randomize music")
	_expect(not bool(snapshot.get("reads_hidden_information", true)) and int(snapshot.get("rules_rng_draw_count", -1)) == 0 and not bool(snapshot.get("save_persisted", true)), "music reads no hidden information, RNG, or Save state")
	_expect(not JSON.stringify(snapshot).contains("res://") and not JSON.stringify(snapshot).contains("third_party"), "music snapshot exposes no resource or vendor path")
	controller.call("stop_music")
	await create_timer(0.1).timeout
	snapshot = controller.call("debug_snapshot")
	_expect(int(snapshot.get("playing_player_count", -1)) == 0 and str(snapshot.get("current_asset_key", "x")).is_empty(), "music stop clears both presentation players")
	root.remove_child(controller)
	controller.free()
	await process_frame


func _test_static_boundaries() -> void:
	var event_map_text := FileAccess.get_file_as_string(EVENT_MAP_PATH)
	var registry_source := FileAccess.get_file_as_string("res://scripts/audio/audio_event_registry.gd")
	var bus_source := FileAccess.get_file_as_string("res://scripts/audio/audio_event_bus.gd")
	var sfx_source := FileAccess.get_file_as_string("res://scripts/audio/commercial_audio_presentation_service.gd")
	var music_source := FileAccess.get_file_as_string("res://scripts/audio/commercial_music_presentation_controller.gd")
	var sfx_scene := FileAccess.get_file_as_string(SFX_SCENE_PATH)
	var music_scene := FileAccess.get_file_as_string(MUSIC_SCENE_PATH)
	_expect(not event_map_text.contains("res://") and not event_map_text.contains("third_party"), "event router contains stable IDs only")
	_expect(not registry_source.contains("assets/third_party/commercial") and not bus_source.contains("assets/third_party/commercial"), "registry and bus contain no vendor paths")
	_expect(not sfx_source.contains("assets/third_party/commercial") and not sfx_source.contains("stream_path"), "SFX service resolves no direct resource path")
	_expect(not music_source.contains("assets/third_party/commercial") and not music_source.contains("stream_path"), "music controller resolves no direct resource path")
	for source in [registry_source, bus_source, sfx_source, music_source]:
		for forbidden in ["RandomNumberGenerator", "RunRngService", "V06SaveOwnerRegistry", "GameRuntimeCoordinator", "/root/Main", "HTTPRequest", "HTTPClient"]:
			_expect(not source.contains(forbidden), "audio runtime excludes authority token %s" % forbidden)
	_expect(sfx_source.contains("resource_for_asset_key") and sfx_source.contains("asset_kind_for_key"), "SFX service consumes Catalog generic API")
	_expect(music_source.contains("resource_for_asset_key") and music_source.contains("asset_kind_for_key"), "music controller consumes Catalog generic API")
	_expect(music_source.contains("_apply_equal_power_crossfade") and music_source.contains("cos(angle)") and music_source.contains("sin(angle)"), "music controller implements the equal-power contract")
	_expect(sfx_scene.count("type=\"AudioStreamPlayer\"") == 1, "SFX scene owns one editable AudioStreamPlayer")
	_expect(music_scene.count("type=\"AudioStreamPlayer\"") == 2, "music scene owns exactly two editable AudioStreamPlayers")


func _catalog_from_contracts(event_contract: Dictionary, music_contract: Dictionary) -> CardIllustrationCatalogResource:
	var catalog := CATALOG_RESOURCE_SCRIPT.new() as CardIllustrationCatalogResource
	var keys := PackedStringArray()
	var resources: Array[Resource] = []
	var kinds := PackedStringArray()
	var scopes := PackedStringArray()
	for rows_variant in [event_contract.get("events", []), music_contract.get("tracks", [])]:
		if not (rows_variant is Array):
			continue
		for row_variant in rows_variant as Array:
			if not (row_variant is Dictionary):
				continue
			var row: Dictionary = row_variant
			var asset_key := str(row.get("asset_key", ""))
			var resource_path := str(row.get("stream_path", ""))
			if asset_key.is_empty() or resource_path.is_empty() or keys.has(asset_key):
				continue
			var stream := load(resource_path) as AudioStream
			_expect(stream != null, "%s fixture stream loads from the authoritative contract" % asset_key)
			keys.append(asset_key)
			resources.append(stream)
			kinds.append("AudioStream")
			scopes.append("reference_only_commercial_audio")
	catalog.stable_asset_keys = keys
	catalog.stable_asset_resources = resources
	catalog.stable_asset_kinds = kinds
	catalog.stable_asset_scopes = scopes
	_expect(keys.size() == 21, "fixture Catalog exposes 17 SFX and four music keys")
	return catalog


func _music_gain(contract: Dictionary, asset_key: String) -> float:
	for row_variant in contract.get("tracks", []) as Array:
		if row_variant is Dictionary and str((row_variant as Dictionary).get("asset_key", "")) == asset_key:
			return float((row_variant as Dictionary).get("gain_db", 0.0))
	return 0.0


func _parse_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_expect(parsed is Dictionary, "%s parses" % path.get_file())
	return parsed as Dictionary if parsed is Dictionary else {}


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("COMMERCIAL_AUDIO_RUNTIME_SERVICE_PASS %d/%d" % [_checks, _checks])
		quit(0)
		return
	for failure in _failures:
		push_error("COMMERCIAL_AUDIO_RUNTIME_SERVICE_FAIL %s" % failure)
	print("COMMERCIAL_AUDIO_RUNTIME_SERVICE_FAIL %d/%d" % [_checks - _failures.size(), _checks])
	quit(1)
