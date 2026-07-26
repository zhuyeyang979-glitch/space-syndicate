extends Control

const SUMMARY_FIELDS := [
	"schema_version",
	"status",
	"failure_ids",
	"configure_usec",
	"first_browser_usec",
	"repeat_browser_usec",
	"hover_usec",
	"detail_usec",
	"card_count",
	"family_count",
	"category_count",
	"browser_card_count",
	"dto_projection_count",
	"dto_cache_hit_count",
	"family_ladder_cache_hit_count",
	"catalog_snapshot_count",
	"catalog_reload_count",
	"catalog_authorization_count",
	"localization_issue_count",
	"semantic_compile_delta",
	"semantic_compile_count",
	"semantic_cache_hit_count",
	"browser_compose_count",
	"detail_compose_count",
]

var _result: Dictionary = {}


func _ready() -> void:
	call_deferred("_run")


func result_snapshot() -> Dictionary:
	return _result.duplicate(true)


func _run() -> void:
	var semantic := get_node_or_null("CardSemanticCatalogService") \
		as CardSemanticCatalogService
	var localization: Node = get_node_or_null(
		"CardPlayerFacePublicLocalizationSourceService"
	)
	var projection: Node = get_node_or_null("CardPlayerFaceProjectionService")
	var snapshot := get_node_or_null("CardCodexPublicSnapshotService") \
		as CardCodexPublicSnapshotService
	var source := get_node_or_null("CardCodexPublicSourceService") \
		as CardCodexPublicSourceService
	var failure_ids: Array[String] = []
	if semantic == null or localization == null or projection == null \
			or snapshot == null or source == null:
		failure_ids.append("production_nodes_missing")
		_publish(_empty_summary(failure_ids))
		return

	var configure_started := Time.get_ticks_usec()
	snapshot.configure({})
	var semantic_configuration := semantic.configure()
	var localization_configuration: Dictionary = localization.call(
		"configure", semantic
	)
	var source_configuration := source.configure({
		"player_face_projection": projection,
		"public_localization_source": localization,
		"semantic_catalog": semantic,
		"snapshot": snapshot,
	})
	var configure_usec := Time.get_ticks_usec() - configure_started
	if not bool(semantic_configuration.get("configured", false)):
		failure_ids.append("semantic_catalog_not_ready")
	if not bool(localization_configuration.get("configured", false)):
		failure_ids.append("public_localization_not_ready")
	if not bool(source_configuration.get("service_ready", false)):
		failure_ids.append("codex_source_not_ready")

	var ids: Array[String] = source.ordered_card_ids("all")
	var request := {
		"names": ids,
		"columns": 5,
		"rows": 8,
		"page_index": 0,
		"filter_id": "all",
		"selected_card": ids[0] if not ids.is_empty() else "",
		"run_pool_count": 0,
		"district_supply_count": 0,
	}
	var first_started := Time.get_ticks_usec()
	var first_browser := source.compose_browser(request)
	var first_browser_usec := Time.get_ticks_usec() - first_started
	var repeat_started := Time.get_ticks_usec()
	var repeated_browser := source.compose_browser(request)
	var repeat_browser_usec := Time.get_ticks_usec() - repeat_started
	var hover_started := Time.get_ticks_usec()
	var hover := source.compose_card_facts(ids[0], 0) \
		if not ids.is_empty() else {}
	var hover_usec := Time.get_ticks_usec() - hover_started
	var detail_started := Time.get_ticks_usec()
	var detail := source.compose_detail(ids[0], 0, ids.size()) \
		if not ids.is_empty() else {}
	var detail_usec := Time.get_ticks_usec() - detail_started
	var debug := source.debug_snapshot()
	var semantic_debug := semantic.validation_snapshot()
	var browser_cards_value: Variant = first_browser.get("cards")
	var browser_cards: Array = browser_cards_value as Array \
		if browser_cards_value is Array else []

	if ids.size() != 348:
		failure_ids.append("card_count_mismatch")
	if int(debug.get("cached_family_ladder_count", 0)) != 87:
		failure_ids.append("family_count_mismatch")
	if source.public_filter_options().size() != 8:
		failure_ids.append("category_count_mismatch")
	if browser_cards.size() != 40 or repeated_browser.is_empty():
		failure_ids.append("browser_projection_invalid")
	if not bool(hover.get("valid", false)):
		failure_ids.append("hover_projection_invalid")
	if detail.is_empty():
		failure_ids.append("detail_projection_invalid")
	if int(debug.get("dto_projection_count", 0)) != 348 \
			or int(debug.get("semantic_compile_delta", -1)) != 0:
		failure_ids.append("projection_cache_gate_failed")
	if int(debug.get("catalog_snapshot_count", 0)) != 1 \
			or int(debug.get("catalog_reload_count", -1)) != 0:
		failure_ids.append("catalog_reload_gate_failed")

	_result = {
		"schema_version": 1,
		"status": "PASS" if failure_ids.is_empty() else "FAIL",
		"failure_ids": failure_ids.duplicate(),
		"configure_usec": configure_usec,
		"first_browser_usec": first_browser_usec,
		"repeat_browser_usec": repeat_browser_usec,
		"hover_usec": hover_usec,
		"detail_usec": detail_usec,
		"card_count": ids.size(),
		"family_count": int(debug.get("cached_family_ladder_count", 0)),
		"category_count": maxi(0, source.public_filter_options().size() - 1),
		"browser_card_count": browser_cards.size(),
		"dto_projection_count": int(debug.get("dto_projection_count", 0)),
		"dto_cache_hit_count": int(debug.get("dto_cache_hit_count", 0)),
		"family_ladder_cache_hit_count": int(
			debug.get("family_ladder_cache_hit_count", 0)
		),
		"catalog_snapshot_count": int(debug.get("catalog_snapshot_count", 0)),
		"catalog_reload_count": int(debug.get("catalog_reload_count", -1)),
		"catalog_authorization_count": int(
			debug.get("catalog_record_authorization_count", 0)
		),
		"localization_issue_count": int(debug.get("localization_issue_count", 0)),
		"semantic_compile_delta": int(debug.get("semantic_compile_delta", -1)),
		"semantic_compile_count": int(semantic_debug.get("compile_count", 0)),
		"semantic_cache_hit_count": int(semantic_debug.get("cache_hit_count", 0)),
		"browser_compose_count": int(debug.get("browser_compose_count", 0)),
		"detail_compose_count": int(debug.get("detail_compose_count", 0)),
	}
	_publish(_result)


