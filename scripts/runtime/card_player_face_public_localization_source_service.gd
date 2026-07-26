@tool
extends Node
class_name CardPlayerFacePublicLocalizationSourceService

const AUTHORIZED_SOURCE := preload(
	"res://scripts/presentation/authorized_card_player_face_localization_source_v1.gd"
)
const CARD_SEMANTIC_SCHEMA := preload(
	"res://scripts/cards/semantic/card_semantic_schema_v1.gd"
)
const WIRE := preload("res://scripts/semantic/semantic_wire_v1.gd")
const TOKEN_MANIFEST := preload(
	"res://scripts/presentation/card_player_face_public_token_manifest_v1.gd"
)

const SOURCE_REVISION := 1
const EXPECTED_CARD_COUNT := 348
const DURATION_PARAMETER_IDS := [
	"counter_window_seconds",
	"duration_seconds",
	"persistence_id",
]
const RANK_LABELS := TOKEN_MANIFEST.RANK_LABEL_BY_RANK
const CATEGORY_PRESENTATION := TOKEN_MANIFEST.CATEGORY_PRESENTATION
const INDUSTRY_PRESENTATION := TOKEN_MANIFEST.INDUSTRY_PRESENTATION
const TIMING_LABELS := {
	"main_action": "普通出牌窗口",
	"response_window": "响应窗口",
}
const TARGET_LABELS := {
	"facility.same_industry": "同产业设施",
	"district.active": "可用区域",
	"unit.same_family": "同家族单位",
	"player.opponent": "一名对手",
	"response.incoming_direct_interaction": "当前直接互动",
	"world.global": "全局匹配对象",
	"organization.self_slot": "自己的组织槽",
}
const SELECTION_LABELS := {
	"actor_choice": "玩家选择",
	"automatic": "自动选择",
	"trigger_context": "触发上下文",
}
const CARDINALITY_LABELS := {
	"exactly_one": "恰好一个",
	"all_matching": "全部匹配对象",
}
const CONDITION_LABELS := {
	"facility.kind.factory_or_market": "设施为工厂或市场",
	"industry.same_as_card": "产业与卡牌一致",
	"district.state.active_or_undeveloped_or_ruined": "区域状态允许建造或修复",
	"facility.slot.unique_by_kind": "设施槽按类型唯一",
	"unit.kind.monster": "单位为怪兽",
	"unit.kind.military": "单位为军队",
	"unit.region_or_same_family": "目标为区域或同家族单位",
	"unit.controller.any": "单位控制者不限",
	"unit.controller.actor": "单位由行动者控制",
	"hand.discardable": "手牌可以被弃置",
	"interaction.direct": "属于直接互动",
	"world.matching_goods": "商品满足全局条件",
	"world.matching_factories": "工厂满足全局条件",
	"organization.slot.available_or_same_family": "组织槽为空或属于同家族",
}
const RESPONSE_LABELS := {
	"none": "不可反制",
	"counterable": "可反制",
	"counter": "反制响应",
}
const INFORMATION_SCOPE_LABELS := {
	"authorized_source_only": "仅向获授权的当前界面公开",
}
const OPERATION_LABELS := {
	"install_rate": "安装生产或需求速率",
	"build_facility": "建造设施",
	"upgrade_facility": "升级设施",
	"repair_facility": "修复设施",
	"deploy_unit": "部署单位",
	"upgrade_same_family_unit": "升级同家族单位",
	"extend_presence": "延长在场时间",
	"heal_unit": "治疗单位",
	"modify_supply": "修改供应",
	"modify_demand": "修改需求",
	"discard_random": "随机弃牌",
	"steal_random": "随机夺取手牌",
	"lock_random": "随机锁定手牌",
	"counter_action": "反制行动",
	"install_organization_upgrade": "安装组织升级",
	"military_move": "军队移动",
	"military_guard": "军队守卫",
	"military_strike": "军队打击",
	"global_order": "全局订单",
	"global_supply_spawn": "全局供应生成",
}
const PARAMETER_LABELS := {
	"amount_units": "数量",
	"card_rank": "等级",
	"count": "数量",
	"counter_strength": "反制强度",
	"counter_window_seconds": "反制窗口秒数",
	"duration_seconds": "持续秒数",
	"heal_policy_id": "治疗策略",
	"industry_id": "产业",
	"persistence_id": "持续策略",
	"rate_units_per_minute": "每分钟速率",
	"refund_cash": "返还现金",
	"repair_policy_id": "修复策略",
	"response_depth": "响应深度",
	"steal_fail_cash": "夺取失败现金",
	"target_cash_penalty": "目标现金惩罚",
	"target_scope_id": "响应目标",
	"unit_family_id": "单位家族",
	"unit_kind_id": "单位类型",
	"valid_facility_kind_ids": "适用设施",
}
const SEMANTIC_VALUE_LABELS := {
	"actor": "当前玩家",
	"any": "任意控制者",
	"card_family": "本卡家族",
	"counterable": "可反制行动",
	"established_facility_repair": "按既有设施规则修复",
	"factory": "工厂",
	"market": "市场",
	"military": "军队",
	"monster": "怪兽",
	"none": "无",
	"production_or_demand_by_facility_kind": "按设施类型增加生产或需求",
	"to_full": "恢复至满值",
	"until_facility_destroyed": "设施被摧毁时结束",
}
const SANITIZED_AUTHORED_TEXT_FIELDS := [
	"name",
	"authored_cost_summary",
	"authored_timing_summary",
	"authored_target_summary",
	"short_effect",
	"full_effect",
	"authored_duration_summary",
	"authored_information_scope_summary",
	"authored_next_step_summary",
]
const MESSAGE_ARG_FIELDS := ["arg_id", "type_id", "value"]
const MESSAGE_ARG_TYPE_IDS := [
	"asset_units",
	"boolean",
	"cash",
	"count",
	"integer",
	"number",
	"rate",
	"seconds",
	"stable_id",
]
const FORBIDDEN_MESSAGE_ARG_IDS := [
	"owner",
	"hidden_owner",
	"true_owner",
	"player_index",
	"hand",
	"rival_hand",
	"opponent_hand",
	"exact_cash",
	"private_plan",
	"ai_score",
	"ai_value",
	"route_plan",
	"future_bag",
	"rng_state",
	"save_payload",
	"machine",
	"player",
	"developer",
	"effect_payload",
	"skill",
	"method_name",
	"script_path",
]

@export var public_catalog_v06: CardRuntimeCatalogV06Resource

var _semantic_catalog_service: CardSemanticCatalogService
var _configured := false
var _last_reason_id := "card_player_face_public_localization.not_configured"
var _source_catalog_id := ""
var _source_catalog_fingerprint := ""
var _manifest_catalog_fingerprint := ""
var _sealed_record_fingerprint_by_card_id: Dictionary = {}
var _sealed_semantic_fingerprint_by_card_id: Dictionary = {}
var _sealed_bundle_by_card_id: Dictionary = {}
var _sanitized_authored_presentation_by_card_id: Dictionary = {}
var _icon_value_by_issued_token_id: Dictionary = {}
var _color_value_by_issued_token_id: Dictionary = {}
var _issue_count := 0
var _verify_count := 0
var _presentation_resolution_count := 0
var _configuration_attempt_count := 0


