extends SceneTree

const CARD_ILLUSTRATION_MANIFEST_PATH := "res://data/art/card_illustration_manifest_v06.json"
const MONSTER_BODY_ART_MANIFEST_PATH := "res://data/art/monster_body_art_manifest.json"
const ILLUSTRATION_LAYER_SCENE_PATH := "res://scenes/ui/CardIllustrationLayer.tscn"
const CARD_UI_SCENE_PATH := "res://scenes/CardUI.tscn"

const WAREHOUSE_STYLE_KEY := "facility.orbital_warehouse.rank_1"
const MONSTER_STYLE_KEY := "unit.monster.spore_tide_emperor.rank_1"
const MONSTER_NAME := "孢雾海皇"
const STYLE_LOCK_STYLE_KEYS := [
	"supply_demand.remote_sea_order.rank_1",
	"supply_demand.near_land_supply.rank_1",
	MONSTER_STYLE_KEY,
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var illustration_manifest := _load_json_object(CARD_ILLUSTRATION_MANIFEST_PATH, "card illustration manifest")
	var monster_manifest := _load_json_object(MONSTER_BODY_ART_MANIFEST_PATH, "monster body art manifest")
	var style_keys: Dictionary = {}
	if not illustration_manifest.is_empty():
		var style_keys_variant: Variant = illustration_manifest.get("style_keys", {})
		_expect(style_keys_variant is Dictionary, "card illustration manifest exposes a style_keys object")
		if style_keys_variant is Dictionary:
			style_keys = style_keys_variant as Dictionary

	_verify_manifest_entries(style_keys)
	_verify_monster_manifest_match(style_keys, monster_manifest)
	await _verify_illustration_layer(style_keys)
	await _verify_card_ui_fallbacks()
	_finish()


func _verify_manifest_entries(style_keys: Dictionary) -> void:
	_expect(style_keys.size() == 6, "card illustration manifest contains exactly six representative cards")
	var visual_sources := {}
	var illustration_anchors := {}
	for style_key_variant in style_keys.keys():
		var style_key := str(style_key_variant)
		var entry_variant: Variant = style_keys.get(style_key_variant, {})
		_expect(entry_variant is Dictionary, "illustration entry %s is a JSON object" % style_key)
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var asset_path := str(entry.get("illustration_path", "")).strip_edges()
		var visual_source_id := str(entry.get("visual_source_id", "")).strip_edges()
		var illustration_anchor := str(entry.get("illustration_anchor", "")).strip_edges()

		_expect(asset_path.begins_with("res://"), "illustration entry %s uses a project resource path" % style_key)
		_expect(FileAccess.file_exists(asset_path), "illustration entry %s points to an existing asset" % style_key)
		var texture := load(asset_path) as Texture2D if FileAccess.file_exists(asset_path) else null
		_expect(texture != null, "illustration entry %s loads as Texture2D" % style_key)

		_expect(visual_source_id != "", "illustration entry %s declares visual_source_id" % style_key)
		_expect(not visual_sources.has(visual_source_id), "illustration entry %s has a unique visual_source_id" % style_key)
		if visual_source_id != "":
			visual_sources[visual_source_id] = style_key

		_expect(illustration_anchor != "", "illustration entry %s declares illustration_anchor" % style_key)
		_expect(not illustration_anchors.has(illustration_anchor), "illustration entry %s has a unique illustration_anchor" % style_key)
		if illustration_anchor != "":
			illustration_anchors[illustration_anchor] = style_key

	_expect(visual_sources.size() == 6, "all six representative cards use distinct visual source identities")
	_expect(illustration_anchors.size() == 6, "all six representative cards use distinct illustration anchors")

	for style_key in STYLE_LOCK_STYLE_KEYS:
		_expect(style_keys.has(style_key), "card illustration manifest includes style-lock candidate %s" % style_key)
		if not style_keys.has(style_key):
			continue
		var candidate := style_keys.get(style_key, {}) as Dictionary
		var superseded_variant: Variant = candidate.get("superseded_placeholder", {})
		_expect(str(candidate.get("source_type", "")) == "authored", "style-lock candidate %s is authored" % style_key)
		_expect(str(candidate.get("status", "")).begins_with("style_lock_candidate_v"), "style-lock candidate %s declares a versioned candidate status" % style_key)
		_expect(str(candidate.get("illustration_path", "")).begins_with("res://assets/art/cards/"), "style-lock candidate %s uses the authored card-art root" % style_key)
		_expect(str(candidate.get("fit_mode", "")) == "cover", "style-lock candidate %s uses cover fitting" % style_key)
		_expect(str(candidate.get("tint_mode", "")) == "preserve", "style-lock candidate %s preserves authored colors" % style_key)
		_expect(str(candidate.get("texture_filter", "")) == "linear", "style-lock candidate %s uses linear filtering" % style_key)
		_expect(str(candidate.get("sha256", "")).length() == 64, "style-lock candidate %s records a SHA-256 hash" % style_key)
		_expect(superseded_variant is Dictionary and not (superseded_variant as Dictionary).is_empty(), "style-lock candidate %s records its superseded placeholder" % style_key)


func _verify_monster_manifest_match(style_keys: Dictionary, monster_manifest: Dictionary) -> void:
	_expect(style_keys.has(MONSTER_STYLE_KEY), "card illustration manifest includes the representative monster")
	var active_roster_variant: Variant = monster_manifest.get("active_roster", {})
	_expect(active_roster_variant is Dictionary, "monster body art manifest exposes active_roster")
	if not style_keys.has(MONSTER_STYLE_KEY) or not (active_roster_variant is Dictionary):
		return
	var active_roster := active_roster_variant as Dictionary
	_expect(active_roster.has(MONSTER_NAME), "monster body art manifest includes %s" % MONSTER_NAME)
	if not active_roster.has(MONSTER_NAME):
		return
	var card_entry := style_keys.get(MONSTER_STYLE_KEY, {}) as Dictionary
	var monster_entry := active_roster.get(MONSTER_NAME, {}) as Dictionary
	_expect(
		str(card_entry.get("body_reference_asset_path", "")) == str(monster_entry.get("asset_path", "")),
		"representative monster card art records the map-body asset reference"
	)
	_expect(
		str(card_entry.get("body_reference_visual_source_id", "")) == str(monster_entry.get("visual_source_id", "")),
		"representative monster card art records the map-body visual identity"
	)
	_expect(
		str(card_entry.get("body_reference_sprite_key", "")) == str(monster_entry.get("sprite_key", "")),
		"representative monster card art records the map-body sprite key"
	)


func _verify_illustration_layer(style_keys: Dictionary) -> void:
	var packed := load(ILLUSTRATION_LAYER_SCENE_PATH) as PackedScene
	_expect(packed != null, "CardIllustrationLayer scene loads")
	_expect(style_keys.has(WAREHOUSE_STYLE_KEY), "card illustration manifest includes the warehouse profile")
	if packed == null or not style_keys.has(WAREHOUSE_STYLE_KEY):
		return
	var warehouse_profile := style_keys.get(WAREHOUSE_STYLE_KEY, {}) as Dictionary
	var warehouse_texture := load(str(warehouse_profile.get("illustration_path", ""))) as Texture2D
	_expect(warehouse_texture != null, "warehouse SVG loads for shared illustration layer validation")
	if warehouse_texture == null:
		return

	var layer := packed.instantiate() as Control
	_expect(layer != null, "CardIllustrationLayer instantiates as a Control")
	if layer == null:
		return
	layer.set_anchors_preset(Control.PRESET_TOP_LEFT)
	layer.size = Vector2(420.0, 260.0)
	root.add_child(layer)
	await process_frame
	_expect(layer.has_method("set_illustration"), "CardIllustrationLayer exposes set_illustration")
	_expect(layer.has_method("clear_illustration"), "CardIllustrationLayer exposes clear_illustration")
	_expect(layer.has_method("get_debug_snapshot"), "CardIllustrationLayer exposes a developer debug snapshot")
	if layer.has_method("set_illustration") and layer.has_method("get_debug_snapshot"):
		layer.call("set_illustration", warehouse_texture, Color("#22d3ee"), warehouse_profile)
		await process_frame
		var active_snapshot := layer.call("get_debug_snapshot") as Dictionary
		_expect(bool(active_snapshot.get("active", false)), "warehouse illustration activates the shared layer")
		_expect(str(active_snapshot.get("source_type", "")) == "open_source_placeholder", "warehouse layer snapshot retains source type")
		_expect(str(active_snapshot.get("visual_source_id", "")) == str(warehouse_profile.get("visual_source_id", "")), "warehouse layer snapshot retains visual source identity")
		_expect(str(active_snapshot.get("fit_mode", "")) == "contain", "warehouse illustration uses contain fitting")
		_expect(str(active_snapshot.get("tint_mode", "")) == "accent_monochrome", "warehouse illustration uses accent monochrome treatment")
		_expect(str(active_snapshot.get("semantic_motif", "")) == "warehouse_grid", "warehouse illustration uses its semantic motif")
		_expect(str(active_snapshot.get("resolved_motif", "")) == "warehouse_grid", "warehouse illustration resolves its semantic motif")

	await _verify_semantic_motif_alias(layer, style_keys, "supply_demand.remote_sea_order.rank_1", "sea_route_arc")
	await _verify_semantic_motif_alias(layer, style_keys, "supply_demand.near_land_supply.rank_1", "supply_stream")

	if layer.has_method("clear_illustration") and layer.has_method("get_debug_snapshot"):
		layer.call("clear_illustration")
		await process_frame
		var cleared_snapshot := layer.call("get_debug_snapshot") as Dictionary
		_expect(not bool(cleared_snapshot.get("active", true)), "clearing the shared illustration layer removes the active texture")
		_expect(not layer.visible, "clearing the shared illustration layer hides it")

	root.remove_child(layer)
	layer.queue_free()
	await process_frame


func _verify_semantic_motif_alias(layer: Control, style_keys: Dictionary, style_key: String, expected_resolved_motif: String) -> void:
	_expect(style_keys.has(style_key), "manifest includes semantic motif probe %s" % style_key)
	if not style_keys.has(style_key):
		return
	var profile := style_keys.get(style_key, {}) as Dictionary
	var texture := load(str(profile.get("illustration_path", ""))) as Texture2D
	_expect(texture != null, "semantic motif probe %s loads its authored texture" % style_key)
	if texture == null:
		return
	layer.call("set_illustration", texture, Color("#22d3ee"), profile)
	await process_frame
	var snapshot := layer.call("get_debug_snapshot") as Dictionary
	_expect(str(snapshot.get("resolved_motif", "")) == expected_resolved_motif, "%s resolves to the supported %s overlay" % [style_key, expected_resolved_motif])


func _verify_card_ui_fallbacks() -> void:
	var packed := load(CARD_UI_SCENE_PATH) as PackedScene
	_expect(packed != null, "CardUI scene loads for fallback validation")
	if packed == null:
		return

	await _verify_card_ui_fallback(
		packed,
		"res://docs/not_an_approved_card_illustration.png",
		{"source_type": "authored", "visual_source_id": "disallowed_path_probe"},
		"path_not_allowed",
		"an illustration outside approved source roots"
	)
	await _verify_card_ui_fallback(
		packed,
		"res://assets/art/cards/../third_party/traversal_probe.png",
		{"source_type": "authored", "visual_source_id": "traversal_path_probe"},
		"path_not_allowed",
		"a traversal path that starts with an approved source root"
	)
	var missing_approved_path := "res://assets/art/cards/v06/__missing_card_illustration_test__.png"
	_expect(not FileAccess.file_exists(missing_approved_path), "approved-prefix missing-texture probe is absent")
	await _verify_card_ui_fallback(
		packed,
		missing_approved_path,
		{"source_type": "authored", "visual_source_id": "missing_texture_probe"},
		"missing_texture",
		"a missing texture inside an approved source root"
	)


func _verify_card_ui_fallback(
	packed: PackedScene,
	illustration_path: String,
	illustration_profile: Dictionary,
	expected_reason: String,
	case_label: String
) -> void:
	var card := packed.instantiate() as Control
	_expect(card != null, "CardUI instantiates for %s" % case_label)
	if card == null:
		return
	card.size = Vector2(280.0, 392.0)
	root.add_child(card)
	await process_frame
	_expect(card.has_method("set_card_data"), "CardUI exposes set_card_data for %s" % case_label)
	if card.has_method("set_card_data"):
		card.call("set_card_data", {
			"name": "回退验证",
			"type": "商品",
			"rank": 1,
			"effect": "验证无法载入外部插画时仍显示程序化卡面。",
			"illustration_path": illustration_path,
			"illustration_profile": illustration_profile,
			"illustration_silent_fallback": true,
		})
		await process_frame
		_expect(not bool(card.get_meta("external_illustration_active", true)), "CardUI keeps external illustration inactive for %s" % case_label)
		_expect(str(card.get_meta("illustration_fallback_reason", "")) == expected_reason, "CardUI records %s for %s" % [expected_reason, case_label])
		var art_view := card.find_child("ArtView", true, false) as Control
		var illustration_layer := card.find_child("IllustrationLayer", true, false) as Control
		_expect(art_view != null and art_view.visible, "CardUI shows CardArtView fallback for %s" % case_label)
		_expect(illustration_layer != null and not illustration_layer.visible, "CardUI hides the external illustration layer for %s" % case_label)

	root.remove_child(card)
	card.queue_free()
	await process_frame


func _load_json_object(path: String, label: String) -> Dictionary:
	_expect(FileAccess.file_exists(path), "%s exists" % label)
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	_expect(parsed is Dictionary, "%s parses as a JSON object" % label)
	return parsed as Dictionary if parsed is Dictionary else {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		_failures.append(message)
		push_error(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Card illustration layer test passed.")
	else:
		push_error("Card illustration layer test failed:\n- " + "\n- ".join(_failures))
	quit(0 if _failures.is_empty() else 1)
