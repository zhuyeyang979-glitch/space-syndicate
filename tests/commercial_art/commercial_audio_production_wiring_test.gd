extends SceneTree

const EVENT_CONTRACT_PATH := "res://resources/audio/commercial/commercial_audio_event_map.json"
const MUSIC_CONTRACT_PATH := "res://resources/audio/commercial/commercial_music_playlist.json"
const CATALOG_PATH := "res://resources/presentation/alpha01_card_illustration_catalog.tres"
const GAME_SCREEN_SCENE_PATH := "res://scenes/ui/GameScreen.tscn"
const MAIN_SCRIPT_PATH := "res://scripts/main.gd"
const MAIN_SCENE_PATH := "res://scenes/main.tscn"

const EXPECTED_EVENT_KEYS := {
	"ui.hover": "audio.ui.hover",
	"ui.confirm": "audio.ui.confirm",
	"ui.cancel": "audio.ui.cancel",
	"card.select": "audio.card.select",
	"card.drag_start": "audio.card.drag_start",
	"card.drop": "audio.card.drop",
	"card.lock": "audio.card.lock",
	"card.merge": "audio.card.merge",
	"asset.refresh": "audio.asset.refresh",
	"commodity.claim": "audio.commodity.claim",
	"normal_card.purchase": "audio.normal_card.purchase",
	"facility.factory_build": "audio.facility.factory_build",
	"facility.market_build": "audio.facility.market_build",
	"facility.warehouse_build": "audio.facility.warehouse_build",
	"monster.attack": "audio.monster.attack",
	"military.action": "audio.military.action",
	"settlement.complete": "audio.settlement.complete",
}

const EXPECTED_MUSIC_KEYS := {
	"menu": "music.menu",
	"gameplay": "music.gameplay",
	"crisis": "music.crisis",
	"military": "music.military",
}

const AUTHORITY_TOKENS := [
	"RandomNumberGenerator",
	"RunRngService",
	"V06SaveOwnerRegistry",
	"GameSaveRuntimeCoordinator",
	"randi(",
	"randf(",
]

var _checks := 0
var _failures: Array[String] = []
var _played_events: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var event_contract := _parse_json(EVENT_CONTRACT_PATH)
	var music_contract := _parse_json(MUSIC_CONTRACT_PATH)
	var catalog := load(CATALOG_PATH)
	_test_contract_and_catalog(event_contract, music_contract, catalog)
	_test_main_responsibility_boundary()

	var packed := load(GAME_SCREEN_SCENE_PATH) as PackedScene
	_expect(packed != null, "production GameScreen scene loads")
	if packed == null:
		_finish()
		return
	var screen := packed.instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame

	var sfx_service := _find_node_with_methods(screen, ["play_event", "bind_event_bus", "debug_snapshot"])
	var music_controller := _find_node_with_methods(screen, ["request_public_state", "request_asset_key", "stop_music"])
	var event_bus := _find_node_with_methods(screen, ["emit_audio_event", "last_canonical_event_id", "debug_snapshot"])
	var menu_overlay := _find_node_with_methods(screen, ["present_menu_shell", "set_global_navigation", "debug_snapshot"])
	var card_dock := _find_node_with_methods(screen, ["apply_projection", "cancel_target_selection", "debug_snapshot"])

	_expect(sfx_service != null, "GameScreen owns one production commercial SFX service below the presentation boundary")
	_expect(music_controller != null, "GameScreen owns one production commercial music controller below the presentation boundary")
	_expect(event_bus != null, "GameScreen owns one presentation AudioEventBus")
	_expect(menu_overlay != null, "GameScreen exposes the existing MenuOverlay")
	_expect(card_dock != null, "GameScreen exposes the existing PlayerCardDock")
	_expect(_count_nodes_with_methods(screen, ["play_event", "bind_event_bus"]) == 1, "production presentation owns exactly one commercial SFX service")
	_expect(_count_nodes_with_methods(screen, ["request_public_state", "request_asset_key"]) == 1, "production presentation owns exactly one commercial music controller")
	_expect(_count_nodes_with_methods(screen, ["emit_audio_event", "last_canonical_event_id"]) == 1, "production presentation owns exactly one AudioEventBus")

	if sfx_service != null:
		if sfx_service.has_signal("event_played"):
			sfx_service.connect("event_played", _on_event_played)
		else:
			_expect(false, "commercial SFX service exposes event_played safe metadata signal")
		_test_sfx_production_instance(sfx_service, event_bus, catalog)
	if music_controller != null:
		await _test_music_production_instance(music_controller, catalog)
	if sfx_service != null and menu_overlay != null:
		await _test_menu_signal_wiring(menu_overlay)
	if sfx_service != null and card_dock != null:
		await _test_card_dock_signal_wiring(card_dock)
	_test_runtime_authority_boundary(screen)

	if music_controller != null:
		music_controller.call("stop_music")
	root.remove_child(screen)
	screen.free()
	catalog = null
	await process_frame
	_finish()


