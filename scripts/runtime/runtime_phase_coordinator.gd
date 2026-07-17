extends Node
class_name RuntimePhaseCoordinator

@onready var lifecycle: RuntimeLifecyclePhaseCoordinator = $RuntimeLifecyclePhaseCoordinator
@onready var command: RuntimeCommandPhaseCoordinator = $RuntimeCommandPhaseCoordinator
@onready var simulation: RuntimeSimulationPhaseCoordinator = $RuntimeSimulationPhaseCoordinator
@onready var resolution: RuntimeResolutionPhaseCoordinator = $RuntimeResolutionPhaseCoordinator
@onready var state_commit: RuntimeStateCommitCoordinator = $RuntimeStateCommitCoordinator
@onready var presentation_schedule: RuntimePresentationScheduleCoordinator = $RuntimePresentationScheduleCoordinator
@onready var simulation_step: RuntimeSimulationStep = $RuntimeSimulationStep

var _last_receipt: Dictionary = {}


func bind_ports(ports: RuntimeWorldPorts) -> void:
	if ports == null:
		return
	lifecycle.bind_port(ports.lifecycle)
	command.bind_ports(ports.lifecycle, ports.card)
	simulation.bind_ports(ports.economy, ports.actors, ports.monster, ports.presentation)
	resolution.bind_port(ports.economy)
	state_commit.bind_ports(ports.economy, ports.victory)
	presentation_schedule.bind_port(ports.presentation)
	_bind_simulation_step()


func is_ready() -> bool:
	return lifecycle != null and lifecycle.is_ready() and command != null and command.is_ready() \
		and simulation != null and simulation.is_ready() and resolution != null and resolution.is_ready() \
		and state_commit != null and state_commit.is_ready() \
		and presentation_schedule != null and presentation_schedule.is_ready() \
		and simulation_step != null and simulation_step.is_ready()


func advance_frame(real_delta: float) -> Dictionary:
	var context := RuntimePhaseFrameContext.new(real_delta)
	if not is_ready():
		_last_receipt = context.receipt()
		return _last_receipt.duplicate(true)
	var path := lifecycle.begin_frame(context)
	if path == &"global_blocked":
		simulation.advance_blocked_realtime(context)
		presentation_schedule.advance_blocked_realtime(context)
		return _finish(context)
	if path != &"active":
		return _finish(context)
	var step_receipt := simulation_step.advance_active(context)
	if not bool(step_receipt.get("completed", false)):
		return _finish(context)
	presentation_schedule.advance_frame_end(context)
	return _finish(context)


func debug_snapshot() -> Dictionary:
	return {
		"ready": is_ready(),
		"phase_count": 6,
		"simulation_step_count": 1,
		"owns_world_state": false,
		"owns_gameplay_rules": false,
		"last_receipt": _last_receipt.duplicate(true),
	}


func _finish(context: RuntimePhaseFrameContext) -> Dictionary:
	_last_receipt = context.receipt()
	return _last_receipt.duplicate(true)


func _bind_simulation_step() -> void:
	if simulation_step != null:
		simulation_step.bind_phases(command, simulation, resolution, lifecycle, state_commit)