func configure(semantic_catalog_service: Variant) -> Dictionary:
	_configuration_attempt_count += 1
	if _configured:
		if semantic_catalog_service == _semantic_catalog_service:
			return debug_snapshot()
		_last_reason_id = "card_player_face_public_localization.rebind_rejected"
		return debug_snapshot()
	if not (semantic_catalog_service is CardSemanticCatalogService):
		_last_reason_id = "card_player_face_public_localization.semantic_catalog_invalid"
		return debug_snapshot()
	if public_catalog_v06 == null:
		_last_reason_id = "card_player_face_public_localization.catalog_missing"
		return debug_snapshot()

	var semantic_service := semantic_catalog_service as CardSemanticCatalogService
	var semantic_summary := semantic_service.validation_snapshot()
	if not bool(semantic_summary.get("configured", false)) \
			or int(semantic_summary.get("cache_entry_count", 0)) != EXPECTED_CARD_COUNT:
		_last_reason_id = "card_player_face_public_localization.semantic_catalog_not_ready"
		return debug_snapshot()
	var catalog_report := public_catalog_v06.validation_report()
	if not bool(catalog_report.get("valid", false)) \
			or int(catalog_report.get("card_count", 0)) != EXPECTED_CARD_COUNT:
		_last_reason_id = "card_player_face_public_localization.catalog_invalid"
		return debug_snapshot()
	var catalog_snapshot := public_catalog_v06.catalog_snapshot()
	var catalog_id := str(catalog_snapshot.get("catalog_id", ""))
	var cards_value: Variant = catalog_snapshot.get("cards")
	if not CARD_SEMANTIC_SCHEMA.is_stable_id(catalog_id) \
			or not (cards_value is Array) \
			or (cards_value as Array).size() != EXPECTED_CARD_COUNT:
		_last_reason_id = "card_player_face_public_localization.catalog_snapshot_invalid"
		return debug_snapshot()
	var catalog_fingerprint := _catalog_machine_fingerprint(catalog_id, cards_value as Array)
	if catalog_fingerprint.is_empty() \
			or catalog_fingerprint != str(semantic_summary.get("source_catalog_fingerprint", "")):
		_last_reason_id = "card_player_face_public_localization.catalog_binding_mismatch"
		return debug_snapshot()

	var record_fingerprints: Dictionary = {}
	var semantic_fingerprints: Dictionary = {}
	var bundles: Dictionary = {}
	var sanitized_presentations: Dictionary = {}
	var manifest_fingerprints: Array = []
	var icon_values: Dictionary = {}
	var color_values: Dictionary = {}
	for index in range((cards_value as Array).size()):
		var record_value: Variant = (cards_value as Array)[index]
		if not (record_value is Dictionary) \
				or not CARD_SEMANTIC_SCHEMA.is_pure_data(record_value):
			_last_reason_id = "card_player_face_public_localization.record_invalid"
			return debug_snapshot()
		var record := record_value as Dictionary
		var machine_value: Variant = record.get("machine")
		if not (machine_value is Dictionary):
			_last_reason_id = "card_player_face_public_localization.machine_invalid"
			return debug_snapshot()
		var machine := machine_value as Dictionary
		var card_id := str(machine.get("card_id", ""))
		var record_fingerprint := CARD_SEMANTIC_SCHEMA.fingerprint({
			"source_catalog_id": catalog_id,
			"card_record": record,
		})
		if not CARD_SEMANTIC_SCHEMA.is_stable_id(card_id) \
				or record_fingerprint.is_empty() \
				or record_fingerprints.has(card_id):
			_last_reason_id = "card_player_face_public_localization.record_identity_invalid"
			return debug_snapshot()
		var compiled := semantic_service.compile_authorized(
			_compiler_envelope(record, index + 1)
		)
		if not bool(compiled.get("ok", false)) \
				or not bool(compiled.get("cache_hit", false)):
			_last_reason_id = "card_player_face_public_localization.semantic_cache_miss"
			return debug_snapshot()
		var semantic_spec := compiled.get("spec", {}) as Dictionary
		var identity := semantic_spec.get("identity", {}) as Dictionary
		if str(identity.get("card_id", "")) != card_id:
			_last_reason_id = "card_player_face_public_localization.semantic_identity_mismatch"
			return debug_snapshot()
		var localization_source := _build_localization_source(
			record,
			semantic_spec,
			catalog_id,
			catalog_fingerprint,
			record_fingerprint
		)
		if localization_source.is_empty():
			_last_reason_id = "card_player_face_public_localization.manifest_invalid"
			return debug_snapshot()
		if not _collect_manifest_token_resolutions(
			localization_source,
			icon_values,
			color_values
		):
			_last_reason_id = "card_player_face_public_localization.token_manifest_invalid"
			return debug_snapshot()
		var receipt := _build_receipt(localization_source, card_id)
		var bundle := AUTHORIZED_SOURCE.build_issue_result(localization_source, receipt)
		if bundle.is_empty():
			_last_reason_id = "card_player_face_public_localization.bundle_invalid"
			return debug_snapshot()
		var sanitized_presentation := _sanitize_authored_presentation(record)
		if sanitized_presentation.is_empty():
			_last_reason_id = "card_player_face_public_localization.authored_presentation_invalid"
			return debug_snapshot()
		record_fingerprints[card_id] = record_fingerprint
		semantic_fingerprints[card_id] = str(semantic_spec.get("semantic_fingerprint", ""))
		bundles[card_id] = bundle.duplicate(true)
		sanitized_presentations[card_id] = sanitized_presentation
		manifest_fingerprints.append(str(localization_source.get("source_manifest_fingerprint", "")))

	if bundles.size() != EXPECTED_CARD_COUNT:
		_last_reason_id = "card_player_face_public_localization.sealed_count_mismatch"
		return debug_snapshot()
	var manifest_catalog_fingerprint := WIRE.fingerprint({
		"schema_version": AUTHORIZED_SOURCE.SCHEMA_VERSION,
		"source_catalog_id": catalog_id,
		"manifest_fingerprints": manifest_fingerprints,
	})
	if manifest_catalog_fingerprint.is_empty():
		_last_reason_id = "card_player_face_public_localization.manifest_catalog_fingerprint_failed"
		return debug_snapshot()

	_semantic_catalog_service = semantic_service
	_source_catalog_id = catalog_id
	_source_catalog_fingerprint = catalog_fingerprint
	_manifest_catalog_fingerprint = manifest_catalog_fingerprint
	_sealed_record_fingerprint_by_card_id = record_fingerprints
	_sealed_semantic_fingerprint_by_card_id = semantic_fingerprints
	_sealed_bundle_by_card_id = bundles
	_sanitized_authored_presentation_by_card_id = sanitized_presentations
	_icon_value_by_issued_token_id = icon_values
	_color_value_by_issued_token_id = color_values
	_configured = true
	_last_reason_id = "none"
	return debug_snapshot()


func issue_for_exact_record(card_record: Variant, semantic_spec: Variant) -> Dictionary:
	if not _configured:
		return _issue_rejected("card_player_face_public_localization.not_configured")
	if not (card_record is Dictionary) \
			or not (semantic_spec is Dictionary) \
			or not CARD_SEMANTIC_SCHEMA.is_pure_data(card_record) \
			or not CARD_SEMANTIC_SCHEMA.is_pure_data(semantic_spec):
		return _issue_rejected("card_player_face_public_localization.input_not_pure_data")
	var record := card_record as Dictionary
	var machine_value: Variant = record.get("machine")
	if not (machine_value is Dictionary):
		return _issue_rejected("card_player_face_public_localization.machine_invalid")
	var card_id := str((machine_value as Dictionary).get("card_id", ""))
	if not _sealed_record_fingerprint_by_card_id.has(card_id):
		return _issue_rejected("card_player_face_public_localization.record_not_registered")
	var supplied_record_fingerprint := CARD_SEMANTIC_SCHEMA.fingerprint({
		"source_catalog_id": _source_catalog_id,
		"card_record": record,
	})
	if supplied_record_fingerprint.is_empty() \
			or supplied_record_fingerprint != str(
				_sealed_record_fingerprint_by_card_id.get(card_id, "")
			):
		return _issue_rejected("card_player_face_public_localization.record_content_mismatch")
	var semantic := semantic_spec as Dictionary
	if not _semantic_matches_registry(card_id, semantic):
		return _issue_rejected("card_player_face_public_localization.semantic_content_mismatch")
	_issue_count += 1
	_last_reason_id = "none"
	return (_sealed_bundle_by_card_id.get(card_id, {}) as Dictionary).duplicate(true)


