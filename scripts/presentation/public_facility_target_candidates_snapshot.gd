extends RefCounted
class_name PublicFacilityTargetCandidatesSnapshot

const CANDIDATE_KEYS := ["region_id", "public_index", "region_revision"]

var schema_version := 1
var available := false
var reason_code := "public_new_facility_target_query_unavailable"
var query_kind: StringName = &"new_facility_installation"
var facility_kind: StringName = &""
var industry_id: StringName = &""
var source_revision := 0
var candidates: Array = []


static func from_dictionary(source: Dictionary) -> PublicFacilityTargetCandidatesSnapshot:
	var snapshot := PublicFacilityTargetCandidatesSnapshot.new()
	snapshot.schema_version = int(source.get("schema_version", 1))
	snapshot.available = bool(source.get("available", false))
	snapshot.reason_code = str(source.get("reason_code", "public_new_facility_target_query_unavailable"))
	snapshot.query_kind = StringName(str(source.get("query_kind", "new_facility_installation")))
	snapshot.facility_kind = StringName(str(source.get("facility_kind", "")))
	snapshot.industry_id = StringName(str(source.get("industry_id", "")))
	snapshot.source_revision = maxi(0, int(source.get("source_revision", 0)))
	snapshot.candidates = (source.get("candidates", []) as Array).duplicate(true) \
		if source.get("candidates", []) is Array else []
	return snapshot


func is_valid() -> bool:
	if schema_version != 1 or query_kind != &"new_facility_installation" \
			or reason_code.strip_edges().is_empty() or source_revision < 0:
		return false
	if available and str(facility_kind).strip_edges().is_empty():
		return false
	var seen_region_ids := {}
	var seen_public_indices := {}
	var previous_public_index := -1
	for candidate_variant in candidates:
		if not (candidate_variant is Dictionary):
			return false
		var candidate := candidate_variant as Dictionary
		if not _has_exact_keys(candidate, CANDIDATE_KEYS):
			return false
		var region_id := str(candidate.get("region_id", "")).strip_edges()
		var public_index_variant: Variant = candidate.get("public_index")
		var region_revision_variant: Variant = candidate.get("region_revision")
		if region_id.is_empty() or typeof(public_index_variant) != TYPE_INT \
				or typeof(region_revision_variant) != TYPE_INT:
			return false
		var public_index := int(public_index_variant)
		if public_index < 0 or int(region_revision_variant) < 0 \
				or public_index < previous_public_index \
				or seen_region_ids.has(region_id) or seen_public_indices.has(public_index):
			return false
		seen_region_ids[region_id] = true
		seen_public_indices[public_index] = true
		previous_public_index = public_index
	return TablePresentationPureDataPolicy.is_pure_data(candidates)


func to_dictionary() -> Dictionary:
	if not is_valid():
		return {}
	return {
		"schema_version": schema_version,
		"available": available,
		"reason_code": reason_code,
		"query_kind": str(query_kind),
		"facility_kind": str(facility_kind),
		"industry_id": str(industry_id),
		"source_revision": source_revision,
		"candidates": TablePresentationPureDataPolicy.detached_copy(candidates),
	}


static func _has_exact_keys(value: Dictionary, expected: Array) -> bool:
	if value.size() != expected.size():
		return false
	for key_variant in expected:
		if not value.has(key_variant):
			return false
	return true
