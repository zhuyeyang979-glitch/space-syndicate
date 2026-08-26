extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const FIXED_SEED := 900626424
const TEST_VIEWPORT := Vector2i(1600, 960)
const PresentationReceiptIdentity := preload(
	"res://scripts/v075/presentation/v075_presentation_receipt_identity_v2.gd"
)

var _checks := 0
var _failures: Array[String] = []
var _application: Node
var _screen: Control
var _flow: Node
var _runtime: Node
var _director: Node
var _arrangement: Control
var _receipts: Array[Dictionary] = []
var _deck_lifecycle_receipts: Array[Dictionary] = []
var _public_resolution_receipts: Array[Dictionary] = []
var _natural_tail_refill_edge_count := 0
var _natural_tail_exit_observed := false
var _post_resolution_commodity_acquire_count := 0
var _post_resolution_commodity_acquire_rejection_count := 0
var _post_resolution_rejection_reason := "none"
var _normal_terminal_observed := false
var _first_commodity_acquire_count := 0
var _second_legal_commodity_opportunity_count := 0
var _second_legal_commodity_acquire_count := 0
var _second_legal_commodity_rejection_count := 0
var _countdown_frozen_after_commit_count := 0
var _action_window_sample_count := 0
var _multi_window_trace: Array[Dictionary] = []
var _multi_window_trace_seen: Dictionary = {}
var _trace_started_wall_msec := Time.get_ticks_msec()
var _facility_trace: Dictionary = {}
var _direct_method_call_false_green_count := 0
var _real_pointer_card_trace: Array[Dictionary] = []
var _director_cues_queued: Array[Dictionary] = []
var _director_cues_finished: Array[Dictionary] = []
var _guard_at_queue: Dictionary = {}
var _guard_at_finish: Dictionary = {}
var _card_transition_start_evidence: Dictionary = {}
var _card_transition_finish_evidence: Dictionary = {}
var _card_transition_bridge_envelopes: Dictionary = {}
var _resolution_receipts_by_id: Dictionary = {}
var _resolution_start_evidence: Dictionary = {}
var _resolution_finish_evidence: Dictionary = {}
var _resolution_finish_debug: Dictionary = {}
var _resolution_bridge_envelopes: Dictionary = {}
var _human_public_transition_ids: Array[String] = []
var _presentation_drain_guard_before: Dictionary = {}
var _presentation_drain_resolution_source_count_before := -1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = TEST_VIEWPORT
	var packed := load(MAIN_SCENE) as PackedScene
	_expect(packed != null, "production main.tscn loads")
	if packed == null:
		await _finish()
		return
	_application = packed.instantiate()
	root.add_child(_application)
	for _frame in range(4):
		await process_frame
	_screen = _application.get_node_or_null("V075GameScreen") as Control
	_flow = _application.get_node_or_null("V075RuntimeComposition") as Node
	_expect(_screen != null, "production V075 GameScreen is composed")
	_expect(_flow != null, "production ApplicationFlow is composed")
	if _screen == null or _flow == null:
		await _finish()
		return
	_runtime = _flow.get("_runtime_owner") as Node
	_expect(_runtime != null, "production flow owns the existing V075 RuntimeOwner")
	_director = _screen.get_node_or_null(
		"V076PresentationAnimationDirector"
	) as Node
	_arrangement = _screen.find_child(
		"CentralPublicActionArrangement",
		true,
		false
	) as Control
	_expect(_director != null, "production Screen composes the unique animation Director")
	_expect(_arrangement != null, "production Screen composes the public arrangement surface")
	_expect(
		_flow.has_method("presentation_authority_guard_snapshot"),
		"production Flow exposes the presentation authority guard"
	)
	_flow.receipt_ready.connect(func(receipt: Dictionary) -> void:
		_receipts.append(receipt.duplicate(true))
	)
	if _flow.has_signal("deck_lifecycle_presentation_receipt_ready"):
		_flow.deck_lifecycle_presentation_receipt_ready.connect(
			func(receipt: Dictionary) -> void:
				_deck_lifecycle_receipts.append(receipt.duplicate(true))
		)
	if _flow.has_signal("public_resolution_ready"):
		_flow.public_resolution_ready.connect(_on_public_resolution_ready)

	_configure_new_game()
	var start_button := _screen.find_child(
		"StartConfiguredButton",
		true,
		false
	) as Button
	var started_msec := Time.get_ticks_msec()
	start_button.pressed.emit()
	for _frame in range(20):
		await process_frame
		if bool((_flow.call("local_snapshot") as Dictionary).get(
			"match_started",
			false
		)):
			break
	var playable_msec := Time.get_ticks_msec()
	var initial := _flow.call("local_snapshot") as Dictionary
	print("V076_STARTUP_TIMING|elapsed_seconds=%.3f|match_started=%s|phase=%s" % [
		float(playable_msec - started_msec) / 1000.0,
		str(initial.get("match_started", false)),
		str(initial.get("phase", "")),
	])
	_expect(bool(initial.get("match_started", false)), "normal UI starts a real game")
	_expect(
		(initial.get("roster", []) as Array).size() == 4,
		"real game contains one human and three AI players"
	)
	_expect(
		float(playable_msec - started_msec) / 1000.0 <= 5.0,
		"new game becomes playable within five wall seconds"
	)
	_record_multi_window_state("S0_NEW_GAME_PUBLISHED")
	await _dismiss_coach()
	_record_multi_window_state("S1_FIRST_ACTION_WINDOW_STARTED")

	var ai_started_msec := Time.get_ticks_msec()
	var ai_feed_visible_msec := -1
	var ai_feed := _screen.find_child(
		"PublicActionFeed",
		true,
		false
	) as RichTextLabel
	for _frame in range(90):
		await process_frame
		if ai_feed != null and ai_feed.text.contains("AI玩家"):
			ai_feed_visible_msec = Time.get_ticks_msec()
			break
	var ai_debug := _runtime.call("debug_snapshot") as Dictionary
	var ai_receipts := ai_debug.get("ai_public_action_receipts", []) as Array
	print("V076_AI_ACTION_TIMING|first_feed_elapsed_seconds=%.3f|receipt_count=%d|phase=%s" % [
		(
			float(ai_feed_visible_msec - ai_started_msec) / 1000.0
			if ai_feed_visible_msec >= 0
			else -1.0
		),
		ai_receipts.size(),
		str((_flow.call("local_snapshot") as Dictionary).get("phase", "")),
	])
	var observation_counts := ai_debug.get(
		"ai_observation_count_by_actor",
		{}
	) as Dictionary
	_expect(ai_receipts.size() == 3, "all three AI seats publish an action or PASS receipt")
	_expect(observation_counts.size() == 3, "all three AI seats use canonical Observation")
	var public_card_count := 0
	var explicit_pass_count := 0
	var private_identity_leak_count := 0
	var actor_labels := {}
	for receipt_variant in ai_receipts:
		var receipt := receipt_variant as Dictionary
		actor_labels[str(receipt.get("actor_label", ""))] = true
		if bool(receipt.get("public_card", false)):
			public_card_count += 1
		if str(receipt.get("status", "")) == "PASS":
			explicit_pass_count += 1
		private_identity_leak_count += _private_ai_receipt_key_count(receipt)
	_expect(actor_labels.size() == 3, "AI action receipts cover three distinct public seat labels")
	_expect(public_card_count == 3, "fixed natural seed gives 3/3 AI public-card plays")
	_expect(
		ai_feed_visible_msec >= 0
		and float(
			ai_feed_visible_msec - ai_started_msec
		) / 1000.0 <= 5.0,
		"first AI public action reaches the fixed visible Action Feed within five wall seconds"
	)
	_expect(private_identity_leak_count == 0, "AI public receipts disclose no private card identity")

	await create_timer(0.62).timeout
	var screen_debug := _screen.call("debug_snapshot") as Dictionary
	var arrangement_debug := screen_debug.get("public_arrangement", {}) as Dictionary
	_expect(
		int(arrangement_debug.get("ai_card_play_visible_animation_count", 0)) >= 3,
		"three AI public cards visibly animate from their seats"
	)
	_expect(
		bool(arrangement_debug.get("ai_card_animation_source_is_seat", false)),
		"AI card animation source is the production roster seat"
	)
	_expect(
		int(arrangement_debug.get("card_transition_failure_count", -1)) == 0,
		"card-table transitions have no missing source or target"
	)
	_expect(
		int(arrangement_debug.get("public_arrangement_numeric_placeholder_count", -1)) == 0,
		"public arrangement uses card faces instead of numeric placeholders"
	)
	_expect(
		int(arrangement_debug.get("last_public_entry_count", 0)) >= 3,
		"public arrangement visibly contains the AI card row"
	)
	_expect(
		ai_feed != null and ai_feed.text.contains("AI玩家"),
		"public Action Feed names visible AI card activity"
	)
	_bind_card_table_evidence_sources()

	var commodity_result := await _assert_commodity_acquisition()
	var human_card_id := ""
	if OS.get_environment("V076_REQUEUE_ONLY") == "1":
		human_card_id = await _assert_human_card_zone_transition()
		print("V076_REQUEUE_FOCUSED_PROBE|card_id=%s" % human_card_id)
		await _finish()
		return
	await _assert_public_arrangement_interaction()
	human_card_id = await _assert_three_authoritative_track_handoffs(
		int(commodity_result.get("vacancy_path_position", -1)),
		human_card_id
	)
	_assert_multi_window_trace_contract()
	await _pause_gameplay_for_presentation_drain()
	await _assert_deck_lifecycle_presentation_chain()
	await _assert_card_table_presentation_chain()

	print("V076_CARD_TABLE_FLOW_PROBE|ai_public_cards=%d|ai_pass=%d|arrangement=%s" % [
		public_card_count,
		explicit_pass_count,
		JSON.stringify(arrangement_debug),
	])
	print("V076_POST_RESOLUTION_LOOP|normal_terminal=%s|post_resolution_acquire_count=%d|post_resolution_acquire_rejection_count=%d|post_victory_rejection_reason=%s" % [
		str(_normal_terminal_observed),
		_post_resolution_commodity_acquire_count,
		_post_resolution_commodity_acquire_rejection_count,
		_post_resolution_rejection_reason,
	])
	print("V076_MULTI_WINDOW_SUMMARY|states=%d|first_commodity=%d|second_opportunity=%d|second_acquire=%d|second_rejection=%d|countdown_frozen=%d|action_windows=%d|facility_commit=%s|map_marker_persists=%s|track_advances=%d|track_handoffs=%d" % [
		_multi_window_trace.size(),
		_first_commodity_acquire_count,
		_second_legal_commodity_opportunity_count,
		_second_legal_commodity_acquire_count,
		_second_legal_commodity_rejection_count,
		_countdown_frozen_after_commit_count,
		_action_window_sample_count,
		str(_facility_trace.get("facility_commit_id", "")),
		str(_trace_map_marker_count("S12_NEXT_ACTION_WINDOW_STARTED") >= _trace_map_marker_count("S11_MAP_MARKER_PRESENTED")),
		int(_screen.acceptance_state.get("track_authoritative_advance_count", 0)),
		int(_screen.acceptance_state.get("track_next_player_handoff_count", 0)),
	])
	await _finish()


func _bind_card_table_evidence_sources() -> void:
	# Initial AI visibility is a production latency measurement.  Bind the
	# heavyweight whole-world guard witnesses only after that budget is sealed,
	# so the test's own synchronous hashing cannot delay the fixed Action Feed.
	# This still precedes every human commodity/card gesture and every public
	# resolution receipt asserted by the commercial card-table chain.
	if _director != null:
		var queued_callback := Callable(self, "_on_director_cue_queued")
		var finished_callback := Callable(self, "_on_director_cue_finished")
		if not _director.is_connected("cue_queued", queued_callback):
			_director.connect("cue_queued", queued_callback)
		if not _director.is_connected("cue_finished", finished_callback):
			_director.connect("cue_finished", finished_callback)
	if _arrangement == null:
		return
	for binding_variant in [
		{
			"signal_name": "card_transition_started",
			"method_name": "_on_card_transition_started",
		},
		{
			"signal_name": "card_transition_finished",
			"method_name": "_on_card_transition_finished",
		},
		{
			"signal_name": "resolution_presentation_started",
			"method_name": "_on_resolution_presentation_started",
		},
		{
			"signal_name": "resolution_presentation_finished",
			"method_name": "_on_resolution_presentation_finished",
		},
	]:
		var binding := binding_variant as Dictionary
		var signal_name := str(binding.get("signal_name", ""))
		var callback := Callable(self, str(binding.get("method_name", "")))
		if not _arrangement.is_connected(signal_name, callback):
			_arrangement.connect(signal_name, callback)


func _pause_gameplay_for_presentation_drain() -> void:
	var pause_button := _screen.find_child("PauseButton", true, false) as Button
	_expect(
		pause_button != null,
		"production pacing surface exposes the existing Pause input for a stable presentation drain"
	)
	if pause_button == null:
		return
	var before := _flow.call("pacing_snapshot") as Dictionary
	pause_button.pressed.emit()
	var after := before
	for _frame in range(12):
		await process_frame
		after = _flow.call("pacing_snapshot") as Dictionary
		if int(after.get("effective_multiplier", -1)) == 0:
			break
	print("V076_PRESENTATION_DRAIN_PACING|before=%s|after=%s" % [
		JSON.stringify(before),
		JSON.stringify(after),
	])
	_expect(
		int(after.get("effective_multiplier", -1)) == 0,
		"existing pacing owner freezes new gameplay ticks while presentation drains"
	)
	_expect(
		not bool(after.get("changes_authority_tick_order", true))
		and not bool(after.get("changes_rng_order", true))
		and not bool(after.get("injects_authority_state", true)),
		"presentation drain pause neither reorders authority nor injects gameplay state"
	)
	_presentation_drain_guard_before = _flow.call(
		"presentation_authority_guard_snapshot"
	) as Dictionary
	_presentation_drain_resolution_source_count_before = (
		_public_resolution_receipts.size()
	)
	print("V076_PRESENTATION_DRAIN_HIGH_WATER|snapshot_sha256=%s|resolution_source_count=%d" % [
		str(_presentation_drain_guard_before.get("snapshot_sha256", "")),
		_presentation_drain_resolution_source_count_before,
	])


func _assert_deck_lifecycle_presentation_chain() -> void:
	var deadline_msec := Time.get_ticks_msec() + 1800
	var screen_debug := _screen.call("debug_snapshot") as Dictionary
	var deck_debug := screen_debug.get(
		"deck_lifecycle_presentation",
		{}
	) as Dictionary
	while (
		int(deck_debug.get("active_animation_count", 0)) > 0
		and Time.get_ticks_msec() < deadline_msec
	):
		await process_frame
		screen_debug = _screen.call("debug_snapshot") as Dictionary
		deck_debug = screen_debug.get(
			"deck_lifecycle_presentation",
			{}
		) as Dictionary
	var runtime_debug := _runtime.call("debug_snapshot") as Dictionary
	print("V076_DECK_LIFECYCLE_DEBUG|screen=%s|runtime=%s" % [
		JSON.stringify({
			"deck": deck_debug,
			"screen_lifecycle": {
				"receipt_fingerprint_count": screen_debug.get("deck_lifecycle_receipt_fingerprint_count", -1),
				"duplicate_count": screen_debug.get("deck_lifecycle_duplicate_count", -1),
				"collision_count": screen_debug.get("deck_lifecycle_collision_count", -1),
				"rejection_count": screen_debug.get("deck_lifecycle_rejection_count", -1),
				"last_rejection_reason": screen_debug.get("deck_lifecycle_last_rejection_reason", ""),
				"acquisition_match_count": screen_debug.get("deck_acquisition_private_receipt_match_count", -1),
				"pending_acquisition_count": screen_debug.get("pending_deck_acquisition_count", -1),
				"missing_acquisition_count": screen_debug.get("deck_acquisition_private_receipt_missing_count", -1),
				"pending_discard_count": screen_debug.get("pending_deck_discard_receipt_count", -1),
				"flush_count": screen_debug.get("deck_discard_receipt_flush_count", -1),
			}
		}),
		JSON.stringify({
			"receipt_count": runtime_debug.get("v076_deck_lifecycle_receipt_count", -1),
			"captured_receipts": _deck_lifecycle_receipts,
			"identity_count": runtime_debug.get("v076_deck_lifecycle_receipt_identity_count", -1),
			"duplicate_count": runtime_debug.get("v076_deck_lifecycle_duplicate_count", -1),
			"collision_count": runtime_debug.get("v076_deck_lifecycle_collision_count", -1),
			"lineage_failure_count": runtime_debug.get("v076_deck_lifecycle_lineage_failure_count", -1),
		})
	])
	_expect(
		bool(deck_debug.get("draw_pile_visible", false)),
		"the production player dock visibly exposes the draw pile"
	)
	_expect(
		bool(deck_debug.get("discard_pile_visible", false)),
		"the production player dock visibly exposes the discard pile"
	)
	_expect(
		int(deck_debug.get("acquire_animation_count", 0)) >= 2,
		"two natural accepted acquisitions animate into their authority zones"
	)
	_expect(
		int(deck_debug.get("discard_animation_count", 0)) >= 1,
		"the naturally resolved local card visibly reaches discard"
	)
	_expect(
		int(deck_debug.get("draw_animation_count", 0)) >= 1,
		"the natural refill receipt visibly draws at least one card"
	)
	_expect(
		int(deck_debug.get("enter_hand_animation_count", -1))
			== int(deck_debug.get("draw_animation_count", -2)),
		"every visible draw completes at the hand anchor"
	)
	_expect(
		int(deck_debug.get("target_zone_mismatch_count", -1)) == 0,
		"deck lifecycle targets match the authority destination zones"
	)
	_expect(
		int(deck_debug.get("receipt_collision_count", -1)) == 0,
		"deck lifecycle presentation receipt identities never collide"
	)
	_expect(
		int(runtime_debug.get("v076_deck_lifecycle_collision_count", -1)) == 0,
		"RuntimeOwner rejects no colliding owner-private lifecycle receipt"
	)
	_expect(
		int(runtime_debug.get("v076_deck_lifecycle_lineage_failure_count", -1)) == 0,
		"every production lifecycle cue retains authority receipt lineage"
	)
	for key in [
		"animation_gameplay_mutation_count",
		"animation_rng_draw_delta",
		"animation_authority_sequence_delta",
		"animation_deck_order_mutation_count",
		"animation_card_zone_mutation_count",
	]:
		_expect(
			int(deck_debug.get(key, -1)) == 0,
			"deck lifecycle presentation keeps %s at zero" % key
		)
	var evidence := deck_debug.get("evidence", []) as Array
	var complete_rect_evidence_count := 0
	for row_variant in evidence:
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		var start_rect: Variant = row.get("start_rect")
		var mid_rect: Variant = row.get("mid_rect")
		var end_rect: Variant = row.get("end_rect")
		if (
			start_rect is Rect2
			and mid_rect is Rect2
			and end_rect is Rect2
			and (start_rect as Rect2).has_area()
			and (mid_rect as Rect2).has_area()
			and (end_rect as Rect2).has_area()
		):
			complete_rect_evidence_count += 1
	_expect(
		complete_rect_evidence_count >= 3,
		"production lifecycle evidence retains real start, mid, and end Rects"
	)


