extends SceneTree

const MainScene := preload("res://scenes/main.tscn")
const V075CardDefinitionRegistry := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)
const CombatSurfaceBench := preload(
	"res://scripts/tools/v075/v075_combat_player_surface_bench.gd"
)

const FIXED_SEED := 900626424

var _checks := 0
var _failures: Array[String] = []
var _green_cases := 0
var _runtime_composition_count := 0
var _real_combat_track_binding_count := 0
var _rows: Array[Dictionary] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var original_size := root.size
	var original_scale_size := root.content_scale_size
	var default_height := int(ProjectSettings.get_setting(
		"display/window/size/viewport_height",
		960
	))
	var cases := [
		{"label": "width_480", "size": Vector2i(480, default_height)},
		{"label": "width_640", "size": Vector2i(640, default_height)},
		{"label": "width_660", "size": Vector2i(660, default_height)},
		{"label": "width_900", "size": Vector2i(900, default_height)},
		{"label": "1366x768", "size": Vector2i(1366, 768)},
		{"label": "1600x960", "size": Vector2i(1600, 960)},
		{"label": "1920x1080", "size": Vector2i(1920, 1080)},
	]
	var requested_case := _argument_value("--case-label")
	if not requested_case.is_empty():
		var filtered_cases := []
		for case_variant in cases:
			if str((case_variant as Dictionary).get("label", "")) == requested_case:
				filtered_cases.append(case_variant)
		cases = filtered_cases
		_expect(cases.size() == 1, "requested viewport case exists")
	for case in cases:
		await _run_case(case)
	root.content_scale_size = original_scale_size
	root.size = original_size
	_expect(_green_cases == cases.size(), "all seven production viewport cases are green")
	_expect(
		_runtime_composition_count == cases.size(),
		"every viewport instantiates the production V075 runtime composition"
	)
	_expect(
		_real_combat_track_binding_count == cases.size(),
		"every viewport binds a real combat TrackCard texture from its definition"
	)
	_finish(cases.size())


