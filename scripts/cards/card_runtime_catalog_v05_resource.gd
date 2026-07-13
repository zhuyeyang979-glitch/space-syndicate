extends Resource
class_name CardRuntimeCatalogV05Resource

@export var schema_version: String = "v0.5"
@export var cards: Array[CardRuntimeRankV05Resource] = []
@export var release_ready_card_ids: Array[String] = []
@export var public_pool_card_ids: Array[String] = []


func card_ids() -> Array[String]:
	var result: Array[String] = []
	for card in cards:
		if card != null:
			result.append(card.card_id)
	return result


func card_snapshot(card_id: String) -> Dictionary:
	for card in cards:
		if card != null and card.card_id == card_id:
			return card.to_snapshot()
	return {}


func debug_snapshot() -> Dictionary:
	var card_snapshots: Array[Dictionary] = []
	for card in cards:
		if card != null:
			card_snapshots.append(card.to_snapshot())
	return {
		"schema_version": schema_version,
		"cards": card_snapshots,
		"release_ready_card_ids": release_ready_card_ids.duplicate(),
		"public_pool_card_ids": public_pool_card_ids.duplicate(),
	}