func _assert_commodity_acquisition() -> Dictionary:
	var before := _flow.call("local_snapshot") as Dictionary
	var before_facts := _dbg_facts(before)
	var before_hand_count := (before_facts.get("hand", []) as Array).size()
	var before_commodity_count := (
		before_facts.get("commodity_inventory", []) as Array
	).size()
	var before_sequence := _scroll_sequence(before)
	var authority_before_purchase := _track_authority_state()
	var track_before_purchase := _track_state(authority_before_purchase)
	var target_control: Control
	var target_payload: Dictionary = {}
	var best_distance := 999999
	var track_rail := _screen.find_child("TrackRail", true, false) as HBoxContainer
	var claimable_candidates: Array[Dictionary] = []
	for child_variant in track_rail.get_children():
		var child := child_variant as Control
		if child == null or not child.has_method("payload"):
			continue
		var payload := child.call("payload") as Dictionary
		if (
			str(payload.get("card_kind", "")) != "commodity_card"
			or not bool(payload.get("claimable", false))
		):
			continue
		claimable_candidates.append(payload.duplicate(true))
		var distance := absi(int(payload.get("local_slot_index", -1)) - 4)
		if distance < best_distance:
			best_distance = distance
			target_control = child
			target_payload = payload.duplicate(true)
	print("V076_COMMODITY_CANDIDATES|rows=%s" % JSON.stringify(claimable_candidates))
	_expect(target_control != null, "natural sushi track exposes a claimable commodity")
	if target_control == null:
		return {}
	var source_track_id := str(target_payload.get("instance_id", ""))
	var source_item_before := _track_item_by_id(
		track_before_purchase,
		source_track_id
	)
	var initial_vacancy_path_position := int(
		source_item_before.get("path_position", -1)
	)
	_expect(
		initial_vacancy_path_position >= 0,
		"commodity source has an authority-owned global path position before purchase"
	)
	await _click_card(target_control)
	var after := before
	for _frame in range(30):
		await process_frame
		after = _flow.call("local_snapshot") as Dictionary
		if (_dbg_facts(after).get("commodity_inventory", []) as Array).size() \
				== before_commodity_count + 1:
			break
	var after_facts := _dbg_facts(after)
	var commodity_inventory := (
		after_facts.get("commodity_inventory", []) as Array
	)
	_expect(
		commodity_inventory.size() == before_commodity_count + 1,
		"one-click acquisition enters the authoritative commodity hand"
	)
	if commodity_inventory.size() == before_commodity_count + 1:
		_first_commodity_acquire_count += 1
	_expect(
		(after_facts.get("hand", []) as Array).size() == before_hand_count,
		"commodity acquisition does not consume the separate general-hand limit"
	)
	var acquired := _commodity_by_track_source(
		commodity_inventory,
		source_track_id
	)
	var acquired_id := str(acquired.get("instance_id", ""))
	_expect(
		str(acquired.get("authority_zone", "")) == "commodity_inventory"
		and str(acquired.get("projection_role", "")) == "commodity_hand",
		"commodity projection binds its existing authority zone and hand role"
	)
	_expect(
		_scroll_sequence(after) == before_sequence,
		"commodity purchase creates a vacancy without advancing scroll_sequence"
	)
	var track_debug := (
		(_runtime.call("debug_snapshot") as Dictionary).get(
			"track_acquisition_policy",
			{}
		) as Dictionary
	)
	_expect(
		int(track_debug.get("supply_cursor_delta_on_acquisition", -1)) == 0
		and int(track_debug.get(
			"supply_instance_sequence_delta_on_acquisition",
			-1
		)) == 0
		and int(track_debug.get("supply_rng_draw_delta_on_acquisition", -1)) == 0
		and int(track_debug.get("immediate_authoritative_refill_count", -1)) == 0,
		"purchase has zero immediate refill, supply cursor, sequence, and RNG delta"
	)
	var authority_after_purchase := _track_authority_state()
	var track_after_purchase := _track_state(authority_after_purchase)
	var before_vacancies := _track_vacancy_positions(track_before_purchase)
	var expected_vacancies := before_vacancies.duplicate()
	if initial_vacancy_path_position >= 0:
		expected_vacancies.append(initial_vacancy_path_position)
	expected_vacancies.sort()
	var actual_vacancies := _track_vacancy_positions(track_after_purchase)
	_expect(
		actual_vacancies == expected_vacancies,
		"purchase leaves the same global path vacancy without shifting other slots"
	)
	_expect(
		_track_item_by_id(track_after_purchase, source_track_id).is_empty(),
		"purchased commodity source leaves the authoritative track exactly once"
	)
	_expect(
		int(track_after_purchase.get("next_instance_sequence", -1))
			== int(track_before_purchase.get("next_instance_sequence", -2)),
		"purchase does not advance the authoritative supply instance sequence"
	)
	_expect(
		int(track_after_purchase.get("revision", -1))
			== int(track_before_purchase.get("revision", -2)) + 1,
		"purchase advances the track revision exactly once"
	)
	var preview_rail := _screen.find_child(
		"CommodityHandPreviewRail",
		true,
		false
	) as HBoxContainer
	var visible_faces := 0
	for child_variant in preview_rail.get_children():
		var child := child_variant as Control
		if child != null and child.visible and child.has_method("debug_snapshot"):
			visible_faces += 1
	_expect(
		visible_faces == commodity_inventory.size(),
		"independent commodity row immediately renders every owned real card face"
	)
	_expect(
		_card_zone_duplicate_count(after_facts) == 0,
		"every card instance remains in exactly one authoritative DBG zone"
	)
	var commodity_tab := _screen.find_child(
		"CommodityHandTabButton",
		true,
		false
	) as Button
	_expect(
		not commodity_tab.button_pressed,
		"successful acquisition keeps the ordinary hand visible"
	)
	var dock_title := _screen.find_child("DockTitle", true, false) as Label
	_expect(dock_title != null, "dock title is present after commodity acquisition")
	var hand_rail := _screen.find_child("HandRail", true, false) as HBoxContainer
	_expect(hand_rail != null, "commodity acquisition preserves the main hand rail")
	for _frame in range(12):
		if (
			dock_title != null
			and dock_title.text.begins_with("HAND ")
			and hand_rail != null
			and _hand_rail_cards(hand_rail).size()
				== (after_facts.get("hand", []) as Array).size()
		):
			break
		await process_frame
	if dock_title != null:
		_expect(
			dock_title.text.begins_with("HAND "),
			"commodity acquisition does not replace the ordinary-hand title"
		)
	_expect(
		_hand_rail_cards(hand_rail).size() == (after_facts.get("hand", []) as Array).size(),
		"ordinary cards remain visible after commodity acquisition"
	)
	commodity_tab.pressed.emit()
	for _frame in range(12):
		var commodity_cards_ready := true
		for candidate in _hand_rail_cards(hand_rail):
			var candidate_width := candidate.get_global_rect().size.x
			if candidate_width < 68.0 or candidate_width > 104.0:
				commodity_cards_ready = false
				break
		if (
			dock_title != null
			and dock_title.text.contains("商品手牌")
			and hand_rail != null
			and hand_rail.get_child_count() == commodity_inventory.size()
			and int(hand_rail.get_theme_constant("separation")) >= 0
			and commodity_cards_ready
		):
			break
		await process_frame
	_expect(
		dock_title != null and dock_title.text.contains("商品手牌"),
		"explicit commodity-tab input expands the commodity hand"
	)
	var compact_visible_after_expand := 0
	for child_variant in preview_rail.get_children():
		var child := child_variant as Control
		if child != null and child.visible and child.has_method("debug_snapshot"):
			compact_visible_after_expand += 1
	_expect(
		compact_visible_after_expand == 0,
		"expanded commodity view suppresses the duplicate compact controls"
	)
	var hand_cards := _hand_rail_cards(hand_rail)
	_expect(
		hand_cards.size() == commodity_inventory.size(),
		"commodity hand rail shows every owned commodity card"
	)
	_expect(
		int(hand_rail.get_theme_constant("separation")) >= 0,
		"commodity hand uses non-negative rail spacing"
	)
	var commodity_previous_rect := Rect2()
	for card in hand_cards:
		_expect(
			card.size_flags_horizontal != Control.SIZE_EXPAND_FILL,
			"commodity card does not expand to the full rail width"
		)
		var card_rect := card.get_global_rect()
		_expect(
			card_rect.size.x >= 68.0 and card_rect.size.x <= 104.0,
			"commodity card width stays bounded after acquisition (width=%.2f, rail=%s)"
				% [card_rect.size.x, hand_rail.size]
		)
		if commodity_previous_rect.has_area():
			_expect(
				card_rect.position.x >= commodity_previous_rect.end.x - 1.0,
				"commodity hand cards do not overlap unexpectedly"
			)
		commodity_previous_rect = card_rect
	var general_tab := _screen.find_child(
		"GeneralHandTabButton",
		true,
		false
	) as Button
	general_tab.pressed.emit()
	var reverted_title := _screen.find_child("DockTitle", true, false) as Label
	for _frame in range(12):
		var general_cards := _hand_rail_cards(hand_rail)
		var general_cards_ready := not general_cards.is_empty()
		if general_cards_ready:
			for card in general_cards:
				var card_rect := card.get_global_rect()
				if card_rect.size.x < 68.0 or card_rect.size.x > 104.0:
					general_cards_ready = false
					break
		if (
			reverted_title != null
			and reverted_title.text.begins_with("HAND ")
			and not reverted_title.text.contains("商品手牌")
			and hand_rail != null
			and general_cards_ready
		):
			break
		await process_frame
	_expect(reverted_title != null, "dock title remains present after returning to general hand")
	if reverted_title != null:
		_expect(
			reverted_title.text.begins_with("HAND "),
			"switching back restores the general-hand title"
		)
		_expect(
			reverted_title.text.contains("CURRENT / DIRECT ACTION"),
			"general-hand title keeps the direct-action context"
		)
		_expect(
			not reverted_title.text.contains("商品手牌"),
			"general-hand title no longer advertises the commodity view"
		)
	var general_cards := _hand_rail_cards(hand_rail)
	_expect(
		general_cards.size() > 0,
		"general hand remains populated after the commodity view closes"
	)
	var previous_rect: Rect2 = Rect2()
	var general_separation := float(hand_rail.get_theme_constant("separation"))
	for card in general_cards:
		var card_rect := card.get_global_rect()
		_expect(
			card_rect.size.x >= 68.0 and card_rect.size.x <= 104.0,
			"general hand card width stays bounded after the tab switch"
		)
		if previous_rect.has_area():
			_expect(
				card_rect.position.x >= previous_rect.position.x - 1.0,
				"general hand card order stays monotonic across the rail"
			)
			_expect(
				previous_rect.end.x - card_rect.position.x
					<= maxf(0.0, -general_separation) + 1.0,
				"general hand card overlap stays within the authored fan spacing"
			)
		previous_rect = card_rect
	var screen_debug := _screen.call("debug_snapshot") as Dictionary
	var hand_inventory := (
		(screen_debug.get("human_playability", {}) as Dictionary).get(
			"hand_control_inventory",
			{}
		) as Dictionary
	)
	_expect(
		int(hand_inventory.get("general_hand_control_count", -1))
			== int(hand_inventory.get("general_hand_projection_count", -2))
		and int(hand_inventory.get("general_hand_authority_count", -1))
			== (after_facts.get("hand", []) as Array).size(),
		"general hand controls match the visible projection and authority count"
	)
	_expect(
		int(hand_inventory.get("commodity_hand_control_count", -1))
			== int(hand_inventory.get("commodity_hand_projection_count", -2))
		and int(hand_inventory.get("commodity_hand_authority_count", -1))
			== commodity_inventory.size(),
		"commodity controls match the independent projection and authority count"
	)
	_expect(
		int(hand_inventory.get("hand_duplicate_instance_control_count", -1)) == 0
		and int(hand_inventory.get("animation_clone_inside_hand_container_count", -1)) == 0
		and int(hand_inventory.get("hand_unexpected_control_overlap_count", -1)) == 0,
		"hand lifetime inventory has no duplicate, clone, or unexpected overlap"
	)
	_record_multi_window_state("S2_FIRST_COMMODITY_ACQUIRED", {
		"first_commodity_instance_id": acquired_id,
		"first_claimability_state": target_payload.get("claimability_state", ""),
		"first_source_instance_id": source_track_id,
	})
	return {
		"vacancy_slot": int(target_payload.get("local_slot_index", -1)),
		"vacancy_path_position": initial_vacancy_path_position,
		"commodity_instance_id": acquired_id,
	}


func _assert_human_card_zone_transition() -> String:
	var before := _flow.call("local_snapshot") as Dictionary
	var before_facts := _dbg_facts(before)
	var card_id := ""
	for option_variant in before.get("legal_actions", []) as Array:
		if not (option_variant is Dictionary):
			continue
		var option := option_variant as Dictionary
		if str(option.get("action_domain", "facility")) != "facility":
			continue
		var candidate_id := str(option.get("card_instance_id", ""))
		if not _card_by_id(before_facts.get("hand", []) as Array, candidate_id).is_empty():
			card_id = candidate_id
			break
	_expect(not card_id.is_empty(), "general hand exposes a legal public facility card")
	if card_id.is_empty():
		return ""
	var selected_option := _first_legal_option_for_card(card_id)
	_facility_trace = {
		"selected_card_instance_id": card_id,
		"facility_type": str(selected_option.get("facility_type", "")),
		"industry_id": str(selected_option.get("industry_id", "")),
		"facility_action_mode": str(selected_option.get("facility_action_mode", "")),
		"facility_region_id": str(selected_option.get("target_region_id", "")),
		"facility_slot_id": str(selected_option.get("target_slot_id", "")),
	}
	_record_multi_window_state("S5_FACILITY_CARD_SELECTED", _facility_trace)
	var animation_before := int((
		(_screen.call("debug_snapshot") as Dictionary).get(
			"public_arrangement",
			{}
		) as Dictionary
	).get("card_move_animation_count", 0))
	var input_before := _screen.call("debug_snapshot") as Dictionary
	var manual_drag_before := int(input_before.get("manual_drag_drop_count", 0))
	var central_drop_before := int(input_before.get("central_card_drop_count", 0))
	var source_capture_before := int(input_before.get(
		"card_transition_source_rect_capture_count",
		0
	))
	var first_receipt_start := _receipts.size()
	var first_bridge_before := _card_table_debug()
	var queued := await _queue_human_card_through_table(card_id)
	_expect(queued, "drag/table target path accepts the real human card")
	var input_after := _screen.call("debug_snapshot") as Dictionary
	_expect(
		int(input_after.get("manual_drag_drop_count", 0)) == manual_drag_before + 1,
		"real SceneTree pointer drag reaches the bounded manual bridge exactly once"
	)
	_expect(
		int(input_after.get("central_card_drop_count", 0)) == central_drop_before + 1,
		"native/manual routing produces exactly one central drop request"
	)
	_expect(
		int(input_after.get("card_transition_source_rect_capture_count", 0))
			== source_capture_before + 1
		and int(input_after.get("card_transition_source_rect_missing_count", 0)) == 0,
		"card.queue captures the real hand source rect before projection refresh"
	)
	var after_queue := _flow.call("local_snapshot") as Dictionary
	var queued_facts := _dbg_facts(after_queue)
	_facility_trace["pending_action_id"] = str(
		(after_queue.get("queued_actions", []) as Array)[0].get("action_id", "")
		if not (after_queue.get("queued_actions", []) as Array).is_empty()
		and (after_queue.get("queued_actions", []) as Array)[0] is Dictionary
		else ""
	)
	_facility_trace["queue_accepted"] = true
	_record_multi_window_state("S6_FACILITY_CARD_COMMIT_ACCEPTED", _facility_trace)
	_expect(
		_card_by_id(queued_facts.get("hand", []) as Array, card_id).is_empty(),
		"accepted public card disappears from GENERAL_HAND immediately"
	)
	_expect(
		not _card_by_id(
			queued_facts.get("committed_escrow", []) as Array,
			card_id
		).is_empty(),
		"accepted public card moves to the existing committed escrow owner"
	)
	_expect(
		(after_queue.get("pending_public_card_instance_ids", []) as Array).has(
			card_id
		),
		"viewer snapshot projects the card as pending public submission"
	)
	_expect(
		_card_zone_duplicate_count(queued_facts) == 0,
		"queued card is not duplicated across hand, escrow, discard, or commodity"
	)
	_assert_rendered_hand_stability(queued_facts)
	var clock_before_commit := _runtime.call("debug_snapshot") as Dictionary
	var phase_before_commit := str(clock_before_commit.get("phase", ""))
	var remaining_before_commit := float(
		clock_before_commit.get("submission_seconds_remaining", -1.0)
	)
	await create_timer(0.35).timeout
	var clock_after_commit := _runtime.call("debug_snapshot") as Dictionary
	var phase_after_commit := str(clock_after_commit.get("phase", ""))
	var remaining_after_commit := float(
		clock_after_commit.get("submission_seconds_remaining", -1.0)
	)
	_action_window_sample_count += 1
	var post_commit_liveness := (
		phase_after_commit == "resolving"
		or phase_after_commit != "submission"
		or remaining_after_commit < remaining_before_commit
	)
	if phase_before_commit == "submission" and phase_after_commit == "submission" \
		and remaining_after_commit >= remaining_before_commit - 0.001:
		_countdown_frozen_after_commit_count += 1
	_expect(
		post_commit_liveness,
		"accepted card commit keeps the authoritative countdown live or enters resolving"
	)
	_facility_trace["phase_before_commit"] = phase_before_commit
	_facility_trace["phase_after_commit"] = phase_after_commit
	_facility_trace["remaining_before_commit"] = remaining_before_commit
	_facility_trace["remaining_after_commit"] = remaining_after_commit
	_record_multi_window_state("S7_SUBMISSION_WINDOW_CONTINUES_OR_ENDS", _facility_trace)
	await _assert_hand_card_node_reuse_on_reapply()
	var first_transition_id := await _assert_human_public_play_bridge(
		card_id,
		after_queue,
		first_receipt_start,
		first_bridge_before
	)
	if not first_transition_id.is_empty():
		_human_public_transition_ids.append(first_transition_id)
	var animation_after := int((
		(_screen.call("debug_snapshot") as Dictionary).get(
			"public_arrangement",
			{}
		) as Dictionary
	).get("card_move_animation_count", 0))
	_expect(
		animation_after == animation_before + 1,
		"human card animates once from its actual hand rect into the arrangement"
	)

	var remove := _first_queue_remove_button()
	_expect(remove != null, "queued card exposes the existing remove action")
	if remove != null:
		remove.pressed.emit()
		for _frame in range(8):
			await process_frame
	var restored := _flow.call("local_snapshot") as Dictionary
	var restored_facts := _dbg_facts(restored)
	_expect(
		not _card_by_id(restored_facts.get("hand", []) as Array, card_id).is_empty()
		and _card_by_id(
			restored_facts.get("committed_escrow", []) as Array,
			card_id
		).is_empty(),
		"pre-lock removal restores the same card from escrow to hand"
	)
	_expect(
		_card_zone_duplicate_count(restored_facts) == 0,
		"restored card still has exactly one authoritative zone"
	)
	if not _card_by_id(restored_facts.get("hand", []) as Array, card_id).is_empty():
		var second_receipt_start := _receipts.size()
		var second_bridge_before := _card_table_debug()
		var requeued := await _queue_human_card_through_table(card_id)
		_expect(
			requeued,
			"restored card can be selected and queued again through the same UI path"
		)
		var requeued_snapshot := _flow.call("local_snapshot") as Dictionary
		var second_transition_id := await _assert_human_public_play_bridge(
			card_id,
			requeued_snapshot,
			second_receipt_start,
			second_bridge_before
		)
		_expect(
			first_transition_id.is_empty()
			or second_transition_id != first_transition_id,
			"remove and requeue receive a fresh public action correlation identity"
		)
		if not second_transition_id.is_empty():
			_human_public_transition_ids.append(second_transition_id)
		_expect(
			int((
				(_screen.call("debug_snapshot") as Dictionary).get(
					"public_arrangement",
					{}
				) as Dictionary
			).get("card_move_animation_count", 0)) == animation_after + 1,
			"a legitimate remove and requeue animates the same card exactly once again"
		)
		_assert_rendered_hand_stability(_dbg_facts(
			_flow.call("local_snapshot") as Dictionary
		))
	return card_id


