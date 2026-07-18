extends SceneTree

const PLANET_MAP_SCENE := preload("res://scenes/ui/PlanetMapView.tscn")
const SOLAR_SCENE := preload("res://scenes/runtime/SolarAvailabilityRuntimeService.tscn")
const MARKET_BENCH_SCENE := preload("res://scenes/tools/DistrictPurchaseRuntimeCutoverBench.tscn")
const SESSION_SCENE := preload("res://scenes/runtime/GameSessionRuntimeController.tscn")
const RULESET_PROFILE := preload("res://resources/rules/space_syndicate_ruleset_v06.tres")

const EXPECTED_PUBLIC_KEYS := ["rotation_period_us", "sun_turn_ppm", "world_effective_us"]
const PRIVATE_TOKENS := ["player", "card", "district", "price", "cash", "hand", "owner", "camera", "quote", "ai_plan"]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_public_solar_snapshot()
	await _test_camera_state_machine()
	await _test_market_independence()
	_test_save_boundary()
	_finish()


func _test_public_solar_snapshot() -> void:
	var solar := SOLAR_SCENE.instantiate()
	root.add_child(solar)
	solar.call("configure", {})
	var t0: Dictionary = solar.call("public_presentation_snapshot", 0)
	var quarter: Dictionary = solar.call("public_presentation_snapshot", 30_000_000)
	var period: Dictionary = solar.call("public_presentation_snapshot", 120_000_000)
	var keys: Array = t0.keys()
	keys.sort()
	_expect(keys == EXPECTED_PUBLIC_KEYS and int(t0.get("rotation_period_us", 0)) == 120_000_000, "solar presentation snapshot is a strict three-field public allowlist")
	_expect(int(t0.get("sun_turn_ppm", -1)) == 0 and int(quarter.get("sun_turn_ppm", -1)) == 250_000 and int(period.get("sun_turn_ppm", -1)) == 0, "public sun longitude derives from the authoritative 120-second clock period")
	var public_text := JSON.stringify(t0).to_lower()
	var privacy_safe := true
	for token in PRIVATE_TOKENS:
		privacy_safe = privacy_safe and not public_text.contains(token)
	_expect(privacy_safe, "solar presentation contains no player, listing, price, camera, ownership or AI fields")
	solar.queue_free()


