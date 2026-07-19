@tool
extends Node
class_name IntelDossierViewerQueryPort

const SCHEMA_VERSION := 2
const MAX_PUBLIC_REGIONS := 32

@export var local_viewer_authorization_path: NodePath
@export var world_session_state_path: NodePath
@export var card_history_public_query_path: NodePath
@export var card_history_annotation_service_path: NodePath
@export var role_catalog_path: NodePath
@export var region_codex_public_source_path: NodePath
@export var snapshot_service_path: NodePath

var _query_count := 0
var _denied_count := 0
var _invalid_output_count := 0
var _owner_mutation_delta := 0


func _ready() -> void:
	var service := _snapshot_service()
	if service != null:
		service.configure()


func snapshot_for_authorized_viewer(focused_history_entry_id: String = "", focused_region_id: String = "") -> Dictionary:
	_query_count += 1
	if not _dependencies_ready():
		return _denied("intel_query_dependency_missing")
	var context := _authorization().context()
	if not context.authorized:
		return _denied("local_viewer_unauthorized")
	var viewer_index := context.viewer_index
	var owner_debug_before := _world().debug_snapshot()
	var annotation_revision_before: int = int(_annotation_service().debug_snapshot().get("revision", 0))
	var public_world := _world().public_intel_projection()
	var inference := _world().city_inference_projection(viewer_index)
	var public_history := _history_query().compose_history()
	var annotation_projection := _annotation_service().viewer_snapshot(viewer_index)
	var public_players: Array = public_world.get("players", []) if public_world.get("players", []) is Array else []
	var public_world_intel := _public_world_intel(public_world, focused_region_id)
	var own_city_entries := _city_entries(public_world, inference, focused_region_id)
	var public_card_entries := _public_card_entries(public_history)
	var presentation_card_entries := _card_entries(public_card_entries, annotation_projection)
	var role_definition := _viewer_role_definition(public_players, viewer_index)
	var role_usage := _annotation_service().role_usage_snapshot(viewer_index)
	var city_owner_revision := str(inference.get("owner_revision", ""))
	var annotation_owner_revision := _annotation_service().owner_revision_for_viewer(viewer_index)
	var source := {
		"valid": true,
		"viewer_index": viewer_index,
		"viewer_name": str(inference.get("viewer_name", "玩家%d" % (viewer_index + 1))),
		"public_players": _detached_array(public_players),
		"public_world_intel": public_world_intel,
		"city_entries": own_city_entries,
		"card_entries": presentation_card_entries,
		"city_owner_revision": city_owner_revision,
		"annotation_owner_revision": annotation_owner_revision,
		"focused_history_entry_id": _canonical_focus(focused_history_entry_id),
		"role_definition": role_definition,
		"role_usage": role_usage,
	}
	var presentation := _snapshot_service().compose(source)
	var result := {
		"schema_version": SCHEMA_VERSION,
		"valid": true,
		"visibility_scope": "authorized_local_viewer",
		"viewer_index": viewer_index,
		"public_world_intel": public_world_intel,
		"own_private_city_or_facility_inference": {
			"visibility_scope": "viewer_private",
			"viewer_index": viewer_index,
			"owner_revision": city_owner_revision,
			"city_entries": own_city_entries,
			"facility_inference_entries": [],
		},
		"public_card_history": public_card_entries,
		"own_private_card_annotations": annotation_projection,
		"role_intel_capabilities": {
			"public_definition": role_definition,
			"own_role_usage": role_usage,
		},
		"public_navigation_links": presentation.get("public_navigation_links", []),
		"city_owner_revision": city_owner_revision,
		"annotation_owner_revision": annotation_owner_revision,
		"public_player_facts": source.get("public_players", []),
		"city_inference_projection": own_city_entries,
		"viewer_annotation_projection": annotation_projection,
		"role_public_definition": role_definition,
		"role_usage_projection": role_usage,
		"summary_text": str(presentation.get("summary_text", "")),
		"board": presentation.get("board", {}),
	}
	var owner_debug_after := _world().debug_snapshot()
	_owner_mutation_delta += int(owner_debug_after.get("city_inference_mutation_count", 0)) - int(owner_debug_before.get("city_inference_mutation_count", 0))
	_owner_mutation_delta += int(_annotation_service().debug_snapshot().get("revision", 0)) - annotation_revision_before
	if not TablePresentationPureDataPolicy.is_pure_data(result) or _contains_forbidden_output_key(result):
		_invalid_output_count += 1
		return _denied("intel_query_output_policy_rejected")
	return TablePresentationPureDataPolicy.detached_copy(result) as Dictionary