func _queue_human_card_through_table(card_id: String) -> bool:
	var hand_rail := _screen.find_child("HandRail", true, false) as HBoxContainer
	var card_control: Control
	var payload: Dictionary = {}
	for child_variant in hand_rail.get_children():
		var child := child_variant as Control
		if child == null or not child.has_method("payload"):
			continue
		var candidate := child.call("payload") as Dictionary
		if str(candidate.get("instance_id", "")) == card_id:
			card_control = child
			payload = candidate.duplicate(true)
			break
	if card_control == null:
		return false
	if card_control.has_method("presentation_data"):
		var semantic := card_control.call("presentation_data") as Dictionary
		_expect(
			not str(semantic.get("name", "")).strip_edges().is_empty()
			and not str(semantic.get("cost", "")).strip_edges().is_empty()
			and not str(semantic.get("type", "")).strip_edges().is_empty()
			and not str(semantic.get("summary", semantic.get("effect", ""))).strip_edges().is_empty(),
			"real hand card face exposes name, cost, type, and purpose"
		)
	var arrangement := _screen.find_child(
		"CentralPublicActionArrangement",
		true,
		false
	) as Control
	var start_position := card_control.get_global_rect().get_center()
	_push_mouse_motion(start_position, Vector2.ZERO)
	await process_frame
	_push_mouse_button(MOUSE_BUTTON_LEFT, start_position, true)
	await process_frame
	var drag_position := start_position + Vector2(32.0, -96.0)
	_push_mouse_motion(drag_position, drag_position - start_position)
	await process_frame
	# The production drag bridge opens the bounded public drawer after the
	# dead-zone.  Release only inside that real panel rectangle; never emit the
	# card_drop_requested signal directly from a test.
	var drop_rect := Rect2()
	if arrangement.has_method("drag_drop_rect"):
		var candidate_rect: Variant = arrangement.call("drag_drop_rect")
		if candidate_rect is Rect2:
			drop_rect = candidate_rect
	if not drop_rect.has_area():
		return false
	var finish_position := drop_rect.get_center()
	_push_mouse_motion(finish_position, finish_position - drag_position)
	await process_frame
	_push_mouse_button(MOUSE_BUTTON_LEFT, finish_position, false)
	await process_frame
	var choices := _screen.find_child(
		"RegionPopupTargetChoices",
		true,
		false
	) as Control
	if choices != null and choices.is_visible_in_tree():
		for candidate_variant in choices.find_children("*", "Button", true, false):
			var candidate := candidate_variant as Button
			if candidate != null and candidate.visible and not candidate.disabled:
				candidate.pressed.emit()
				await process_frame
				break
	var confirm := _screen.find_child(
		"CurrentActionConfirmButton",
		true,
		false
	) as Button
	if confirm == null or confirm.disabled:
		var choice_debug: Array[Dictionary] = []
		if choices != null:
			for choice_variant in choices.find_children("*", "Button", true, false):
				var choice := choice_variant as Button
				if choice == null:
					continue
				choice_debug.append({
					"text": choice.text,
					"visible": choice.visible,
					"disabled": choice.disabled,
					"queued_for_deletion": choice.is_queued_for_deletion(),
				})
		var first_option := _first_legal_option_for_card(card_id)
		var resolution: Dictionary = {}
		if not first_option.is_empty():
			resolution = _flow.call(
				"resolve_map_target",
				card_id,
				str(first_option.get("target_region_id", "")),
				str(first_option.get("facility_type", "")),
				str(first_option.get("industry_id", "")),
				str(first_option.get("facility_action_mode", ""))
			) as Dictionary
		var action_status := _screen.get("_action_status") as Label
		var action_reason := _screen.get("_current_action_reason") as Label
		print("V076_REQUEUE_UI_DIAGNOSTIC|stage=confirm_disabled|state=%s" % JSON.stringify({
			"phase": (_flow.call("local_snapshot") as Dictionary).get("phase"),
			"selected_card_id": _screen.get("_selected_card_id"),
			"current_action_mode": _screen.get("_current_action_mode"),
			"pending_confirm_binding": _screen.get("_pending_confirm_binding"),
			"legal_option_count": _legal_option_count_for_card(card_id),
			"confirm_exists": confirm != null,
			"confirm_disabled": confirm.disabled if confirm != null else true,
			"popup_visible": choices.is_visible_in_tree() if choices != null else false,
			"choice_debug": choice_debug,
			"first_option": first_option,
			"direct_resolution": resolution,
			"action_status": action_status.text if action_status != null else "",
			"action_reason": action_reason.text if action_reason != null else "",
		}))
		return false
	var accepted_before := _receipt_count("card.queue", true)
	confirm.pressed.emit()
	for _frame in range(12):
		await process_frame
		if _receipt_count("card.queue", true) > accepted_before:
			return true
	print("V076_REQUEUE_UI_DIAGNOSTIC|stage=no_accept|receipts=%s" % JSON.stringify(
		_receipts.slice(maxi(0, _receipts.size() - 4), _receipts.size())
	))
	return false


func _assert_public_arrangement_interaction() -> void:
	var arrangement := _screen.find_child(
		"CentralPublicActionArrangement",
		true,
		false
	) as Control
	var planet := _screen.find_child("PlanetStageViewport", true, false) as Control
	var map_rect_before := planet.get_global_rect()
	var toggle := arrangement.find_child("PopoutToggle", true, false) as Button
	_expect(toggle != null, "public card-table popout exposes a collapse control")
	if toggle == null:
		return
	var before := arrangement.call("arrangement_debug_snapshot") as Dictionary
	_expect(
		str(before.get("public_arrangement_root_mouse_filter", "")) == "IGNORE"
			and int(before.get("public_arrangement_fullscreen_opaque_layer_count", -1)) == 0,
		"public arrangement root is transparent and does not own a fullscreen opaque layer"
	)
	_expect(
		bool(before.get("public_arrangement_pushes_map_layout", true)) == false
			and float(before.get("public_arrangement_map_visible_area_ratio", 0.0)) >= 0.55,
		"map remains visible behind the bounded public drawer"
	)
	# The public batch remains inspectable throughout its 30-second submission
	# window.  This replaces the old 1.05-second PEEK that real humans could miss.
	await create_timer(1.18).timeout
	var post_peek := arrangement.call("arrangement_debug_snapshot") as Dictionary
	print("V076_PUBLIC_ARRANGEMENT_PERSISTENCE|phase=%s|submission_active=%s|expanded=%s|entry_count=%d|state=%s|user_toggled=%s|toggle_reason=%s|target_selection_active=%s|resolution_active=%s|resolution_stage=%s" % [
		str((_flow.call("local_snapshot") as Dictionary).get("phase", "")),
		str(post_peek.get("submission_window_active", false)),
		str(post_peek.get("public_arrangement_expanded", false)),
		int(post_peek.get("last_public_entry_count", 0)),
		str(post_peek.get("public_arrangement_state", "")),
		str(post_peek.get("public_arrangement_user_toggled", false)),
		str(post_peek.get("public_arrangement_user_toggle_reason", "")),
		str(post_peek.get("target_selection_collapse_active", false)),
		str(post_peek.get("resolution_window_active", false)),
		str(post_peek.get("resolution_stage", "")),
	])
	_expect(
		bool(post_peek.get("submission_window_active", false))
		and bool(post_peek.get("public_arrangement_expanded", false)),
		"public arrangement remains inspectable across the submission window"
	)
	if bool(post_peek.get("public_arrangement_expanded", false)):
		toggle.pressed.emit()
		await process_frame
	var collapsed := arrangement.call("arrangement_debug_snapshot") as Dictionary
	_expect(
		not bool(collapsed.get("public_arrangement_expanded", true)),
		"public arrangement collapses to its compact handle"
	)
	_expect(
		planet.get_global_rect().is_equal_approx(map_rect_before),
		"collapsing the overlay preserves the map's primary layout rect"
	)
	toggle.pressed.emit()
	await process_frame
	var expanded := arrangement.call("arrangement_debug_snapshot") as Dictionary
	_expect(
		bool(expanded.get("public_arrangement_expanded", false)),
		"public arrangement expands without repartitioning the table"
	)
	var card_rail := arrangement.find_child(
		"PublicCardFaceRail",
		true,
		false
	) as HBoxContainer
	var face: Control
	if card_rail != null and card_rail.get_child_count() > 0:
		var wrapper := card_rail.get_child(0) as Control
		if wrapper != null and wrapper.get_child_count() > 0:
			face = wrapper.get_child(wrapper.get_child_count() - 1) as Control
	_expect(face != null, "expanded arrangement renders a real interactive card face")
	if face != null and face.has_method("card_face"):
		var inner := face.call("card_face") as Control
		inner.mouse_entered.emit()
		await process_frame
	# Exercise every real face once so the readiness evidence measures hover
	# coverage instead of assuming that one sampled card proves the whole rail.
	if card_rail != null:
		for wrapper_variant in card_rail.get_children():
			var wrapper := wrapper_variant as Control
			if wrapper == null or wrapper.get_child_count() == 0:
				continue
			var candidate_face := wrapper.get_child(wrapper.get_child_count() - 1) as Control
			if candidate_face != null and candidate_face.has_method("card_face"):
				var candidate_inner := candidate_face.call("card_face") as Control
				candidate_inner.mouse_entered.emit()
				await process_frame
	var hovered := arrangement.call("arrangement_debug_snapshot") as Dictionary
	_expect(
		int(hovered.get("arrangement_hover_count", 0)) >= 1,
		"hovering a public card opens its effect inspection path"
	)
	_expect(
		int(hovered.get("arrangement_hover_layout_reflow_count", -1)) == 0,
		"public card hover does not reflow the popout or map"
	)
	_expect(
		float(hovered.get("arrangement_card_hover_coverage_percent", 0.0)) >= 100.0,
		"every rendered public card exposes the real hover inspection path"
	)
	# Escape and an outside click close only the drawer; the map keeps its own
	# input surface because the arrangement root is MOUSE_FILTER_IGNORE.
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	arrangement.call("_input", escape)
	await process_frame
	_expect(
		not bool((arrangement.call("arrangement_debug_snapshot") as Dictionary).get(
			"public_arrangement_expanded",
			true
		)),
		"Escape closes the public drawer"
	)
	toggle.pressed.emit()
	await process_frame
	var outside := InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	outside.position = planet.get_global_rect().position + Vector2(8.0, 8.0)
	arrangement.call("_input", outside)
	await process_frame
	_expect(
		not bool((arrangement.call("arrangement_debug_snapshot") as Dictionary).get(
			"public_arrangement_expanded",
			true
		)),
		"clicking outside the drawer closes it without swallowing the map"
	)