func _test_contract_and_catalog(event_contract: Dictionary, music_contract: Dictionary, catalog: Resource) -> void:
	_expect(int(event_contract.get("schema_version", 0)) == 1, "commercial SFX contract schema is v1")
	_expect(str(event_contract.get("contract_id", "")) == "space_syndicate.commercial_audio.events.v1", "commercial SFX contract ID is canonical")
	_expect(bool(event_contract.get("presentation_only", false)), "commercial SFX contract is presentation-only")
	_expect(not bool(event_contract.get("randomize", true)), "commercial SFX contract forbids randomized selection")
	_expect(int(event_contract.get("rules_rng_draw_count", -1)) == 0, "commercial SFX contract consumes no rules RNG")
	var event_rows: Array = event_contract.get("events", []) if event_contract.get("events", []) is Array else []
	_expect(event_rows.size() == 17, "commercial SFX contract contains exactly 17 event mappings")
	var rows_by_event := _rows_by_field(event_rows, "event_id")
	_expect(rows_by_event.size() == EXPECTED_EVENT_KEYS.size(), "commercial SFX event IDs are unique")
	for event_id_variant in EXPECTED_EVENT_KEYS.keys():
		var event_id := str(event_id_variant)
		var expected_key := str(EXPECTED_EVENT_KEYS[event_id])
		var row_variant: Variant = rows_by_event.get(event_id)
		_expect(row_variant is Dictionary, "%s has a contract row" % event_id)
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		_expect(str(row.get("asset_key", "")) == expected_key, "%s maps to stable key %s" % [event_id, expected_key])
		_expect(not bool(row.get("loop", true)), "%s is a one-shot SFX event" % event_id)
		_test_catalog_audio_key(catalog, expected_key)

	_expect(int(music_contract.get("schema_version", 0)) == 1, "commercial music contract schema is v1")
	_expect(str(music_contract.get("contract_id", "")) == "space_syndicate.commercial_music.playlist.v1", "commercial music contract ID is canonical")
	_expect(bool(music_contract.get("presentation_only", false)), "commercial music contract is presentation-only")
	_expect(is_equal_approx(float(music_contract.get("crossfade_seconds", 0.0)), 1.5), "commercial music contract fixes crossfade at 1.5 seconds")
	_expect(str(music_contract.get("crossfade_curve", "")) == "equal_power", "commercial music contract uses equal-power crossfade")
	_expect(not bool(music_contract.get("hidden_information_dependency", true)), "music selection reads no hidden information")
	_expect(not bool(music_contract.get("gameplay_effect", true)), "music has no gameplay effect")
	_expect(not bool(music_contract.get("save_persisted", true)), "music state is not persisted")
	_expect(int(music_contract.get("rules_rng_draw_count", -1)) == 0, "commercial music consumes no rules RNG")
	var track_rows: Array = music_contract.get("tracks", []) if music_contract.get("tracks", []) is Array else []
	_expect(track_rows.size() == 4, "commercial music contract contains exactly four public tracks")
	var rows_by_state := _rows_by_field(track_rows, "state_id")
	for state_variant in EXPECTED_MUSIC_KEYS.keys():
		var state_id := str(state_variant)
		var expected_key := str(EXPECTED_MUSIC_KEYS[state_id])
		var row_variant: Variant = rows_by_state.get(state_id)
		_expect(row_variant is Dictionary, "%s music state has a contract row" % state_id)
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		_expect(str(row.get("asset_key", "")) == expected_key, "%s music state maps to stable key %s" % [state_id, expected_key])
		_expect(bool(row.get("loop", false)), "%s music stream is loop-enabled" % state_id)
		_test_catalog_audio_key(catalog, expected_key)