func debug_snapshot() -> Dictionary:
	return {
		"port_id": "intel_dossier_viewer_query_port_v2",
		"query_count": _query_count,
		"denied_count": _denied_count,
		"invalid_output_count": _invalid_output_count,
		"owner_mutation_delta": _owner_mutation_delta,
		"authorized_local_viewer_required": true,
		"detached_pure_data": true,
		"reads_public_world_projection": true,
		"reads_region_codex_public_source_only": true,
		"reads_viewer_city_inference_only": true,
		"reads_public_card_history": true,
		"reads_viewer_annotations_only": true,
		"reads_role_public_definition": true,
		"reads_opponent_cash": false,
		"reads_opponent_hand": false,
		"reads_opponent_guesses": false,
		"reads_opponent_annotations": false,
		"reads_hidden_city_owner": false,
		"reads_raw_monsters": false,
		"reads_raw_warehouse_inventory": false,
		"reads_private_economy_query": false,
		"reads_ai_state": false,
		"refreshes_route_network": false,
		"references_main": false,
	}


func _public_world_intel(public_world: Dictionary, focused_region_id: String) -> Array:
	var result: Array = []
	var regions: Array = public_world.get("regions", []) if public_world.get("regions", []) is Array else []
	for region_variant in regions.slice(0, mini(MAX_PUBLIC_REGIONS, regions.size())):
		if not (region_variant is Dictionary):
			continue
		var world_region := region_variant as Dictionary
		var district_index := int(world_region.get("district_index", -1))
		if district_index < 0:
			continue
		var public_source := _region_public_source().compose_source(district_index)
		if public_source.is_empty() or not bool(public_source.get("valid", false)) or int(public_source.get("index", -1)) != district_index:
			continue
		var region_stable_item_id := _region_public_source().stable_item_id_at(district_index)
		var public_facility_entries := _public_facility_rows(public_source.get("facility_entries", []))
		var facility_counts := _anonymous_facility_counts(public_facility_entries)
		var product_ids := _canonical_public_ids(public_source.get("products", []))
		result.append({
			"district_index": district_index,
			"region_id": str(world_region.get("region_id", "")),
			"region_stable_item_id": region_stable_item_id,
			"name": str(public_source.get("name", "区域")),
			"terrain_label": str(public_source.get("terrain_label", "区域")),
			"economic_focus_label": str(public_source.get("economic_focus_label", "均衡")),
			"destroyed": bool(public_source.get("destroyed", false)),
			"facility_count": _sum_counts(facility_counts),
			"anonymous_warehouse_count": int(facility_counts.get("warehouse", 0)),
			"anonymous_facility_type_counts": facility_counts,
			"public_facility_entries": public_facility_entries,
			"supply_product_ids": product_ids,
			"supply_text": str(public_source.get("supply_text", "无")),
			"demand_text": str(public_source.get("demand_text", "无")),
			"weather_text": str(public_source.get("weather_text", "暂无")),
			"trade_route_load": maxi(0, int(public_source.get("trade_route_load", 0))),
			"connection_summary": str(public_source.get("connection_summary", "无邻接")),
			"public_clue": str(public_source.get("public_clue", "暂无公开线索")),
			"monster_attraction_entries": _public_monster_attraction(public_source.get("monster_entries", [])),
		})
	var canonical_focus := focused_region_id if _world().district_index_for_region_id(focused_region_id) >= 0 else ""
	if not canonical_focus.is_empty():
		for index in range(result.size()):
			if str((result[index] as Dictionary).get("region_id", "")) == canonical_focus:
				var focused_entry: Dictionary = result.pop_at(index)
				result.push_front(focused_entry)
				break
	return result


func _anonymous_facility_counts(value: Variant) -> Dictionary:
	var counts: Dictionary = {}
	if not (value is Array):
		return counts
	for facility_variant in value as Array:
		if not (facility_variant is Dictionary):
			continue
		var facility_type := str((facility_variant as Dictionary).get("facility_type", "")).strip_edges()
		if facility_type.is_empty() or facility_type.length() > 48:
			continue
		counts[facility_type] = int(counts.get(facility_type, 0)) + 1
	return counts