func issue_verified_for_exact_record(
	card_record: Variant,
	semantic_spec: Variant
) -> Dictionary:
	var bundle := issue_for_exact_record(card_record, semantic_spec)
	if not bool(bundle.get("accepted", false)):
		return _verify_rejected(str(bundle.get(
			"reason_id",
			"card_player_face_public_localization.issue_rejected"
		)))
	var localization_source := bundle.get("localization_source", {}) as Dictionary
	var source_binding := localization_source.get("source_binding", {}) as Dictionary
	return _build_registered_verified_report(
		bundle,
		semantic_spec as Dictionary,
		str(source_binding.get("card_id", ""))
	)


func verify_bundle(bundle: Variant, semantic_spec: Variant) -> Dictionary:
	if not _configured:
		return _verify_rejected("card_player_face_public_localization.not_configured")
	var bundle_report := AUTHORIZED_SOURCE.validate_issue_result(bundle)
	if not bool(bundle_report.get("valid", false)):
		return _verify_rejected(str(bundle_report.get(
			"reason_id",
			"card_player_face_public_localization.bundle_invalid"
		)))
	if not (semantic_spec is Dictionary) \
			or not CARD_SEMANTIC_SCHEMA.is_pure_data(semantic_spec):
		return _verify_rejected("card_player_face_public_localization.semantic_not_pure_data")
	var supplied_bundle := bundle as Dictionary
	var localization_source := supplied_bundle.get("localization_source", {}) as Dictionary
	var source_binding := localization_source.get("source_binding", {}) as Dictionary
	var card_id := str(source_binding.get("card_id", ""))
	if not _sealed_bundle_by_card_id.has(card_id):
		return _verify_rejected("card_player_face_public_localization.bundle_not_registered")
	var expected_bundle := _sealed_bundle_by_card_id.get(card_id, {}) as Dictionary
	if WIRE.canonical_json(supplied_bundle).is_empty() \
			or WIRE.canonical_json(supplied_bundle) \
				!= WIRE.canonical_json(expected_bundle):
		return _verify_rejected("card_player_face_public_localization.bundle_registry_mismatch")
	var semantic := semantic_spec as Dictionary
	if not _semantic_matches_registry(card_id, semantic):
		return _verify_rejected("card_player_face_public_localization.semantic_content_mismatch")
	var semantic_binding := localization_source.get("semantic_binding", {}) as Dictionary
	if str(semantic_binding.get("semantic_fingerprint", "")) \
			!= str(semantic.get("semantic_fingerprint", "")):
		return _verify_rejected("card_player_face_public_localization.semantic_binding_stale")
	return _build_registered_verified_report(
		supplied_bundle,
		semantic,
		card_id
	)


func _build_registered_verified_report(
	bundle: Dictionary,
	semantic: Dictionary,
	card_id: String
) -> Dictionary:
	var localization_source := bundle.get("localization_source", {}) as Dictionary
	var source_binding := localization_source.get("source_binding", {}) as Dictionary
	var semantic_binding := localization_source.get("semantic_binding", {}) as Dictionary
	if not _sealed_bundle_by_card_id.has(card_id) \
			or not _semantic_matches_registry(card_id, semantic) \
			or str(semantic_binding.get("semantic_fingerprint", "")) \
				!= str(semantic.get("semantic_fingerprint", "")):
		return _verify_rejected(
			"card_player_face_public_localization.registered_binding_mismatch"
		)
	var authored_presentation := (
		_sanitized_authored_presentation_by_card_id.get(card_id, {})
		as Dictionary
	)
	var presentation_copy := _presentation_copy(
		authored_presentation,
		localization_source,
		semantic
	)
	if presentation_copy.is_empty():
		return _verify_rejected("card_player_face_public_localization.presentation_copy_failed")
	var projection_source := _legacy_projection_source(localization_source)
	var verified := AUTHORIZED_SOURCE.build_verified_report({
		"accepted": true,
		"reason_id": AUTHORIZED_SOURCE.VERIFIED_REASON_ID,
		"projection_source": projection_source,
		"localization_binding": {
			"source_id": str(source_binding.get("source_id", "")),
			"source_revision": int(source_binding.get("source_revision", 0)),
			"source_fingerprint": str(localization_source.get("source_manifest_fingerprint", "")),
			"semantic_fingerprint": str(semantic_binding.get("semantic_fingerprint", "")),
		},
		"taxonomy": (localization_source.get("taxonomy", {}) as Dictionary).duplicate(true),
		"presentation_tokens": (localization_source.get("presentation_tokens", {}) as Dictionary).duplicate(true),
		"presentation_copy": presentation_copy,
		"authorization_receipt": (bundle.get("authorization_receipt", {}) as Dictionary).duplicate(true),
		"bundle_fingerprint": str(bundle.get("bundle_fingerprint", "")),
	})
	if verified.is_empty():
		return _verify_rejected("card_player_face_public_localization.verified_report_invalid")
	_verify_count += 1
	_last_reason_id = "none"
	return verified.duplicate(true)


func resolve_at_presentation(
	bundle: Variant,
	semantic_spec: Variant,
	message_ref: Variant,
	locale_id: String = AUTHORIZED_SOURCE.LOCALE_ID
) -> Dictionary:
	if locale_id != AUTHORIZED_SOURCE.LOCALE_ID:
		return _resolution_rejected("card_player_face_public_localization.locale_not_supported")
	if not (message_ref is Dictionary) \
			or not CARD_SEMANTIC_SCHEMA.is_pure_data(message_ref):
		return _resolution_rejected("card_player_face_public_localization.message_ref_invalid")
	var message := message_ref as Dictionary
	if message.size() != 2 or not message.has("message_id") or not message.has("args") \
			or not (message.get("args") is Array) \
			or not WIRE.is_stable_id(message.get("message_id")):
		return _resolution_rejected("card_player_face_public_localization.message_ref_fields_invalid")
	var args_error := _message_args_error(message.get("args") as Array)
	if not args_error.is_empty():
		return _resolution_rejected(args_error)
	var verified := verify_bundle(bundle, semantic_spec)
	if not bool(verified.get("accepted", false)):
		return _resolution_rejected(str(verified.get(
			"reason_id",
			"card_player_face_public_localization.bundle_not_verified"
		)))
	var source := (bundle as Dictionary).get("localization_source", {}) as Dictionary
	var source_binding := source.get("source_binding", {}) as Dictionary
	var authored_presentation := (
		_sanitized_authored_presentation_by_card_id.get(
			str(source_binding.get("card_id", "")),
			{}
		) as Dictionary
	)
	var message_id := str(message.get("message_id", ""))
	if not _is_authorized_message_id(source, message_id):
		return _resolution_rejected("card_player_face_public_localization.message_not_authorized")
	var copy := verified.get("presentation_copy", {}) as Dictionary
	var text := _resolved_message_text(
		message_id,
		source,
		semantic_spec as Dictionary,
		copy,
		authored_presentation
	)
	if text.strip_edges().is_empty():
		return _resolution_rejected("card_player_face_public_localization.message_unresolved")
	_presentation_resolution_count += 1
	return {
		"accepted": true,
		"reason_id": "card_player_face_public_localization.message_resolved",
		"message_id": message_id,
		"locale_id": locale_id,
		"text": text,
	}


