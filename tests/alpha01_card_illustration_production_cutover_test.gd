extends SceneTree

const STATUS_MANIFEST_PATH := "res://data/art/alpha01_card_illustration_status_manifest.json"
const ALPHA_MANIFEST_PATH := "res://resources/content/alpha01/alpha01_content_manifest.tres"
const CATALOG_RESOURCE_PATH := "res://resources/presentation/alpha01_card_illustration_catalog.tres"
const CATALOG_SCENE_PATH := "res://scenes/runtime/CardIllustrationCatalog.tscn"
const PRESENTATION_SCENE_PATH := "res://scenes/runtime/CardPresentationRuntimeService.tscn"
const CODEX_SOURCE_SCENE_PATH := "res://scenes/runtime/CardCodexPublicSourceService.tscn"
const CODEX_SNAPSHOT_SCENE_PATH := "res://scenes/runtime/CardCodexPublicSnapshotService.tscn"
const CARD_FACE_SCENE_PATH := "res://scenes/ui/CardFace.tscn"
const CODEX_THUMBNAIL_SCENE_PATH := "res://scenes/ui/codex/CardCodexThumbnailCard.tscn"
const CODEX_DETAIL_SCENE_PATH := "res://scenes/ui/CardCodexDetail.tscn"
const V06_CATALOG_PATH := "res://resources/cards/runtime/card_runtime_catalog_v06.tres"
const FORBIDDEN_PRESENTATION_KEYS := [
	"illustration_path", "illustration_profile", "source_type", "visual_source_id", "upstream_source_id",
	"license", "attribution", "sha256", "commercial_status", "prompt_document",
]

