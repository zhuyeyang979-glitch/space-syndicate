extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const CARD_ART_SCRIPT_PATH := "res://scripts/card_art_view.gd"
const MONSTER_ART_SCRIPT_PATH := "res://scripts/monster_art_view.gd"
const MONSTER_BODY_ART_MANIFEST_PATH := "res://data/art/monster_body_art_manifest.json"

const EXPECTED_MONSTER_BODY_SPRITES := {
	"孢雾海皇": {"upstream": "superpowers_asset_packs_cc0", "visual": "superpowers_cc0_dragon_family", "sprite": "superpowers_dragon"},
	"砂铠陆行兽": {"upstream": "monster_battler_cc0", "visual": "monster_battler_cc0_rock_family", "sprite": "monster_battler_rock"},
	"流星哨兵": {"upstream": "kenney_cc0", "visual": "kenney_cc0_enemy_ufo_family", "sprite": "kenney_enemy_ufo"},
	"棱刃重甲": {"upstream": "monster_battler_cc0", "visual": "monster_battler_cc0_dino_family", "sprite": "monster_battler_dino"},
	"绿洲修复体": {"upstream": "pixelmob_cc0", "visual": "pixelmob_cc0_slime_square_family", "sprite": "pixelmob_slime_square"},
	"焰环幼星": {"upstream": "moth_kaijuice_mit", "visual": "moth_kaijuice_mit_kaiju_family", "sprite": "moth_kaijuice_kaiju"},
	"蓝锋骑士": {"upstream": "superpowers_asset_packs_cc0", "visual": "superpowers_cc0_snake_family", "sprite": "superpowers_snake"},
	"镜像猎兵": {"upstream": "kenney_cc0", "visual": "kenney_cc0_alien_blue_family", "sprite": "kenney_alien_blue"},
}

const ONLY_MOTH_KAIJUICE_MONSTER := "焰环幼星"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(MAIN_SCENE_PATH)
	_expect(packed is PackedScene, "main scene loads for art identity audit")
	if not (packed is PackedScene):
		_finish()
		return

	var main := (packed as PackedScene).instantiate()
	get_root().add_child(main)
	await process_frame
	await process_frame

	await _verify_card_art_identity(main)
	await _verify_monster_art_identity(main)
	_verify_monster_body_art_manifest()
	_verify_monster_action_art_identity(main)

	main.queue_free()
	_finish()


func _verify_card_art_identity(main: Node) -> void:
	_expect(main.has_method("_art_identity_audit_card_sources"), "main exposes a dev-only full-card art identity audit source list")
	if not main.has_method("_art_identity_audit_card_sources"):
		return
	var card_sources := main.call("_art_identity_audit_card_sources") as Array
	_expect(card_sources.size() >= 120, "art identity audit covers the full current card catalog, not just a small sample")

	var script := load(CARD_ART_SCRIPT_PATH)
	_expect(script != null, "card art script loads for identity audit")
	if script == null:
		return
	var card_view := script.new() as Control
	_expect(card_view != null, "card art identity audit can instantiate the shared CardArtView")
	if card_view == null:
		return
	get_root().add_child(card_view)
	await process_frame

	var seen_keys := {}
	var sprite_keys := {}
	var visual_sources := {}
	var required_focus_cards := {
		"城市融资1": "city_money",
		"产业升级1": "factory_upgrade",
		"交通升级1": "transit_route",
		"星际广告1": "broadcast",
		"诱导电波1": "lure_beacon",
		"过载补给1": "supply_cache",
		"移动1": "movement_arrow",
		"普攻1": "impact_attack",
		"格挡1": "shield_guard",
		"区域破坏1": "district_crack",
	}
	var verified_focus_cards := {}
	for source_variant in card_sources:
		if not (source_variant is Dictionary):
			_failures.append("card art source entry is not a Dictionary")
			continue
		var source := source_variant as Dictionary
		var card_name := String(source.get("name", ""))
		card_view.call(
			"set_card",
			card_name,
			String(source.get("kind", "")),
			String(source.get("tags", "")),
			source.get("accent", Color("#94a3b8")) as Color,
			int(source.get("rank", 1)),
			false,
			String(source.get("stats", ""))
		)
		var profile := card_view.call("card_visual_profile_snapshot") as Dictionary
		var profile_key := String(card_view.call("card_visual_profile_key"))
		_expect(String(profile.get("theme", "")) == "multi-source-open-card-illustrations-v2", "card %s uses the multi-source open card illustration theme" % card_name)
		_expect(String(profile.get("visual_source_id", "")) != "", "card %s declares a concrete visual source id" % card_name)
		_expect(String(profile.get("sprite_key", "")) != "" and String(profile.get("sprite_cell", "")) != "", "card %s has a concrete sprite key and region/cell" % card_name)
		_expect(profile.has("layout_variant") and profile.has("palette_variant") and profile.has("effect_variant") and profile.has("composition_variant") and profile.has("motif_family") and profile.has("first_run_art_focus") and profile.has("illustration_anchor"), "card %s has multi-axis illustration fields beyond text/name" % card_name)
		if required_focus_cards.has(card_name):
			var expected_focus := String(required_focus_cards[card_name])
			_expect(String(profile.get("first_run_art_focus", "")) == expected_focus, "first-run card %s has the authored focus overlay %s" % [card_name, expected_focus])
			verified_focus_cards[card_name] = true
		_expect(not seen_keys.has(profile_key), "card %s has a unique visual profile key; duplicate=%s" % [card_name, profile_key])
		seen_keys[profile_key] = card_name
		sprite_keys[String(profile.get("sprite_key", ""))] = true
		visual_sources[String(profile.get("visual_source_id", ""))] = true
	card_view.queue_free()

	_expect(seen_keys.size() == card_sources.size(), "every audited card has one unique card illustration profile")
	_expect(sprite_keys.size() >= 10, "card illustrations use at least ten sprite families across the catalog")
	_expect(visual_sources.size() >= 10, "card illustrations use at least ten visual source families across the catalog")
	var missing_focus_cards := []
	for required_name_variant in required_focus_cards.keys():
		var required_name := String(required_name_variant)
		if not verified_focus_cards.has(required_name):
			missing_focus_cards.append(required_name)
	_expect(verified_focus_cards.size() == required_focus_cards.size(), "starter/high-frequency card art focus overlays are present for the complete first-run card set; missing=%s" % ", ".join(missing_focus_cards))


