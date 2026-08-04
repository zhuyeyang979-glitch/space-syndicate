extends SceneTree

const Support := preload("res://tests/v074_planet_test_support.gd")
const Adapter := preload("res://scripts/presentation/v074/v074_planet_presentation_adapter_v1.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array = []
	var checks := 0
	var receipt := Support.build_receipt(16, "STANDARD")
	var projection := Support.public_projection(receipt)
	var adapter := Adapter.new()
	var payload := adapter.build_map_view_payload(receipt, projection, "card.fixture", "region.002")
	checks += 1
	Support.add_failure(failures, not payload.is_empty(), "direct receipt object was rejected")
	var snapshot := payload.get("snapshot") as Object
	var surface := payload.get("authoritative_surface", {}) as Dictionary
	checks += 1
	Support.add_failure(failures, snapshot != null and (snapshot.get("districts") as Array).size() == 16, "dynamic district count mismatch")
	checks += 1
	Support.add_failure(failures, str(surface.get("geometry_source", "")) == "MapGenesisReceiptV1", "presentation generated geometry")
	checks += 1
	Support.add_failure(failures, int(surface.get("presentation_generated_terrain_count", -1)) == 0, "presentation generated terrain")
	checks += 1
	Support.add_failure(failures, (surface.get("hit_test_cells", []) as Array).size() == 112, "microcell hit index mismatch")
	var markers := snapshot.get("city_markers") as Array
	var marker_types: Array[String] = []
	var private_field_count := 0
	for marker_variant in markers:
		var marker := marker_variant as Dictionary
		marker_types.append(str(marker.get("facility_type", "")))
		private_field_count += int(marker.has("private_stock")) + int(marker.has("private_logistics_plan"))
	checks += 1
	Support.add_failure(failures, markers.size() == 3 and marker_types.has("factory") and marker_types.has("market") and marker_types.has("warehouse"), "three facility markers missing")
	checks += 1
	Support.add_failure(failures, private_field_count == 0, "warehouse private fields leaked")
	var warehouse_index := marker_types.find("warehouse")
	var warehouse := markers[warehouse_index] as Dictionary if warehouse_index >= 0 else {}
	checks += 1
	Support.add_failure(failures, warehouse_index >= 0 and int(warehouse.get("public_capacity", -1)) == 8 and float(warehouse.get("public_ingress_throughput", -1.0)) == 4.0, "warehouse public facts missing")
	var debug := adapter.debug_snapshot()
	checks += 1
	Support.add_failure(failures, int(debug.get("gameplay_owner_count", -1)) == 0 and int(debug.get("rng_owner_count", -1)) == 0, "adapter claimed gameplay or RNG ownership")
	var receipt_30 := Support.build_receipt(30, "COMPLEX")
	var payload_30 := adapter.build_map_view_payload(receipt_30, Support.public_projection(receipt_30))
	checks += 1
	Support.add_failure(failures, ((payload_30.get("snapshot") as Object).get("districts") as Array).size() == 30, "30-region receipt unsupported")

	var lane_a_fixture := Support.build_receipt(8, "STANDARD")
	var lane_a_projection := Support.public_projection(lane_a_fixture)
	var single_loop_receipt := Support.build_lane_a_boundary_receipt(lane_a_fixture)
	var single_loop_payload := adapter.build_map_view_payload(
		single_loop_receipt,
		lane_a_projection
	)
	var single_surface := single_loop_payload.get("authoritative_surface", {}) as Dictionary
	var single_primary := (
		(single_surface.get("region_boundary_lods_spherical", {}) as Dictionary)
		.get("region.000", {}) as Dictionary
	).get("near", []) as Array
	var single_loop_lods := (
		(single_surface.get("region_boundary_loop_lods_spherical", {}) as Dictionary)
		.get("region.000", {}) as Dictionary
	).get("near", []) as Array
	checks += 1
	Support.add_failure(failures, not single_loop_payload.is_empty(), "Lane A single-loop receipt was rejected")
	checks += 1
	Support.add_failure(failures, single_primary.size() == 20 and single_loop_lods.size() == 1, "Lane A single-loop LOD normalization failed")
	checks += 1
	Support.add_failure(failures, str((single_surface.get("boundary_source_by_region", {}) as Dictionary).get("region.000", "")) == "region_boundary_lods_spherical", "preferred Lane A LOD source was not used")
	checks += 1
	Support.add_failure(failures, (single_surface.get("hit_test_cells", []) as Array).size() == 56 and str(single_surface.get("microcell_center_source", "")) == "microcell_centers_unit_sphere", "top-level authoritative microcell centers were not used")

	var multi_loop_receipt := Support.build_lane_a_boundary_receipt(
		lane_a_fixture,
		true
	)
	var multi_loop_payload := adapter.build_map_view_payload(
		multi_loop_receipt,
		lane_a_projection
	)
	var multi_surface := multi_loop_payload.get("authoritative_surface", {}) as Dictionary
	var multi_primary := (
		(multi_surface.get("region_boundary_lods_spherical", {}) as Dictionary)
		.get("region.000", {}) as Dictionary
	).get("near", []) as Array
	var multi_loops := (
		(multi_surface.get("region_boundary_loop_lods_spherical", {}) as Dictionary)
		.get("region.000", {}) as Dictionary
	).get("near", []) as Array
	var multi_snapshot := multi_loop_payload.get("snapshot") as Object
	var multi_districts: Array = multi_snapshot.get("districts") as Array if multi_snapshot != null else []
	var multi_polygon: Array = (multi_districts[0] as Dictionary).get("polygon", []) as Array if not multi_districts.is_empty() else []
	checks += 1
	Support.add_failure(failures, not multi_loop_payload.is_empty(), "Lane A multi-loop receipt was rejected")
	checks += 1
	Support.add_failure(failures, multi_loops.size() == 2 and multi_primary.size() == 20, "all authoritative loops were not preserved")
	checks += 1
	Support.add_failure(failures, multi_polygon.size() == multi_primary.size(), "district polygon did not select the largest authoritative loop")
	checks += 1
	Support.add_failure(failures, int(multi_surface.get("presentation_generated_geometry_count", -1)) == 0, "multi-loop normalization generated geometry")

	var fallback_receipt := Support.build_lane_a_boundary_receipt(
		lane_a_fixture,
		false,
		true
	)
	var fallback_payload := adapter.build_map_view_payload(
		fallback_receipt,
		lane_a_projection
	)
	var fallback_surface := fallback_payload.get("authoritative_surface", {}) as Dictionary
	var fallback_near := (
		(fallback_surface.get("region_boundary_lods_spherical", {}) as Dictionary)
		.get("region.000", {}) as Dictionary
	).get("near", []) as Array
	var all_points_from_shared_edges := true
	for point_variant in fallback_near:
		var point := point_variant as Vector3
		var found := false
		for edge_variant in fallback_receipt.get("shared_boundary_edges", []) as Array:
			var edge := edge_variant as Dictionary
			if str(edge.get("region_a", "")) != "region.000":
				continue
			for source_point_variant in edge.get("points_unit_sphere", []) as Array:
				if point.is_equal_approx(source_point_variant as Vector3):
					found = true
					break
			if found:
				break
		if not found:
			all_points_from_shared_edges = false
			break
	checks += 1
	Support.add_failure(failures, not fallback_payload.is_empty(), "shared-edge-only receipt was rejected")
	checks += 1
	Support.add_failure(failures, str((fallback_surface.get("boundary_source_by_region", {}) as Dictionary).get("region.000", "")) == "shared_boundary_edges.points_unit_sphere", "shared-edge fallback source mismatch")
	checks += 1
	Support.add_failure(failures, fallback_near.size() == 20 and all_points_from_shared_edges, "shared-edge fallback changed authoritative vertices")
	checks += 1
	Support.add_failure(failures, int(fallback_surface.get("presentation_boundary_order_reconstruction_count", 0)) == 8 and int(fallback_surface.get("presentation_generated_geometry_count", -1)) == 0, "shared-edge presentation ordering ownership mismatch")

	Support.print_result("V074_PLANET_PRESENTATION_ADAPTER_TEST", checks, failures, self)