func _test_camera_state_machine() -> void:
	var map_view := PLANET_MAP_SCENE.instantiate() as Control
	root.add_child(map_view)
	map_view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	map_view.size = Vector2(960.0, 720.0)
	await process_frame
	map_view.call("set_map", _districts(), 1000.0, 500.0, 2, _palette())
	map_view.call("set_programmatic_focus_animation_enabled", false)
	map_view.call("zoom_to_local_projection")
	map_view.call("focus_district", 2, true)
	var controller := map_view.get_node_or_null("PlanetSolarCameraController")
	_expect(controller != null and controller.scene_file_path == "res://scenes/ui/map/PlanetSolarCameraController.tscn", "PlanetMapView statically owns the solar camera controller scene")
	if controller == null:
		map_view.queue_free()
		return
	controller.call("set_auto_advance_enabled", false)
	var solar := SOLAR_SCENE.instantiate()
	root.add_child(solar)
	solar.call("configure", {})
	var t0: Dictionary = solar.call("public_presentation_snapshot", 0)
	_expect(bool(map_view.call("set_solar_presentation_snapshot", t0)) and str((controller.call("debug_snapshot") as Dictionary).get("state", "")) == "IDLE_WAIT", "first public snapshot enters IDLE_WAIT")
	controller.call("advance_presentation", 2.999)
	_expect(str((controller.call("debug_snapshot") as Dictionary).get("state", "")) == "IDLE_WAIT", "2.999 seconds remains idle")
	controller.call("advance_presentation", 0.001)
	_expect(str((controller.call("debug_snapshot") as Dictionary).get("state", "")) == "ALIGNING", "3.0 seconds enters ALIGNING")
	var before_alignment: Dictionary = map_view.call("solar_presentation_camera_snapshot")
	controller.call("advance_presentation", 0.799)
	var almost_aligned: Dictionary = map_view.call("solar_presentation_camera_snapshot")
	_expect(str((controller.call("debug_snapshot") as Dictionary).get("state", "")) == "ALIGNING" and int(almost_aligned.get("center_turn_ppm", -1)) != 0 and int(almost_aligned.get("center_turn_ppm", -1)) != int(before_alignment.get("center_turn_ppm", -1)), "0.799 seconds applies smoothstep without settling")
	controller.call("advance_presentation", 0.001)
	var aligned: Dictionary = map_view.call("solar_presentation_camera_snapshot")
	_expect(str((controller.call("debug_snapshot") as Dictionary).get("state", "")) == "FOLLOWING" and int(aligned.get("center_turn_ppm", -1)) == 0, "0.8 seconds settles exactly into FOLLOWING")
	_expect(is_equal_approx(float(aligned.get("view_zoom", 0.0)), 0.98) and int(aligned.get("selected_district", -1)) == 2, "automatic alignment preserves zoom and selected district")
	var quarter: Dictionary = solar.call("public_presentation_snapshot", 30_000_000)
	map_view.call("set_solar_presentation_snapshot", quarter)
	var followed: Dictionary = map_view.call("solar_presentation_camera_snapshot")
	_expect(int(followed.get("center_turn_ppm", -1)) == 250_000 and is_equal_approx(float(followed.get("view_zoom", 0.0)), 0.98), "FOLLOWING continuously tracks the latest public sun longitude without changing zoom")
	_test_interaction_resets(map_view, controller)
	map_view.call("zoom_to_local_projection")
	map_view.call("focus_district", 1, true)
	map_view.call("set_solar_presentation_snapshot", quarter)
	map_view.call("request_solar_camera_return")
	var returned: Dictionary = map_view.call("solar_presentation_camera_snapshot")
	_expect(int(returned.get("center_turn_ppm", -1)) == 250_000 and int(returned.get("center_latitude_ppm", 1)) == 0 and is_equal_approx(float(returned.get("view_zoom", 0.0)), 0.48) and int(returned.get("selected_district", -1)) == 1, "explicit return faces the current sun, restores globe zoom 0.48 and preserves selection")
	var return_button := controller.get_node_or_null("ReturnToSunButton") as Button
	_expect(return_button != null and return_button.pressed.is_connected(Callable(controller, "request_return_to_sun")), "compact return button is wired directly to the scene-owned controller")
	for motion_mode in ["reduced", "off"]:
		controller.call("set_motion_mode", motion_mode)
		map_view.call("focus_district", 2, true)
		map_view.call("set_solar_presentation_snapshot", quarter)
		controller.call("advance_presentation", 2.999)
		var before_snap: Dictionary = controller.call("debug_snapshot")
		controller.call("advance_presentation", 0.001)
		var after_snap: Dictionary = controller.call("debug_snapshot")
		var snap_camera: Dictionary = map_view.call("solar_presentation_camera_snapshot")
		_expect(str(before_snap.get("state", "")) == "IDLE_WAIT" and str(after_snap.get("state", "")) == "FOLLOWING" and int(snap_camera.get("center_turn_ppm", -1)) == 250_000, "%s motion snaps once at the same three-second threshold and keeps the feature enabled" % motion_mode)
	var leaked := quarter.duplicate(true)
	leaked["player_index"] = 0
	_expect(not bool(map_view.call("set_solar_presentation_snapshot", leaked)) and str((controller.call("debug_snapshot") as Dictionary).get("state", "")) == "UNAVAILABLE", "controller rejects any field outside the public solar allowlist")
	var button := controller.get_node_or_null("ReturnToSunButton") as Button
	_expect(button != null and button.text == "☀" and not button.tooltip_text.is_empty(), "scene provides one compact symbol return button with a tooltip")
	controller.call("set_auto_advance_enabled", false)
	map_view.queue_free()
	solar.queue_free()
	await process_frame


func _test_interaction_resets(map_view: Control, controller: Node) -> void:
	var t: Dictionary = {"world_effective_us": 30_000_000, "rotation_period_us": 120_000_000, "sun_turn_ppm": 250_000}
	var interactions := []
	controller.call("request_return_to_sun")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(480.0, 360.0)
	map_view.call("_gui_input", wheel)
	interactions.append(str((controller.call("debug_snapshot") as Dictionary).get("last_interaction_kind", "")) == "wheel")
	controller.call("request_return_to_sun")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(480.0, 360.0)
	map_view.call("_gui_input", press)
	interactions.append(str((controller.call("debug_snapshot") as Dictionary).get("last_interaction_kind", "")) == "click")
	controller.call("request_return_to_sun")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(500.0, 380.0)
	map_view.call("_gui_input", motion)
	interactions.append(str((controller.call("debug_snapshot") as Dictionary).get("last_interaction_kind", "")) == "drag")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = motion.position
	map_view.call("_gui_input", release)
	controller.call("request_return_to_sun")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_A
	map_view.call("_gui_input", key)
	interactions.append(str((controller.call("debug_snapshot") as Dictionary).get("last_interaction_kind", "")) == "key")
	controller.call("request_return_to_sun")
	map_view.call("focus_district", 1, true)
	interactions.append(str((controller.call("debug_snapshot") as Dictionary).get("last_interaction_kind", "")) == "focus_district")
	controller.call("request_return_to_sun")
	map_view.emit_signal("focus_entered")
	interactions.append(str((controller.call("debug_snapshot") as Dictionary).get("last_interaction_kind", "")) == "focus_entered")
	var snapshot: Dictionary = controller.call("debug_snapshot")
	_expect(interactions.all(func(value: Variant) -> bool: return bool(value)) and str(snapshot.get("state", "")) == "IDLE_WAIT" and is_zero_approx(float(snapshot.get("idle_elapsed", -1.0))), "wheel, drag, click, key, focus_district and focus-enter all reset FOLLOWING to IDLE_WAIT")
	map_view.call("set_solar_presentation_snapshot", t)