func _message_args_error(args: Array) -> String:
	var seen_arg_ids: Array[String] = []
	for arg_variant in args:
		if not (arg_variant is Dictionary):
			return "card_player_face_public_localization.message_arg_not_dictionary"
		var arg := arg_variant as Dictionary
		if not WIRE.exact_fields(arg, MESSAGE_ARG_FIELDS):
			return "card_player_face_public_localization.message_arg_fields_invalid"
		var arg_id := str(arg.get("arg_id", ""))
		var type_id := str(arg.get("type_id", ""))
		if not WIRE.is_stable_id(arg_id) or not MESSAGE_ARG_TYPE_IDS.has(type_id):
			return "card_player_face_public_localization.message_arg_identity_invalid"
		for segment in arg_id.split("."):
			if FORBIDDEN_MESSAGE_ARG_IDS.has(segment):
				return "card_player_face_public_localization.message_arg_forbidden"
		if seen_arg_ids.has(arg_id):
			return "card_player_face_public_localization.message_arg_duplicate"
		seen_arg_ids.append(arg_id)
		if not _message_arg_value_matches_type(type_id, arg.get("value")):
			return "card_player_face_public_localization.message_arg_value_invalid"
	return ""


func _message_arg_value_matches_type(type_id: String, value: Variant) -> bool:
	match type_id:
		"boolean":
			return value is bool
		"stable_id":
			return WIRE.is_stable_id(value)
		"number":
			return WIRE.is_safe_integer(value) \
				or (value is float and is_finite(float(value)))
		_:
			return WIRE.is_safe_integer(value)


func resolve_color_token(token_id: String) -> Color:
	if not _configured \
			or not WIRE.is_stable_id(token_id) \
			or not _color_value_by_issued_token_id.has(token_id):
		return Color(0.0, 0.0, 0.0, 0.0)
	return Color.from_string(
		str(_color_value_by_issued_token_id.get(token_id, "")),
		Color(0.0, 0.0, 0.0, 0.0)
	)


func resolve_icon_token(token_id: String) -> String:
	if not _configured \
			or not WIRE.is_stable_id(token_id) \
			or not _icon_value_by_issued_token_id.has(token_id):
		return ""
	return str(_icon_value_by_issued_token_id.get(token_id, ""))


func debug_snapshot() -> Dictionary:
	return {
		"schema_version": AUTHORIZED_SOURCE.SCHEMA_VERSION,
		"service_id": "card_player_face_public_localization_source.v1",
		"configured": _configured,
		"last_reason_id": _last_reason_id,
		"source_owner_id": AUTHORIZED_SOURCE.SOURCE_OWNER_ID,
		"visibility_scope_id": AUTHORIZED_SOURCE.VISIBILITY_SCOPE_ID,
		"source_catalog_id": _source_catalog_id,
		"source_catalog_fingerprint": _source_catalog_fingerprint,
		"manifest_catalog_fingerprint": _manifest_catalog_fingerprint,
		"sealed_record_fingerprint_count": _sealed_record_fingerprint_by_card_id.size(),
		"sealed_bundle_count": _sealed_bundle_by_card_id.size(),
		"sanitized_authored_presentation_count": _sanitized_authored_presentation_by_card_id.size(),
		"issued_icon_token_count": _icon_value_by_issued_token_id.size(),
		"issued_color_token_count": _color_value_by_issued_token_id.size(),
		"configuration_attempt_count": _configuration_attempt_count,
		"issue_count": _issue_count,
		"verify_count": _verify_count,
		"presentation_resolution_count": _presentation_resolution_count,
		"owns_save_state": false,
		"uses_rng": false,
		"owns_rules": false,
		"owns_world_state": false,
		"depends_on_main": false,
		"supports_arbitrary_card_id_lookup": false,
		"supports_catalog_enumeration": false,
		"retains_full_card_records": false,
		"retains_full_record_canonical_json": false,
		"retains_machine_blocks": false,
		"retains_developer_blocks": false,
	}


func _build_localization_source(
	card_record: Dictionary,
	semantic_spec: Dictionary,
	catalog_id: String,
	catalog_fingerprint: String,
	record_fingerprint: String
) -> Dictionary:
	var identity := semantic_spec.get("identity", {}) as Dictionary
	var card_id := str(identity.get("card_id", ""))
	var family_id := str(identity.get("family_id", ""))
	var rank := int(identity.get("rank", 0))
	var category_id := str(identity.get("category_id", ""))
	var industry_id := str(identity.get("industry_id", "generic"))
	if not CATEGORY_PRESENTATION.has(category_id) \
			or not INDUSTRY_PRESENTATION.has(industry_id):
		return {}
	var category := CATEGORY_PRESENTATION.get(category_id, {}) as Dictionary
	var industry := INDUSTRY_PRESENTATION.get(industry_id, {}) as Dictionary
	var source_hash := WIRE.fingerprint({
		"source_owner_id": AUTHORIZED_SOURCE.SOURCE_OWNER_ID,
		"card_id": card_id,
		"source_record_fingerprint": record_fingerprint,
	})
	if source_hash.is_empty():
		return {}
	var source_id := "card.localization.%s" % source_hash.left(32)
	var target := semantic_spec.get("target", {}) as Dictionary
	var effects := semantic_spec.get("effect_ops", []) as Array
	var response := semantic_spec.get("response", {}) as Dictionary
	var timing := semantic_spec.get("timing", {}) as Dictionary
	var information := semantic_spec.get("information_policy", {}) as Dictionary
	var acquisition := (
		(semantic_spec.get("cost", {}) as Dictionary).get("acquisition", {})
		as Dictionary
	)
	var condition_ids := _condition_ids(target, effects)
	var condition_rows: Array = []
	for condition_id_variant in condition_ids:
		var condition_id := str(condition_id_variant)
		condition_rows.append({
			"condition_id": condition_id,
			"message_id": "card.condition.%s" % condition_id,
		})
	var effect_rows: Array = []
	for index in range(effects.size()):
		var effect := effects[index] as Dictionary
		var op_id := str(effect.get("op_id", ""))
		effect_rows.append({
			"order": index + 1,
			"op_id": op_id,
			"summary_message_id": "card.effect.%s.summary" % op_id,
			"detail_message_id": "card.effect.%s.detail" % op_id,
		})
	var keyword_rows := _semantic_keyword_rows(
		category_id,
		industry_id,
		str(timing.get("timing_id", "")),
		str(response.get("response_id", "")),
		effects,
		category,
		industry
	)
	var authored_keyword_rows := _authored_keyword_rows(card_record, card_id)
	if keyword_rows.is_empty() or authored_keyword_rows.is_empty():
		return {}
	var authored_prefix := "card.authored.%s" % card_id
	return AUTHORIZED_SOURCE.seal_localization_source({
		"schema_version": AUTHORIZED_SOURCE.SCHEMA_VERSION,
		"source_binding": {
			"source_id": source_id,
			"source_revision": SOURCE_REVISION,
			"source_catalog_id": catalog_id,
			"source_catalog_fingerprint": catalog_fingerprint,
			"source_record_fingerprint": record_fingerprint,
			"card_id": card_id,
			"family_id": family_id,
			"rank": rank,
			"locale_id": AUTHORIZED_SOURCE.LOCALE_ID,
			"visibility_scope_id": AUTHORIZED_SOURCE.VISIBILITY_SCOPE_ID,
		},
		"semantic_binding": {
			"semantic_schema_version": int(semantic_spec.get("schema_version", 0)),
			"source_definition_fingerprint": str(semantic_spec.get("source_definition_fingerprint", "")),
			"semantic_fingerprint": str(semantic_spec.get("semantic_fingerprint", "")),
		},
		"structural_message_ids": {
			"name": "card.name.%s" % card_id,
			"family_name": "card.family.%s" % family_id,
			"acquisition_cost": "card.cost.acquisition.%s" % str(acquisition.get("acquisition_kind", "")),
			"activation_cost": "card.cost.activation.assets",
			"timing": "card.timing.%s" % str(timing.get("timing_id", "")),
			"duration": "card.duration.%s" % (
				"effect_defined" if _has_duration_component(effects) else "not_specified"
			),
			"counterability": "card.counterability.%s" % str(response.get("response_id", "")),
			"information_scope": "card.information.%s" % str(information.get("visibility_policy_id", "")),
		},
		"authored_message_ids": {
			"name": "%s.name" % authored_prefix,
			"family_name": "%s.family_name" % authored_prefix,
			"rank_label": "%s.rank_label" % authored_prefix,
			"category_label": "%s.category_label" % authored_prefix,
			"industry_label": "%s.industry_label" % authored_prefix,
			"authored_cost_summary": "%s.authored_cost_summary" % authored_prefix,
			"timing_summary": "%s.timing_summary" % authored_prefix,
			"target_summary": "%s.target_summary" % authored_prefix,
			"short_effect_summary": "%s.short_effect_summary" % authored_prefix,
			"effect_detail": "%s.effect_detail" % authored_prefix,
			"duration_summary": "%s.duration_summary" % authored_prefix,
			"information_scope_summary": "%s.information_scope_summary" % authored_prefix,
			"next_step_summary": "%s.next_step_summary" % authored_prefix,
		},
		"target_message_rows": [{
			"target_id": str(target.get("target_id", "")),
			"message_id": "card.target.%s" % str(target.get("target_id", "")),
		}],
		"condition_message_rows": condition_rows,
		"effect_step_message_rows": effect_rows,
		"keyword_rows": keyword_rows,
		"authored_keyword_rows": authored_keyword_rows,
		"taxonomy": {
			"category_id": category_id,
			"industry_id": industry_id,
			"category_label_ref": "card.category.%s.label" % category_id,
			"industry_label_ref": "card.industry.%s.label" % industry_id,
		},
		"presentation_tokens": {
			"category_icon_token_id": str(category.get("icon_token_id", "")),
			"category_color_token_id": str(category.get("color_token_id", "")),
			"industry_color_token_id": str(industry.get("color_token_id", "")),
			"illustration_key": "",
			"fallback_illustration_token_id": "illustration.fallback.card.%s" % category_id,
		},
	})