func _run_case(case: Dictionary) -> void:
	var label := str(case.get("label", "viewport"))
	var requested_size := case.get("size", Vector2i.ZERO) as Vector2i
	root.content_scale_size = requested_size
	root.size = requested_size
	await _settle_frames(2)
	var main := MainScene.instantiate() as Control
	_expect(main != null, "%s main.tscn instantiates" % label)
	if main == null:
		return
	root.add_child(main)
	await _settle_frames(4)
	var composition := main.get_node_or_null("V075RuntimeComposition")
	var screen := main.get_node_or_null("V075GameScreen") as Control
	var surface := (
		screen.find_child("CombatSurface", true, false) as Control
		if screen != null
		else null
	)
	_expect(
		composition != null and screen != null and surface != null,
		"%s uses main -> V075 composition -> V075 screen -> real combat surface"
			% label
	)
	if composition != null:
		_runtime_composition_count += 1
	if screen == null or surface == null:
		main.queue_free()
		await process_frame
		return
	var seed_input := screen.find_child("SeedInput", true, false) as LineEdit
	var start_button := screen.find_child(
		"StartConfiguredButton",
		true,
		false
	) as Button
	_expect(
		seed_input != null and start_button != null,
		"%s production new-game controls are reachable" % label
	)
	if seed_input != null and start_button != null:
		seed_input.text = str(FIXED_SEED)
		start_button.pressed.emit()
		await _settle_frames(8)
	var debug_before := screen.call("combat_debug_snapshot") as Dictionary
	if bool(debug_before.get("overlay_collapsed", true)):
		screen.call("_toggle_combat_surface")
	await _settle_frames(4)
	screen.call(
		"apply_combat_projection",
		CombatSurfaceBench.make_projection("player.local"),
		"monster.tech.local.01"
	)
	await _settle_frames(4)
	var root_scroll := screen.get_node("RootMargin") as ScrollContainer
	var transition_green := true
	var transition_audits := {}
	if label == "1600x960":
		# Exercise the two state transitions that a fresh-per-size matrix would
		# otherwise miss. Production callbacks, not direct resolver calls, must
		# settle both the expanded surface and the live narrow/wide resize.
		screen.call("_toggle_combat_surface")
		await _settle_frames(2)
		screen.call("_toggle_combat_surface")
		await _settle_frames(4)
		var expanded_audit := (
			screen.call("v075_responsive_geometry_audit") as Dictionary
		)
		var expanded_probe := await _probe_populated_surface(
			surface,
			root_scroll
		)
		root.content_scale_size = Vector2i(480, 960)
		root.size = Vector2i(480, 960)
		await _settle_frames(5)
		var narrow_audit := (
			screen.call("v075_responsive_geometry_audit") as Dictionary
		)
		var narrow_probe := await _probe_populated_surface(surface, root_scroll)
		root.content_scale_size = requested_size
		root.size = requested_size
		await _settle_frames(5)
		var restored_audit := (
			screen.call("v075_responsive_geometry_audit") as Dictionary
		)
		var restored_probe := await _probe_populated_surface(
			surface,
			root_scroll
		)
		var cue_result_a := surface.call("show_presentation_cue", {
			"presentation_receipt_id": "layout.presentation.1",
			"event_kind": "monster_card_resolved",
			"public_payload": {"public_summary": "公开战斗回执一"},
			"asset_keys": [],
		}) as Dictionary
		var cue_result_b := surface.call("show_presentation_cue", {
			"presentation_receipt_id": "layout.presentation.2",
			"event_kind": "military_action_resolved",
			"public_payload": {"public_summary": "公开战斗回执二"},
			"asset_keys": [],
		}) as Dictionary
		await _settle_frames(5)
		var cue_audit := (
			screen.call("v075_responsive_geometry_audit") as Dictionary
		)
		var cue_probe := await _probe_populated_surface(surface, root_scroll)
		var cue_debug := surface.call("debug_snapshot") as Dictionary
		surface.call("reset_presentation_cues")
		await _settle_frames(5)
		var reset_audit := (
			screen.call("v075_responsive_geometry_audit") as Dictionary
		)
		var reset_probe := await _probe_populated_surface(surface, root_scroll)
		var reset_debug := surface.call("debug_snapshot") as Dictionary
		var presentation_layout_green := (
			bool(cue_result_a.get("applied", false))
			and bool(cue_result_b.get("applied", false))
			and int(cue_debug.get("presentation_history_count", 0)) == 2
			and _surface_measurement_green(cue_audit)
			and float(cue_audit.get(
				"combat_surface_preferred_content_height",
				0.0
			)) > float(restored_audit.get(
				"combat_surface_preferred_content_height",
				0.0
			))
			and bool(cue_probe.get("green", false))
			and int(reset_debug.get("presentation_history_count", 1)) == 0
			and _surface_measurement_green(reset_audit)
			and absf(float(reset_audit.get(
				"combat_surface_preferred_content_height",
				0.0
			)) - float(restored_audit.get(
				"combat_surface_preferred_content_height",
				-1.0
			))) <= 0.5
			and bool(reset_probe.get("green", false))
		)
		transition_green = (
			bool(expanded_audit.get("combat_surface_content_origin_green", false))
			and _wide_surface_stable(expanded_audit)
			and bool(expanded_probe.get("green", false))
			and str(narrow_audit.get("layout_mode", "")) == "NARROW"
			and bool(narrow_audit.get(
				"combat_surface_content_origin_green",
				false
			))
			and int(narrow_audit.get("private_grid_columns", 0)) == 1
			and _surface_measurement_green(narrow_audit)
			and bool(narrow_probe.get("green", false))
			and str(restored_audit.get("layout_mode", "")) == "REGULAR"
			and bool(restored_audit.get(
				"combat_surface_content_origin_green",
				false
			))
			and _wide_surface_stable(restored_audit)
			and bool(restored_probe.get("green", false))
			and presentation_layout_green
		)
		transition_audits = {
			"expanded": expanded_audit,
			"expanded_probe": expanded_probe,
			"narrow": narrow_audit,
			"narrow_probe": narrow_probe,
			"restored": restored_audit,
			"restored_probe": restored_probe,
			"presentation": cue_audit,
			"presentation_probe": cue_probe,
			"presentation_reset": reset_audit,
			"presentation_reset_probe": reset_probe,
			"presentation_layout_green": presentation_layout_green,
		}
		_expect(
			transition_green,
			"1600x960 production collapse/expand and 480->1600 live resize remeasure cleanly"
		)
	var surface_debug := surface.call("debug_snapshot") as Dictionary
	var skill_debug := surface_debug.get("owner_skill_dock", {}) as Dictionary
	var military_debug := surface_debug.get("military_panel", {}) as Dictionary
	var population_green := (
		bool(surface_debug.get("viewer_is_owner", false))
		and int(skill_debug.get("skill_card_count", 0)) == 4
		and int(skill_debug.get("rendered_cost_pip_count", 0)) > 0
		and int(surface_debug.get("military_task_button_count", 0)) == 2
		and int(military_debug.get("option_menu_item_count", 0)) == 2
		and int(military_debug.get("invalid_option_count", 1)) == 0
		and int(military_debug.get("presentation_binding_failure_count", 1)) == 0
	)
	_expect(
		population_green,
		"%s production combat surface is populated with four owner skills and two military identities"
			% label
	)
	var open_button := _target_list_button(screen)
	_expect(open_button != null, "%s real target-list button exists" % label)
	var open_button_probe := {"green": false, "reason": "button_missing"}
	if open_button != null:
		open_button_probe = await _probe_scroll_target(
			root_scroll,
			open_button,
			false
		)
		_expect(
			bool(open_button_probe.get("green", false)),
			"%s target-list button reaches a real interaction anchor" % label
		)
		open_button.pressed.emit()
		await _settle_frames(4)
	var target_rail := screen.find_child(
		"V074VirtualizedTargetRail",
		true,
		false
	) as Control
	_expect(
		target_rail != null and target_rail.is_visible_in_tree(),
		"%s production target utility rail opens visibly" % label
	)
	root_scroll.scroll_horizontal = 0
	root_scroll.scroll_vertical = 0
	await _settle_frames(2)
	var target_rail_probe := (
		await _probe_scroll_target(root_scroll, target_rail)
		if target_rail != null
		else {"green": false, "reason": "target_rail_missing"}
	)
	var protected_probes := {}
	var protected_probe_green_count := 0
	var protected_targets := {
		"marker": screen.get_node(
			"PlaytestUtilityLayer/PlaytestSafeArea/V073PlaytestMarkerPanel"
		) as Control,
		"table": screen.get_node("RootMargin/Shell/TableArea") as Control,
		"planet": screen.get_node(
			"RootMargin/Shell/TableArea/PlanetBoard/PlanetRows/PlanetStageViewport"
		) as Control,
		"dock": screen.get_node("RootMargin/Shell/DockPanel") as Control,
		"asset": screen.get_node(
			"RootMargin/Shell/DockPanel/DockMargin/DockRows/DockHeader/AssetRail"
		) as Control,
	}
	for target_name in protected_targets:
		root_scroll.scroll_horizontal = 0
		root_scroll.scroll_vertical = 0
		await _settle_frames(2)
		var probe := await _probe_scroll_target(
			root_scroll,
			protected_targets.get(target_name) as Control
		)
		protected_probes[target_name] = probe
		if bool(probe.get("green", false)):
			protected_probe_green_count += 1
	var surface_probes := await _probe_populated_surface(surface, root_scroll)
	root_scroll.scroll_horizontal = 0
	root_scroll.scroll_vertical = 0
	await _settle_frames(2)
	screen.call("_resolve_combat_layout")
	await _settle_frames(4)
	var audit := screen.call("v075_responsive_geometry_audit") as Dictionary
	var runtime_size := Vector2i(screen.get_viewport_rect().size)
	var expected_mode := _expected_mode(requested_size.x)
	var case_green := (
		runtime_size == requested_size
		and str(audit.get("geometry_source", ""))
			== "instantiated_production_controls"
		and str(audit.get("layout_mode", "")) == expected_mode
		and bool(audit.get("panel_width_green", false))
		and bool(audit.get("combat_surface_content_origin_green", false))
		and _surface_measurement_green(audit)
		and _expected_surface_profile_green(label, audit)
		and bool(audit.get("root_scroll_disabled", false))
		and str(audit.get("panel_anchor", ""))
			== "single_table_right_sidebar"
		and population_green
		and bool(open_button_probe.get("green", false))
		and bool(target_rail_probe.get("green", false))
		and protected_probe_green_count == protected_targets.size()
		and bool(surface_probes.get("green", false))
		and transition_green
		and int(audit.get("panel_viewport_overflow_count", 1)) == 0
		and int(audit.get("panel_safe_area_overflow_count", 1)) == 0
		and int(audit.get("primary_planet_occlusion_count", 1)) == 0
		and int(audit.get("track_panel_overlap_count", 1)) == 0
		and int(audit.get("dock_panel_overlap_count", 1)) == 0
		and int(audit.get("asset_reserve_lane_overlap_count", 1)) == 0
		and bool(audit.get("utility_target_rail_visible", false))
		and bool(audit.get("utility_target_rail_parent_is_flow", false))
		and bool(audit.get("utility_target_rail_flow_index_green", false))
		and int(audit.get("utility_target_rail_overlap_count", 1)) == 0
		and bool(audit.get("utility_marker_visible", false))
		and bool(audit.get("utility_marker_parent_is_flow", false))
		and bool(audit.get("utility_marker_flow_index_green", false))
		and int(audit.get("utility_marker_offscreen_count", 1)) == 0
		and int(audit.get("utility_marker_overlap_count", 1)) == 0
		and int(audit.get("protected_surface_nonempty_count", 0))
			== int(audit.get("protected_surface_expected_count", -1))
		and int(audit.get("protected_surface_content_containment_count", 0))
			== int(audit.get("protected_surface_expected_count", -1))
		and int(audit.get("protected_surface_scroll_reachable_count", 0))
			== int(audit.get("protected_surface_expected_count", -1))
		and int(audit.get("ui_child_collision_count", 1)) == 0
	)
	_expect(
		runtime_size == requested_size,
		"%s runtime viewport exactly matches %s" % [label, requested_size]
	)
	_expect(
		str(audit.get("layout_mode", "")) == expected_mode,
		"%s resolves the expected %s layout" % [label, expected_mode]
	)
	_expect(
		bool(audit.get("panel_width_green", false))
			and int(audit.get("panel_viewport_overflow_count", 1)) == 0
			and int(audit.get("panel_safe_area_overflow_count", 1)) == 0,
		"%s combat panel uses actual safe width without overflow" % label
	)
	_expect(
		int(audit.get("primary_planet_occlusion_count", 1)) == 0
			and int(audit.get("track_panel_overlap_count", 1)) == 0
			and int(audit.get("dock_panel_overlap_count", 1)) == 0
			and int(audit.get("asset_reserve_lane_overlap_count", 1)) == 0,
		"%s actual planet, track, dock and asset lane remain unobstructed" % label
	)
	_expect(
		int(audit.get("ui_child_collision_count", 1)) == 0
			and bool(audit.get("root_scroll_disabled", false))
			and str(audit.get("panel_anchor", ""))
				== "single_table_right_sidebar",
		"%s child controls are collision-free on the fixed single-screen table"
			% label
	)
	_expect(
		bool(audit.get("utility_target_rail_visible", false))
			and bool(audit.get("utility_target_rail_parent_is_flow", false))
			and bool(audit.get("utility_target_rail_flow_index_green", false))
			and int(audit.get("utility_target_rail_overlap_count", 1)) == 0
			and bool(audit.get("utility_marker_visible", false))
			and bool(audit.get("utility_marker_parent_is_flow", false))
			and bool(audit.get("utility_marker_flow_index_green", false))
			and int(audit.get("utility_marker_offscreen_count", 1)) == 0
			and int(audit.get("utility_marker_overlap_count", 1)) == 0,
		"%s opened production utility rail and marker remain reachable and non-occluding"
			% label
	)
	_expect(
		protected_probe_green_count == protected_targets.size()
			and int(audit.get("protected_surface_nonempty_count", 0))
				== int(audit.get("protected_surface_expected_count", -1))
			and int(audit.get("protected_surface_content_containment_count", 0))
				== int(audit.get("protected_surface_expected_count", -1))
			and int(audit.get("protected_surface_scroll_reachable_count", 0))
				== int(audit.get("protected_surface_expected_count", -1)),
		"%s marker, table, planet, dock, asset and open utility rail are reachable without root scrolling"
			% label
	)
	_expect(
		bool(surface_probes.get("green", false)),
		"%s populated public, skill, military and last-skill controls are actively reachable"
			% label
	)
	_expect(
		bool(audit.get("combat_surface_content_origin_green", false)),
		"%s combat content starts at the real SurfaceHost scroll origin" % label
	)
	_expect(
		_surface_measurement_green(audit),
		"%s settled content minimum and SurfaceHost scroll range are coherent"
			% label
	)
	_expect(
		_expected_surface_profile_green(label, audit),
		"%s uses the expected real column and scrollbar profile" % label
	)
	var flow_bound := bool(
		(screen.call("combat_debug_snapshot") as Dictionary).get(
			"application_flow_bound",
			false
		)
	)
	_expect(flow_bound, "%s production application flow is bound" % label)
	var track_binding := _real_combat_track_binding(screen)
	_expect(
		bool(track_binding.get("green", false)),
		"%s real TrackCard binds its definition-resolved Texture2D" % label
	)
	if bool(track_binding.get("green", false)):
		_real_combat_track_binding_count += 1
	_rows.append({
		"label": label,
		"requested_size": requested_size,
		"runtime_size": runtime_size,
		"layout_mode": str(audit.get("layout_mode", "")),
		"panel_rect": audit.get("panel_rect", Rect2()),
		"private_grid_columns": int(
			audit.get("private_grid_columns", 0)
		),
		"green": case_green,
		"track_binding": track_binding,
		"population_green": population_green,
		"open_button_probe": open_button_probe,
		"target_rail_probe": target_rail_probe,
		"protected_probes": protected_probes,
		"surface_probes": surface_probes,
		"transition_green": transition_green,
		"transition_audits": transition_audits,
		"surface_debug": surface_debug,
		"surface_rects": {
			"host": (surface.get_parent() as Control).get_global_rect(),
			"surface": surface.get_global_rect(),
			"rows": (surface.get_node("Rows") as Control).get_global_rect(),
			"public": (
				surface.get_node("Rows/PublicMonsterPanel") as Control
			).get_global_rect(),
		},
		"geometry_audit": audit,
	})
	if case_green:
		_green_cases += 1
	main.queue_free()
	await _settle_frames(2)


