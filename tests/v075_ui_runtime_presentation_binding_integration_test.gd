extends SceneTree

const ScreenScene := preload(
	"res://scenes/ui/v075/V075SampleGameScreen.tscn"
)
const RuntimeOwner := preload(
	"res://scripts/v075_runtime/v075_runtime_owner.gd"
)
const CombatOwner := preload(
	"res://scripts/v075/runtime/v075_combat_runtime_owner.gd"
)
const ProjectionAdapter := preload(
	"res://scripts/v075/player/v075_combat_projection_adapter.gd"
)
const ResponsiveLayout := preload(
	"res://scripts/ui/v074/v074_responsive_table_layout.gd"
)
const Bench := preload(
	"res://scripts/tools/v075/v075_combat_player_surface_bench.gd"
)
const EXPECTED_MILITARY_TASKS := [
	"assault_region",
	"assault_monster",
]
const COMBAT_SURFACE_PATH := (
	"PlaytestUtilityLayer/PlaytestSafeArea/V075CombatOverlay/"
	+ "Margin/Rows/SurfaceHost/CombatSurface"
)


class FlowHarness:
	extends Node

	var _intent_sequence := 0

	func issue_intent(
		intent_kind: String,
		parameters: Dictionary = {}
	) -> Dictionary:
		_intent_sequence += 1
		return {
			"schema": "V075ApplicationIntentV1",
			"intent_id": "ui.integration.%03d" % _intent_sequence,
			"intent_kind": intent_kind,
			"ruleset_id": "v0.7.5",
			"parameters": parameters.duplicate(true),
		}

	func debug_snapshot() -> Dictionary:
		return {"runtime": {}}


