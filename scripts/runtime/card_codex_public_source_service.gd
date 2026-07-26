@tool
extends Node
class_name CardCodexPublicSourceService

const SOURCE_ADAPTER_SCRIPT := preload(
	"res://scripts/runtime/card_codex_public_source_adapter.gd"
)
const CARD_SEMANTIC_SCHEMA := preload(
	"res://scripts/cards/semantic/card_semantic_schema_v1.gd"
)
const PLAYER_CARD_CODEX_DTO := preload(
	"res://scripts/presentation/player_card_codex_dto_v1.gd"
)
const PLAYER_CARD_CODEX_FAMILY_LADDER_DTO := preload(
	"res://scripts/presentation/player_card_codex_family_ladder_dto_v1.gd"
)

const DEPENDENCY_KEYS := [
	"player_face_projection",
	"public_localization_source",
	"semantic_catalog",
	"snapshot",
]
const FILTER_ORDER := [
	"commodity",
	"facility",
	"supply_demand",
	"monster",
	"military",
	"interaction",
	"organization",
]
const PUBLIC_AUTHORIZATION_SCHEMA_VERSION := 1
const PUBLIC_SOURCE_KIND := "codex_public_catalog"
const PUBLIC_VISIBILITY_SCOPE_ID := "public"

@export var public_catalog_v06: CardRuntimeCatalogV06Resource

var _snapshot: CardCodexPublicSnapshotService
var _semantic_catalog: CardSemanticCatalogService
var _player_face_projection: CardPlayerFaceProjectionService
var _public_localization_source: CardPlayerFacePublicLocalizationSourceService
var _adapter: RefCounted = SOURCE_ADAPTER_SCRIPT.new()
var _dependencies_bound := false
var _configured := false
var _last_error := "dependencies_not_configured"
var _ordered_ids: Array[String] = []
var _ids_by_category: Dictionary = {}
var _dto_by_card_id: Dictionary = {}
var _family_id_by_card_id: Dictionary = {}
var _ladder_by_family_id: Dictionary = {}
var _facts_by_card_id: Dictionary = {}
var _upgrade_facts_by_family_id: Dictionary = {}
var _filter_meta_by_category: Dictionary = {}
var _source_compose_count := 0
var _browser_compose_count := 0
var _detail_compose_count := 0
var _dto_projection_count := 0
var _dto_cache_hit_count := 0
var _facts_cache_hit_count := 0
var _family_ladder_cache_hit_count := 0
var _catalog_snapshot_count := 0
var _catalog_record_authorization_count := 0
var _localization_issue_count := 0
var _semantic_compile_delta := 0
var _page_fact_build_count := 0
var _stable_identity_rejection_count := 0
var _monster_codex_compatibility_lookup_count := 0
var _initialization_timings_usec: Dictionary = {}


func bind_dependencies(dependencies: Dictionary) -> Dictionary:
	if _dependencies_bound:
		if _dependencies_match(dependencies):
			_last_error = ""
			return debug_snapshot()
		_last_error = "dependency_rebind_rejected"
		return debug_snapshot()
	_clear_dependencies()
	var keys := dependencies.keys()
	keys.sort()
	var expected := DEPENDENCY_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		_last_error = "dependency_keys_invalid"
		return debug_snapshot()
	_snapshot = dependencies.get("snapshot") as CardCodexPublicSnapshotService
	_semantic_catalog = dependencies.get("semantic_catalog") \
		as CardSemanticCatalogService
	_player_face_projection = dependencies.get("player_face_projection") \
		as CardPlayerFaceProjectionService
	_public_localization_source = dependencies.get("public_localization_source") \
		as CardPlayerFacePublicLocalizationSourceService
	if _snapshot == null or not _snapshot.has_method("compose_browser") \
			or not _snapshot.has_method("compose_detail"):
		return _configuration_failure("snapshot_service_invalid")
	if _semantic_catalog == null \
			or not _semantic_catalog.has_method("authorize_public_codex_record") \
			or not _semantic_catalog.has_method("validation_snapshot"):
		return _configuration_failure("semantic_catalog_invalid")
	if _player_face_projection == null \
			or not _player_face_projection.has_method(
				"project_authorized_public_detail"
			):
		return _configuration_failure("player_face_projection_invalid")
	if _public_localization_source == null \
			or not _public_localization_source.has_method("issue_for_exact_record") \
			or not _public_localization_source.has_method(
				"issue_verified_for_exact_record"
			) \
			or not _public_localization_source.has_method("verify_bundle"):
		return _configuration_failure("public_localization_source_invalid")
	if public_catalog_v06 == null:
		return _configuration_failure("v06_public_catalog_missing")
	_dependencies_bound = true
	_last_error = ""
	return debug_snapshot()


