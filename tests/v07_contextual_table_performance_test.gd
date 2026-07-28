extends SceneTree

const SURFACE_SCENE := preload("res://scenes/ui/v07/V07ContextualTableSurface.tscn")
const RUNTIME = preload("res://scripts/runtime/card_batch_reference_runtime.gd")
const INVENTORY = preload("res://scripts/semantic/card_batch_inventory_state_v1.gd")
const TARGET = preload("res://scripts/semantic/card_batch_prebound_target_spec_v1.gd")
const SUBMISSION = preload("res://scripts/semantic/card_batch_submission_v1.gd")
const AUTHORED_RULE = preload("res://scripts/semantic/card_batch_authored_rule_v1.gd")
const SAMPLE_COUNT := 64
const MAX_PRESENTATION_P95_US := 100_000
const MAX_CORE_P95_US := 100_000

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var core_metrics := _measure_core_performance()
	var order_build_samples: Array[int] = core_metrics.get("order_build_samples", [])
	var core_resolution_samples: Array[int] = core_metrics.get("core_resolution_samples", [])
	var order_build_p95 := _p95(order_build_samples)
	var core_resolution_p95 := _p95(core_resolution_samples)
	_expect(bool(core_metrics.get("fixture_valid", false)), "fixed eight-seat Core fixtures complete without a gameplay wait")
	_expect(order_build_samples.size() == SAMPLE_COUNT, "resolution-order build records one sample per eight-card batch")
	_expect(core_resolution_samples.size() == SAMPLE_COUNT * 8, "Core resolution records all eight cards in every fixed batch")
	_expect(order_build_p95 < MAX_CORE_P95_US, "eight-card resolution-order build p95 stays bounded")
	_expect(core_resolution_p95 < MAX_CORE_P95_US, "per-card authoritative Core resolution p95 stays bounded")

	root.size = Vector2i(1920, 1080)
	var surface := SURFACE_SCENE.instantiate() as V07ContextualTableSurface
	root.add_child(surface)
	await process_frame
	await process_frame

	var roster_samples: Array[int] = []
	var popup_samples: Array[int] = []
	var dock_samples: Array[int] = []
	var resolution_samples: Array[int] = []
	for sample in range(SAMPLE_COUNT):
		var started := Time.get_ticks_usec()
		surface.apply_player_roster({"players": _players(8)})
		roster_samples.append(Time.get_ticks_usec() - started)

		started = Time.get_ticks_usec()
		surface.set_interaction_mode(V07ContextualTableSurface.MODE_TABLE_MAP)
		surface.open_region_popup(_region_projection(sample % 8))
		popup_samples.append(Time.get_ticks_usec() - started)

		started = Time.get_ticks_usec()
		surface.apply_player_card_dock({
			"normal_cards": _cards("普通", 5),
			"commodity_stacks": _cards("商品", 5),
			"bound_actions": _cards("绑定", 16),
		})
		dock_samples.append(Time.get_ticks_usec() - started)

		started = Time.get_ticks_usec()
		surface.apply_resolution_overlay({
			"phase": "CARD_RESOLUTION_ACTIVE",
			"batch_label": "8 人满批次",
			"completed_count": sample % 8,
			"total_count": 8,
			"current_card": "卡牌 %d" % (sample % 8),
			"next_card": "卡牌 %d" % ((sample + 1) % 8),
			"remaining_cards": ["后续 1", "后续 2", "后续 3"],
			"defense_feedback": "既存防御自动应用",
			"authoritative_result": "无需玩家输入",
		})
		resolution_samples.append(Time.get_ticks_usec() - started)
		if sample % 8 == 7:
			await process_frame

	var roster_p95 := _p95(roster_samples)
	var popup_p95 := _p95(popup_samples)
	var dock_p95 := _p95(dock_samples)
	var resolution_p95 := _p95(resolution_samples)
	_expect(roster_p95 < MAX_PRESENTATION_P95_US, "eight-seat roster update stays bounded")
	_expect(popup_p95 < MAX_PRESENTATION_P95_US, "region popup opening stays bounded")
	_expect(dock_p95 < MAX_PRESENTATION_P95_US, "three-pool card dock update stays bounded")
	_expect(resolution_p95 < MAX_PRESENTATION_P95_US, "per-card resolution overlay advance stays bounded")
	var snapshot := surface.debug_snapshot()
	_expect(int(snapshot.get("counter_ui_element_count", -1)) == 0, "performance path creates no counter UI")
	_expect(int(snapshot.get("ignored_gameplay_input_count", -1)) == 0, "performance driver inserts no gameplay wait")

	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("V07_CONTEXTUAL_TABLE_PERFORMANCE_TEST|status=%s|checks=%d|failures=%d|samples=%d|resolution_order_build_p95_us=%d|core_card_resolution_p95_us=%d|core_card_resolution_samples=%d|roster_p95_us=%d|popup_p95_us=%d|dock_p95_us=%d|resolution_ui_p95_us=%d|mid_resolution_gameplay_wait_count=0|counter_window_wait_seconds=0|counter_stack_depth=0" % [
		status,
		_checks,
		_failures.size(),
		SAMPLE_COUNT,
		order_build_p95,
		core_resolution_p95,
		core_resolution_samples.size(),
		roster_p95,
		popup_p95,
		dock_p95,
		resolution_p95,
	])
	for failure in _failures:
		push_error("V07_CONTEXTUAL_TABLE_PERFORMANCE_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)


func _measure_core_performance() -> Dictionary:
	var order_build_samples: Array[int] = []
	var core_resolution_samples: Array[int] = []
	var fixture_valid := true
	for sample in range(SAMPLE_COUNT):
		var runtime := RUNTIME.new() as CardBatchReferenceRuntime
		root.add_child(runtime)
		var fixture := _prepare_core_fixture(runtime)
		if not bool(fixture.get("valid", false)):
			fixture_valid = false
			root.remove_child(runtime)
			runtime.free()
			continue
		var started := Time.get_ticks_usec()
		var lock_result := runtime.lock_window()
		order_build_samples.append(Time.get_ticks_usec() - started)
		if not bool(lock_result.get("accepted", false)) \
				or (lock_result.get("resolution_order", []) as Array).size() != 8:
			fixture_valid = false
		else:
			var projections: Dictionary = fixture.get("target_projections", {})
			for _card_index in range(8):
				var state := runtime.state_snapshot()
				var active_submission_id := str(state.get("active_resolution_id", ""))
				var projection: Dictionary = projections.get(active_submission_id, {}) \
					if projections.get(active_submission_id) is Dictionary else {}
				started = Time.get_ticks_usec()
				var commit := runtime.commit_active_card(projection)
				core_resolution_samples.append(Time.get_ticks_usec() - started)
				var receipt: Dictionary = commit.get("receipt", {}) \
					if commit.get("receipt") is Dictionary else {}
				if not bool(commit.get("accepted", false)) \
						or not bool(runtime.complete_card_aftermath(str(receipt.get("receipt_id", ""))).get("accepted", false)):
					fixture_valid = false
					break
			if str(runtime.state_snapshot().get("phase", "")) != "BATCH_AFTERMATH" \
					or not bool(runtime.complete_batch_aftermath().get("accepted", false)):
				fixture_valid = false
		var audit := runtime.debug_snapshot()
		fixture_valid = fixture_valid \
			and int(audit.get("mid_resolution_gameplay_wait_count", -1)) == 0 \
			and int(audit.get("counter_window_wait_seconds", -1)) == 0 \
			and int(audit.get("counter_stack_depth", -1)) == 0
		root.remove_child(runtime)
		runtime.free()
	return {
		"fixture_valid": fixture_valid,
		"order_build_samples": order_build_samples,
		"core_resolution_samples": core_resolution_samples,
	}


func _prepare_core_fixture(runtime: CardBatchReferenceRuntime) -> Dictionary:
	var actor_ids: Array[String] = []
	var inventories: Dictionary = {}
	var submissions: Array[Dictionary] = []
	var projections: Dictionary = {}
	var rules: Dictionary = {}
	for index in range(8):
		var actor_id := "performance.player.%d" % index
		var card_instance_id := "performance.card.%d" % index
		var semantic_id := "v07.performance.card.%d" % index
		var source_revision := index + 1
		actor_ids.append(actor_id)
		var inventory := INVENTORY.empty(actor_id)
		var add := INVENTORY.add_normal_card(inventory, {
			"card_instance_id": card_instance_id,
			"card_semantic_id": semantic_id,
			"source_revision": source_revision,
		})
		if not bool(add.get("committed", false)):
			return {"valid": false}
		inventories[actor_id] = add.get("state", {})
		var target_id := "region.performance.%d" % index
		var target := TARGET.build(
			"region",
			[target_id],
			1,
			"",
			"standard",
			1,
			{"effect_kind": "performance_effect", "effect_amount": index + 1}
		)
		var submission := SUBMISSION.build(
			"performance.submission.%d" % index,
			actor_id,
			card_instance_id,
			semantic_id,
			"normal_card",
			"normal_hand",
			source_revision,
			index,
			7 - index,
			0,
			target
		)
		submissions.append(submission)
		rules[semantic_id] = AUTHORED_RULE.from_submission(submission)
		projections[str(submission.get("submission_id", ""))] = {
			"target_revisions": {target_id: 1},
			"inactive_target_ids": [],
		}
	if not bool(runtime.begin_initial_window(actor_ids, inventories).get("accepted", false)) \
			or not bool(runtime.configure_authoritative_card_rules(rules).get("accepted", false)):
		return {"valid": false}
	for submission in submissions:
		if not bool(runtime.submit_or_replace_draft(submission).get("accepted", false)):
			return {"valid": false}
	return {"valid": true, "target_projections": projections}


func _p95(samples: Array[int]) -> int:
	if samples.is_empty():
		return 2_147_483_647
	var ordered := samples.duplicate()
	ordered.sort()
	return ordered[clampi(int(ceil(float(ordered.size()) * 0.95)) - 1, 0, ordered.size() - 1)]


func _players(count: int) -> Array:
	var rows: Array = []
	for index in range(count):
		rows.append({"player_id": "seat-%d" % index, "display_name": "玩家 %d" % (index + 1), "public_status": "已锁定", "public_order_index": index, "is_viewer": index == count - 1})
	return rows


func _cards(prefix: String, count: int) -> Array:
	var rows: Array = []
	for index in range(count):
		rows.append({"display_name": "%s %d" % [prefix, index + 1]})
	return rows


func _region_projection(index: int) -> Dictionary:
	return {
		"region_index": index,
		"region_id": "region.%d" % index,
		"rack_revision": "perf-rack-%d" % index,
		"display_name": "地区 %d" % index,
		"public_status": "公开",
		"availability_text": "稳定投影",
		"cards": _cards("牌架", 4),
	}


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