func _build_receipt(localization_source: Dictionary, card_id: String) -> Dictionary:
	var source_binding := localization_source.get("source_binding", {}) as Dictionary
	var semantic_binding := localization_source.get("semantic_binding", {}) as Dictionary
	var receipt_seed := WIRE.fingerprint({
		"owner_id": AUTHORIZED_SOURCE.SOURCE_OWNER_ID,
		"card_id": card_id,
		"source_manifest_fingerprint": str(localization_source.get("source_manifest_fingerprint", "")),
		"semantic_fingerprint": str(semantic_binding.get("semantic_fingerprint", "")),
	})
	if receipt_seed.is_empty():
		return {}
	return AUTHORIZED_SOURCE.build_receipt({
		"schema_version": AUTHORIZED_SOURCE.SCHEMA_VERSION,
		"receipt_id": "card.localization.receipt.%s" % receipt_seed.left(32),
		"owner_id": AUTHORIZED_SOURCE.SOURCE_OWNER_ID,
		"visibility_scope_id": AUTHORIZED_SOURCE.VISIBILITY_SCOPE_ID,
		"source_id": str(source_binding.get("source_id", "")),
		"source_revision": int(source_binding.get("source_revision", 0)),
		"source_fingerprint": str(localization_source.get("source_manifest_fingerprint", "")),
		"semantic_fingerprint": str(semantic_binding.get("semantic_fingerprint", "")),
	})


func _legacy_projection_source(localization_source: Dictionary) -> Dictionary:
	var source_binding := localization_source.get("source_binding", {}) as Dictionary
	var semantic_binding := localization_source.get("semantic_binding", {}) as Dictionary
	return {
		"schema_version": AUTHORIZED_SOURCE.SCHEMA_VERSION,
		"source_id": str(source_binding.get("source_id", "")),
		"card_id": str(source_binding.get("card_id", "")),
		"semantic_fingerprint": str(semantic_binding.get("semantic_fingerprint", "")),
		"authorization_scope_id": AUTHORIZED_SOURCE.LEGACY_PROJECTION_SCOPE_ID,
		"authorization_revision": int(source_binding.get("source_revision", 0)),
		"authorized": true,
		"message_ids": (localization_source.get("structural_message_ids", {}) as Dictionary).duplicate(true),
		"target_message_rows": (localization_source.get("target_message_rows", []) as Array).duplicate(true),
		"condition_message_rows": (localization_source.get("condition_message_rows", []) as Array).duplicate(true),
		"effect_step_message_rows": (localization_source.get("effect_step_message_rows", []) as Array).duplicate(true),
		"keyword_rows": (localization_source.get("keyword_rows", []) as Array).duplicate(true),
	}


func _sanitize_authored_presentation(card_record: Dictionary) -> Dictionary:
	var player_value: Variant = card_record.get("player")
	if not (player_value is Dictionary):
		return {}
	var player := player_value as Dictionary
	var sanitized := {
		"name": str(player.get("name", "")),
		"authored_cost_summary": str(player.get("cost", "")),
		"authored_timing_summary": str(player.get("timing", "")),
		"authored_target_summary": str(player.get("target", "")),
		"short_effect": str(player.get("short_effect", "")),
		"full_effect": str(player.get("effect", "")),
		"authored_duration_summary": str(player.get("duration", "")),
		"authored_information_scope_summary": str(player.get("visibility", "")),
		"authored_next_step_summary": str(player.get("next_step", "")),
		"keyword_rows": [],
	}
	for field_id in SANITIZED_AUTHORED_TEXT_FIELDS:
		if str(sanitized.get(field_id, "")).strip_edges().is_empty():
			return {}
	var keywords_value: Variant = player.get("keywords")
	if not (keywords_value is Array) \
			or (keywords_value as Array).is_empty() \
			or (keywords_value as Array).size() > 16:
		return {}
	var keyword_rows: Array = []
	for keyword_variant in keywords_value as Array:
		if not (keyword_variant is Dictionary):
			return {}
		var keyword := keyword_variant as Dictionary
		var label_text := str(keyword.get("text", ""))
		var tooltip_text := str(keyword.get("tooltip", ""))
		if label_text.strip_edges().is_empty() or tooltip_text.strip_edges().is_empty():
			return {}
		keyword_rows.append({
			"label_text": label_text,
			"tooltip_text": tooltip_text,
		})
	sanitized["keyword_rows"] = keyword_rows
	return sanitized if WIRE.is_closed_data(sanitized) else {}


