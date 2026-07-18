@tool
extends Node
class_name CodexNavigationRuntimeController

const CODEX_OPEN_REQUEST_SCRIPT := preload("res://scripts/runtime/codex_open_request.gd")

const VALID_MODES := ["", "compendium", "card", "monster", "product", "region", "role"]
const VALID_RETURN_TARGETS := ["main", "compendium", "intel", "economy", "standings", "game"]

var catalog_mode := ""
var return_target := "main"
var bestiary_index := 0
var bestiary_grid_page := 0
var bestiary_show_detail := false
var previewed_bestiary_index := 0
var card_codex_index := 0
var card_codex_filter := "all"
var card_codex_grid_page := 0
var card_codex_show_detail := false
var previewed_card_codex_card := ""
var product_codex_index := 0
var product_codex_grid_page := 0
var product_codex_show_detail := false
var previewed_product_codex_index := 0
var region_codex_index := 0
var role_codex_index := 0

var _configured := false
var _current_view := "hub"
var _stable_item_id := "hub"
var _location_stack: Array[Dictionary] = []
var _transition_count := 0
var _rejected_transition_count := 0


func configure(_config: Dictionary = {}) -> void:
	_configured = true
	_normalize_navigation_ids()


func reset_navigation() -> void:
	catalog_mode = ""
	return_target = "main"
	bestiary_index = 0
	bestiary_grid_page = 0
	bestiary_show_detail = false
	previewed_bestiary_index = 0
	card_codex_index = 0
	card_codex_filter = "all"
	card_codex_grid_page = 0
	card_codex_show_detail = false
	previewed_card_codex_card = ""
	product_codex_index = 0
	product_codex_grid_page = 0
	product_codex_show_detail = false
	previewed_product_codex_index = 0
	region_codex_index = 0
	role_codex_index = 0
	_current_view = "hub"
	_stable_item_id = "hub"
	_location_stack.clear()


func set_catalog_mode(mode: String) -> String:
	catalog_mode = mode if VALID_MODES.has(mode) else ""
	return catalog_mode


func set_return_target(target: String) -> String:
	return_target = target if VALID_RETURN_TARGETS.has(target) else "main"
	return return_target


func domain_state(domain: String) -> Dictionary:
	match domain:
		"monster":
			return {
				"selected_index": bestiary_index,
				"page_index": bestiary_grid_page,
				"show_detail": bestiary_show_detail,
				"preview_index": previewed_bestiary_index,
			}
		"card":
			return {
				"selected_index": card_codex_index,
				"filter_id": card_codex_filter,
				"page_index": card_codex_grid_page,
				"show_detail": card_codex_show_detail,
				"preview_id": previewed_card_codex_card,
			}
		"product":
			return {
				"selected_index": product_codex_index,
				"page_index": product_codex_grid_page,
				"show_detail": product_codex_show_detail,
				"preview_index": previewed_product_codex_index,
			}
		"region":
			return {"selected_index": region_codex_index}
		"role":
			return {"selected_index": role_codex_index}
	return {}


func update_domain(domain: String, patch: Dictionary) -> Dictionary:
	match domain:
		"monster":
			bestiary_index = int(patch.get("selected_index", bestiary_index))
			bestiary_grid_page = int(patch.get("page_index", bestiary_grid_page))
			bestiary_show_detail = bool(patch.get("show_detail", bestiary_show_detail))
			previewed_bestiary_index = int(patch.get("preview_index", previewed_bestiary_index))
		"card":
			card_codex_index = int(patch.get("selected_index", card_codex_index))
			card_codex_filter = str(patch.get("filter_id", card_codex_filter))
			card_codex_grid_page = int(patch.get("page_index", card_codex_grid_page))
			card_codex_show_detail = bool(patch.get("show_detail", card_codex_show_detail))
			previewed_card_codex_card = str(patch.get("preview_id", previewed_card_codex_card))
		"product":
			product_codex_index = int(patch.get("selected_index", product_codex_index))
			product_codex_grid_page = int(patch.get("page_index", product_codex_grid_page))
			product_codex_show_detail = bool(patch.get("show_detail", product_codex_show_detail))
			previewed_product_codex_index = int(patch.get("preview_index", previewed_product_codex_index))
		"region":
			region_codex_index = int(patch.get("selected_index", region_codex_index))
		"role":
			role_codex_index = int(patch.get("selected_index", role_codex_index))
	return domain_state(domain)


func page_count(total_count: int, entries_per_page: int) -> int:
	return maxi(1, int(ceil(float(maxi(0, total_count)) / float(maxi(1, entries_per_page)))))


func page_for_index(index: int, total_count: int, entries_per_page: int) -> int:
	var page_index := int(floor(float(maxi(0, index)) / float(maxi(1, entries_per_page))))
	return clampi(page_index, 0, page_count(total_count, entries_per_page) - 1)


func first_index_on_page(page_index: int, total_count: int, entries_per_page: int) -> int:
	return clampi(page_index * maxi(1, entries_per_page), 0, max(0, total_count - 1))


