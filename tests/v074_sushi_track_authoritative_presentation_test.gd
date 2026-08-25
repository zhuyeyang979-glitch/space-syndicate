extends SceneTree

const RuntimeOwner := preload(
	"res://scripts/v074_runtime/v074_runtime_owner.gd"
)
const ScreenScene := preload(
	"res://scenes/ui/v074/V074SampleGameScreen.tscn"
)
const LOCAL_PLAYER_ID := "player.local"
const TEST_SEED := 7407410

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var runtime := RuntimeOwner.new()
	root.add_child(runtime)
	var started := runtime.start_new_game(
		3,
		TEST_SEED,
		false,
		false,
		{
			"map_seed": TEST_SEED,
			"region_count": 8,
			"geography_complexity": "SIMPLE",
			"land_ocean_profile": "BALANCED",
		}
	)
	_expect(bool(started.get("accepted", false)), "V0.7.4 runtime starts")
	if not bool(started.get("accepted", false)):
		await _finish(runtime, null)
		return

	var core := runtime.get("_track_core") as RefCounted
	_expect(core != null, "production runtime exposes its existing track owner")
	if core == null:
		await _finish(runtime, null)
		return

	var screen := ScreenScene.instantiate() as V074SampleGameScreen
	root.add_child(screen)
	await process_frame
	await process_frame

	var initial_snapshot := _screen_snapshot(runtime)
	var initial_sequence := _scroll_sequence(initial_snapshot)
	screen.apply_snapshot(initial_snapshot)
	await process_frame
	await process_frame
	screen.call("_update_acceptance_state")
	var initial_acceptance := screen.acceptance_state.duplicate(true)
	_expect(
		int(initial_acceptance.get(
			"track_authoritative_animation_count",
			-1
		)) == 0,
		"initial snapshot establishes a baseline without animation"
	)
	_expect(
		is_zero_approx(_track_rail(screen).position.x),
		"initial track projection has zero presentation offset"
	)
	_expect(
		_track_children_have_neutral_modulate(screen),
		"initial track has no sine luminance wave"
	)

	var initial_items := _own_track_items(initial_snapshot)
	var target := _item_nearest_slot(initial_items, 4)
	_expect(not target.is_empty(), "a claimable middle-slot card exists")
	if target.is_empty():
		await _finish(runtime, screen)
		return
	var before_supply := _supply_consumption_probe(core)
	var acquisition := runtime.acquire_track_item(
		LOCAL_PLAYER_ID,
		str(target.get("instance_id", ""))
	)
	_expect(
		bool(acquisition.get("accepted", false)),
		"real track acquisition commits before the presentation probe"
	)
	var after_purchase := _screen_snapshot(runtime)
	_expect(
		_scroll_sequence(after_purchase) == initial_sequence,
		"purchase does not advance the authoritative scroll sequence"
	)
	screen.apply_snapshot(after_purchase)
	await process_frame
	await process_frame
	screen.call("_update_acceptance_state")
	var purchase_acceptance := screen.acceptance_state.duplicate(true)
	_expect(
		int(purchase_acceptance.get(
			"track_authoritative_animation_count",
			-1
		)) == 0,
		"purchase-created vacancy does not manufacture a handoff animation"
	)
	_expect(
		int(purchase_acceptance.get("track_vacancy_slot_count", 0)) == 1,
		"purchase projection includes one real vacancy slot"
	)
	_expect(
		_supply_consumption_probe(core) == before_supply,
		"purchase consumes no supply cursor, instance sequence, or RNG"
	)

	var previous_snapshot := after_purchase
	for advance_index in range(3):
		var receipt := _advance_track(core, advance_index)
		_expect(
			bool(receipt.get("accepted", false)),
			"authoritative track advance %d commits" % (advance_index + 1)
		)
		var advanced_snapshot := _screen_snapshot(runtime)
		_expect(
			_scroll_sequence(advanced_snapshot)
				== _scroll_sequence(previous_snapshot) + 1,
			"advance %d increments scroll_sequence exactly once"
				% (advance_index + 1)
		)
		_expect(
			_surviving_slot_delta_count(
				previous_snapshot,
				advanced_snapshot
			) > 0,
			"advance %d moves surviving cards to new local slots"
				% (advance_index + 1)
		)

		screen.apply_snapshot(advanced_snapshot)
		# Replay the identical authoritative snapshot before the deferred layout
		# boundary.  The already scheduled transition must remain exact-once.
		screen.apply_snapshot(advanced_snapshot)
		await process_frame
		await process_frame
		screen.call("_update_acceptance_state")
		var moving_acceptance := screen.acceptance_state.duplicate(true)
		_expect(
			int(moving_acceptance.get(
				"track_authoritative_animation_count",
				-1
			)) == advance_index + 1,
			"advance %d starts one animation despite snapshot replay"
				% (advance_index + 1)
		)
		_expect(
			float(moving_acceptance.get(
				"track_last_translation_px",
				0.0
			)) >= 72.0,
			"advance %d uses one full measured slot translation"
				% (advance_index + 1)
		)
		_expect(
			_track_children_have_neutral_modulate(screen),
			"advance %d has no oscillating luminance presentation"
				% (advance_index + 1)
		)

		await create_timer(0.76).timeout
		screen.call("_update_acceptance_state")
		var settled := screen.acceptance_state.duplicate(true)
		_expect(
			int(settled.get(
				"track_authoritative_animation_settle_count",
				-1
			)) == advance_index + 1,
			"advance %d settles exactly once" % (advance_index + 1)
		)
		_expect(
			absf(float(settled.get(
				"track_animation_end_offset_px",
				999.0
			))) <= 0.5
			and is_zero_approx(_track_rail(screen).position.x),
			"advance %d ends at the new authoritative phase"
				% (advance_index + 1)
		)
		_expect(
			bool(settled.get(
				"track_card_end_rect_matches_new_slot",
				false
			))
			and bool(settled.get(
				"track_vacancy_end_rect_matches_new_slot",
				false
			)),
			"advance %d settles cards and vacancy in their new slots"
				% (advance_index + 1)
		)
		previous_snapshot = advanced_snapshot

	# A settled snapshot replay remains static and does not reset the rail to an
	# earlier visual phase or add another animation receipt.
	screen.apply_snapshot(previous_snapshot)
	await process_frame
	await process_frame
	screen.call("_update_acceptance_state")
	var final_acceptance := screen.acceptance_state.duplicate(true)
	_expect(
		int(final_acceptance.get(
			"track_authoritative_animation_count",
			-1
		)) == 3
		and int(final_acceptance.get(
			"track_authoritative_animation_settle_count",
			-1
		)) == 3,
		"three authority increments produce exactly three settled animations"
	)
	_expect(
		int(final_acceptance.get("track_oscillation_only_count", -1)) == 0
		and int(final_acceptance.get(
			"track_visual_return_to_old_phase_count",
			-1
		)) == 0,
		"presentation records no idle oscillation or return to old phase"
	)
	_expect(
		str(final_acceptance.get(
			"track_presentation_authority_source",
			""
		)) == "unified_track.public_facts.scroll_sequence",
		"presentation names the reused authoritative sequence owner"
	)
	_expect(
		bool(final_acceptance.get("track_sushi_motion_enabled", false)),
		"legacy sushi-motion sentinel is green only after authority animation"
	)

	await _finish(runtime, screen)


