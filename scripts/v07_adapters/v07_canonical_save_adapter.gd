extends RefCounted
class_name V07CanonicalSaveAdapter

const CODEC := preload(
	"res://scripts/v07_adapters/v07_canonical_data_codec.gd"
)
const UNIFIED_CORE := preload(
	"res://scripts/v07_semantic/v07_unified_card_track_core.gd"
)
const DBG_CORE := preload(
	"res://scripts/v07_semantic/v07_dbg_deck_core.gd"
)
const ASSET_BATCH_CORE := preload(
	"res://scripts/v07_semantic/v07_asset_batch_core.gd"
)
const SOLAR_VICTORY_CORE := preload(
	"res://scripts/v07_semantic/v07_solar_victory_core.gd"
)

const SCHEMA_VERSION := 2
const SAVE_SCHEMA_ID := "space_syndicate.v071.semantic_save.v1"
const CONSTITUTION_ID := "space_syndicate.v071.complete"
const RULESET_ID := "v0.7.1"
const RNG_REGISTRY_ID := "space_syndicate.v071.rng_ownership.v1"
const PLAN_SCHEMA_ID := "space_syndicate.v071.detached_restore_plan.v1"
const CHECKPOINT_SCHEMA_ID := "space_syndicate.v071.detached_restore_checkpoint.v1"
const BALANCE_PROFILE_ID := "V071_CANDIDATE_A_FAST"
const BALANCE_PROFILE_FINGERPRINT := (
	"8d8de8d406ca2f7d5123ecc951a606a0a08b56282bc3d6a40e0cd4d5ff50f19a"
)

const SOURCE_NEW_V07_GAME := "NEW_V071_GAME"
const SOURCE_V07_SAVE := "V07_SAVE"
const SOURCE_V06_SAVE := "V06_SAVE"
const V06_BACKUP_REQUIRED_REASON := "v06_save_backup_required"
const V07_DIRECT_RESUME_REJECTED_REASON := "v07_save_to_v071_direct_resume_forbidden"

const SECTION_UNIFIED := "unified_card_track_cycle"
const SECTION_DBG := "personal_dbg_and_merge"
const SECTION_ASSET := "six_color_assets_and_reservations"
const SECTION_BATCH := "card_batch_and_anonymous_resolution"
const SECTION_SOLAR := "solar_facility_and_macro_victory"
const SECTION_IDS := [
	SECTION_UNIFIED,
	SECTION_DBG,
	SECTION_ASSET,
	SECTION_BATCH,
	SECTION_SOLAR,
]

const ENVELOPE_FIELDS := [
	"schema_version",
	"save_schema_id",
	"ruleset_id",
	"save_id",
	"scenario_fingerprint",
	"repository_head",
	"created_at_utc",
	"balance_profile_id",
	"balance_profile_fingerprint",
	"sections",
	"rng_stream_states",
	"envelope_fingerprint",
]
const METADATA_FIELDS := [
	"save_id",
	"scenario_fingerprint",
	"repository_head",
	"created_at_utc",
	"balance_profile_id",
	"balance_profile_fingerprint",
]
const RNG_ROW_FIELDS := [
	"schema_version",
	"stream_id",
	"stream_instance_id",
	"state_profile_id",
	"authoritative_owner_id",
	"save_section_id",
	"state",
	"state_fingerprint",
]
const PLAN_FIELDS := [
	"schema_version",
	"plan_schema_id",
	"source_kind",
	"save_id",
	"envelope_fingerprint",
	"preflight_complete",
	"preflight_section_count",
	"restore_nodes",
	"target_snapshot",
	"plan_fingerprint",
]
const CHECKPOINT_FIELDS := [
	"schema_version",
	"checkpoint_schema_id",
	"plan_fingerprint",
	"snapshot_present",
	"snapshot",
	"snapshot_fingerprint",
	"checkpoint_fingerprint",
]

const RESTORE_NODE_SPECS := [
	{
		"node_id": "envelope_identity",
		"section_id": "envelope",
		"depends_on": [],
	},
	{
		"node_id": "rng_stream_states",
		"section_id": "rng_stream_states",
		"depends_on": ["envelope_identity"],
	},
	{
		"node_id": "personal_dbg_and_merge",
		"section_id": SECTION_DBG,
		"depends_on": ["envelope_identity", "rng_stream_states"],
	},
	{
		"node_id": "hidden_lead_cycle",
		"section_id": (
			"unified_card_track_cycle.authority_state.hidden_lead_cycle_state"
		),
		"depends_on": ["envelope_identity", "rng_stream_states"],
	},
	{
		"node_id": "unified_card_track_cycle",
		"section_id": SECTION_UNIFIED,
		"depends_on": [
			"envelope_identity",
			"rng_stream_states",
			"personal_dbg_and_merge",
			"hidden_lead_cycle",
		],
	},
	{
		"node_id": "six_color_assets_and_reservations",
		"section_id": SECTION_ASSET,
		"depends_on": ["envelope_identity"],
	},
	{
		"node_id": "card_batch_and_anonymous_resolution",
		"section_id": SECTION_BATCH,
		"depends_on": [
			"envelope_identity",
			"personal_dbg_and_merge",
			"hidden_lead_cycle",
			"unified_card_track_cycle",
			"six_color_assets_and_reservations",
		],
	},
	{
		"node_id": "solar_facility_state",
		"section_id": "solar_facility_and_macro_victory.state.solar",
		"depends_on": ["envelope_identity"],
	},
	{
		"node_id": "macro_round_victory_gate",
		"section_id": (
			"solar_facility_and_macro_victory.state.victory_gate"
		),
		"depends_on": [
			"envelope_identity",
			"hidden_lead_cycle",
			"card_batch_and_anonymous_resolution",
			"solar_facility_state",
		],
	},
	{
		"node_id": "atomic_restore_commit",
		"section_id": "transaction",
		"depends_on": [
			"rng_stream_states",
			"personal_dbg_and_merge",
			"hidden_lead_cycle",
			"unified_card_track_cycle",
			"six_color_assets_and_reservations",
			"card_batch_and_anonymous_resolution",
			"solar_facility_state",
			"macro_round_victory_gate",
		],
	},
]


