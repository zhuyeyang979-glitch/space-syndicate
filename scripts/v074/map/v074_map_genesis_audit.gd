extends RefCounted
class_name V074MapGenesisAudit

const REGION_COUNTS := [6, 8, 12, 16, 20, 24, 30]
const COMPLEXITIES := ["SIMPLE", "STANDARD", "COMPLEX"]
const LAND_OCEAN_PROFILES := ["CONTINENTAL", "BALANCED", "ARCHIPELAGO"]
const REQUIRED_COMBINATIONS := [
	[6, "SIMPLE", "CONTINENTAL"],
	[12, "COMPLEX", "ARCHIPELAGO"],
	[16, "STANDARD", "BALANCED"],
	[20, "SIMPLE", "BALANCED"],
	[24, "COMPLEX", "CONTINENTAL"],
	[30, "STANDARD", "ARCHIPELAGO"],
]
const BOUNDARY_MINIMUM := {
	"SIMPLE": 10,
	"STANDARD": 18,
	"COMPLEX": 28,
}
const CONCAVITY_MINIMUM := {
	"SIMPLE": 0.0,
	"STANDARD": 0.35,
	"COMPLEX": 0.60,
}


static func run_focused() -> Dictionary:
	var checks := 0
	var failures: Array[String] = []
	var rows: Array[Dictionary] = []
	for index in range(REQUIRED_COMBINATIONS.size()):
		var combination: Array = REQUIRED_COMBINATIONS[index] as Array
		var request := MapGenesisRequestV1.build(
			900626424 + index * 7919,
			int(combination[0]),
			str(combination[1]),
			str(combination[2])
		)
		var receipt := V074MapGenesisCore.generate(request)
		var report := V074MapGenesisCore.validation_report(receipt)
		checks += 8
		_expect(failures, bool(receipt.get("accepted", false)), "focused_%d_receipt" % index)
		_expect(failures, bool(report.get("valid", false)), "focused_%d_validation" % index)
		_expect(failures, int(receipt.get("region_count", 0)) == int(combination[0]), "focused_%d_region_count" % index)
		_expect(
			failures,
			(receipt.get("facility_slot_registry", {}) as Dictionary).size() == int(combination[0]) * 18,
			"focused_%d_slot_parity" % index
		)
		_expect(failures, int(report.get("global_region_adjacency_component_count", 0)) == 1, "focused_%d_global_connected" % index)
		_expect(failures, int(report.get("disconnected_region_count", -1)) == 0, "focused_%d_regions_connected" % index)
		_expect(failures, int(report.get("land_region_count", 0)) > 0, "focused_%d_has_land" % index)
		_expect(failures, int(report.get("ocean_region_count", 0)) > 0, "focused_%d_has_ocean" % index)
		rows.append({
			"region_count": int(combination[0]),
			"complexity": str(combination[1]),
			"land_ocean_profile": str(combination[2]),
			"map_fingerprint": str(receipt.get("map_fingerprint", "")),
			"median_boundary_vertex_count": int(report.get("median_boundary_vertex_count", 0)),
			"concave_region_ratio": float(report.get("concave_region_ratio", 0.0)),
			"land_region_count": int(report.get("land_region_count", 0)),
			"ocean_region_count": int(report.get("ocean_region_count", 0)),
			"facility_slot_count": (receipt.get("facility_slot_registry", {}) as Dictionary).size(),
		})
	var replay_request := MapGenesisRequestV1.build(
		900626424,
		16,
		"STANDARD",
		"BALANCED"
	)
	var replay_a := V074MapGenesisCore.generate(replay_request)
	var replay_b := V074MapGenesisCore.generate(replay_request)
	var changed_seed := V074MapGenesisCore.generate(MapGenesisRequestV1.build(
		900626425,
		16,
		"STANDARD",
		"BALANCED"
	))
	checks += 6
	_expect(failures, str(replay_a.get("map_fingerprint", "")) == str(replay_b.get("map_fingerprint", "")), "same_seed_replay_parity")
	_expect(failures, str(replay_a.get("map_fingerprint", "")) != str(changed_seed.get("map_fingerprint", "")), "different_seed_geometry_delta")
	_expect(failures, int(replay_a.get("map_genesis_owner_count", 0)) == 1, "single_map_genesis_owner")
	_expect(failures, int(replay_a.get("map_genesis_rng_owner_count", 0)) == 1, "single_map_genesis_rng_owner")
	_expect(failures, int(replay_a.get("map_genesis_gameplay_rng_cross_draw_count", -1)) == 0, "gameplay_rng_cross_draw_zero")
	var alternate_sun := Vector3(0.31, -0.42, 0.85).normalized()
	_expect(
		failures,
		V074MapGenesisCore.geometric_solar_by_region(replay_a, alternate_sun).size() == 16,
		"geometric_solar_covers_regions"
	)
	return {
		"success": failures.is_empty(),
		"passed": checks - failures.size(),
		"total": checks,
		"failures": failures,
		"rows": rows,
		"same_seed_geometry_parity": str(replay_a.get("map_fingerprint", "")) == str(replay_b.get("map_fingerprint", "")),
		"different_seed_geometry_delta": str(replay_a.get("map_fingerprint", "")) != str(changed_seed.get("map_fingerprint", "")),
		"reference_fingerprint": str(replay_a.get("map_fingerprint", "")),
	}


