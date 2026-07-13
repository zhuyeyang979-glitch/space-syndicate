@tool
extends Node
class_name CodexNavigationRuntimeController

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
		"return_target": return_target,
		"monster": domain_state("monster"),
		"card": domain_state("card"),
		"product": domain_state("product"),
		"region": domain_state("region"),
		"role": domain_state("role"),
	}


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
	}


func _normalize_navigation_ids() -> void:
	if not VALID_MODES.has(catalog_mode):
		catalog_mode = ""
	if not VALID_RETURN_TARGETS.has(return_target):
		return_target = "main"
	if card_codex_filter.is_empty():
		card_codex_filter = "all"
