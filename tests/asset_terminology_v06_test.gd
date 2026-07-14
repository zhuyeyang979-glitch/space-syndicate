extends SceneTree

const CATALOG_PATH := "res://data/cards/card_runtime_catalog_v06.json"
const SKIN_FIXTURE_PATH := "res://data/ui/card_ui_skin_lab_cards_v06.json"
const RULEBOOK_PATH := "res://docs/tabletop_rulebook_v06.md"
const INSPECTOR_PATH := "res://scripts/ui/right_inspector.gd"

var _checks := 0
var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog := _read_json(CATALOG_PATH)
	_expect(not catalog.is_empty(), "v0.6 card catalog parses")
	var cards: Array = catalog.get("cards", []) if catalog.get("cards", []) is Array else []
	var metadata: Dictionary = catalog.get("metadata", {}) if catalog.get("metadata", {}) is Dictionary else {}
	var expected_card_count := int(metadata.get("explicit_ranked_card_count", 0))
	var expected_family_count := int(metadata.get("named_family_count", 0))
	var expected_organization_count := int(metadata.get("organization_ranked_card_count", 0))
	_expect(expected_card_count == 348, "catalog manifest declares the authoritative 348-card v0.6 seed")
	_expect(expected_family_count == 87, "catalog manifest declares 87 complete named families")
	_expect(expected_organization_count == 20, "catalog manifest declares 20 organization ranks")
	_expect(cards.size() == expected_card_count, "all manifest-declared v0.6 ranked cards are checked")
	var family_ids: Dictionary = {}
	var organization_count := 0
	for card_variant in cards:
		if not (card_variant is Dictionary):
			_expect(false, "catalog card is a dictionary")
			continue
		var card: Dictionary = card_variant
		var machine: Dictionary = card.get("machine", {}) if card.get("machine", {}) is Dictionary else {}
		var player: Dictionary = card.get("player", {}) if card.get("player", {}) is Dictionary else {}
		var card_id := str(machine.get("card_id", "<missing>"))
		var family_id := str(machine.get("family_id", ""))
		_expect(not family_id.is_empty(), "%s has a stable family identity" % card_id)
		if not family_id.is_empty():
			family_ids[family_id] = true
		if str(machine.get("category_id", "")) == "organization":
			organization_count += 1
		_expect(machine.has("asset_cost") and not machine.has("mana_cost"), "%s uses asset_cost machine schema" % card_id)
		_expect(not _contains_legacy_term(player), "%s player text uses only the asset terminology" % card_id)
	_expect(family_ids.size() == expected_family_count, "catalog family count matches its authoritative manifest")
	_expect(organization_count == expected_organization_count, "organization category count matches its authoritative manifest")
	var skin_source := _read_text(SKIN_FIXTURE_PATH)
	_expect(not skin_source.is_empty() and not _contains_legacy_text(skin_source), "Skin Lab player fixture contains no legacy resource term")
	var rulebook_source := _read_text(RULEBOOK_PATH)
	_expect(not rulebook_source.is_empty() and not _contains_legacy_text(rulebook_source), "v0.6 player rulebook contains no legacy resource term")
	var inspector_source := _read_text(INSPECTOR_PATH)
	_expect(not inspector_source.is_empty() and not _contains_legacy_text(inspector_source), "right-side player inspector contains no legacy resource term")
	_finish()


func _read_json(path: String) -> Dictionary:
	var source := _read_text(path)
	var parsed: Variant = JSON.parse_string(source)
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_as_text() if file != null else ""


func _contains_legacy_term(value: Variant) -> bool:
	return _contains_legacy_text(JSON.stringify(value))


func _contains_legacy_text(value: String) -> bool:
	return value.contains("法力") or value.to_lower().contains("mana")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	print("FAIL: %s" % message)


func _finish() -> void:
	if _failures.is_empty():
		print("ASSET_TERMINOLOGY_V06_TEST|status=PASS|checks=%d|failures=0" % _checks)
		quit(0)
		return
	print("ASSET_TERMINOLOGY_V06_TEST|status=FAIL|checks=%d|failures=%d|details=%s" % [_checks, _failures.size(), JSON.stringify(_failures)])
	quit(1)
