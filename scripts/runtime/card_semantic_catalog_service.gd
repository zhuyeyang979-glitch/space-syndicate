@tool
extends Node
class_name CardSemanticCatalogService

const COMPILER := preload("res://scripts/cards/semantic/card_semantic_compiler_v1.gd")
const SCHEMA := preload("res://scripts/cards/semantic/card_semantic_schema_v1.gd")

@export var configure_on_ready := true
@export var _catalog: CardRuntimeCatalogV06Resource

var _compiler = COMPILER.new()
var _configured := false
var _configuration_attempt_count := 0
var _source_catalog_id := ""
var _summary: Dictionary = {
	"schema_version": 1,
	"configured": false,
	"source_catalog_id": "",
	"source_record_count": 0,
	"compiled_count": 0,
	"active_count": 0,
	"projection_only_count": 0,
	"not_acquirable_count": 0,
	"op_counts": {},
	"source_catalog_fingerprint": "",
	"semantic_catalog_fingerprint": "",
	"error_count": 0,
	"errors": [],
}


func _ready() -> void:
	if configure_on_ready and not Engine.is_editor_hint():
		configure()


func configure() -> Dictionary:
	if _configured:
		return validation_snapshot()
	_configuration_attempt_count += 1
	if _catalog == null:
		_set_failure(["catalog_resource_missing"])
		return validation_snapshot()
	var catalog_report := _catalog.reload()
	if not bool(catalog_report.get("valid", false)):
		_set_failure([{"error_id": "catalog_validation_failed", "details": (catalog_report.get("errors", []) as Array).duplicate()}])
		return validation_snapshot()
	var catalog_snapshot := _catalog.catalog_snapshot()
	_source_catalog_id = str(catalog_snapshot.get("catalog_id", ""))
	var compile_report := _compiler.compile_catalog_snapshot(catalog_snapshot)
	_summary = {
		"schema_version": SCHEMA.SCHEMA_VERSION,
		"configured": bool(compile_report.get("ok", false)),
		"source_catalog_id": _source_catalog_id,
		"source_record_count": int(compile_report.get("source_record_count", 0)),
		"compiled_count": int(compile_report.get("compiled_count", 0)),
		"active_count": int(compile_report.get("active_count", 0)),
		"projection_only_count": int(compile_report.get("projection_only_count", 0)),
		"not_acquirable_count": int(compile_report.get("not_acquirable_count", 0)),
		"op_counts": (compile_report.get("op_counts", {}) as Dictionary).duplicate(true),
		"source_catalog_fingerprint": str(compile_report.get("source_catalog_fingerprint", "")),
		"semantic_catalog_fingerprint": str(compile_report.get("semantic_catalog_fingerprint", "")),
		"error_count": (compile_report.get("errors", []) as Array).size(),
		"errors": (compile_report.get("errors", []) as Array).duplicate(true),
	}
	_configured = bool(_summary["configured"])
	return validation_snapshot()


func compile_authorized(envelope: Dictionary) -> Dictionary:
	if not _configured:
		configure()
	if not _configured:
		return {"ok": false, "spec": {}, "errors": ["semantic_catalog_not_configured"], "source_definition_fingerprint": "", "cache_hit": false}
	return _compiler.compile_authorized(envelope.duplicate(true), _source_catalog_id)


func validation_snapshot() -> Dictionary:
	var snapshot := _summary.duplicate(true)
	var metrics := _compiler.cache_metrics()
	snapshot["configuration_attempt_count"] = _configuration_attempt_count
	snapshot["cache_entry_count"] = int(metrics.get("cache_entry_count", 0))
	snapshot["compile_count"] = int(metrics.get("compile_count", 0))
	snapshot["cache_hit_count"] = int(metrics.get("cache_hit_count", 0))
	snapshot["compile_failure_count"] = int(metrics.get("failure_count", 0))
	return snapshot


func debug_snapshot() -> Dictionary:
	return validation_snapshot()


func _set_failure(errors: Array) -> void:
	_configured = false
	_source_catalog_id = ""
	_summary = {
		"schema_version": SCHEMA.SCHEMA_VERSION,
		"configured": false,
		"source_catalog_id": "",
		"source_record_count": 0,
		"compiled_count": 0,
		"active_count": 0,
		"projection_only_count": 0,
		"not_acquirable_count": 0,
		"op_counts": {},
		"source_catalog_fingerprint": "",
		"semantic_catalog_fingerprint": "",
		"error_count": errors.size(),
		"errors": errors.duplicate(true),
	}