func _test_market_independence() -> void:
	var bench := MARKET_BENCH_SCENE.instantiate()
	bench.set("auto_run", false)
	root.add_child(bench)
	await process_frame
	bench.call("_prepare_runtime")
	bench.call("_reset_policy")
	var coordinator := bench.get_node_or_null("%GameRuntimeCoordinator")
	var world: Node = bench.get("_world") as Node
	var bridge := coordinator.get_node_or_null("CardMarketPolicyWorldBridge") if coordinator != null else null
	var monsters: Node = world.get("monster_runtime_controller") as Node if world != null else null
	_expect(coordinator != null and bridge != null and monsters != null, "production market fixture composes the clock, solar and quote authorities")
	if coordinator != null and bridge != null and monsters != null:
		monsters.set("entries", [{"district_index": 0, "down": false, "remaining_time": 10.0, "owner": "PRIVATE_OWNER"}])
		coordinator.call("restore_world_effective_seconds", 0.0)
		var presentation: Dictionary = coordinator.call("solar_public_presentation_snapshot")
		var listing := {"player_index": 0, "district_index": 0, "card_id": "card.camera-negative", "supply_revision": "solar-camera-rev", "base_price": 101}
		coordinator.call("open_district_purchase_window", 0, 0, {"supply_revision": "solar-camera-rev"})
		coordinator.call("acknowledge_district_purchase_selection", 0, 0, "card.camera-negative", "solar-camera-rev")
		var before_facts: Dictionary = bridge.call("capture_market_facts", 0)
		var before_quote: Dictionary = coordinator.call("card_market_quote", listing)
		var map_view := PLANET_MAP_SCENE.instantiate() as Control
		root.add_child(map_view)
		map_view.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		map_view.size = Vector2(960.0, 720.0)
		await process_frame
		map_view.call("set_map", world.get("districts"), float(world.get("map_width_m")), float(world.get("map_height_m")), 0, _palette())
		map_view.call("set_solar_presentation_snapshot", presentation)
		map_view.call("zoom_to_local_projection")
		map_view.call("focus_district", 2, false)
		map_view.call("request_solar_camera_return")
		var after_facts: Dictionary = bridge.call("capture_market_facts", 0)
		var after_quote: Dictionary = coordinator.call("card_market_quote", listing)
		_expect(before_facts == after_facts and str(before_quote.get("quote_id", "")) == str(after_quote.get("quote_id", "")) and str(before_quote.get("quote_fingerprint", "")) == str(after_quote.get("quote_fingerprint", "")), "camera zoom, focus and solar return cannot alter market facts, quote id or public fingerprint")
		map_view.queue_free()
	bench.queue_free()
	await process_frame


func _test_save_boundary() -> void:
	var session := SESSION_SCENE.instantiate()
	root.add_child(session)
	var save := session.get_node_or_null("GameSaveRuntimeCoordinator")
	var handshake := save.get_node_or_null("RulesetSaveHandshakeService") if save != null else null
	var manifest: Dictionary = handshake.call("required_section_manifest") if handshake != null else {}
	_expect(manifest.size() == 19 and not manifest.has("solar_camera") and not manifest.has("solar_phase"), "existing 19-owner save manifest gains no solar camera or phase section")
	var map_view := PLANET_MAP_SCENE.instantiate() as Control
	var controller := map_view.get_node_or_null("PlanetSolarCameraController")
	_expect(controller != null and not controller.has_method("to_save_data") and not controller.has_method("apply_save_data"), "solar camera controller is local presentation state with no save API")
	var controller_source := FileAccess.get_file_as_string("res://scripts/ui/map/planet_solar_camera_controller.gd")
	_expect(not controller_source.contains("GameRuntimeCoordinator") and not controller_source.contains("CardMarket") and not controller_source.contains("WorldBridge"), "scene controller holds no Coordinator, market authority or world bridge reference")
	map_view.free()
	session.queue_free()


func _districts() -> Array:
	return [
		{"index": 0, "name": "晨港", "center": Vector2(100.0, 250.0), "neighbors": [1], "polygon": [Vector2(20, 160), Vector2(180, 160), Vector2(180, 340), Vector2(20, 340)]},
		{"index": 1, "name": "中环", "center": Vector2(400.0, 200.0), "neighbors": [0, 2], "polygon": [Vector2(300, 100), Vector2(500, 100), Vector2(500, 300), Vector2(300, 300)]},
		{"index": 2, "name": "暮原", "center": Vector2(750.0, 300.0), "neighbors": [1], "polygon": [Vector2(640, 190), Vector2(860, 190), Vector2(860, 410), Vector2(640, 410)]},
	]


func _palette() -> Array:
	return [Color("#0f766e"), Color("#2563eb"), Color("#9333ea")]


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		push_error("PLANET SOLAR CAMERA PRESENTATION: %s" % label)


func _finish() -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("PLANET_SOLAR_CAMERA_PRESENTATION_TEST|status=%s|checks=%d|failures=%d|details=%s" % [status, _checks, _failures.size(), JSON.stringify(_failures)])
	quit(0 if _failures.is_empty() else 1)
