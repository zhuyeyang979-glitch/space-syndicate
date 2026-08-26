extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const FIXED_SEED := 900626424
const TEST_VIEWPORT := Vector2i(1600, 960)
const LOCAL_PLAYER_ID := "player.local"

var _application: Node
var _screen: Control
var _flow: Node
var _runtime: Node
var _checks := 0
var _failures: Array[String] = []
var _public_resolution_receipts: Array[Dictionary] = []
var _resolution_link_seen := false
var _resolution_link_endpoint_parity_seen := false
var _resolution_link_source_rect_seen := false
var _resolution_link_target_occlusion_count := 0
var _resolution_link_facility_request_seen := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = TEST_VIEWPORT
	var packed: PackedScene = load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "production main scene loads")
	if packed == null:
		await _finish()
		return
	_application = packed.instantiate()
	root.add_child(_application)
	await _frames(12)
	_screen = _application.get_node_or_null("V075GameScreen") as Control
	_flow = _application.get_node_or_null("V075RuntimeComposition") as Node
	_expect(_screen != null, "production V075 GameScreen is composed")
	_expect(_flow != null, "production V075 runtime composition is composed")
	if _screen == null or _flow == null:
		await _finish()
		return
	_runtime = _flow.get("_runtime_owner") as Node
	_expect(_runtime != null, "facility probe reuses the existing RuntimeOwner")
	if _runtime == null:
		await _finish()
		return
	if _flow.has_signal("public_resolution_ready"):
		_flow.public_resolution_ready.connect(_on_public_resolution_ready)

	_configure_new_game()
	var start_button: Button = _screen.find_child(
		"StartConfiguredButton", true, false
	) as Button
	_expect(start_button != null, "production start control exists")
	if start_button == null:
		await _finish()
		return
	start_button.pressed.emit()
	var started: bool = await _wait_for_match_start(12.0)
	_expect(started, "normal UI starts a real four-seat game")
	if not started:
		await _finish()
		return
	await _dismiss_coach()
	await _frames(60)

	var submission_ready: bool = await _wait_for_submission(10.0)
	_expect(submission_ready, "production flow reaches submission")
	if not submission_ready:
		await _finish()
		return

	var before: Dictionary = _flow.call("local_snapshot") as Dictionary
	var before_map_payload: Dictionary = _flow.call("planet_map_view_payload") as Dictionary
	var before_markers: Array = _payload_city_markers(before_map_payload)
	var before_marker_count: int = before_markers.size()
	var selected_card: Control
	var selected_option: Dictionary = _first_legal_facility_option(before)
	var selected_card_id: String = str(selected_option.get("card_instance_id", ""))
	var selected_type: String = str(selected_option.get("facility_type", ""))
	var selected_industry: String = str(selected_option.get("industry_id", ""))
	_expect(not selected_card_id.is_empty(), "a real legal facility card is available")
	_expect(["factory", "market", "warehouse"].has(selected_type), "facility type is catalog-owned")
	var hand_rail: HBoxContainer = _screen.find_child("HandRail", true, false) as HBoxContainer
	if hand_rail != null:
		for child_variant: Variant in hand_rail.get_children():
			var card: Control = child_variant as Control
			if card == null or not card.visible or not card.has_method("payload"):
				continue
			var payload: Dictionary = card.call("payload") as Dictionary
			if str(payload.get("instance_id", payload.get("card_instance_id", ""))) == selected_card_id:
				selected_card = card
				break
	_expect(selected_card != null, "the authoritative facility card has one visible hand control")
	if selected_card == null:
		await _finish()
		return
	await _click(selected_card)
	await _frames(10)

	var selected_after_click: String = str(_screen.get("_selected_card_id"))
	_expect(selected_after_click == selected_card_id, "hand selection keeps the authoritative instance id")
	var target_clicked: bool = await _click_first_legal_target()
	_expect(target_clicked, "real map/target rail accepts a legal target")
	await _frames(2)
	var binding: Dictionary = _screen.get("_pending_confirm_binding") as Dictionary
	var target_region: String = str(binding.get("target_region_id", ""))
	_expect(not target_region.is_empty(), "target selection produces an authoritative region binding")
	_expect(str(binding.get("card_instance_id", "")) == selected_card_id, "target binding preserves card identity")
	var confirm: Button = _screen.find_child("CurrentActionConfirmButton", true, false) as Button
	_expect(confirm != null and not confirm.disabled, "fixed action tray exposes an enabled confirm")
	if confirm == null or confirm.disabled:
		await _finish()
		return

	var prequeue_payload: Dictionary = _flow.call("planet_map_view_payload") as Dictionary
	var prequeue_markers: Array = _payload_city_markers(prequeue_payload)
	var prequeue_slots: Array = _public_slots(_flow.call("local_snapshot") as Dictionary)
	var prequeue_target_markers: Array = _matching_markers(prequeue_markers, target_region, selected_type, selected_industry)
	_expect(prequeue_target_markers.is_empty(), "BUILD_NEW target has no formal marker before queue")
	await _click(confirm)
	await _frames(4)

	var queued: Dictionary = _flow.call("local_snapshot") as Dictionary
	var queued_phase: String = str(queued.get("phase", ""))
	var queued_actions: Array = queued.get("queued_actions", []) as Array
	_expect(queued_phase == "submission", "queue acceptance remains in submission")
	_expect(queued_actions.size() >= 1, "queue acceptance creates a pending action")
	var queued_payload: Dictionary = _flow.call("planet_map_view_payload") as Dictionary
	var queued_markers: Array = _payload_city_markers(queued_payload)
	var queued_slots: Array = _public_slots(queued)
	_expect(
		_matching_markers(queued_markers, target_region, selected_type, selected_industry).is_empty(),
		"queue accepted does not create a permanent facility marker"
	)
	_expect(
		_matching_slots(queued_slots, target_region, selected_type, selected_industry).is_empty(),
		"queue accepted does not occupy the public facility slot"
	)
	var queued_hand: Array = _hand_payloads(queued)
	_expect(_no_raw_variant_text(queued_hand), "queued hand projection has no raw Variant/Object text")
	_expect(_visible_instance_ids_unique(), "queued hand controls have unique instance ids")
	# Keep the expiry leg bounded in headless CI through the existing user-facing
	# pace intent; the window still closes naturally and no lock/deadline is
	# injected by this test.
	var fast_pace: Dictionary = _flow.submit_intent(
		_flow.issue_intent("ui.pacing.set", {"multiplier": 4})
	) as Dictionary
	_expect(bool(fast_pace.get("accepted", false)), "4x pace intent is accepted for facility resolution")

	var resolving_seen := false
	var maintenance_seen := false
	var deadline_msec: int = Time.get_ticks_msec() + 90_000
	while Time.get_ticks_msec() < deadline_msec:
		await create_timer(0.25).timeout
		var snapshot: Dictionary = _flow.call("local_snapshot") as Dictionary
		var phase: String = str(snapshot.get("phase", ""))
		if phase == "resolving":
			resolving_seen = true
			var combat_debug := _screen.call("combat_debug_snapshot") as Dictionary
			var link_debug := combat_debug.get("resolution_screen_link", {}) as Dictionary
			_resolution_link_seen = _resolution_link_seen or int(link_debug.get("active_link_count", 0)) > 0
			_resolution_link_endpoint_parity_seen = _resolution_link_endpoint_parity_seen or bool(link_debug.get("endpoint_authority_parity", false))
			_resolution_link_source_rect_seen = _resolution_link_source_rect_seen or int(link_debug.get("source_focus_rect_count", 0)) > 0
			_resolution_link_target_occlusion_count = maxi(
				_resolution_link_target_occlusion_count,
				int(link_debug.get("target_region_occlusion_count", 0))
			)
			_resolution_link_facility_request_seen = _resolution_link_facility_request_seen or int(link_debug.get("facility_animation_request_count", 0)) > 0
		if phase in ["maintenance", "settled", "failed"]:
			maintenance_seen = phase == "maintenance"
			break
	_expect(resolving_seen, "natural submission expiry reaches resolving")
	_expect(maintenance_seen, "facility batch naturally reaches maintenance")
	await _frames(30)

	var final_snapshot: Dictionary = _flow.call("local_snapshot") as Dictionary
	var final_payload: Dictionary = _flow.call("planet_map_view_payload") as Dictionary
	var final_slots: Array = _public_slots(final_snapshot)
	var final_markers: Array = _payload_city_markers(final_payload)
	var committed_slots: Array = _matching_slots(final_slots, target_region, selected_type, selected_industry)
	var committed_markers: Array = _matching_markers(final_markers, target_region, selected_type, selected_industry)
	_expect(committed_slots.size() == 1, "facility commit occupies exactly one authoritative public slot")
	_expect(committed_markers.size() == 1, "facility commit produces exactly one map marker")
	_expect(final_markers.size() >= before_marker_count, "committed map projection does not lose existing markers")
	var embedded: Control = _screen.find_child("PlanetMapView", true, false) as Control
	var planet_board: Node = _screen.find_child("PlanetBoard", true, false) as Node
	var fullscreen: Control = planet_board.find_child("FullscreenMapView", true, false) as Control if planet_board != null else null
	var embedded_markers: Array = embedded.get("city_markers") as Array if embedded != null else []
	var fullscreen_markers: Array = fullscreen.get("city_markers") as Array if fullscreen != null else []
	_expect(embedded != null, "production embedded PlanetMapView is present")
	_expect(fullscreen != null, "production fullscreen PlanetMapView is present")
	_expect(
		_matching_markers(embedded_markers, target_region, selected_type, selected_industry).size() == 1,
		"embedded map renders the committed marker"
	)
	_expect(
		_matching_markers(fullscreen_markers, target_region, selected_type, selected_industry).size() == 1,
		"fullscreen map renders the same committed marker"
	)
	var embedded_debug: Dictionary = _map_debug_snapshot(embedded)
	var fullscreen_debug: Dictionary = _map_debug_snapshot(fullscreen)
	var embedded_facility_debug: Array = embedded_debug.get("facility_marker_debug", []) as Array
	var fullscreen_facility_debug: Array = fullscreen_debug.get("facility_marker_debug", []) as Array
	if embedded_facility_debug.is_empty() and embedded != null:
		for node_variant in embedded.find_children("*", "Control", true, false):
			var node := node_variant as Control
			if node != null and node.has_method("debug_snapshot") and node.has_meta("facility_marker_id"):
				embedded_facility_debug.append(node.call("debug_snapshot") as Dictionary)
	if fullscreen_facility_debug.is_empty() and fullscreen != null:
		for node_variant in fullscreen.find_children("*", "Control", true, false):
			var node := node_variant as Control
			if node != null and node.has_method("debug_snapshot") and node.has_meta("facility_marker_id"):
				fullscreen_facility_debug.append(node.call("debug_snapshot") as Dictionary)
	print("V076_FACILITY_MAP_DEBUG|embedded=%s|fullscreen=%s" % [JSON.stringify(embedded_debug), JSON.stringify(fullscreen_debug)])
	var board_debug: Dictionary = planet_board.call("map_presentation_target_debug_snapshot") as Dictionary if planet_board != null and planet_board.has_method("map_presentation_target_debug_snapshot") else {}
	_expect(int(board_debug.get("apply_count", 0)) > 0, "PlanetBoard fan-out applies the shared map snapshot")
	_expect(int(embedded_debug.get("city_marker_count", 0)) >= embedded_markers.size(), "embedded PlanetCityMarker nodes are sceneized")
	_expect(int(fullscreen_debug.get("city_marker_count", 0)) >= fullscreen_markers.size(), "fullscreen PlanetCityMarker nodes are sceneized")
	var target_embedded_marker_debug: Dictionary = {}
	for marker_variant in embedded_facility_debug:
		if marker_variant is Dictionary and str((marker_variant as Dictionary).get("region_id", "")) == target_region:
			target_embedded_marker_debug = marker_variant as Dictionary
			break
	print("V076_FACILITY_MARKER_SCREEN_DEBUG|%s" % JSON.stringify(target_embedded_marker_debug))
	_expect(
		bool(target_embedded_marker_debug.get("human_visible", false)),
		"committed facility marker has a human-visible screen rect and alpha"
	)
	_expect(
		int(target_embedded_marker_debug.get("commit_animation_count", 0)) >= 1,
		"committed facility marker receives the presentation build animation"
	)
	_expect(
		int(embedded_facility_debug.size()) >= embedded_markers.size()
		and int(fullscreen_facility_debug.size()) >= fullscreen_markers.size(),
		"facility marker visibility snapshots cover embedded and fullscreen consumers"
	)
	_expect(_marker_identity_duplicates(final_markers) == 0, "committed map markers have no duplicate identity")
	var runtime_debug: Dictionary = _runtime.call("debug_snapshot") as Dictionary
	_expect(int(runtime_debug.get("runtime_error_count", 0)) == 0, "facility resolution has no runtime errors")
	_expect(_public_resolution_receipts.size() >= 1, "facility resolution publishes a public receipt")
	var final_combat_debug := _screen.call("combat_debug_snapshot") as Dictionary
	var final_link_debug := final_combat_debug.get("resolution_screen_link", {}) as Dictionary
	_expect(_resolution_link_seen, "resolution creates a live screen-space card-to-map link")
	_expect(_resolution_link_source_rect_seen, "resolution link records the focused sidecar card rect")
	_expect(_resolution_link_endpoint_parity_seen, "resolution link endpoint follows the live target region projection")
	_expect(_resolution_link_target_occlusion_count == 0, "resolution link target is not occluded by the sidecar")
	_expect(
		_resolution_link_facility_request_seen
		or int(final_link_debug.get("facility_animation_request_count", 0)) > 0,
		"facility animation request follows the visible card-to-target link"
	)
	print(
		"V076_FACILITY_COMMIT_MAP_MARKER_E2E|status=%s|queue_accepted=%s|resolving=%s|maintenance=%s|target_region=%s|facility_type=%s|public_slots=%d|map_markers=%d|embedded_markers=%d|fullscreen_markers=%d|resolution_receipts=%d|link_seen=%s|link_endpoint_parity=%s|link_source_rect=%s|link_target_occlusion=%d|facility_link_request=%s|before_markers=%d|prequeue_slots=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			str(queued_actions.size() >= 1),
			str(resolving_seen),
			str(maintenance_seen),
			target_region,
			selected_type,
			committed_slots.size(),
			committed_markers.size(),
			_matching_markers(embedded_markers, target_region, selected_type, selected_industry).size(),
			_matching_markers(fullscreen_markers, target_region, selected_type, selected_industry).size(),
			_public_resolution_receipts.size(),
			str(_resolution_link_seen),
			str(_resolution_link_endpoint_parity_seen),
			str(_resolution_link_source_rect_seen),
			_resolution_link_target_occlusion_count,
			str(_resolution_link_facility_request_seen),
			before_markers.size(),
			prequeue_slots.size(),
			JSON.stringify(_failures),
		]
	)
	await _finish()