func _verify_monster_art_identity(main: Node) -> void:
	_expect(main.has_method("_art_identity_audit_monster_sources"), "main exposes a dev-only monster art identity audit source list")
	if not main.has_method("_art_identity_audit_monster_sources"):
		return
	var monster_sources := main.call("_art_identity_audit_monster_sources") as Array
	_expect(monster_sources.size() >= 8, "monster art audit covers every current monster family")

	var script := load(MONSTER_ART_SCRIPT_PATH)
	_expect(script != null, "monster art script loads for identity audit")
	if script == null:
		return
	var card_script := load(CARD_ART_SCRIPT_PATH)
	_expect(card_script != null, "card art script loads for monster-card body matching audit")
	if card_script == null:
		return
	var monster_view := script.new() as Control
	_expect(monster_view != null, "monster art identity audit can instantiate the shared MonsterArtView")
	if monster_view == null:
		return
	var card_view := card_script.new() as Control
	_expect(card_view != null, "monster-card body matching audit can instantiate the shared CardArtView")
	if card_view == null:
		return
	get_root().add_child(monster_view)
	get_root().add_child(card_view)
	await process_frame

	var seen_keys := {}
	var silhouettes := {}
	var sprite_keys := {}
	var visual_sources := {}
	var upstream_sources := {}
	var upstream_counts := {}
	var required_upstream_sources := {
		"moth_kaijuice_mit": false,
		"monster_battler_cc0": false,
		"kenney_cc0": false,
		"pixelmob_cc0": false,
		"superpowers_asset_packs_cc0": false,
	}
	var moth_source_count := 0
	var moth_upstream_count := 0
	var moth_sprite_count := 0
	var moth_monster_names: Array[String] = []
	var monster_index := -1
	for source_variant in monster_sources:
		monster_index += 1
		if not (source_variant is Dictionary):
			_failures.append("monster art source entry is not a Dictionary")
			continue
		var source := source_variant as Dictionary
		var monster_name := String(source.get("name", ""))
		monster_view.call(
			"set_monster",
			monster_name,
			String(source.get("style", "自动怪兽")),
			int(source.get("hp", 0)),
			int(source.get("armor", 0)),
			String(source.get("move_text", "")),
			source.get("profile", {}) as Dictionary,
			false
		)
		var profile := monster_view.call("monster_visual_profile_snapshot") as Dictionary
		var profile_key := String(monster_view.call("monster_visual_profile_key"))
		var visual_source_id := String(profile.get("visual_source_id", ""))
		var upstream_source_id := String(profile.get("upstream_source_id", ""))
		var sprite_key := String(profile.get("sprite_key", ""))
		_expect(String(profile.get("theme", "")) == "multi-source-open-monster-sprites-v2", "monster %s uses the multi-source open monster sprite theme" % monster_name)
		_expect(upstream_source_id != "", "monster %s declares a concrete upstream source pack id" % monster_name)
		_expect(visual_source_id != "", "monster %s declares a concrete visual source id" % monster_name)
		_expect(sprite_key != "" and String(profile.get("sprite_cell", "")) != "", "monster %s has a concrete sprite key and region/cell" % monster_name)
		_expect(profile.has("upstream_source_id") and profile.has("silhouette") and profile.has("layout_variant") and profile.has("palette_variant") and profile.has("effect_layer") and profile.has("composition_variant"), "monster %s has multi-axis illustration fields beyond text/name" % monster_name)
		_expect(EXPECTED_MONSTER_BODY_SPRITES.has(monster_name), "monster %s is listed in the explicit one-monster-one-body art roster" % monster_name)
		if EXPECTED_MONSTER_BODY_SPRITES.has(monster_name):
			var expected_profile := EXPECTED_MONSTER_BODY_SPRITES[monster_name] as Dictionary
			_expect(upstream_source_id == String(expected_profile.get("upstream", "")), "monster %s keeps its authored upstream art pack; expected=%s got=%s" % [monster_name, String(expected_profile.get("upstream", "")), upstream_source_id])
			_expect(visual_source_id == String(expected_profile.get("visual", "")), "monster %s keeps its authored visual body family; expected=%s got=%s" % [monster_name, String(expected_profile.get("visual", "")), visual_source_id])
			_expect(sprite_key == String(expected_profile.get("sprite", "")), "monster %s keeps its authored body sprite; expected=%s got=%s" % [monster_name, String(expected_profile.get("sprite", "")), sprite_key])
		if upstream_source_id == "moth_kaijuice_mit" or visual_source_id.begins_with("moth_kaijuice") or sprite_key.begins_with("moth_kaijuice"):
			moth_monster_names.append(monster_name)
		if upstream_source_id == "moth_kaijuice_mit":
			moth_upstream_count += 1
		if sprite_key.begins_with("moth_kaijuice"):
			moth_sprite_count += 1
		if monster_name != ONLY_MOTH_KAIJUICE_MONSTER:
			_expect(upstream_source_id != "moth_kaijuice_mit" and not visual_source_id.begins_with("moth_kaijuice") and not sprite_key.begins_with("moth_kaijuice"), "monster %s must not reuse MOS/Moth Kaijuice body art; it is reserved for %s" % [monster_name, ONLY_MOTH_KAIJUICE_MONSTER])
		_expect(not seen_keys.has(profile_key), "monster %s has a unique visual profile key; duplicate=%s" % [monster_name, profile_key])
		var monster_card_name := String(main.call("_monster_card_name", monster_index, 1)) if main.has_method("_monster_card_name") else ""
		var monster_card_skill: Dictionary = main.call("_skill_definition", monster_card_name) as Dictionary if monster_card_name != "" and main.has_method("_skill_definition") else {}
		card_view.call(
			"set_card",
			monster_card_name,
			String(monster_card_skill.get("kind", "monster_card")),
			String(main.call("_skill_tag_text", monster_card_skill)) if main.has_method("_skill_tag_text") else "怪兽卡",
			main.call("_card_theme_color", monster_card_skill) as Color if main.has_method("_card_theme_color") else Color("#ef4444"),
			1,
			false,
			String(main.call("_art_identity_card_stats", monster_card_name, monster_card_skill)) if main.has_method("_art_identity_card_stats") else ""
		)
		var card_profile := card_view.call("card_visual_profile_snapshot") as Dictionary
		_expect(String(card_profile.get("sprite_key", "")) == sprite_key, "monster card %s uses the same body sprite key as %s; card=%s body=%s" % [
			monster_card_name,
			monster_name,
			String(card_profile.get("sprite_key", "")),
			sprite_key,
		])
		seen_keys[profile_key] = monster_name
		silhouettes[String(profile.get("silhouette", ""))] = true
		sprite_keys[sprite_key] = true
		visual_sources[visual_source_id] = true
		upstream_sources[upstream_source_id] = true
		upstream_counts[upstream_source_id] = int(upstream_counts.get(upstream_source_id, 0)) + 1
		if required_upstream_sources.has(upstream_source_id):
			required_upstream_sources[upstream_source_id] = true
		if visual_source_id.begins_with("moth_kaijuice"):
			moth_source_count += 1
	monster_view.queue_free()
	card_view.queue_free()

	_expect(seen_keys.size() == monster_sources.size(), "every monster has one unique monster art profile")
	_expect(silhouettes.size() == monster_sources.size(), "every current monster family has a distinct silhouette/motif assignment")
	_expect(sprite_keys.size() == monster_sources.size(), "every current monster family uses a distinct body sprite key, not one reused sprite with cosmetic edits")
	_expect(visual_sources.size() == monster_sources.size(), "every current monster family uses a distinct visual source family")
	_expect(upstream_sources.size() >= 5, "current monster roster draws body art from at least five upstream/open-source packs instead of one repeated sprite sheet")
	var missing_upstream_sources: Array[String] = []
	for source_id in required_upstream_sources.keys():
		if not bool(required_upstream_sources[source_id]):
			missing_upstream_sources.append(String(source_id))
	_expect(missing_upstream_sources.is_empty(), "current monster roster includes every required open monster body source; missing=%s" % ", ".join(missing_upstream_sources))
	var largest_upstream_count := 0
	for count_variant in upstream_counts.values():
		largest_upstream_count = maxi(largest_upstream_count, int(count_variant))
	_expect(largest_upstream_count <= int(ceil(float(monster_sources.size()) * 0.35)), "no single upstream monster art pack supplies more than 35% of the current roster")
	_expect(moth_source_count == 1, "Moth Kaijuice/MOS kaiju art is reserved for exactly one monster family in the current roster")
	_expect(moth_upstream_count == 1 and moth_sprite_count == 1 and moth_monster_names == [ONLY_MOTH_KAIJUICE_MONSTER], "MOS/Moth Kaijuice body art must appear on %s only; found=%s upstream=%d sprites=%d" % [ONLY_MOTH_KAIJUICE_MONSTER, ", ".join(moth_monster_names), moth_upstream_count, moth_sprite_count])


