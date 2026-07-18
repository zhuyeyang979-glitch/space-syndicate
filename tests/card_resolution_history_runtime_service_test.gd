extends SceneTree

const HISTORY_SCENE := preload("res://scenes/runtime/CardResolutionHistoryRuntimeService.tscn")

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var service := HISTORY_SCENE.instantiate()
	root.add_child(service)
	service.configure({"history_limit": 2})
	_expect(bool(service.debug_snapshot().get("history_authoritative", false)), "configured service owns resolved history")

	var first := _entry(11, 0, "星链拆解")
	var second := _entry(12, 1, "影仓牵引")
	_expect(bool(service.append_resolved(first).get("appended", false)), "first resolution appends")
	_expect(bool(service.append_resolved(second).get("appended", false)), "second resolution appends")
	var duplicate: Dictionary = service.append_resolved(first)
	_expect(not bool(duplicate.get("appended", true)) and bool(duplicate.get("duplicate", false)), "duplicate resolution is rejected exact-once")
	_expect((service.history_snapshot() as Array).size() == 2, "duplicate does not add history")

	var patch: Dictionary = service.patch_entry(11, {"aftermath_clue": "公开余波", "resolved": true})
	_expect(bool(patch.get("patched", false)) and bool(patch.get("changed", false)), "history entry accepts a data-only patch")
	_expect(not bool(service.patch_entry(11, {"player_index": 7}).get("patched", true)), "identity fields cannot be patched")
	_expect(not bool(service.patch_entry(11, {"public_owner_revealed": true}).get("patched", true)), "retired owner reveal cannot be patched")
	_expect(not bool(service.patch_entry(11, {"nested": {"guessers": [1]}}).get("patched", true)), "nested retired owner fields fail closed")

	var public_history: Array = service.public_history_snapshot()
	var public_text := JSON.stringify(public_history)
	_expect(public_history.size() == 2, "public snapshot preserves order")
	for forbidden in ["player_index", "slot_index", "true_owner", "hidden_owner", "owner_truth", "public_owner", "guessers", "ai_plan", "cash", "private-hand-sentinel"]:
		_expect(not public_text.contains(forbidden), "public history omits private token %s" % forbidden)

	var owner_view: Array = service.private_viewer_snapshot(0)
	var rival_view: Array = service.private_viewer_snapshot(1)
	_expect(owner_view == public_history and rival_view == public_history, "all viewers receive byte-equivalent public history")

	var saved: Dictionary = service.to_save_data()
	_expect(not JSON.stringify(saved).contains("guessers") and not JSON.stringify(saved).contains("public_owner_"), "new save omits retired guess and owner fields")
	var restored := HISTORY_SCENE.instantiate()
	root.add_child(restored)
	restored.configure({"history_limit": 9})
	_expect(bool(restored.apply_save_data(saved).get("applied", false)), "save data restores")
	_expect(restored.to_save_data() == saved, "save/load roundtrip is exact")
	_expect(bool(restored.append_resolved(first).get("duplicate", false)), "restored lineage still rejects duplicate resolution")

	var third: Dictionary = _entry(13, 0, "业主透镜")
	_expect(bool(restored.append_resolved(third).get("appended", false)), "new resolution appends after restore")
	var limited: Array = restored.history_snapshot()
	_expect(limited.size() == 2 and int((limited[0] as Dictionary).get("resolution_id", -1)) == 12 and int((limited[1] as Dictionary).get("resolution_id", -1)) == 13, "history limit evicts oldest entry without losing order")
	_expect(bool(restored.append_resolved(first).get("duplicate", false)), "evicted resolution lineage remains exact-once")

	var before_bad_load: Dictionary = restored.to_save_data()
	var invalid: Dictionary = before_bad_load.duplicate(true)
	invalid["appended_resolution_ids"] = [12]
	_expect(not bool(restored.apply_save_data(invalid).get("applied", true)), "invalid lineage save fails closed")
	_expect(restored.to_save_data() == before_bad_load, "failed load is atomic")
	var legacy: Dictionary = before_bad_load.duplicate(true)
	legacy["history"] = (legacy.get("history", []) as Array).duplicate(true)
	(legacy["history"][0] as Dictionary)["guessers"] = [0, 1]
	(legacy["history"][0] as Dictionary)["public_owner_revealed"] = true
	(legacy["history"][0] as Dictionary)["nested_legacy"] = {"public_owner_label": "SECRET_OWNER"}
	_expect(bool(restored.apply_save_data(legacy).get("applied", false)), "legacy save applies while discarding retired owner fields")
	var restored_text := JSON.stringify(restored.to_save_data())
	_expect(not restored_text.contains("guessers") and not restored_text.contains("public_owner_") and not restored_text.contains("SECRET_OWNER"), "legacy owner and guess fields are recursively discarded without reward")

	var source := FileAccess.get_file_as_string("res://scripts/runtime/card_resolution_history_runtime_service.gd")
	_expect(not source.contains("Main") and not source.contains("current_scene") and not source.contains("Callable"), "history owner has no Main callback or scene lookup")
	_expect(not source.contains("selected_card_resolution_id"), "selected resolution remains outside history owner")
	var debug_text := JSON.stringify(restored.debug_snapshot())
	for forbidden in ["player_index", "skill", "true_owner", "cash", "hand"]:
		_expect(not debug_text.contains(forbidden), "debug snapshot omits private payload %s" % forbidden)

	service.queue_free()
	restored.queue_free()
	await process_frame
	_finish()


func _entry(resolution_id: int, player_index: int, card_name: String) -> Dictionary:
	return {
		"resolution_id": resolution_id,
		"player_index": player_index,
		"slot_index": 2,
		"selected_district": 4,
		"resolved_time": 12.5 + resolution_id,
		"skill": {
			"name": card_name,
			"kind": "player_hand_disrupt",
			"hidden_owner": "SECRET_OWNER",
			"cash": 999,
		},
		"true_owner": player_index,
		"owner_truth": player_index,
		"ai_plan": "SECRET_PLAN",
		"private_hand": "private-hand-sentinel",
		"guessers": [1],
		"public_owner_revealed": false,
		"public_owner_label": "",
	}


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Card resolution history runtime service passed (%d checks)." % _checks)
		quit(0)
		return
	push_error("Card resolution history runtime service failed:\n- " + "\n- ".join(_failures))
	quit(1)