func configure(dependencies: Dictionary) -> Dictionary:
	bind_dependencies(dependencies)
	if not _dependencies_bound or not _dependencies_match(dependencies):
		return debug_snapshot()
	if _configured:
		return debug_snapshot()
	if not _build_projection_cache():
		return _configuration_failure(_last_error)
	_configured = true
	_last_error = ""
	return debug_snapshot()


func ordered_card_ids(filter_id: String = "all") -> Array[String]:
	if not _require_ready() or not _valid_filter_id(filter_id):
		return []
	if filter_id == "all":
		return _ordered_ids.duplicate()
	return _string_array(_ids_by_category.get(filter_id, []))


func public_filter_options() -> Array:
	if not _require_ready():
		return []
	var result: Array = [{
		"id": "all",
		"label": "全部",
		"short_label": "全部",
		"icon": "□",
		"accent": Color("#93c5fd"),
	}]
	for category_id in FILTER_ORDER:
		var meta := _dictionary(_filter_meta_by_category.get(category_id, {}))
		if meta.is_empty():
			continue
		result.append({
			"id": category_id,
			"label": str(meta.get("label", category_id)),
			"short_label": str(meta.get("label", category_id)),
			"icon": _resolve_icon_token(str(meta.get("icon_token_id", ""))),
			"accent": _resolve_color_token(str(meta.get("color_token_id", ""))),
		})
	return result


func resolve_card_id(card_identity: String) -> String:
	if not _require_ready():
		return ""
	var card_id := card_identity.strip_edges()
	if card_id == card_identity and _dto_by_card_id.has(card_id):
		return card_id
	_stable_identity_rejection_count += 1
	return ""


func legacy_monster_codex_card_id(
	monster_catalog_index: int,
	rank: int = 1
) -> String:
	if not _require_ready() or monster_catalog_index < 0 \
			or rank < 1 or rank > 4:
		return ""
	var monster_ids := _string_array(_ids_by_category.get("monster", []))
	var catalog_offset := monster_catalog_index * 4 + rank - 1
	if catalog_offset < 0 or catalog_offset >= monster_ids.size():
		return ""
	_monster_codex_compatibility_lookup_count += 1
	return monster_ids[catalog_offset]


