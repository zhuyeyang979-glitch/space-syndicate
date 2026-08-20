# V0.7.6 deterministic simulation kernel

Status: **TEST_ONLY production candidate** until the Stage 7 composition cutover.

## Player-facing hard standard

The same seed and the same legal player commands must produce the same gameplay
result regardless of render frame rate, animation timing, command arrival order,
or unrelated random draws in another gameplay domain. A saved tick-boundary
snapshot must resume to the same ordered command log and terminal state hash.

## Authority contract

- `mechanic_id`: `v076.deterministic_simulation_kernel`
- rule source: the v0.7.6 master delivery authorization, deterministic combat
  clock section; inherited hidden-information rules remain unchanged.
- player meaning: combat and Direct Actions resolve consistently and can be
  saved, resumed, audited, and replayed.
- authoritative owner: one `V076DeterministicKernel` instance in the future
  production composition.
- privacy: authority state stays private by default. Public UI receives only
  separately allowlisted presentation receipts.
- persistence: tick-boundary snapshot plus ordered command log, per-domain RNG
  cursors, Authority Sequence cursor, and SHA256 identities.

The clock is integer-only: 20 ticks per second and exactly 50,000 microseconds
per tick. The kernel never reads engine frames, wall time, OS time, or camera/UI
state.

Before a tick executes, commands are sorted by:

1. scheduled tick;
2. domain priority;
3. domain ID;
4. actor ID;
5. producer sequence;
6. command ID.

Only after that stable order is closed does the kernel allocate its monotonic
Authority Sequence. Duplicate identical command IDs are acknowledged without a
second effect; a same-ID/different-payload collision fails closed.

Authority values are restricted to `null`, Boolean, integer, String, Array, and
String-keyed Dictionary. Float, StringName, Vector, Color, Object, Callable,
and presentation fields fail validation with an exact path. Dictionary keys are
canonicalized before SHA256 identity is calculated. The persistence decoder
requires the expected canonical-byte SHA256, restores only JSON numbers that
are exact safe integers, and rejects non-canonical or fractional encodings.

Each domain owns an independent Park-Miller integer RNG stream derived from the
root seed and domain namespace. Its state and draw cursor are included in every
snapshot. Domain logic is registered only as an instantiable `Script` with an
explicit stateless, deterministic, replay-safe contract. The kernel itself
calls `Script.new()` for every command and snapshot replay, so cached or
rotating factory-owned reducer instances cannot enter authority execution.
Reducers that declare external side effects or presentation ownership are
rejected. Reducer scripts must be zero-argument constructible. Presentation and
animation own no gameplay mutation path.

Snapshot restore is transactional and performs a full semantic replay before
installing any live field. The replay must reproduce the terminal authority
fingerprint, every sequenced command record, and every tick hash byte-for-byte.

## Acceptance surface

- `res://tests/v076_deterministic_kernel_test.gd`
- `res://scenes/tools/v076/V076DeterministicKernelBench.tscn`

The focused gate covers the integer 20Hz clock, zero-float authority, stable
same-tick ordering, domain RNG isolation, exact-once commands, collision
rejection, tick-boundary save/restore, tamper rejection, per-command before and
after hashes, and at least 2,000 independent deterministic replays.

Stage 1 deliberately does not modify `main.tscn`, project autoloads, V0.7.5
composition, or current production gameplay. Stage 7 will perform one atomic
composition cutover after the map, movement, Direct Action, and presentation
owners are ready.
