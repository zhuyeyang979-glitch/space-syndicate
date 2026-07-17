extends Node
class_name RuntimeWorldPorts

var lifecycle: RuntimeLifecyclePort:
	get: return get_node_or_null("RuntimeLifecyclePort") as RuntimeLifecyclePort
var card: RuntimeCardPort:
	get: return get_node_or_null("RuntimeCardPort") as RuntimeCardPort
var economy: RuntimeEconomyPort:
	get: return get_node_or_null("RuntimeEconomyPort") as RuntimeEconomyPort
var actors: RuntimeActorPort:
	get: return get_node_or_null("RuntimeActorPort") as RuntimeActorPort
var monster: RuntimeMonsterPort:
	get: return get_node_or_null("RuntimeMonsterPort") as RuntimeMonsterPort
var presentation: RuntimePresentationPort:
	get: return get_node_or_null("RuntimePresentationPort") as RuntimePresentationPort
var victory: RuntimeVictoryPort:
	get: return get_node_or_null("RuntimeVictoryPort") as RuntimeVictoryPort


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