func _empty_summary(failure_ids: Array[String]) -> Dictionary:
	var summary := {
		"schema_version": 1,
		"status": "FAIL",
		"failure_ids": failure_ids.duplicate(),
	}
	for field_id in SUMMARY_FIELDS:
		if not summary.has(field_id):
			summary[field_id] = 0
	return summary


func _publish(summary: Dictionary) -> void:
	var keys: Array = summary.keys()
	keys.sort()
	var expected := SUMMARY_FIELDS.duplicate()
	expected.sort()
	if keys != expected:
		summary = _empty_summary(["summary_schema_not_closed"])
	_result = summary.duplicate(true)
	var status_label := get_node_or_null("BenchPanel/Layout/Status") as Label
	var metrics_label := get_node_or_null("BenchPanel/Layout/Metrics") as Label
	if status_label != null:
		status_label.text = "PASS" if str(summary.get("status", "")) == "PASS" \
			else "FAIL"
		status_label.modulate = Color("#4ade80") \
			if str(summary.get("status", "")) == "PASS" else Color("#fb7185")
	if metrics_label != null:
		metrics_label.text = (
			"348-card PlayerFace production chain\n"
			+ "Configure: %dus | First page: %dus | Repeat: %dus\n"
			+ "Hover: %dus | Detail: %dus | Compile delta: %d\n"
			+ "DTOs: %d | Families: %d | Categories: %d"
		) % [
			int(summary.get("configure_usec", 0)),
			int(summary.get("first_browser_usec", 0)),
			int(summary.get("repeat_browser_usec", 0)),
			int(summary.get("hover_usec", 0)),
			int(summary.get("detail_usec", 0)),
			int(summary.get("semantic_compile_delta", -1)),
			int(summary.get("dto_projection_count", 0)),
			int(summary.get("family_count", 0)),
			int(summary.get("category_count", 0)),
		]
	print(
		"CARD_CODEX_PLAYERFACE_PRODUCTION_BENCH|%s"
		% JSON.stringify(summary)
	)
	if str(summary.get("status", "")) != "PASS":
		push_error(
			"CARD_CODEX_PLAYERFACE_PRODUCTION_BENCH_FAILED|%s"
			% JSON.stringify(summary.get("failure_ids", []))
		)
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		get_tree().quit(0 if str(summary.get("status", "")) == "PASS" else 1)
