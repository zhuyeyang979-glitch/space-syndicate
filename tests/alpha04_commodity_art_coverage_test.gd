extends SceneTree

const ACTIVE_MANIFEST_PATH := "res://data/art/alpha04_commodity_art_manifest.json"
const ALPHA_MANIFEST_PATH := "res://resources/content/alpha01/alpha01_content_manifest.tres"
const CARD_CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const ILLUSTRATION_CATALOG_PATH := "res://resources/presentation/alpha01_card_illustration_catalog.tres"
const ILLUSTRATION_SCENE_PATH := "res://scenes/runtime/CardIllustrationCatalog.tscn"
const PRESENTATION_SCENE_PATH := "res://scenes/runtime/CardPresentationRuntimeService.tscn"
const CARD_FACE_SCENE_PATH := "res://scenes/ui/CardFace.tscn"
const EXPECTED_COLORS := ["life", "energy", "industry", "technology", "commerce", "shipping"]
const ROMAN_LEVELS := ["I", "II", "III", "IV"]

var _checks := 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var manifest := _load_json(ACTIVE_MANIFEST_PATH)
	var alpha: Resource = load(ALPHA_MANIFEST_PATH)
	var cards: Resource = load(CARD_CATALOG_PATH)
	var catalog := load(ILLUSTRATION_CATALOG_PATH) as CardIllustrationCatalogResource
	_expect(not manifest.is_empty() and alpha != null and cards != null and catalog != null, "authoritative selection, card catalog, art manifest, and typed illustration catalog load")
	if manifest.is_empty() or alpha == null or cards == null or catalog == null:
		_finish(0, 0, 0, 0, 0)
		return

	var active_families := _active_commodity_families(alpha)
	var entries: Array = manifest.get("entries", []) if manifest.get("entries", []) is Array else []
	var entries_by_family := _entries_by_family(entries)
	_expect(active_families.size() == 12 and entries.size() == 12 and entries_by_family.size() == 12, "Alpha selection resolves exactly 12 active commodity types and families")
	_expect(_same_set(active_families, entries_by_family.keys()), "art manifest has exact active-family parity without invented or missing commodities")

	var report := catalog.validation_report()
	_expect(bool(report.get("valid", false)), "typed illustration catalog validates")
	_expect(int(report.get("rendered_count", -1)) == 16 and int(report.get("fallback_count", -1)) == 24, "overall Alpha boundary is 16 rendered and 24 allowed non-commodity fallbacks")
	_expect(int(report.get("active_commodity_type_count", -1)) == 12 \
		and int(report.get("active_commodity_family_count", -1)) == 12 \
		and int(report.get("active_commodity_card_id_count", -1)) == 48 \
		and int(report.get("active_commodity_unique_art_count", -1)) == 12 \
		and int(report.get("active_commodity_fallback_count", -1)) == 0, "active commodity catalog reports 12 types, 48 ranked ids, 12 unique assets, and zero fallback")

	var catalog_scene := (load(ILLUSTRATION_SCENE_PATH) as PackedScene).instantiate() as CardIllustrationCatalog
	root.add_child(catalog_scene)
	var scene_report := catalog_scene.validation_report()
	_expect(bool(scene_report.get("valid", false)) and int(catalog_scene.debug_snapshot().get("active_commodity_fallback_count", -1)) == 0, "scene-owned catalog exposes the zero-fallback commodity contract")
	var presentation := (load(PRESENTATION_SCENE_PATH) as PackedScene).instantiate() as CardPresentationRuntimeService
	root.add_child(presentation)
	presentation.configure({})
	_expect(bool(presentation.debug_snapshot().get("illustration_catalog_ready", false)), "production CardPresentationRuntimeService binds the expanded catalog")

	var face := (load(CARD_FACE_SCENE_PATH) as PackedScene).instantiate() as SpaceSyndicateCardFace
	root.add_child(face)
	face.size = Vector2(96.0, 128.0)
	await process_frame

	var color_counts := {}
	var product_ids := {}
	var presentation_keys := {}
	var asset_hashes := {}
	var geometry_fingerprints := {}
	var authoritative_card_ids := {}
	var source_coverage := 0
	var inventory_coverage := 0
	for family_id in active_families:
		var entry := _dictionary(entries_by_family.get(family_id, {}))
		var commodity_id := str(entry.get("commodity_id", ""))
		var color_id := str(entry.get("color_id", ""))
		var presentation_key := str(entry.get("illustration_key", ""))
		var asset_path := str(entry.get("asset_path", ""))
		var card_ids := _string_array(entry.get("card_ids", []))
		var levels := _int_array(entry.get("levels", []))
		_expect(not commodity_id.is_empty() and not product_ids.has(commodity_id), "%s has a unique authoritative commodity_id" % family_id)
		product_ids[commodity_id] = true
		_expect(color_id in EXPECTED_COLORS, "%s has an authoritative six-color family" % family_id)
		color_counts[color_id] = int(color_counts.get(color_id, 0)) + 1
		_expect(levels == [1, 2, 3, 4] and card_ids.size() == 4, "%s declares the complete I-IV level ladder" % family_id)
		_expect(not presentation_key.is_empty() and not presentation_keys.has(presentation_key), "%s owns a unique opaque illustration key" % family_id)
		presentation_keys[presentation_key] = true
		var source_key := str(catalog.presentation_key_for_commodity_id(commodity_id))
		_expect(source_key == presentation_key, "%s source-surface commodity_id resolves through CardIllustrationCatalog" % commodity_id)
		_expect(str(catalog_scene.presentation_key_for_commodity_id(commodity_id)) == presentation_key, "%s scene-owned catalog exposes the same opaque source key" % commodity_id)
		if source_key == presentation_key:
			source_coverage += 1
		var family_key := str(catalog.presentation_key_for_commodity_family(family_id))
		_expect(family_key == presentation_key, "%s family resolves to the same source and inventory art" % family_id)

		for level in range(1, 5):
			var card_id := "%s.rank_%d" % [family_id, level]
			authoritative_card_ids[card_id] = true
			var runtime_card := cards.call("card_snapshot", card_id) as Dictionary
			var machine := _dictionary(runtime_card.get("machine", {}))
			var payload := _dictionary(machine.get("effect_payload", {}))
			var player := _dictionary(runtime_card.get("player", {}))
			_expect(not runtime_card.is_empty() \
				and str(machine.get("family_id", "")) == family_id \
				and int(machine.get("rank", 0)) == level \
				and str(machine.get("category_id", "")) == "commodity" \
				and str(machine.get("industry_id", "")) == color_id \
				and str(payload.get("product_id", "")) == commodity_id, "%s matches authoritative family, level, color, and commodity_id" % card_id)
			var card_key := str(catalog.presentation_key_for_card(card_id))
			_expect(card_key == presentation_key, "%s shares its commodity base art without fallback" % card_id)
			if card_key == presentation_key:
				inventory_coverage += 1
			var card_view := presentation.compose_card(_presentation_source(card_id, runtime_card))
			_expect(str(card_view.get("illustration_key", "")) == presentation_key \
				and not JSON.stringify(card_view).contains(asset_path), "%s reaches player projection through the existing opaque CardPresentation path" % card_id)
			face.set_card_data({
				"name": str(player.get("name", commodity_id)),
				"type": "商品",
				"rank": ROMAN_LEVELS[level - 1],
				"effect": str(player.get("short_effect", "商品效果")),
				"presentation": "mini_hand",
				"illustration_key": card_key,
				"illustration_silent_fallback": true,
			})
			_expect(bool(face.get_meta("external_illustration_active", false)) \
				and str(face.get_meta("card_stats", "")) == ROMAN_LEVELS[level - 1], "%s renders authored art and keeps its CardFace Roman level" % card_id)

		var svg := FileAccess.get_file_as_string(asset_path)
		var safe_source := svg.replace("xmlns=\"http://www.w3.org/2000/svg\"", "")
		_expect(asset_path.begins_with("res://assets/art/cards/v06/style_keys/commodity/") and asset_path.ends_with(".svg") and FileAccess.file_exists(asset_path), "%s uses the existing owned card-art directory" % family_id)
		_expect(svg.contains("width=\"1024\"") and svg.contains("height=\"768\"") and svg.contains("viewBox=\"0 0 1024 768\""), "%s uses the common 1024x768 SVG canvas" % family_id)
		_expect(not _contains_any(safe_source.to_lower(), ["<text", "<script", "<image", "<foreignobject", "href=", "http://", "https://", "data:", "@import", "<!entity"]), "%s contains no text, scripts, embedded images, or remote resources" % family_id)
		var actual_hash := FileAccess.get_sha256(asset_path).to_lower()
		_expect(actual_hash == str(entry.get("sha256", "")).to_lower() and not asset_hashes.has(actual_hash), "%s has a pinned unique SVG fingerprint" % family_id)
		asset_hashes[actual_hash] = true
		var geometry_fingerprint := _geometry_fingerprint(svg)
		_expect(not geometry_fingerprint.is_empty() and not geometry_fingerprints.has(geometry_fingerprint), "%s has unique geometry, not a palette-only clone" % family_id)
		geometry_fingerprints[geometry_fingerprint] = true
		_expect(_unique_visual_contract(entry), "%s declares unique silhouette, texture, symbol, and theme cues" % family_id)
		var texture := load(asset_path) as Texture2D
		_expect(texture != null and Vector2i(texture.get_size()) == Vector2i(1024, 768), "%s imports in Godot as a 1024x768 Texture2D" % family_id)
		_expect(catalog.texture_for_key(StringName(presentation_key)) == texture \
			or (catalog.texture_for_key(StringName(presentation_key)) != null \
			and catalog.texture_for_key(StringName(presentation_key)).resource_path == texture.resource_path), "%s illustration key resolves the pinned SVG texture" % family_id)
		_expect(catalog.is_authored_key(StringName(presentation_key)), "%s is classified as authored art" % family_id)

	for color_id in EXPECTED_COLORS:
		_expect(int(color_counts.get(color_id, 0)) == 2, "%s has exactly two active commodity families" % color_id)
	_expect(authoritative_card_ids.size() == 48 and _same_set(authoritative_card_ids.keys(), catalog.ranked_active_commodity_card_ids()), "catalog exposes exactly the 48 authoritative active commodity card ids")
	_expect(source_coverage == 12 and inventory_coverage == 48, "source and inventory lookups have 100 percent art coverage")
	_expect(presentation_keys.size() == 12 and asset_hashes.size() == 12 and geometry_fingerprints.size() == 12, "all 12 active commodity types remain visually distinct without color-only identity")
	_expect(catalog.presentation_key_for_card("supply_demand.remote_sea_order.rank_2") == StringName() \
		and catalog.presentation_key_for_card("facility.factory.life.rank_2") == StringName() \
		and catalog.presentation_key_for_card("commodity.not_active.rank_2") == StringName() \
		and catalog.presentation_key_for_card("commodity.blue_tide_algae.rank_5") == StringName() \
		and catalog.presentation_key_for_card("commodity.blue_tide_algae.rank_01") == StringName(), "I-IV normalization is constrained to known active commodity families and never leaks to non-commodity or malformed ids")
	_expect(catalog.presentation_key_for_commodity_id("未知商品") == StringName(), "unknown commodity_id retains the neutral fallback contract")

	face.queue_free()
	catalog_scene.queue_free()
	presentation.queue_free()
	await process_frame
	_finish(active_families.size(), authoritative_card_ids.size(), presentation_keys.size(), source_coverage, inventory_coverage)