static func capture_new_v07_game(
	metadata: Dictionary,
	sections: Dictionary
) -> Dictionary:
	var metadata_error := _metadata_error(metadata)
	if not metadata_error.is_empty():
		return _capture_failure(metadata_error)
	var section_preflight := _preflight_sections(sections)
	if not bool(section_preflight.get("accepted", false)):
		return _capture_failure(str(section_preflight.get(
			"reason_code", "section_preflight_failed"
		)))
	var rng_result := build_rng_stream_states(sections)
	if not bool(rng_result.get("accepted", false)):
		return _capture_failure(str(rng_result.get(
			"reason_code", "rng_stream_states_invalid"
		)))
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"save_schema_id": SAVE_SCHEMA_ID,
		"ruleset_id": RULESET_ID,
		"save_id": str(metadata.get("save_id", "")),
		"scenario_fingerprint": str(metadata.get("scenario_fingerprint", "")),
		"repository_head": str(metadata.get("repository_head", "")),
		"created_at_utc": str(metadata.get("created_at_utc", "")),
		"balance_profile_id": str(metadata.get("balance_profile_id", "")),
		"balance_profile_fingerprint": str(
			metadata.get("balance_profile_fingerprint", "")
		),
		"sections": sections.duplicate(true),
		"rng_stream_states": (
			rng_result.get("rows", []) as Array
		).duplicate(true),
	}
	var envelope := CODEC.seal(unsealed, "envelope_fingerprint")
	var preflight := preflight_restore(envelope, SOURCE_NEW_V07_GAME)
	if not bool(preflight.get("accepted", false)):
		return _capture_failure(str(preflight.get(
			"reason_code", "envelope_capture_preflight_failed"
		)))
	return {
		"accepted": true,
		"captured": true,
		"reason_code": "v071_canonical_envelope_captured",
		"source_kind": SOURCE_NEW_V07_GAME,
		"requires_backup": false,
		"section_count": SECTION_IDS.size(),
		"rng_stream_count": (envelope.get("rng_stream_states") as Array).size(),
		"envelope": envelope.duplicate(true),
		"canonical_text": CODEC.canonical_json(envelope),
		"envelope_fingerprint": str(envelope.get("envelope_fingerprint", "")),
	}


static func compose_new_v07_game_envelope(
	metadata: Dictionary,
	sections: Dictionary
) -> Dictionary:
	var capture := capture_new_v07_game(metadata, sections)
	return (capture.get("envelope", {}) as Dictionary).duplicate(true) \
		if bool(capture.get("captured", false)) else {}


static func preflight_restore(
	candidate: Variant,
	source_kind: String = SOURCE_NEW_V07_GAME
) -> Dictionary:
	if _looks_like_v07_save(candidate, source_kind):
		return _source_rejection(
			V07_DIRECT_RESUME_REJECTED_REASON, source_kind, false
		)
	if _looks_like_v06_save(candidate, source_kind):
		return _source_rejection(
			V06_BACKUP_REQUIRED_REASON, source_kind, true
		)
	if source_kind != SOURCE_NEW_V07_GAME:
		return _source_rejection(
			"new_v071_game_source_required", source_kind, false
		)
	if not (candidate is Dictionary):
		return _preflight_failure("envelope_not_dictionary", 0, 0)
	var envelope := _normalize_envelope_wire_numbers(candidate as Dictionary)
	var envelope_result := _validate_envelope(envelope)
	if not bool(envelope_result.get("accepted", false)):
		return envelope_result
	return {
		"accepted": true,
		"reason_code": "v071_canonical_envelope_preflight_green",
		"source_kind": SOURCE_NEW_V07_GAME,
		"requires_backup": false,
		"backup_required": false,
		"direct_resume_allowed": true,
		"envelope_valid": true,
		"preflight_complete": true,
		"preflight_count": SECTION_IDS.size(),
		"section_count": SECTION_IDS.size(),
		"rng_stream_count": (
			envelope.get("rng_stream_states", []) as Array
		).size(),
		"normalized_envelope": envelope.duplicate(true),
		"canonical_text": CODEC.canonical_json(envelope),
	}


static func preflight_envelope(
	candidate: Variant,
	source_kind: String = SOURCE_NEW_V07_GAME
) -> Dictionary:
	return preflight_restore(candidate, source_kind)


static func build_rng_stream_states(sections: Dictionary) -> Dictionary:
	if not CODEC.has_exact_fields(sections, SECTION_IDS):
		return _rng_failure("section_set_invalid")
	if not (sections.get(SECTION_UNIFIED) is Dictionary) \
			or not (sections.get(SECTION_DBG) is Array):
		return _rng_failure("rng_source_sections_invalid")
	var rows: Array = []
	var dbg_payloads := sections.get(SECTION_DBG, []) as Array
	for payload_variant in dbg_payloads:
		if not (payload_variant is Dictionary):
			return _rng_failure("dbg_rng_payload_invalid")
		var payload := payload_variant as Dictionary
		var state_variant: Variant = payload.get("state")
		if not (state_variant is Dictionary):
			return _rng_failure("dbg_rng_state_invalid")
		var state := state_variant as Dictionary
		var player_id := str(state.get("owner_player_id", ""))
		for spec_variant in [
			{
				"stream_id": "starter_deck_shuffle",
				"state_field": "starter_rng",
			},
			{
				"stream_id": "normal_deck_reshuffle_by_player",
				"state_field": "reshuffle_rng",
			},
		]:
			var spec := spec_variant as Dictionary
			var embedded_variant: Variant = state.get(str(spec.get("state_field", "")))
			if not (embedded_variant is Dictionary):
				return _rng_failure("dbg_rng_state_invalid")
			var embedded := embedded_variant as Dictionary
			if str(embedded.get("stream_id", "")) != str(spec.get("stream_id", "")) \
					or str(embedded.get("stream_instance_id", "")) != player_id:
				return _rng_failure("dbg_rng_identity_mismatch")
			rows.append(_rng_row(
				str(spec.get("stream_id", "")),
				player_id,
				"dbg_tagged_sha256_counter_v1",
				DBG_CORE.RNG_AUTHORITY_OWNER_ID,
				SECTION_DBG,
				embedded
			))

	var unified := sections.get(SECTION_UNIFIED) as Dictionary
	var authority_variant: Variant = unified.get("authority_state")
	if not (authority_variant is Dictionary):
		return _rng_failure("unified_rng_authority_state_invalid")
	var authority := authority_variant as Dictionary
	var unified_specs := [
		{
			"stream_id": "unified_track_type_draw",
			"path": ["type_supply_state"],
		},
		{
			"stream_id": "unified_track_color_draw",
			"path": ["color_cycle_state", "color_supply_state"],
		},
		{
			"stream_id": "unified_track_normal_card_draw",
			"path": ["normal_supply_state"],
		},
		{
			"stream_id": "unified_track_commodity_draw",
			"path": ["commodity_supply_state"],
		},
		{
			"stream_id": "initial_hidden_lead_order",
			"path": ["hidden_lead_cycle_state"],
		},
	]
	for spec_variant in unified_specs:
		var spec := spec_variant as Dictionary
		var embedded_variant: Variant = _value_at_path(
			authority, spec.get("path", []) as Array
		)
		if not (embedded_variant is Dictionary):
			return _rng_failure("unified_rng_state_invalid")
		var embedded := embedded_variant as Dictionary
		if str(embedded.get("stream_id", "")) != str(spec.get("stream_id", "")) \
				or not (embedded.get("rng_state") is int) \
				or not (embedded.get("rng_draw_count") is int):
			return _rng_failure("unified_rng_identity_mismatch")
		rows.append(_rng_row(
			str(spec.get("stream_id", "")),
			"global",
			"unified_park_miller_embedded_v1",
			UNIFIED_CORE.CORE_INTERFACE_ID,
			SECTION_UNIFIED,
			{
				"rng_state": int(embedded.get("rng_state", 0)),
				"rng_draw_count": int(embedded.get("rng_draw_count", -1)),
			}
		))
	rows.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			var left_key := "%s|%s" % [
				str(left.get("stream_id", "")),
				str(left.get("stream_instance_id", "")),
			]
			var right_key := "%s|%s" % [
				str(right.get("stream_id", "")),
				str(right.get("stream_instance_id", "")),
			]
			return left_key < right_key
	)
	var seen := {}
	for row_variant in rows:
		var row := row_variant as Dictionary
		if row.is_empty() or not CODEC.has_exact_fields(row, RNG_ROW_FIELDS):
			return _rng_failure("rng_row_build_failed")
		var key := "%s|%s" % [
			str(row.get("stream_id", "")),
			str(row.get("stream_instance_id", "")),
		]
		if seen.has(key):
			return _rng_failure("rng_stream_instance_duplicate")
		seen[key] = true
	var expected_count := 5 + (2 * dbg_payloads.size())
	if rows.size() != expected_count:
		return _rng_failure("rng_stream_count_invalid")
	return {
		"accepted": true,
		"reason_code": "canonical_rng_stream_states_built",
		"rng_registry_id": RNG_REGISTRY_ID,
		"logical_stream_count": 7,
		"concrete_stream_count": rows.size(),
		"rows": rows.duplicate(true),
	}