func _test_catalog_audio_key(catalog: Resource, asset_key: String) -> void:
	_expect(catalog != null, "%s can be checked against the canonical Catalog" % asset_key)
	if catalog == null:
		return
	_expect(not asset_key.contains("/") and not asset_key.contains("\\") and not asset_key.contains("third_party"), "%s is a stable key, not a resource path" % asset_key)
	_expect(bool(catalog.call("has_asset_key", StringName(asset_key))), "Catalog resolves %s" % asset_key)
	_expect(str(catalog.call("asset_kind_for_key", StringName(asset_key))) == "AudioStream", "Catalog classifies %s as AudioStream" % asset_key)
	var scope := str(catalog.call("asset_scope_for_key", StringName(asset_key)))
	_expect(scope.begins_with("production_safe_") or scope.begins_with("reference_only_"), "Catalog gives %s an explicit production/reference scope" % asset_key)
	_expect(catalog.call("resource_for_asset_key", StringName(asset_key)) is AudioStream, "Catalog resource for %s is loadable audio" % asset_key)


func _test_sfx_production_instance(service: Node, event_bus: Node, catalog: Resource) -> void:
	var snapshot: Dictionary = service.call("debug_snapshot")
	_expect(bool(snapshot.get("contract_ready", false)), "production SFX service loaded its 17-row contract")
	_expect(bool(snapshot.get("catalog_bound", false)), "production SFX service is bound to the canonical Catalog")
	_expect(bool(snapshot.get("event_bus_bound", false)), "production SFX service is bound to the production presentation bus")
	_expect(service.get("catalog") == catalog, "production SFX service shares the canonical Catalog resource")
	_expect(str(snapshot.get("allowed_asset_scope_prefix", "")) == "production_safe_", "production SFX service enforces the Catalog production-safe scope")
	_expect(not bool(snapshot.get("randomized_selection", true)), "production SFX service selects one fixed file per event")
	_expect(int(snapshot.get("rules_rng_draw_count", -1)) == 0, "production SFX service reports zero rules RNG draws")
	_expect(not bool(snapshot.get("mutates_gameplay", true)), "production SFX service does not mutate gameplay")
	_expect(_safe_public_value(snapshot), "production SFX debug snapshot leaks no resource or vendor path")

	var initial_played := _played_events.size()
	for event_id_variant in EXPECTED_EVENT_KEYS.keys():
		var event_id := str(event_id_variant)
		var expected_key := str(EXPECTED_EVENT_KEYS[event_id])
		var scope := str(catalog.call("asset_scope_for_key", StringName(expected_key)))
		var production_safe := scope.begins_with("production_safe_")
		var accepted := bool(service.call("play_event", event_id, {
			"canonical_id": event_id,
			"asset_key": expected_key,
			"source": "commercial_audio_production_wiring_test",
		}))
		_expect(accepted == production_safe, "production SFX scope decision matches %s for %s" % [scope, event_id])
		_expect(_played_events.size() == initial_played + (1 if production_safe else 0), "%s playback receipt count matches its production scope" % event_id)
		if production_safe and _played_events.size() > initial_played:
			var receipt: Dictionary = _played_events.back()
			_expect(str(receipt.get("event_id", "")) == event_id, "%s playback receipt preserves canonical event ID" % event_id)
			_expect(str(receipt.get("asset_key", "")) == expected_key, "%s playback receipt exposes only its stable key" % event_id)
			_expect(_safe_public_value(receipt), "%s playback receipt leaks no resource or vendor path" % event_id)
		elif not production_safe:
			var rejected_snapshot: Dictionary = service.call("debug_snapshot")
			_expect(str(rejected_snapshot.get("last_failure_reason", "")) == "asset_scope_not_allowed", "%s fails closed with a typed scope reason" % event_id)
		initial_played = _played_events.size()

	_expect(event_bus != null, "production SFX mapping can be exercised through AudioEventBus")
	if event_bus == null:
		return
	var before_bus := _played_events.size()
	var public_record: Dictionary = event_bus.call("emit_audio_event", "ui.hover", {
		"source": "production_wiring_test",
		"stream_path": "res://private/vendor.ogg",
		"nested": {"unsafe": "assets/third_party/private/vendor.ogg"},
	})
	_expect(_played_events.size() == before_bus + 1, "production AudioEventBus reaches the SFX service exactly once")
	_expect(str(public_record.get("canonical_id", "")) == "ui.hover", "production bus preserves the canonical event identity")
	_expect(str(public_record.get("asset_key", "")) == "audio.ui.hover", "production bus exposes the stable Catalog key")
	_expect(_safe_public_value(public_record), "production bus recursively removes caller resource paths")
	var bus_snapshot: Dictionary = event_bus.call("debug_snapshot")
	_expect(not bool(bus_snapshot.get("contains_resource_paths", true)), "production bus history contains no resource path")
	_expect(int(bus_snapshot.get("rules_rng_draw_count", -1)) == 0, "production bus reports zero rules RNG draws")


