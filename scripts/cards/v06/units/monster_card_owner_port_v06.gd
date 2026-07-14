extends UnitCardOwnerForwardingPortV06
class_name MonsterCardOwnerPortV06


func configure_owner(owner: Object) -> Dictionary:
	return configure(owner, "monster")


func capability_matrix() -> Dictionary:
	var matrix := super.capability_matrix()
	if _owner == null or not _owner.has_method("unit_card_runtime_capabilities_v06"):
		return matrix
	var declared_variant: Variant = _owner.call("unit_card_runtime_capabilities_v06", "monster")
	if not (declared_variant is Dictionary):
		return matrix
	var declared := declared_variant as Dictionary
	var owner_atomic_ready := bool(declared.get("atomic_mutation_ready", false))
	matrix["cross_owner_dependency_matrix"] = (declared.get("cross_owner_dependency_matrix", {}) as Dictionary).duplicate(true) if declared.get("cross_owner_dependency_matrix", {}) is Dictionary else {}
	matrix["production_ready_scope"] = str(declared.get("production_ready_scope", declared.get("p0_scope", "rank_1_starter_first_summon_and_same_family_upgrade")))
	matrix["upgrade_duration_policy_ready"] = bool(declared.get("upgrade_duration_policy_ready", false))
	matrix["atomic_mutation_ready"] = bool(matrix.get("atomic_mutation_ready", false)) and owner_atomic_ready
	if not bool(matrix.get("atomic_mutation_ready", false)):
		matrix["capability_reason"] = str(declared.get("capability_reason", "monster_cross_owner_atomicity_unavailable"))
	return matrix