func _screen_snapshot(runtime: Node) -> Dictionary:
	var snapshot := (
		runtime.call("player_snapshot", LOCAL_PLAYER_ID) as Dictionary
	).duplicate(true)
	# The test exercises the real runtime projection but does not bind a map
	# presentation flow; map rendering is outside this focused gate.
	snapshot["match_started"] = false
	return snapshot


func _scroll_sequence(snapshot: Dictionary) -> int:
	return int((
		(snapshot.get("unified_track", {}) as Dictionary).get(
			"public_facts",
			{}
		) as Dictionary
	).get("scroll_sequence", -1))


func _own_track_items(snapshot: Dictionary) -> Array:
	return ((
		(snapshot.get("unified_track", {}) as Dictionary).get(
			"viewer_private_facts",
			{}
		) as Dictionary
	).get("own_segment_items", []) as Array).duplicate(true)


func _item_nearest_slot(items: Array, preferred_slot: int) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := 999999
	for item_variant in items:
		var item := item_variant as Dictionary
		if not bool(item.get("claimable", false)):
			continue
		var distance := absi(
			int(item.get("local_slot_index", -1)) - preferred_slot
		)
		if distance < best_distance:
			best = item.duplicate(true)
			best_distance = distance
	return best


func _advance_track(core: RefCounted, index: int) -> Dictionary:
	var intent := core.call(
		"build_intent_v1",
		"request.v074.presentation.advance.%d" % index,
		"system",
		core.ACTION_ADVANCE_TRACK,
		{"steps": 1}
	) as Dictionary
	return core.call("apply_intent_v1", intent) as Dictionary


func _surviving_slot_delta_count(
	before_snapshot: Dictionary,
	after_snapshot: Dictionary
) -> int:
	var before_by_id := {}
	for item_variant in _own_track_items(before_snapshot):
		var item := item_variant as Dictionary
		before_by_id[str(item.get("instance_id", ""))] = int(
			item.get("local_slot_index", -1)
		)
	var count := 0
	for item_variant in _own_track_items(after_snapshot):
		var item := item_variant as Dictionary
		var instance_id := str(item.get("instance_id", ""))
		if before_by_id.has(instance_id) \
				and int(before_by_id.get(instance_id, -1)) \
					!= int(item.get("local_slot_index", -1)):
			count += 1
	return count


func _supply_consumption_probe(core: RefCounted) -> Dictionary:
	var debug := core.call("debug_snapshot_v074") as Dictionary
	return {
		"cursor_delta": int(debug.get(
			"supply_cursor_delta_on_acquisition",
			-1
		)),
		"instance_delta": int(debug.get(
			"supply_instance_sequence_delta_on_acquisition",
			-1
		)),
		"rng_delta": int(debug.get(
			"supply_rng_draw_delta_on_acquisition",
			-1
		)),
		"immediate_refill": int(debug.get(
			"immediate_authoritative_refill_count",
			-1
		)),
	}


func _track_rail(screen: Control) -> HBoxContainer:
	return screen.get_node(
		"RootMargin/Shell/TrackPanel/TrackMargin/TrackRows/TrackScroll/TrackRail"
	) as HBoxContainer


func _track_children_have_neutral_modulate(screen: Control) -> bool:
	for child_variant in _track_rail(screen).get_children():
		var child := child_variant as CanvasItem
		if child == null or not child.modulate.is_equal_approx(Color.WHITE):
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish(runtime: Node, screen: Control) -> void:
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	if runtime != null and is_instance_valid(runtime):
		runtime.queue_free()
	await process_frame
	print(
		"V074_SUSHI_TRACK_AUTHORITATIVE_PRESENTATION_TEST|"
		+ "status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