static func canonical_rng_stream_states(sections: Dictionary) -> Array:
	var result := build_rng_stream_states(sections)
	return (result.get("rows", []) as Array).duplicate(true) \
		if bool(result.get("accepted", false)) else []


static func build_detached_restore_plan(
	candidate: Variant,
	source_kind: String = SOURCE_NEW_V07_GAME
) -> Dictionary:
	var preflight := preflight_restore(candidate, source_kind)
	if not bool(preflight.get("accepted", false)):
		return {
			"accepted": false,
			"reason_code": str(preflight.get(
				"reason_code", "restore_preflight_failed"
			)),
			"requires_backup": bool(preflight.get("requires_backup", false)),
			"plan": {},
		}
	var envelope := preflight.get("normalized_envelope", {}) as Dictionary
	var plan := _build_plan_unchecked(envelope)
	if plan.is_empty():
		return {
			"accepted": false,
			"reason_code": "detached_restore_plan_build_failed",
			"requires_backup": false,
			"plan": {},
		}
	return {
		"accepted": true,
		"reason_code": "v07_detached_restore_plan_ready",
		"requires_backup": false,
		"preflight_complete": true,
		"node_count": RESTORE_NODE_SPECS.size(),
		"plan": plan.duplicate(true),
	}


static func build_restore_plan(
	candidate: Variant,
	source_kind: String = SOURCE_NEW_V07_GAME
) -> Dictionary:
	return build_detached_restore_plan(candidate, source_kind)


static func preflight_restore_plan(plan: Dictionary) -> Dictionary:
	var reason := _plan_error(plan)
	return {
		"accepted": reason.is_empty(),
		"reason_code": (
			"v07_detached_restore_plan_valid"
			if reason.is_empty()
			else reason
		),
		"preflight_complete": reason.is_empty(),
		"node_count": (
			(plan.get("restore_nodes", []) as Array).size()
			if plan.get("restore_nodes", []) is Array
			else 0
		),
	}


static func capture_checkpoint(
	current_snapshot: Dictionary,
	plan: Dictionary
) -> Dictionary:
	if not _plan_error(plan).is_empty() \
			or not _snapshot_error(current_snapshot).is_empty():
		return {}
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"checkpoint_schema_id": CHECKPOINT_SCHEMA_ID,
		"plan_fingerprint": str(plan.get("plan_fingerprint", "")),
		"snapshot_present": not current_snapshot.is_empty(),
		"snapshot": current_snapshot.duplicate(true),
		"snapshot_fingerprint": CODEC.fingerprint(current_snapshot),
	}
	return CODEC.seal(unsealed, "checkpoint_fingerprint")


static func capture_restore_checkpoint(
	current_snapshot: Dictionary,
	plan: Dictionary
) -> Dictionary:
	return capture_checkpoint(current_snapshot, plan)


static func execute_detached_restore(
	plan: Dictionary,
	current_snapshot: Dictionary = {},
	failure_node_id: String = ""
) -> Dictionary:
	var plan_reason := _plan_error(plan)
	if not plan_reason.is_empty():
		return _execution_failure(plan_reason)
	var checkpoint := capture_checkpoint(current_snapshot, plan)
	if checkpoint.is_empty():
		return _execution_failure("detached_restore_checkpoint_capture_failed")
	var node_ids := restore_node_ids()
	if not failure_node_id.is_empty() and failure_node_id not in node_ids:
		return _execution_failure("detached_restore_failure_node_unknown")
	var applied_node_ids: Array[String] = []
	for node_id in node_ids:
		if node_id == failure_node_id:
			var rollback := rollback_to_checkpoint(
				checkpoint, plan, applied_node_ids
			)
			return {
				"accepted": false,
				"applied": false,
				"committed": false,
				"reason_code": "detached_restore_node_rejected.%s" % node_id,
				"source_kind": SOURCE_NEW_V07_GAME,
				"checkpoint_captured": true,
				"rollback_attempted": not applied_node_ids.is_empty(),
				"rollback_complete": bool(rollback.get("rolled_back", false)),
				"applied_node_ids": applied_node_ids.duplicate(),
				"rollback_node_ids": (
					rollback.get("rollback_node_ids", []) as Array
				).duplicate(),
				"checkpoint": checkpoint.duplicate(true),
				"rollback": rollback.duplicate(true),
				"snapshot": (
					rollback.get("snapshot", {}) as Dictionary
				).duplicate(true),
			}
		applied_node_ids.append(node_id)
	var target := plan.get("target_snapshot", {}) as Dictionary
	return {
		"accepted": true,
		"applied": true,
		"committed": true,
		"reason_code": "v07_detached_restore_committed",
		"source_kind": SOURCE_NEW_V07_GAME,
		"checkpoint_captured": true,
		"rollback_attempted": false,
		"rollback_complete": true,
		"applied_node_ids": applied_node_ids.duplicate(),
		"rollback_node_ids": [],
		"checkpoint": checkpoint.duplicate(true),
		"snapshot": target.duplicate(true),
		"snapshot_fingerprint": CODEC.fingerprint(target),
		"envelope_fingerprint": str(target.get("envelope_fingerprint", "")),
	}


static func apply_restore_plan(
	plan: Dictionary,
	current_snapshot: Dictionary = {},
	failure_node_id: String = ""
) -> Dictionary:
	return execute_detached_restore(plan, current_snapshot, failure_node_id)


