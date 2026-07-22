@tool
extends Node
class_name CardIllustrationCatalog

@export var catalog: CardIllustrationCatalogResource

var _request_count := 0
var _rendered_hit_count := 0
var _fallback_count := 0


func presentation_key_for_card(card_id: String) -> StringName:
	_request_count += 1
	if catalog == null:
		_fallback_count += 1
		return StringName()
	var key := catalog.presentation_key_for_card(card_id)
	if key == StringName():
		_fallback_count += 1
	else:
		_rendered_hit_count += 1
	return key


func validation_report() -> Dictionary:
	return catalog.validation_report() if catalog != null else {
		"valid": false,
		"errors": ["catalog_resource_missing"],
		"alpha_count": 0,
		"rendered_count": 0,
		"fallback_count": 0,
	}


func debug_snapshot() -> Dictionary:
	var report := validation_report()
	return {
		"service_ready": bool(report.get("valid", false)),
		"read_only": true,
		"presentation_only": true,
		"alpha_count": int(report.get("alpha_count", 0)),
		"rendered_count": int(report.get("rendered_count", 0)),
		"fallback_count": int(report.get("fallback_count", 0)),
		"request_count": _request_count,
		"rendered_hit_count": _rendered_hit_count,
		"semantic_fallback_count": _fallback_count,
		"owns_card_state": false,
		"mutates_gameplay": false,
		"reads_main": false,
	}