func _surface_measurement_green(audit: Dictionary) -> bool:
	var host_rect := audit.get(
		"combat_surface_host_rect",
		Rect2()
	) as Rect2
	var content_rect := audit.get(
		"combat_surface_content_rect",
		Rect2()
	) as Rect2
	var rows_minimum := float(audit.get(
		"combat_surface_rows_combined_minimum_height",
		0.0
	))
	var preferred_height := float(audit.get(
		"combat_surface_preferred_content_height",
		0.0
	))
	var vertical_range := float(audit.get(
		"combat_surface_host_vertical_scroll_range",
		0.0
	))
	var content_requires_scroll := (
		content_rect.size.y > host_rect.size.y + 0.5
	)
	return (
		host_rect.size.y > 0.5
		and content_rect.size.y > 0.5
		and preferred_height + 0.5 >= rows_minimum + 20.0
		and content_rect.size.y + 0.5 >= preferred_height
		and (not content_requires_scroll or vertical_range > 0.5)
	)


func _wide_surface_stable(audit: Dictionary) -> bool:
	var host_rect := audit.get(
		"combat_surface_host_rect",
		Rect2()
	) as Rect2
	var content_rect := audit.get(
		"combat_surface_content_rect",
		Rect2()
	) as Rect2
	return (
		_surface_measurement_green(audit)
		and int(audit.get("private_grid_columns", 0)) in [1, 2]
		and absf(content_rect.size.x - host_rect.size.x) <= 16.0
		and float(audit.get(
			"combat_surface_host_vertical_scroll_range",
			-1.0
		)) >= 0.0
		and int(audit.get("ui_child_collision_count", 1)) == 0
	)