func _active_commodity_families(alpha: Resource) -> Array[String]:
	var result: Array[String] = []
	var family_ids: PackedStringArray = alpha.get("card_family_ids")
	for family_id in family_ids:
		if family_id.begins_with("commodity."):
			result.append(family_id)
	result.sort()
	return result


func _entries_by_family(entries: Array) -> Dictionary:
	var result := {}
	for entry_variant in entries:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var family_id := str(entry.get("family_id", ""))
		if family_id.is_empty() or result.has(family_id):
			continue
		result[family_id] = entry.duplicate(true)
	return result


func _presentation_source(card_id: String, card: Dictionary) -> Dictionary:
	var machine := _dictionary(card.get("machine", {}))
	var player := _dictionary(card.get("player", {}))
	return {
		"card_id": card_id,
		"card_name": card_id,
		"skill": {
			"name": card_id,
			"card_id": card_id,
			"machine": machine,
			"kind": str(machine.get("effect_kind", "")),
			"rank": int(machine.get("rank", 1)),
			"text": str(player.get("effect", player.get("short_effect", ""))),
			"type_label": str(player.get("type", "")),
			"subtype_label": str(player.get("industry", "")),
		},
		"display_name": str(player.get("name", card_id)),
		"display_text": str(player.get("effect", player.get("short_effect", ""))),
		"rank": int(machine.get("rank", 1)),
		"price": int(machine.get("purchase_cash", 0)),
		"category_id": str(machine.get("category_id", "")),
	}