func _test_music_production_instance(controller: Node, catalog: Resource) -> void:
	var snapshot: Dictionary = controller.call("debug_snapshot")
	_expect(bool(snapshot.get("contract_ready", false)), "production music controller loaded its four-track contract")
	_expect(bool(snapshot.get("catalog_bound", false)), "production music controller is bound to the canonical Catalog")
	_expect(controller.get("catalog") == catalog, "production music controller shares the canonical Catalog resource")
	_expect(is_equal_approx(float(snapshot.get("crossfade_seconds", 0.0)), 1.5), "production music controller fixes crossfade at 1.5 seconds")
	_expect(not bool(snapshot.get("reads_hidden_information", true)), "production music controller reads no hidden information")
	_expect(int(snapshot.get("rules_rng_draw_count", -1)) == 0, "production music controller reports zero rules RNG draws")
	_expect(not bool(snapshot.get("save_persisted", true)), "production music controller does not persist presentation state")
	_expect(not bool(snapshot.get("mutates_gameplay", true)), "production music controller does not mutate gameplay")
	_expect(_safe_public_value(snapshot), "production music snapshot leaks no resource or vendor path")

	controller.call("stop_music")
	_expect(bool(controller.call("request_public_state", "menu")), "production music accepts the public menu state")
	_expect(bool(controller.call("request_public_state", "gameplay")), "production music accepts the public gameplay state")
	snapshot = controller.call("debug_snapshot")
	_expect(bool(snapshot.get("crossfade_active", false)), "menu-to-gameplay transition starts a live crossfade")
	_expect(int(snapshot.get("playing_player_count", 0)) == 2, "live crossfade uses exactly two presentation players")
	_expect(int(snapshot.get("crossfade_count", 0)) >= 1, "production music records the public-state crossfade")
	await create_timer(1.65).timeout
	snapshot = controller.call("debug_snapshot")
	_expect(not bool(snapshot.get("crossfade_active", true)), "1.5-second production crossfade completes")
	_expect(int(snapshot.get("playing_player_count", 0)) == 1, "completed crossfade stops the previous stream")
	_expect(str(snapshot.get("current_public_state", "")) == "gameplay", "completed crossfade retains only the public gameplay state")
	_expect(str(snapshot.get("current_asset_key", "")) == "music.gameplay", "completed crossfade exposes only the stable gameplay music key")
	_expect(_safe_public_value(snapshot), "completed music snapshot leaks no resource or vendor path")