func compose_browser_source(request: Dictionary) -> Dictionary:
	if not _require_ready() or not bool(
		_adapter.call("accepts_public_input", request)
	):
		_last_error = "browser_request_rejected"
		return {}
	var filter_id := str(request.get("filter_id", "all"))
	if not _valid_filter_id(filter_id):
		_last_error = "filter_id_invalid"
		return {}
	var requested_ids := _string_array(request.get("names", []))
	var allowed_ids := ordered_card_ids(filter_id)
	var card_ids := allowed_ids.duplicate() \
		if requested_ids.is_empty() else requested_ids
	var seen_ids: Dictionary = {}
	for card_id in card_ids:
		if seen_ids.has(card_id) or resolve_card_id(card_id) != card_id \
				or not allowed_ids.has(card_id):
			_last_error = "browser_card_id_invalid"
			return {}
		seen_ids[card_id] = true
	var columns := clampi(int(request.get("columns", 3)), 1, 6)
	var rows := maxi(1, int(request.get("rows", 1)))
	var per_page := maxi(1, columns * rows)
	var page_count := maxi(1, int(ceil(float(card_ids.size()) / float(per_page))))
	var page_index := clampi(
		int(request.get("page_index", 0)),
		0,
		maxi(0, page_count - 1)
	)
	var page_start := page_index * per_page
	var page_end := mini(card_ids.size(), page_start + per_page)
	var cards: Array = []
	for index in range(page_start, page_end):
		var facts := compose_card_facts(card_ids[index], index)
		if not bool(facts.get("valid", false)):
			_last_error = "browser_card_facts_invalid"
			return {}
		cards.append(facts)
		_page_fact_build_count += 1
	var selected_card := str(request.get("selected_card", ""))
	if selected_card.is_empty() and page_start < card_ids.size():
		selected_card = card_ids[page_start]
	if not selected_card.is_empty() and not card_ids.has(selected_card):
		_last_error = "selected_card_not_in_catalog"
		return {}
	var preview := compose_card_facts(
		selected_card,
		card_ids.find(selected_card)
	) if not selected_card.is_empty() else {}
	var source_request := {
		"names": card_ids,
		"columns": columns,
		"rows": rows,
		"page_index": page_index,
		"filter_id": filter_id,
		"filter_label": _filter_label(filter_id),
		"selected_card": selected_card,
		"icon_legend": "公开类别｜获取费用与打出费用分列",
		"run_pool_count": maxi(0, int(request.get("run_pool_count", 0))),
		"district_supply_count": maxi(
			0,
			int(request.get("district_supply_count", 0))
		),
		"filters": _filters_with_counts(),
	}
	var value: Variant = _adapter.call(
		"compose_browser_source",
		source_request,
		cards,
		preview,
		source_request["filters"]
	)
	var result := (value as Dictionary).duplicate(true) \
		if value is Dictionary else {}
	if not result.is_empty():
		_source_compose_count += 1
		_last_error = ""
	return result


func compose_browser(request: Dictionary) -> Dictionary:
	var source := compose_browser_source(request)
	if source.is_empty():
		return {}
	_browser_compose_count += 1
	return _snapshot.compose_browser(source)


func compose_card_facts(card_id: String, card_index: int = -1) -> Dictionary:
	if not _require_ready() or resolve_card_id(card_id) != card_id:
		return {"valid": false, "card_name": "", "index": card_index}
	if not _dto_by_card_id.has(card_id):
		return {"valid": false, "card_name": "", "index": card_index}
	var facts := _dictionary(_facts_by_card_id.get(card_id, {})).duplicate(true)
	if facts.is_empty():
		return {"valid": false, "card_name": "", "index": card_index}
	facts["index"] = card_index
	_dto_cache_hit_count += 1
	_facts_cache_hit_count += 1
	_family_ladder_cache_hit_count += 1
	_source_compose_count += 1
	_last_error = ""
	return facts


func compose_upgrades(card_id: String) -> Array:
	if not _require_ready() or resolve_card_id(card_id) != card_id:
		return []
	var family_id := str(_family_id_by_card_id.get(card_id, ""))
	var upgrades_value: Variant = _upgrade_facts_by_family_id.get(family_id, [])
	if not (upgrades_value is Array):
		return []
	_family_ladder_cache_hit_count += 1
	return (upgrades_value as Array).duplicate(true)


func compose_detail(card_id: String, index: int, total: int) -> Dictionary:
	if not _require_ready() or resolve_card_id(card_id) != card_id:
		return {}
	var facts := compose_card_facts(card_id, index)
	if not bool(facts.get("valid", false)):
		return {}
	var value: Variant = _adapter.call(
		"compose_detail_source",
		facts,
		compose_upgrades(card_id),
		total
	)
	var source := (value as Dictionary).duplicate(true) \
		if value is Dictionary else {}
	if source.is_empty():
		return {}
	_detail_compose_count += 1
	return _snapshot.compose_detail(source)


func public_field_schema() -> Dictionary:
	var value: Variant = _adapter.call("public_field_schema")
	return (value as Dictionary).duplicate(true) \
		if value is Dictionary else {}