func _expected_surface_profile_green(
	label: String,
	audit: Dictionary
) -> bool:
	var host_rect := audit.get(
		"combat_surface_host_rect",
		Rect2()
	) as Rect2
	var content_rect := audit.get(
		"combat_surface_content_rect",
		Rect2()
	) as Rect2
	var columns := int(audit.get("private_grid_columns", 0))
	var vertical_range := float(audit.get(
		"combat_surface_host_vertical_scroll_range",
		0.0
	))
	if label in ["width_480", "width_640", "width_660"]:
		return (
			columns == 1
			and content_rect.size.y > host_rect.size.y + 0.5
			and vertical_range > 0.5
		)
	if label == "1366x768":
		return (
			columns == 1
			and content_rect.size.y > host_rect.size.y + 0.5
			and vertical_range > 0.5
		)
	if label in ["1600x960", "1920x1080"]:
		return _wide_surface_stable(audit)
	return columns in [1, 2]


func _real_combat_track_binding(screen: Control) -> Dictionary:
	var rail := screen.get_node_or_null(
		"RootMargin/Shell/TrackPanel/TrackMargin/TrackRows/TrackScroll/TrackRail"
	)
	if rail == null:
		return {"green": false, "reason": "track_rail_missing"}
	for card_variant in rail.get_children():
		if not (card_variant is Control):
			continue
		var card := card_variant as Control
		if not card.has_method("payload"):
			continue
		var payload := card.call("payload") as Dictionary
		var definition_id := str(payload.get("card_definition_id", ""))
		var definition := V075CardDefinitionRegistry.definition(definition_id)
		var domain := V075CardDefinitionRegistry.card_domain(
			str(definition.get("card_type", ""))
		)
		if domain not in ["monster", "military"]:
			continue
		var descriptor := (
			V075CardDefinitionRegistry.presentation_descriptor(definition_id)
		)
		var expected := (
			V075CardDefinitionRegistry.presentation_texture(definition_id)
		)
		var actual: Texture2D = null
		for texture_node_variant in card.find_children(
			"*",
			"TextureRect",
			true,
			false
		):
			var texture_node := texture_node_variant as TextureRect
			if texture_node.texture != null:
				actual = texture_node.texture
				break
		var expected_path := str(descriptor.get("resource_path", ""))
		return {
			"green": (
				not descriptor.is_empty()
				and expected != null
				and actual == expected
				and str(actual.resource_path) == expected_path
			),
			"definition_id": definition_id,
			"domain": domain,
			"expected_path": expected_path,
			"actual_path": (
				str(actual.resource_path) if actual != null else ""
			),
		}
	return {"green": false, "reason": "combat_track_card_missing"}


