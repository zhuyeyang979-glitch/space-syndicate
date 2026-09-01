extends SceneTree

const Adapter := preload(
	"res://scripts/v075/player/v075_combat_projection_adapter.gd"
)
const AIAdapter := preload(
	"res://scripts/v075/ai/v075_combat_ai_adapter.gd"
)
const Bench := preload(
	"res://scripts/tools/v075/v075_combat_player_surface_bench.gd"
)
const SurfaceScene := preload(
	"res://scenes/ui/v075/V075CombatPlayerSurface.tscn"
)
const RuntimeOwner := preload(
	"res://scripts/v075_runtime/v075_runtime_owner.gd"
)
const CombatOwner := preload(
	"res://scripts/v075/runtime/v075_combat_runtime_owner.gd"
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
			and not str(option.get("target_slot_id", "")).is_empty()
			and option.get("card_action_binding") is Dictionary
			and str((option.get(
				"card_action_binding",
				{}
			) as Dictionary).get("owner_player_id", "")) == "player.local"
			and str((option.get(
				"card_action_binding",
				{}
			) as Dictionary).get("binding_fingerprint", "")).length() == 64
			and (
				(
					str(option.get("task_kind", "")) == "assault_region"
					and not option.has("target_source_generation")
				)
				or (
					str(option.get("task_kind", "")) == "assault_monster"
					and int(option.get("target_source_generation", 0)) == 2
				)
			),
			"owner military option keeps card and target identity"
		)
	_expect(
		(rival_projection.get("military_task_options", []) as Array).is_empty(),
		"rival receives no owner military command choice"
	)
	var missing_binding_authority := authority.duplicate(true)
	var missing_binding_source := (
		((missing_binding_authority.get(
			"private_skill_zones_by_player",
			{}
		) as Dictionary).get("player.local", []) as Array)[0] as Dictionary
	)
	var missing_binding_skills := missing_binding_source.get("skills", []) as Array
	(missing_binding_skills[2] as Dictionary).erase("target_binding")
	var missing_binding_projection := adapter.project_for_viewer(
		missing_binding_authority,
		"player.local"
	)
	_expect(
		(((missing_binding_projection.get(
			"own_monster_skill_sources",
			[]
		) as Array)[0] as Dictionary).get("skills", []) as Array).size() == 3,
		"missing private target binding is omitted instead of auto-selecting a target"
	)
	var mixed_facility_authority := authority.duplicate(true)
	var mixed_facility_source := (
		((mixed_facility_authority.get(
			"private_skill_zones_by_player",
			{}
		) as Dictionary).get("player.local", []) as Array)[0] as Dictionary
	)
	var mixed_facility_skills := mixed_facility_source.get("skills", []) as Array
	var mixed_facility_binding := (
		(mixed_facility_skills[1] as Dictionary).get(
			"target_binding",
			{}
		) as Dictionary
	)
	mixed_facility_binding["target_region_id"] = "warehouse.14.technology"
	var mixed_facility_projection := adapter.project_for_viewer(
		mixed_facility_authority,
		"player.local"
	)
	_expect(
		(((mixed_facility_projection.get(
			"own_monster_skill_sources",
			[]
		) as Array)[0] as Dictionary).get("skills", []) as Array).size() == 3,
		"facility identity in target_region_id is omitted instead of reinterpreted"
	)
	var stale_source_projection := owner_projection.duplicate(true)
	var stale_source := (
		(stale_source_projection.get(
			"own_monster_skill_sources",
			[]
		) as Array)[0] as Dictionary
	)
	stale_source["source_generation"] = 3
	var stale_source_privacy := adapter.privacy_report(stale_source_projection)
	_expect(
		not bool(stale_source_privacy.get("valid", true))
		and int(stale_source_privacy.get("stale_private_source_count", 0)) == 1,
		"same-owner stale private source DTO fails the privacy audit"
	)
	var missing_card_binding := authority.duplicate(true)
	var missing_binding_options := (
		((missing_card_binding.get(
			"private_player_facts_by_player",
			{}
		) as Dictionary).get("player.local", {}) as Dictionary).get(
			"military_options",
			[]
		) as Array
	)
	(missing_binding_options[0] as Dictionary).erase("card_action_binding")
	var missing_card_binding_projection := adapter.project_for_viewer(
		missing_card_binding,
		"player.local"
	)
	_expect(
		(missing_card_binding_projection.get(
			"military_task_options",
			[]
		) as Array).size() == 1,
		"military option without an authoritative card binding is omitted"
	)
	var stale_target_generation := authority.duplicate(true)
	var stale_target_options := (
		((stale_target_generation.get(
			"private_player_facts_by_player",
			{}
		) as Dictionary).get("player.local", {}) as Dictionary).get(
			"military_options",
			[]
		) as Array
	)
	(stale_target_options[1] as Dictionary)["target_source_generation"] = 1
	var stale_target_projection := adapter.project_for_viewer(
		stale_target_generation,
		"player.local"
	)
	_expect(
		(stale_target_projection.get(
			"military_task_options",
			[]
		) as Array).size() == 1,
		"military monster option with stale target generation is omitted"
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
		) == 0
		and int(privacy.get(
			"private_card_identity_disclosure_count",
			1
		)) == 0,
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
			) == 0
		and int(rival_privacy.get(
			"private_card_identity_disclosure_count",
			1
		)) == 0,
		"rival projection discloses no future monster target or path"
	)
	for private_card_key in [
		"card_action_binding",
		"authority_lineage_fingerprint",
		"immutable_identity_fingerprint",
		"lifecycle_evidence_fingerprint",
		"binding_fingerprint",
	]:
		_expect(
			not _contains_key(rival_projection, private_card_key),
			"rival projection recursively hides %s" % private_card_key
		)
	var ai_adapter := AIAdapter.new()
	var ai_private_facts := {
		"viewer_player_id": "player.local",
		"owned_monsters": [],
	}
	var clean_ai_public_facts := adapter.public_projection(authority)
	var clean_ai_result := ai_adapter.enumerate_candidates(
		ai_private_facts,
		clean_ai_public_facts
	)
	_expect(
		bool(clean_ai_result.get("accepted", false))
		and int(clean_ai_result.get(
			"hidden_info_violation_count",
			1
		)) == 0,
		"legal public source and target identities do not trip the private binding gate"
	)
	for poisoned_key in [
		"card_action_binding",
		"authority_lineage_fingerprint",
		"immutable_identity_fingerprint",
		"authoritative_zone",
		"zone_revision",
		"lifecycle_evidence_fingerprint",
		"expected_action_lifecycle",
		"binding_fingerprint",
	]:
		var poisoned_public_projection := clean_ai_public_facts.duplicate(true)
		var nested_poison := {}
		nested_poison[poisoned_key] = "private.card.binding.poison"
		poisoned_public_projection["public_history"] = [{
			"receipt": {
				"nested": nested_poison,
			},
		}]
		var poisoned_projection_privacy := adapter.privacy_report(
			poisoned_public_projection
		)
		_expect(
			not bool(poisoned_projection_privacy.get("valid", true))
			and int(poisoned_projection_privacy.get(
				"private_card_identity_disclosure_count",
				0
			)) == 1,
			"deep public receipt %s poison turns the projection gate red"
			% poisoned_key
		)
		var ai_result := ai_adapter.enumerate_candidates(
			ai_private_facts,
			poisoned_public_projection
		)
		_expect(
			not bool(ai_result.get("accepted", true))
			and int(ai_result.get("hidden_info_violation_count", 0)) == 1
			and str(ai_result.get("reason_code", "")).begins_with(
				"public_facts_contains_private_card_identity:"
			),
			"AI rejects and counts deep public %s poison" % poisoned_key
		)

	var production_runtime := RuntimeOwner.new()
	var production_combat := CombatOwner.new()
	root.add_child(production_runtime)
	root.add_child(production_combat)
	var production_bound := production_runtime.bind_combat_owner(
		production_combat
	)
	var production_started := production_runtime.start_new_game(
		4,
		900626424,
		false,
		false,
		{
			"map_seed": 900626424,
			"region_count": 16,
			"geography_complexity": "STANDARD",
			"land_ocean_profile": "BALANCED",
		}
	)
	var production_viewer := str(production_runtime.get("_local_player_id"))
	var clean_player_snapshot := production_runtime.player_snapshot(
		production_viewer
	)
	var debug_before_poison := production_runtime.debug_snapshot()
	_expect(
		bool(production_bound.get("accepted", false))
		and bool(production_started.get("accepted", false))
		and not clean_player_snapshot.is_empty(),
		"production player snapshot boundary is available before poison"
	)
	production_runtime.set("_combat_public_history", [{
		"status_changes": [{
			"nested": {
				"binding_fingerprint": "f".repeat(64),
			},
		}],
	}])
	var rejected_player_snapshot := production_runtime.player_snapshot(
		production_viewer
	)
	var debug_after_poison := production_runtime.debug_snapshot()
	_expect(
		rejected_player_snapshot.is_empty()
		and int(production_runtime.get(
			"_v075_public_card_identity_rejection_count"
		)) == 1
		and int(production_runtime.get("_hidden_info_violation_count")) == 1,
		"production player snapshot rejects poisoned public history"
	)
	_expect(
		int(debug_after_poison.get(
			"public_card_identity_rejection_count",
			0
		)) == int(debug_before_poison.get(
			"public_card_identity_rejection_count",
			0
		)) + 1
		and int(debug_after_poison.get(
			"hidden_info_violation_count",
			0
		)) == int(debug_before_poison.get(
			"hidden_info_violation_count",
			0
		)) + 1,
		"privacy rejection invalidates the cached production debug observer"
	)
	production_runtime.queue_free()
	production_combat.queue_free()
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
	# A 660px production viewport yields a measured 636px combat panel after
	# the root safe-area margins; audit the real panel width, not the viewport.
	surface.size = Vector2(636.0, 620.0)
	await process_frame
	_expect(
		int(surface.debug_snapshot().get("private_grid_columns", 0)) == 1,
		"660px production viewport panel stacks without internal wrap"
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