func debug_snapshot() -> Dictionary:
	var report := public_catalog_v06.validation_report() \
		if public_catalog_v06 != null else {}
	return {
		"service_ready": _dependencies_bound,
		"service_authoritative": _configured,
		"dependencies_bound": _dependencies_bound,
		"projection_cache_ready": _configured,
		"last_error": _last_error,
		"dependency_allowlist": DEPENDENCY_KEYS.duplicate(),
		"dependency_count": DEPENDENCY_KEYS.size() if _dependencies_bound else 0,
		"public_catalog_schema": str(public_catalog_v06.schema_version) \
			if public_catalog_v06 != null else "",
		"public_catalog_card_count": int(report.get("card_count", 0)),
		"public_catalog_family_count": int(report.get("family_count", 0)),
		"cached_dto_count": _dto_by_card_id.size(),
		"cached_family_ladder_count": _ladder_by_family_id.size(),
		"cached_card_facts_count": _facts_by_card_id.size(),
		"cached_upgrade_facts_count": _upgrade_facts_by_family_id.size(),
		"dto_projection_count": _dto_projection_count,
		"dto_cache_hit_count": _dto_cache_hit_count,
		"facts_cache_hit_count": _facts_cache_hit_count,
		"family_ladder_cache_hit_count": _family_ladder_cache_hit_count,
		"catalog_snapshot_count": _catalog_snapshot_count,
		"catalog_reload_count": 0,
		"catalog_record_authorization_count": _catalog_record_authorization_count,
		"localization_issue_count": _localization_issue_count,
		"semantic_compile_delta": _semantic_compile_delta,
		"initialization_timings_usec": _initialization_timings_usec.duplicate(true),
		"page_fact_build_count": _page_fact_build_count,
		"stable_identity_rejection_count": _stable_identity_rejection_count,
		"monster_codex_compatibility_lookup_count": _monster_codex_compatibility_lookup_count,
		"monster_codex_compatibility_retirement": "MonsterSemanticSpec supplies stable card_family_id",
		"source_compose_count": _source_compose_count,
		"browser_compose_count": _browser_compose_count,
		"detail_compose_count": _detail_compose_count,
		"owns_public_source_assembly": true,
		"owns_rules": false,
		"owns_save_state": false,
		"has_save_api": false,
		"reads_world_bridge": false,
		"reads_private_world": false,
		"reads_player_state": false,
		"reads_legacy_v04_catalog": false,
		"uses_catalog_owned_semantic": true,
		"uses_owner_attested_localization": true,
		"uses_player_card_codex_dto_v1": true,
		"illustration_catalog_ready": _illustration_catalog() != null \
			and bool(_illustration_catalog().validation_report().get("valid", false)),
		"adapter": _adapter.call("debug_snapshot"),
	}


