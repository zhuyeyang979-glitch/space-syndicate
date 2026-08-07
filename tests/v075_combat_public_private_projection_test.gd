extends SceneTree

const Adapter := preload(
	"res://scripts/v075/player/v075_combat_projection_adapter.gd"
)
const Bench := preload(
	"res://scripts/tools/v075/v075_combat_player_surface_bench.gd"
)
const SurfaceScene := preload(
	"res://scenes/ui/v075/V075CombatPlayerSurface.tscn"
)

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var authority := Bench.make_authority_snapshot()
	var before := authority.duplicate(true)
	var adapter := Adapter.new()
	var owner_projection := adapter.project_for_viewer(
		authority,
		"player.local"
	)
	var rival_projection := adapter.project_for_viewer(
		authority,
		"player.rival"
	)
	_expect(
		int(owner_projection.get("public_monster_count", 0)) == 2,
		"owner sees the public monster roster"
	)
	_expect(
		int(owner_projection.get("own_private_skill_source_count", 0)) == 1,
		"owner receives one private monster skill source"
	)
	var owner_sources := (
		owner_projection.get("own_monster_skill_sources", []) as Array
	)
	_expect(
		(owner_sources[0] as Dictionary).get("skills", []) is Array
		and (
			(owner_sources[0] as Dictionary).get("skills", []) as Array
		).size() == 4,
		"owner receives four rank-unlocked skill cards"
	)
	_expect(
		(rival_projection.get("own_monster_skill_sources", []) as Array).is_empty(),
		"rival receives no owner skill cards"
	)
	_expect(
		(owner_projection.get("military_task_options", []) as Array).size()
			== 2,
		"owner military projection has exactly two tasks"
	)
	for option_variant in owner_projection.get(
		"military_task_options",
		[]
	) as Array:
		var option := option_variant as Dictionary
		_expect(
			not str(option.get("option_id", "")).is_empty()
			and not str(option.get("card_instance_id", "")).is_empty()
			and not str(option.get("target_slot_id", "")).is_empty(),
			"owner military option keeps card and target identity"
		)
	_expect(
		(rival_projection.get("military_task_options", []) as Array).is_empty(),
		"rival receives no owner military command choice"
	)
	var public_monster := _public_source(
		owner_projection,
		"monster.tech.local.01"
	)
	var rival_view_of_owner := _public_source(
		rival_projection,
		"monster.tech.local.01"
	)
	for field in [
		"display_name",
		"rank",
		"hp",
		"armor",
		"preferred_industry_color",
		"region_id",
		"tracked_facility_id",
		"projected_path",
		"unlocked_skill_count",
		"batch_active_skill_used",
	]:
		_expect(
			public_monster.has(field),
			"owner monster projection exposes %s" % field
		)
	for private_navigation_field in [
		"tracked_region_id",
		"tracked_facility_id",
		"projected_path",
	]:
		_expect(
			not rival_view_of_owner.has(private_navigation_field),
			"rival monster projection hides %s"
				% private_navigation_field
		)
	for forbidden in [
		"skill_definition_id",
		"asset_cost_by_color",
		"cooldown_remaining_batches",
		"skill_card",
		"future_skill_target",
	]:
		_expect(
			not _contains_key(
				owner_projection.get("public_monsters", []),
				forbidden
			),
			"public monster hides %s" % forbidden
		)
	var privacy := adapter.privacy_report(owner_projection)
	_expect(
		bool(privacy.get("valid", false))
		and int(
			privacy.get("public_skill_card_disclosure_count", 1)
		) == 0,
		"owner projection passes public/private privacy audit"
	)
	var rival_privacy := adapter.privacy_report(rival_projection)
	_expect(
		bool(rival_privacy.get("valid", false))
		and int(
			rival_privacy.get(
				"opponent_future_target_disclosure_count",
				1
			)
		) == 0,
		"rival projection discloses no future monster target or path"
	)
	_expect(
		authority == before,
		"projection adapter does not mutate authority input"
	)
	var public_projection := adapter.public_projection(authority)
	_expect(
		(public_projection.get("own_monster_skill_sources", []) as Array).is_empty()
		and (
			public_projection.get("military_task_options", []) as Array
		).is_empty(),
		"public-only projection strips all private zones"
	)
	var public_view_of_owner := _public_source(
		public_projection,
		"monster.tech.local.01"
	)
	_expect(
		not public_view_of_owner.has("tracked_region_id")
		and not public_view_of_owner.has("tracked_facility_id")
		and not public_view_of_owner.has("projected_path"),
		"public-only projection strips future target navigation"
	)
	var downed_authority := authority.duplicate(true)
	var downed_zone := (
		(downed_authority.get(
			"private_skill_zones_by_player",
			{}
		) as Dictionary).get("player.local", []) as Array
	)
	(downed_zone[0] as Dictionary)["status"] = "downed"
	var downed_projection := adapter.project_for_viewer(
		downed_authority,
		"player.local"
	)
	var downed_source := (
		(downed_projection.get(
			"own_monster_skill_sources",
			[]
		) as Array)[0] as Dictionary
	)
	var downed_request_count := 0
	for skill_variant in downed_source.get("skills", []) as Array:
		if bool((skill_variant as Dictionary).get("can_request", false)):
			downed_request_count += 1
	_expect(
		downed_request_count == 0,
		"downed source exposes no requestable private skill"
	)

	var surface := SurfaceScene.instantiate() as V075CombatPlayerSurface
	root.add_child(surface)
	surface.set_anchors_preset(Control.PRESET_TOP_LEFT)
	surface.size = Vector2(1366.0, 520.0)
	surface.apply_projection(
		owner_projection,
		"monster.tech.local.01"
	)
	await process_frame
	var owner_ui := surface.debug_snapshot()
	var owner_dock := owner_ui.get("owner_skill_dock", {}) as Dictionary
	_expect(
		bool(owner_ui.get("viewer_is_owner", false))
		and int(owner_dock.get("skill_card_count", 0)) == 4,
		"owner UI renders four private skill cards"
	)
	_expect(
		int(owner_ui.get("military_task_button_count", 0)) == 2
		and int(owner_ui.get("military_guard_ui_count", 1)) == 0,
		"military UI has two assaults and no guard"
	)
	_expect(
		int(owner_ui.get("public_skill_card_disclosure_count", 1)) == 0,
		"public monster surface contains no skill card fields"
	)
	_expect(
		int(owner_ui.get("private_grid_columns", 0)) == 2,
		"wide combat surface uses two columns"
	)
	surface.size = Vector2(900.0, 620.0)
	await process_frame
	_expect(
		int(surface.debug_snapshot().get("private_grid_columns", 0)) == 2,
		"900px combat surface fits measured two-column children"
	)
	surface.size = Vector2(660.0, 620.0)
	await process_frame
	_expect(
		int(surface.debug_snapshot().get("private_grid_columns", 0)) == 1,
		"660px combat surface stacks without internal wrap"
	)
	surface.apply_projection(
		rival_projection,
		"monster.tech.local.01"
	)
	await process_frame
	var rival_ui := surface.debug_snapshot()
	var rival_dock := rival_ui.get("owner_skill_dock", {}) as Dictionary
	_expect(
		not bool(rival_ui.get("viewer_is_owner", true))
		and not bool(rival_dock.get("visible", true))
		and int(rival_dock.get("skill_card_count", 1)) == 0,
		"rival UI removes skill cards, costs and cooldowns"
	)
	_expect(
		bool(rival_ui.get("public_monster_visible", false)),
		"rival still sees the same public monster"
	)
	surface.queue_free()
	_finish()


func _public_source(
	projection: Dictionary,
	source_instance_id: String
) -> Dictionary:
	for source_variant in projection.get("public_monsters", []) as Array:
		if (
			source_variant is Dictionary
			and str(
				(source_variant as Dictionary).get(
					"source_instance_id",
					""
				)
			) == source_instance_id
		):
			return (source_variant as Dictionary).duplicate(true)
	return {}


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
	if not condition:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	print(
		"V075_COMBAT_PUBLIC_PRIVATE_PROJECTION_TEST|status=%s|passed=%d|total=%d|failures=%s"
		% [
			"PASS" if _failures.is_empty() else "FAIL",
			_checks - _failures.size(),
			_checks,
			JSON.stringify(_failures),
		]
	)
	quit(0 if _failures.is_empty() else 1)
