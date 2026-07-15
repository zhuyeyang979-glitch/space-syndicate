@tool
extends Node
class_name MonsterCodexPublicSourceService

const SOURCE_ADAPTER_SCRIPT := preload("res://scripts/runtime/monster_codex_public_source_adapter.gd")
const MONSTER_CATALOG_V06 := preload("res://scripts/runtime/monster_catalog_v06.gd")
const DEPENDENCY_KEYS := ["monster", "snapshot", "card_source"]

var _monster: Node
var _snapshot: MonsterCodexPublicSnapshotService
var _card_source: Node
var _adapter: RefCounted = SOURCE_ADAPTER_SCRIPT.new()
var _configured := false
var _last_error := "dependencies_not_configured"
var _source_compose_count := 0
var _snapshot_compose_count := 0
var _browser_compose_count := 0


func configure(dependencies: Dictionary) -> Dictionary:
	_clear_dependencies()
	var keys := dependencies.keys()
	keys.sort()
	var expected := DEPENDENCY_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		_last_error = "dependency_keys_invalid"
		return debug_snapshot()
	_monster = dependencies.get("monster") as Node
	_snapshot = dependencies.get("snapshot") as MonsterCodexPublicSnapshotService
	_card_source = dependencies.get("card_source") as Node
	if _monster == null or not _monster.has_method("monster_codex_public_catalog_source_v06") or not _monster.has_method("monster_codex_public_catalog_summary_v06"):
		_last_error = "monster_public_catalog_owner_invalid"
		_clear_dependencies()
		return debug_snapshot()
	if _snapshot == null or not _snapshot.has_method("compose"):
		_last_error = "snapshot_service_invalid"
		_clear_dependencies()
		return debug_snapshot()
	if _card_source == null or not _card_source.has_method("compose_card_facts"):
		_last_error = "card_public_source_invalid"
		_clear_dependencies()
		return debug_snapshot()
	_configured = true
	_last_error = ""
	return debug_snapshot()


func compose_detail_source(catalog_index: int, selected: bool = false) -> Dictionary:
	if not _require_ready():
		return {}
	var value: Variant = _monster.call("monster_codex_public_catalog_source_v06", catalog_index)
	if not (value is Dictionary):
		_last_error = "monster_public_catalog_return_invalid"
		return {}
	var source := (value as Dictionary).duplicate(true)
	source["selected"] = selected
	source["profile"] = _presentation_profile(source)
	source["accent"] = (source.get("profile", {}) as Dictionary).get("accent", Color("#fb7185")) as Color if source.get("profile", {}) is Dictionary else Color("#fb7185")
	source["monster_card"] = _monster_card_facts(source.get("monster_card", {}))
	var monster_card_source := source.get("monster_card", {}) as Dictionary if source.get("monster_card", {}) is Dictionary else {}
	source["monster_card_link"] = _monster_card_link(monster_card_source)
	var sanitized_variant: Variant = _adapter.call("compose_source", source)
	var sanitized := (sanitized_variant as Dictionary).duplicate(true) if sanitized_variant is Dictionary else {}
	if sanitized.is_empty():
		_last_error = "public_source_rejected"
		return {}
	_source_compose_count += 1
	_last_error = ""
	return sanitized


func compose_snapshot(catalog_index: int, selected: bool = false) -> Dictionary:
	var source := compose_detail_source(catalog_index, selected)
	if source.is_empty():
		return {}
	var value: Variant = _snapshot.call("compose", source)
	var result := (value as Dictionary).duplicate(true) if value is Dictionary else {}
	if not result.is_empty():
		result["monster_card_link"] = (source.get("monster_card_link", {}) as Dictionary).duplicate(true) if source.get("monster_card_link", {}) is Dictionary else {}
		_snapshot_compose_count += 1
	return result


func compose_browser_source(request: Dictionary) -> Dictionary:
	if not _require_ready() or not bool(_adapter.call("accepts_public_input", request)):
		_last_error = "browser_request_rejected"
		return {}
	var start_index := maxi(0, int(request.get("start_index", 0)))
	var end_index := maxi(start_index, int(request.get("end_index", start_index)))
	var selected_index := int(request.get("selected_index", start_index))
	var entries: Array = []
	for catalog_index in range(start_index, end_index):
		var snapshot := compose_snapshot(catalog_index, catalog_index == selected_index)
		if snapshot.get("browser_entry", {}) is Dictionary:
			entries.append((snapshot.get("browser_entry", {}) as Dictionary).duplicate(true))
	var preview: Variant = compose_snapshot(selected_index, true).get("detail", {})
	var summary_value: Variant = _monster.call("monster_codex_public_catalog_summary_v06")
	var summary := (summary_value as Dictionary).duplicate(true) if summary_value is Dictionary else {}
	var result := {
		"columns": clampi(int(request.get("columns", 3)), 1, 6),
		"selected_index": selected_index,
		"can_page": bool(request.get("can_page", false)),
		"page_label": str(request.get("page_label", "")),
		"summaries": [_browser_summary(summary)],
		"entries": entries,
		"preview": (preview as Dictionary).duplicate(true) if preview is Dictionary else {},
	}
	_browser_compose_count += 1
	_last_error = ""
	return result