func _verify_monster_body_art_manifest() -> void:
	_expect(FileAccess.file_exists(MONSTER_BODY_ART_MANIFEST_PATH), "monster body art manifest exists as the source-diversity contract")
	if not FileAccess.file_exists(MONSTER_BODY_ART_MANIFEST_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MONSTER_BODY_ART_MANIFEST_PATH))
	_expect(parsed is Dictionary, "monster body art manifest parses as JSON object")
	if not (parsed is Dictionary):
		return
	var manifest := parsed as Dictionary
	_expect(String(manifest.get("version", "")) == "monster-body-art-manifest-v1", "monster body art manifest has the expected version")
	var rules := manifest.get("rules", {}) as Dictionary
	_expect(String(rules.get("moth_kaijuice_reserved_monster", "")) == ONLY_MOTH_KAIJUICE_MONSTER, "manifest reserves the MOS/Moth slot for the same single monster as the audit gate")
	_expect(int(rules.get("moth_kaijuice_max_active_body_monsters", 0)) == 1, "manifest caps active MOS/Moth body usage at exactly one monster")
	_expect(int(rules.get("minimum_active_upstream_sources", 0)) >= 5, "manifest requires at least five active upstream monster art packs")
	_expect(float(rules.get("maximum_single_upstream_active_share", 1.0)) <= 0.35, "manifest caps any one upstream pack at 35% or less of active roster")
	_expect(int(rules.get("minimum_future_non_mos_candidates", 0)) >= 8, "manifest requires at least eight non-MOS future body candidates")
	_expect(not bool(rules.get("candidate_moth_kaijuice_usage_allowed", true)), "manifest forbids MOS/Moth candidates for future generic monster expansion")

	var active_roster := manifest.get("active_roster", {}) as Dictionary
	_expect(active_roster.size() == EXPECTED_MONSTER_BODY_SPRITES.size(), "manifest active roster covers the explicit current monster list one-for-one")
	var active_visuals := {}
	var active_sprites := {}
	var moth_active_names: Array[String] = []
	for monster_name_variant in EXPECTED_MONSTER_BODY_SPRITES.keys():
		var monster_name := String(monster_name_variant)
		_expect(active_roster.has(monster_name), "manifest active roster lists %s" % monster_name)
		if not active_roster.has(monster_name):
			continue
		var entry := active_roster[monster_name] as Dictionary
		var expected := EXPECTED_MONSTER_BODY_SPRITES[monster_name] as Dictionary
		var upstream_source_id := String(entry.get("upstream_source_id", ""))
		var visual_source_id := String(entry.get("visual_source_id", ""))
		var sprite_key := String(entry.get("sprite_key", ""))
		var asset_path := String(entry.get("asset_path", ""))
		_expect(upstream_source_id == String(expected.get("upstream", "")), "manifest %s upstream matches code/test art profile" % monster_name)
		_expect(visual_source_id == String(expected.get("visual", "")), "manifest %s visual family matches code/test art profile" % monster_name)
		_expect(sprite_key == String(expected.get("sprite", "")), "manifest %s sprite key matches code/test art profile" % monster_name)
		_expect(asset_path.begins_with("res://") and FileAccess.file_exists(asset_path), "manifest %s points at an existing imported body asset" % monster_name)
		_expect(String(entry.get("silhouette_intent", "")).length() >= 8, "manifest %s explains the silhouette intent for human art review" % monster_name)
		_expect(not active_visuals.has(visual_source_id), "manifest active visual family is unique for %s" % monster_name)
		_expect(not active_sprites.has(sprite_key), "manifest active sprite key is unique for %s" % monster_name)
		active_visuals[visual_source_id] = monster_name
		active_sprites[sprite_key] = monster_name
		if upstream_source_id == "moth_kaijuice_mit" or visual_source_id.begins_with("moth_kaijuice") or sprite_key.begins_with("moth_kaijuice"):
			moth_active_names.append(monster_name)
	_expect(moth_active_names == [ONLY_MOTH_KAIJUICE_MONSTER], "manifest active MOS/Moth body appears only on %s; found=%s" % [ONLY_MOTH_KAIJUICE_MONSTER, ", ".join(moth_active_names)])

	var candidates := manifest.get("future_candidate_bank", []) as Array
	var min_candidates := int(rules.get("minimum_future_non_mos_candidates", 8))
	_expect(candidates.size() >= min_candidates, "manifest keeps a future non-MOS monster body candidate bank with at least %d entries" % min_candidates)
	var candidate_visuals := {}
	var candidate_sprites := {}
	var candidate_upstreams := {}
	for candidate_variant in candidates:
		if not (candidate_variant is Dictionary):
			_failures.append("monster body art manifest candidate is not a Dictionary")
			continue
		var candidate := candidate_variant as Dictionary
		var candidate_id := String(candidate.get("candidate_id", ""))
		var candidate_upstream := String(candidate.get("upstream_source_id", ""))
		var candidate_visual := String(candidate.get("visual_source_id", ""))
		var candidate_sprite := String(candidate.get("sprite_key", ""))
		var candidate_path := String(candidate.get("asset_path", ""))
		_expect(candidate_id != "" and candidate_visual != "" and candidate_sprite != "", "future monster art candidate declares id, visual family, and sprite key")
		_expect(candidate_upstream != "moth_kaijuice_mit" and not candidate_visual.begins_with("moth_kaijuice") and not candidate_sprite.begins_with("moth_kaijuice"), "future monster art candidate %s is not a hidden reuse of MOS/Moth body art" % candidate_id)
		_expect(not active_visuals.has(candidate_visual), "future monster art candidate %s uses a visual family not already consumed by the active roster" % candidate_id)
		_expect(not active_sprites.has(candidate_sprite), "future monster art candidate %s uses a body sprite not already consumed by the active roster" % candidate_id)
		_expect(not candidate_visuals.has(candidate_visual), "future monster art candidate %s has a unique candidate visual family" % candidate_id)
		_expect(not candidate_sprites.has(candidate_sprite), "future monster art candidate %s has a unique candidate sprite key" % candidate_id)
		_expect(candidate_path.begins_with("res://") and FileAccess.file_exists(candidate_path), "future monster art candidate %s points at an existing imported asset" % candidate_id)
		_expect(String(candidate.get("best_fit", "")).length() >= 8, "future monster art candidate %s states a gameplay/ecology fit, not only a file path" % candidate_id)
		candidate_visuals[candidate_visual] = candidate_id
		candidate_sprites[candidate_sprite] = candidate_id
		candidate_upstreams[candidate_upstream] = true
	_expect(candidate_visuals.size() >= min_candidates, "future monster art candidate bank has enough distinct visual families")
	_expect(candidate_upstreams.size() >= 4, "future monster art candidate bank draws from several upstream packs, not one backup sheet")

	var reference_sources := manifest.get("reference_only_sources", []) as Array
	_expect(reference_sources.size() >= 3, "manifest tracks non-imported kaiju/city/planet references separately from copied body assets")
	for reference_variant in reference_sources:
		if not (reference_variant is Dictionary):
			_failures.append("monster art reference-only source is not a Dictionary")
			continue
		var reference := reference_variant as Dictionary
		_expect(String(reference.get("url", "")).begins_with("https://github.com/"), "reference-only monster art source keeps a GitHub URL for follow-up review")
		_expect(String(reference.get("usage", "")).length() >= 12, "reference-only monster art source states what it is useful for")


