# PR90 Attempt 20 startup stall postmortem

Attempt 20 did not prove an MCP endpoint failure. It proved a startup-observation failure: the runbook could not distinguish endpoint binding, endpoint ownership, request flush, response arrival, and Raw persistence because all of those actions were hidden inside one launcher loop.

The replacement tooling now uses independent M0-M11 receipts, per-stage timeouts, detached Godot stdout/stderr files, a tooling-generated launch session, an observer-only watchdog, and an HTTP transaction that records request flush before waiting for the response. Each failure records process state, endpoint owner, CPU/working set, log sizes/tails, and the last evidence file.

The pure boundary self-test passes 35/35. The latest executed minimal fixture reached M6: endpoint bound, owner matched, and the first JSON-RPC request was flushed. Its M7 observation then failed because PowerShell expanded the transaction return value. The final tooling commit fixes that shape defect and proves it with a loopback transaction test, but the final bytes were not run through Godot again.

Accordingly, the tooling is sealed but authorization-ineligible. Probe B, the PR90 pre-formal dry run, and formal MCP were not started. A new explicit non-formal probe authorization is required before an Attempt 21 formal authorization request can be issued.

Exact new tooling identity:

- Head: `3ce3f0fb9e63def5455f25481a11c28964e74821`
- Tree: `5591b46669f8f3cc223182283d3c48aaa984e8d8`
- Startup state machine: `a6090dab98b7158f789c6b196b9267770991c8811d3ca7ec4bce9ff27e8e1b9f`
- Watchdog: `e7ae19424cb36814ef9da2bf819f11b26fbe4949d7de398bc1b85b8f7ca71a40`
- Cursor-aware v5 runbook: `3f6cf15435751999154ae35c7a241a6756c1846a6958119024f61ea1921c995b`