func public_field_schema() -> Dictionary:
	var value: Variant = _adapter.call("public_field_schema")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func debug_snapshot() -> Dictionary:
	var adapter_debug: Dictionary = _adapter.call("debug_snapshot") as Dictionary
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"last_error": _last_error,
		"source_compose_count": _source_compose_count,
		"snapshot_compose_count": _snapshot_compose_count,
		"browser_compose_count": _browser_compose_count,
		"dependency_allowlist": DEPENDENCY_KEYS.duplicate(),
		"dependency_count": DEPENDENCY_KEYS.size() if _configured else 0,
		"owns_public_source_assembly": true,
		"owns_rules": false,
		"owns_save_state": false,
		"has_save_api": false,
		"reads_world_bridge": false,
		"reads_roster": false,
		"reads_private_targeting": false,
		"reads_player_state": false,
		"reads_market_quote": false,
		"reads_camera": false,
		"uses_monster_public_catalog_owner": _monster != null,
		"uses_card_public_source_without_quotes": _card_source != null,
		"uses_existing_snapshot_formatter": _snapshot != null,
		"adapter": adapter_debug.duplicate(true),
	}


func _monster_card_facts(owner_card: Variant) -> Dictionary:
	var card := (owner_card as Dictionary).duplicate(true) if owner_card is Dictionary else {}
	if not bool(card.get("valid", false)):
		return {"valid": false}
	var card_name := str(card.get("card_name", ""))
	var card_variant: Variant = _card_source.call("compose_card_facts", card_name, -1) if card_name != "" else {}
	var card_facts := (card_variant as Dictionary).duplicate(true) if card_variant is Dictionary else {}
	if not bool(card_facts.get("valid", false)):
		card["valid"] = false
		return card
	card["display_name"] = str(card_facts.get("display_name", card.get("display_name", card_name)))
	card["price"] = int(card_facts.get("price", card.get("price", 0)))
	card["region_text"] = str(card.get("region_text", "不限区"))
	return card


func _presentation_profile(source: Dictionary) -> Dictionary:
	var entry := source.get("entry", {}) as Dictionary if source.get("entry", {}) is Dictionary else {}
	var monster_name := str(entry.get("name", ""))
	return MONSTER_CATALOG_V06.art_profile(monster_name)


func _monster_card_link(card: Dictionary) -> Dictionary:
	if not bool(card.get("valid", false)):
		return {"visible": false}
	var card_name := str(card.get("card_name", ""))
	var card_variant: Variant = _card_source.call("compose_card_facts", card_name, -1) if card_name != "" else {}
	var card_facts := (card_variant as Dictionary).duplicate(true) if card_variant is Dictionary else {}
	return {
		"visible": bool(card_facts.get("valid", false)),
		"card_name": card_name,
		"label": "对应怪兽牌（属于卡牌图鉴｜悬停看属性｜点击跳转）：",
		"button_text": "%s｜¥%d" % [str(card.get("display_name", card_name)), int(card.get("price", 0))],
		"tooltip": str(card_facts.get("detail_tooltip", "")),
	}


func _browser_summary(summary: Dictionary) -> Dictionary:
	var movement_counts := summary.get("movement_counts", {}) as Dictionary if summary.get("movement_counts", {}) is Dictionary else {}
	var movement_pieces: Array[String] = []
	for movement_variant: Variant in movement_counts.keys():
		var movement := str(movement_variant)
		movement_pieces.append("%s×%d" % [movement, int(movement_counts.get(movement, 0))])
	return {
		"title": "生态速览",
		"body": "%d只怪兽｜移动:%s｜偏好%d种商品｜%d种行动风格" % [
			int(summary.get("catalog_count", 0)),
			" / ".join(movement_pieces) if not movement_pieces.is_empty() else "暂无",
			int(summary.get("resource_good_count", 0)),
			int(summary.get("role_tag_count", 0)),
		],
		"meta": "飞行 / 水栖海域 / 陆行会改变接近城市和商路的方式。",
		"accent": Color("#fb7185"),
	}


func _require_ready() -> bool:
	if _configured:
		return true
	_last_error = "dependencies_not_configured"
	return false


func _clear_dependencies() -> void:
	_monster = null
	_snapshot = null
	_card_source = null
	_configured = false