func navigation_snapshot() -> Dictionary:
	return {
		"catalog_mode": catalog_mode,
		"current_view": _current_view,
		"stable_item_id": _stable_item_id,
		"return_target": return_target,
		"stack_depth": _location_stack.size(),
		"monster": domain_state("monster"),
		"card": domain_state("card"),
		"product": domain_state("product"),
		"region": domain_state("region"),
		"role": domain_state("role"),
	}


func apply_request(request: CODEX_OPEN_REQUEST_SCRIPT, resolved_context: Dictionary) -> Dictionary:
	if request == null or not bool(request.validation_report().get("valid", false)) or not _resolved_context_valid(resolved_context):
		_rejected_transition_count += 1
		return {"accepted": false, "reason": "request_or_context_invalid"}
	if bool(request.public_source_context.get("push_current", false)):
		_push_current_location()
	if bool(request.public_source_context.get("pop_stack", false)):
		if _location_stack.is_empty():
			_rejected_transition_count += 1
			return {"accepted": false, "reason": "navigation_stack_empty"}
		_location_stack.pop_back()
	set_return_target(request.return_target)
	set_catalog_mode(request.domain)
	_current_view = "browser" if request.view == "preview" else request.view
	_stable_item_id = str(resolved_context.get("stable_item_id", request.stable_item_id))
	var selected_index := int(resolved_context.get("selected_index", request.optional_index))
	var page_index := maxi(0, int(resolved_context.get("page_index", 0)))
	match request.domain:
		"compendium":
			_current_view = "hub"
			_stable_item_id = "hub"
		"role":
			role_codex_index = selected_index
		"region":
			region_codex_index = selected_index
		"card":
			card_codex_filter = str(resolved_context.get("filter_id", request.filter_id if not request.filter_id.is_empty() else card_codex_filter))
			card_codex_index = selected_index
			card_codex_grid_page = page_index
			card_codex_show_detail = request.view == "detail"
			previewed_card_codex_card = _stable_item_id
		"monster":
			bestiary_index = selected_index
			previewed_bestiary_index = selected_index
			bestiary_grid_page = page_index
			bestiary_show_detail = request.view == "detail"
		"product":
			product_codex_index = selected_index
			previewed_product_codex_index = selected_index
			product_codex_grid_page = page_index
			product_codex_show_detail = request.view == "detail"
	_transition_count += 1
	return {"accepted": true, "kind": "navigation", "navigation": navigation_snapshot()}


func back_request_spec() -> Dictionary:
	if not _location_stack.is_empty():
		var location: Dictionary = _location_stack.back()
		var location_domain := str(location.get("catalog_mode", "compendium"))
		return {
			"kind": "navigation",
			"domain": location_domain,
			"view": str(location.get("current_view", "hub")),
			"stable_item_id": str(location.get("stable_item_id", "hub")),
			"optional_index": _location_selected_index(location),
			"filter_id": str((location.get("card", {}) as Dictionary).get("filter_id", "all")) if location_domain == "card" and location.get("card", {}) is Dictionary else "",
			"return_target": str(location.get("return_target", "compendium")),
			"public_source_context": {"origin": "compendium", "pop_stack": true},
		}
	if catalog_mode in ["card", "monster", "product"] and _current_view == "detail":
		return {
			"kind": "navigation", "domain": catalog_mode, "view": "browser",
			"stable_item_id": _stable_item_id, "optional_index": int(domain_state(catalog_mode).get("selected_index", -1)),
			"filter_id": card_codex_filter if catalog_mode == "card" else "",
			"return_target": return_target, "public_source_context": {"origin": "compendium"},
		}
	return {"kind": "return", "target": return_target}


func back() -> Dictionary:
	if not _location_stack.is_empty():
		var location: Dictionary = _location_stack.pop_back()
		_restore_location(location)
		_transition_count += 1
		return {"accepted": true, "kind": "navigation", "navigation": navigation_snapshot(), "restored_link": true}
	if catalog_mode in ["card", "monster", "product"] and _current_view == "detail":
		_current_view = "browser"
		match catalog_mode:
			"card": card_codex_show_detail = false
			"monster": bestiary_show_detail = false
			"product": product_codex_show_detail = false
		_transition_count += 1
		return {"accepted": true, "kind": "navigation", "navigation": navigation_snapshot()}
	return {"accepted": true, "kind": "return", "target": return_target}


func to_legacy_save_snapshot() -> Dictionary:
	return {
		"bestiary_index": bestiary_index,
		"bestiary_grid_page": bestiary_grid_page,
		"bestiary_show_detail": bestiary_show_detail,
		"previewed_bestiary_index": previewed_bestiary_index,
		"card_codex_index": card_codex_index,
		"card_codex_filter": card_codex_filter,
		"product_codex_index": product_codex_index,
		"product_codex_grid_page": product_codex_grid_page,
		"product_codex_show_detail": product_codex_show_detail,
		"previewed_product_codex_index": previewed_product_codex_index,
		"region_codex_index": region_codex_index,
		"role_codex_index": role_codex_index,
	}