static func rollback_to_checkpoint(
	checkpoint: Dictionary,
	plan: Dictionary,
	applied_node_ids: Array = []
) -> Dictionary:
	var plan_reason := _plan_error(plan)
	if not plan_reason.is_empty():
		return _rollback_failure(plan_reason)
	var checkpoint_reason := _checkpoint_error(checkpoint, plan)
	if not checkpoint_reason.is_empty():
		return _rollback_failure(checkpoint_reason)
	var prefix_reason := _applied_node_prefix_error(applied_node_ids)
	if not prefix_reason.is_empty():
		return _rollback_failure(prefix_reason)
	var rollback_node_ids: Array = applied_node_ids.duplicate()
	rollback_node_ids.reverse()
	var snapshot := checkpoint.get("snapshot", {}) as Dictionary
	return {
		"accepted": true,
		"rolled_back": true,
		"reason_code": "v07_detached_checkpoint_restored",
		"rollback_complete": true,
		"rollback_node_ids": rollback_node_ids,
		"snapshot_present": bool(checkpoint.get("snapshot_present", false)),
		"snapshot": snapshot.duplicate(true),
		"snapshot_fingerprint": str(
			checkpoint.get("snapshot_fingerprint", "")
		),
		"plan_fingerprint": str(plan.get("plan_fingerprint", "")),
	}


static func rollback(
	checkpoint: Dictionary,
	plan: Dictionary,
	applied_node_ids: Array = []
) -> Dictionary:
	return rollback_to_checkpoint(checkpoint, plan, applied_node_ids)


static func recapture_exact(snapshot: Dictionary) -> Dictionary:
	if not _snapshot_error(snapshot).is_empty() or snapshot.is_empty():
		return {}
	var unsealed := {}
	for field_variant in ENVELOPE_FIELDS:
		var field := str(field_variant)
		if field != "envelope_fingerprint":
			unsealed[field] = CODEC.deep_copy(snapshot.get(field))
	return CODEC.seal(unsealed, "envelope_fingerprint")


static func exact_roundtrip(
	candidate: Variant,
	source_kind: String = SOURCE_NEW_V07_GAME
) -> Dictionary:
	var preflight := preflight_restore(candidate, source_kind)
	if not bool(preflight.get("accepted", false)):
		return _roundtrip_failure(
			str(preflight.get("reason_code", "restore_preflight_failed")),
			bool(preflight.get("requires_backup", false))
		)
	var envelope := preflight.get("normalized_envelope", {}) as Dictionary
	var original_text := CODEC.canonical_json(envelope)
	var decoded := CODEC.decode_text(original_text, true)
	if not bool(decoded.get("accepted", false)) \
			or not (decoded.get("value") is Dictionary):
		return _roundtrip_failure("canonical_decode_failed", false)
	var decoded_envelope := decoded.get("value") as Dictionary
	var decoded_preflight := preflight_restore(
		decoded_envelope, SOURCE_NEW_V07_GAME
	)
	if not bool(decoded_preflight.get("accepted", false)):
		return _roundtrip_failure(str(decoded_preflight.get(
			"reason_code", "decoded_envelope_preflight_failed"
		)), false)
	var plan_result := build_detached_restore_plan(
		decoded_envelope, SOURCE_NEW_V07_GAME
	)
	if not bool(plan_result.get("accepted", false)):
		return _roundtrip_failure(str(plan_result.get(
			"reason_code", "detached_restore_plan_failed"
		)), false)
	var plan := plan_result.get("plan", {}) as Dictionary
	var execution := execute_detached_restore(plan)
	if not bool(execution.get("committed", false)):
		return _roundtrip_failure(str(execution.get(
			"reason_code", "detached_restore_commit_failed"
		)), false)
	var recaptured := recapture_exact(
		execution.get("snapshot", {}) as Dictionary
	)
	var recaptured_text := CODEC.canonical_json(recaptured)
	var exact: bool = not recaptured.is_empty() \
		and recaptured == envelope \
		and recaptured_text == original_text \
		and recaptured.get("envelope_fingerprint") \
			== envelope.get("envelope_fingerprint")
	return {
		"accepted": exact,
		"exact": exact,
		"reason_code": (
			"v07_canonical_roundtrip_exact"
			if exact
			else "v07_canonical_roundtrip_mismatch"
		),
		"requires_backup": false,
		"source_kind": SOURCE_NEW_V07_GAME,
		"section_count": SECTION_IDS.size(),
		"rng_stream_count": (
			envelope.get("rng_stream_states", []) as Array
		).size(),
		"node_count": RESTORE_NODE_SPECS.size(),
		"canonical_byte_count": original_text.to_utf8_buffer().size(),
		"envelope_fingerprint": str(
			envelope.get("envelope_fingerprint", "")
		),
		"recaptured_envelope": recaptured.duplicate(true),
		"plan_fingerprint": str(plan.get("plan_fingerprint", "")),
	}


static func roundtrip(
	candidate: Variant,
	source_kind: String = SOURCE_NEW_V07_GAME
) -> Dictionary:
	return exact_roundtrip(candidate, source_kind)


static func restore_node_ids() -> Array[String]:
	var result: Array[String] = []
	for spec_variant in RESTORE_NODE_SPECS:
		result.append(str((spec_variant as Dictionary).get("node_id", "")))
	return result


static func adapter_contract() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"save_schema_id": SAVE_SCHEMA_ID,
		"constitution_id": CONSTITUTION_ID,
		"ruleset_id": RULESET_ID,
		"target_ruleset_id": RULESET_ID,
		"balance_profile_id": BALANCE_PROFILE_ID,
		"balance_profile_fingerprint": BALANCE_PROFILE_FINGERPRINT,
		"source_kinds_allowed": [SOURCE_NEW_V07_GAME],
		"v07_direct_resume_allowed": false,
		"v07_test_only_migration_requires_explicit_contract": true,
		"v06_direct_resume_allowed": false,
		"v06_backup_required": true,
		"section_ids": SECTION_IDS.duplicate(),
		"section_count": SECTION_IDS.size(),
		"restore_node_ids": restore_node_ids(),
		"restore_node_count": RESTORE_NODE_SPECS.size(),
		"all_preflight_before_apply": true,
		"detached_restore_only": true,
		"checkpoint_before_apply": true,
		"reverse_order_rollback": true,
		"exact_recapture": true,
		"production_runtime_connected": false,
	}