func _verify_monster_action_art_identity(main: Node) -> void:
	_expect(main.has_method("_art_identity_audit_monster_action_sources"), "main exposes a dev-only monster action animation audit source list")
	if not main.has_method("_art_identity_audit_monster_action_sources"):
		return
	var action_sources := main.call("_art_identity_audit_monster_action_sources") as Array
	_expect(action_sources.size() >= 48, "monster action art audit covers every current monster action slot")
	var by_monster := {}
	var motion_families := {}
	var effect_layers := {}
	for source_variant in action_sources:
		if not (source_variant is Dictionary):
			_failures.append("monster action source entry is not a Dictionary")
			continue
		var source := source_variant as Dictionary
		var monster_name := String(source.get("monster_name", "怪兽"))
		var action_name := String(source.get("action_name", "行动"))
		var profile := source.get("profile", {}) as Dictionary
		_expect(String(profile.get("motion_family", "")) != "" and String(profile.get("pose_key", "")) != "" and String(profile.get("effect_layer", "")) != "", "%s/%s has motion, pose, and effect fields" % [monster_name, action_name])
		_expect(profile.has("anticipation_seconds") and profile.has("active_seconds") and profile.has("recovery_seconds") and profile.has("impact_seconds"), "%s/%s has animation timing fields" % [monster_name, action_name])
		_expect(profile.has("range_meters") and profile.has("move_override_mps") and profile.has("knockback_meters") and profile.has("throw_meters") and String(profile.get("scale_contract", "")).contains("linear-meter-stage"), "%s/%s has meter-based range/move/knockback scale contract" % [monster_name, action_name])
		if float(source.get("knockback", 0.0)) > 0.0 or float(profile.get("throw_meters", 0.0)) > 0.0:
			_expect(float(profile.get("impact_seconds", 9.0)) <= 0.60, "%s/%s knockback/throw impact resolves within a readable sub-second window" % [monster_name, action_name])
		if int(source.get("damage", 0)) > 0:
			_expect(String(profile.get("motion_family", "")) != "utility_pose", "%s/%s damage action is not using a generic utility pose" % [monster_name, action_name])
		if not by_monster.has(monster_name):
			by_monster[monster_name] = {"names": {}, "keys": {}, "poses": {}}
		var bucket := by_monster[monster_name] as Dictionary
		var names := bucket["names"] as Dictionary
		var keys := bucket["keys"] as Dictionary
		var poses := bucket["poses"] as Dictionary
		var profile_key := String(profile.get("profile_key", ""))
		var pose_key := String(profile.get("pose_key", ""))
		_expect(not names.has(action_name), "%s action name is authored once, not duplicated for probability weighting: %s" % [monster_name, action_name])
		_expect(not keys.has(profile_key), "%s action has a unique animation profile: %s" % [monster_name, action_name])
		_expect(not poses.has(pose_key), "%s action has a unique pose key: %s" % [monster_name, action_name])
		names[action_name] = true
		keys[profile_key] = true
		poses[pose_key] = true
		motion_families[String(profile.get("motion_family", ""))] = true
		effect_layers[String(profile.get("effect_layer", ""))] = true
	for monster_name_variant in by_monster.keys():
		var bucket := by_monster[monster_name_variant] as Dictionary
		_expect((bucket["names"] as Dictionary).size() >= 6, "%s keeps six authored action slots with independent animation identities" % String(monster_name_variant))
	_expect(motion_families.size() >= 8, "monster roster action art covers at least eight motion families")
	_expect(effect_layers.size() >= 7, "monster roster action art covers at least seven effect layers")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Art identity gate test passed.")
	else:
		push_error("Art identity gate test failed:\n- " + "\n- ".join(_failures))
	quit(_failures.size())