func _target_list_button(screen: Control) -> Button:
	var target_rail := screen.get_node_or_null(
		"RootMargin/Shell/TargetPanel/TargetMargin/TargetRow/TargetScroll/TargetRail"
	)
	if target_rail == null:
		return null
	for child_variant in target_rail.get_children():
		if (
			child_variant is Button
			and (child_variant as Button).text.begins_with("目标列表")
		):
			return child_variant as Button
	return null


func _probe_populated_surface(
	surface: Control,
	root_scroll: ScrollContainer
) -> Dictionary:
	var host := surface.get_parent() as ScrollContainer
	var root_before := Vector2i(
		root_scroll.scroll_horizontal,
		root_scroll.scroll_vertical
	)
	var host_probe := await _probe_scroll_target(root_scroll, host, false)
	var targets := {
		"public_monster": surface.get_node("Rows/PublicMonsterPanel") as Control,
		"military_panel": surface.get_node("Rows/PrivateGrid/MilitaryPanel") as Control,
	}
	var probes := {}
	var green_count := 0
	for target_name in targets:
		host.scroll_horizontal = 0
		host.scroll_vertical = 0
		await _settle_frames(2)
		var probe := await _probe_scroll_target(
			host,
			targets.get(target_name) as Control
		)
		probes[target_name] = probe
		if bool(probe.get("green", false)):
			green_count += 1
	var skill_scroll := surface.get_node(
		"Rows/PrivateGrid/SkillDock/Margin/Rows/SkillScroll"
	) as ScrollContainer
	var skill_dock := surface.get_node("Rows/PrivateGrid/SkillDock") as Control
	host.scroll_horizontal = 0
	host.scroll_vertical = 0
	await _settle_frames(2)
	var skill_dock_probe := await _probe_scroll_target(host, skill_dock, false)
	var skill_cards := skill_scroll.get_node("SkillCards") as HBoxContainer
	var last_skill: Control = null
	if skill_cards.get_child_count() > 0:
		last_skill = skill_cards.get_child(skill_cards.get_child_count() - 1) as Control
	var last_skill_probe := (
		await _probe_scroll_target(skill_scroll, last_skill, false)
		if last_skill != null
		else {"green": false, "reason": "last_skill_missing"}
	)
	var nested_clip := _scroll_clip_rect(skill_scroll).intersection(
		_scroll_clip_rect(host)
	).intersection(_scroll_clip_rect(root_scroll))
	var nested_center_green := (
		last_skill != null
		and nested_clip.grow(1.0).has_point(last_skill.get_global_rect().get_center())
	)
	skill_scroll.scroll_horizontal = 0
	skill_scroll.scroll_vertical = 0
	host.scroll_horizontal = 0
	host.scroll_vertical = 0
	root_scroll.scroll_horizontal = root_before.x
	root_scroll.scroll_vertical = root_before.y
	await _settle_frames(2)
	return {
		"green": (
			bool(host_probe.get("green", false))
			and green_count == targets.size()
			and bool(skill_dock_probe.get("green", false))
			and bool(last_skill_probe.get("green", false))
			and nested_center_green
		),
		"host_probe": host_probe,
		"panel_probes": probes,
		"skill_dock_probe": skill_dock_probe,
		"last_skill_probe": last_skill_probe,
		"nested_clip": nested_clip,
		"nested_center_green": nested_center_green,
	}