func _public_facility_rows(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for facility_variant in value as Array:
		if not (facility_variant is Dictionary):
			continue
		var facility := facility_variant as Dictionary
		var row := {
			"facility_type": str(facility.get("facility_type", "")),
			"industry_id": str(facility.get("industry_id", "")),
			"owner_kind": str(facility.get("owner_kind", "")),
			"owner_player_index": int(facility.get("owner_player_index", -1)),
			"rank": maxi(0, int(facility.get("rank", 0))),
		}
		if _is_public_facility_projection(row):
			result.append(row)
	return result


func _public_monster_attraction(value: Variant) -> Array:
	var result: Array = []
	if not (value is Array):
		return result
	for entry_variant in value as Array:
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		var monster_name := str(entry.get("name", "")).strip_edges()
		var reason := str(entry.get("reason", "")).strip_edges()
		if monster_name.is_empty() or reason.is_empty():
			continue
		var catalog_index := MonsterCatalogV06.monster_catalog_index_by_name(monster_name)
		var stable_item_id := "monster:%d" % catalog_index if catalog_index >= 0 and catalog_index < MonsterCatalogV06.catalog_size() else ""
		result.append({
			"name": monster_name,
			"reason": reason,
			"factor_codes": _canonical_public_ids(entry.get("factor_codes", [])),
			"stable_item_id": stable_item_id,
		})
	return result


func _city_entries(public_world: Dictionary, inference: Dictionary, focused_region_id: String) -> Array:
	var allowed_region_ids: Array = inference.get("foreign_active_region_ids", []) if inference.get("foreign_active_region_ids", []) is Array else []
	var records_by_region: Dictionary = {}
	for record_variant in inference.get("records", []) if inference.get("records", []) is Array else []:
		if record_variant is Dictionary:
			var record := record_variant as Dictionary
			records_by_region[str(record.get("region_id", ""))] = record
	var result: Array = []
	var regions: Array = public_world.get("regions", []) if public_world.get("regions", []) is Array else []
	for region_variant in regions:
		if not (region_variant is Dictionary):
			continue
		var region := region_variant as Dictionary
		var region_id := str(region.get("region_id", ""))
		if not allowed_region_ids.has(region_id):
			continue
		var record: Dictionary = records_by_region.get(region_id, {}) if records_by_region.get(region_id, {}) is Dictionary else {}
		result.append({
			"district_index": int(region.get("district_index", -1)),
			"region_id": region_id,
			"name": str(region.get("name", "区域")),
			"terrain": str(region.get("terrain", "land")),
			"products": _detached_array(region.get("products", [])),
			"demands": _detached_array(region.get("demands", [])),
			"damage": int(region.get("damage", 0)),
			"city_level": int(region.get("city_level", 0)),
			"city_products": _detached_array(region.get("city_products", [])),
			"city_demands": _detached_array(region.get("city_demands", [])),
			"city_last_income": int(region.get("city_last_income", 0)),
			"city_competition_matches": int(region.get("city_competition_matches", 0)),
			"suspected_player_index": int(record.get("suspected_player_index", -1)),
			"confidence": int(record.get("confidence", 0)),
			"reason_id": str(record.get("reason_id", "")),
			"authorized_reveal": bool(record.get("authorized_reveal", false)),
		})
	var canonical_focus := focused_region_id if _world().district_index_for_region_id(focused_region_id) >= 0 else ""
	if not canonical_focus.is_empty():
		for index in range(result.size()):
			if str((result[index] as Dictionary).get("region_id", "")) == canonical_focus:
				var focused_entry: Dictionary = result.pop_at(index)
				result.push_front(focused_entry)
				break
	return result


func _public_card_entries(public_history: Dictionary) -> Array:
	var entries: Array = public_history.get("entries", []) if public_history.get("entries", []) is Array else []
	return _detached_array(entries)


func _card_entries(public_entries: Array, annotation_projection: Dictionary) -> Array:
	var annotations_by_id: Dictionary = {}
	var annotations: Array = annotation_projection.get("annotations", []) if annotation_projection.get("annotations", []) is Array else []
	for annotation_variant in annotations:
		if annotation_variant is Dictionary:
			var annotation := annotation_variant as Dictionary
			annotations_by_id[str(annotation.get("history_entry_id", ""))] = annotation
	var result: Array = []
	for entry_variant in public_entries:
		if not (entry_variant is Dictionary):
			continue
		var entry := (entry_variant as Dictionary).duplicate(true)
		var history_entry_id := str(entry.get("history_entry_id", ""))
		entry["viewer_annotation"] = (annotations_by_id.get(history_entry_id, {}) as Dictionary).duplicate(true) if annotations_by_id.get(history_entry_id, {}) is Dictionary else {}
		result.append(entry)
	return result


func _viewer_role_definition(public_players: Array, viewer_index: int) -> Dictionary:
	for player_variant in public_players:
		if not (player_variant is Dictionary):
			continue
		var player := player_variant as Dictionary
		if int(player.get("player_index", -1)) == viewer_index:
			return _roles().public_definition_at(int(player.get("role_index", -1)))
	return {}


func _canonical_focus(history_entry_id: String) -> String:
	var normalized := history_entry_id.strip_edges()
	if normalized.is_empty() or normalized != history_entry_id:
		return ""
	return normalized if not _history_query().entry_by_id(normalized).is_empty() else ""


func _canonical_public_ids(value: Variant) -> Array:
	var result: Array[String] = []
	if not (value is Array):
		return result
	for item_variant in value as Array:
		if not (item_variant is String or item_variant is StringName):
			continue
		var item := str(item_variant).strip_edges()
		if not item.is_empty() and item.length() <= 96 and not result.has(item):
			result.append(item)
	return result


func _sum_counts(counts: Dictionary) -> int:
	var result := 0
	for value_variant in counts.values():
		result += maxi(0, int(value_variant))
	return result


func _detached_array(value: Variant) -> Array:
	if not (value is Array) or not TablePresentationPureDataPolicy.is_pure_data(value):
		return []
	return TablePresentationPureDataPolicy.detached_copy(value) as Array


func _contains_forbidden_output_key(value: Variant) -> bool:
	if value is Dictionary:
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			if key == "owner_player_index" and not _is_public_facility_projection(value as Dictionary):
				return true
			if key in [
				"cash", "cash_cents", "exact_cash", "hand", "slots", "private_hand",
				"city_guesses", "city_guess_confidence", "city_guess_reasons",
				"owner", "owner_index", "hidden_owner", "true_owner",
				"raw_monsters", "auto_monsters", "warehouse_inventory", "inventory",
				"ai_state", "ai_memory", "price", "current_price", "base_price",
			]:
				return true
			if _contains_forbidden_output_key((value as Dictionary)[key_variant]):
				return true
	elif value is Array:
		for child_variant in value as Array:
			if _contains_forbidden_output_key(child_variant):
				return true
	return false


func _is_public_facility_projection(value: Dictionary) -> bool:
	var keys := value.keys()
	keys.sort()
	var expected := ["facility_type", "industry_id", "owner_kind", "owner_player_index", "rank"]
	expected.sort()
	if keys != expected:
		return false
	return not str(value.get("facility_type", "")).is_empty() \
		and str(value.get("owner_kind", "")) in ["player", "neutral"] \
		and int(value.get("owner_player_index", -2)) >= -1 \
		and int(value.get("rank", -1)) >= 0


func _denied(reason_code: String) -> Dictionary:
	_denied_count += 1
	return {
		"schema_version": SCHEMA_VERSION,
		"valid": false,
		"visibility_scope": "none",
		"reason_code": reason_code,
		"public_world_intel": [],
		"own_private_city_or_facility_inference": {},
		"public_card_history": [],
		"own_private_card_annotations": {},
		"role_intel_capabilities": {},
		"public_navigation_links": [],
		"summary_text": "暂无当前局情报",
		"board": {},
	}


func _dependencies_ready() -> bool:
	return _authorization() != null and _world() != null and _history_query() != null \
		and _annotation_service() != null and _roles() != null and _region_public_source() != null \
		and _snapshot_service() != null


func _authorization() -> LocalViewerAuthorization:
	return get_node_or_null(local_viewer_authorization_path) as LocalViewerAuthorization


func _world() -> WorldSessionState:
	return get_node_or_null(world_session_state_path) as WorldSessionState


func _history_query() -> CardHistoryPublicQueryPort:
	return get_node_or_null(card_history_public_query_path) as CardHistoryPublicQueryPort


func _annotation_service() -> CardHistoryPrivateAnnotationService:
	return get_node_or_null(card_history_annotation_service_path) as CardHistoryPrivateAnnotationService


func _roles() -> RoleCatalogRuntimeService:
	return get_node_or_null(role_catalog_path) as RoleCatalogRuntimeService


func _region_public_source() -> RegionCodexPublicSourceService:
	return get_node_or_null(region_codex_public_source_path) as RegionCodexPublicSourceService


func _snapshot_service() -> IntelDossierPublicSnapshotService:
	return get_node_or_null(snapshot_service_path) as IntelDossierPublicSnapshotService
