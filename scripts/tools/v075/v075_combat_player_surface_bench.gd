extends Control
class_name V075CombatPlayerSurfaceBench

const SurfaceScene := preload(
	"res://scenes/ui/v075/V075CombatPlayerSurface.tscn"
)
const ProjectionAdapter := preload(
	"res://scripts/v075/player/v075_combat_projection_adapter.gd"
)
const PresentationConsumer := preload(
	"res://scripts/v075/presentation/v075_combat_presentation_consumer.gd"
)
const CATALOG := preload(
	"res://resources/presentation/alpha01_card_illustration_catalog.tres"
)

@onready var _mode_label: Label = %ModeLabel
@onready var _owner_button: Button = %OwnerButton
@onready var _rival_button: Button = %RivalButton
@onready var _receipt_button: Button = %ReceiptButton
@onready var _surface_host: Control = %SurfaceHost
@onready var _event_label: Label = %EventLabel
@onready var _asset_icon: TextureRect = %AssetIcon

var _surface: V075CombatPlayerSurface
var _projection_adapter := ProjectionAdapter.new()
var _presentation := PresentationConsumer.new()
var _viewer_mode := "owner"
var _last_projection: Dictionary = {}
var _last_presentation_result: Dictionary = {}


func _ready() -> void:
	_asset_icon.texture = CATALOG.resource_for_asset_key(
		&"vfx.monster.attack_smoke"
	) as Texture2D
	_asset_icon.set_meta(
		"stable_asset_key",
		"vfx.monster.attack_smoke"
	)
	_owner_button.pressed.connect(_set_owner_mode)
	_rival_button.pressed.connect(_set_rival_mode)
	_receipt_button.pressed.connect(_emit_demo_receipt)
	_presentation.presentation_cue_ready.connect(
		_on_presentation_cue_ready
	)
	add_child(_presentation)
	_surface = SurfaceScene.instantiate() as V075CombatPlayerSurface
	_surface_host.add_child(_surface)
	_surface.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_surface.private_target_selection_requested.connect(
		_on_private_target_selection_requested
	)
	_surface.military_mission_selected.connect(
		_on_military_mission_selected
	)
	resized.connect(_resolve_layout)
	_set_owner_mode()
	_resolve_layout()


func debug_snapshot() -> Dictionary:
	var surface_debug := (
		_surface.debug_snapshot()
		if is_instance_valid(_surface)
		else {}
	)
	var presentation_debug := _presentation.debug_snapshot()
	return {
		"schema": "V075CombatPlayerSurfaceBenchDebugV1",
		"viewer_mode": _viewer_mode,
		"projection_schema": str(
			_last_projection.get("schema", "")
		),
		"owner_skill_source_count": int(
			_last_projection.get(
				"own_private_skill_source_count",
				0
			)
		),
		"public_monster_count": int(
			_last_projection.get("public_monster_count", 0)
		),
		"surface": surface_debug,
		"presentation": presentation_debug,
		"rival_private_skill_card_count": (
			0
			if _viewer_mode == "rival"
			else int(
				surface_debug.get(
					"owner_skill_dock",
					{}
				).get("skill_card_count", 0)
			)
		),
		"military_task_button_count": int(
			surface_debug.get("military_task_button_count", 0)
		),
		"military_guard_ui_count": int(
			surface_debug.get("military_guard_ui_count", 0)
		),
		"commercial_asset_key_present": (
			_asset_icon.texture != null
			and str(_asset_icon.get_meta("stable_asset_key", "")) ==
				"vfx.monster.attack_smoke"
		),
		"responsive_layout_green": (
			int(surface_debug.get("private_grid_columns", 0)) in [1, 2]
		),
		"presentation_gameplay_mutation_count": int(
			presentation_debug.get(
				"presentation_gameplay_mutation_count",
				-1
			)
		),
		"presentation_rng_draw_delta": int(
			presentation_debug.get(
				"presentation_rng_draw_delta",
				-1
			)
		),
	}