func _assert_three_authoritative_track_handoffs(
	initial_vacancy_path_position: int,
	human_card_id: String
) -> String:
	_expect(
		initial_vacancy_path_position >= 0,
		"purchase records a real global authority vacancy position"
	)
	var target_vacancy_path_position := initial_vacancy_path_position
	var initial_track := _track_state(_track_authority_state())
	var capacity := int(initial_track.get("capacity", -1))
	# The natural production seed reaches a legitimate Victory/FinalSettlement
	# after its fourth batch and therefore exposes exactly three pre-terminal
	# track advances.  This production-main probe proves those three visible
	# handoffs.  Natural-tail refill remains owned by the inherited focused track
	# authority sentinel; attempting to force a fourth post-Victory handoff would
	# misclassify a normal terminal as a gameplay loop failure.
	var handoff_count := 3
	var handoff_count_override := OS.get_environment("V076_HANDOFF_COUNT").to_int()
	if handoff_count_override > 0:
		handoff_count = mini(3, maxi(1, handoff_count_override))
	_expect(capacity > initial_vacancy_path_position, "natural-tail probe derives a positive authority run length")
	for handoff_index in range(handoff_count):
		var submission_window := await _ensure_submission_window()
		_expect(
			bool(submission_window.get("ready", false)),
			"handoff %d reaches a pre-terminal submission window"
				% (handoff_index + 1)
		)
		if not bool(submission_window.get("ready", false)):
			break
		_action_window_sample_count += 1
		var snapshot := _flow.call("local_snapshot") as Dictionary
		if handoff_index >= 2 and not _multi_window_trace_seen.has(
			"S12_NEXT_ACTION_WINDOW_STARTED"
		):
			_record_multi_window_state("S12_NEXT_ACTION_WINDOW_STARTED", {
				"track_handoff_index": handoff_index + 1,
			})
		var authority_before := _track_authority_state()
		var track_before := _track_state(authority_before)
		var sequence_before := int(track_before.get("scroll_sequence", -1))
		_expect(
			str(snapshot.get("phase", "")) == "submission",
			"handoff %d begins at a normal submission window"
				% (handoff_index + 1)
		)
		var lock := _screen.find_child("LockButton", true, false) as Button
		lock.pressed.emit()
		var maintenance_requested := false
		var handoff_started_msec := -1
		var authority_reached_msec := -1
		var projection_reached_msec := -1
		var advanced := snapshot
		var authority_after: Dictionary = {}
		for _frame in range(180):
			await process_frame
			if not _multi_window_trace_seen.has("S8_RESOLUTION_STARTED") \
				and str(_runtime.call("phase")) == "resolving":
				_record_multi_window_state("S8_RESOLUTION_STARTED", {
					"facility_commit_id": _facility_trace.get("facility_commit_id", ""),
				})
			# Do not call local_snapshot on every frame here.  It rebuilds the
			# complete player projection and used to make the probe measure its
			# own polling cost instead of the authority handoff edge.  The
			# production Finish button is the presentation-side readiness signal;
			# the existing track core is the timing authority.
			if not maintenance_requested:
				var finish := _screen.find_child(
					"FinishMaintenanceButton",
					true,
					false
				) as Button
				if finish != null and not finish.disabled:
					maintenance_requested = true
					handoff_started_msec = Time.get_ticks_msec()
					finish.pressed.emit()
					print("V076_HANDOFF_SIGNAL_TIMING|index=%d|emit_elapsed_seconds=%.3f" % [
						handoff_index + 1,
						float(Time.get_ticks_msec() - handoff_started_msec) / 1000.0,
					])
			# Read the authority-owned commit timestamp while waiting for the
			# sequence edge; cloning the full envelope on every frame would measure
			# the probe's own audit cost instead of the production handoff.
			var advance_timing := _track_advance_timing_snapshot()
			if int(advance_timing.get("sequence", -1)) > sequence_before:
				authority_reached_msec = int(advance_timing.get(
					"committed_msec",
					-1
				))
				authority_after = _track_authority_state()
				break
		var presentation_probe := true
		if authority_reached_msec >= 0 and presentation_probe:
			# The authority edge is the hard pacing measurement.  Separately wait
			# for the normal production projection to expose the same sequence so
			# the evidence still covers what a player can see.
			for _projection_frame in range(120):
				advanced = _flow.call("local_snapshot") as Dictionary
				if _scroll_sequence(advanced) == sequence_before + 1:
					projection_reached_msec = Time.get_ticks_msec()
					break
				await process_frame
		elif authority_reached_msec < 0:
			advanced = _flow.call("local_snapshot") as Dictionary
		else:
			# After the first three visible handoffs, the full-tail extension is an
			# authority lineage probe.  Avoid polling a cloned full snapshot on every
			# frame; the next iteration still uses the production UI Lock/Finish edge.
			projection_reached_msec = authority_reached_msec
		if authority_after.is_empty():
			authority_after = _track_authority_state()
		var track_after := _track_state(authority_after)
		var authority_sequence := int(track_after.get("scroll_sequence", -1))
		var current_sequence := int(track_after.get("scroll_sequence", -1))
		var handoff_elapsed_seconds := (
			float(authority_reached_msec - handoff_started_msec) / 1000.0
			if handoff_started_msec >= 0 and authority_reached_msec >= 0
			else -1.0
		)
		var projection_elapsed_seconds := (
			float(projection_reached_msec - handoff_started_msec) / 1000.0
			if handoff_started_msec >= 0 and projection_reached_msec >= 0
			else -1.0
		)
		print("V076_HANDOFF_TIMING|index=%d|authority_elapsed_seconds=%.3f|projection_elapsed_seconds=%.3f|sequence=%d" % [
			handoff_index + 1,
			handoff_elapsed_seconds,
			projection_elapsed_seconds,
			current_sequence,
		])
		if current_sequence != sequence_before + 1:
			print("V076_HANDOFF_DIAGNOSTIC|index=%d|snapshot=%s|runtime=%s" % [
				handoff_index + 1,
				JSON.stringify({
					"phase": advanced.get("phase"),
					"batch_number": advanced.get("batch_number"),
					"submission_locked": advanced.get("submission_locked"),
					"queued_actions": advanced.get("queued_actions"),
					"scroll_sequence": current_sequence,
				}),
				JSON.stringify({
					"phase": (_runtime.call("debug_snapshot") as Dictionary).get("phase"),
					"runtime_error_count": (_runtime.call("debug_snapshot") as Dictionary).get("runtime_error_count"),
					"invalid_action_reasons": (_runtime.call("debug_snapshot") as Dictionary).get("invalid_action_reasons"),
				}),
			])
		_expect(
			current_sequence == sequence_before + 1
			and authority_sequence == sequence_before + 1,
			"handoff %d increments authoritative scroll_sequence once"
				% (handoff_index + 1)
		)
		_expect(
			handoff_started_msec >= 0 and handoff_elapsed_seconds <= 2.0,
			"handoff %d reaches the next player within two wall seconds"
				% (handoff_index + 1)
		)
		target_vacancy_path_position = _assert_authoritative_track_transition(
			authority_before,
			authority_after,
			target_vacancy_path_position,
			handoff_index + 1,
		)
		if target_vacancy_path_position < 0:
			_natural_tail_exit_observed = true
		if presentation_probe:
			var settled := false
			for _settle_frame in range(180):
				await process_frame
				if is_zero_approx((_screen.find_child(
					"TrackRail",
					true,
					false
				) as Control).position.x):
					settled = true
					break
			var terminal_snapshot := _flow.call("local_snapshot") as Dictionary
			var terminal_phase := str(terminal_snapshot.get("phase", ""))
			var settle_classification := (
				"SETTLED"
				if settled
				else "NORMAL_TERMINAL"
				if terminal_phase == "settled"
				else "GAP"
			)
			print("V076_HANDOFF_SETTLE_CLASSIFICATION|index=%d|phase=%s|classification=%s|settled=%s" % [
				handoff_index + 1,
				terminal_phase,
				settle_classification,
				str(settled),
			])
			_screen.call("_update_acceptance_state")
			_expect(
				settled or terminal_phase == "settled",
				"handoff %d animation settles in the new physical slots or reaches NORMAL_TERMINAL"
				% (handoff_index + 1)
			)
			if handoff_index == 1 and maintenance_requested:
				if not _multi_window_trace_seen.has("S9_FACILITY_EFFECT_COMMITTED"):
					_record_multi_window_state("S9_FACILITY_EFFECT_COMMITTED", {
						"facility_commit_id": _facility_trace.get("facility_commit_id", ""),
					})
				if not _multi_window_trace_seen.has("S10_PUBLIC_FACILITY_PROJECTION_PUBLISHED"):
					_record_multi_window_state("S10_PUBLIC_FACILITY_PROJECTION_PUBLISHED", {
						"facility_commit_id": _facility_trace.get("facility_commit_id", ""),
					})
				if not _multi_window_trace_seen.has("S11_MAP_MARKER_PRESENTED"):
					_record_multi_window_state("S11_MAP_MARKER_PRESENTED", {
						"facility_commit_id": _facility_trace.get("facility_commit_id", ""),
					})
		if handoff_index == 0:
			_record_multi_window_state("S3_FIRST_TRACK_HANDOFF", {
				"track_handoff_index": handoff_index + 1,
				"advance_sequence": current_sequence,
			})
			await _assert_post_resolution_commodity_acquisition()
			human_card_id = await _assert_human_card_zone_transition()
		if handoff_index == 1:
			if not _multi_window_trace_seen.has("S9_FACILITY_EFFECT_COMMITTED"):
				_record_multi_window_state("S9_FACILITY_EFFECT_COMMITTED", {
					"facility_commit_id": _facility_trace.get("facility_commit_id", ""),
				})
			if not _multi_window_trace_seen.has("S10_PUBLIC_FACILITY_PROJECTION_PUBLISHED"):
				_record_multi_window_state("S10_PUBLIC_FACILITY_PROJECTION_PUBLISHED", {
					"facility_commit_id": _facility_trace.get("facility_commit_id", ""),
				})
			if not _multi_window_trace_seen.has("S11_MAP_MARKER_PRESENTED"):
				_record_multi_window_state("S11_MAP_MARKER_PRESENTED", {
					"facility_commit_id": _facility_trace.get("facility_commit_id", ""),
				})
			if str((_flow.call("local_snapshot") as Dictionary).get("phase", "")) == "submission":
				_record_multi_window_state("S12_NEXT_ACTION_WINDOW_STARTED", {
					"track_handoff_index": handoff_index + 1,
					"advance_sequence": current_sequence,
				})
		if handoff_index == 2:
			_record_multi_window_state("S13_SECOND_OR_THIRD_TRACK_HANDOFF", {
				"track_handoff_index": handoff_index + 1,
				"advance_sequence": current_sequence,
			})
	if not human_card_id.is_empty():
		var final_facts := _dbg_facts(
			_flow.call("local_snapshot") as Dictionary
		)
		_expect(
			_card_by_id(final_facts.get("hand", []) as Array, human_card_id).is_empty()
			and _card_by_id(
				final_facts.get("committed_escrow", []) as Array,
				human_card_id
			).is_empty()
			and not _card_by_id(
				final_facts.get("discard", []) as Array,
				human_card_id
			).is_empty(),
			"resolved human card ends in discard and never reappears in hand"
		)
	_expect(
		int(_screen.acceptance_state.get(
			"track_authoritative_advance_count",
			0
		)) >= 3
		and int(_screen.acceptance_state.get(
			"track_next_player_handoff_count",
			0
		)) >= 3
		and int(_screen.acceptance_state.get(
			"track_oscillation_only_count",
			-1
		)) == 0,
		"track presentation records three authority-owned handoffs and zero wobble"
	)
	print("V076_TRACK_SCREEN_SPACE_ACCEPTANCE|%s" % JSON.stringify({
		"visible_handoff_sample_count": _screen.acceptance_state.get("track_visible_handoff_sample_count", 0),
		"min_slot_ratio": _screen.acceptance_state.get("track_visual_displacement_min_slot_ratio", 0.0),
		"card_min_slot_ratio": _screen.acceptance_state.get("track_card_visual_displacement_min_slot_ratio", 0.0),
		"vacancy_min_slot_ratio": _screen.acceptance_state.get("track_vacancy_visual_displacement_min_slot_ratio", 0.0),
		"end_rect_parity": _screen.acceptance_state.get("track_visual_end_rect_authority_parity", false),
		"vacancy_moves": _screen.acceptance_state.get("vacancy_moves_with_track", false),
		"direction_green": _screen.acceptance_state.get("track_visible_next_player_direction_green", false),
		"current_next_cue_green": _screen.acceptance_state.get("current_and_next_player_visual_cue_green", false),
		"direction_delta_x": _screen.acceptance_state.get("track_direction_screen_delta_x", 0.0),
	}))
	_expect(
		int(_screen.acceptance_state.get(
			"track_visible_handoff_sample_count",
			0
		)) >= 3,
		"three authoritative handoffs each produce a completed screen-space sample"
	)
	_expect(
		float(_screen.acceptance_state.get(
			"track_card_visual_displacement_min_slot_ratio",
			0.0
		)) >= 0.75,
		"every sampled track card visibly moves at least three quarters of one slot"
	)
	_expect(
		float(_screen.acceptance_state.get(
			"track_vacancy_visual_displacement_min_slot_ratio",
			0.0
		)) >= 0.75,
		"the persistent vacancy visibly moves at least three quarters of one slot"
	)
	_expect(
		bool(_screen.acceptance_state.get(
			"track_visual_end_rect_authority_parity",
			false
		))
		and bool(_screen.acceptance_state.get(
			"track_card_end_rect_matches_new_slot",
			false
		))
		and bool(_screen.acceptance_state.get(
			"track_vacancy_end_rect_matches_new_slot",
			false
		)),
		"track cards and vacancy finish in their new authoritative screen slots"
	)
	_expect(
		bool(_screen.acceptance_state.get("vacancy_moves_with_track", false)),
		"the authority-owned vacancy participates in the visible track handoff"
	)
	_expect(
		bool(_screen.acceptance_state.get(
			"current_and_next_player_visual_cue_green",
			false
		))
		and bool(_screen.acceptance_state.get(
			"track_visible_next_player_direction_green",
			false
		)),
		"current and next player cues agree with the visible handoff direction"
	)
	_expect(
		_post_resolution_commodity_acquire_count >= 1
		and _post_resolution_commodity_acquire_rejection_count == 0,
		"a legal commodity can be acquired again in the next submission window"
	)
	return human_card_id


func _assert_post_resolution_commodity_acquisition() -> void:
	var before := _flow.call("local_snapshot") as Dictionary
	_expect(
		str(before.get("phase", "")) == "submission",
		"post-resolution commodity probe begins in the next submission window"
	)
	if str(before.get("phase", "")) != "submission":
		_second_legal_commodity_rejection_count += 1
		_post_resolution_commodity_acquire_rejection_count += 1
		_record_multi_window_state("S4_SECOND_COMMODITY_ACQUIRE_ATTEMPT", {
			"second_acquire_reason_code": "track_acquisition_outside_submission",
		})
		return
	var before_facts := _dbg_facts(before)
	var before_inventory_count := (
		before_facts.get("commodity_inventory", []) as Array
	).size()
	_expect(
		before_inventory_count < 5,
		"post-resolution commodity hand has legal remaining capacity"
	)
	var before_sequence := _scroll_sequence(before)
	var core := _track_core_object()
	var before_supply := _supply_consumption_probe(core)
	var target: Control
	var target_payload: Dictionary = {}
	var track_rail := _screen.find_child("TrackRail", true, false) as HBoxContainer
	for child_variant in track_rail.get_children():
		var child := child_variant as Control
		if child == null or not child.has_method("payload"):
			continue
		var payload := child.call("payload") as Dictionary
		if (
			str(payload.get("card_kind", "")) == "commodity_card"
			and bool(payload.get("claimable", false))
		):
			target = child
			target_payload = payload.duplicate(true)
			break
	_expect(target != null, "next authoritative segment exposes a legal commodity")
	if target == null:
		_second_legal_commodity_rejection_count += 1
		_post_resolution_commodity_acquire_rejection_count += 1
		_record_multi_window_state("S4_SECOND_COMMODITY_ACQUIRE_ATTEMPT", {
			"second_acquire_reason_code": "no_legal_commodity_opportunity",
		})
		return
	_second_legal_commodity_opportunity_count += 1
	var accepted_before := _receipt_count("track.acquire", true)
	var rejected_before := _receipt_count("track.acquire", false)
	await _click_card(target)
	var after := before
	for _frame in range(60):
		await process_frame
		after = _flow.call("local_snapshot") as Dictionary
		if (_dbg_facts(after).get("commodity_inventory", []) as Array).size() \
				== before_inventory_count + 1:
			break
	var after_inventory := (
		_dbg_facts(after).get("commodity_inventory", []) as Array
	)
	var accepted := (
		after_inventory.size() == before_inventory_count + 1
		and _receipt_count("track.acquire", true) == accepted_before + 1
	)
	if accepted:
		_post_resolution_commodity_acquire_count += 1
		_second_legal_commodity_acquire_count += 1
	else:
		_second_legal_commodity_rejection_count += 1
		_post_resolution_commodity_acquire_rejection_count += 1
	_expect(accepted, "post-resolution legal commodity acquisition commits exactly once")
	_expect(
		_receipt_count("track.acquire", false) == rejected_before,
		"post-resolution legal commodity acquisition emits no rejection"
	)
	_expect(
		_scroll_sequence(after) == before_sequence,
		"post-resolution purchase does not manufacture a track handoff"
	)
	_expect(
		_supply_consumption_probe(core) == before_supply,
		"post-resolution purchase creates a vacancy without supply cursor or RNG consumption"
	)
	_expect(
		not str(target_payload.get("instance_id", "")).is_empty(),
		"post-resolution acquisition records its stable source instance"
	)
	_record_multi_window_state("S4_SECOND_COMMODITY_ACQUIRE_ATTEMPT", {
		"second_commodity_instance_id": (
			_commodity_by_track_source(
				after_inventory,
				str(target_payload.get("instance_id", ""))
			).get("instance_id", "")
		),
		"second_source_instance_id": str(target_payload.get("instance_id", "")),
		"second_claimability_state": target_payload.get("claimability_state", ""),
		"second_acquire_reason_code": "none" if accepted else "track_acquisition_rejected",
		"second_acquire_accepted": accepted,
	})


func _assert_multi_window_trace_contract() -> void:
	var required := [
		"S0_NEW_GAME_PUBLISHED",
		"S1_FIRST_ACTION_WINDOW_STARTED",
		"S2_FIRST_COMMODITY_ACQUIRED",
		"S3_FIRST_TRACK_HANDOFF",
		"S4_SECOND_COMMODITY_ACQUIRE_ATTEMPT",
		"S5_FACILITY_CARD_SELECTED",
		"S6_FACILITY_CARD_COMMIT_ACCEPTED",
		"S7_SUBMISSION_WINDOW_CONTINUES_OR_ENDS",
		"S8_RESOLUTION_STARTED",
		"S9_FACILITY_EFFECT_COMMITTED",
		"S10_PUBLIC_FACILITY_PROJECTION_PUBLISHED",
		"S11_MAP_MARKER_PRESENTED",
		"S12_NEXT_ACTION_WINDOW_STARTED",
		"S13_SECOND_OR_THIRD_TRACK_HANDOFF",
	]
	for state_id in required:
		_expect(
			_multi_window_trace_seen.has(state_id),
			"unified multi-window trace records %s" % state_id
		)
	_expect(_first_commodity_acquire_count >= 1, "trace proves first commodity acquisition")
	_expect(
		_second_legal_commodity_opportunity_count >= 1,
		"trace proves a natural legal second commodity opportunity"
	)
	_expect(
		_second_legal_commodity_acquire_count >= 1
		and _second_legal_commodity_rejection_count == 0,
		"trace proves the legal second commodity acquisition without rejection"
	)
	_expect(_countdown_frozen_after_commit_count == 0, "post-commit authoritative countdown never freezes")
	_expect(_action_window_sample_count >= 3, "trace samples at least three natural action windows")
	var s4 := _trace_row("S4_SECOND_COMMODITY_ACQUIRE_ATTEMPT")
	_expect(
		int(s4.get("commodity_hand_projection_ids", []).size()) == 2,
		"second commodity trace records two commodity cards"
	)
	var s0 := _trace_row("S0_NEW_GAME_PUBLISHED")
	_expect(
		float(s0.get("submission_seconds_total", 0.0)) == 30.0,
		"new-game trace starts a fixed 30-second authoritative window"
	)
	var s7 := _trace_row("S7_SUBMISSION_WINDOW_CONTINUES_OR_ENDS")
	_expect(
		str(s7.get("phase_before_commit", "")) == "submission"
		and str(s7.get("phase_after_commit", "")) == "submission"
		and float(s7.get("remaining_after_commit", 0.0)) < float(s7.get("remaining_before_commit", 0.0)),
		"card commit keeps the same submission window live"
	)
	var s9 := _trace_row("S9_FACILITY_EFFECT_COMMITTED")
	var s10 := _trace_row("S10_PUBLIC_FACILITY_PROJECTION_PUBLISHED")
	var s11 := _trace_row("S11_MAP_MARKER_PRESENTED")
	_expect(
		not str(s9.get("facility_commit_id", "")).is_empty()
		and int(s9.get("public_facility_occupied_slot_count", 0)) > 0,
		"facility effect commit has a stable public commit witness"
	)
	_expect(
		int(s10.get("public_facility_occupied_slot_count", 0)) > 0,
		"facility commit publishes occupied public facility slots"
	)
	_expect(
		int(s11.get("map_marker_count", 0)) > 0
		and int(s11.get("embedded_map_marker_count", 0)) > 0
		and int(s11.get("fullscreen_map_marker_count", 0)) > 0,
		"facility commit reaches both production map marker consumers"
	)
	_expect(
		_trace_map_marker_count("S12_NEXT_ACTION_WINDOW_STARTED") >= _trace_map_marker_count("S11_MAP_MARKER_PRESENTED"),
		"committed facility markers persist into the next action window"
	)
	var handoff_rows: Array[Dictionary] = []
	for row in _multi_window_trace:
		if str(row.get("state_id", "")) in [
			"S3_FIRST_TRACK_HANDOFF",
			"S12_NEXT_ACTION_WINDOW_STARTED",
			"S13_SECOND_OR_THIRD_TRACK_HANDOFF",
		]:
			handoff_rows.append(row)
	for row in handoff_rows:
		_expect(
			int(row.get("advance_sequence", -1)) == int(row.get("scroll_sequence", -2)),
			"authoritative handoff sequence equals projected scroll sequence"
		)
	if handoff_rows.size() >= 2:
		_expect(
			str(handoff_rows[0].get("current_player_id", ""))
				!= str(handoff_rows[1].get("current_player_id", "")),
			"successive track handoffs change the authoritative current player"
		)


