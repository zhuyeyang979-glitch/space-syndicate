extends SceneTree

const ArrangementScene := preload(
	"res://scenes/ui/v075/V075PublicActionArrangement.tscn"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var arrangement := ArrangementScene.instantiate()
	root.add_child(arrangement)
	await process_frame
	var dropped: Array[Dictionary] = []
	arrangement.card_drop_requested.connect(
		func(payload: Dictionary) -> void:
			dropped.append(payload.duplicate(true))
	)
	arrangement.apply_public_arrangement(
		[
			{
				"id": "pending.a",
				"resolution_id": -1,
				"lane": "queue",
				"kind": "queue",
				"label": "匿名行动",
				"owner_hint": "匿名",
				"state": "等待提交",
				"active": false,
			},
			{
				"id": "active.b",
				"resolution_id": 0,
				"lane": "active",
				"kind": "active",
				"label": "设施行动",
				"owner_hint": "你",
				"state": "正在结算",
				"active": true,
			},
			{
				"id": "history.c",
				"resolution_id": 1,
				"lane": "history",
				"kind": "history",
				"label": "军队行动",
				"owner_hint": "匿名",
				"state": "已结算",
				"active": false,
			},
		],
		"30秒·悬停",
		"按权威顺序排列",
		"匿名身份保持隐藏。"
	)
	await process_frame
	var debug := arrangement.arrangement_debug_snapshot() as Dictionary
	_expect(int(debug.get("entry_count", 0)) == 3, "arrangement renders pending/active/history entries")
	_expect(int(debug.get("queue_count", 0)) == 1, "pending queue lane remains visible")
	_expect(int(debug.get("active_count", 0)) == 1, "active lane remains visible")
	_expect(int(debug.get("history_count", 0)) == 1, "history lane remains visible")
	_expect(not bool(debug.get("has_private_text", true)), "arrangement keeps private tokens out of rendered text")
	await create_timer(1.18).timeout
	debug = arrangement.arrangement_debug_snapshot() as Dictionary
	_expect(bool(debug.get("submission_window_active", false)), "submission window remains active past the legacy peek timeout")
	_expect(bool(debug.get("public_arrangement_expanded", false)), "public cards remain inspectable for the submission window")

	arrangement.apply_public_arrangement(
		[{
			"id": "active.b",
				"lane": "active",
				"kind": "active",
			"label": "设施行动",
			"owner_hint": "你",
			"state": "正在结算",
		}],
		"匿名轮转结算",
		"当前行动",
		"匿名身份保持隐藏。"
	)
	await process_frame
	debug = arrangement.arrangement_debug_snapshot() as Dictionary
	_expect(int(debug.get("arrangement_animation_count", 0)) >= 1, "arrangement transition animates")

	arrangement.begin_drag_drop_mode()
	await process_frame
	var drop_rect := arrangement.drag_drop_rect() as Rect2
	_expect(drop_rect.has_area(), "real drag mode exposes a bounded drop rectangle")
	var local_drop: Vector2 = arrangement.get_global_transform().affine_inverse() * drop_rect.get_center()
	arrangement._drop_data(local_drop, {
		"drag_type": "v073_card",
		"payload": {"instance_id": "card.local.1", "definition_id": "facility.factory.life.rank_1"},
	})
	_expect(dropped.size() == 1, "valid drag payload emits one drop signal")
	arrangement._drop_data(local_drop, {
		"drag_type": "invalid",
		"payload": {"instance_id": "card.local.2"},
	})
	_expect(dropped.size() == 1, "invalid drag payload is rejected")
	arrangement.end_drag_drop_mode()

	var move_before := int((arrangement.arrangement_debug_snapshot() as Dictionary).get(
		"card_move_animation_count",
		0
	))
	arrangement.register_card_source_transition(
		"card.local.transition",
		{},
		Rect2(Vector2(20.0, 20.0), Vector2(96.0, 128.0))
	)
	arrangement.apply_public_arrangement(
		[{
			"id": "pending.transition",
			"presentation_correlation_id": "public.card.transition",
			"source_receipt": "queue.transition",
			"card_instance_id": "card.local.transition",
			"card_definition_id": "facility.factory.life.rank_1",
			"viewer_owned": true,
			"card_face_mode": "face",
			"projection_role": "public_pending_card",
			"lane": "pending",
			"kind": "pending",
			"label": "工厂",
			"owner_hint": "你",
			"state": "等待提交",
		}],
		"30秒·悬停",
		"按权威顺序排列",
		"匿名身份保持隐藏。"
	)
	await process_frame
	await process_frame
	var move_after := int((arrangement.arrangement_debug_snapshot() as Dictionary).get(
		"card_move_animation_count",
		0
	))
	_expect(
		move_after == move_before + 1,
		"registered human source starts one visible move when its target row appears"
	)
	arrangement.register_card_source_transition(
		"card.local.transition",
		{},
		Rect2(Vector2(20.0, 20.0), Vector2(96.0, 128.0))
	)
	await process_frame
	_expect(
		int((arrangement.arrangement_debug_snapshot() as Dictionary).get(
			"card_move_animation_count",
			0
		)) == move_after,
		"duplicate receipt registration does not replay the same card move"
	)

	var resolution_receipts: Array[Dictionary] = [
		{
			"accepted": true,
			"receipt_id": "resolution.theater.test.001",
			"anonymous_action_id": "anonymous.action.test.001",
			"action_domain": "facility",
			"facility_type": "factory",
			"target_region_id": "region.000",
			"outcome_id": "facility_action_resolved",
			"public_effect_label": "工厂建成",
			"card_definition_id": "facility.factory.life.rank_1",
		},
		{
			"accepted": true,
			"receipt_id": "resolution.theater.test.002",
			"anonymous_action_id": "anonymous.action.test.002",
			"action_domain": "facility",
			"facility_type": "market",
			"target_region_id": "region.001",
			"outcome_id": "facility_action_resolved",
			"public_effect_label": "市场建成",
			"card_definition_id": "facility.market.life.rank_1",
		},
	]
	var resolving_entries: Array[Dictionary] = [
		{
			"id": "anonymous.action.test.001",
			"presentation_correlation_id": "resolution.theater.test.001",
			"source_receipt": "resolution.theater.test.001",
			"card_definition_id": "facility.factory.life.rank_1",
			"lane": "active",
			"kind": "active",
			"label": "工厂行动",
			"owner_hint": "匿名玩家",
			"state": "正在结算",
		},
		{
			"id": "anonymous.action.test.002",
			"presentation_correlation_id": "resolution.theater.test.002",
			"source_receipt": "resolution.theater.test.002",
			"card_definition_id": "facility.market.life.rank_1",
			"lane": "queue",
			"kind": "queue",
			"label": "市场行动",
			"owner_hint": "匿名玩家",
			"state": "等待结算",
		},
	]
	# First schedule the discoverability PEEK, then enter the authoritative
	# resolving projection before its timer fires.  This is the production race
	# that used to collapse the sidecar while the second receipt was starting.
	arrangement.apply_public_arrangement(
		resolving_entries,
		"公开更新",
		"两张公开牌等待结算",
		"匿名身份保持隐藏。",
		{
			"phase": "public_update",
			"batch_id": "batch.resolution.theater.test",
			"revision": 1,
		}
	)
	await process_frame
	arrangement.apply_public_arrangement(
		resolving_entries,
		"结算中",
		"按权威顺序逐张展示",
		"匿名身份保持隐藏。",
		{
			"phase": "resolving",
			"batch_id": "batch.resolution.theater.test",
			"revision": 2,
		}
	)
	await process_frame
	await process_frame
	var pre_resolution_debug := arrangement.arrangement_debug_snapshot() as Dictionary
	_expect(
		bool(pre_resolution_debug.get("resolution_window_active", false))
		and bool(pre_resolution_debug.get("public_arrangement_expanded", false))
		and (pre_resolution_debug.get(
			"resolution_sidecar_panel_rect",
			Rect2()
		) as Rect2).has_area(),
		"resolving projection opens one visible sidecar with a real rectangle"
	)
	var pre_resolution_toggle := arrangement.find_child(
		"PopoutToggle",
		true,
		false
	) as Button
	_expect(pre_resolution_toggle != null, "resolution sidecar exposes its collapse intent")
	if pre_resolution_toggle != null:
		pre_resolution_toggle.pressed.emit()
		await process_frame
	var blocked_collapse_debug := arrangement.arrangement_debug_snapshot() as Dictionary
	_expect(
		bool(blocked_collapse_debug.get("resolution_window_active", false))
		and bool(blocked_collapse_debug.get("public_arrangement_expanded", false))
		and (blocked_collapse_debug.get(
			"resolution_sidecar_panel_rect",
			Rect2()
		) as Rect2).has_area()
		and not bool(blocked_collapse_debug.get(
			"public_arrangement_user_toggled",
			true
		)),
		"collapse intent remains fail-visible and leaves no terminal-close override"
	)
	for resolution_receipt in resolution_receipts:
		var resolution_result := arrangement.consume_public_resolution_receipt(
			resolution_receipt
		) as Dictionary
		_expect(
			bool(resolution_result.get("accepted", false))
			and not bool(resolution_result.get("replayed", false)),
			"each accepted public resolution receipt enters the existing theater once"
		)
	var focus_deadline := Time.get_ticks_msec() + 1_000
	var focus_debug := {}
	while Time.get_ticks_msec() < focus_deadline:
		await process_frame
		focus_debug = arrangement.arrangement_debug_snapshot() as Dictionary
		if (focus_debug.get("resolution_focus_global_rect", Rect2()) as Rect2).has_area():
			break
	_expect(
		bool(focus_debug.get("public_arrangement_expanded", false)),
		"resolution receipt forcibly auto-opens the bounded sidecar"
	)
	_expect(
		bool(focus_debug.get("resolution_focus_within_sidecar", false)),
		"focused resolution card rect stays inside the sidecar"
	)
	_expect(
		not bool(focus_debug.get("resolution_focus_over_planet_center", true)),
		"focused resolution card does not move over the planet center"
	)
	_expect(
		float(focus_debug.get("resolution_sidecar_center_occlusion_area_px", -1.0)) == 0.0,
		"sidecar reports zero measured planet-center overlap"
	)
	await create_timer(1.18).timeout
	var post_peek_debug := arrangement.arrangement_debug_snapshot() as Dictionary
	_expect(
		bool(post_peek_debug.get("resolution_window_active", false))
		and bool(post_peek_debug.get("public_arrangement_expanded", false))
		and (post_peek_debug.get(
			"resolution_sidecar_panel_rect",
			Rect2()
		) as Rect2).has_area()
		and int(post_peek_debug.get("resolution_prestart_failure_count", -1)) == 0,
		"two-receipt resolution remains visible beyond the stale PEEK timeout"
	)
	var stage_deadline := Time.get_ticks_msec() + 6_000
	var terminal_history: Array = []
	while Time.get_ticks_msec() < stage_deadline:
		await process_frame
		var resolution_debug := arrangement.arrangement_debug_snapshot() as Dictionary
		terminal_history = resolution_debug.get("resolution_stage_history", []) as Array
		if terminal_history.size() >= 10 and not bool(
			resolution_debug.get("resolution_window_active", true)
		):
			break
	var expected_stages := [
		"QUEUED", "FOCUSED", "RESOLVING", "EFFECT_PRESENTED", "RESOLVED",
		"QUEUED", "FOCUSED", "RESOLVING", "EFFECT_PRESENTED", "RESOLVED",
	]
	_expect(
		terminal_history == expected_stages,
		"two public cards record complete ordered resolution theater stages"
	)
	var post_resolution_debug := arrangement.arrangement_debug_snapshot() as Dictionary
	_expect(
		int(post_resolution_debug.get("resolution_focus_animation_count", 0)) == 2
		and int(post_resolution_debug.get("resolution_effect_presented_count", 0)) == 2
		and int(post_resolution_debug.get("resolution_terminal_count", 0)) == 2
		and int(post_resolution_debug.get("resolution_prestart_failure_count", -1)) == 0,
		"two public cards each have one focus, effect presentation, and terminal stage"
	)
	_expect(
		not bool(post_resolution_debug.get("resolution_window_active", true))
		and not bool(post_resolution_debug.get("public_arrangement_expanded", true)),
		"resolution theater auto-closes after the final card presentation"
	)
	for resolution_receipt in resolution_receipts:
		var duplicate_result := arrangement.consume_public_resolution_receipt(
			resolution_receipt
		) as Dictionary
		_expect(
			bool(duplicate_result.get("accepted", false))
			and bool(duplicate_result.get("replayed", false))
			and str(duplicate_result.get("reason_code", ""))
				== "resolution_receipt_duplicate_suppressed",
			"each resolution receipt is suppressed exact-once after presentation"
		)
	var collision_receipt := resolution_receipts[0].duplicate(true)
	collision_receipt["target_region_id"] = "region.002"
	var collision_result := arrangement.consume_public_resolution_receipt(
		collision_receipt
	) as Dictionary
	_expect(
		not bool(collision_result.get("accepted", false))
		and str(collision_result.get("reason_code", "")) == "resolution_receipt_identity_collision",
		"same resolution identity with a different fingerprint fails closed"
	)
	var collision_debug := arrangement.arrangement_debug_snapshot() as Dictionary
	_expect(int(collision_debug.get("resolution_duplicate_suppression_count", 0)) == 2, "duplicate suppression ledger records both receipts once")
	_expect(int(collision_debug.get("resolution_collision_count", 0)) == 1, "collision ledger increments once")

	arrangement.queue_free()
	_finish()


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish() -> void:
	if _failures.is_empty():
		print("V076_PUBLIC_ACTION_ARRANGEMENT_TEST|status=PASS|checks=%d" % _checks)
	else:
		print("V076_PUBLIC_ACTION_ARRANGEMENT_TEST|status=FAIL|checks=%d|failures=%s" % [_checks, JSON.stringify(_failures)])
	quit(0 if _failures.is_empty() else 1)