var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var flow := FlowHarness.new()
	flow.name = "V075RuntimeCompositionHarness"
	var runtime := RuntimeOwner.new() as Node
	runtime.name = "V074RuntimeOwner"
	var combat := CombatOwner.new() as Node
	combat.name = "V075CombatRuntimeOwner"
	flow.add_child(runtime)
	flow.add_child(combat)
	root.add_child(flow)
	await process_frame

	var bound := runtime.call("bind_combat_owner", combat) as Dictionary
	_expect(
		bool(bound.get("accepted", false)),
		"real runtime binds the real combat owner"
	)
	var shared_consumer := runtime.call(
		"combat_presentation_consumer"
	) as Node
	_expect(
		is_instance_valid(shared_consumer),
		"runtime creates its authoritative presentation consumer"
	)

	var screen := ScreenScene.instantiate() as V075SampleGameScreen
	root.add_child(screen)
	await process_frame
	screen.bind_application_flow(
		flow,
		{
			"ruleset_id": "v0.7.5",
			"viewer_player_id": "player.local",
		},
		{
			"combat": {
				"private_skill_intent_kind":
					"combat.monster_private_skill.request",
				"military_intent_kind":
					"combat.military_mission.select",
			},
		}
	)
	await process_frame

	var fixed_seed_track_item := {
		"card_kind": "normal_card",
		"card_definition_id":
			"military.submarine_fleet.life.rank_1",
		"instance_id": "track.900626424.local.05",
		"local_slot_index": 5,
		"primary_color": "life",
	}
	var fixed_card_audit := screen.call(
		"v075_card_presentation_audit",
		fixed_seed_track_item
	) as Dictionary
	_expect(
		int(fixed_card_audit.get("local_slot_index", -1)) == 5
			and str(
				fixed_card_audit.get("card_definition_id", "")
			) == "military.submarine_fleet.life.rank_1",
		"fixed seed 900626424 segment index 5 remains the authoritative military instance"
	)
	_expect(
		str(fixed_card_audit.get("domain", "")) == "military"
			and str(fixed_card_audit.get("card_type", "")) ==
				"military.submarine_fleet"
			and str(fixed_card_audit.get("type_label", "")) == "军队"
			and str(fixed_card_audit.get("type_label", "")) != "工厂",
		"V075 registry renders the fixed combat card as military, not facility"
	)
	_expect(
		bool(fixed_card_audit.get("art_present", false))
			and bool(
				fixed_card_audit.get("combat_art_mapping_green", false)
			)
			and not bool(
				fixed_card_audit.get("uses_facility_art", true)
			)
			and str(
				fixed_card_audit.get("stable_mapping_path", "")
			).ends_with("spaceship.svg"),
		"fixed military card uses recognizable stable combat art, not facility art"
	)

	var layout_resolver := ResponsiveLayout.new()
	for layout_case in [
		{"label": "1366x768", "size": Vector2(1366.0, 768.0)},
		{"label": "1600x960", "size": Vector2(1600.0, 960.0)},
		{"label": "1920x1080", "size": Vector2(1920.0, 1080.0)},
	]:
		var layout_size := layout_case.get("size", Vector2.ZERO) as Vector2
		var layout_profile := layout_resolver.resolve_for_window(
			layout_size,
			layout_size,
			4
		)
		var combat_layout := screen.call(
			"v075_combat_layout_for_geometry",
			layout_size,
			layout_profile.get("table_rect", Rect2()),
			layout_profile.get("planet_rect", Rect2()),
			layout_profile.get("hand_dock_rect", Rect2())
		) as Dictionary
		var panel_rect := combat_layout.get(
			"panel_rect",
			Rect2()
		) as Rect2
		var layout_label := str(layout_case.get("label", "resolution"))
		_expect(
			int(
				combat_layout.get(
					"panel_viewport_overflow_count",
					1
				)
			) == 0
				and bool(
					combat_layout.get("panel_min_width_green", false)
				),
			"%s combat panel stays in-bounds with compact width" % layout_label
		)
		_expect(
			str(combat_layout.get("panel_anchor", "")) ==
				"left_utility_lane"
				and int(
					combat_layout.get(
						"primary_planet_occlusion_count",
						1
					)
				) == 0
				and int(
					combat_layout.get(
						"planet_right_half_occlusion_count",
						1
					)
				) == 0,
			"%s combat panel leaves the planet operation core and right half clear"
				% layout_label
		)
		_expect(
			panel_rect.size.x >= 480.0
				and panel_rect.size.y >= 300.0
				and bool(
					combat_layout.get(
						"two_column_information_contract",
						""
					) == "preserved"
				)
				and bool(
					combat_layout.get(
						"track_and_asset_surfaces_untouched",
						false
					)
				),
			"%s keeps the two-column information contract and existing track/Pip surfaces"
				% layout_label
		)

	var screen_debug := screen.combat_debug_snapshot()
	_expect(
		str(screen_debug.get("presentation_source_mode", ""))
			== "runtime_shared"
			and int(
				screen_debug.get(
					"presentation_shared_consumer_count",
					0
				)
			) == 1
			and int(
				screen_debug.get(
					"presentation_local_preview_consumer_count",
					-1
				)
			) == 0,
		"production screen binds one runtime-shared consumer"
	)
	_expect(
		int(
			screen_debug.get(
				"presentation_consumer_instance_id",
				0
			)
		) == shared_consumer.get_instance_id()
			and bool(
				screen_debug.get(
					"presentation_shared_identity_green",
					false
				)
			)
			and int(
				screen_debug.get(
					"presentation_signal_connection_count",
					0
				)
			) == 1,
		"screen and runtime share the same consumer identity"
	)

	var authority := Bench.make_authority_snapshot()
	var adapter := ProjectionAdapter.new()
	var owner_projection := adapter.project_for_viewer(
		authority,
		"player.local"
	)
	screen.apply_combat_projection(
		owner_projection,
		"monster.tech.local.01"
	)
	await process_frame
	var owner_debug := screen.combat_debug_snapshot()
	var owner_surface := owner_debug.get("surface", {}) as Dictionary
	var owner_dock := (
		owner_surface.get("owner_skill_dock", {}) as Dictionary
	)
	var military_debug := (
		owner_surface.get("military_panel", {}) as Dictionary
	)
	_expect(
		bool(owner_surface.get("viewer_is_owner", false))
			and bool(owner_dock.get("visible", false))
			and int(owner_dock.get("skill_card_count", 0)) == 4,
		"owner sees the private monster skill dock"
	)
	_expect(
		int(owner_surface.get("public_skill_card_disclosure_count", 1))
			== 0,
		"public monster surface discloses no private skill card"
	)
	_expect(
		int(owner_surface.get("military_task_button_count", 0)) == 2
			and _string_values(
				owner_surface.get("military_task_kinds", []) as Array
			) == EXPECTED_MILITARY_TASKS
			and int(owner_surface.get("military_guard_ui_count", 1)) == 0
			and int(
				owner_surface.get(
					"military_bound_action_ui_count",
					1
				)
			) == 0
			and int(
				owner_surface.get(
					"special_support_placeholder_count",
					1
				)
			) == 0
			and int(military_debug.get("task_button_count", 0)) == 2,
		"military UI contains only two one-shot assault tasks"
	)
	_expect(
		int(military_debug.get("option_menu_item_count", 0)) == 2
			and str(
				(military_debug.get("selected_option_ids", {}) as Dictionary).get(
					"assault_region", ""
				)
			) == "option.military.region.local"
			and str(
				(military_debug.get("selected_option_ids", {}) as Dictionary).get(
					"assault_monster", ""
				)
			) == "option.military.monster.local",
		"military controls retain complete prebound option identities"
	)

	var surface := screen.get_node(COMBAT_SURFACE_PATH) as Control
	var surface_node := surface as V075CombatPlayerSurface
	var selected_military: Array[Dictionary] = []
	surface_node.military_mission_selected.connect(
		func(option: Dictionary) -> void:
			selected_military.append(option.duplicate(true))
	)
	var military_panel := surface_node.get_node(
		"Rows/PrivateGrid/MilitaryPanel"
	) as V075MilitaryMissionPanel
	var region_option: Dictionary = {}
	for option_variant in owner_projection.get(
		"military_task_options",
		[]
	) as Array:
		if (
			option_variant is Dictionary
			and str((option_variant as Dictionary).get("task_kind", ""))
				== "assault_region"
		):
			region_option = (option_variant as Dictionary).duplicate(true)
			break
	var alternate_region := region_option.duplicate(true)
	alternate_region["option_id"] = "option.military.region.alternate"
	alternate_region["target_slot_id"] = "combat.military.assault_region.region.19"
	alternate_region["target_region_id"] = "region.19"
	military_panel.configure(
		[
			region_option.duplicate(true),
			alternate_region,
			(owner_projection.get("military_task_options", []) as Array)[1],
		],
		true
	)
	var alternate_selected := military_panel.select_option_id(
			"assault_region",
			"option.military.region.alternate"
		)
	var stale_selected := military_panel.select_option_id(
		"assault_region",
		"option.military.region.stale"
	)
	_expect(
		alternate_selected
			and not stale_selected
			and str(
				(military_panel.debug_snapshot().get(
					"selected_option_ids", {}
				) as Dictionary).get("assault_region", "")
			) == "option.military.region.alternate",
		"military option selector rejects stale identity and preserves selected DTO"
	)
	var region_button := military_panel.get_node(
		"Margin/Rows/TaskButtons/AssaultRegionButton"
	) as Button
	region_button.emit_signal("pressed")
	_expect(
		selected_military.size() == 1
			and str(selected_military[0].get("option_id", ""))
				== "option.military.region.alternate"
			and str(selected_military[0].get("target_region_id", ""))
				== "region.19",
		"military button submits the selected option without a first-card fallback"
	)
	var geometry := surface_node.debug_geometry_audit()
	_expect(
		int(geometry.get("unintended_overlap_count", 1)) == 0
			and int(geometry.get("outside_surface_count", 1)) == 0,
		"owner combat surface child rectangles do not overlap or escape"
	)
	var rival_projection := adapter.project_for_viewer(
		authority,
		"player.rival"
	)

	screen.apply_combat_projection(
		owner_projection,
		"monster.industry.ai.02"
	)
	await process_frame
	var rival_monster_surface := (
		screen.combat_debug_snapshot().get("surface", {}) as Dictionary
	)
	_expect(
		not bool(rival_monster_surface.get("viewer_is_owner", true))
			and bool(rival_monster_surface.get("viewer_can_submit_military", false))
			and bool(
				(rival_monster_surface.get("military_panel", {}) as Dictionary).get(
					"visible", false
				)
			),
		"owner retains military controls while inspecting a rival monster"
	)
	screen.apply_combat_projection(
		rival_projection,
		"monster.tech.local.01"
	)
	await process_frame
	var rival_private_surface := (
		screen.combat_debug_snapshot().get("surface", {}) as Dictionary
	)
	_expect(
		not bool(rival_private_surface.get("viewer_can_submit_military", true))
			and not bool(
				(rival_private_surface.get("military_panel", {}) as Dictionary).get(
					"visible", true
				)
			),
		"rival projection fails closed for private military controls"
	)
	_expect(
		_count_surface_tokens(
			surface,
			[
				"special.support",
				"战术支援",
				"guard_region",
				"protect_region",
				"defend_region",
				"intercept_region",
				"保护地区",
				"bound action",
			]
		) == 0,
		"combat surface has no placeholder guard or bound-action UI"
	)

	screen.apply_combat_projection(
		rival_projection,
		"monster.tech.local.01"
	)
	await process_frame
	var rival_surface := (
		screen.combat_debug_snapshot().get("surface", {}) as Dictionary
	)
	var rival_dock := (
		rival_surface.get("owner_skill_dock", {}) as Dictionary
	)
	_expect(
		not bool(rival_surface.get("viewer_is_owner", true))
			and not bool(rival_dock.get("visible", true))
			and int(rival_dock.get("skill_card_count", 1)) == 0
			and int(
				rival_surface.get(
					"public_skill_card_disclosure_count",
					1
				)
			) == 0,
		"rival sees the monster but no private skills costs or cooldowns"
	)
	_expect(
		bool(rival_surface.get("public_monster_visible", false)),
		"rival retains the public monster presentation"
	)

	var receipt := {
		"ruleset_id": "v0.7.5",
		"combat_receipt_id": "ui.runtime.presentation.001",
		"event_kind": "monster_private_skill_resolved",
		"public_effect_id": "effect.public.ui.integration",
		"source_rank": 4,
		"preferred_industry_color": "technology",
		"target_kind": "region",
		"target_region_id": "region.14",
		"damage_amount": 7,
		"public_summary": "Public combat effect resolved",
		"skill_definition_id": "skill.owner.only",
		"asset_cost_by_color": {"technology": 3},
		"cooldown_remaining_batches": 2,
		"future_skill_target": "facility.hidden.future",
	}
	var receipt_before := receipt.duplicate(true)
	runtime.emit_signal(
		"resolution_presented",
		receipt.duplicate(true)
	)
	await process_frame

	var consumer_debug := shared_consumer.call(
		"debug_snapshot"
	) as Dictionary
	var cue_surface := (
		screen.combat_debug_snapshot().get("surface", {}) as Dictionary
	)
	var cues := shared_consumer.call("recent_cues", 8) as Array
	_expect(
		int(consumer_debug.get("applied_receipt_count", 0)) == 1
			and int(
				consumer_debug.get("duplicate_receipt_count", 0)
			) == 0
			and cues.size() == 1,
		"one runtime receipt creates one authoritative cue"
	)
	_expect(
		int(cue_surface.get("presentation_cue_applied_count", 0)) == 1
			and int(
				cue_surface.get(
					"presentation_cue_duplicate_count",
					-1
				)
			) == 0
			and int(
				cue_surface.get(
					"presentation_cue_rejected_count",
					-1
				)
			) == 0,
		"screen displays the shared cue exactly once"
	)
	var public_cue := cues[0] as Dictionary if not cues.is_empty() else {}
	_expect(
		not _contains_key(public_cue, "skill_definition_id")
			and not _contains_key(public_cue, "asset_cost_by_color")
			and not _contains_key(
				public_cue,
				"cooldown_remaining_batches"
			)
			and not _contains_key(public_cue, "future_skill_target"),
		"shared public cue strips every private skill field"
	)

	var forwarded := screen.apply_combat_receipt(receipt)
	await process_frame
	screen_debug = screen.combat_debug_snapshot()
	consumer_debug = shared_consumer.call("debug_snapshot") as Dictionary
	cue_surface = screen_debug.get("surface", {}) as Dictionary
	_expect(
		bool(forwarded.get("applied", false))
			and bool(forwarded.get("consume_suppressed", false))
			and str(forwarded.get("reason_code", ""))
				== "combat_presentation_runtime_shared_acknowledged",
		"screen acknowledges forwarded receipt without consuming it again"
	)
	_expect(
		int(consumer_debug.get("applied_receipt_count", 0)) == 1
			and int(
				consumer_debug.get("duplicate_receipt_count", 0)
			) == 0
			and int(
				screen_debug.get(
					"presentation_suppressed_duplicate_consume_count",
					0
				)
			) == 1
			and int(
				cue_surface.get(
					"presentation_cue_applied_count",
					0
				)
			) == 1
			and int(
				cue_surface.get(
					"presentation_cue_duplicate_count",
					-1
				)
			) == 0,
		"receipt forwarding leaves both exact-once journals unchanged"
	)
	_expect(
		receipt == receipt_before
			and int(screen_debug.get("gameplay_mutation_count", -1)) == 0
			and int(screen_debug.get("rng_draw_delta", -1)) == 0
			and int(
				cue_surface.get(
					"presentation_gameplay_mutation_count",
					-1
				)
			) == 0
			and int(
				cue_surface.get(
					"presentation_rng_draw_delta",
					-1
				)
			) == 0,
		"UI binding has zero gameplay RNG or receipt mutation"
	)

	screen.queue_free()
	flow.queue_free()
	_finish()


