extends SceneTree

const SOURCE_SCENE := preload("res://scenes/runtime/CardCodexPublicSourceService.tscn")
const SNAPSHOT_SCENE := preload("res://scenes/runtime/CardCodexPublicSnapshotService.tscn")
const SEMANTIC_CATALOG_SCENE := preload(
	"res://scenes/runtime/CardSemanticCatalogService.tscn"
)
const PLAYER_FACE_PROJECTION_SCENE := preload(
	"res://scenes/runtime/CardPlayerFaceProjectionService.tscn"
)
const PUBLIC_LOCALIZATION_SCENE := preload(
	"res://scenes/runtime/CardPlayerFacePublicLocalizationSourceService.tscn"
)
const MAX_INITIALIZATION_USEC := 8000000
const BASELINE_CONFIGURE_USEC := 276953
const BASELINE_FIRST_BROWSER_USEC := 685780
const BASELINE_REPEAT_BROWSER_USEC := 749173
const BASELINE_HOVER_100_USEC := 57699
const BASELINE_DETAIL_20_USEC := 53094
const BASELINE_FULL_CATALOG_USEC := 159751
const MAX_BASELINE_MULTIPLIER := 1.25
const MAX_MAGNITUDE_MULTIPLIER := 10.0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var snapshot := SNAPSHOT_SCENE.instantiate()
	var source := SOURCE_SCENE.instantiate()
	var semantic_catalog := SEMANTIC_CATALOG_SCENE.instantiate()
	var player_face_projection := PLAYER_FACE_PROJECTION_SCENE.instantiate()
	var public_localization := PUBLIC_LOCALIZATION_SCENE.instantiate()
	root.add_child(snapshot)
	root.add_child(semantic_catalog)
	root.add_child(player_face_projection)
	root.add_child(public_localization)
	root.add_child(source)
	snapshot.configure({})
	var semantic_started := Time.get_ticks_usec()
	semantic_catalog.configure()
	var semantic_usec := Time.get_ticks_usec() - semantic_started
	var localization_started := Time.get_ticks_usec()
	public_localization.configure(semantic_catalog)
	var localization_usec := Time.get_ticks_usec() - localization_started
	var bind_started := Time.get_ticks_usec()
	var bound: Dictionary = source.bind_dependencies({
		"player_face_projection": player_face_projection,
		"public_localization_source": public_localization,
		"semantic_catalog": semantic_catalog,
		"snapshot": snapshot,
	})
	var bind_usec := Time.get_ticks_usec() - bind_started
	if not bool(bound.get("service_ready", false)) \
			or bool(bound.get("projection_cache_ready", true)):
		push_error("CARD_CODEX_PLAYERFACE_PERFORMANCE_TEST|source_binding_invalid")
		quit(1)
		return
	var projection_cache_started := Time.get_ticks_usec()
	var ids: Array[String] = source.ordered_card_ids("all")
	var projection_cache_usec := Time.get_ticks_usec() - projection_cache_started
	var configured: Dictionary = source.debug_snapshot()
	if not bool(configured.get("service_ready", false)) \
			or not bool(configured.get("projection_cache_ready", false)):
		push_error("CARD_CODEX_PLAYERFACE_PERFORMANCE_TEST|source_not_ready")
		quit(1)
		return
	var request := {
		"names": ids,
		"columns": 5,
		"rows": 8,
		"page_index": 0,
		"filter_id": "all",
		"selected_card": ids[0],
		"filters": [],
	}
	var first_started := Time.get_ticks_usec()
	var first_browser: Dictionary = source.compose_browser(request)
	var first_browser_usec := Time.get_ticks_usec() - first_started
	var repeat_started := Time.get_ticks_usec()
	var repeated_browser: Dictionary = source.compose_browser(request)
	var repeated_browser_usec := Time.get_ticks_usec() - repeat_started
	var hover_started := Time.get_ticks_usec()
	for index in range(100):
		source.compose_card_facts(ids[index % ids.size()], index)
	var hover_100_usec := Time.get_ticks_usec() - hover_started
	var detail_started := Time.get_ticks_usec()
	for index in range(20):
		source.compose_detail(ids[index % ids.size()], index, ids.size())
	var detail_20_usec := Time.get_ticks_usec() - detail_started
	var full_catalog_started := Time.get_ticks_usec()
	for index in range(ids.size()):
		source.compose_card_facts(ids[index], index)
	var full_catalog_usec := Time.get_ticks_usec() - full_catalog_started
	var browser_cards: Array = first_browser.get("cards", []) as Array
	var debug: Dictionary = source.debug_snapshot()
	var initialization_usec := localization_usec + projection_cache_usec
	var startup_authorization_usec := localization_usec + bind_usec
	var first_open_usec := projection_cache_usec + first_browser_usec
	if ids.size() != 348 or browser_cards.size() != 40 \
			or repeated_browser.is_empty() \
			or int(debug.get("cached_dto_count", 0)) != 348 \
			or int(debug.get("cached_family_ladder_count", 0)) != 87 \
			or int(debug.get("semantic_compile_delta", -1)) != 0 \
			or int(debug.get("catalog_snapshot_count", 0)) != 1:
		push_error("CARD_CODEX_PLAYERFACE_PERFORMANCE_TEST|output_invalid")
		quit(1)
		return
	if initialization_usec > MAX_INITIALIZATION_USEC \
			or startup_authorization_usec > int(
				BASELINE_CONFIGURE_USEC * MAX_MAGNITUDE_MULTIPLIER
			) \
			or first_open_usec > int(
				BASELINE_FIRST_BROWSER_USEC * MAX_MAGNITUDE_MULTIPLIER
			) \
			or first_browser_usec > int(
				BASELINE_FIRST_BROWSER_USEC * MAX_BASELINE_MULTIPLIER
			) \
			or repeated_browser_usec > int(
				BASELINE_REPEAT_BROWSER_USEC * MAX_BASELINE_MULTIPLIER
			) \
			or hover_100_usec > int(
				BASELINE_HOVER_100_USEC * MAX_BASELINE_MULTIPLIER
			) \
			or detail_20_usec > int(
				BASELINE_DETAIL_20_USEC * MAX_BASELINE_MULTIPLIER
			) \
			or full_catalog_usec > int(
				BASELINE_FULL_CATALOG_USEC * MAX_BASELINE_MULTIPLIER
			):
		push_error(
			"CARD_CODEX_PLAYERFACE_PERFORMANCE_TEST|performance_gate_failed|semantic_usec=%d|localization_usec=%d|bind_usec=%d|startup_authorization_usec=%d|projection_cache_usec=%d|first_open_usec=%d|first_browser_usec=%d|repeat_browser_usec=%d|hover_100_usec=%d|detail_20_usec=%d|full_catalog_usec=%d"
			% [
				semantic_usec,
				localization_usec,
				bind_usec,
				startup_authorization_usec,
				projection_cache_usec,
				first_open_usec,
				first_browser_usec,
				repeated_browser_usec,
				hover_100_usec,
				detail_20_usec,
				full_catalog_usec,
			]
		)
		quit(1)
		return
	print("CARD_CODEX_PLAYERFACE_PERFORMANCE_TEST|status=PASS|semantic_usec=%d|localization_usec=%d|bind_usec=%d|startup_authorization_usec=%d|projection_cache_usec=%d|first_open_usec=%d|first_browser_usec=%d|repeat_browser_usec=%d|hover_100_usec=%d|detail_20_usec=%d|full_catalog_usec=%d|dto_count=%d|family_count=%d|compile_delta=%d|catalog_snapshot_count=%d|initialization_phases=%s" % [
		semantic_usec,
		localization_usec,
		bind_usec,
		startup_authorization_usec,
		projection_cache_usec,
		first_open_usec,
		first_browser_usec,
		repeated_browser_usec,
		hover_100_usec,
		detail_20_usec,
		full_catalog_usec,
		int(debug.get("cached_dto_count", 0)),
		int(debug.get("cached_family_ladder_count", 0)),
		int(debug.get("semantic_compile_delta", -1)),
		int(debug.get("catalog_snapshot_count", 0)),
		JSON.stringify(debug.get("initialization_timings_usec", {})),
	])
	source.free()
	snapshot.free()
	semantic_catalog.free()
	player_face_projection.free()
	public_localization.free()
	quit(0)
