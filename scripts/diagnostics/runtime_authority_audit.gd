@tool
extends Node
class_name RuntimeAuthorityAudit

const VALID_ROLES: Array[StringName] = [
	&"state_owner",
	&"tick_owner",
	&"signal_publisher",
	&"snapshot_builder",
	&"save_writer",
	&"mutation_path",
]

var _registrations: Array[Dictionary] = []


func clear() -> void:
	_registrations.clear()


func register_authority(
	domain: StringName,
	role: StringName,
	owner_path: NodePath,
	revision: int = 0
) -> bool:
	if domain == &"" or not VALID_ROLES.has(role) or owner_path.is_empty():
		return false
	_registrations.append({
		"domain": domain,
		"role": role,
		"owner_path": owner_path,
		"revision": maxi(0, revision),
	})
	return true


func audit_snapshot() -> Dictionary:
	var grouped: Dictionary = {}
	var invalid_rows: Array = []
	for row_variant in _registrations:
		var row: Dictionary = row_variant
		var domain := StringName(str(row.get("domain", "")))
		var role := StringName(str(row.get("role", "")))
		var owner_path := NodePath(str(row.get("owner_path", "")))
		if domain == &"" or not VALID_ROLES.has(role) or owner_path.is_empty():
			invalid_rows.append(row.duplicate(true))
			continue
		var key := "%s::%s" % [domain, role]
		if not grouped.has(key):
			grouped[key] = []
		(grouped[key] as Array).append({
			"owner_path": owner_path,
			"revision": int(row.get("revision", 0)),
		})

	var duplicates: Array = []
	for key_variant in grouped.keys():
		var key := str(key_variant)
		var owners: Array = grouped[key]
		var unique_paths: Array[String] = []
		for owner_variant in owners:
			var owner: Dictionary = owner_variant
			var path_text := str(owner.get("owner_path", ""))
			if not unique_paths.has(path_text):
				unique_paths.append(path_text)
		if unique_paths.size() > 1:
			duplicates.append({
				"authority_key": key,
				"owner_paths": unique_paths,
			})

	var role_duplicate_counts := {}
	for role in VALID_ROLES:
		role_duplicate_counts[str(role)] = 0
	for duplicate_variant in duplicates:
		var duplicate: Dictionary = duplicate_variant
		var pieces := str(duplicate.get("authority_key", "")).split("::")
		var role_text := pieces[1] if pieces.size() > 1 else ""
		role_duplicate_counts[role_text] = int(role_duplicate_counts.get(role_text, 0)) + 1

	return {
		"schema_version": 1,
		"registration_count": _registrations.size(),
		"duplicate_count": duplicates.size(),
		"invalid_count": invalid_rows.size(),
		"duplicates": duplicates,
		"invalid_rows": invalid_rows,
		"duplicate_tick_count": int(role_duplicate_counts.get("tick_owner", 0)),
		"duplicate_signal_count": int(role_duplicate_counts.get("signal_publisher", 0)),
		"duplicate_snapshot_count": int(role_duplicate_counts.get("snapshot_builder", 0)),
		"duplicate_save_writer_count": int(role_duplicate_counts.get("save_writer", 0)),
		"duplicate_mutation_path_count": int(role_duplicate_counts.get("mutation_path", 0)),
		"ok": duplicates.is_empty() and invalid_rows.is_empty(),
	}