func _trace_row(state_id: String) -> Dictionary:
	for row in _multi_window_trace:
		if str(row.get("state_id", "")) == state_id:
			return row
	return {}


func _trace_map_marker_count(state_id: String) -> int:
	return int(_trace_row(state_id).get("map_marker_count", 0))


func _assert_normal_terminal_and_post_victory_rejection() -> void:
	var window := await _ensure_submission_window()
	_expect(
		bool(window.get("ready", false)),
		"fourth batch begins as a normal submission before Victory"
	)
	if not bool(window.get("ready", false)):
		return
	var lock := _screen.find_child("LockButton", true, false) as Button
	_expect(lock != null and not lock.disabled, "terminal qualification uses the production Lock control")
	if lock == null or lock.disabled:
		return
	lock.pressed.emit()
	# The terminal batch is a CI-only bounded wait.  It uses the existing typed
	# pacing intent (never a visible production control) after the three human
	# handoff observations are complete; the production candidate remains 1x.
	var terminal_fast_forward := _flow.submit_intent(_flow.issue_intent(
		"ui.pacing.set",
		{"multiplier": 4}
	)) as Dictionary
	_expect(
		bool(terminal_fast_forward.get("accepted", false)),
		"terminal probe uses the existing TEST_ONLY pacing intent"
	)
	var previous_time_scale := Engine.time_scale
	# Headless CI can spend more wall time laying out the public theater than a
	# human window does.  This test-only scale bounds the terminal observation;
	# it never reaches the production UI and is restored before the probe exits.
	Engine.time_scale = 4.0
	var terminal_snapshot: Dictionary = {}
	var deadline := Time.get_ticks_msec() + 15_000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		terminal_snapshot = _flow.call("local_snapshot") as Dictionary
		var phase := str(terminal_snapshot.get("phase", ""))
		if phase == "settled":
			break
		if phase == "maintenance":
			var finish := _screen.find_child("FinishMaintenanceButton", true, false) as Button
			if finish != null and not finish.disabled:
				finish.pressed.emit()
	var runtime_debug := _runtime.call("debug_snapshot") as Dictionary
	var terminal_phase := str(runtime_debug.get("phase", ""))
	var progress := int(runtime_debug.get("public_progress_points", -1))
	var target := int(runtime_debug.get("public_progress_target", -1))
	_normal_terminal_observed = (
		terminal_phase == "settled"
		and progress >= target
		and int(runtime_debug.get("final_settlement_count", 0)) == 1
		and int(runtime_debug.get("final_settlement_presentation_count", 0)) == 1
		and int(runtime_debug.get("final_settlement_public_log_count", 0)) == 1
		and int(runtime_debug.get("runtime_error_count", 0)) == 0
	)
	print("V076_NATURAL_TERMINAL_CLASSIFICATION|classification=%s|phase=%s|progress=%d|target=%d|final_settlement=%d|presentation=%d|public_log=%d|runtime_errors=%d" % [
		"NORMAL_TERMINAL" if _normal_terminal_observed else "LOOP_BLOCKER",
		terminal_phase,
		progress,
		target,
		int(runtime_debug.get("final_settlement_count", 0)),
		int(runtime_debug.get("final_settlement_presentation_count", 0)),
		int(runtime_debug.get("final_settlement_public_log_count", 0)),
		int(runtime_debug.get("runtime_error_count", 0)),
	])
	_expect(
		_normal_terminal_observed,
		"settled Victory is classified NORMAL_TERMINAL with FinalSettlement exactly once"
	)
	if not _normal_terminal_observed:
		Engine.time_scale = previous_time_scale
		return
	var source_instance_id := ""
	var authority_track := _track_state(_track_authority_state())
	for item_variant in authority_track.get("items", []) as Array:
		if item_variant is Dictionary:
			source_instance_id = str((item_variant as Dictionary).get("instance_id", ""))
			if not source_instance_id.is_empty():
				break
	_expect(not source_instance_id.is_empty(), "terminal rejection probe has a real track source")
	if source_instance_id.is_empty():
		Engine.time_scale = previous_time_scale
		return
	var rejected := _flow.submit_intent(_flow.issue_intent(
		"track.acquire",
		{"source_instance_id": source_instance_id}
	)) as Dictionary
	_post_resolution_rejection_reason = str(rejected.get("reason_code", ""))
	_expect(
		not bool(rejected.get("accepted", false))
		and _post_resolution_rejection_reason == "track_acquisition_outside_submission",
		"post-Victory acquisition is rejected with the exact terminal phase reason"
	)
	_flow.submit_intent(_flow.issue_intent(
		"ui.pacing.set",
		{"multiplier": 1}
	))
	Engine.time_scale = previous_time_scale


func _assert_authoritative_track_transition(
	before_authority: Dictionary,
	after_authority: Dictionary,
	target_vacancy_path_position: int,
	handoff_index: int
) -> int:
	var before_track := _track_state(before_authority)
	var after_track := _track_state(after_authority)
	_expect(
		not before_track.is_empty() and not after_track.is_empty(),
		"handoff %d exposes the existing track authority state" % handoff_index
	)
	if before_track.is_empty() or after_track.is_empty():
		return target_vacancy_path_position
	var capacity := int(after_track.get("capacity", -1))
	var local_slots := int(after_track.get("local_visible_slot_count", -1))
	_expect(
		capacity > 0 and local_slots > 0,
		"handoff %d keeps a positive shared-track capacity" % handoff_index
	)
	var before_items := _track_items_by_id(before_track)
	var after_items := _track_items_by_id(after_track)
	var before_vacancies := _track_vacancy_positions(before_track)
	print("V076_AUTH_TRANS|index=%d|before_seq=%d|after_seq=%d|before_vac=%s|after_vac=%s|before_count=%d|after_count=%d" % [
		handoff_index,
		int(before_track.get("scroll_sequence", -1)),
		int(after_track.get("scroll_sequence", -1)),
		JSON.stringify(before_vacancies),
		JSON.stringify(_track_vacancy_positions(after_track)),
		before_items.size(),
		after_items.size(),
	])
	var expected_vacancies: Array[int] = []
	for position in before_vacancies:
		if position + 1 < capacity:
			expected_vacancies.append(position + 1)
	expected_vacancies.sort()
	var actual_vacancies := _track_vacancy_positions(after_track)
	_expect(
		actual_vacancies == expected_vacancies,
		"handoff %d advances every global vacancy by one physical path slot"
			% handoff_index
	)
	_expect(
		int(after_track.get("scroll_sequence", -1))
			== int(before_track.get("scroll_sequence", -2)) + 1,
		"handoff %d advances the authoritative track sequence exactly once"
			% handoff_index
	)
	_expect(
		int(after_track.get("next_instance_sequence", -1))
			== int(before_track.get("next_instance_sequence", -2)) + 1,
		"handoff %d draws exactly one natural tail replacement"
			% handoff_index
	)

	var new_instance_ids: Array[String] = []
	for instance_id_variant in after_items.keys():
		var instance_id := str(instance_id_variant)
		if not before_items.has(instance_id):
			new_instance_ids.append(instance_id)
	_expect(
		new_instance_ids.size() == 1,
		"handoff %d inserts exactly one new authority-owned track instance"
			% handoff_index
	)
	if new_instance_ids.size() == 1:
		_expect(
			int((after_items.get(new_instance_ids[0], {}) as Dictionary).get(
				"path_position",
				-1
			)) == 0,
			"handoff %d natural replacement enters physical path position zero"
				% handoff_index
		)
	for instance_id_variant in before_items.keys():
		var instance_id := str(instance_id_variant)
		var before_item := before_items.get(instance_id, {}) as Dictionary
		var expected_position := int(before_item.get("path_position", -1)) + 1
		if expected_position >= capacity:
			_expect(
				not after_items.has(instance_id),
				"handoff %d removes the physical tail instance exactly once"
					% handoff_index
			)
			continue
		_expect(
			after_items.has(instance_id)
			and int((after_items.get(instance_id, {}) as Dictionary).get(
				"path_position",
				-1
			)) == expected_position,
			"handoff %d preserves each surviving card's path lineage"
				% handoff_index
		)

	var lead := after_authority.get("hidden_lead_cycle_state", {}) as Dictionary
	var fixed_order := lead.get("fixed_order", []) as Array
	var current_origin_index := fixed_order.find(str(
		lead.get("current_lead_id", "")
	))
	_expect(
		not fixed_order.is_empty() and current_origin_index >= 0,
		"handoff %d retains the existing fixed-order lead authority"
			% handoff_index
	)
	if not fixed_order.is_empty() and current_origin_index >= 0:
		for item_variant in after_track.get("items", []) as Array:
			if not (item_variant is Dictionary):
				continue
			var item := item_variant as Dictionary
			var path_position := int(item.get("path_position", -1))
			var segment_offset := int(path_position / local_slots)
			var owner_index := (
				current_origin_index + segment_offset
			) % fixed_order.size()
			var expected_owner := str(fixed_order[owner_index])
			_expect(
				int(item.get("path_origin_index", -1)) == current_origin_index
				and str(item.get("segment_owner_id", "")) == expected_owner,
				"handoff %d refreshes owner/origin from each item's new path position"
					% handoff_index
			)

	var projected_items := _track_projection_items_by_id()
	for instance_id_variant in after_items.keys():
		var instance_id := str(instance_id_variant)
		var item := after_items.get(instance_id, {}) as Dictionary
		var projection := projected_items.get(instance_id, {}) as Dictionary
		if projection.is_empty():
			continue
		_expect(
			int(projection.get("local_slot_index", -1))
				== int(item.get("path_position", -1)) % local_slots,
			"handoff %d maps projected local slots from authoritative path position"
				% handoff_index
		)

	if target_vacancy_path_position < 0:
		return -1
	var next_target := target_vacancy_path_position + 1
	if next_target < capacity:
		_expect(
			actual_vacancies.has(next_target),
			"handoff %d moves the purchased vacancy to global path position %d"
				% [handoff_index, next_target]
		)
		return next_target
	_expect(
		not actual_vacancies.has(target_vacancy_path_position),
		"handoff %d carries the purchased vacancy through the natural tail"
			% handoff_index
	)
	_natural_tail_refill_edge_count += 1
	_expect(
		after_items.size() == before_items.size() + 1,
		"handoff %d naturally refills one card when the purchased vacancy exits the tail"
			% handoff_index
	)
	if before_vacancies.size() == 1:
		_expect(
			after_items.size() == capacity,
			"handoff %d restores full capacity when no other vacancy remains"
			% handoff_index
		)
	return -1


func _ensure_submission_window() -> Dictionary:
	# A real V075 start may leave the local player in the explicit maintenance
	# decision state after the first starter batch.  Advance through the same
	# production UI control a human uses before asking the next handoff probe to
	# lock a submission; do not call the RuntimeOwner directly or inject a phase.
	for _attempt in range(8):
		var snapshot := _flow.call("local_snapshot") as Dictionary
		var phase := str(snapshot.get("phase", ""))
		if phase == "submission":
			return {"ready": true, "terminal": false, "phase": phase}
		if phase in ["settled", "failed"]:
			return {"ready": false, "terminal": true, "phase": phase}
		if phase != "maintenance":
			await process_frame
			continue
		var finish := _screen.find_child(
			"FinishMaintenanceButton",
			true,
			false
		) as Button
		if finish == null or finish.disabled:
			await process_frame
			continue
		finish.pressed.emit()
		for _frame in range(12):
			await process_frame
			if str((_flow.call("local_snapshot") as Dictionary).get(
				"phase",
				""
			)) == "submission":
				return {"ready": true, "terminal": false, "phase": "submission"}
	return {
		"ready": false,
		"terminal": false,
		"phase": str((_flow.call("local_snapshot") as Dictionary).get("phase", "")),
	}


func _supply_consumption_probe(_core: Variant) -> Dictionary:
	var debug := _runtime.call("debug_snapshot") as Dictionary
	var policy := debug.get("track_acquisition_policy", {}) as Dictionary
	return {
		"supply_cursor_delta": int(policy.get("supply_cursor_delta_on_acquisition", -1)),
		"supply_instance_sequence_delta": int(policy.get(
			"supply_instance_sequence_delta_on_acquisition",
			-1
		)),
		"supply_rng_draw_delta": int(policy.get(
			"supply_rng_draw_delta_on_acquisition",
			-1
		)),
		"immediate_refill_count": int(policy.get(
			"immediate_authoritative_refill_count",
			-1
		)),
	}


func _configure_new_game() -> void:
	var player_option := _screen.find_child(
		"PlayerCountOption",
		true,
		false
	) as OptionButton
	var seed_input := _screen.find_child("SeedInput", true, false) as LineEdit
	for index in range(player_option.item_count):
		if int(player_option.get_item_metadata(index)) == 4:
			player_option.select(index)
			break
	var configured_seed := FIXED_SEED
	var seed_override := OS.get_environment("V076_SEED")
	if not seed_override.is_empty() and seed_override.is_valid_int():
		configured_seed = seed_override.to_int()
	seed_input.text = str(configured_seed)


