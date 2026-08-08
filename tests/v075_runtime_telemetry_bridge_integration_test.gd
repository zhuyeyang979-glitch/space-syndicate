extends SceneTree

const RUNTIME_OWNER_PATH := (
	"res://scripts/v075_runtime/v075_runtime_owner.gd"
)
const COMBAT_OWNER_PATH := (
	"res://scripts/v075/runtime/v075_combat_runtime_owner.gd"
)
const TELEMETRY_BRIDGE_PATH := (
	"res://scripts/v075/telemetry/v075_combat_telemetry_bridge.gd"
)
const TELEMETRY_CONTRACT_PATH := (
	"res://scripts/v075/telemetry/v075_combat_telemetry_contract.gd"
)
const PRESENTATION_CONSUMER_PATH := (
	"res://scripts/v075/presentation/v075_combat_presentation_consumer.gd"
)
const REQUIRED_PATHS := [
	RUNTIME_OWNER_PATH,
	COMBAT_OWNER_PATH,
	TELEMETRY_BRIDGE_PATH,
	TELEMETRY_CONTRACT_PATH,
	PRESENTATION_CONSUMER_PATH,
]
const FORBIDDEN_FIELD_FRAGMENTS := [
	"skill_definition",
	"skill_card",
	"skill_target",
	"cooldown_remaining",
	"cooldown_batches",
	"private",
	"future",
	"instant_sequence",
	"internal_order",
	"warehouse_stock",
	"logistics_plan",
	"ai_plan",
	"hidden",
	"rng_state",
	"owner_player_id",
	"player_id",
	"source_instance_id",
	"card_instance_id",
]