func _presentation_copy(
	authored_presentation: Dictionary,
	localization_source: Dictionary,
	semantic_spec: Dictionary
) -> Dictionary:
	for field_id in SANITIZED_AUTHORED_TEXT_FIELDS:
		if not (authored_presentation.get(field_id) is String) \
				or str(authored_presentation.get(field_id, "")).strip_edges().is_empty():
			return {}
	var taxonomy := localization_source.get("taxonomy", {}) as Dictionary
	var category := CATEGORY_PRESENTATION.get(str(taxonomy.get("category_id", "")), {}) as Dictionary
	var industry := INDUSTRY_PRESENTATION.get(str(taxonomy.get("industry_id", "")), {}) as Dictionary
	var target_texts: Array = [_semantic_target_text(semantic_spec)]
	var condition_texts := _semantic_condition_texts(semantic_spec)
	var effect_step_texts := _semantic_effect_step_texts(semantic_spec)
	var keyword_texts := _semantic_keyword_texts(
		localization_source,
		category,
		industry,
		semantic_spec
	)
	if keyword_texts.is_empty():
		return {}
	return {
		"name": str(authored_presentation.get("name", "")),
		"family_name": str(authored_presentation.get("name", "")),
		"category_label": str(category.get("label", "")),
		"industry_label": str(industry.get("label", "")),
		"acquisition_cost": _acquisition_cost_text(semantic_spec),
		"activation_cost": _activation_cost_text(semantic_spec),
		"timing": _semantic_timing_text(semantic_spec),
		"targets": target_texts,
		"conditions": condition_texts,
		"effect_steps": effect_step_texts,
		"duration": _semantic_duration_text(semantic_spec),
		"counterability": _counterability_text(semantic_spec),
		"information_scope": _semantic_information_scope_text(semantic_spec),
		"keywords": keyword_texts,
		"short_effect": str(authored_presentation.get("short_effect", "")),
		"full_effect": str(authored_presentation.get("full_effect", "")),
	}


func _semantic_keyword_rows(
	category_id: String,
	industry_id: String,
	timing_id: String,
	response_id: String,
	effects: Array,
	category: Dictionary,
	industry: Dictionary
) -> Array:
	var rows: Array = []
	_append_semantic_keyword(
		rows,
		"card.category.%s" % category_id,
		"category.%s" % category_id,
		str(category.get("icon_token_id", "")),
		str(category.get("color_token_id", ""))
	)
	_append_semantic_keyword(
		rows,
		"card.industry.%s" % industry_id,
		"industry.%s" % industry_id,
		str(industry.get("icon_token_id", "")),
		str(industry.get("color_token_id", ""))
	)
	_append_semantic_keyword(
		rows,
		"card.timing.%s" % timing_id,
		"timing.%s" % timing_id,
		"icon.card.timing.%s" % timing_id,
		"color.card.timing"
	)
	_append_semantic_keyword(
		rows,
		"card.response.%s" % response_id,
		"response.%s" % response_id,
		"icon.card.response.%s" % response_id,
		"color.card.response"
	)
	var seen_ops: Dictionary = {}
	for effect_variant in effects:
		var effect := effect_variant as Dictionary
		var op_id := str(effect.get("op_id", ""))
		if seen_ops.has(op_id):
			continue
		seen_ops[op_id] = true
		_append_semantic_keyword(
			rows,
			"card.operation.%s" % op_id,
			"operation.%s" % op_id,
			"icon.card.operation.%s" % op_id,
			"color.card.operation"
		)
	return rows if rows.size() <= 16 else []


func _semantic_keyword_texts(
	localization_source: Dictionary,
	category: Dictionary,
	industry: Dictionary,
	semantic_spec: Dictionary
) -> Array:
	var identity := semantic_spec.get("identity", {}) as Dictionary
	var timing := semantic_spec.get("timing", {}) as Dictionary
	var response := semantic_spec.get("response", {}) as Dictionary
	var text_by_keyword_id := {
		"card.category.%s" % str(identity.get("category_id", "")): str(category.get("label", "")),
		"card.industry.%s" % str(identity.get("industry_id", "generic")): str(industry.get("label", "")),
		"card.timing.%s" % str(timing.get("timing_id", "")): _semantic_timing_text(semantic_spec),
		"card.response.%s" % str(response.get("response_id", "")): _counterability_text(semantic_spec),
	}
	for effect_variant in semantic_spec.get("effect_ops", []) as Array:
		var effect := effect_variant as Dictionary
		var op_id := str(effect.get("op_id", ""))
		text_by_keyword_id["card.operation.%s" % op_id] = str(
			OPERATION_LABELS.get(op_id, op_id)
		)
	var result: Array = []
	for row_variant in localization_source.get("keyword_rows", []) as Array:
		var keyword_id := str((row_variant as Dictionary).get("keyword_id", ""))
		var text := str(text_by_keyword_id.get(keyword_id, ""))
		if text.strip_edges().is_empty():
			return []
		result.append(text)
	return result


func _append_semantic_keyword(
	rows: Array,
	keyword_id: String,
	message_suffix: String,
	icon_token_id: String,
	color_token_id: String
) -> void:
	rows.append({
		"keyword_id": keyword_id,
		"label_message_id": "card.keyword.%s.label" % message_suffix,
		"tooltip_message_id": "card.keyword.%s.tooltip" % message_suffix,
		"icon_token_id": icon_token_id,
		"color_token_id": color_token_id,
	})


func _collect_manifest_token_resolutions(
	localization_source: Dictionary,
	icon_values: Dictionary,
	color_values: Dictionary
) -> bool:
	var tokens := localization_source.get("presentation_tokens", {}) as Dictionary
	var icon_token_id := str(tokens.get("category_icon_token_id", ""))
	var category_color_token_id := str(tokens.get("category_color_token_id", ""))
	var industry_color_token_id := str(tokens.get("industry_color_token_id", ""))
	var category_icon_value := _known_icon_value(icon_token_id)
	var category_color_value := _known_color_value(category_color_token_id)
	var industry_color_value := _known_color_value(industry_color_token_id)
	if category_icon_value.is_empty() \
			or category_color_value.is_empty() \
			or industry_color_value.is_empty() \
			or not _register_token_value(icon_values, icon_token_id, category_icon_value) \
			or not _register_token_value(color_values, category_color_token_id, category_color_value) \
			or not _register_token_value(color_values, industry_color_token_id, industry_color_value):
		return false
	for row_variant in localization_source.get("keyword_rows", []) as Array:
		var row := row_variant as Dictionary
		icon_token_id = str(row.get("icon_token_id", ""))
		var color_token_id := str(row.get("color_token_id", ""))
		var icon_value := _known_icon_value(icon_token_id)
		var color_value := _known_color_value(color_token_id)
		if icon_value.is_empty() \
				or color_value.is_empty() \
				or not _register_token_value(icon_values, icon_token_id, icon_value) \
				or not _register_token_value(color_values, color_token_id, color_value):
			return false
	return true


func _known_icon_value(token_id: String) -> String:
	return TOKEN_MANIFEST.icon_value(token_id)


func _known_color_value(token_id: String) -> String:
	return TOKEN_MANIFEST.color_value(token_id)


func _register_token_value(
	registry: Dictionary,
	token_id: String,
	resolved_value: String
) -> bool:
	if not WIRE.is_stable_id(token_id) or resolved_value.is_empty():
		return false
	if registry.has(token_id):
		return str(registry.get(token_id, "")) == resolved_value
	registry[token_id] = resolved_value
	return true


func _authored_keyword_rows(card_record: Dictionary, card_id: String) -> Array:
	var player := card_record.get("player", {}) as Dictionary
	var keywords_value: Variant = player.get("keywords")
	if not (keywords_value is Array) \
			or (keywords_value as Array).is_empty() \
			or (keywords_value as Array).size() > 16:
		return []
	var rows: Array = []
	for index in range((keywords_value as Array).size()):
		rows.append({
			"keyword_id": "card.presentation.%s.keyword.%d" % [card_id, index + 1],
			"label_message_id": "card.authored.%s.keyword.%d.label" % [card_id, index + 1],
			"tooltip_message_id": "card.authored.%s.keyword.%d.tooltip" % [card_id, index + 1],
		})
	return rows