var failures: Array[String] = []
var checks := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var status := _load_json(STATUS_MANIFEST_PATH)
	var alpha: Resource = load(ALPHA_MANIFEST_PATH)
	var catalog_resource := load(CATALOG_RESOURCE_PATH) as CardIllustrationCatalogResource
	_expect(not status.is_empty() and alpha != null and catalog_resource != null, "manifests and typed catalog resource load")
	if status.is_empty() or alpha == null or catalog_resource == null:
		_finish()
		return
	var alpha_ids := _alpha_rank_one_ids(alpha)
	var rendered := _dictionary(status.get("rendered_entries", {}))
	var fallback := _string_array(status.get("semantic_fallback_entries", []))
	var status_ids := rendered.keys()
	status_ids.append_array(fallback)
	status_ids.sort()
	var expected_ids: Array = alpha_ids.duplicate()
	expected_ids.sort()
	_expect(alpha_ids.size() == 40 and rendered.size() == 5 and fallback.size() == 35, "status manifest declares 40 Alpha ids as 5 rendered plus 35 semantic fallbacks")
	_expect(status_ids == expected_ids, "status manifest has exact Alpha id parity without overlap or invented cards")
	var validation := catalog_resource.validation_report()
	_expect(bool(validation.get("valid", false)) and int(validation.get("rendered_count", 0)) == 5 and int(validation.get("fallback_count", 0)) == 35, "typed catalog resource validates the 5/35 boundary")
	for card_id_variant in rendered.keys():
		var card_id := str(card_id_variant)
		var entry := _dictionary(rendered[card_id_variant])
		var asset_path := str(entry.get("illustration_path", ""))
		var evidence_path := str(entry.get("license_evidence", ""))
		_expect(FileAccess.file_exists(asset_path), "%s rendered asset exists" % card_id)
		_expect(FileAccess.get_sha256(asset_path).to_lower() == str(entry.get("sha256", "")).to_lower(), "%s asset hash matches" % card_id)
		_expect(str(entry.get("license", "")).strip_edges() != "" and FileAccess.file_exists(evidence_path), "%s license and evidence exist" % card_id)
		var presentation_key := str(entry.get("presentation_key", ""))
		_expect(presentation_key.begins_with("alpha01_art_") and not presentation_key.contains(card_id), "%s exposes an opaque presentation key" % card_id)
		_expect(str(catalog_resource.presentation_key_for_card(card_id)) == presentation_key and catalog_resource.texture_for_key(StringName(presentation_key)) != null, "%s typed presentation key resolves" % card_id)
	for card_id in fallback:
		_expect(catalog_resource.presentation_key_for_card(card_id) == StringName(), "%s remains an explicit semantic fallback" % card_id)

	var catalog_scene := (load(CATALOG_SCENE_PATH) as PackedScene).instantiate() as CardIllustrationCatalog
	root.add_child(catalog_scene)
	var scene_report := catalog_scene.validation_report()
	_expect(bool(scene_report.get("valid", false)) and bool(catalog_scene.debug_snapshot().get("read_only", false)), "scene-owned catalog loads as a read-only presentation service")

	var presentation := (load(PRESENTATION_SCENE_PATH) as PackedScene).instantiate() as CardPresentationRuntimeService
	var codex_snapshot := (load(CODEX_SNAPSHOT_SCENE_PATH) as PackedScene).instantiate() as CardCodexPublicSnapshotService
	var codex_source := (load(CODEX_SOURCE_SCENE_PATH) as PackedScene).instantiate() as CardCodexPublicSourceService
	root.add_child(presentation)
	root.add_child(codex_snapshot)
	root.add_child(codex_source)
	presentation.configure({})
	codex_snapshot.configure({})
	var configured := codex_source.configure({"snapshot": codex_snapshot})
	_expect(bool(presentation.debug_snapshot().get("illustration_catalog_ready", false)) and bool(configured.get("service_ready", false)) and bool(codex_source.debug_snapshot().get("illustration_catalog_ready", false)), "formal card and codex presentation services bind the typed catalog")

	var v06_catalog: Resource = load(V06_CATALOG_PATH)
	var rendered_output_count := 0
	var fallback_output_count := 0
	for card_id in alpha_ids:
		var card := v06_catalog.call("card_snapshot", card_id) as Dictionary
		var source := _presentation_source(card_id, card)
		var card_view := presentation.compose_card(source)
		var hand_view := presentation.compose_hand_card({"slot": 0, "card": source, "eligibility": {"allowed": true, "actionable": true, "reason_code": "playable"}})
		var codex_facts := codex_source.compose_card_facts(card_id, 0)
		var rendered_entry := _dictionary(rendered.get(card_id, {}))
		var expected_key := str(rendered_entry.get("presentation_key", ""))
		_expect(str(card_view.get("illustration_key", "")) == expected_key and str(hand_view.get("illustration_key", "")) == expected_key and str(codex_facts.get("illustration_key", "")) == expected_key, "%s keeps CardUI and Codex illustration parity" % card_id)
		_expect(not _contains_forbidden_key(card_view) and not _contains_forbidden_key(hand_view) and not _contains_forbidden_key(codex_facts), "%s player ViewModels hide paths, hashes, licenses and provenance" % card_id)
		if expected_key == "":
			fallback_output_count += 1
		else:
			rendered_output_count += 1
	_expect(rendered_output_count == 5 and fallback_output_count == 35, "formal presentation outputs resolve exactly 5/40 illustrations")

	var rendered_id := "commodity.ring_crystal_battery.rank_1"
	var fallback_id := "facility.factory.life.rank_1"
	var browser := codex_source.compose_browser({
		"names": [rendered_id, fallback_id], "columns": 2, "rows": 1, "page_index": 0,
		"filter_id": "all", "selected_card": rendered_id,
	})
	var detail := codex_source.compose_detail(rendered_id, 0, 40)
	var browser_cards := browser.get("cards", []) as Array
	var detail_payload := _dictionary(detail.get("detail", {}))
	var detail_face := _dictionary(detail_payload.get("card_face", {}))
	var rendered_key := str(_dictionary(rendered.get(rendered_id, {})).get("presentation_key", ""))
	_expect(browser_cards.size() == 2 and str(_dictionary(browser_cards[0]).get("illustration_key", "")) == rendered_key and str(_dictionary(browser_cards[1]).get("illustration_key", "")) == "", "Codex thumbnails preserve rendered and fallback identities")
	_expect(str(detail_face.get("illustration_key", "")) == rendered_key and not _contains_forbidden_key(detail), "Codex detail preserves only the opaque illustration key")

	await _verify_card_face(rendered_key, true, Vector2(86.0, 112.0))
	await _verify_card_face("", false, Vector2(86.0, 112.0))
	await _verify_codex_targets(_dictionary(browser_cards[0]), detail_payload)

	var architecture_sources := [
		"res://scripts/presentation/card_illustration_catalog.gd",
		"res://scripts/presentation/card_illustration_catalog_resource.gd",
	]
	for source_path in architecture_sources:
		var source_text := FileAccess.get_file_as_string(source_path)
		_expect(not source_text.contains("main.gd") and not source_text.contains("current_scene") and not source_text.contains("/root/Main"), "%s has no Main or service-locator dependency" % source_path)

	for node in [catalog_scene, presentation, codex_source, codex_snapshot]:
		node.queue_free()
	await process_frame
	_finish()