func _string_values(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(str(value))
	return result


func _count_surface_tokens(
	node: Node,
	fragments: Array
) -> int:
	var searchable := node.name.to_lower()
	if node is Label:
		searchable += " " + (node as Label).text.to_lower()
	elif node is BaseButton:
		searchable += " " + (node as BaseButton).text.to_lower()
	if node is Control:
		searchable += " " + (node as Control).tooltip_text.to_lower()
	var count := 0
	for fragment_variant in fragments:
		if str(fragment_variant).to_lower() in searchable:
			count += 1
	for child_variant in node.get_children():
		if child_variant is Node:
			count += _count_surface_tokens(
				child_variant as Node,
				fragments
			)
	return count


func _contains_key(value: Variant, expected: String) -> bool:
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary.keys():
			if str(key_variant) == expected:
				return true
			if _contains_key(dictionary.get(key_variant), expected):
				return true
	elif value is Array:
		for child_variant in value as Array:
			if _contains_key(child_variant, expected):
				return true
	return false


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print(
		"V075_UI_RUNTIME_PRESENTATION_BINDING_INTEGRATION_TEST|%s"
		% JSON.stringify({
			"status": "PASS" if _failures.is_empty() else "FAIL",
			"passed": _checks - _failures.size(),
			"total": _checks,
			"failures": _failures,
			"shared_consumer_count": (
				1 if _failures.is_empty() else -1
			),
			"local_preview_consumer_count": (
				0 if _failures.is_empty() else -1
			),
			"duplicate_display_count": (
				0 if _failures.is_empty() else -1
			),
			"gameplay_mutation_count": (
				0 if _failures.is_empty() else -1
			),
			"rng_draw_delta": (
				0 if _failures.is_empty() else -1
			),
		})
	)
	quit(0 if _failures.is_empty() else 1)