static func run_sample_suite(sample_count: int = 2000) -> Dictionary:
	sample_count = maxi(1, sample_count)
	var configurations: Array = []
	for region_count in REGION_COUNTS:
		for complexity in COMPLEXITIES:
			for profile in LAND_OCEAN_PROFILES:
				configurations.append([region_count, complexity, profile])
	var generation_failure_count := 0
	var global_disconnected_map_count := 0
	var disconnected_region_count := 0
	var self_intersection_map_count := 0
	var gap_or_overlap_map_count := 0
	var sliver_map_count := 0
	var landless_map_count := 0
	var oceanless_map_count := 0
	var starter_no_legal_target_map_count := 0
	var warehouse_slot_parity_failure_count := 0
	var triangle_region_count := 0
	var quadrilateral_region_count := 0
	var land_counts: Array[int] = []
	var ocean_counts: Array[int] = []
	var region_area_values: Array[float] = []
	var neighbor_count_values: Array[int] = []
	var boundary_values := {"SIMPLE": [], "STANDARD": [], "COMPLEX": []}
	var concavity_values := {"SIMPLE": [], "STANDARD": [], "COMPLEX": []}
	var land_ratio_values: Array[float] = []
	var slot_count_values: Array[int] = []
	var generation_30_region_ms: Array[float] = []
	var started_usec := Time.get_ticks_usec()
	for sample_index in range(sample_count):
		var configuration: Array = configurations[sample_index % configurations.size()] as Array
		var region_count := int(configuration[0])
		var complexity := str(configuration[1])
		var profile := str(configuration[2])
		var seed := 900626424 + sample_index * 7919
		var map_started_usec := Time.get_ticks_usec()
		var receipt := V074MapGenesisCore.generate(MapGenesisRequestV1.build(
			seed,
			region_count,
			complexity,
			profile
		))
		var elapsed_ms := float(Time.get_ticks_usec() - map_started_usec) / 1000.0
		if region_count == 30:
			generation_30_region_ms.append(elapsed_ms)
		if not bool(receipt.get("accepted", false)):
			generation_failure_count += 1
			continue
		var report: Dictionary = receipt.get("validation_summary", {}) as Dictionary
		if not bool(report.get("valid", false)):
			generation_failure_count += 1
		if int(report.get("global_region_adjacency_component_count", 0)) != 1:
			global_disconnected_map_count += 1
		disconnected_region_count += int(report.get("disconnected_region_count", 0))
		if int(report.get("region_boundary_self_intersection_count", 0)) > 0:
			self_intersection_map_count += 1
		if int(report.get("region_boundary_gap_count", 0)) > 0 				or int(report.get("region_boundary_overlap_count", 0)) > 0:
			gap_or_overlap_map_count += 1
		if int(report.get("region_sliver_count", 0)) > 0:
			sliver_map_count += 1
		if int(report.get("land_region_count", 0)) == 0:
			landless_map_count += 1
		if int(report.get("ocean_region_count", 0)) == 0:
			oceanless_map_count += 1
		triangle_region_count += int(report.get("triangle_region_count", 0))
		quadrilateral_region_count += int(report.get("quadrilateral_region_count", 0))
		var slot_count := (receipt.get("facility_slot_registry", {}) as Dictionary).size()
		if slot_count != region_count * 18:
			warehouse_slot_parity_failure_count += 1
		if not _has_starter_legal_target(receipt):
			starter_no_legal_target_map_count += 1
		land_counts.append(int(report.get("land_region_count", 0)))
		ocean_counts.append(int(report.get("ocean_region_count", 0)))
		boundary_values[complexity].append(int(report.get("median_boundary_vertex_count", 0)))
		concavity_values[complexity].append(float(report.get("concave_region_ratio", 0.0)))
		land_ratio_values.append(float(report.get("land_region_count", 0)) / float(region_count))
		slot_count_values.append(slot_count)
		for area_variant in (receipt.get("region_area_ratio", {}) as Dictionary).values():
			region_area_values.append(float(area_variant))
		for neighbors_variant in (receipt.get("adjacency_graph", {}) as Dictionary).values():
			neighbor_count_values.append((neighbors_variant as Array).size())
	var simple_median := _percentile(boundary_values["SIMPLE"] as Array, 0.50)
	var standard_median := _percentile(boundary_values["STANDARD"] as Array, 0.50)
	var complex_median := _percentile(boundary_values["COMPLEX"] as Array, 0.50)
	var standard_concavity := _percentile(concavity_values["STANDARD"] as Array, 0.50)
	var complex_concavity := _percentile(concavity_values["COMPLEX"] as Array, 0.50)
	var quality_green := generation_failure_count == 0 		and global_disconnected_map_count == 0 		and disconnected_region_count == 0 		and self_intersection_map_count == 0 		and gap_or_overlap_map_count == 0 		and sliver_map_count == 0 		and landless_map_count == 0 		and oceanless_map_count == 0 		and starter_no_legal_target_map_count == 0 		and warehouse_slot_parity_failure_count == 0 		and triangle_region_count == 0 		and quadrilateral_region_count == 0 		and simple_median >= float(BOUNDARY_MINIMUM["SIMPLE"]) 		and standard_median >= float(BOUNDARY_MINIMUM["STANDARD"]) 		and complex_median >= float(BOUNDARY_MINIMUM["COMPLEX"]) 		and standard_concavity >= float(CONCAVITY_MINIMUM["STANDARD"]) 		and complex_concavity >= float(CONCAVITY_MINIMUM["COMPLEX"])
	return {
		"success": quality_green,
		"map_generation_sample_count": sample_count,
		"map_generation_failure_count": generation_failure_count,
		"generation_failure_rate": float(generation_failure_count) / float(sample_count),
		"global_disconnected_map_count": global_disconnected_map_count,
		"disconnected_region_count": disconnected_region_count,
		"self_intersection_map_count": self_intersection_map_count,
		"gap_or_overlap_map_count": gap_or_overlap_map_count,
		"sliver_map_count": sliver_map_count,
		"landless_map_count": landless_map_count,
		"oceanless_map_count": oceanless_map_count,
		"starter_no_legal_target_map_count": starter_no_legal_target_map_count,
		"warehouse_slot_parity_failure_count": warehouse_slot_parity_failure_count,
		"triangle_region_count": triangle_region_count,
		"quadrilateral_region_count": quadrilateral_region_count,
		"land_region_count_range": _range(land_counts),
		"ocean_region_count_range": _range(ocean_counts),
		"simple_median_boundary_vertex_count": simple_median,
		"standard_median_boundary_vertex_count": standard_median,
		"complex_median_boundary_vertex_count": complex_median,
		"standard_concave_region_ratio": standard_concavity,
		"complex_concave_region_ratio": complex_concavity,
		"region_area_distribution": _distribution(region_area_values),
		"neighbor_count_distribution": _distribution(neighbor_count_values),
		"boundary_vertex_distribution": {
			"SIMPLE": _distribution(boundary_values["SIMPLE"] as Array),
			"STANDARD": _distribution(boundary_values["STANDARD"] as Array),
			"COMPLEX": _distribution(boundary_values["COMPLEX"] as Array),
		},
		"concavity_distribution": {
			"STANDARD": _distribution(concavity_values["STANDARD"] as Array),
			"COMPLEX": _distribution(concavity_values["COMPLEX"] as Array),
		},
		"land_ocean_ratio_distribution": _distribution(land_ratio_values),
		"facility_slot_count_distribution": _distribution(slot_count_values),
		"map_genesis_30_region_p95_ms": _percentile(generation_30_region_ms, 0.95),
		"elapsed_ms": float(Time.get_ticks_usec() - started_usec) / 1000.0,
	}


