@tool
extends Node
class_name RoleCodexPublicSourceService

const ADAPTER_SCRIPT := preload("res://scripts/runtime/role_codex_public_source_adapter.gd")
const DEPENDENCY_KEYS := ["catalog", "snapshot"]

var _catalog: RoleCatalogRuntimeService
var _snapshot: CodexPublicSnapshotService
var _adapter: RefCounted = ADAPTER_SCRIPT.new()
var _configured := false
var _last_error := "dependencies_not_configured"
var _compose_count := 0


func configure(dependencies: Dictionary) -> Dictionary:
	_clear_dependencies()
	var keys := dependencies.keys()
	keys.sort()
	var expected := DEPENDENCY_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		_last_error = "dependency_keys_invalid"
		return debug_snapshot()
	_catalog = dependencies.get("catalog") as RoleCatalogRuntimeService
	_snapshot = dependencies.get("snapshot") as CodexPublicSnapshotService
	if _catalog == null or not bool(_catalog.validate_catalog().get("valid", false)):
		_last_error = "role_catalog_invalid"
		_clear_dependencies()
		return debug_snapshot()
	if _snapshot == null or not _snapshot.has_method("compose_role"):
		_last_error = "snapshot_service_invalid"
		_clear_dependencies()
		return debug_snapshot()
	_configured = true
	_last_error = ""
	return debug_snapshot()


func compose_snapshot(role_index: int, presentation: Dictionary = {}) -> Dictionary:
	if not _configured or role_index < 0 or role_index >= _catalog.role_count():
		_last_error = "role_index_invalid"
		return {}
	if not bool(_adapter.call("accepts_public_input", presentation)):
		_last_error = "presentation_rejected"
		return {}
	var definition := _catalog.public_definition_at(role_index)
	var value: Variant = _adapter.call("compose_source", definition, presentation, role_index, _catalog.role_count())
	var source := (value as Dictionary).duplicate(true) if value is Dictionary else {}
	if source.is_empty():
		_last_error = "public_source_rejected"
		return {}
	_compose_count += 1
	_last_error = ""
	return _snapshot.compose_role(source)


func public_field_schema() -> Dictionary:
	var value: Variant = _adapter.call("public_field_schema")
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func debug_snapshot() -> Dictionary:
	return {
		"service_ready": _configured,
		"service_authoritative": _configured,
		"last_error": _last_error,
		"compose_count": _compose_count,
		"dependency_allowlist": DEPENDENCY_KEYS.duplicate(),
		"uses_role_catalog_public_projection": _catalog != null,
		"reads_player_state": false,
		"reads_private_world": false,
		"owns_rules": false,
		"owns_save_state": false,
		"adapter": _adapter.call("debug_snapshot"),
	}


func _clear_dependencies() -> void:
	_catalog = null
	_snapshot = null
	_configured = false