func _record_multi_window_state(state_id: String, extra: Dictionary = {}) -> void:
	if _multi_window_trace_seen.has(state_id):
		return
	if _flow == null or _runtime == null:
		return
	var snapshot := _flow.call("local_snapshot") as Dictionary
	var runtime_debug := _runtime.call("debug_snapshot") as Dictionary
	var authority := _track_authority_state()
	var track := _track_state(authority)
	var facts := _dbg_facts(snapshot)
	var arrangement := snapshot.get("v076_public_action_arrangement", {}) as Dictionary
	var local_player_id := str(snapshot.get("local_player_id", ""))
	var local_track_projection := _local_track_projection(local_player_id)
	var local_track_facts := local_track_projection.get(
		"viewer_private_facts",
		{}
	) as Dictionary
	var lead := authority.get("hidden_lead_cycle_state", {}) as Dictionary
	var fixed_order := lead.get("fixed_order", []) as Array
	var current_player_id := str(lead.get("current_lead_id", ""))
	var current_player_index := fixed_order.find(current_player_id)
	var next_player_id := ""
	if current_player_index >= 0 and not fixed_order.is_empty():
		next_player_id = str(fixed_order[
			(current_player_index + 1) % fixed_order.size()
		])
	var track_slot_mapping := {}
	var segment_owner_mapping := {}
	for item_variant in track.get("items", []) as Array:
		if not (item_variant is Dictionary):
			continue
		var item := item_variant as Dictionary
		var instance_id := str(item.get("instance_id", ""))
		if instance_id.is_empty():
			continue
		track_slot_mapping[instance_id] = int(item.get("path_position", -1))
		segment_owner_mapping[instance_id] = str(item.get("segment_owner_id", ""))
	var claimability := {}
	for item_variant in local_track_facts.get("own_segment_items", []) as Array:
		if not (item_variant is Dictionary):
			continue
		var item := item_variant as Dictionary
		var instance_id := str(item.get("instance_id", ""))
		if instance_id.is_empty():
			continue
		claimability[instance_id] = {
			"claimable": bool(item.get("claimable", false)),
			"claimability_state": str(item.get("claimability_state", "")),
			"local_slot_index": int(item.get("local_slot_index", -1)),
			"segment_owner_id": str(item.get("segment_owner_id", "")),
		}
	var map_payload := _flow.call("planet_map_view_payload") as Dictionary
	var map_snapshot := map_payload.get("snapshot") as MapPresentationSnapshot
	var map_markers := _trace_marker_summaries(
		map_snapshot.city_markers if map_snapshot != null else []
	)
	var embedded_marker_count := _actual_map_marker_count("PlanetMapView")
	var fullscreen_marker_count := _actual_map_marker_count("FullscreenMapView")
	var facility_projection := snapshot.get("facility_contention", {}) as Dictionary
	var public_slots := facility_projection.get("public_facility_slots", []) as Array
	if public_slots.is_empty():
		var map_player_projection := snapshot.get("map_player_projection", {}) as Dictionary
		public_slots = map_player_projection.get("public_facility_slots", []) as Array
	var latest_facility_receipt := _latest_facility_receipt()
	var facility_slot_summaries := _trace_facility_slot_summaries(public_slots)
	var occupied_slot_count := 0
	for slot_variant in public_slots:
		if slot_variant is Dictionary and str((slot_variant as Dictionary).get("occupancy", "")) == "occupied":
			occupied_slot_count += 1
	var facility_marker_ids: Array[String] = []
	for marker_variant in map_markers:
		if marker_variant is Dictionary:
			var marker_id := str((marker_variant as Dictionary).get("marker_id", ""))
			if not marker_id.is_empty():
				facility_marker_ids.append(marker_id)
	var locked_by_player := {}
	var locked_variant: Variant = _runtime.get("_locked_by_player")
	if locked_variant is Dictionary:
		for key_variant in (locked_variant as Dictionary).keys():
			locked_by_player[str(key_variant)] = bool(
				(locked_variant as Dictionary).get(key_variant, false)
			)
	var authority_general_ids := _authority_hand_ids(local_player_id, "hand")
	var authority_commodity_ids := _authority_hand_ids(
		local_player_id,
		"commodity_inventory"
	)
	var queued_ids := _ids_from_rows(snapshot.get("queued_actions", []))
	var visible_hands := _visible_hand_control_ids()
	var advance_timing := _track_advance_timing_snapshot()
	var row: Dictionary = {
		"schema": "V076MultiWindowStateTraceV1",
		"trace_index": _multi_window_trace.size(),
		"state_id": state_id,
		"captured_wall_msec": Time.get_ticks_msec(),
		"elapsed_wall_msec": Time.get_ticks_msec() - _trace_started_wall_msec,
		"match_id": str(snapshot.get("match_id", runtime_debug.get("match_id", ""))),
		"batch_id": str(runtime_debug.get("batch_id", arrangement.get("batch_id", snapshot.get("batch_id", "")))),
		"phase": str(snapshot.get("phase", "")),
		"clock_msec": int(runtime_debug.get("authoritative_clock_msec", -1)),
		"submission_window_id": str(runtime_debug.get("submission_window_id", snapshot.get("submission_window_id", arrangement.get("batch_id", "")))),
		"submission_started_clock_msec": int(runtime_debug.get("submission_started_clock_msec", runtime_debug.get("submission_opened_at_msec", -1))),
		"submission_deadline_clock_msec": int(runtime_debug.get("submission_deadline_clock_msec", runtime_debug.get("submission_deadline_msec", -1))),
		"submission_seconds_total": float(runtime_debug.get("submission_seconds_total", snapshot.get("submission_seconds_total", 0.0))),
		"submission_seconds_remaining": float(runtime_debug.get("submission_seconds_remaining", snapshot.get("submission_seconds_remaining", 0.0))),
		"current_player_id": current_player_id,
		"next_player_id": next_player_id,
		"locked_by_player": locked_by_player,
		"local_player_locked": bool(snapshot.get("submission_locked", false)),
		"track_phase": str(snapshot.get("phase", "")),
		"scroll_sequence": int(track.get("scroll_sequence", -1)),
		"advance_sequence": int(advance_timing.get("sequence", track.get("scroll_sequence", -1))),
		"local_visible_segment_owner": str(local_track_facts.get("segment_owner_id", current_player_id)),
		"track_slot_mapping": track_slot_mapping,
		"vacancy_slot_mapping": _track_vacancy_positions(track),
		"segment_owner_mapping": segment_owner_mapping,
		"claimability": claimability,
		"first_commodity_instance_id": str(extra.get("first_commodity_instance_id", "")),
		"second_commodity_instance_id": str(extra.get("second_commodity_instance_id", "")),
		"first_claimability_state": str(extra.get("first_claimability_state", "")),
		"second_claimability_state": str(extra.get("second_claimability_state", "")),
		"second_acquire_reason_code": str(extra.get("second_acquire_reason_code", "none")),
		"general_hand_authority_ids": authority_general_ids,
		"general_hand_projection_ids": _ids_from_rows(facts.get("hand", [])),
		"general_hand_visible_control_ids": visible_hands.get("general", []),
		"commodity_hand_authority_ids": authority_commodity_ids,
		"commodity_hand_projection_ids": _ids_from_rows(facts.get("commodity_inventory", [])),
		"commodity_hand_visible_control_ids": visible_hands.get("commodity", []),
		"active_hand_category": str(_screen.get("_active_hand_category")),
		"selected_card_instance_id": str(_screen.get("_selected_card_id")),
		"pending_action_id": str(extra.get("pending_action_id", "")),
		"queued_action_ids": queued_ids,
		"facility_commit_id": str(extra.get("facility_commit_id", _facility_trace.get("facility_commit_id", latest_facility_receipt.get("receipt_id", "")))),
		"facility_slot_id": str(extra.get("facility_slot_id", _facility_trace.get("facility_slot_id", ""))),
		"facility_type": str(extra.get("facility_type", _facility_trace.get("facility_type", latest_facility_receipt.get("facility_type", "")))),
		"facility_region_id": str(extra.get("facility_region_id", _facility_trace.get("facility_region_id", latest_facility_receipt.get("target_region_id", "")))),
		"facility_resolution_receipt_id": str(latest_facility_receipt.get("receipt_id", "")),
		"public_facility_slots": facility_slot_summaries,
		"public_facility_slot_total": public_slots.size(),
		"public_facility_occupied_slot_count": occupied_slot_count,
		"facility_state_revision": int(facility_projection.get("state_revision", facility_projection.get("revision", 0))),
		"map_projection_revision": str(map_payload.get("projection_fingerprint", map_payload.get("source_revision", ""))),
		"map_city_markers": map_markers,
		"visible_facility_marker_ids": facility_marker_ids,
		"map_marker_count": map_markers.size(),
		"embedded_map_marker_count": embedded_marker_count,
		"fullscreen_map_marker_count": fullscreen_marker_count,
	}
	row.merge(extra, true)
	_multi_window_trace_seen[state_id] = true
	_multi_window_trace.append(row)
	print("V076_MULTI_WINDOW_STATE|%s" % JSON.stringify(row))


func _local_track_projection(actor_id: String) -> Dictionary:
	var core := _track_core_object()
	if core == null or actor_id.is_empty():
		return {}
	return (core.call("player_projection_v1", actor_id) as Dictionary).duplicate(true)


func _authority_hand_ids(actor_id: String, zone: String) -> Array[String]:
	var result: Array[String] = []
	var dbg_by_player_variant: Variant = _runtime.get("_dbg_by_player")
	if not (dbg_by_player_variant is Dictionary):
		return result
	var owner: Variant = (dbg_by_player_variant as Dictionary).get(actor_id)
	if owner == null or not owner.has_method("core_authority_snapshot"):
		return result
	var envelope := owner.call("core_authority_snapshot") as Dictionary
	var state := envelope.get("state", {}) as Dictionary
	return _ids_from_rows(state.get(zone, []))


func _visible_hand_control_ids() -> Dictionary:
	var result := {"general": [], "commodity": []}
	var rail := _screen.find_child("HandRail", true, false) as HBoxContainer
	var preview := _screen.find_child("CommodityHandPreviewRail", true, false) as HBoxContainer
	if rail != null:
		for child_variant in rail.get_children():
			var child := child_variant as Control
			if child == null or not child.visible or not child.has_method("payload"):
				continue
			var id := str((child.call("payload") as Dictionary).get("instance_id", ""))
			if id.is_empty():
				continue
			if str((child.call("payload") as Dictionary).get("authority_zone", "")) == "commodity_inventory":
				(result["commodity"] as Array).append(id)
			else:
				(result["general"] as Array).append(id)
	if preview != null:
		for child_variant in preview.get_children():
			var child := child_variant as Control
			if child == null or not child.visible or not child.has_method("payload"):
				continue
			var id := str((child.call("payload") as Dictionary).get("instance_id", ""))
			if not id.is_empty() and not (result["commodity"] as Array).has(id):
				(result["commodity"] as Array).append(id)
	return result


func _ids_from_rows(rows: Variant) -> Array[String]:
	var result: Array[String] = []
	if not (rows is Array):
		return result
	for row_variant in rows as Array:
		if row_variant is Dictionary:
			var id := str((row_variant as Dictionary).get("instance_id", (row_variant as Dictionary).get("card_instance_id", "")))
			if not id.is_empty():
				result.append(id)
	return result