static func _validate_envelope(envelope: Dictionary) -> Dictionary:
	if not CODEC.is_pure_data(envelope):
		return _preflight_failure("envelope_not_pure_data", 0, 0)
	if not CODEC.has_exact_fields(envelope, ENVELOPE_FIELDS):
		return _preflight_failure("envelope_fields_invalid", 0, 0)
	if not (envelope.get("schema_version") is int) \
			or int(envelope.get("schema_version", -1)) != SCHEMA_VERSION \
			or envelope.get("save_schema_id") != SAVE_SCHEMA_ID \
			or envelope.get("ruleset_id") != RULESET_ID:
		return _preflight_failure("envelope_identity_invalid", 0, 0)
	var metadata := {}
	for field_variant in METADATA_FIELDS:
		var field := str(field_variant)
		metadata[field] = envelope.get(field)
	var metadata_error := _metadata_error(metadata)
	if not metadata_error.is_empty():
		return _preflight_failure(metadata_error, 0, 0)
	if not (envelope.get("sections") is Dictionary) \
			or not (envelope.get("rng_stream_states") is Array):
		return _preflight_failure("envelope_payload_types_invalid", 0, 0)
	if not CODEC.is_fingerprint(envelope.get("envelope_fingerprint")) \
			or str(envelope.get("envelope_fingerprint", "")) \
				!= CODEC.fingerprint(envelope, "envelope_fingerprint"):
		return _preflight_failure("envelope_fingerprint_invalid", 0, 0)
	var sections := envelope.get("sections") as Dictionary
	var section_preflight := _preflight_sections(sections)
	if not bool(section_preflight.get("accepted", false)):
		return _preflight_failure(
			str(section_preflight.get("reason_code", "section_preflight_failed")),
			int(section_preflight.get("preflight_count", 0)),
			0
		)
	var expected_rng := build_rng_stream_states(sections)
	if not bool(expected_rng.get("accepted", false)):
		return _preflight_failure(str(expected_rng.get(
			"reason_code", "rng_stream_states_invalid"
		)), SECTION_IDS.size(), 0)
	var observed_rows := envelope.get("rng_stream_states") as Array
	var expected_rows := expected_rng.get("rows", []) as Array
	if observed_rows != expected_rows:
		return _preflight_failure(
			"canonical_rng_stream_states_mismatch",
			SECTION_IDS.size(),
			observed_rows.size()
		)
	return {
		"accepted": true,
		"reason_code": "envelope_valid",
		"preflight_count": SECTION_IDS.size(),
		"rng_stream_count": observed_rows.size(),
	}


static func _preflight_sections(sections: Dictionary) -> Dictionary:
	if not CODEC.is_pure_data(sections) \
			or not CODEC.has_exact_fields(sections, SECTION_IDS):
		return _section_failure("section_set_invalid", 0)
	var preflight_count := 0
	var unified_variant: Variant = sections.get(SECTION_UNIFIED)
	if not (unified_variant is Dictionary):
		return _section_failure(
			"section_preflight_failed.%s.payload_invalid" % SECTION_UNIFIED,
			preflight_count
		)
	var unified := unified_variant as Dictionary
	var unified_reason := str(UNIFIED_CORE._save_state_error(unified))
	if not unified_reason.is_empty():
		return _section_failure(
			"section_preflight_failed.%s.%s" % [SECTION_UNIFIED, unified_reason],
			preflight_count
		)
	preflight_count += 1

	var dbg_variant: Variant = sections.get(SECTION_DBG)
	if not (dbg_variant is Array):
		return _section_failure(
			"section_preflight_failed.%s.payload_invalid" % SECTION_DBG,
			preflight_count
		)
	var dbg_payloads := dbg_variant as Array
	var previous_owner := ""
	var seen_owners := {}
	for payload_variant in dbg_payloads:
		if not (payload_variant is Dictionary):
			return _section_failure(
				"section_preflight_failed.%s.player_payload_invalid" % SECTION_DBG,
				preflight_count
			)
		var payload := payload_variant as Dictionary
		var dbg_reason := str(DBG_CORE.validate_save_state(payload))
		if not dbg_reason.is_empty():
			return _section_failure(
				"section_preflight_failed.%s.%s" % [SECTION_DBG, dbg_reason],
				preflight_count
			)
		var owner_id := str((payload.get("state") as Dictionary).get(
			"owner_player_id", ""
		))
		if seen_owners.has(owner_id) \
				or (not previous_owner.is_empty() and owner_id <= previous_owner):
			return _section_failure(
				"section_preflight_failed.%s.player_order_invalid" % SECTION_DBG,
				preflight_count
			)
		seen_owners[owner_id] = true
		previous_owner = owner_id
	preflight_count += 1

	var asset_variant: Variant = sections.get(SECTION_ASSET)
	if not (asset_variant is Dictionary):
		return _section_failure(
			"section_preflight_failed.%s.payload_invalid" % SECTION_ASSET,
			preflight_count
		)
	var asset := asset_variant as Dictionary
	var asset_preflight := ASSET_BATCH_CORE.restore_domain_save_state(
		asset, ASSET_BATCH_CORE.ASSET_SAVE_STATE_ID
	)
	if not bool(asset_preflight.get("preflight_valid", false)):
		return _section_failure(
			"section_preflight_failed.%s.%s" % [
				SECTION_ASSET,
				str(asset_preflight.get("reason_code", "domain_save_invalid")),
			],
			preflight_count
		)
	preflight_count += 1

	var batch_variant: Variant = sections.get(SECTION_BATCH)
	if not (batch_variant is Dictionary):
		return _section_failure(
			"section_preflight_failed.%s.payload_invalid" % SECTION_BATCH,
			preflight_count
		)
	var batch := batch_variant as Dictionary
	var batch_preflight := ASSET_BATCH_CORE.restore_domain_save_state(
		batch, ASSET_BATCH_CORE.BATCH_SAVE_STATE_ID
	)
	if not bool(batch_preflight.get("preflight_valid", false)):
		return _section_failure(
			"section_preflight_failed.%s.%s" % [
				SECTION_BATCH,
				str(batch_preflight.get("reason_code", "domain_save_invalid")),
			],
			preflight_count
		)
	preflight_count += 1
	var pair_preflight := ASSET_BATCH_CORE.restore_domain_save_pair(asset, batch)
	if not bool(pair_preflight.get("restored", false)) \
			or asset.get("state_revision") != batch.get("state_revision"):
		return _section_failure(
			"section_pair_preflight_failed.%s" % str(pair_preflight.get(
				"reason_code", "domain_save_pair_revision_mismatch"
			)),
			preflight_count
		)

	var solar_variant: Variant = sections.get(SECTION_SOLAR)
	if not (solar_variant is Dictionary):
		return _section_failure(
			"section_preflight_failed.%s.payload_invalid" % SECTION_SOLAR,
			preflight_count
		)
	var solar_state := SOLAR_VICTORY_CORE.from_save_state(
		solar_variant as Dictionary
	)
	if solar_state.is_empty():
		return _section_failure(
			"section_preflight_failed.%s.save_state_invalid" % SECTION_SOLAR,
			preflight_count
		)
	preflight_count += 1

	var cross_reason := _cross_section_error(sections, solar_state)
	if not cross_reason.is_empty():
		return _section_failure(
			"cross_section_preflight_failed.%s" % cross_reason,
			preflight_count
		)
	return {
		"accepted": true,
		"reason_code": "all_five_section_preflights_green",
		"preflight_count": preflight_count,
	}