func _condition_ids(target: Dictionary, effects: Array) -> Array:
	var result: Array = []
	var seen: Dictionary = {}
	for filter_variant in target.get("filter_ids", []) as Array:
		_append_unique_id(result, seen, str(filter_variant))
	for effect_variant in effects:
		var effect := effect_variant as Dictionary
		if effect.get("condition_id") is String:
			_append_unique_id(result, seen, str(effect.get("condition_id", "")))
		if effect.get("condition_ids") is Array:
			for condition_variant in effect.get("condition_ids", []) as Array:
				_append_unique_id(result, seen, str(condition_variant))
	return result


func _append_unique_id(result: Array, seen: Dictionary, value: String) -> void:
	if value.is_empty() or seen.has(value):
		return
	seen[value] = true
	result.append(value)


func _has_duration_component(effects: Array) -> bool:
	for effect_variant in effects:
		var effect := effect_variant as Dictionary
		for parameter_id in DURATION_PARAMETER_IDS:
			if effect.has(parameter_id):
				return true
	return false


func _semantic_matches_registry(card_id: String, semantic_spec: Dictionary) -> bool:
	if not _sealed_semantic_fingerprint_by_card_id.has(card_id) \
			or _semantic_catalog_service == null \
			or not is_instance_valid(_semantic_catalog_service):
		return false
	var identity := semantic_spec.get("identity", {}) as Dictionary
	if str(identity.get("card_id", "")) != card_id \
			or str(semantic_spec.get("semantic_fingerprint", "")) != str(
				_sealed_semantic_fingerprint_by_card_id.get(card_id, "")
			):
		return false
	var authorized := _semantic_catalog_service.authorize_semantic_spec(semantic_spec)
	if not bool(authorized.get("ok", false)):
		return false
	var authorized_spec := authorized.get("spec", {}) as Dictionary
	return str(authorized_spec.get("semantic_fingerprint", "")) \
		== str(semantic_spec.get("semantic_fingerprint", ""))


func _catalog_machine_fingerprint(catalog_id: String, cards: Array) -> String:
	var machines: Array = []
	for record_variant in cards:
		if not (record_variant is Dictionary) \
				or not ((record_variant as Dictionary).get("machine") is Dictionary):
			return ""
		machines.append(((record_variant as Dictionary).get("machine") as Dictionary).duplicate(true))
	return CARD_SEMANTIC_SCHEMA.fingerprint({
		"source_catalog_id": catalog_id,
		"machines": machines,
	})


func _compiler_envelope(card_record: Dictionary, source_revision: int) -> Dictionary:
	return {
		"schema_version": CARD_SEMANTIC_SCHEMA.SCHEMA_VERSION,
		"source_kind": "public_rack",
		"source_revision": source_revision,
		"visibility_scope_id": "public",
		"card_record": card_record.duplicate(true),
	}


func _is_authorized_message_id(source: Dictionary, message_id: String) -> bool:
	for dictionary_field in ["structural_message_ids", "authored_message_ids"]:
		var messages := source.get(dictionary_field, {}) as Dictionary
		if messages.values().has(message_id):
			return true
	var taxonomy := source.get("taxonomy", {}) as Dictionary
	if taxonomy.values().has(message_id):
		return true
	for array_field in [
		"target_message_rows",
		"condition_message_rows",
		"effect_step_message_rows",
		"keyword_rows",
		"authored_keyword_rows",
	]:
		for row_variant in source.get(array_field, []) as Array:
			var row := row_variant as Dictionary
			if row.values().has(message_id):
				return true
	return false


func _resolved_message_text(
	message_id: String,
	source: Dictionary,
	semantic_spec: Dictionary,
	presentation_copy: Dictionary,
	authored_presentation: Dictionary
) -> String:
	var structural := source.get("structural_message_ids", {}) as Dictionary
	if message_id == str(structural.get("name", "")):
		return str(presentation_copy.get("name", ""))
	if message_id == str(structural.get("family_name", "")):
		return str(presentation_copy.get("family_name", ""))
	if message_id == str(structural.get("acquisition_cost", "")):
		return _acquisition_cost_text(semantic_spec)
	if message_id == str(structural.get("activation_cost", "")):
		return _activation_cost_text(semantic_spec)
	if message_id == str(structural.get("timing", "")):
		return str(presentation_copy.get("timing", ""))
	if message_id == str(structural.get("duration", "")):
		return str(presentation_copy.get("duration", ""))
	if message_id == str(structural.get("counterability", "")):
		return str(presentation_copy.get("counterability", ""))
	if message_id == str(structural.get("information_scope", "")):
		return str(presentation_copy.get("information_scope", ""))
	var target_rows := source.get("target_message_rows", []) as Array
	if not target_rows.is_empty() \
			and target_rows[0] is Dictionary \
			and message_id == str((target_rows[0] as Dictionary).get("message_id", "")):
		var target_texts := presentation_copy.get("targets", []) as Array
		return str(target_texts[0]) if not target_texts.is_empty() else ""
	var condition_rows := source.get("condition_message_rows", []) as Array
	var condition_texts := presentation_copy.get("conditions", []) as Array
	for index in range(condition_rows.size()):
		var row := condition_rows[index] as Dictionary
		if message_id == str(row.get("message_id", "")):
			return str(condition_texts[index]) if index < condition_texts.size() else ""
	var effect_rows := source.get("effect_step_message_rows", []) as Array
	var effect_texts := presentation_copy.get("effect_steps", []) as Array
	for index in range(effect_rows.size()):
		var row := effect_rows[index] as Dictionary
		if message_id == str(row.get("summary_message_id", "")):
			return str(effect_texts[index]) if index < effect_texts.size() else ""
		if message_id == str(row.get("detail_message_id", "")):
			return str(effect_texts[index]) if index < effect_texts.size() else ""
	var authored := source.get("authored_message_ids", {}) as Dictionary
	var authored_copy_fields := {
		"name": "name",
		"family_name": "family_name",
		"category_label": "category_label",
		"industry_label": "industry_label",
		"short_effect_summary": "short_effect",
		"effect_detail": "full_effect",
	}
	for authored_field in authored_copy_fields:
		if message_id == str(authored.get(authored_field, "")):
			return str(presentation_copy.get(authored_copy_fields[authored_field], ""))
	if message_id == str(authored.get("rank_label", "")):
		var source_binding := source.get("source_binding", {}) as Dictionary
		return str(RANK_LABELS.get(int(source_binding.get("rank", 0)), ""))
	var authored_internal_fields := {
		"authored_cost_summary": "authored_cost_summary",
		"timing_summary": "authored_timing_summary",
		"target_summary": "authored_target_summary",
		"duration_summary": "authored_duration_summary",
		"information_scope_summary": "authored_information_scope_summary",
		"next_step_summary": "authored_next_step_summary",
	}
	for authored_field in authored_internal_fields:
		if message_id == str(authored.get(authored_field, "")):
			return str(authored_presentation.get(
				authored_internal_fields[authored_field],
				""
			))
	var taxonomy := source.get("taxonomy", {}) as Dictionary
	if message_id == str(taxonomy.get("category_label_ref", "")):
		return str(presentation_copy.get("category_label", ""))
	if message_id == str(taxonomy.get("industry_label_ref", "")):
		return str(presentation_copy.get("industry_label", ""))
	var semantic_keyword_rows := source.get("keyword_rows", []) as Array
	var semantic_keyword_texts := presentation_copy.get("keywords", []) as Array
	for index in range(semantic_keyword_rows.size()):
		var semantic_keyword := semantic_keyword_rows[index] as Dictionary
		if message_id == str(semantic_keyword.get("label_message_id", "")) \
				or message_id == str(semantic_keyword.get("tooltip_message_id", "")):
			return str(semantic_keyword_texts[index]) \
				if index < semantic_keyword_texts.size() else ""
	var authored_keyword_rows := source.get("authored_keyword_rows", []) as Array
	var authored_copy_keyword_rows := authored_presentation.get("keyword_rows", []) as Array
	for index in range(mini(authored_keyword_rows.size(), authored_copy_keyword_rows.size())):
		var authored_keyword := authored_keyword_rows[index] as Dictionary
		var copy_keyword := authored_copy_keyword_rows[index] as Dictionary
		if message_id == str(authored_keyword.get("label_message_id", "")):
			return str(copy_keyword.get("label_text", ""))
		if message_id == str(authored_keyword.get("tooltip_message_id", "")):
			return str(copy_keyword.get("tooltip_text", ""))
	return ""