static func _has_starter_legal_target(receipt: Dictionary) -> bool:
	var slots: Dictionary = receipt.get("facility_slot_registry", {}) as Dictionary
	for slot_variant in slots.values():
		var slot := slot_variant as Dictionary
		if str(slot.get("facility_type", "")) in ["factory", "market"] 				and str(slot.get("occupancy", "")) == "empty":
			return true
	return false


static func _expect(failures: Array[String], condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


static func _range(values: Array) -> Dictionary:
	if values.is_empty():
		return {"min": 0, "max": 0}
	var sorted_values: Array = values.duplicate()
	sorted_values.sort()
	return {"min": sorted_values.front(), "max": sorted_values.back()}


static func _distribution(values: Array) -> Dictionary:
	if values.is_empty():
		return {"count": 0, "min": 0.0, "p50": 0.0, "p95": 0.0, "max": 0.0}
	var sorted_values: Array = values.duplicate()
	sorted_values.sort()
	return {
		"count": sorted_values.size(),
		"min": float(sorted_values.front()),
		"p50": _percentile(sorted_values, 0.50),
		"p95": _percentile(sorted_values, 0.95),
		"max": float(sorted_values.back()),
	}


static func _percentile(values: Array, percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted_values: Array = values.duplicate()
	sorted_values.sort()
	var index := clampi(
		ceili(percentile * float(sorted_values.size())) - 1,
		0,
		sorted_values.size() - 1
	)
	return float(sorted_values[index])