static func _cross_section_error(
	sections: Dictionary,
	solar_state: Dictionary
) -> String:
	var unified := sections.get(SECTION_UNIFIED) as Dictionary
	var authority := unified.get("authority_state") as Dictionary
	if authority.get("match_instance_id_explicit") != true:
		return "unified_match_instance_id_not_explicit"
	var roster := authority.get("roster_ids", []) as Array
	var roster_ids := _string_array(roster)
	if roster_ids.is_empty():
		return "unified_roster_invalid"
	var dbg_owners: Array[String] = []
	for payload_variant in sections.get(SECTION_DBG) as Array:
		var payload := payload_variant as Dictionary
		dbg_owners.append(str((payload.get("state") as Dictionary).get(
			"owner_player_id", ""
		)))
	if not _same_string_set(dbg_owners, roster_ids):
		return "personal_dbg_roster_mismatch"

	var asset := sections.get(SECTION_ASSET) as Dictionary
	var batch := sections.get(SECTION_BATCH) as Dictionary
	var shared_state := asset.get("shared_authority_state") as Dictionary
	if not _same_string_set(
		_string_array(shared_state.get("player_ids", []) as Array), roster_ids
	):
		return "asset_batch_roster_mismatch"
	if asset.get("shared_batch_id") != batch.get("shared_batch_id") \
			or asset.get("shared_lineage_fingerprint") \
				!= batch.get("shared_lineage_fingerprint") \
			or asset.get("state_revision") != batch.get("state_revision") \
			or asset.get("shared_authority_state") \
				!= batch.get("shared_authority_state"):
		return "asset_batch_shared_state_mismatch"

	var hidden := authority.get("hidden_lead_cycle_state") as Dictionary
	var round_order := _string_array(hidden.get("round_order", []) as Array)
	if not _same_string_set(round_order, roster_ids):
		return "hidden_lead_roster_mismatch"
	var submission_order := _string_array(
		shared_state.get("submission_hidden_lead_order", []) as Array
	)
	if submission_order != round_order:
		return "asset_batch_hidden_lead_order_mismatch"
	var frozen_order := _string_array(
		shared_state.get("frozen_hidden_lead_order", []) as Array
	)
	if not frozen_order.is_empty() and frozen_order != round_order:
		return "asset_batch_frozen_hidden_lead_order_mismatch"

	if str(solar_state.get("match_instance_id", "")) \
			!= str(authority.get("match_instance_id", "")):
		return "solar_match_instance_id_mismatch"
	if int((solar_state.get("victory_gate") as Dictionary).get(
		"macro_round_index", -1
	)) != int(hidden.get("macro_round_number", -2)):
		return "macro_round_index_mismatch"

	var lineage_basis := {
		"schema_version": int(authority.get("schema_version", 0)),
		"state_version": int(authority.get("state_version", 0)),
		"ruleset_id": str(authority.get("ruleset_id", "")),
		"domain_id": str(authority.get("domain_id", "")),
		"match_instance_id": str(authority.get("match_instance_id", "")),
		"match_seed": int(authority.get("match_seed", 0)),
		"roster_ids": roster.duplicate(true),
	}
	var expected_lineage := UNIFIED_CORE.fingerprint(lineage_basis)
	for payload_variant in sections.get(SECTION_DBG) as Array:
		var state := (payload_variant as Dictionary).get("state") as Dictionary
		var bound := state.get("bound_source_state") as Dictionary
		var entries := bound.get("entries", []) as Array
		if entries.size() == 1:
			var entry := entries[0] as Dictionary
			if str(entry.get("match_instance_id", "")) \
					!= str(authority.get("match_instance_id", "")) \
					or str(entry.get("lineage_fingerprint", "")) \
						!= expected_lineage:
				return "personal_dbg_bound_track_lineage_mismatch"

	var seen_locations := {}
	for item_variant in (
		(authority.get("track_state") as Dictionary).get("items", []) as Array
	):
		var duplicate_reason := _register_location(
			seen_locations, item_variant, "unified_track"
		)
		if not duplicate_reason.is_empty():
			return duplicate_reason
	for payload_variant in sections.get(SECTION_DBG) as Array:
		var state := (payload_variant as Dictionary).get("state") as Dictionary
		var owner_id := str(state.get("owner_player_id", ""))
		for zone in [
			"draw_pile", "hand", "committed_escrow", "discard",
			"commodity_inventory",
		]:
			for item_variant in state.get(zone, []) as Array:
				var duplicate_reason := _register_location(
					seen_locations, item_variant, "%s.%s" % [owner_id, zone]
				)
				if not duplicate_reason.is_empty():
					return duplicate_reason
	return ""


static func _build_plan_unchecked(envelope: Dictionary) -> Dictionary:
	var sections := envelope.get("sections") as Dictionary
	var unified := sections.get(SECTION_UNIFIED) as Dictionary
	var authority := unified.get("authority_state") as Dictionary
	var solar_state := SOLAR_VICTORY_CORE.from_save_state(
		sections.get(SECTION_SOLAR) as Dictionary
	)
	if solar_state.is_empty():
		return {}
	var nodes: Array = []
	for index in range(RESTORE_NODE_SPECS.size()):
		var spec := RESTORE_NODE_SPECS[index] as Dictionary
		var node_id := str(spec.get("node_id", ""))
		var payload: Variant
		match node_id:
			"envelope_identity":
				payload = {
					"save_schema_id": SAVE_SCHEMA_ID,
					"ruleset_id": RULESET_ID,
					"save_id": str(envelope.get("save_id", "")),
					"scenario_fingerprint": str(
						envelope.get("scenario_fingerprint", "")
					),
					"repository_head": str(envelope.get("repository_head", "")),
					"created_at_utc": str(envelope.get("created_at_utc", "")),
					"envelope_fingerprint": str(
						envelope.get("envelope_fingerprint", "")
					),
				}
			"rng_stream_states":
				payload = (envelope.get("rng_stream_states") as Array).duplicate(true)
			"personal_dbg_and_merge":
				payload = (sections.get(SECTION_DBG) as Array).duplicate(true)
			"hidden_lead_cycle":
				payload = (
					authority.get("hidden_lead_cycle_state") as Dictionary
				).duplicate(true)
			"unified_card_track_cycle":
				payload = unified.duplicate(true)
			"six_color_assets_and_reservations":
				payload = (
					sections.get(SECTION_ASSET) as Dictionary
				).duplicate(true)
			"card_batch_and_anonymous_resolution":
				payload = (
					sections.get(SECTION_BATCH) as Dictionary
				).duplicate(true)
			"solar_facility_state":
				payload = (
					solar_state.get("solar") as Dictionary
				).duplicate(true)
			"macro_round_victory_gate":
				payload = (
					solar_state.get("victory_gate") as Dictionary
				).duplicate(true)
			"atomic_restore_commit":
				payload = {
					"target_envelope_fingerprint": str(
						envelope.get("envelope_fingerprint", "")
					),
					"target_snapshot_fingerprint": CODEC.fingerprint(envelope),
				}
			_:
				return {}
		var node := {
			"restore_order": index + 1,
			"node_id": node_id,
			"section_id": str(spec.get("section_id", "")),
			"depends_on": (spec.get("depends_on", []) as Array).duplicate(),
			"payload": CODEC.deep_copy(payload),
		}
		node["payload_fingerprint"] = CODEC.fingerprint(payload)
		nodes.append(node)
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"plan_schema_id": PLAN_SCHEMA_ID,
		"source_kind": SOURCE_NEW_V07_GAME,
		"save_id": str(envelope.get("save_id", "")),
		"envelope_fingerprint": str(
			envelope.get("envelope_fingerprint", "")
		),
		"preflight_complete": true,
		"preflight_section_count": SECTION_IDS.size(),
		"restore_nodes": nodes,
		"target_snapshot": envelope.duplicate(true),
	}
	return CODEC.seal(unsealed, "plan_fingerprint")