var _checks := 0
var _failures: Array[String] = []
var _missing_dependencies: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for path_variant in REQUIRED_PATHS:
		var path := str(path_variant)
		if not ResourceLoader.exists(path):
			_missing_dependencies.append(path)
	_expect(
		_missing_dependencies.is_empty(),
		"production_runtime_telemetry_dependencies_missing:%s"
			% ",".join(_missing_dependencies)
	)
	if not _missing_dependencies.is_empty():
		_finish()
		return

	var runtime_script := load(RUNTIME_OWNER_PATH) as Script
	var combat_script := load(COMBAT_OWNER_PATH) as Script
	_expect(
		runtime_script != null and combat_script != null,
		"production_runtime_telemetry_owner_scripts_load"
	)
	if runtime_script == null or combat_script == null:
		_finish()
		return

	var runtime := runtime_script.new() as Node
	var combat := combat_script.new() as Node
	_expect(
		is_instance_valid(runtime) and is_instance_valid(combat),
		"production_runtime_telemetry_owner_instances_create"
	)
	if not is_instance_valid(runtime) or not is_instance_valid(combat):
		_finish()
		return
	root.add_child(runtime)
	root.add_child(combat)

	var bound := runtime.call("bind_combat_owner", combat) as Dictionary
	_expect(
		bool(bound.get("accepted", false)),
		"production_runtime_combat_owner_bind"
	)
	if not bool(bound.get("accepted", false)):
		_cleanup(runtime, combat)
		_finish()
		return

	var signal_sources: Array = [combat, runtime]
	var receipt_link := _find_connection(
		signal_sources,
		["combat_receipt_committed", "resolution_presented"],
		"consume_public_receipt"
	)
	var presentation_link := _find_connection(
		signal_sources,
		["public_combat_result_ready", "resolution_presented"],
		"consume_receipt"
	)
	_expect(
		not receipt_link.is_empty(),
		"production_runtime_telemetry_receipt_connection_missing:"
			+ "expected combat_receipt_committed/resolution_presented"
			+ " -> consume_public_receipt"
	)
	_expect(
		not presentation_link.is_empty(),
		"production_runtime_presentation_receipt_connection_missing:"
			+ "expected public_combat_result_ready/resolution_presented"
			+ " -> consume_receipt"
	)
	if receipt_link.is_empty() or presentation_link.is_empty():
		_cleanup(runtime, combat)
		_finish()
		return

	var telemetry: Object = receipt_link.get("target") as Object
	var presentation: Object = presentation_link.get("target") as Object
	var cue_link := _find_connection(
		[presentation],
		["presentation_cue_ready"],
		"consume_public_cue"
	)
	_expect(
		not cue_link.is_empty()
			and cue_link.get("target") == telemetry,
		"production_runtime_telemetry_cue_connection_missing:"
			+ "expected presentation_cue_ready"
			+ " -> same telemetry bridge consume_public_cue"
	)
	if cue_link.is_empty() or cue_link.get("target") != telemetry:
		_cleanup(runtime, combat)
		_finish()
		return

	var initial_telemetry := telemetry.call("debug_snapshot") as Dictionary
	var initial_presentation := (
		presentation.call("debug_snapshot") as Dictionary
	)
	_expect(
		int(initial_telemetry.get("emitted_event_count", -1)) == 0
			and int(initial_telemetry.get("source_binding_count", -1)) == 0
			and int(
				initial_presentation.get("applied_receipt_count", -1)
			) == 0,
		"production_runtime_telemetry_starts_detached_and_empty"
	)

	var receipt := _public_receipt()
	var receipt_before := receipt.duplicate(true)
	_emit_link(receipt_link, receipt)
	if not _same_signal_link(receipt_link, presentation_link):
		_emit_link(presentation_link, receipt)
	_emit_link(receipt_link, receipt)
	if not _same_signal_link(receipt_link, presentation_link):
		_emit_link(presentation_link, receipt)

	var telemetry_debug := telemetry.call("debug_snapshot") as Dictionary
	var presentation_debug := (
		presentation.call("debug_snapshot") as Dictionary
	)
	var events := telemetry.call("recent_events", 10) as Array
	var cues := presentation.call("recent_cues", 10) as Array
	_expect(
		int(telemetry_debug.get("receipt_input_count", -1)) == 2
			and int(telemetry_debug.get("cue_input_count", -1)) == 1
			and int(telemetry_debug.get("emitted_event_count", -1)) == 1
			and int(
				telemetry_debug.get("duplicate_source_count", -1)
			) == 2
			and int(
				telemetry_debug.get("source_binding_count", -1)
			) == 1,
		"public_receipt_and_cue_share_one_exact_once_telemetry_identity"
	)
	_expect(
		int(presentation_debug.get("applied_receipt_count", -1)) == 1
			and int(
				presentation_debug.get("duplicate_receipt_count", -1)
			) == 1
			and int(
				presentation_debug.get("collision_receipt_count", -1)
			) == 0,
		"public_receipt_reaches_presentation_exactly_once"
	)
	_expect(
		events.size() == 1
			and cues.size() == 1
			and receipt == receipt_before,
		"runtime_telemetry_and_presentation_consumers_are_read_only"
	)

	var event := events[0] as Dictionary if not events.is_empty() else {}
	var cue := cues[0] as Dictionary if not cues.is_empty() else {}
	var event_payload := event.get("payload", {}) as Dictionary
	var cue_payload := cue.get("public_payload", {}) as Dictionary
	_expect(
		str(event.get("event_type", ""))
				== "monster_private_skill_resolved"
			and str(event_payload.get("public_effect_id", ""))
				== "effect.public.integration"
			and int(event_payload.get("damage_amount", -1)) == 7,
		"runtime_public_receipt_retains_allowed_telemetry_parity"
	)
	_expect(
		str(cue.get("event_kind", ""))
				== "monster_private_skill_resolved"
			and str(cue_payload.get("public_effect_id", ""))
				== "effect.public.integration"
			and int(cue_payload.get("damage_amount", -1)) == 7,
		"runtime_public_receipt_retains_allowed_presentation_parity"
	)
	_expect(
		not _contains_forbidden_field(event)
			and not _contains_forbidden_field(cue)
			and int(
				telemetry_debug.get("stored_hidden_field_count", -1)
			) == 0,
		"runtime_telemetry_and_cue_store_no_hidden_fields"
	)
	_expect(
		int(
			telemetry_debug.get(
				"opponent_skill_definition_input_count",
				0
			)
		) > 0
			and int(
				telemetry_debug.get(
					"opponent_skill_target_input_count",
					0
				)
			) > 0
			and int(
				telemetry_debug.get(
					"opponent_skill_cooldown_input_count",
					0
				)
			) > 0
			and int(
				telemetry_debug.get("instant_sequence_input_count", 0)
			) > 0
			and int(
				telemetry_debug.get(
					"warehouse_private_stock_input_count",
					0
				)
			) > 0
			and int(
				telemetry_debug.get("ai_private_plan_input_count", 0)
			) > 0,
		"runtime_telemetry_observes_then_filters_all_hidden_categories"
	)

	var contract_debug := (
		telemetry_debug.get("contract", {}) as Dictionary
	)
	_expect(
		int(telemetry_debug.get("gameplay_owner_count", -1)) == 0
			and int(telemetry_debug.get("rng_owner_count", -1)) == 0
			and int(telemetry_debug.get("world_mutation_count", -1)) == 0
			and int(contract_debug.get("gameplay_owner_count", -1)) == 0
			and int(contract_debug.get("rng_owner_count", -1)) == 0
			and int(contract_debug.get("world_mutation_count", -1)) == 0,
		"runtime_telemetry_has_zero_gameplay_rng_and_world_mutation"
	)
	_expect(
		int(
			presentation_debug.get(
				"presentation_gameplay_mutation_count",
				-1
			)
		) == 0
			and int(
				presentation_debug.get("presentation_rng_draw_delta", -1)
			) == 0
			and int(cue.get("gameplay_mutation_count", -1)) == 0
			and int(cue.get("rng_draw_delta", -1)) == 0,
		"runtime_presentation_has_zero_gameplay_and_rng_mutation"
	)

	var reset_invoked := false
	if runtime.has_method("reset_for_new_match"):
		runtime.call("reset_for_new_match")
		reset_invoked = true
	elif runtime.has_method("_reset_runtime"):
		runtime.call("_reset_runtime")
		reset_invoked = true
	_expect(
		reset_invoked,
		"production_runtime_new_match_reset_entrypoint_missing"
	)
	var reset_telemetry := telemetry.call("debug_snapshot") as Dictionary
	var reset_presentation := (
		presentation.call("debug_snapshot") as Dictionary
	)
	_expect(
		int(reset_telemetry.get("receipt_input_count", -1)) == 0
			and int(reset_telemetry.get("cue_input_count", -1)) == 0
			and int(reset_telemetry.get("emitted_event_count", -1)) == 0
			and int(reset_telemetry.get("source_binding_count", -1)) == 0
			and (telemetry.call("recent_events", 10) as Array).is_empty(),
		"new_match_reset_clears_runtime_telemetry_exact_once_state"
	)
	_expect(
		int(reset_presentation.get("applied_receipt_count", -1)) == 0
			and int(
				reset_presentation.get("duplicate_receipt_count", -1)
			) == 0
			and (
				presentation.call("recent_cues", 10) as Array
			).is_empty(),
		"new_match_reset_clears_runtime_presentation_exact_once_state"
	)
	_expect(
		int(reset_telemetry.get("gameplay_owner_count", -1)) == 0
			and int(reset_telemetry.get("rng_owner_count", -1)) == 0
			and int(reset_telemetry.get("world_mutation_count", -1)) == 0
			and int(
				reset_presentation.get(
					"presentation_gameplay_mutation_count",
					-1
				)
			) == 0
			and int(
				reset_presentation.get(
					"presentation_rng_draw_delta",
					-1
				)
			) == 0,
		"new_match_reset_preserves_zero_mutation_contracts"
	)

	_cleanup(runtime, combat)
	_finish()