func _configure_new_game() -> void:
	var player_option: OptionButton = _screen.find_child("PlayerCountOption", true, false) as OptionButton
	var seed_input: LineEdit = _screen.find_child("SeedInput", true, false) as LineEdit
	if player_option != null:
		for index in range(player_option.item_count):
			if int(player_option.get_item_metadata(index)) == 4:
				player_option.select(index)
				break
	if seed_input != null:
		seed_input.text = str(FIXED_SEED)


func _first_legal_facility_option(snapshot: Dictionary) -> Dictionary:
	for option_variant: Variant in snapshot.get("legal_actions", []) as Array:
		if not (option_variant is Dictionary):
			continue
		var option: Dictionary = option_variant as Dictionary
		var card_id: String = str(option.get("card_instance_id", ""))
		var facility_type: String = str(option.get("facility_type", ""))
		if not card_id.is_empty() and ["factory", "market", "warehouse"].has(facility_type):
			return option.duplicate(true)
	return {}


func _wait_for_match_start(seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var snapshot: Dictionary = _flow.call("local_snapshot") as Dictionary
		if bool(snapshot.get("match_started", false)):
			return true
		await process_frame
	return false


func _wait_for_submission(seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var snapshot: Dictionary = _flow.call("local_snapshot") as Dictionary
		if str(snapshot.get("phase", "")) == "submission":
			return true
		await process_frame
	return false


func _dismiss_coach() -> void:
	var coach: Node = _screen.get_node_or_null("V073PlaytestCoachMarks") as Node
	if coach == null:
		return
	var skip: Button = coach.find_child("CoachSkipAll", true, false) as Button
	if skip != null and bool((coach.call("debug_snapshot") as Dictionary).get("active", false)):
		skip.pressed.emit()
		await _frames(4)


func _click_first_legal_target() -> bool:
	var target_rail: HBoxContainer = _screen.find_child("TargetRail", true, false) as HBoxContainer
	if target_rail != null:
		for child_variant: Variant in target_rail.get_children():
			var button: Button = child_variant as Button
			if button != null and button.visible and not button.disabled:
				await _click(button)
				await _frames(2)
				break
	var virtual: Control = _screen.find_child("V074VirtualizedTargetRail", true, false) as Control
	if virtual != null:
		for candidate: Node in virtual.find_children("VirtualTargetRow*", "Button", true, false):
			var button: Button = candidate as Button
			if button.visible and not button.disabled:
				await _click(button)
				await _frames(2)
				var virtual_binding: Dictionary = _screen.get("_pending_confirm_binding") as Dictionary
				if not virtual_binding.is_empty():
					return true
				break
	var board: Node = _screen.find_child("PlanetBoard", true, false) as Node
	var map: Control = board.call("get_embedded_map_view") as Control if board != null and board.has_method("get_embedded_map_view") else null
	if map == null or not map.has_method("get_district_control_position"):
		return false
	for index in range(24):
		var local_position: Vector2 = map.call("get_district_control_position", index) as Vector2
		if local_position.x < 0.0 or local_position.y < 0.0:
			continue
		var point: Vector2 = map.global_position + local_position
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		Input.parse_input_event(motion)
		await process_frame
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.pressed = true
		down.position = point
		down.global_position = point
		Input.parse_input_event(down)
		await process_frame
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.pressed = false
		up.position = point
		up.global_position = point
		Input.parse_input_event(up)
		await process_frame
		var binding: Dictionary = _screen.get("_pending_confirm_binding") as Dictionary
		if not binding.is_empty():
			return true
	var popup_choices: Control = _screen.find_child("RegionPopupTargetChoices", true, false) as Control
	if popup_choices != null:
		for candidate: Node in popup_choices.find_children("*", "Button", true, false):
			var button: Button = candidate as Button
			if button != null and button.visible and not button.disabled:
				await _click(button)
				await _frames(2)
				var popup_binding: Dictionary = _screen.get("_pending_confirm_binding") as Dictionary
				if not popup_binding.is_empty():
					return true
	return false


func _click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = point
	down.global_position = point
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = point
	up.global_position = point
	Input.parse_input_event(up)
	await process_frame


func _frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _on_public_resolution_ready(receipt: Dictionary) -> void:
	_public_resolution_receipts.append(receipt.duplicate(true))


func _public_slots(snapshot: Dictionary) -> Array:
	var projection: Dictionary = snapshot.get("map_player_projection", {}) as Dictionary
	return (projection.get("public_facility_slots", []) as Array).duplicate(true)


func _payload_city_markers(payload: Dictionary) -> Array:
	var snapshot: MapPresentationSnapshot = payload.get("snapshot") as MapPresentationSnapshot
	return snapshot.city_markers.duplicate(true) if snapshot != null else []


func _matching_slots(rows: Array, region_id: String, facility_type: String, industry_id: String) -> Array:
	var result: Array = []
	for row_variant: Variant in rows:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant as Dictionary
		var facility: Dictionary = row.get("facility", {}) as Dictionary
		var occupancy: String = str(row.get("occupancy", ""))
		var row_type: String = str(row.get("facility_type", facility.get("facility_type", "")))
		var row_industry: String = str(row.get("industry_id", facility.get("industry_id", "")))
		if occupancy == "occupied" and str(row.get("region_id", "")) == region_id and row_type == facility_type and row_industry == industry_id:
			result.append(row)
	return result


func _matching_markers(rows: Array, region_id: String, facility_type: String, industry_id: String) -> Array:
	var result: Array = []
	for row_variant: Variant in rows:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant as Dictionary
		if str(row.get("region_id", "")) == region_id and str(row.get("facility_type", "")) == facility_type and str(row.get("industry_id", "")) == industry_id:
			result.append(row)
	return result


func _hand_payloads(snapshot: Dictionary) -> Array:
	var facts: Dictionary = (
		(snapshot.get("personal_dbg", {}) as Dictionary).get("facts", {})
		as Dictionary
	)
	var result: Array = []
	for key in ["hand", "commodity_inventory"]:
		for value_variant: Variant in facts.get(key, []) as Array:
			if value_variant is Dictionary:
				result.append(value_variant)
	return result


func _no_raw_variant_text(rows: Array) -> bool:
	var forbidden: Array[String] = ["<null>", "Object(", "RefCounted", "RID(", "Dictionary", "@GDScript", "[Object:null]"]
	for row_variant: Variant in rows:
		var text: String = JSON.stringify(row_variant)
		for token in forbidden:
			if text.contains(token):
				return false
	return true


func _visible_instance_ids_unique() -> bool:
	var rail: HBoxContainer = _screen.find_child("HandRail", true, false) as HBoxContainer
	var seen: Dictionary = {}
	if rail == null:
		return false
	for child_variant: Variant in rail.get_children():
		var child: Control = child_variant as Control
		if child == null or not child.visible or not child.has_method("payload"):
			continue
		var payload: Dictionary = child.call("payload") as Dictionary
		var id: String = str(payload.get("instance_id", payload.get("card_instance_id", "")))
		if id.is_empty() or seen.has(id):
			return false
		seen[id] = true
	return true


func _marker_identity_duplicates(rows: Array) -> int:
	var counts: Dictionary = {}
	for row_variant: Variant in rows:
		if not (row_variant is Dictionary):
			continue
		var row: Dictionary = row_variant as Dictionary
		var identity: String = "%s|%s|%s|%s" % [
			str(row.get("region_id", "")),
			str(row.get("facility_type", "")),
			str(row.get("industry_id", "")),
			str(row.get("owner_public_id", "")),
		]
		counts[identity] = int(counts.get(identity, 0)) + 1
	var duplicate_count := 0
	for count_variant: Variant in counts.values():
		duplicate_count += maxi(0, int(count_variant) - 1)
	return duplicate_count


func _map_debug_snapshot(map_view: Control) -> Dictionary:
	if map_view == null:
		return {}
	var result: Dictionary = {}
	if map_view.has_method("v074_planet_debug_snapshot"):
		result.merge(map_view.call("v074_planet_debug_snapshot") as Dictionary, true)
	if map_view.has_method("get_sceneized_child_snapshot"):
		result.merge(map_view.call("get_sceneized_child_snapshot") as Dictionary, true)
	return result


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	if _application != null and is_instance_valid(_application):
		_application.queue_free()
		await process_frame
		await process_frame
	if _failures.is_empty():
		print("V076_FACILITY_COMMIT_MAP_MARKER_E2E|checks=%d|passed=%d|status=PASS" % [_checks, _checks])
	else:
		print("V076_FACILITY_COMMIT_MAP_MARKER_E2E|checks=%d|passed=%d|status=FAIL|failures=%s" % [_checks, _checks - _failures.size(), JSON.stringify(_failures)])
	quit(0 if _failures.is_empty() else 1)