static func _plan_error(plan: Dictionary) -> String:
	if not CODEC.is_pure_data(plan) or not CODEC.has_exact_fields(
		plan, PLAN_FIELDS
	):
		return "detached_restore_plan_fields_invalid"
	if plan.get("schema_version") != SCHEMA_VERSION \
			or plan.get("plan_schema_id") != PLAN_SCHEMA_ID \
			or plan.get("source_kind") != SOURCE_NEW_V07_GAME \
			or plan.get("preflight_complete") != true \
			or plan.get("preflight_section_count") != SECTION_IDS.size():
		return "detached_restore_plan_identity_invalid"
	if not CODEC.is_fingerprint(plan.get("plan_fingerprint")) \
			or str(plan.get("plan_fingerprint", "")) \
				!= CODEC.fingerprint(plan, "plan_fingerprint"):
		return "detached_restore_plan_fingerprint_invalid"
	if not (plan.get("target_snapshot") is Dictionary) \
			or not (plan.get("restore_nodes") is Array):
		return "detached_restore_plan_payload_invalid"
	var target := plan.get("target_snapshot") as Dictionary
	var target_preflight := preflight_restore(target, SOURCE_NEW_V07_GAME)
	if not bool(target_preflight.get("accepted", false)):
		return "detached_restore_plan_target_invalid"
	if plan.get("save_id") != target.get("save_id") \
			or plan.get("envelope_fingerprint") \
				!= target.get("envelope_fingerprint"):
		return "detached_restore_plan_target_binding_invalid"
	var expected := _build_plan_unchecked(target)
	if expected.is_empty() or expected != plan:
		return "detached_restore_plan_nodes_invalid"
	return ""


static func _checkpoint_error(
	checkpoint: Dictionary,
	plan: Dictionary
) -> String:
	if not CODEC.is_pure_data(checkpoint) \
			or not CODEC.has_exact_fields(checkpoint, CHECKPOINT_FIELDS):
		return "detached_restore_checkpoint_fields_invalid"
	if checkpoint.get("schema_version") != SCHEMA_VERSION \
			or checkpoint.get("checkpoint_schema_id") != CHECKPOINT_SCHEMA_ID \
			or checkpoint.get("plan_fingerprint") \
				!= plan.get("plan_fingerprint") \
			or not (checkpoint.get("snapshot_present") is bool) \
			or not (checkpoint.get("snapshot") is Dictionary):
		return "detached_restore_checkpoint_identity_invalid"
	if not CODEC.is_fingerprint(checkpoint.get("checkpoint_fingerprint")) \
			or str(checkpoint.get("checkpoint_fingerprint", "")) \
				!= CODEC.fingerprint(checkpoint, "checkpoint_fingerprint"):
		return "detached_restore_checkpoint_fingerprint_invalid"
	var snapshot := checkpoint.get("snapshot") as Dictionary
	if bool(checkpoint.get("snapshot_present", false)) == snapshot.is_empty():
		return "detached_restore_checkpoint_presence_invalid"
	if not _snapshot_error(snapshot).is_empty() \
			or str(checkpoint.get("snapshot_fingerprint", "")) \
				!= CODEC.fingerprint(snapshot):
		return "detached_restore_checkpoint_snapshot_invalid"
	return ""


static func _snapshot_error(snapshot: Dictionary) -> String:
	if snapshot.is_empty():
		return ""
	var preflight := preflight_restore(snapshot, SOURCE_NEW_V07_GAME)
	return "" if bool(preflight.get("accepted", false)) \
		else "detached_snapshot_invalid"


static func _applied_node_prefix_error(applied_node_ids: Array) -> String:
	var expected := restore_node_ids()
	if applied_node_ids.size() > expected.size():
		return "rollback_node_count_invalid"
	for index in range(applied_node_ids.size()):
		if not (applied_node_ids[index] is String) \
				or str(applied_node_ids[index]) != expected[index]:
			return "rollback_nodes_not_apply_prefix"
	return ""


static func _metadata_error(metadata: Dictionary) -> String:
	if not CODEC.is_pure_data(metadata) \
			or not CODEC.has_exact_fields(metadata, METADATA_FIELDS):
		return "envelope_metadata_fields_invalid"
	if not _stable_id(metadata.get("save_id")):
		return "save_id_invalid"
	if not CODEC.is_fingerprint(metadata.get("scenario_fingerprint")):
		return "scenario_fingerprint_invalid"
	var repository_head := str(metadata.get("repository_head", ""))
	if repository_head.length() not in [40, 64] \
			or not _lower_hex(repository_head):
		return "repository_head_invalid"
	if not _utc_timestamp(metadata.get("created_at_utc")):
		return "created_at_utc_invalid"
	if str(metadata.get("balance_profile_id", "")) != BALANCE_PROFILE_ID:
		return "balance_profile_id_invalid"
	if str(metadata.get("balance_profile_fingerprint", "")) \
			!= BALANCE_PROFILE_FINGERPRINT:
		return "balance_profile_fingerprint_invalid"
	return ""


static func _looks_like_v07_save(candidate: Variant, source_kind: String) -> bool:
	if source_kind == SOURCE_V07_SAVE or source_kind.to_upper() == "V07_SAVE":
		return true
	if not (candidate is Dictionary):
		return false
	var value := candidate as Dictionary
	if str(value.get("ruleset_id", "")) == "v0.7" \
			or str(value.get("ruleset", "")) == "v0.7":
		return true
	for field in ["header", "metadata", "manifest"]:
		var nested_variant: Variant = value.get(field)
		if nested_variant is Dictionary \
				and str((nested_variant as Dictionary).get("ruleset_id", "")) \
					== "v0.7":
			return true
	return false


static func _looks_like_v06_save(candidate: Variant, source_kind: String) -> bool:
	if source_kind == SOURCE_V06_SAVE or source_kind.to_upper().contains("V06"):
		return true
	if not (candidate is Dictionary):
		return false
	var value := candidate as Dictionary
	if str(value.get("ruleset_id", "")) == "v0.6" \
			or str(value.get("ruleset", "")) == "v0.6":
		return true
	for field in ["header", "metadata", "manifest"]:
		var nested_variant: Variant = value.get(field)
		if nested_variant is Dictionary \
				and str((nested_variant as Dictionary).get("ruleset_id", "")) \
					== "v0.6":
			return true
	return false