static func make_authority_snapshot() -> Dictionary:
	return {
		"phase": "batch_active",
		"public_monsters": [
			{
				"source_instance_id": "monster.tech.local.01",
				"source_generation": 4,
				"monster_family_id": "monster.technology.prism",
				"owner_player_id": "player.local",
				"display_name": "棱镜技术巨兽",
				"model_asset_key": "model.monster.technology",
				"rank": 4,
				"hp": 78,
				"max_hp": 100,
				"armor": 12,
				"preferred_industry_color": "technology",
				"region_id": "region.07",
				"tracked_region_id": "region.14",
				"tracked_facility_id": "warehouse.14.technology",
				"projected_path": [
					"region.07",
					"region.10",
					"region.14",
				],
				"unlocked_skill_count": 4,
				"batch_active_skill_used": false,
				"status": "active",
			},
			{
				"source_instance_id": "monster.industry.ai.02",
				"source_generation": 2,
				"monster_family_id": "monster.industry.orc",
				"owner_player_id": "player.ai.1",
				"display_name": "铸炉工业巨兽",
				"model_asset_key": "model.monster.industry",
				"rank": 2,
				"hp": 54,
				"max_hp": 80,
				"armor": 7,
				"preferred_industry_color": "industry",
				"region_id": "region.11",
				"tracked_region_id": "region.04",
				"tracked_facility_id": "factory.04.industry",
				"projected_path": [
					"region.11",
					"region.08",
					"region.04",
				],
				"unlocked_skill_count": 2,
				"batch_active_skill_used": true,
				"status": "active",
			},
		],
		"private_skill_zones_by_player": {
			"player.local": [
				{
					"source_instance_id": "monster.tech.local.01",
					"source_generation": 4,
					"owner_player_id": "player.local",
					"monster_display_name": "棱镜技术巨兽",
					"rank": 4,
					"status": "active",
					"batch_active_skill_used": false,
					"skills": [
						{
							"skill_definition_id": "skill.tech.prism.l1",
							"display_name": "棱光修复",
							"state": "READY",
							"asset_cost_by_color": {
								"technology": 1,
							},
							"target_contract": "self",
							"cooldown_remaining_batches": 0,
							"ultimate": false,
							"required_rank": 1,
							"public_effect_id": "effect.monster.repair",
						},
						{
							"skill_definition_id": "skill.tech.prism.l2",
							"display_name": "折射压制",
							"state": "COOLDOWN",
							"asset_cost_by_color": {
								"technology": 2,
								"energy": 1,
							},
							"target_contract": "enemy_facility",
							"cooldown_remaining_batches": 2,
							"ultimate": false,
							"required_rank": 2,
							"public_effect_id": "effect.facility.suppress",
						},
						{
							"skill_definition_id": "skill.tech.prism.l3",
							"display_name": "棱镜突袭",
							"state": "DISABLED",
							"asset_cost_by_color": {
								"technology": 2,
								"industry": 1,
							},
							"target_contract": "enemy_monster",
							"cooldown_remaining_batches": 0,
							"ultimate": false,
							"required_rank": 3,
							"public_effect_id": "effect.monster.strike",
						},
						{
							"skill_definition_id": "skill.tech.prism.l4",
							"display_name": "星环终结",
							"state": "READY",
							"asset_cost_by_color": {
								"technology": 3,
								"energy": 1,
								"commerce": 1,
							},
							"target_contract": "region",
							"cooldown_remaining_batches": 0,
							"ultimate": true,
							"required_rank": 4,
							"public_effect_id": "effect.region.cataclysm",
						},
					],
				},
			],
			"player.ai.1": [
				{
					"source_instance_id": "monster.industry.ai.02",
					"owner_player_id": "player.ai.1",
					"monster_display_name": "铸炉工业巨兽",
					"rank": 2,
					"status": "active",
					"batch_active_skill_used": true,
					"skills": [
						{
							"skill_definition_id": "skill.industry.orc.l1",
							"display_name": "熔炉冲撞",
							"state": "READY",
							"asset_cost_by_color": {
								"industry": 1,
							},
							"target_contract": "enemy_facility",
							"cooldown_remaining_batches": 0,
							"ultimate": false,
							"required_rank": 1,
							"public_effect_id": "effect.facility.damage",
						},
					],
				},
			],
		},
		"private_player_facts_by_player": {
			"player.local": {
				"military_card_selected": true,
				"can_assault_region": true,
				"can_assault_monster": true,
				"military_options": [
					{
						"option_id": "option.military.region.local",
						"owner_player_id": "player.local",
						"card_instance_id": "dbg.military.local.01",
						"card_definition_id": "military.submarine_fleet.life.rank_1",
						"target_slot_id": "combat.military.assault_region.region.14",
						"task_kind": "assault_region",
						"target_region_id": "region.14",
						"target_monster_source_instance_id": "",
						"target_source_generation": 0,
						"launch_region_id": "region.07",
						"asset_cost_by_color": {"life": 1},
						"enabled": true,
						"disabled_reason": "none",
						"action_domain": "military",
					},
					{
						"option_id": "option.military.monster.local",
						"owner_player_id": "player.local",
						"card_instance_id": "dbg.military.local.01",
						"card_definition_id": "military.submarine_fleet.life.rank_1",
						"target_slot_id": "combat.military.assault_monster.monster.ai.02",
						"task_kind": "assault_monster",
						"target_region_id": "",
						"target_monster_source_instance_id": "monster.industry.ai.02",
						"target_source_generation": 2,
						"launch_region_id": "region.07",
						"asset_cost_by_color": {"life": 1},
						"enabled": true,
						"disabled_reason": "none",
						"action_domain": "military",
					},
				],
			},
			"player.ai.1": {
				"military_card_selected": true,
				"can_assault_region": true,
				"can_assault_monster": true,
			},
		},
	}


