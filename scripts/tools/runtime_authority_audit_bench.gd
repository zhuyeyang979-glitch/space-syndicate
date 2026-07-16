extends Node

@onready var audit: RuntimeAuthorityAudit = $RuntimeAuthorityAudit


func _ready() -> void:
	var failures: Array[String] = []
	for role in RuntimeAuthorityAudit.VALID_ROLES:
		if not audit.register_authority(&"card_execution", role, NodePath("../CardOwner"), 1):
			failures.append("valid_registration_rejected:%s" % role)
	var clean := audit.audit_snapshot()
	if not bool(clean.get("ok", false)) or int(clean.get("duplicate_count", -1)) != 0:
		failures.append("single_authority_not_clean")

	if not audit.register_authority(
		&"card_execution",
		&"tick_owner",
		NodePath("../SecondCardTickOwner"),
		1
	):
		failures.append("duplicate_fixture_registration_rejected")
	var duplicate := audit.audit_snapshot()
	if bool(duplicate.get("ok", true)):
		failures.append("duplicate_authority_not_rejected")
	if int(duplicate.get("duplicate_tick_count", 0)) != 1:
		failures.append("duplicate_tick_not_counted")
	if int(duplicate.get("duplicate_signal_count", -1)) != 0:
		failures.append("unrelated_duplicate_signal_reported")

	var status := "PASS" if failures.is_empty() else "FAIL"
	print(
		"RUNTIME_AUTHORITY_AUDIT_BENCH|status=%s|checks=10|failures=%d|notes=%s"
		% [status, failures.size(), JSON.stringify(failures)]
	)
	if not failures.is_empty():
		push_error("Runtime authority audit bench failed: %s" % failures)