func apply_legacy_save_snapshot(snapshot: Dictionary) -> Dictionary:
	bestiary_index = int(snapshot.get("bestiary_index", 0))
	bestiary_grid_page = int(snapshot.get("bestiary_grid_page", 0))
	bestiary_show_detail = bool(snapshot.get("bestiary_show_detail", false))
	previewed_bestiary_index = int(snapshot.get("previewed_bestiary_index", bestiary_index))
	card_codex_index = int(snapshot.get("card_codex_index", 0))
	card_codex_filter = str(snapshot.get("card_codex_filter", "all"))
	product_codex_index = int(snapshot.get("product_codex_index", 0))
	product_codex_grid_page = int(snapshot.get("product_codex_grid_page", 0))
	product_codex_show_detail = bool(snapshot.get("product_codex_show_detail", false))
	previewed_product_codex_index = int(snapshot.get("previewed_product_codex_index", product_codex_index))
	region_codex_index = int(snapshot.get("region_codex_index", 0))
	role_codex_index = int(snapshot.get("role_codex_index", 0))
	_normalize_navigation_ids()
	return to_legacy_save_snapshot()


func debug_snapshot() -> Dictionary:
	return {
		"controller_ready": _configured,
		"controller_authoritative": _configured,
		"legacy_main_authority_active": false,
		"navigation": navigation_snapshot(),
		"legacy_save": to_legacy_save_snapshot(),
		"transition_count": _transition_count,
		"rejected_transition_count": _rejected_transition_count,
		"location_stack_depth": _location_stack.size(),
		"owns_navigation_stack": true,
		"reads_gameplay_world": false,
	}


func _normalize_navigation_ids() -> void:
	if not VALID_MODES.has(catalog_mode):
		catalog_mode = ""
	if not VALID_RETURN_TARGETS.has(return_target):
		return_target = "main"
	if card_codex_filter.is_empty():
		card_codex_filter = "all"


func _resolved_context_valid(context: Dictionary) -> bool:
	var allowed := [
		"valid", "stable_item_id", "selected_index", "page_index", "page_count", "entries_per_page",
		"total_count", "filter_id", "return_target", "start_index", "end_index", "columns", "rows",
		"can_step", "page_label",
	]
	for key_variant: Variant in context:
		if not allowed.has(str(key_variant)):
			return false
		var value: Variant = context[key_variant]
		if value is Callable or typeof(value) == TYPE_OBJECT:
			return false
	return bool(context.get("valid", false)) and not str(context.get("stable_item_id", "")).is_empty()


func _push_current_location() -> void:
	var location := navigation_snapshot()
	location.erase("stack_depth")
	_location_stack.append(location)


func _restore_location(location: Dictionary) -> void:
	catalog_mode = str(location.get("catalog_mode", "compendium"))
	_current_view = str(location.get("current_view", "hub"))
	_stable_item_id = str(location.get("stable_item_id", "hub"))
	return_target = str(location.get("return_target", "compendium"))
	var monster: Dictionary = location.get("monster", {}) if location.get("monster", {}) is Dictionary else {}
	var card: Dictionary = location.get("card", {}) if location.get("card", {}) is Dictionary else {}
	var product: Dictionary = location.get("product", {}) if location.get("product", {}) is Dictionary else {}
	var region: Dictionary = location.get("region", {}) if location.get("region", {}) is Dictionary else {}
	var role: Dictionary = location.get("role", {}) if location.get("role", {}) is Dictionary else {}
	bestiary_index = int(monster.get("selected_index", bestiary_index))
	bestiary_grid_page = int(monster.get("page_index", bestiary_grid_page))
	bestiary_show_detail = bool(monster.get("show_detail", bestiary_show_detail))
	previewed_bestiary_index = int(monster.get("preview_index", previewed_bestiary_index))
	card_codex_index = int(card.get("selected_index", card_codex_index))
	card_codex_filter = str(card.get("filter_id", card_codex_filter))
	card_codex_grid_page = int(card.get("page_index", card_codex_grid_page))
	card_codex_show_detail = bool(card.get("show_detail", card_codex_show_detail))
	previewed_card_codex_card = str(card.get("preview_id", previewed_card_codex_card))
	product_codex_index = int(product.get("selected_index", product_codex_index))
	product_codex_grid_page = int(product.get("page_index", product_codex_grid_page))
	product_codex_show_detail = bool(product.get("show_detail", product_codex_show_detail))
	previewed_product_codex_index = int(product.get("preview_index", previewed_product_codex_index))
	region_codex_index = int(region.get("selected_index", region_codex_index))
	role_codex_index = int(role.get("selected_index", role_codex_index))


func _location_selected_index(location: Dictionary) -> int:
	var domain := str(location.get("catalog_mode", ""))
	var state: Dictionary = location.get(domain, {}) if location.get(domain, {}) is Dictionary else {}
	return int(state.get("selected_index", -1))
