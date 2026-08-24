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
		"30秒公开排列",
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

	arrangement._drop_data(Vector2.ZERO, {
		"drag_type": "v073_card",
		"payload": {"instance_id": "card.local.1", "definition_id": "facility.factory.life.rank_1"},
	})
	_expect(dropped.size() == 1, "valid drag payload emits one drop signal")
	arrangement._drop_data(Vector2.ZERO, {
		"drag_type": "invalid",
		"payload": {"instance_id": "card.local.2"},
	})
	_expect(dropped.size() == 1, "invalid drag payload is rejected")

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