func _trace_marker_summaries(rows: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (rows is Array):
		return result
	for row_variant in rows as Array:
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		result.append({
			"marker_id": str(row.get("marker_id", row.get("facility_id", row.get("slot_id", "")))),
			"facility_id": str(row.get("facility_id", "")),
			"slot_id": str(row.get("slot_id", "")),
			"region_id": str(row.get("region_id", "")),
			"facility_type": str(row.get("facility_type", "city")),
			"industry_id": str(row.get("industry_id", "")),
			"level": int(row.get("level", 1)),
			"damage_points": int(row.get("damage_points", 0)),
		})
	return result


func _trace_facility_slot_summaries(rows: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not (rows is Array):
		return result
	for row_variant in rows as Array:
		if not (row_variant is Dictionary):
			continue
		var row := row_variant as Dictionary
		var facility := row.get("facility", {}) as Dictionary
		var occupancy := str(row.get("occupancy", ""))
		var facility_id := str(row.get("facility_id", facility.get("facility_id", "")))
		if occupancy != "occupied" and (facility_id.is_empty() or facility_id == "<null>"):
			continue
		result.append({
			"slot_id": str(row.get("slot_id", "")),
			"region_id": str(row.get("region_id", "")),
			"facility_type": str(row.get("facility_type", facility.get("facility_type", ""))),
			"industry_id": str(row.get("industry_id", facility.get("industry_id", ""))),
			"facility_id": facility_id if facility_id != "<null>" else "",
			"occupancy": occupancy,
		})
	return result


func _actual_map_marker_count(node_name: String) -> int:
	var node := _screen.find_child(node_name, true, false) as Control
	if node == null:
		return 0
	var markers: Variant = node.get("city_markers")
	return (markers as Array).size() if markers is Array else 0


func _latest_facility_receipt() -> Dictionary:
	var selected_receipt_id := str(_facility_trace.get("resolution_receipt_id", ""))
	if not selected_receipt_id.is_empty():
		return {
			"receipt_id": selected_receipt_id,
			"facility_type": _facility_trace.get("facility_type", ""),
			"industry_id": _facility_trace.get("industry_id", ""),
			"target_region_id": _facility_trace.get("facility_region_id", ""),
			"target_slot_id": _facility_trace.get("facility_slot_id", ""),
		}
	if not _public_resolution_receipts.is_empty():
		return _public_resolution_receipts.back().duplicate(true)
	for index in range(_receipts.size() - 1, -1, -1):
		var receipt := _receipts[index]
		if receipt.has("facility_type") or receipt.has("target_region_id"):
			return receipt.duplicate(true)
	return {}


func _on_public_resolution_ready(receipt: Dictionary) -> void:
	var copy := receipt.duplicate(true)
	_public_resolution_receipts.append(copy)
	if not copy.has("facility_type") and not copy.has("target_region_id"):
		return
	if not _facility_trace.has("selected_card_instance_id"):
		return
	if not str(_facility_trace.get("resolution_receipt_id", "")).is_empty():
		return
	if (
		str(copy.get("facility_type", "")) != str(_facility_trace.get("facility_type", ""))
		or str(copy.get("target_region_id", "")) != str(_facility_trace.get("facility_region_id", ""))
		or str(copy.get("industry_id", "")) != str(_facility_trace.get("industry_id", ""))
		or str(copy.get("target_slot_id", "")) != str(_facility_trace.get("facility_slot_id", ""))
	):
		return
	var commit_id := str(copy.get(
		"receipt_id",
		copy.get("combat_receipt_id", copy.get(
			"anonymous_action_id",
			copy.get("action_id", copy.get("resolution_id", ""))
		))
	))
	_facility_trace["facility_commit_id"] = commit_id
	_facility_trace["facility_slot_id"] = str(copy.get("target_slot_id", ""))
	_facility_trace["facility_type"] = str(copy.get(
		"facility_type",
		_facility_trace.get("facility_type", "")
	))
	_facility_trace["facility_region_id"] = str(copy.get(
		"target_region_id",
		_facility_trace.get("facility_region_id", "")
	))
	_facility_trace["resolution_receipt_id"] = commit_id
	_record_multi_window_state("S9_FACILITY_EFFECT_COMMITTED", {
		"facility_commit_id": commit_id,
		"facility_slot_id": _facility_trace["facility_slot_id"],
		"facility_type": _facility_trace["facility_type"],
		"facility_region_id": _facility_trace["facility_region_id"],
		"resolution_receipt_id": _facility_trace["resolution_receipt_id"],
	})


func _dbg_facts(snapshot: Dictionary) -> Dictionary:
	return (
		(snapshot.get("personal_dbg", {}) as Dictionary).get("facts", {})
		as Dictionary
	)


func _scroll_sequence(snapshot: Dictionary) -> int:
	return int((
		(snapshot.get("unified_track", {}) as Dictionary).get(
			"public_facts",
			{}
		) as Dictionary
	).get("scroll_sequence", -1))


func _track_core_object() -> RefCounted:
	if _runtime == null:
		return null
	var core_variant: Variant = _runtime.get("_track_core")
	if not (core_variant is RefCounted):
		return null
	return core_variant as RefCounted


func _track_authority_state() -> Dictionary:
	var core := _track_core_object()
	if core == null or not core.has_method("core_authority_v1"):
		return {}
	var envelope := core.call("core_authority_v1") as Dictionary
	return (envelope.get("authority_state", {}) as Dictionary).duplicate(true)


func _track_advance_timing_snapshot() -> Dictionary:
	if _runtime == null or not _runtime.has_method(
		"v076_track_advance_timing_snapshot"
	):
		return {}
	return (_runtime.call("v076_track_advance_timing_snapshot") as Dictionary).duplicate(true)


func _track_state(authority_state: Dictionary) -> Dictionary:
	return (authority_state.get("track_state", {}) as Dictionary).duplicate(true)


func _track_items_by_id(track_state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for item_variant in track_state.get("items", []) as Array:
		if not (item_variant is Dictionary):
			continue
		var item := item_variant as Dictionary
		var instance_id := str(item.get("instance_id", ""))
		if not instance_id.is_empty():
			result[instance_id] = item.duplicate(true)
	return result


func _track_item_by_id(track_state: Dictionary, instance_id: String) -> Dictionary:
	var items := _track_items_by_id(track_state)
	return (items.get(instance_id, {}) as Dictionary).duplicate(true)


func _track_vacancy_positions(track_state: Dictionary) -> Array[int]:
	var occupied: Dictionary = {}
	for item_variant in track_state.get("items", []) as Array:
		if not (item_variant is Dictionary):
			continue
		occupied[int((item_variant as Dictionary).get(
			"path_position",
			-1
		))] = true
	var result: Array[int] = []
	for path_position in range(int(track_state.get("capacity", 0))):
		if not occupied.has(path_position):
			result.append(path_position)
	return result


func _track_projection_items_by_id() -> Dictionary:
	var result: Dictionary = {}
	var core := _track_core_object()
	var authority := _track_authority_state()
	if core == null:
		return result
	for actor_variant in authority.get("roster_ids", []) as Array:
		var actor_id := str(actor_variant)
		var projection := core.call(
			"player_projection_v1",
			actor_id
		) as Dictionary
		var private_facts := projection.get(
			"viewer_private_facts",
			{}
		) as Dictionary
		for item_variant in private_facts.get("own_segment_items", []) as Array:
			if not (item_variant is Dictionary):
				continue
			var item := item_variant as Dictionary
			var instance_id := str(item.get("instance_id", ""))
			if not instance_id.is_empty():
				result[instance_id] = item.duplicate(true)
	return result


func _card_by_id(cards: Array, instance_id: String) -> Dictionary:
	for card_variant in cards:
		if not (card_variant is Dictionary):
			continue
		var card := card_variant as Dictionary
		if str(card.get("instance_id", "")) == instance_id:
			return card.duplicate(true)
	return {}


func _commodity_by_track_source(
	commodities: Array,
	source_track_instance_id: String
) -> Dictionary:
	for commodity_variant in commodities:
		if not (commodity_variant is Dictionary):
			continue
		var commodity := commodity_variant as Dictionary
		if str(commodity.get(
			"source_track_instance_id",
			""
		)) == source_track_instance_id:
			return commodity.duplicate(true)
	return {}


func _card_zone_duplicate_count(facts: Dictionary) -> int:
	var counts := {}
	for zone_name in [
		"hand",
		"committed_escrow",
		"discard",
		"commodity_inventory",
	]:
		for card_variant in facts.get(zone_name, []) as Array:
			if not (card_variant is Dictionary):
				continue
			var instance_id := str((card_variant as Dictionary).get(
				"instance_id",
				""
			))
			if instance_id.is_empty():
				continue
			counts[instance_id] = int(counts.get(instance_id, 0)) + 1
	var duplicate_count := 0
	for count_variant in counts.values():
		if int(count_variant) > 1:
			duplicate_count += 1
	return duplicate_count


func _hand_rail_cards(hand_rail: HBoxContainer) -> Array[Control]:
	var cards: Array[Control] = []
	if hand_rail == null:
		return cards
	for child_variant in hand_rail.get_children():
		var child := child_variant as Control
		if child != null and child.visible and child.has_method("debug_snapshot"):
			cards.append(child)
	return cards


func _assert_rendered_hand_stability(facts: Dictionary) -> void:
	var hand_rail := _screen.find_child("HandRail", true, false) as HBoxContainer
	var cards := _hand_rail_cards(hand_rail)
	var authority_hand := facts.get("hand", []) as Array
	_expect(
		cards.size() == authority_hand.size(),
		"post-queue visible general hand count matches the authoritative hand"
	)
	var seen: Dictionary = {}
	var previous_rect := Rect2()
	var separation := float(hand_rail.get_theme_constant("separation")) if hand_rail != null else 0.0
	var forbidden := [
		"<null>", "Object(", "RefCounted", "RID(", "Dictionary",
		"@GDScript", "[Object:null]", "�",
	]
	for card in cards:
		var payload := card.call("payload") as Dictionary
		var instance_id := str(payload.get("instance_id", ""))
		_expect(not instance_id.is_empty() and not seen.has(instance_id),
			"post-queue rendered hand instance ids are nonempty and unique")
		seen[instance_id] = true
		var face := card.find_child("CardFace", true, false) as Control
		var name_label := face.find_child("NameLabel", true, false) as Label if face != null else null
		var cost_label := face.find_child("CostLabel", true, false) as Label if face != null else null
		var effect_label := face.find_child("EffectLabel", true, false) as Label if face != null else null
		_expect(
			name_label != null and not name_label.text.strip_edges().is_empty()
			and name_label.get_global_rect().size.x >= 18.0,
			"post-queue hand name remains readable with usable width"
		)
		_expect(
			cost_label != null and effect_label != null
			and not cost_label.text.strip_edges().is_empty()
			and not effect_label.text.strip_edges().is_empty(),
			"post-queue hand retains cost and purpose text"
		)
		var visible_text := "%s|%s|%s" % [
			name_label.text if name_label != null else "",
			cost_label.text if cost_label != null else "",
			effect_label.text if effect_label != null else "",
		]
		var clean := true
		for token in forbidden:
			if visible_text.contains(token):
				clean = false
				break
		_expect(clean, "post-queue hand does not expose raw Variant or invalid text")
		var rect := card.get_global_rect()
		if previous_rect.has_area():
			_expect(
				previous_rect.end.x - rect.position.x
				<= maxf(0.0, -separation) + 1.0,
				"post-queue hand overlap stays within authored fan spacing"
			)
		previous_rect = rect


func _assert_hand_card_node_reuse_on_reapply() -> void:
	var hand_rail := _screen.find_child("HandRail", true, false) as HBoxContainer
	var before_cards: Dictionary = {}
	for card in _hand_rail_cards(hand_rail):
		var payload := card.call("payload") as Dictionary
		var instance_id := str(payload.get("instance_id", ""))
		if not instance_id.is_empty():
			before_cards[instance_id] = card
	_screen.call("apply_snapshot", (_flow.call("local_snapshot") as Dictionary).duplicate(true))
	await process_frame
	var after_cards := _hand_rail_cards(hand_rail)
	_expect(
		after_cards.size() == before_cards.size(),
		"redundant snapshot refresh keeps the visible general hand count stable"
	)
	for card in after_cards:
		var payload := card.call("payload") as Dictionary
		var instance_id := str(payload.get("instance_id", ""))
		_expect(
			not instance_id.is_empty() and before_cards.has(instance_id),
			"redundant snapshot refresh keeps every hand instance visible"
		)
		_expect(
			before_cards.get(instance_id) == card,
			"redundant snapshot refresh reuses the same hand Control for %s"
				% instance_id
		)


func _click_card(card: Control) -> void:
	if card == null or not is_instance_valid(card):
		return
	var center := card.get_global_rect().get_center()
	var card_path := str(card.get_path())
	var card_rect := card.get_global_rect()
	var card_payload: Dictionary = card.call("payload") as Dictionary if card.has_method("payload") else {}
	var activation_before := _screen_activation_count("track_card_activation_count")
	var motion := InputEventMouseMotion.new()
	motion.position = center
	motion.global_position = center
	root.get_viewport().push_input(motion, true)
	await process_frame
	var hovered_before := root.gui_get_hovered_control()
	var hovered_before_path := str(hovered_before.get_path()) if hovered_before != null else "<none>"
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = center
	down.global_position = center
	root.get_viewport().push_input(down, true)
	var dispatch_route := "viewport.push_input"
	var hovered_pressed := root.gui_get_hovered_control()
	var hovered_pressed_path := str(hovered_pressed.get_path()) if hovered_pressed != null and is_instance_valid(hovered_pressed) else "<freed>"
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = center
	up.global_position = center
	root.get_viewport().push_input(up, true)
	for _frame in range(3):
		await process_frame
	var activated_after_release := _screen_activation_count("track_card_activation_count") - activation_before
	var hovered_after := root.gui_get_hovered_control()
	var hovered_after_path := str(hovered_after.get_path()) if hovered_after != null and is_instance_valid(hovered_after) else "<freed>"
	_real_pointer_card_trace.append({
		"card_path": card_path,
		"instance_id": str((card_payload as Dictionary).get("instance_id", "")),
		"global_rect": card_rect,
		"hovered_before": hovered_before_path,
		"hovered_pressed": hovered_pressed_path,
		"hovered_after": hovered_after_path,
		"activated_count": activated_after_release,
		"dispatch_route": dispatch_route,
	})
	_expect(activated_after_release == 1, "real viewport pointer activates each commodity card exactly once")
	_expect(
		hovered_before_path == card_path
		or hovered_before_path.contains(card_path + "/")
		or hovered_pressed_path == card_path
		or hovered_pressed_path.contains(card_path + "/")
		or hovered_pressed_path.contains("TrackRail"),
		"real viewport pointer hit-tests the production TrackRail card"
	)


func _screen_activation_count(key: String) -> int:
	if _screen == null or not is_instance_valid(_screen):
		return 0
	var debug := _screen.call("debug_snapshot") as Dictionary
	var human := debug.get("human_playability", {}) as Dictionary
	return int(human.get(key, 0))


func _push_mouse_button(
	button_index: int,
	position: Vector2,
	pressed: bool
) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	event.position = position
	event.global_position = position
	event.pressed = pressed
	Input.parse_input_event(event)


func _push_mouse_motion(position: Vector2, relative: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if relative.length() > 0.0 else 0
	Input.parse_input_event(event)


func _receipt_count(intent_kind: String, accepted: bool) -> int:
	var count := 0
	for receipt in _receipts:
		if (
			str(receipt.get("intent_kind", "")) == intent_kind
			and bool(receipt.get("accepted", false)) == accepted
		):
			count += 1
	return count


func _legal_option_count_for_card(card_id: String) -> int:
	var count := 0
	for option_variant in (
		_flow.call("local_snapshot") as Dictionary
	).get("legal_actions", []) as Array:
		if (
			option_variant is Dictionary
			and str((option_variant as Dictionary).get(
				"card_instance_id",
				""
			)) == card_id
		):
			count += 1
	return count


func _first_legal_option_for_card(card_id: String) -> Dictionary:
	for option_variant in (
		_flow.call("local_snapshot") as Dictionary
	).get("legal_actions", []) as Array:
		if (
			option_variant is Dictionary
			and str((option_variant as Dictionary).get(
				"card_instance_id",
				""
			)) == card_id
		):
			return (option_variant as Dictionary).duplicate(true)
	return {}


func _first_queue_remove_button() -> Button:
	var queue_rail := _screen.get_node(
		"RootMargin/Shell/DockPanel/DockMargin/DockRows/DockBody/"
		+ "QueuePanel/QueueRows/QueueScroll/QueueRail"
	) as Control
	if queue_rail == null:
		return null
	for row_variant in queue_rail.get_children():
		var row := row_variant as Control
		if row == null:
			continue
		for candidate_variant in row.get_children():
			var candidate := candidate_variant as Button
			if (
				candidate != null
				and (
					candidate.tooltip_text == "移除"
					or candidate.text == "×"
				)
			):
				return candidate
	for candidate_variant in queue_rail.find_children("*", "Button", true, false):
		var candidate := candidate_variant as Button
		if candidate != null and (
			candidate.tooltip_text == "移除" or candidate.text == "×"
		):
			return candidate
	return null


func _dismiss_coach() -> void:
	var coach := _screen.get_node("V073PlaytestCoachMarks") as Node
	var skip := coach.find_child("CoachSkipAll", true, false) as Button
	_expect(skip != null, "production coach exposes Skip")
	if skip == null:
		return
	# New-game publication and Coach restart are separate presentation frames;
	# wait for the real coach lifecycle edge before emitting Skip.  Clicking the
	# hidden pre-restart button would leave the shared pace at PAUSE and make the
	# rest of this production probe measure a test race instead of gameplay.
	for _frame in range(30):
		var state := coach.call("debug_snapshot") as Dictionary
		if bool(state.get("active", false)):
			break
		await process_frame
	if bool((coach.call("debug_snapshot") as Dictionary).get("active", false)):
		skip.pressed.emit()
	for _frame in range(30):
		await process_frame
		if not bool((coach.call("debug_snapshot") as Dictionary).get(
			"active",
			false
		)):
			break


func _on_director_cue_queued(cue: Dictionary) -> void:
	var cue_id := str(cue.get("cue_id", ""))
	if cue_id not in ["CARD_SELECT", "CARD_PLAY_PUBLIC", "CARD_RESOLUTION_FOCUS"]:
		return
	var copy := cue.duplicate(true)
	_director_cues_queued.append(copy)
	var receipt_id := str(copy.get("receipt_id", ""))
	if not receipt_id.is_empty():
		_guard_at_queue[receipt_id] = _stable_guard_subset()


func _on_director_cue_finished(cue: Dictionary) -> void:
	var cue_id := str(cue.get("cue_id", ""))
	if cue_id not in ["CARD_SELECT", "CARD_PLAY_PUBLIC", "CARD_RESOLUTION_FOCUS"]:
		return
	var copy := cue.duplicate(true)
	_director_cues_finished.append(copy)
	var receipt_id := str(copy.get("receipt_id", ""))
	if not receipt_id.is_empty():
		_guard_at_finish[receipt_id] = _stable_guard_subset()


func _on_card_transition_started(
	transition_id: String,
	evidence: Dictionary
) -> void:
	_card_transition_start_evidence[transition_id] = evidence.duplicate(true)
	var envelope := _card_table_debug().get("last_envelope", {}) as Dictionary
	if (
		str(envelope.get("cue_id", "")) == "CARD_PLAY_PUBLIC"
		and str(envelope.get("source_public_projection_id", "")) == transition_id
	):
		_card_transition_bridge_envelopes[transition_id] = envelope.duplicate(true)


func _on_card_transition_finished(
	transition_id: String,
	evidence: Dictionary
) -> void:
	_card_transition_finish_evidence[transition_id] = evidence.duplicate(true)


func _on_resolution_presentation_started(
	receipt: Dictionary,
	evidence: Dictionary
) -> void:
	var public_id := _public_resolution_identity(receipt)
	if public_id.is_empty():
		return
	_resolution_receipts_by_id[public_id] = receipt.duplicate(true)
	_resolution_start_evidence[public_id] = evidence.duplicate(true)
	var envelope := _card_table_debug().get("last_envelope", {}) as Dictionary
	if (
		str(envelope.get("cue_id", "")) == "CARD_RESOLUTION_FOCUS"
		and str(envelope.get("source_public_receipt_id", "")) == public_id
	):
		_resolution_bridge_envelopes[public_id] = envelope.duplicate(true)


func _on_resolution_presentation_finished(
	public_id: String,
	evidence: Dictionary
) -> void:
	_resolution_finish_evidence[public_id] = evidence.duplicate(true)
	if _arrangement != null and is_instance_valid(_arrangement):
		_resolution_finish_debug[public_id] = (
			_arrangement.call("arrangement_debug_snapshot") as Dictionary
		).duplicate(true)


func _assert_human_public_play_bridge(
	card_id: String,
	queued_snapshot: Dictionary,
	receipt_start_index: int,
	bridge_before: Dictionary
) -> String:
	var application_receipt := _latest_accepted_card_queue_receipt(
		card_id,
		receipt_start_index
	)
	_expect(
		not application_receipt.is_empty(),
		"real card.queue returns one accepted application receipt"
	)
	if application_receipt.is_empty():
		return ""
	var binding := application_receipt.get("binding", {}) as Dictionary
	var action_id := str(binding.get("action_id", ""))
	_expect(not action_id.is_empty(), "accepted card.queue binds a stable action_id")
	if action_id.is_empty():
		return ""
	var transition_id := "public.card.%s" % action_id.sha256_text().left(20)
	var bridge_receipt_id := _bridge_receipt_id(
		"CARD_PLAY_PUBLIC",
		transition_id
	)
	for _frame in range(300):
		var current := _card_table_debug()
		if (
			_card_transition_finish_evidence.has(transition_id)
			and _director_cue_count(
				_director_cues_queued,
				"CARD_PLAY_PUBLIC",
				bridge_receipt_id
			) == 1
			and _director_cue_count(
				_director_cues_finished,
				"CARD_PLAY_PUBLIC",
				bridge_receipt_id
			) == 1
			and _cue_finished_delta_ready(
				bridge_before,
				current,
				"CARD_SELECT",
				1
			)
			and _cue_finished_delta_ready(
				bridge_before,
				current,
				"CARD_PLAY_PUBLIC",
				1
			)
		):
			break
		await process_frame
	var bridge_after := _card_table_debug()
	_assert_cue_delta(
		bridge_before,
		bridge_after,
		"CARD_SELECT",
		1,
		true
	)
	_assert_cue_delta(
		bridge_before,
		bridge_after,
		"CARD_PLAY_PUBLIC",
		1,
		false
	)
	var public_entry := _viewer_public_entry_for_card(queued_snapshot, card_id)
	_expect(
		not public_entry.is_empty(),
		"accepted card.queue appears in the real viewer public projection"
	)
	_expect(
		str(public_entry.get("presentation_correlation_id", "")) == transition_id,
		"accepted action_id binds the public projection correlation identity"
	)
	var envelope := _card_transition_bridge_envelopes.get(
		transition_id,
		{}
	) as Dictionary
	_expect(
		str(envelope.get("schema", ""))
			== "V076PublicCardPlayPresentationEnvelopeV1"
		and int(envelope.get("schema_version", 0)) == 1
		and str(envelope.get("cue_id", "")) == "CARD_PLAY_PUBLIC"
		and str(envelope.get("receipt_kind", "")) == "public_card_play_receipt"
		and str(envelope.get("bridge_consumer_class", ""))
			== "AUTHORIZED_PUBLIC_PROJECTION"
		and str(envelope.get("source_lineage_class", ""))
			== "ACCEPTED_CARD_QUEUE_RECEIPT",
		"public card play uses the production projection envelope and accepted queue lineage"
	)
	_expect(
		str(envelope.get("receipt_id", "")) == bridge_receipt_id
		and str(envelope.get("source_public_projection_id", "")) == transition_id
		and str(envelope.get("source_application_receipt_sha256", ""))
			== PresentationReceiptIdentity.canonical_sha256(application_receipt)
		and str(envelope.get("source_queue_action_sha256", ""))
			== PresentationReceiptIdentity.canonical_sha256({"action_id": action_id})
		and str(envelope.get("source_public_receipt_sha256", ""))
			== PresentationReceiptIdentity.canonical_sha256({
				"source_receipt": str(public_entry.get("source_receipt", "")),
			})
		and str(envelope.get("source_public_projection_sha256", ""))
			== PresentationReceiptIdentity.canonical_sha256(public_entry),
		"application receipt, queue action, public row, and Director receipt share one hash lineage"
	)
	var start_evidence := _card_transition_start_evidence.get(
		transition_id,
		{}
	) as Dictionary
	var finish_evidence := _card_transition_finish_evidence.get(
		transition_id,
		{}
	) as Dictionary
	_expect(
		_surface_evidence_green(start_evidence, true)
		and _surface_evidence_green(finish_evidence, false),
		"public card play records real start, target, and terminal screen Rect evidence"
	)
	_expect(
		_director_cue_count(
			_director_cues_queued,
			"CARD_PLAY_PUBLIC",
			bridge_receipt_id
		) == 1
		and _director_cue_count(
			_director_cues_finished,
			"CARD_PLAY_PUBLIC",
			bridge_receipt_id
		) == 1,
		"the expected public card receipt is queued and finished by the unique Director exactly once"
	)
	var queued_guard := _guard_at_queue.get(bridge_receipt_id, {}) as Dictionary
	var finished_guard := _guard_at_finish.get(bridge_receipt_id, {}) as Dictionary
	if not _guard_valid(queued_guard) or not _guard_valid(finished_guard):
		print("V076_CARD_TABLE_GUARD_DIAGNOSTIC|cue=CARD_PLAY_PUBLIC|receipt_id=%s|queued=%s|finished=%s" % [
			bridge_receipt_id,
			JSON.stringify(queued_guard),
			JSON.stringify(finished_guard),
		])
	_expect(
		_guard_valid(queued_guard)
		and _guard_valid(finished_guard),
		"public card Director boundaries retain valid authority guards"
	)
	return transition_id


func _assert_card_table_presentation_chain() -> void:
	var pending_resolution_count := 0
	if _arrangement != null and is_instance_valid(_arrangement):
		pending_resolution_count = int((
			_arrangement.call("arrangement_debug_snapshot") as Dictionary
		).get("resolution_queue_count", 0))
	var observed_resolution_count := maxi(
		_resolution_receipts_by_id.size() + pending_resolution_count,
		_public_resolution_receipts.size()
	)
	var deadline_msec := Time.get_ticks_msec() + maxi(
		12000,
		6000 + observed_resolution_count * 2000
	)
	while Time.get_ticks_msec() < deadline_msec:
		var bridge := _card_table_debug()
		var arrangement_debug := (
			_arrangement.call("arrangement_debug_snapshot") as Dictionary
			if _arrangement != null and is_instance_valid(_arrangement)
			else {}
		)
		var card_table_drained := (
			int(bridge.get("active_receipt_count", -1)) == 0
			and int(bridge.get("queued_count", -1))
				== int(bridge.get("finished_count", -2))
			and int(bridge.get("surface_started_count", -1))
				== int(bridge.get("surface_finished_count", -2))
			and str(arrangement_debug.get("resolution_stage", "")) == "IDLE"
			and int(arrangement_debug.get("resolution_queue_count", -1)) == 0
			and str(arrangement_debug.get(
				"resolution_current_receipt_id",
				"missing"
			)).is_empty()
			and _resolution_finish_evidence.size()
				>= _resolution_receipts_by_id.size()
		)
		if card_table_drained:
			var director_at_drain := _animation_director_debug()
			if int(director_at_drain.get("queued_cue_count", -1)) == 0:
				break
		await process_frame
	var unique_public_receipts := _resolution_receipts_by_id.duplicate(true)
	var final_bridge := _card_table_debug()
	var final_arrangement := (
		_arrangement.call("arrangement_debug_snapshot") as Dictionary
		if _arrangement != null and is_instance_valid(_arrangement)
		else {}
	)
	_expect(
		int(final_bridge.get("active_receipt_count", -1)) == 0
		and int(final_bridge.get("queued_count", -1))
			== int(final_bridge.get("finished_count", -2))
		and int(final_bridge.get("surface_started_count", -1))
			== int(final_bridge.get("surface_finished_count", -2))
		and bool(final_bridge.get("exact_once", false)),
		"card-table bridge drains every natural receipt with exact-once parity"
	)
	_expect(
		str(final_arrangement.get("resolution_stage", "")) == "IDLE"
		and int(final_arrangement.get("resolution_queue_count", -1)) == 0
		and str(final_arrangement.get(
			"resolution_current_receipt_id",
			"missing"
		)).is_empty(),
		"public resolution theater drains its real queue and current receipt"
	)
	for cue_id in ["CARD_SELECT", "CARD_PLAY_PUBLIC", "CARD_RESOLUTION_FOCUS"]:
		_assert_cue_terminal_row(final_bridge, cue_id)
	var select_row := _cue_row(final_bridge, "CARD_SELECT")
	var public_row := _cue_row(final_bridge, "CARD_PLAY_PUBLIC")
	var resolution_row := _cue_row(final_bridge, "CARD_RESOLUTION_FOCUS")
	_expect(
		int(select_row.get("production_source_count", -1)) == 2,
		"two real hand gestures produce exactly two production CARD_SELECT cues"
	)
	_expect(
		int(public_row.get("production_source_count", -1)) >= 5
		and _human_public_transition_ids.size() == 2,
		"three AI cards plus remove/requeue human play produce the natural public cue set"
	)
	_expect(
		unique_public_receipts.size() > 0
		and int(resolution_row.get("production_source_count", -1))
			== unique_public_receipts.size(),
		"every unique public resolution receipt produces one production focus cue"
	)
	_assert_selection_director_evidence(select_row)
	for public_id_variant in unique_public_receipts.keys():
		var public_id := str(public_id_variant)
		_assert_resolution_receipt_chain(
			public_id,
			unique_public_receipts.get(public_id, {}) as Dictionary
		)
	var director_debug := _animation_director_debug()
	if (
		int(director_debug.get("queued_cue_count", -1)) != 0
		or int(director_debug.get("receipt_collision_count", -1)) != 0
		or int(director_debug.get("receipt_rejection_count", -1)) != 0
	):
		print("V076_ANIMATION_DIRECTOR_DRAIN_DIAGNOSTIC|%s" % JSON.stringify(
			director_debug
		))
	_expect(
		int(director_debug.get("queued_cue_count", -1)) == 0
		and int(director_debug.get("receipt_collision_count", -1)) == 0
		and int(director_debug.get("receipt_rejection_count", -1)) == 0,
		"unique production Director is quiescent with no collision or rejection"
	)
	_expect(
		int(final_bridge.get("animation_gameplay_mutation_count", -1)) == 0
		and int(final_bridge.get("animation_rng_draw_delta", -1)) == 0
		and int(final_bridge.get("animation_authority_sequence_delta", -1)) == 0
		and int(final_bridge.get("animation_card_zone_mutation_count", -1)) == 0,
		"natural card-table animations report zero gameplay, RNG, sequence, or card-zone mutation"
	)
	var presentation_drain_guard_after := _flow.call(
		"presentation_authority_guard_snapshot"
	) as Dictionary
	_expect(
		bool(_presentation_drain_guard_before.get("valid", false))
		and bool(presentation_drain_guard_after.get("valid", false))
		and str(_presentation_drain_guard_before.get("snapshot_sha256", ""))
			== str(presentation_drain_guard_after.get("snapshot_sha256", ""))
		and _public_resolution_receipts.size()
			== _presentation_drain_resolution_source_count_before,
		"paused presentation drain preserves the full authority high-water and emits no new resolution source"
	)
	print("V076_CARD_TABLE_PRESENTATION_CHAIN|%s" % JSON.stringify({
		"bridge": final_bridge,
		"director": director_debug,
		"human_public_transition_ids": _human_public_transition_ids,
		"unique_public_resolution_count": unique_public_receipts.size(),
		"resolution_finish_count": _resolution_finish_evidence.size(),
	}))


func _assert_resolution_receipt_chain(
	public_id: String,
	receipt: Dictionary
) -> void:
	var bridge_receipt_id := _bridge_receipt_id(
		"CARD_RESOLUTION_FOCUS",
		public_id
	)
	var envelope := _resolution_bridge_envelopes.get(public_id, {}) as Dictionary
	var start_evidence := _resolution_start_evidence.get(public_id, {}) as Dictionary
	var finish_evidence := _resolution_finish_evidence.get(public_id, {}) as Dictionary
	_expect(
		str(envelope.get("schema", ""))
			== "V076PublicCardResolutionPresentationEnvelopeV1"
		and int(envelope.get("schema_version", 0)) == 1
		and str(envelope.get("receipt_id", "")) == bridge_receipt_id
		and str(envelope.get("cue_id", "")) == "CARD_RESOLUTION_FOCUS"
		and str(envelope.get("receipt_kind", "")) == "public_resolution_receipt"
		and str(envelope.get("bridge_consumer_class", ""))
			== "AUTHORIZED_PUBLIC_PROJECTION"
		and str(envelope.get("source_public_receipt_id", "")) == public_id
		and str(envelope.get("source_public_receipt_sha256", ""))
			== PresentationReceiptIdentity.canonical_sha256(receipt),
		"public resolution identity and canonical hash reach the production Director unchanged"
	)
	_expect(
		_surface_evidence_green(start_evidence, true)
		and _surface_evidence_green(finish_evidence, false)
		and int(finish_evidence.get("terminal_stage_count", 0)) == 1,
		"each public resolution focus has real Rect evidence and one terminal stage"
	)
	var finish_debug := _resolution_finish_debug.get(public_id, {}) as Dictionary
	var history := finish_debug.get("resolution_stage_history", []) as Array
	var tail := history.slice(maxi(0, history.size() - 5), history.size())
	_expect(
		tail.size() == 5
		and str(tail[0]) == "QUEUED"
		and str(tail[1]) == "FOCUSED"
		and str(tail[2]) == "RESOLVING"
		and str(tail[3]) == "EFFECT_PRESENTED"
		and str(tail[4]) in ["RESOLVED", "FIZZLED"],
		"resolution sidecar follows QUEUED to FOCUSED to RESOLVING to terminal order"
	)
	_expect(
		_director_cue_count(
			_director_cues_queued,
			"CARD_RESOLUTION_FOCUS",
			bridge_receipt_id
		) == 1
		and _director_cue_count(
			_director_cues_finished,
			"CARD_RESOLUTION_FOCUS",
			bridge_receipt_id
		) == 1,
		"each public resolution is queued and finished by the unique Director exactly once"
	)
	_expect(
		_guard_valid(_guard_at_queue.get(bridge_receipt_id, {}) as Dictionary)
		and _guard_valid(_guard_at_finish.get(bridge_receipt_id, {}) as Dictionary),
		"resolution Director boundaries retain valid authority guards"
	)


func _assert_selection_director_evidence(select_row: Dictionary) -> void:
	var queued_ids: Dictionary = {}
	for cue in _director_cues_queued:
		if str(cue.get("cue_id", "")) != "CARD_SELECT":
			continue
		var receipt_id := str(cue.get("receipt_id", ""))
		var projection := cue.get("projection", {}) as Dictionary
		var source_anchor := projection.get("source_anchor", {}) as Dictionary
		var target_anchor := projection.get("target_anchor", {}) as Dictionary
		queued_ids[receipt_id] = true
		_expect(
			str(cue.get("receipt_kind", "")) == "card_selection_receipt"
			and bool(projection.get("current_player_authorized", false))
			and _rect_has_area(source_anchor.get("global_rect", Rect2()))
			and _rect_has_area(target_anchor.get("global_rect", Rect2())),
			"CARD_SELECT consumes lawful own-hand anchors with real screen Rects"
		)
		_expect(
			_director_cue_count(
				_director_cues_finished,
				"CARD_SELECT",
				receipt_id
			) == 1,
			"each CARD_SELECT receipt reaches one Director finish even when drag interrupts the pulse"
		)
		var queued_guard := _guard_at_queue.get(receipt_id, {}) as Dictionary
		var finished_guard := _guard_at_finish.get(receipt_id, {}) as Dictionary
		_expect(
			_guard_valid(queued_guard)
			and _guard_valid(finished_guard)
			and _guard_hashes(queued_guard) == _guard_hashes(finished_guard),
			"CARD_SELECT presentation leaves stable authority domains byte-identical"
		)
	_expect(
		queued_ids.size() == int(select_row.get("production_source_count", -1)),
		"selection aggregate count equals the unique Director receipt count"
	)


func _assert_cue_delta(
	before: Dictionary,
	after: Dictionary,
	cue_id: String,
	minimum_delta: int,
	exact: bool
) -> void:
	var before_row := _cue_row(before, cue_id)
	var after_row := _cue_row(after, cue_id)
	for field_name in [
		"source_count",
		"envelope_count",
		"queued_count",
		"surface_started_count",
		"surface_finished_count",
		"finished_count",
		"production_source_count",
		"production_queued_count",
		"production_surface_started_count",
		"production_surface_finished_count",
		"production_finished_count",
	]:
		var delta := int(after_row.get(field_name, 0)) - int(
			before_row.get(field_name, 0)
		)
		_expect(
			delta == minimum_delta if exact else delta >= minimum_delta,
			"%s %s advances by the expected natural production delta"
				% [cue_id, field_name]
		)
	for field_name in [
		"duplicate_count",
		"collision_count",
		"rejection_count",
		"finish_missing_count",
		"surface_rejection_count",
		"fixture_source_count",
		"fixture_queued_count",
		"fixture_surface_started_count",
		"fixture_surface_finished_count",
		"fixture_finished_count",
	]:
		_expect(
			int(after_row.get(field_name, 0))
				== int(before_row.get(field_name, 0)),
			"%s %s remains unchanged during the natural gesture"
				% [cue_id, field_name]
		)


func _assert_cue_terminal_row(bridge: Dictionary, cue_id: String) -> void:
	var row := _cue_row(bridge, cue_id)
	_expect(
		int(row.get("source_count", -1)) == int(row.get("envelope_count", -2))
		and int(row.get("source_count", -1)) == int(row.get("queued_count", -2))
		and int(row.get("source_count", -1))
			== int(row.get("surface_started_count", -2))
		and int(row.get("source_count", -1))
			== int(row.get("surface_finished_count", -2))
		and int(row.get("source_count", -1)) == int(row.get("finished_count", -2))
		and int(row.get("production_source_count", -1))
			== int(row.get("source_count", -2)),
		"%s has source, queue, surface, and finish exact-once parity" % cue_id
	)
	_expect(
		int(row.get("duplicate_count", -1)) == 0
		and int(row.get("collision_count", -1)) == 0
		and int(row.get("rejection_count", -1)) == 0
		and int(row.get("finish_missing_count", -1)) == 0
		and int(row.get("surface_rejection_count", -1)) == 0
		and int(row.get("fixture_source_count", -1)) == 0
		and int(row.get("fixture_queued_count", -1)) == 0
		and int(row.get("fixture_surface_started_count", -1)) == 0
		and int(row.get("fixture_surface_finished_count", -1)) == 0
		and int(row.get("fixture_finished_count", -1)) == 0,
		"%s has no duplicate, collision, rejection, missing finish, or fixture credit" % cue_id
	)


func _card_table_debug() -> Dictionary:
	if _screen == null or not is_instance_valid(_screen):
		return {}
	return (
		(_screen.call("combat_debug_snapshot") as Dictionary).get(
			"card_table_presentation",
			{}
		) as Dictionary
	).duplicate(true)


func _animation_director_debug() -> Dictionary:
	if _screen == null or not is_instance_valid(_screen):
		return {}
	return (
		(_screen.call("combat_debug_snapshot") as Dictionary).get(
			"combat_animation_director",
			{}
		) as Dictionary
	).duplicate(true)


func _cue_row(bridge: Dictionary, cue_id: String) -> Dictionary:
	return (
		(bridge.get("cue_counts", {}) as Dictionary).get(cue_id, {})
		as Dictionary
	).duplicate(true)


func _cue_finished_delta_ready(
	before: Dictionary,
	after: Dictionary,
	cue_id: String,
	minimum_delta: int
) -> bool:
	var before_row := _cue_row(before, cue_id)
	var after_row := _cue_row(after, cue_id)
	return (
		int(after_row.get("production_source_count", 0))
			- int(before_row.get("production_source_count", 0)) >= minimum_delta
		and int(after_row.get("production_finished_count", 0))
			- int(before_row.get("production_finished_count", 0)) >= minimum_delta
	)


func _latest_accepted_card_queue_receipt(
	card_id: String,
	start_index: int
) -> Dictionary:
	for index in range(_receipts.size() - 1, start_index - 1, -1):
		var receipt := _receipts[index]
		if (
			str(receipt.get("intent_kind", "")) != "card.queue"
			or not bool(receipt.get("accepted", false))
		):
			continue
		var binding := receipt.get("binding", {}) as Dictionary
		var bound_card_id := str(binding.get("card_instance_id", card_id))
		if bound_card_id == card_id:
			return receipt.duplicate(true)
	return {}


func _viewer_public_entry_for_card(
	snapshot: Dictionary,
	card_id: String
) -> Dictionary:
	var projection := snapshot.get(
		"v076_public_action_arrangement",
		{}
	) as Dictionary
	for entry_variant in projection.get("entries", []) as Array:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		if (
			bool(entry.get("viewer_owned", false))
			and str(entry.get("card_instance_id", "")) == card_id
		):
			return entry.duplicate(true)
	return {}


func _bridge_receipt_id(cue_id: String, source_id: String) -> String:
	var prefix := cue_id.to_lower().replace("_", "-")
	var fingerprint := PresentationReceiptIdentity.canonical_sha256({
		"cue_id": cue_id,
		"source_id": source_id,
	})
	return "%s:%s" % [prefix, fingerprint.left(32)]


func _public_resolution_identity(receipt: Dictionary) -> String:
	return str(receipt.get(
		"presentation_receipt_id",
		receipt.get(
			"combat_receipt_id",
			receipt.get("receipt_id", receipt.get("anonymous_action_id", ""))
		)
	)).strip_edges()


func _director_cue_count(
	rows: Array[Dictionary],
	cue_id: String,
	receipt_id: String
) -> int:
	var count := 0
	for row in rows:
		if (
			str(row.get("cue_id", "")) == cue_id
			and str(row.get("receipt_id", "")) == receipt_id
		):
			count += 1
	return count


func _surface_evidence_green(evidence: Dictionary, is_start: bool) -> bool:
	return (
		not evidence.is_empty()
		and bool(evidence.get("presentation_only", false))
		and int(evidence.get("gameplay_mutation_count", -1)) == 0
		and int(evidence.get("rng_draw_delta", -1)) == 0
		and int(evidence.get("authority_sequence_delta", -1)) == 0
		and (
			_rect_has_area(evidence.get("source_rect", Rect2()))
			and _rect_has_area(evidence.get("target_rect", Rect2()))
			if is_start
			else _rect_has_area(evidence.get("end_rect", Rect2()))
		)
	)


func _rect_has_area(value: Variant) -> bool:
	return value is Rect2 and (value as Rect2).has_area()


func _stable_guard_subset() -> Dictionary:
	if (
		_flow == null
		or not is_instance_valid(_flow)
		or not _flow.has_method("presentation_authority_guard_snapshot")
	):
		return {}
	var guard := _flow.call(
		"presentation_authority_guard_snapshot"
	) as Dictionary
	return {
		"valid": bool(guard.get("valid", false)),
		"kernel_rng_state_sha256": str(guard.get("kernel_rng_state_sha256", "")),
		"runtime_card_zone_state_sha256": str(guard.get("runtime_card_zone_state_sha256", "")),
		"runtime_track_state_sha256": str(guard.get("runtime_track_state_sha256", "")),
		"runtime_facility_state_sha256": str(guard.get("runtime_facility_state_sha256", "")),
		"runtime_settlement_state_sha256": str(guard.get("runtime_settlement_state_sha256", "")),
	}


func _guard_hashes(guard: Dictionary) -> Dictionary:
	return {
		"kernel_rng_state_sha256": guard.get("kernel_rng_state_sha256", ""),
		"runtime_card_zone_state_sha256": guard.get("runtime_card_zone_state_sha256", ""),
		"runtime_track_state_sha256": guard.get("runtime_track_state_sha256", ""),
		"runtime_facility_state_sha256": guard.get("runtime_facility_state_sha256", ""),
		"runtime_settlement_state_sha256": guard.get("runtime_settlement_state_sha256", ""),
	}


func _guard_valid(guard: Dictionary) -> bool:
	if not bool(guard.get("valid", false)):
		return false
	for value in _guard_hashes(guard).values():
		if not PresentationReceiptIdentity.valid_sha256(str(value)):
			return false
	return true


func _private_ai_receipt_key_count(value: Variant) -> int:
	var forbidden := [
		"actor_id",
		"card_instance_id",
		"card_definition_id",
		"target_binding",
		"private_queue",
	]
	if value is Dictionary:
		var count := 0
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant).to_lower()
			if key in forbidden or key.begins_with("private_"):
				count += 1
			count += _private_ai_receipt_key_count(
				(value as Dictionary).get(key_variant)
			)
		return count
	if value is Array:
		var count := 0
		for child in value as Array:
			count += _private_ai_receipt_key_count(child)
		return count
	return 0


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
	print((
		"V076_ALPHA07_CARD_TABLE_FLOW_READINESS|status=%s|passed=%d|total=%d|"
		+ "production_main_scene_used=true|fixture_card_injection_count=0|"
		+ "fixture_track_phase_injection_count=0|fixture_ai_action_injection_count=0|"
		+ "failures=%s|direct_method_call_false_green_count=%d|real_pointer_card_trace=%s"
	) % [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
			_direct_method_call_false_green_count,
			JSON.stringify(_real_pointer_card_trace),
		]
	)
	quit(0 if _failures.is_empty() else 1)
