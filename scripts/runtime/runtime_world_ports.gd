extends Node
class_name RuntimeWorldPorts

@onready var lifecycle: RuntimeLifecyclePort = $RuntimeLifecyclePort
@onready var card: RuntimeCardPort = $RuntimeCardPort
@onready var economy: RuntimeEconomyPort = $RuntimeEconomyPort
@onready var actors: RuntimeActorPort = $RuntimeActorPort
@onready var monster: RuntimeMonsterPort = $RuntimeMonsterPort
@onready var presentation: RuntimePresentationPort = $RuntimePresentationPort
@onready var victory: RuntimeVictoryPort = $RuntimeVictoryPort


func is_ready() -> bool:
	return lifecycle != null and lifecycle.is_ready() and card != null and card.is_ready() \
		and economy != null and economy.is_ready() and actors != null and actors.is_ready() \
		and monster != null and monster.is_ready() and presentation != null and presentation.is_ready() \
		and victory != null and victory.is_ready()


func debug_snapshot() -> Dictionary:
	return {
		"ready": is_ready(),
		"port_count": 7,
		"ports": {
			"lifecycle": lifecycle.debug_snapshot() if lifecycle != null else {},
			"card": card.debug_snapshot() if card != null else {},
			"economy": economy.debug_snapshot() if economy != null else {},
			"actors": actors.debug_snapshot() if actors != null else {},
			"monster": monster.debug_snapshot() if monster != null else {},
			"presentation": presentation.debug_snapshot() if presentation != null else {},
			"victory": victory.debug_snapshot() if victory != null else {},
		},
		"owns_world_state": false,
		"references_main": false,
	}
