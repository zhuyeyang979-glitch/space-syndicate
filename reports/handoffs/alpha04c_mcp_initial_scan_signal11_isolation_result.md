# Alpha 0.4-C MCP initial-scan isolation result

Status: BLOCKED.

## Matrix result

The minimal cells M0, M1, M2, and M3 all completed with no native crash and no
diagnostics. M2 observed the endpoint with zero requests. M3 sent exactly the
three permitted read-only requests.

Both full-project no-MCP controls failed:

- B0: origin/main, Funplay disabled, zero endpoint and requests, signal 11.
- P0: PR77, Funplay disabled, zero endpoint and requests, signal 11.

B1 was skipped because B0 was not GREEN. P1 was skipped because P0 was not
GREEN. This is a gate-driven skip, not missing evidence.

## Native failure

Both B0 and P0 failed during 3D texture post-import reconfiguration. Windows
reported access violation 0xc0000005 at fault offset 0x327d10a. Both Godot logs
contain the same 41-frame raw backtrace, without symbols.

The crash is reproducible without the Funplay addon, endpoint, transport poll,
or wrapper request. The isolated trigger class is therefore the Godot 4.7 ANGLE
full-project import path, not MCP request reentrancy. The final logged HDR
resource is not claimed as the individual root cause.

## Project diagnostics

P0 reproduced the prior PR77 sequence exactly:

- 9 pathless Unicode/NUL diagnostics whose source remains unclassified.
- 10 real GDScript parse diagnostics in five files.
- 5 failed loads caused by those parse diagnostics.

These all occur before signal 11. The parse and load diagnostics are real
project errors because P0 used a fresh cache with MCP disabled. They are not
MCP errors or interrupted-scan aftermath.

## Stop boundary

The task stops before B1, P1, reload self-tests, or PR77 retrospective
acceptance. No Session, Save, gameplay, main.gd, main.tscn, V0.7.3, PR80, or
PR82 code was changed. V8, Process A, Formal, FullRun, Smoke, and smoke_test.gd
were not started.

Next task:

ALPHA_0_4_C_PR77_MCP_ATTESTED_SCRIPT_OR_RESOURCE_REPAIR