func _test_menu_signal_wiring(menu: Node) -> void:
	_expect(menu.has_signal("continue_requested"), "MenuOverlay retains continue_requested")
	_expect(menu.has_signal("main_menu_requested"), "MenuOverlay retains main_menu_requested")
	_expect(menu.has_signal("catalog_step_requested"), "MenuOverlay retains catalog_step_requested")
	_expect(menu.has_signal("catalog_back_requested"), "MenuOverlay retains catalog_back_requested")
	var continue_button := menu.get_node_or_null("MenuSurfacePanel/MenuShellMargin/MenuShell/MenuNavRow/MenuContinueButton")
	var back_button := menu.get_node_or_null("MenuSurfacePanel/MenuShellMargin/MenuShell/MenuNavRow/MenuBackButton")
	_expect(continue_button is Button, "MenuOverlay exposes its existing Continue button")
	_expect(back_button is Button, "MenuOverlay exposes its existing Back button")
	if continue_button is Button:
		await _expect_single_ui_event(func() -> void: (continue_button as Button).mouse_entered.emit(), "ui.hover", "Menu Continue hover")
		await _expect_single_ui_event(func() -> void: (continue_button as Button).pressed.emit(), "ui.confirm", "Menu Continue command")
	if back_button is Button:
		await _expect_single_ui_event(func() -> void: (back_button as Button).pressed.emit(), "ui.cancel", "Menu Back command")


func _test_card_dock_signal_wiring(card_dock: Node) -> void:
	_expect(card_dock.has_signal("card_hovered"), "PlayerCardDock retains card_hovered")
	_expect(card_dock.has_signal("card_selected"), "PlayerCardDock retains card_selected")
	_expect(card_dock.has_signal("game_action_offer_requested"), "PlayerCardDock retains its single gameplay offer path")
	_expect(card_dock.has_signal("presentation_audio_event_requested"), "PlayerCardDock exposes a presentation-only audio request without changing gameplay signals")
	if card_dock.has_signal("presentation_audio_event_requested"):
		var connections := card_dock.get_signal_connection_list("presentation_audio_event_requested")
		_expect(connections.size() == 1, "PlayerCardDock presentation audio request has exactly one production consumer")
		await _expect_single_ui_event(
			func() -> void: card_dock.emit_signal("presentation_audio_event_requested", "ui.hover", {"surface": "player_card_dock"}),
			"ui.hover",
			"PlayerCardDock hover request"
		)
		await _expect_single_ui_event(
			func() -> void: card_dock.emit_signal("presentation_audio_event_requested", "card.select", {"surface": "player_card_dock"}),
			"card.select",
			"PlayerCardDock selection request"
		)
	var source := FileAccess.get_file_as_string("res://scripts/ui/table/player_card_dock.gd")
	for event_id in ["ui.hover", "ui.cancel", "card.select", "card.drag_start", "card.drop"]:
		_expect(source.contains("_request_presentation_audio(\"%s\")" % event_id), "PlayerCardDock interaction source requests %s through the presentation signal" % event_id)
	_expect(not source.contains("AudioStreamPlayer") and not source.contains("resource_for_asset_key"), "PlayerCardDock never resolves or plays an audio resource directly")


func _expect_single_ui_event(trigger: Callable, expected_event_id: String, label: String) -> void:
	var before := _played_events.size()
	trigger.call()
	await process_frame
	var delta := _played_events.size() - before
	_expect(delta == 1, "%s emits exactly one presentation audio event" % label)
	if delta > 0:
		_expect(str(_played_events.back().get("event_id", "")) == expected_event_id, "%s resolves to %s" % [label, expected_event_id])
		_expect(_safe_public_value(_played_events.back()), "%s audio receipt leaks no resource or vendor path" % label)


