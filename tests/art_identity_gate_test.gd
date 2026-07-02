extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const CARD_ART_SCRIPT_PATH := "res://scripts/card_art_view.gd"
const MONSTER_ART_SCRIPT_PATH := "res://scripts/monster_art_view.gd"

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
		_expect(profile.has("layout_variant") and profile.has("palette_variant") and profile.has("effect_variant") and profile.has("composition_variant") and profile.has("motif_family") and profile.has("first_run_art_focus"), "card %s has multi-axis illustration fields beyond text/name" % card_name)
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
	var monster_view := script.new() as Control
	_expect(monster_view != null, "monster art identity audit can instantiate the shared MonsterArtView")
	if monster_view == null:
		return
	get_root().add_child(monster_view)
	await process_frame

	var seen_keys := {}
	var silhouettes := {}
	var sprite_keys := {}
	var visual_sources := {}
	var upstream_sources := {}
	var upstream_counts := {}
	var moth_source_count := 0
	for source_variant in monster_sources:
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
		_expect(String(profile.get("theme", "")) == "multi-source-open-monster-sprites-v2", "monster %s uses the multi-source open monster sprite theme" % monster_name)
		_expect(upstream_source_id != "", "monster %s declares a concrete upstream source pack id" % monster_name)
		_expect(visual_source_id != "", "monster %s declares a concrete visual source id" % monster_name)
		_expect(String(profile.get("sprite_key", "")) != "" and String(profile.get("sprite_cell", "")) != "", "monster %s has a concrete sprite key and region/cell" % monster_name)
		_expect(profile.has("upstream_source_id") and profile.has("silhouette") and profile.has("layout_variant") and profile.has("palette_variant") and profile.has("effect_layer") and profile.has("composition_variant"), "monster %s has multi-axis illustration fields beyond text/name" % monster_name)
		_expect(not seen_keys.has(profile_key), "monster %s has a unique visual profile key; duplicate=%s" % [monster_name, profile_key])
		seen_keys[profile_key] = monster_name
		silhouettes[String(profile.get("silhouette", ""))] = true
		sprite_keys[String(profile.get("sprite_key", ""))] = true
		visual_sources[visual_source_id] = true
		upstream_sources[upstream_source_id] = true
		upstream_counts[upstream_source_id] = int(upstream_counts.get(upstream_source_id, 0)) + 1
		if visual_source_id.begins_with("moth_kaijuice"):
			moth_source_count += 1
	monster_view.queue_free()

	_expect(seen_keys.size() == monster_sources.size(), "every monster has one unique monster art profile")
	_expect(silhouettes.size() == monster_sources.size(), "every current monster family has a distinct silhouette/motif assignment")
	_expect(sprite_keys.size() == monster_sources.size(), "every current monster family uses a distinct body sprite key, not one reused sprite with cosmetic edits")
	_expect(visual_sources.size() == monster_sources.size(), "every current monster family uses a distinct visual source family")
	_expect(upstream_sources.size() >= 4, "current monster roster draws body art from at least four upstream/open-source packs instead of one repeated sprite sheet")
	var largest_upstream_count := 0
	for count_variant in upstream_counts.values():
		largest_upstream_count = maxi(largest_upstream_count, int(count_variant))
	_expect(largest_upstream_count <= int(ceil(float(monster_sources.size()) * 0.5)), "no single upstream monster art pack supplies more than half of the current roster")
	_expect(moth_source_count == 1, "Moth Kaijuice/MOS kaiju art is reserved for exactly one monster family in the current roster")


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