func _semantic_timing_text(semantic_spec: Dictionary) -> String:
	var timing := semantic_spec.get("timing", {}) as Dictionary
	var timing_id := str(timing.get("timing_id", ""))
	return str(TIMING_LABELS.get(timing_id, timing_id))


func _semantic_target_text(semantic_spec: Dictionary) -> String:
	var target := semantic_spec.get("target", {}) as Dictionary
	var target_id := str(target.get("target_id", ""))
	var selection_id := str(target.get("selection_id", ""))
	var cardinality_id := str(target.get("cardinality_id", ""))
	var filter_labels: Array[String] = []
	for filter_variant in target.get("filter_ids", []) as Array:
		var filter_id := str(filter_variant)
		filter_labels.append(str(CONDITION_LABELS.get(filter_id, filter_id)))
	return "%s；%s；%s；条件：%s" % [
		str(TARGET_LABELS.get(target_id, target_id)),
		str(SELECTION_LABELS.get(selection_id, selection_id)),
		str(CARDINALITY_LABELS.get(cardinality_id, cardinality_id)),
		"、".join(filter_labels),
	]


func _semantic_condition_texts(semantic_spec: Dictionary) -> Array:
	var target := semantic_spec.get("target", {}) as Dictionary
	var effects := semantic_spec.get("effect_ops", []) as Array
	var result: Array = []
	for condition_variant in _condition_ids(target, effects):
		var condition_id := str(condition_variant)
		result.append(str(CONDITION_LABELS.get(condition_id, condition_id)))
	return result


func _semantic_effect_step_texts(semantic_spec: Dictionary) -> Array:
	var result: Array = []
	var effects := semantic_spec.get("effect_ops", []) as Array
	for index in range(effects.size()):
		var effect := effects[index] as Dictionary
		var op_id := str(effect.get("op_id", ""))
		var parameters := _semantic_parameters_text(effect)
		var suffix := "" if parameters.is_empty() else "（%s）" % parameters
		result.append("%d. %s%s" % [
			index + 1,
			str(OPERATION_LABELS.get(op_id, op_id)),
			suffix,
		])
	return result


func _semantic_parameters_text(effect: Dictionary) -> String:
	var keys: Array[String] = []
	for key_variant in effect.keys():
		var key := str(key_variant)
		if key != "op_id" and PARAMETER_LABELS.has(key):
			keys.append(key)
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		var value_text := _semantic_value_text(effect.get(key))
		if value_text.is_empty():
			continue
		parts.append("%s=%s" % [
			str(PARAMETER_LABELS.get(key, "")),
			value_text,
		])
	return "；".join(parts)


func _semantic_value_text(value: Variant) -> String:
	if value is bool:
		return "是" if bool(value) else "否"
	if value is String:
		var value_id := str(value)
		if SEMANTIC_VALUE_LABELS.has(value_id):
			return str(SEMANTIC_VALUE_LABELS.get(value_id, ""))
		if INDUSTRY_PRESENTATION.has(value_id):
			return str((INDUSTRY_PRESENTATION.get(value_id, {}) as Dictionary).get(
				"label",
				""
			))
		return "" if WIRE.is_stable_id(value_id) else value_id
	if value is int or value is float:
		return str(value)
	if value is Array:
		var items: Array[String] = []
		for item in value as Array:
			var item_text := _semantic_value_text(item)
			if not item_text.is_empty():
				items.append(item_text)
		if items.is_empty():
			return ""
		return "[" + "、".join(items) + "]"
	if value is Dictionary:
		var keys: Array[String] = []
		for key_variant in (value as Dictionary).keys():
			var key := str(key_variant)
			if PARAMETER_LABELS.has(key):
				keys.append(key)
		keys.sort()
		var members: Array[String] = []
		for key in keys:
			var member_text := _semantic_value_text(
				(value as Dictionary).get(key)
			)
			if member_text.is_empty():
				continue
			members.append("%s=%s" % [
				str(PARAMETER_LABELS.get(key, "")),
				member_text,
			])
		return "{" + "；".join(members) + "}" if not members.is_empty() else ""
	return ""


func _semantic_duration_text(semantic_spec: Dictionary) -> String:
	var components: Array[String] = []
	var effects := semantic_spec.get("effect_ops", []) as Array
	for index in range(effects.size()):
		var effect := effects[index] as Dictionary
		for parameter_id in DURATION_PARAMETER_IDS:
			if not effect.has(parameter_id):
				continue
			components.append("步骤 %d · %s=%s" % [
				index + 1,
				str(PARAMETER_LABELS.get(parameter_id, parameter_id)),
				_semantic_value_text(effect.get(parameter_id)),
			])
	return "未声明持续参数" if components.is_empty() else "；".join(components)


func _semantic_information_scope_text(semantic_spec: Dictionary) -> String:
	var policy := semantic_spec.get("information_policy", {}) as Dictionary
	var policy_id := str(policy.get("visibility_policy_id", ""))
	return str(INFORMATION_SCOPE_LABELS.get(policy_id, policy_id))


func _acquisition_cost_text(semantic_spec: Dictionary) -> String:
	var acquisition := (
		(semantic_spec.get("cost", {}) as Dictionary).get("acquisition", {})
		as Dictionary
	)
	var cash := int(acquisition.get("purchase_cash", 0))
	return "免费领取" if cash == 0 else "获取：现金 %d" % cash


func _counterability_text(semantic_spec: Dictionary) -> String:
	var response := semantic_spec.get("response", {}) as Dictionary
	var response_id := str(response.get("response_id", ""))
	return str(RESPONSE_LABELS.get(response_id, response_id))


func _activation_cost_text(semantic_spec: Dictionary) -> String:
	var activation := (
		(semantic_spec.get("cost", {}) as Dictionary).get("activation", {})
		as Dictionary
	)
	var parts: Array[String] = []
	for asset_id in [
		"life",
		"energy",
		"industry",
		"technology",
		"commerce",
		"shipping",
		"generic",
	]:
		var amount := int(activation.get(asset_id, 0))
		if amount <= 0:
			continue
		var presentation := INDUSTRY_PRESENTATION.get(asset_id, {}) as Dictionary
		parts.append("%d %s资产" % [amount, str(presentation.get("label", asset_id))])
	return "打出免费" if parts.is_empty() else "打出：%s" % " + ".join(parts)


func _issue_rejected(reason_id: String) -> Dictionary:
	_last_reason_id = reason_id
	return {
		"accepted": false,
		"reason_id": reason_id,
		"localization_source": {},
		"authorization_receipt": {},
		"bundle_fingerprint": "",
	}


func _verify_rejected(reason_id: String) -> Dictionary:
	_last_reason_id = reason_id
	return {
		"accepted": false,
		"reason_id": reason_id,
		"projection_source": {},
		"localization_binding": {},
		"taxonomy": {},
		"presentation_tokens": {},
		"presentation_copy": {},
		"authorization_receipt": {},
		"bundle_fingerprint": "",
	}


func _resolution_rejected(reason_id: String) -> Dictionary:
	_last_reason_id = reason_id
	return {
		"accepted": false,
		"reason_id": reason_id,
		"message_id": "",
		"locale_id": "",
		"text": "",
	}
