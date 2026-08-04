extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var receipt := V074MapGenesisCore.generate(MapGenesisRequestV1.build(
		900626424,
		30,
		"COMPLEX",
		"ARCHIPELAGO"
	))
	var report := V074MapGenesisCore.validation_report(receipt)
	var failures: Array[String] = []
	_expect(failures, bool(receipt.get("accepted", false)), "receipt")
	_expect(failures, bool(report.get("valid", false)), "validation")
	_expect(failures, int(report.get("global_region_adjacency_component_count", 0)) == 1, "global_connected")
	_expect(failures, int(report.get("disconnected_region_count", -1)) == 0, "regions_connected")
	_expect(failures, int(report.get("triangle_region_count", -1)) == 0, "no_triangles")
	_expect(failures, int(report.get("quadrilateral_region_count", -1)) == 0, "no_quadrilaterals")
	_expect(failures, int(report.get("region_boundary_gap_count", -1)) == 0, "no_gaps")
	_expect(failures, int(report.get("region_boundary_overlap_count", -1)) == 0, "no_overlaps")
	_expect(failures, int(report.get("median_boundary_vertex_count", 0)) >= 28, "complex_boundary_detail")
	_expect(failures, float(report.get("concave_region_ratio", 0.0)) >= 0.60, "complex_concavity")
	_expect(failures, (receipt.get("facility_slot_registry", {}) as Dictionary).size() == 540, "thirty_region_slot_parity")
	var passed := failures.is_empty()
	print("V074_REGION_TOPOLOGY_TEST|status=%s|passed=%d|total=11|median=%d|concavity=%.3f|failures=%s" % [
		"PASS" if passed else "FAIL",
		11 - failures.size(),
		int(report.get("median_boundary_vertex_count", 0)),
		float(report.get("concave_region_ratio", 0.0)),
		JSON.stringify(failures),
	])
	quit(0 if passed else 1)


func _expect(failures: Array[String], condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