func _probe_scroll_target(
	scroll: ScrollContainer,
	target: Control,
	restore: bool = true
) -> Dictionary:
	if (
		not is_instance_valid(scroll)
		or not is_instance_valid(target)
		or not target.is_visible_in_tree()
	):
		return {"green": false, "reason": "target_not_visible"}
	var target_is_scroll_descendant := scroll.is_ancestor_of(target)
	var target_rect := target.get_global_rect()
	if target_rect.size.x <= 0.5 or target_rect.size.y <= 0.5:
		return {"green": false, "reason": "target_rect_empty"}
	var before := Vector2(
		float(scroll.scroll_horizontal),
		float(scroll.scroll_vertical)
	)
	var clip_before := _scroll_clip_rect(scroll)
	var center_before := target_rect.get_center()
	var initially_inside := clip_before.grow(1.0).has_point(center_before)
	var horizontal_bar := scroll.get_h_scroll_bar()
	var vertical_bar := scroll.get_v_scroll_bar()
	var horizontal_range := maxf(
		0.0,
		horizontal_bar.max_value - horizontal_bar.page
	)
	var vertical_range := maxf(
		0.0,
		vertical_bar.max_value - vertical_bar.page
	)
	if target_is_scroll_descendant:
		scroll.ensure_control_visible(target)
		await _settle_frames(2)
	var clip_after := _scroll_clip_rect(scroll)
	var center_after := target.get_global_rect().get_center()
	if not clip_after.grow(1.0).has_point(center_after):
		var clip_center := clip_after.get_center()
		scroll.scroll_horizontal = int(round(clampf(
			float(scroll.scroll_horizontal) + center_after.x - clip_center.x,
			0.0,
			horizontal_range
		)))
		scroll.scroll_vertical = int(round(clampf(
			float(scroll.scroll_vertical) + center_after.y - clip_center.y,
			0.0,
			vertical_range
		)))
		await _settle_frames(2)
		clip_after = _scroll_clip_rect(scroll)
		center_after = target.get_global_rect().get_center()
	var after := Vector2(
		float(scroll.scroll_horizontal),
		float(scroll.scroll_vertical)
	)
	var intersection := clip_after.intersection(target.get_global_rect())
	var meaningful_intersection := (
		intersection.size.x >= minf(24.0, target.get_global_rect().size.x)
		and intersection.size.y >= minf(24.0, target.get_global_rect().size.y)
	)
	var moved_when_required := (
		initially_inside
		or (
			(horizontal_range > 0.0 or vertical_range > 0.0)
			and before.distance_to(after) > 0.5
		)
	)
	var green := (
		clip_after.grow(1.0).has_point(center_after)
		and meaningful_intersection
		and moved_when_required
	)
	var result := {
		"green": green,
		"target_path": str(scroll.get_path_to(target)),
		"target_is_scroll_descendant": target_is_scroll_descendant,
		"before_scroll": before,
		"after_scroll": after,
		"horizontal_range": horizontal_range,
		"vertical_range": vertical_range,
		"initially_inside": initially_inside,
		"center_after": center_after,
		"clip_after": clip_after,
		"meaningful_intersection": meaningful_intersection,
		"moved_when_required": moved_when_required,
	}
	if restore:
		scroll.scroll_horizontal = int(round(before.x))
		scroll.scroll_vertical = int(round(before.y))
		await _settle_frames(2)
	return result


func _scroll_clip_rect(scroll: ScrollContainer) -> Rect2:
	var clip := scroll.get_global_rect()
	var vertical_bar := scroll.get_v_scroll_bar()
	var horizontal_bar := scroll.get_h_scroll_bar()
	if vertical_bar.is_visible_in_tree():
		clip.size.x = maxf(0.0, clip.size.x - vertical_bar.size.x)
	if horizontal_bar.is_visible_in_tree():
		clip.size.y = maxf(0.0, clip.size.y - horizontal_bar.size.y)
	return clip


func _expected_mode(width: int) -> String:
	if width < 720:
		return "NARROW"
	if width < 1480:
		return "COMPACT"
	return "REGULAR"


func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_args():
		var text := str(argument)
		if text.begins_with("%s=" % prefix):
			return text.trim_prefix("%s=" % prefix)
	return ""


func _settle_frames(count: int) -> void:
	for _index in range(count):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _finish(case_count: int) -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("V075_RESPONSIVE_VIEWPORT_MATRIX_TEST|%s" % JSON.stringify({
		"status": status,
		"cases": case_count,
		"green_cases": _green_cases,
		"checks": _checks,
		"failures": _failures,
		"rows": _rows,
	}))
	quit(0 if _failures.is_empty() else 1)