func _public_receipt() -> Dictionary:
	return {
		"ruleset_id": "v0.7.5",
		"combat_receipt_id": "combat.runtime.telemetry.integration.001",
		"event_kind": "monster_private_skill_resolved",
		"batch_id": "batch.runtime.telemetry.001",
		"source_rank": 4,
		"public_effect_id": "effect.public.integration",
		"target_kind": "region",
		"damage_amount": 7,
		"public_summary": "public combat result",
		"skill_definition_id": "skill.hidden.owner_only",
		"skill_target": "facility.hidden.future",
		"cooldown_remaining_batches": 3,
		"monster_private_instant_sequence": 42,
		"warehouse_stock": ["stock.hidden.001"],
		"ai_private_plan": {"next_target": "facility.hidden.002"},
	}


func _find_connection(
	sources: Array,
	signal_names: Array,
	required_method: String
) -> Dictionary:
	for source_variant in sources:
		var source := source_variant as Object
		if not is_instance_valid(source):
			continue
		for signal_variant in signal_names:
			var signal_name := str(signal_variant)
			if not source.has_signal(signal_name):
				continue
			for connection_variant in source.get_signal_connection_list(
				signal_name
			):
				var connection := connection_variant as Dictionary
				var callable_variant: Variant = connection.get("callable")
				if not (callable_variant is Callable):
					continue
				var callable := callable_variant as Callable
				var target := callable.get_object()
				if (
					is_instance_valid(target)
					and target.has_method(required_method)
				):
					return {
						"source": source,
						"signal_name": signal_name,
						"target": target,
						"callable": callable,
					}
	return {}


func _emit_link(link: Dictionary, receipt: Dictionary) -> void:
	var source := link.get("source") as Object
	source.emit_signal(
		str(link.get("signal_name", "")),
		receipt.duplicate(true)
	)


func _same_signal_link(left: Dictionary, right: Dictionary) -> bool:
	return (
		left.get("source") == right.get("source")
		and str(left.get("signal_name", ""))
			== str(right.get("signal_name", ""))
	)


func _contains_forbidden_field(value: Variant) -> bool:
	if value is Dictionary:
		var dictionary := value as Dictionary
		for key_variant in dictionary.keys():
			var key := str(key_variant).to_lower()
			for fragment_variant in FORBIDDEN_FIELD_FRAGMENTS:
				if str(fragment_variant) in key:
					return true
			if _contains_forbidden_field(dictionary.get(key_variant)):
				return true
	elif value is Array:
		for child_variant in value as Array:
			if _contains_forbidden_field(child_variant):
				return true
	return false


func _cleanup(runtime: Node, combat: Node) -> void:
	if is_instance_valid(combat):
		combat.queue_free()
	if is_instance_valid(runtime):
		runtime.queue_free()


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures.append(message)
	push_error(message)


func _finish() -> void:
	print(
		"V075_RUNTIME_TELEMETRY_BRIDGE_INTEGRATION_TEST|%s"
		% JSON.stringify({
			"status": "PASS" if _failures.is_empty() else "FAIL",
			"passed": _checks - _failures.size(),
			"total": _checks,
			"failures": _failures,
			"missing_dependencies": _missing_dependencies,
			"coverage_complete": _failures.is_empty(),
			"gameplay_mutation_count": (
				0 if _failures.is_empty() else -1
			),
			"rng_mutation_count": (
				0 if _failures.is_empty() else -1
			),
			"world_mutation_count": (
				0 if _failures.is_empty() else -1
			),
		})
	)
	quit(0 if _failures.is_empty() else 1)