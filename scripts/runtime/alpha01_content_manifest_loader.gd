extends RefCounted
class_name Alpha01ContentManifestLoader

const RESOURCE_MANIFEST_PATH := "res://resources/content/alpha01/alpha01_content_manifest.tres"
const Selection := preload("res://scripts/runtime/alpha01_runtime_content_selection.gd")


static func load_active_selection() -> Alpha01RuntimeContentSelection:
	var manifest := load(RESOURCE_MANIFEST_PATH) as Resource
	if manifest == null or not manifest.has_method("runtime_selection_snapshot") or not manifest.has_method("deterministic_sha256"):
		var missing := Selection.new()
		missing.errors.append("alpha01_resource_manifest_missing")
		return missing
	var snapshot: Variant = manifest.call("runtime_selection_snapshot")
	if not (snapshot is Dictionary):
		var malformed := Selection.new()
		malformed.errors.append("alpha01_resource_runtime_selection_malformed")
		return malformed
	var selection := Selection.from_dictionary(snapshot as Dictionary)
	if str(manifest.call("deterministic_sha256")) != selection.selection_sha256:
		selection.errors.append("alpha01_resource_selection_sha_mismatch")
	return selection
