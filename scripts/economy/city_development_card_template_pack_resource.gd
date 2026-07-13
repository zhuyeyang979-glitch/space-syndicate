extends Resource
class_name CityDevelopmentCardTemplatePackResource

@export var pack_id := "core_city_development_v04"
@export var templates: Array[Resource] = []


func definitions_for_products(product_ids: Array) -> Dictionary:
	var result := {}
	for product_variant in product_ids:
		var product_id := str(product_variant).strip_edges()
		if product_id == "":
			continue
		for template_variant in templates:
			if template_variant == null or not template_variant.has_method("make_definition"):
				continue
			for rank in range(1, 5):
				var definition: Dictionary = template_variant.call("make_definition", product_id, rank)
				var card_name := str(definition.get("name", ""))
				if card_name != "":
					result[card_name] = definition
	return result