func _test_main_responsibility_boundary() -> void:
	var main_source := FileAccess.get_file_as_string(MAIN_SCRIPT_PATH)
	var main_scene := FileAccess.get_file_as_string(MAIN_SCENE_PATH)
	for token in ["CommercialAudioPresentationService", "CommercialMusicPresentationController", "AudioEventBus", "emit_audio_event", "request_public_state"]:
		_expect(not main_source.contains(token), "main.gd owns no commercial audio responsibility token %s" % token)
		_expect(not main_scene.contains(token), "main.tscn owns no commercial audio responsibility token %s" % token)


func _test_runtime_authority_boundary(screen: Node) -> void:
	var paths: Dictionary = {
		"res://scripts/audio/audio_event_bus.gd": true,
		"res://scripts/audio/audio_event_registry.gd": true,
		"res://scripts/audio/commercial_audio_presentation_service.gd": true,
		"res://scripts/audio/commercial_music_presentation_controller.gd": true,
		"res://scripts/ui/game_screen.gd": true,
		"res://scripts/ui/menu_overlay.gd": true,
		"res://scripts/ui/table/player_card_dock.gd": true,
	}
	_collect_script_paths(screen, paths)
	for path_variant in paths.keys():
		var path := str(path_variant)
		if not path.begins_with("res://scripts/"):
			continue
		var source := FileAccess.get_file_as_string(path)
		for token in AUTHORITY_TOKENS:
			_expect(not source.contains(token), "%s excludes authority/RNG token %s" % [path.get_file(), token])
	_expect(FileAccess.get_file_as_string("res://scripts/audio/commercial_audio_presentation_service.gd").contains("resource_for_asset_key"), "production SFX resolves audio only through Catalog")
	_expect(FileAccess.get_file_as_string("res://scripts/audio/commercial_music_presentation_controller.gd").contains("resource_for_asset_key"), "production music resolves audio only through Catalog")


func _collect_script_paths(start: Node, paths: Dictionary) -> void:
	var script := start.get_script() as Script
	if script != null and not script.resource_path.is_empty():
		paths[script.resource_path] = true
	for child in start.get_children():
		if child is Node:
			_collect_script_paths(child as Node, paths)


func _find_node_with_methods(start: Node, methods: Array[String]) -> Node:
	if _node_has_methods(start, methods):
		return start
	for child in start.get_children():
		if not (child is Node):
			continue
		var found := _find_node_with_methods(child as Node, methods)
		if found != null:
			return found
	return null


func _count_nodes_with_methods(start: Node, methods: Array[String]) -> int:
	var count := 1 if _node_has_methods(start, methods) else 0
	for child in start.get_children():
		if child is Node:
			count += _count_nodes_with_methods(child as Node, methods)
	return count


func _node_has_methods(node: Node, methods: Array[String]) -> bool:
	for method in methods:
		if not node.has_method(method):
			return false
	return true


func _rows_by_field(rows: Array, field: String) -> Dictionary:
	var result: Dictionary = {}
	for row_variant in rows:
		if not (row_variant is Dictionary):
			continue
		var key := str((row_variant as Dictionary).get(field, "")).strip_edges()
		if not key.is_empty() and not result.has(key):
			result[key] = row_variant
	return result


func _parse_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_expect(parsed is Dictionary, "%s parses" % path.get_file())
	return parsed as Dictionary if parsed is Dictionary else {}


func _safe_public_value(value: Variant) -> bool:
	var encoded := JSON.stringify(value).to_lower()
	return not encoded.contains("res://") \
		and not encoded.contains("user://") \
		and not encoded.contains("file://") \
		and not encoded.contains("assets/third_party") \
		and not encoded.contains("assets\\\\third_party")


func _on_event_played(event_id: String, asset_key: StringName) -> void:
	_played_events.append({
		"event_id": event_id,
		"asset_key": str(asset_key),
	})


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("COMMERCIAL_AUDIO_PRODUCTION_WIRING_PASS %d/%d" % [_checks, _checks])
		quit(0)
		return
	for failure in _failures:
		push_error("COMMERCIAL_AUDIO_PRODUCTION_WIRING_FAIL %s" % failure)
	print("COMMERCIAL_AUDIO_PRODUCTION_WIRING_FAIL %d/%d" % [_checks - _failures.size(), _checks])
	quit(1)
