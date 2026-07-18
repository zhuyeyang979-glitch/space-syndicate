extends RefCounted
class_name CommoditySushiTrackSnapshot

const ITEM_SCRIPT := preload("res://scripts/viewmodels/commodity_sushi_track_item_snapshot.gd")
const ALLOWED_INPUT_KEYS := [
	"schema_version",
	"available",
	"snapshot_revision",
	"belt_revision",
	"visibility_revision",
	"market_revision",
	"public_refresh_phase",
	"items",
	"empty_text",
]

var schema_version := 1
var available := false
var snapshot_revision := 0
var belt_revision := 0
var visibility_revision := 0
var market_revision := 0
var public_refresh_phase := ""
var items: Array[ITEM_SCRIPT] = []
var empty_text := "共享商品带尚未就绪。"
var _valid := false


func apply_dictionary(source: Dictionary) -> CommoditySushiTrackSnapshot:
	_valid = false
	items.clear()
	for key_variant in source.keys():
		if not ALLOWED_INPUT_KEYS.has(str(key_variant)):
			return self
	schema_version = int(source.get("schema_version", 1))
	available = bool(source.get("available", false))
	snapshot_revision = int(source.get("snapshot_revision", 0))
	belt_revision = int(source.get("belt_revision", 0))
	visibility_revision = int(source.get("visibility_revision", 0))
	market_revision = int(source.get("market_revision", 0))
	public_refresh_phase = str(source.get("public_refresh_phase", "")).strip_edges()
	empty_text = str(source.get("empty_text", "共享商品带尚未就绪。")).strip_edges()
	var seen_ids: Dictionary = {}
	var source_items: Array = source.get("items", []) if source.get("items", []) is Array else []
	for item_variant in source_items:
		if not (item_variant is Dictionary):
			return self
		var item: ITEM_SCRIPT = ITEM_SCRIPT.new().apply_dictionary(item_variant as Dictionary)
		if item == null or not item.is_valid() or seen_ids.has(item.commodity_slot_id):
			return self
		seen_ids[item.commodity_slot_id] = true
		items.append(item)
	items.sort_custom(func(left: ITEM_SCRIPT, right: ITEM_SCRIPT) -> bool:
		return left.slot_index < right.slot_index
	)
	_valid = _validation_errors().is_empty()
	return self


func is_valid() -> bool:
	return _valid and _validation_errors().is_empty()


func to_dictionary() -> Dictionary:
	if not is_valid():
		return {}
	var item_rows: Array = []
	for item in items:
		item_rows.append(item.to_dictionary())
	return {
		"schema_version": schema_version,
		"available": available,
		"snapshot_revision": snapshot_revision,
		"belt_revision": belt_revision,
		"visibility_revision": visibility_revision,
		"market_revision": market_revision,
		"public_refresh_phase": public_refresh_phase,
		"items": item_rows,
		"empty_text": empty_text,
	}


func item_by_id(commodity_slot_id: String) -> ITEM_SCRIPT:
	for item in items:
		if item.commodity_slot_id == commodity_slot_id:
			return ITEM_SCRIPT.new().apply_dictionary(item.to_dictionary())
	return null


func _validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if schema_version != 1:
		errors.append("schema_version_invalid")
	if snapshot_revision < 0 or belt_revision < 0 or visibility_revision < 0 or market_revision < 0:
		errors.append("revision_invalid")
	if available and visibility_revision <= 0:
		errors.append("visibility_revision_missing")
	if empty_text.is_empty():
		errors.append("empty_text_missing")
	return errors
