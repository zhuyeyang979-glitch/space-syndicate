# PR90 netstat target-port prefilter fix and V4 blocker

The authorized Tooling repair is sealed at Head `55ce9f6bb0f9edb43ad81afdf3582d49a984ebdc` / Tree `231152886b5054c32af90378b096c3ae59f35ca4`. The adapter now parses a TCP row lexically, validates its local port, ignores valid rows outside 7576/7586 before listener-state validation, and still rejects malformed or non-listener rows on a target port. The committed pure test is `57/57 PASS`; its real global-netstat target observation has zero parse failures.

The new characterization-only authority is sealed: manifest `fc3236efe39d0415b36fc0af34fc8c30e178c6edf98ec057771d40458cc917a1`, validation `0e86db6e59a9db3dec29e6064f3208c5da5ba186dcc89481a40d00daff701f59`, seal `929752760447121dc3397d1d1621d317d6f12e5c6ffcc6a4cd55484189847edd`, and self-test `41545777923bd9105c3494663fb92838bf7b6c13a7f56f0ef97a89a8ab89649f`. Formal authorization remains false.

The one authorized passive probe `pr90-m5-endpoint-owner-characterization-v4-001` was consumed exactly once and was not retried. M0–M4 all persisted PASS. M4 observed exactly one 7576 listener in both sources, and the first M5 sample obtained owner PID `13108`. The controller then failed with `Cannot convert the System.Object[] value ... to type System.Int32`; no M5 receipt or sample/parity evidence was persisted.

Read-only source localization places the new defect at the ancestor-chain cardinality boundary: `Get-EndpointProcessAncestorChainV1` returns `,@($rows)`, while the controller calls it inside `@(…)`; the nested array reaches `[int]$_.pid`. That classification is diagnostic only. This consumed Tooling authority was not modified and the probe was not rerun.

Terminal cleanup is green: no task-owned process, Godot process, 7576 listener, or 7586 listener remains; forced stop is false. `FIRST_JSONRPC_REQUEST_SENT=false`, endpoint request count is 0, M6–M11 count is 0, formal MCP count is 0, and authorized formal-run consumption remains 0. Product/addon/formal-M5 changes are all zero. A fresh authorization and new Tooling SHA are required for any ancestor-chain cardinality repair or another passive probe.