func _geometry_fingerprint(svg: String) -> String:
	var expression := RegEx.new()
	if expression.compile("(?:d|cx|cy|r|rx|ry|x|y|width|height|points|transform)=\\\"[^\\\"]+\\\"") != OK:
		return ""
	var geometry: Array[String] = []
	for match_result in expression.search_all(svg):
		geometry.append(match_result.get_string())
	return "\n".join(geometry).sha256_text() if not geometry.is_empty() else ""


func _unique_visual_contract(entry: Dictionary) -> bool:
	var cues := {}
	for key in ["visual_theme", "silhouette", "internal_texture", "symbol"]:
		var cue := str(entry.get(key, "")).strip_edges().to_lower()
		if cue.is_empty() or cues.has(cue):
			return false
		cues[cue] = true
	return cues.size() == 4


func _contains_any(source: String, needles: Array[String]) -> bool:
	for needle in needles:
		if source.contains(needle):
			return true
	return false


func _same_set(left: Variant, right: Variant) -> bool:
	var left_values: Array = (left as Array).duplicate() if left is Array else Array(left)
	var right_values: Array = (right as Array).duplicate() if right is Array else Array(right)
	left_values.sort()
	right_values.sort()
	return left_values == right_values


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item in value:
			result.append(str(item))
	return result


func _int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if value is Array:
		for item in value:
			result.append(int(item))
	return result


func _expect(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)


func _finish(types: int, card_ids: int, unique_art: int, source_coverage: int, inventory_coverage: int) -> void:
	var status := "PASS" if _failures.is_empty() else "FAIL"
	print("ALPHA04_COMMODITY_ART_COVERAGE_TEST|status=%s|checks=%d|failures=%d|types=%d|families=%d|card_ids=%d|unique_art=%d|source_coverage=%d|inventory_coverage=%d|fallback=%d" % [status, _checks, _failures.size(), types, types, card_ids, unique_art, source_coverage, inventory_coverage, maxi(0, card_ids - inventory_coverage)])
	for failure in _failures:
		push_error("ALPHA04_COMMODITY_ART_COVERAGE_TEST: %s" % failure)
	quit(0 if _failures.is_empty() else 1)