func _build_projection_cache() -> bool:
	var initialization_started := Time.get_ticks_usec()
	var authorization_usec := 0
	var localization_issue_usec := 0
	var localization_verify_usec := 0
	var player_projection_usec := 0
	var dto_seal_usec := 0
	var semantic_before := _semantic_catalog.call(
		"validation_snapshot"
	) as Dictionary
	if not bool(semantic_before.get("configured", false)):
		_last_error = "semantic_catalog_not_configured"
		return false
	var membership_fingerprint := str(
		semantic_before.get("public_catalog_membership_fingerprint", "")
	)
	var source_catalog_id := str(semantic_before.get("source_catalog_id", ""))
	if not CARD_SEMANTIC_SCHEMA.is_stable_id(source_catalog_id) \
			or membership_fingerprint.is_empty():
		_last_error = "semantic_catalog_membership_invalid"
		return false
	var catalog_snapshot := public_catalog_v06.catalog_snapshot()
	_catalog_snapshot_count += 1
	if str(catalog_snapshot.get("catalog_id", "")) != source_catalog_id \
			or not (catalog_snapshot.get("cards") is Array):
		_last_error = "public_catalog_identity_mismatch"
		return false
	var cards := catalog_snapshot.get("cards", []) as Array
	for ordinal in range(cards.size()):
		var record_value: Variant = cards[ordinal]
		if not (record_value is Dictionary):
			_last_error = "public_catalog_record_invalid"
			return false
		var record := record_value as Dictionary
		var record_fingerprint := CARD_SEMANTIC_SCHEMA.fingerprint(record)
		var machine := _dictionary(record.get("machine", {}))
		var card_id := str(machine.get("card_id", ""))
		var request := {
			"schema_version": PUBLIC_AUTHORIZATION_SCHEMA_VERSION,
			"source_kind": PUBLIC_SOURCE_KIND,
			"visibility_scope_id": PUBLIC_VISIBILITY_SCOPE_ID,
			"source_catalog_id": source_catalog_id,
			"catalog_membership_fingerprint": membership_fingerprint,
			"catalog_member_id": card_id,
			"catalog_ordinal": ordinal,
			"source_record_fingerprint": record_fingerprint,
			"card_record": record.duplicate(true),
			"request_fingerprint": "",
		}
		request["request_fingerprint"] = CARD_SEMANTIC_SCHEMA.fingerprint(
			request,
			"request_fingerprint"
		)
		var phase_started := Time.get_ticks_usec()
		var authorization_value: Variant = _semantic_catalog.call(
			"authorize_public_codex_record",
			request
		)
		authorization_usec += Time.get_ticks_usec() - phase_started
		if not (authorization_value is Dictionary):
			_last_error = "public_semantic_authorization_invalid"
			return false
		var authorization := authorization_value as Dictionary
		if not bool(authorization.get("accepted", false)) \
				or not bool(authorization.get("cache_hit", false)):
			_last_error = str(authorization.get(
				"reason_id",
				"public_semantic_authorization_rejected"
			))
			return false
		_catalog_record_authorization_count += 1
		var semantic_spec := _dictionary(
			authorization.get("semantic_spec", {})
		)
		phase_started = Time.get_ticks_usec()
		var projection_value: Variant = _player_face_projection.call(
			"project_authorized_public_detail",
			semantic_spec,
			record.duplicate(true),
			_public_localization_source
		)
		player_projection_usec += Time.get_ticks_usec() - phase_started
		if not (projection_value is Dictionary) \
				or not bool((projection_value as Dictionary).get("accepted", false)):
			_last_error = str(
				(projection_value as Dictionary).get("reason_id", "public_projection_rejected")
			) if projection_value is Dictionary else "public_projection_invalid"
			return false
		_localization_issue_count += 1
		var projection := projection_value as Dictionary
		var identity := _dictionary(semantic_spec.get("identity", {}))
		var taxonomy := _dictionary(projection.get("taxonomy", {}))
		if str(identity.get("card_id", "")) != card_id \
				or str(taxonomy.get("category_id", "")) \
					!= str(identity.get("category_id", "")) \
				or str(taxonomy.get("industry_id", "")) \
					!= str(identity.get("industry_id", "")):
			_last_error = "public_projection_identity_mismatch"
			return false
		var presentation_tokens := _dictionary(
			projection.get("presentation_tokens", {})
		).duplicate(true)
		presentation_tokens["illustration_key"] = _illustration_key(card_id)
		phase_started = Time.get_ticks_usec()
		var dto := PLAYER_CARD_CODEX_DTO.seal_catalog_owned({
			"schema_version": PLAYER_CARD_CODEX_DTO.SCHEMA_VERSION,
			"projection_id": PLAYER_CARD_CODEX_DTO.PROJECTION_ID,
			"semantic_binding": {
				"source_catalog_id": str(semantic_spec.get("source_catalog_id", "")),
				"source_definition_fingerprint": str(
					semantic_spec.get("source_definition_fingerprint", "")
				),
				"semantic_fingerprint": str(
					semantic_spec.get("semantic_fingerprint", "")
				),
			},
			"localization_binding": _dictionary(
				projection.get("localization_binding", {})
			).duplicate(true),
			"detail_face": _dictionary(
				projection.get("detail_face", {})
			).duplicate(true),
			"taxonomy": taxonomy.duplicate(true),
			"presentation_tokens": presentation_tokens,
			"presentation_copy": _dictionary(
				projection.get("presentation_copy", {})
			).duplicate(true),
		})
		dto_seal_usec += Time.get_ticks_usec() - phase_started
		if dto.is_empty():
			_last_error = "player_card_codex_dto_seal_failed"
			return false
		_ordered_ids.append(card_id)
		_dto_by_card_id[card_id] = dto.duplicate(true)
		var family_id := str(identity.get("family_id", ""))
		var category_id := str(identity.get("category_id", ""))
		_family_id_by_card_id[card_id] = family_id
		if not _ids_by_category.has(category_id):
			_ids_by_category[category_id] = []
		(_ids_by_category[category_id] as Array).append(card_id)
		if not _filter_meta_by_category.has(category_id):
			var copy := _dictionary(dto.get("presentation_copy", {}))
			_filter_meta_by_category[category_id] = {
				"label": str(copy.get("category_label", category_id)),
				"icon_token_id": str(
					presentation_tokens.get("category_icon_token_id", "")
				),
				"color_token_id": str(
					presentation_tokens.get("category_color_token_id", "")
				),
			}
		_dto_projection_count += 1
	catalog_snapshot.clear()
	var ladder_started := Time.get_ticks_usec()
	var ladders_valid := _build_family_ladders()
	var family_ladder_usec := Time.get_ticks_usec() - ladder_started
	var adapter_started := Time.get_ticks_usec()
	var adapter_cache_valid := ladders_valid and _build_adapter_cache()
	var adapter_cache_usec := Time.get_ticks_usec() - adapter_started
	_initialization_timings_usec = {
		"authorization": authorization_usec,
		"localization_issue": localization_issue_usec,
		"localization_verify": localization_verify_usec,
		"player_projection": player_projection_usec,
		"dto_seal": dto_seal_usec,
		"family_ladder": family_ladder_usec,
		"adapter_cache": adapter_cache_usec,
		"total": Time.get_ticks_usec() - initialization_started,
	}
	if _dto_by_card_id.size() != 348 or not ladders_valid \
			or not adapter_cache_valid:
		_last_error = "player_card_codex_cache_incomplete"
		return false
	var semantic_after := _semantic_catalog.call(
		"validation_snapshot"
	) as Dictionary
	_semantic_compile_delta = int(semantic_after.get("compile_count", 0)) \
		- int(semantic_before.get("compile_count", 0))
	if _semantic_compile_delta != 0:
		_last_error = "semantic_compile_delta_nonzero"
		return false
	return true


