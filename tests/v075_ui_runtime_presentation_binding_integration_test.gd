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
const PresentationIdentity := preload(
	"res://scripts/v075/presentation/v075_presentation_receipt_identity_v2.gd"
)
const ProjectionAdapter := preload(
	"res://scripts/v075/player/v075_combat_projection_adapter.gd"
)
const V075CardDefinitionRegistry := preload(
	"res://scripts/v075/cards/v075_card_definition_registry.gd"
)
const PresentationCatalog := preload(
	"res://resources/presentation/alpha01_card_illustration_catalog.tres"
)
const Bench := preload(
	"res://scripts/tools/v075/v075_combat_player_surface_bench.gd"
)
const EXPECTED_MILITARY_TASKS := [
	"assault_region",
	"assault_monster",
]
const COMBAT_SURFACE_PATH := (
	"RootMargin/Shell/V075CombatStackHost/V075CombatOverlay/"
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
	runtime.name = "V075RuntimeOwner"
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
	var application_intents: Array[Dictionary] = []
	screen.application_intent_requested.connect(func(intent: Dictionary) -> void:
		application_intents.append(intent.duplicate(true))
	)
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
			).ends_with("mothkaiju_npc_tank.png"),
		"fixed military card uses recognizable stable combat art, not facility art"
	)

	screen.call("_toggle_combat_surface")
	await process_frame
	await process_frame
	var combat_layout := screen.call(
		"v075_responsive_geometry_audit"
	) as Dictionary
	_expect(
		str(combat_layout.get("geometry_source", ""))
			== "instantiated_production_controls"
			and str(combat_layout.get("panel_anchor", ""))
				== "production_flow_stack"
			and bool(combat_layout.get("root_scroll_accessible", false)),
		"combat geometry comes from the instantiated flow layout and accessible root scroll"
	)
	_expect(
		int(combat_layout.get("panel_viewport_overflow_count", 1)) == 0
			and int(combat_layout.get("panel_safe_area_overflow_count", 1)) == 0
			and bool(combat_layout.get("panel_width_green", false)),
		"combat panel actual rect stays inside the runtime viewport and safe area"
	)
	_expect(
		int(combat_layout.get("primary_planet_occlusion_count", 1)) == 0
			and int(combat_layout.get("asset_reserve_lane_overlap_count", 1)) == 0
			and int(combat_layout.get("track_panel_overlap_count", 1)) == 0
			and int(combat_layout.get("dock_panel_overlap_count", 1)) == 0
			and int(combat_layout.get("ui_child_collision_count", 1)) == 0,
		"actual combat, planet, track, dock, asset and child rects are collision-free"
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
			).is_empty()
			and str(
				(military_debug.get("selected_option_ids", {}) as Dictionary).get(
					"assault_monster", ""
				)
			).is_empty(),
		"military controls expose candidates without auto-selecting the first identity"
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
		selected_military.is_empty(),
		"surface rejects a panel option absent from the current projection"
	)
	surface_node.apply_projection(owner_projection, "monster.tech.local.01")
	await process_frame
	var canonical_region_selected := military_panel.select_option_id(
		"assault_region",
		"option.military.region.local"
	)
	var region_descriptor := (
		V075CardDefinitionRegistry.presentation_descriptor(
			str(region_option.get("card_definition_id", ""))
		)
	)
	var region_texture := (
		V075CardDefinitionRegistry.presentation_texture(
			str(region_option.get("card_definition_id", ""))
		)
	)
	var region_menu := military_panel.get_node(
		"Margin/Rows/TargetMenus/AssaultRegionOption"
	) as OptionButton
	var selected_region_index := region_menu.selected
	var selected_region_icon := (
		region_menu.get_item_icon(selected_region_index)
		if selected_region_index >= 0
		else null
	)
	var presentation_debug := military_panel.debug_snapshot()
	var region_button_binding := (
		(presentation_debug.get(
			"button_presentation_bindings",
			{}
		) as Dictionary).get("assault_region", {}) as Dictionary
	)
	_expect(
		canonical_region_selected
			and not region_descriptor.is_empty()
			and region_texture != null
			and selected_region_icon == region_texture
			and region_button.icon == region_texture
			and str(region_button_binding.get("card_definition_id", ""))
				== str(region_option.get("card_definition_id", ""))
			and str(region_button_binding.get("resource_path", ""))
				== str(region_descriptor.get("resource_path", ""))
			and int(
				presentation_debug.get(
					"presentation_binding_failure_count",
					1
				)
			) == 0,
		"military menu item and selected task button bind the exact card-definition Texture2D"
	)
	var skill_dock := surface_node.get_node(
		"Rows/PrivateGrid/SkillDock"
	) as Control
	var skill_cost_pip_count := 0
	var skill_cost_pip_binding_failure_count := 0
	for pip_variant in skill_dock.find_children("*", "TextureRect", true, false):
		var pip := pip_variant as TextureRect
		var asset_key := str(pip.get_meta("stable_asset_key", ""))
		if not asset_key.begins_with("icon.asset."):
			continue
		skill_cost_pip_count += 1
		var expected_pip := PresentationCatalog.resource_for_asset_key(
			StringName(asset_key)
		) as Texture2D
		if expected_pip == null or pip.texture != expected_pip:
			skill_cost_pip_binding_failure_count += 1
	_expect(
		skill_cost_pip_count > 0
			and skill_cost_pip_binding_failure_count == 0,
		"owner SkillDock cost pips bind their catalog-resolved Texture2D resources"
	)
	region_button.emit_signal("pressed")
	_expect(
		canonical_region_selected
		and selected_military.size() == 1
		and str(selected_military[0].get("option_id", ""))
			== "option.military.region.local"
		and str((selected_military[0].get(
			"card_action_binding",
			{}
		) as Dictionary).get("binding_fingerprint", "")).length() == 64,
		"explicit current military identity submits with its exact DBG binding"
	)
	var next_lifecycle_region := region_option.duplicate(true)
	var next_lifecycle_binding := (
		next_lifecycle_region.get("card_action_binding", {}) as Dictionary
	).duplicate(true)
	next_lifecycle_binding["zone_revision"] = int(
		next_lifecycle_binding.get("zone_revision", 0)
	) + 1
	next_lifecycle_binding["binding_fingerprint"] = (
		"next-lifecycle-binding"
	).sha256_text()
	next_lifecycle_region["card_action_binding"] = next_lifecycle_binding
	military_panel.configure([next_lifecycle_region], true)
	var stale_reconfigure_debug := military_panel.debug_snapshot()
	region_button.emit_signal("pressed")
	_expect(
		str((stale_reconfigure_debug.get(
			"selected_option_ids",
			{}
		) as Dictionary).get("assault_region", "")).is_empty()
		and region_button.disabled
		and selected_military.size() == 1,
		"lifecycle binding change clears stale selection without choosing the first candidate"
	)
	surface_node.apply_projection(owner_projection, "monster.tech.local.01")
	await process_frame
	var geometry := surface_node.debug_geometry_audit()
	_expect(
		int(geometry.get("unintended_overlap_count", 1)) == 0
			and int(geometry.get("outside_surface_count", 1)) == 0,
		"owner combat surface child rectangles do not overlap or escape"
	)
	var rival_projection := adapter.project_for_viewer(
		authority,
		"player.ai.1"
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
	var intents_before_hostile_projection := application_intents.size()
	screen.apply_combat_projection(
		rival_projection,
		"monster.industry.ai.02"
	)
	await process_frame
	var rival_private_surface := (
		screen.combat_debug_snapshot().get("surface", {}) as Dictionary
	)
	_expect(
		not bool(rival_private_surface.get("viewer_can_submit_military", true))
			and not bool(rival_private_surface.get("public_monster_visible", true))
			and not bool(
				(rival_private_surface.get("military_panel", {}) as Dictionary).get(
					"visible", true
				)
			),
		"authenticated screen rejects a rival-owned projection in full"
	)
	var hostile_request := {
		"source_instance_id": "monster.industry.ai.02",
		"source_generation": 2,
		"skill_definition_id": "skill.industry.orc.l1",
		"target_binding": {
			"target_kind": "facility",
			"target_id": "warehouse.14.technology",
			"target_facility_id": "warehouse.14.technology",
			"target_facility_generation": 1,
		},
		"target_contract": {"target_kind": "enemy_public_facility"},
	}
	surface_node.private_target_selection_requested.emit(hostile_request)
	await process_frame
	_expect(
		application_intents.size() == intents_before_hostile_projection,
		"rival private DTO produces no application submission"
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

	var stale_owner_projection := owner_projection.duplicate(true)
	var stale_owner_source := (
		(stale_owner_projection.get(
			"own_monster_skill_sources",
			[]
		) as Array)[0] as Dictionary
	)
	stale_owner_source["source_generation"] = 3
	screen.apply_combat_projection(
		stale_owner_projection,
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
		"same-owner stale-generation DTO displays no skills costs or cooldowns"
	)
	_expect(
		not bool(rival_surface.get("public_monster_visible", true))
		and application_intents.size() == intents_before_hostile_projection,
		"stale DTO is rejected in full and produces no submission"
	)
	screen.apply_combat_projection(
		owner_projection,
		"monster.tech.local.01"
	)
	await process_frame

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
	var v2_receipt := PresentationIdentity.build_public(
		"ui.runtime.presentation.001",
		PresentationIdentity.source_fingerprint(
			"ui.runtime.presentation.001",
			receipt
		),
		0,
		"monster_private_skill_resolved",
		0,
		"v0.7.5",
		"session.ui.runtime.presentation.integration",
		receipt
	)
	runtime.emit_signal(
		"combat_presentation_receipt_ready",
		v2_receipt.duplicate(true)
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
	_expect(
		str(public_cue.get("audience_scope", "")) == "PUBLIC"
			and str(public_cue.get("source_receipt_id", ""))
				== "ui.runtime.presentation.001"
			and str(public_cue.get("canonical_payload_fingerprint", "")).length()
				== 64,
		"shared public cue carries sealed V2 lineage, audience and fingerprint"
	)
	var observer_only_variant := public_cue.duplicate(true)
	observer_only_variant["observer_correlation_id"] = (
		"observer.presentation.transport.changed"
	)
	observer_only_variant["observer_correlation_fingerprint"] = (
		"observer-metadata-not-a-surface-identity"
	)
	var observer_only_replay := surface_node.show_presentation_cue(
		observer_only_variant
	)
	var observer_surface_debug := surface_node.debug_snapshot()
	_expect(
		str(observer_only_replay.get("reason_code", ""))
			== "presentation_cue_duplicate"
			and int(observer_surface_debug.get(
				"presentation_cue_collision_count",
				-1
			)) == 0,
		"observer correlation cannot become a downstream cue identity dialect"
	)

	var runtime_before_publish := runtime.call("debug_snapshot") as Dictionary
	var consumer_before_publish := shared_consumer.call(
		"debug_snapshot"
	) as Dictionary
	var screen_before_publish := screen.combat_debug_snapshot()
	var surface_before_publish := (
		screen_before_publish.get("surface", {}) as Dictionary
	)
	_expect(
		int(screen_before_publish.get("receipt_count", -1)) == 0
		and int(screen_before_publish.get("receipt_applied_count", -1)) == 0
		and int(screen_before_publish.get("receipt_rejected_count", -1)) == 0
		and int(screen_before_publish.get(
			"presentation_suppressed_duplicate_consume_count",
			-1
		)) == 0,
		"production shared presentation starts with zero direct screen receipts"
	)
	runtime.set("_match_id", "match.ui.runtime.presentation.integration")
	var runtime_source_id := "source.ui.runtime.presentation.002"
	var runtime_source := {
		"receipt_id": runtime_source_id,
		"state_revision": 2,
		"event_kind": "military_region_assault",
	}
	runtime.call(
		"_publish_combat_event",
		"military_region_assault",
		{
			"target_region_id": "region.14",
			"damage_amount": 3,
			"task_kind": "assault_region",
			"public_summary": "Public military assault resolved",
		},
		"ui.runtime.presentation.002",
		runtime_source_id,
		PresentationIdentity.source_fingerprint(
			runtime_source_id,
			runtime_source
		),
		2
	)
	await process_frame
	var runtime_after_publish := runtime.call("debug_snapshot") as Dictionary
	var consumer_after_publish := shared_consumer.call(
		"debug_snapshot"
	) as Dictionary
	var screen_after_publish := screen.combat_debug_snapshot()
	var surface_after_publish := (
		screen_after_publish.get("surface", {}) as Dictionary
	)
	_expect(
		int(runtime_after_publish.get("combat_public_receipt_count", -1))
			- int(runtime_before_publish.get("combat_public_receipt_count", -1))
			== 1
		and int(consumer_after_publish.get("applied_receipt_count", -1))
			- int(consumer_before_publish.get("applied_receipt_count", -1))
			== 1
		and int(screen_after_publish.get("combat_map_cue_apply_count", -1))
			- int(screen_before_publish.get("combat_map_cue_apply_count", -1))
			== 1
		and int(surface_after_publish.get(
			"presentation_cue_applied_count",
			-1
		)) - int(surface_before_publish.get(
			"presentation_cue_applied_count",
			-1
		)) == 1,
		"one public runtime receipt traverses consumer, map and surface exactly once"
	)
	_expect(
		int(screen_after_publish.get("receipt_count", -1)) == 0
		and int(screen_after_publish.get("receipt_applied_count", -1)) == 0
		and int(screen_after_publish.get("receipt_rejected_count", -1)) == 0
		and int(screen_after_publish.get(
			"presentation_suppressed_duplicate_consume_count",
			-1
		)) == 0,
		"runtime publication reaches UI only through the shared cue signal"
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
		int(consumer_debug.get("applied_receipt_count", 0)) == 2
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
			) == 2
			and int(
				cue_surface.get(
					"presentation_cue_duplicate_count",
					-1
				)
			) == 1,
		"receipt forwarding leaves both exact-once journals unchanged beyond the explicit observer-only replay"
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