func _verify_card_face(illustration_key: String, expected_active: bool, card_size: Vector2) -> void:
	var face := (load(CARD_FACE_SCENE_PATH) as PackedScene).instantiate() as Control
	root.add_child(face)
	face.size = card_size
	face.call("set_card_data", {
		"name": "验收卡面", "rank": "I", "type": "商品", "cost": "0", "effect": "低分辨率仍保留完整语义卡面。",
		"presentation": "mini_hand", "illustration_key": illustration_key, "illustration_silent_fallback": true,
	})
	await process_frame
	_expect(bool(face.get_meta("external_illustration_active", false)) == expected_active, "CardUI %s illustration at 86x112" % ("activates" if expected_active else "keeps fallback"))
	_expect(face.size.x >= 80.0 and face.size.y >= 100.0, "CardUI low-resolution card keeps readable geometry")
	face.queue_free()
	await process_frame


func _verify_codex_targets(browser_card: Dictionary, detail: Dictionary) -> void:
	var thumbnail := (load(CODEX_THUMBNAIL_SCENE_PATH) as PackedScene).instantiate() as Control
	root.add_child(thumbnail)
	thumbnail.call("set_card", browser_card)
	await process_frame
	_expect(bool(thumbnail.get_meta("external_illustration_active", false)), "formal Codex thumbnail target renders the approved illustration")
	thumbnail.queue_free()
	await process_frame
	var detail_node := (load(CODEX_DETAIL_SCENE_PATH) as PackedScene).instantiate() as Control
	root.add_child(detail_node)
	detail_node.call("set_detail", detail)
	await process_frame
	var face := detail_node.find_child("CardCodexSceneCardFace", true, false) as Control
	_expect(face != null and bool(face.get_meta("external_illustration_active", false)), "formal Codex detail CardFace renders the same approved illustration")
	detail_node.queue_free()
	await process_frame


func _presentation_source(card_id: String, card: Dictionary) -> Dictionary:
	var machine := _dictionary(card.get("machine", {}))
	var player := _dictionary(card.get("player", {}))
	var skill := {
		"name": card_id,
		"card_id": card_id,
		"machine": machine,
		"kind": str(machine.get("effect_kind", "")),
		"rank": int(machine.get("rank", 1)),
		"text": str(player.get("effect", player.get("short_effect", ""))),
		"type_label": str(player.get("type", "")),
		"subtype_label": str(player.get("industry", "")),
	}
	return {
		"card_id": card_id,
		"card_name": card_id,
		"skill": skill,
		"display_name": str(player.get("name", card_id)),
		"display_text": str(player.get("effect", player.get("short_effect", ""))),
		"rank": int(machine.get("rank", 1)),
		"price": int(machine.get("purchase_cash", 0)),
		"category_id": str(machine.get("category_id", "")),
	}


func _alpha_rank_one_ids(alpha: Resource) -> Array[String]:
	var result: Array[String] = []
	for family_variant in alpha.get("card_family_ids") as PackedStringArray:
		result.append("%s.rank_1" % str(family_variant))
	return result


func _contains_forbidden_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in value:
			if FORBIDDEN_PRESENTATION_KEYS.has(str(key_variant)) or _contains_forbidden_key(value[key_variant]):
				return true
	elif value is Array:
		for item_variant in value:
			if _contains_forbidden_key(item_variant):
				return true
	return false


func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed as Dictionary if parsed is Dictionary else {}


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for item_variant in value:
			result.append(str(item_variant))
	return result


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("ALPHA01 CARD ILLUSTRATION CUTOVER: %s" % message)


func _finish() -> void:
	if failures.is_empty():
		print("ALPHA01_CARD_ILLUSTRATION_PRODUCTION_CUTOVER|status=PASS|checks=%d|rendered=5|fallback=35|privacy_leaks=0" % checks)
		quit(0)
		return
	print("ALPHA01_CARD_ILLUSTRATION_PRODUCTION_CUTOVER|status=FAIL|checks=%d|failures=%d|details=%s" % [checks, failures.size(), JSON.stringify(failures)])
	quit(1)