func _build_family_ladders() -> bool:
	var entries_by_family: Dictionary = {}
	for card_id in _ordered_ids:
		var dto := _dictionary(_dto_by_card_id.get(card_id, {}))
		var detail_face := _dictionary(dto.get("detail_face", {}))
		var family_id := str(detail_face.get("family_id", ""))
		var rank := int(detail_face.get("rank", 0))
		if family_id.is_empty() or rank < 1 or rank > 4:
			return false
		if not entries_by_family.has(family_id):
			entries_by_family[family_id] = {}
		var by_rank := entries_by_family[family_id] as Dictionary
		if by_rank.has(rank):
			return false
		by_rank[rank] = dto.duplicate(true)
	for family_id_variant in entries_by_family.keys():
		var family_id := str(family_id_variant)
		var by_rank := entries_by_family[family_id] as Dictionary
		var entries: Array = []
		for rank in range(1, 5):
			if not by_rank.has(rank):
				return false
			entries.append((by_rank[rank] as Dictionary).duplicate(true))
		var ladder := PLAYER_CARD_CODEX_FAMILY_LADDER_DTO.seal_catalog_owned({
			"schema_version": PLAYER_CARD_CODEX_FAMILY_LADDER_DTO.SCHEMA_VERSION,
			"family_id": family_id,
			"entries": entries,
		})
		if ladder.is_empty():
			return false
		_ladder_by_family_id[family_id] = ladder.duplicate(true)
	return _ladder_by_family_id.size() == 87


func _build_adapter_cache() -> bool:
	for family_id_variant in _ladder_by_family_id.keys():
		var family_id := str(family_id_variant)
		var ladder := _dictionary(_ladder_by_family_id.get(family_id, {}))
		var upgrades_value: Variant = _adapter.call(
			"compose_catalog_owned_upgrade_facts",
			ladder
		)
		if not (upgrades_value is Array) \
				or (upgrades_value as Array).size() != 4:
			return false
		_upgrade_facts_by_family_id[family_id] = \
			(upgrades_value as Array).duplicate(true)
	for card_index in range(_ordered_ids.size()):
		var card_id := _ordered_ids[card_index]
		var family_id := str(_family_id_by_card_id.get(card_id, ""))
		var facts_value: Variant = _adapter.call(
			"compose_catalog_owned_card_facts",
			_dictionary(_dto_by_card_id.get(card_id, {})),
			card_index,
			_dictionary(_ladder_by_family_id.get(family_id, {}))
		)
		if not (facts_value is Dictionary) \
				or not bool((facts_value as Dictionary).get("valid", false)):
			return false
		_facts_by_card_id[card_id] = (facts_value as Dictionary).duplicate(true)
	return _facts_by_card_id.size() == 348 \
		and _upgrade_facts_by_family_id.size() == 87


