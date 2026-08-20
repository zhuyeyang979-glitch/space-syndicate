# PR90 characterization controller canonical/cardinality repair

Status: **BLOCKED on a new netstat adapter scope defect**.

The requested controller repair is complete and sealed at Tooling HEAD `bdbf852c587b720970d20dc2602c8f7dcfe9bae4` / TREE `4542a667faed2b78ad6c614bd660974f24873d43`. The expanded self-test passes 49/49, including ordered-dictionary and PSCustomObject canonical receipt generation plus 0/1/N collection cardinality.

The single new passive probe `pr90-m5-endpoint-owner-characterization-v3-001` proved both requested fixes: M0 contains a valid, recomputable canonical payload SHA, and an empty Godot process set no longer raises a Count exception. The probe then failed closed before M1 because the netstat adapter parses all global TCP rows as if each were a listener before applying the requested 7576/7586 port filter. A read-only diagnostic observed 247 global TCP rows, zero target-port records, and 214 false parse failures from unrelated `ESTABLISHED`, `TIME_WAIT`, and `CLOSE_WAIT` rows.

No Godot process was created, both protected ports remained empty, no endpoint request or JSON-RPC was sent, M6–M11 and formal MCP counts remain zero, and the probe was not retried. The prior `v2-001` root and the new `v3-001` root are both frozen.

The next task must repair only the netstat target-port prefilter ordering: extract local endpoint/state/PID, ignore rows outside the requested port set, and then strictly validate LISTEN state for target-port rows. Unknown state on a target port must remain fail-closed.

`NEXT_TASK=PR90_NETSTAT_LISTENER_ADAPTER_TARGET_PORT_PREFILTER_AND_NON_LISTENER_STATE_SCOPE_FIX_AUTHORIZATION`