static func make_projection(viewer_id: String) -> Dictionary:
	var adapter := ProjectionAdapter.new()
	return adapter.project_for_viewer(
		make_authority_snapshot(),
		viewer_id
	)


func _set_owner_mode() -> void:
	_apply_mode("owner")


func _set_rival_mode() -> void:
	_apply_mode("rival")


func _apply_mode(mode: String) -> void:
	_viewer_mode = mode
	var viewer_id := (
		"player.local"
		if mode == "owner"
		else "player.rival"
	)
	_last_projection = _projection_adapter.project_for_viewer(
		make_authority_snapshot(),
		viewer_id
	)
	_mode_label.text = (
		"Owner 视角 · 私密技能可见"
		if mode == "owner"
		else "Rival 视角 · 只显示公开结果"
	)
	_owner_button.button_pressed = mode == "owner"
	_rival_button.button_pressed = mode == "rival"
	_surface.apply_projection(_last_projection, "monster.tech.local.01")
	_event_label.text = (
		"Owner-only skill zone"
		if mode == "owner"
		else "Rival projection: skill definitions, costs and cooldowns withheld"
	)
	_owner_button.grab_focus()


func _emit_demo_receipt() -> void:
	_last_presentation_result = _presentation.consume_receipt({
		"combat_receipt_id": "bench.combat.receipt.001",
		"event_kind": "monster_private_skill_resolved",
		"public_effect_id": "effect.region.cataclysm",
		"source_public_name": "棱镜技术巨兽",
		"source_rank": 4,
		"preferred_industry_color": "technology",
		"target_kind": "region",
		"target_region_id": "region.14",
		"damage_amount": 8,
		"public_summary": "公开效果 · 星环终结已结算",
		"skill_definition_id": "HIDDEN_AND_STRIPPED",
		"asset_cost_by_color": {
			"technology": 3,
		},
		"cooldown_remaining_batches": 3,
	})
	_event_label.text = "Receipt consumed exactly once · duplicate-safe"


func _on_presentation_cue_ready(cue: Dictionary) -> void:
	_surface.show_presentation_cue(cue)


func _on_private_target_selection_requested(request: Dictionary) -> void:
	var source_instance_id := str(request.get("source_instance_id", ""))
	var target_binding := request.get("target_binding", {}) as Dictionary
	_event_label.text = "私密目标选择 · %s · %s" % [
		str(target_binding.get("target_kind", "")),
		source_instance_id,
	]
	# The real Combat Owner binds this signal to a private target selector.


func _on_military_mission_selected(option: Dictionary) -> void:
	var task_kind := str(option.get("task_kind", ""))
	_event_label.text = (
		"任务已选择 · %s · 结算后立即撤离"
		% (
			"攻击地区"
			if task_kind == "assault_region"
			else "攻击怪兽"
		)
	)


func _resolve_layout() -> void:
	if not is_instance_valid(_surface_host):
		return
	var narrow := size.x < 980.0
	_surface_host.custom_minimum_size.y = 610.0 if narrow else 430.0