func _illustration_catalog() -> CardIllustrationCatalog:
	return get_node_or_null("CardIllustrationCatalog") as CardIllustrationCatalog


func _illustration_key(card_id: String) -> String:
	var catalog := _illustration_catalog()
	if catalog == null:
		return ""
	var key := catalog.presentation_key_for_card(card_id)
	return str(key) if key != StringName() else ""


func _filters_with_counts() -> Array:
	var result: Array = []
	for option_variant in public_filter_options():
		var option := _dictionary(option_variant).duplicate(true)
		var filter_id := str(option.get("id", "all"))
		option["count"] = ordered_card_ids(filter_id).size()
		result.append(option)
	return result


func _valid_filter_id(filter_id: String) -> bool:
	return filter_id == "all" or _ids_by_category.has(filter_id)


func _filter_label(filter_id: String) -> String:
	if filter_id == "all":
		return "全部"
	return str(_dictionary(_filter_meta_by_category.get(
		filter_id,
		{}
	)).get("label", filter_id))


func _resolve_icon_token(token_id: String) -> String:
	if _public_localization_source != null \
			and _public_localization_source.has_method("resolve_icon_token"):
		return str(_public_localization_source.call("resolve_icon_token", token_id))
	return "□"


func _resolve_color_token(token_id: String) -> Color:
	if _public_localization_source != null \
			and _public_localization_source.has_method("resolve_color_token"):
		var value: Variant = _public_localization_source.call(
			"resolve_color_token",
			token_id
		)
		if value is Color:
			return value as Color
	return Color("#93c5fd")


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array or value is PackedStringArray:
		for item_variant: Variant in value:
			var item := str(item_variant)
			if not item.is_empty():
				result.append(item)
	return result


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _require_ready() -> bool:
	if _configured:
		return true
	if not _dependencies_bound:
		_last_error = "dependencies_not_configured"
		return false
	if _build_projection_cache():
		_configured = true
		_last_error = ""
		return true
	var failure_reason := _last_error
	_clear_dependencies()
	_last_error = failure_reason
	return false


func _dependencies_match(dependencies: Dictionary) -> bool:
	var keys := dependencies.keys()
	keys.sort()
	var expected := DEPENDENCY_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		return false
	return dependencies.get("snapshot") == _snapshot \
		and dependencies.get("semantic_catalog") == _semantic_catalog \
		and dependencies.get("player_face_projection") == _player_face_projection \
		and dependencies.get("public_localization_source") \
			== _public_localization_source


func _configuration_failure(reason_id: String) -> Dictionary:
	var failure_reason := reason_id if not reason_id.is_empty() \
		else "configuration_failed"
	_clear_dependencies()
	_last_error = failure_reason
	return debug_snapshot()


func _clear_dependencies() -> void:
	_snapshot = null
	_semantic_catalog = null
	_player_face_projection = null
	_public_localization_source = null
	_dependencies_bound = false
	_configured = false
	_last_error = "dependencies_not_configured"
	_clear_runtime_cache()


func _clear_runtime_cache() -> void:
	_ordered_ids.clear()
	_ids_by_category.clear()
	_dto_by_card_id.clear()
	_family_id_by_card_id.clear()
	_ladder_by_family_id.clear()
	_facts_by_card_id.clear()
	_upgrade_facts_by_family_id.clear()
	_filter_meta_by_category.clear()
	_dto_projection_count = 0
	_dto_cache_hit_count = 0
	_facts_cache_hit_count = 0
	_family_ladder_cache_hit_count = 0
	_catalog_snapshot_count = 0
	_catalog_record_authorization_count = 0
	_localization_issue_count = 0
	_semantic_compile_delta = 0
	_page_fact_build_count = 0
	_monster_codex_compatibility_lookup_count = 0
	_initialization_timings_usec.clear()
