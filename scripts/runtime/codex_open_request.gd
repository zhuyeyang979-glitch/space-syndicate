extends RefCounted
class_name CodexOpenRequest

const VALID_DOMAINS := ["compendium", "role", "card", "monster", "product", "region"]
const VALID_VIEWS := ["hub", "browser", "preview", "detail"]
const VALID_RETURN_TARGETS := ["main", "compendium", "intel", "economy", "standings", "game"]
const VALID_CARD_FILTERS := ["all", "commodity", "facility", "supply_demand", "monster", "military", "interaction", "organization"]
const VALID_CONTEXT_KEYS := ["origin", "push_current", "pop_stack"]
const VALID_ORIGINS := ["main", "compendium", "intel", "economy", "standings", "game", "role", "card", "monster", "product", "region"]

var domain := "compendium"
var view := "hub"
var stable_item_id := "hub"
var optional_index := -1
var filter_id := ""
var page_delta := 0
var return_target := "main"
var request_revision := 0
var public_source_context: Dictionary = {}


func validation_report() -> Dictionary:
	var errors: Array[String] = []
	if not VALID_DOMAINS.has(domain):
		errors.append("domain_invalid")
	if not VALID_VIEWS.has(view):
		errors.append("view_invalid")
	if not VALID_RETURN_TARGETS.has(return_target):
		errors.append("return_target_invalid")
	if request_revision <= 0:
		errors.append("request_revision_invalid")
	if page_delta not in [-1, 0, 1]:
		errors.append("page_delta_invalid")
	if stable_item_id.is_empty():
		errors.append("stable_item_id_missing")
	if not _domain_view_valid():
		errors.append("domain_view_invalid")
	if domain == "card":
		var normalized_filter := filter_id if not filter_id.is_empty() else "all"
		if not VALID_CARD_FILTERS.has(normalized_filter):
			errors.append("filter_id_invalid")
	elif not filter_id.is_empty():
		errors.append("filter_not_allowed")
	if view in ["preview", "detail"] and optional_index < 0 and stable_item_id in ["hub", "catalog"]:
		errors.append("item_identity_invalid")
	if not _context_valid():
		errors.append("public_context_invalid")
	return {"valid": errors.is_empty(), "errors": errors}


func to_public_dictionary() -> Dictionary:
	return {
		"domain": domain,
		"view": view,
		"stable_item_id": stable_item_id,
		"optional_index": optional_index,
		"filter_id": filter_id,
		"page_delta": page_delta,
		"return_target": return_target,
		"request_revision": request_revision,
		"public_source_context": public_source_context.duplicate(true),
	}


func canonical_key() -> String:
	return "%d|%s|%s|%s|%d|%s|%d|%s" % [
		request_revision,
		domain,
		view,
		stable_item_id,
		optional_index,
		filter_id,
		page_delta,
		return_target,
	]


func _domain_view_valid() -> bool:
	match domain:
		"compendium":
			return view == "hub"
		"role", "region":
			return view == "detail"
		"card", "monster", "product":
			return view in ["browser", "preview", "detail"]
	return false


func _context_valid() -> bool:
	var keys := public_source_context.keys()
	for key_variant: Variant in keys:
		var key := str(key_variant)
		if not VALID_CONTEXT_KEYS.has(key):
			return false
		var value: Variant = public_source_context[key_variant]
		if value is Callable or typeof(value) == TYPE_OBJECT:
			return false
	if public_source_context.has("origin") and not VALID_ORIGINS.has(str(public_source_context.get("origin", ""))):
		return false
	if public_source_context.has("push_current") and not (public_source_context.get("push_current") is bool):
		return false
	if public_source_context.has("pop_stack") and not (public_source_context.get("pop_stack") is bool):
		return false
	return true