static func _rng_row(
	stream_id: String,
	stream_instance_id: String,
	state_profile_id: String,
	authoritative_owner_id: String,
	save_section_id: String,
	state: Dictionary
) -> Dictionary:
	var unsealed := {
		"schema_version": SCHEMA_VERSION,
		"stream_id": stream_id,
		"stream_instance_id": stream_instance_id,
		"state_profile_id": state_profile_id,
		"authoritative_owner_id": authoritative_owner_id,
		"save_section_id": save_section_id,
		"state": state.duplicate(true),
	}
	return CODEC.seal(unsealed, "state_fingerprint")


static func _value_at_path(root: Dictionary, path: Array) -> Variant:
	var current: Variant = root
	for field_variant in path:
		if not (current is Dictionary):
			return null
		current = (current as Dictionary).get(str(field_variant))
	return current


static func _normalize_envelope_wire_numbers(envelope: Dictionary) -> Dictionary:
	var result := envelope.duplicate(true)
	var sections_variant: Variant = result.get("sections")
	if not (sections_variant is Dictionary):
		return result
	var sections := sections_variant as Dictionary
	var solar_variant: Variant = sections.get(SECTION_SOLAR)
	if not (solar_variant is Dictionary):
		return result
	var solar := solar_variant as Dictionary
	if solar.has("state"):
		solar["state"] = _restore_fraction_wire_numbers(solar.get("state"))
	return result


static func _restore_fraction_wire_numbers(value: Variant) -> Variant:
	if value is int:
		return float(value)
	if value is Array:
		var restored_array: Array = []
		for item_variant in value as Array:
			restored_array.append(_restore_fraction_wire_numbers(item_variant))
		return restored_array
	if value is Dictionary:
		var restored_dictionary := {}
		for key_variant in (value as Dictionary).keys():
			restored_dictionary[str(key_variant)] = _restore_fraction_wire_numbers(
				(value as Dictionary).get(key_variant)
			)
		return restored_dictionary
	return value


static func _register_location(
	seen: Dictionary,
	item_variant: Variant,
	location: String
) -> String:
	if not (item_variant is Dictionary):
		return "authoritative_card_location_invalid"
	var instance_id := str((item_variant as Dictionary).get("instance_id", ""))
	if instance_id.is_empty():
		return "authoritative_card_instance_id_missing"
	if seen.has(instance_id):
		return "card_instance_location_duplicate.%s" % instance_id
	seen[instance_id] = location
	return ""


static func _string_array(values: Array) -> Array[String]:
	var result: Array[String] = []
	for value_variant in values:
		if not (value_variant is String):
			return []
		result.append(str(value_variant))
	return result


static func _same_string_set(left: Array[String], right: Array[String]) -> bool:
	var left_copy := left.duplicate()
	var right_copy := right.duplicate()
	left_copy.sort()
	right_copy.sort()
	return left_copy == right_copy


static func _stable_id(value: Variant) -> bool:
	if not (value is String):
		return false
	var text := str(value)
	if text.is_empty() or text.length() > 160 or text.strip_edges() != text:
		return false
	for index in range(text.length()):
		var code := text.unicode_at(index)
		var allowed := (code >= 48 and code <= 57) \
			or (code >= 65 and code <= 90) \
			or (code >= 97 and code <= 122) \
			or code in [45, 46, 58, 95]
		if not allowed:
			return false
	return true


static func _lower_hex(value: String) -> bool:
	if value.is_empty():
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true


static func _utc_timestamp(value: Variant) -> bool:
	if not (value is String):
		return false
	var text := str(value)
	if text.length() < 20 or text.length() > 32 \
			or text.strip_edges() != text \
			or text.unicode_at(4) != 45 \
			or text.unicode_at(7) != 45 \
			or text.unicode_at(10) != 84 \
			or text.unicode_at(13) != 58 \
			or text.unicode_at(16) != 58 \
			or not text.ends_with("Z"):
		return false
	for index in [0, 1, 2, 3, 5, 6, 8, 9, 11, 12, 14, 15, 17, 18]:
		var code := text.unicode_at(index)
		if code < 48 or code > 57:
			return false
	return true


static func _source_rejection(
	reason_code: String,
	source_kind: String,
	requires_backup: bool
) -> Dictionary:
	return {
		"accepted": false,
		"reason_code": reason_code,
		"source_kind": source_kind,
		"target_ruleset_id": RULESET_ID,
		"requires_backup": requires_backup,
		"backup_required": requires_backup,
		"new_v071_game_required": true,
		"direct_resume_allowed": false,
		"envelope_valid": false,
		"preflight_complete": false,
		"preflight_count": 0,
		"section_count": 0,
		"rng_stream_count": 0,
	}


static func _preflight_failure(
	reason_code: String,
	preflight_count: int,
	rng_stream_count: int
) -> Dictionary:
	return {
		"accepted": false,
		"reason_code": reason_code,
		"source_kind": SOURCE_NEW_V07_GAME,
		"requires_backup": false,
		"backup_required": false,
		"direct_resume_allowed": false,
		"envelope_valid": false,
		"preflight_complete": false,
		"preflight_count": preflight_count,
		"section_count": SECTION_IDS.size(),
		"rng_stream_count": rng_stream_count,
	}


static func _section_failure(reason_code: String, count: int) -> Dictionary:
	return {
		"accepted": false,
		"reason_code": reason_code,
		"preflight_count": count,
	}


static func _rng_failure(reason_code: String) -> Dictionary:
	return {
		"accepted": false,
		"reason_code": reason_code,
		"rng_registry_id": RNG_REGISTRY_ID,
		"logical_stream_count": 7,
		"concrete_stream_count": 0,
		"rows": [],
	}


static func _capture_failure(reason_code: String) -> Dictionary:
	return {
		"accepted": false,
		"captured": false,
		"reason_code": reason_code,
		"source_kind": SOURCE_NEW_V07_GAME,
		"requires_backup": false,
		"section_count": 0,
		"rng_stream_count": 0,
		"envelope": {},
	}


static func _execution_failure(reason_code: String) -> Dictionary:
	return {
		"accepted": false,
		"applied": false,
		"committed": false,
		"reason_code": reason_code,
		"checkpoint_captured": false,
		"rollback_attempted": false,
		"rollback_complete": true,
		"applied_node_ids": [],
		"rollback_node_ids": [],
		"checkpoint": {},
		"snapshot": {},
	}


static func _rollback_failure(reason_code: String) -> Dictionary:
	return {
		"accepted": false,
		"rolled_back": false,
		"reason_code": reason_code,
		"rollback_complete": false,
		"rollback_node_ids": [],
		"snapshot_present": false,
		"snapshot": {},
		"snapshot_fingerprint": "",
		"plan_fingerprint": "",
	}


static func _roundtrip_failure(
	reason_code: String,
	requires_backup: bool
) -> Dictionary:
	return {
		"accepted": false,
		"exact": false,
		"reason_code": reason_code,
		"requires_backup": requires_backup,
		"source_kind": SOURCE_NEW_V07_GAME,
		"section_count": 0,
		"rng_stream_count": 0,
		"node_count": 0,
		"canonical_byte_count": 0,
		"envelope_fingerprint": "",
		"recaptured_envelope": {},
		"plan_fingerprint": "",
	}
