# Multi-Agent Collaboration Memory Protocol

This protocol turns discoveries from parallel Codex work into reusable project knowledge. It does not merge model memory or hidden reasoning. Agents share only reviewed artifacts, public API contracts, test evidence, and concise coordination messages.

## Single-writer rule

- The coordinator is the only writer of `reports/coordination/agent_knowledge_index.md`.
- Each development agent writes lessons only inside its current exclusive report directory and its task handoff.
- Agents may read every handoff and contract, but must not edit another agent's handoff, tests, or owned implementation.
- A cross-owner problem is sent as an interface request. The discovering agent must not patch the other owner's files.

## Start-of-task intake

Before editing, every agent reads:

1. `AGENTS.md` and the relevant ownership contract.
2. `reports/coordination/agent_knowledge_index.md`.
3. The latest completed handoff from each related owner.
4. The public API contract and focused tests for every dependency it will consume.

The first progress message states which lessons were adopted, which files are exclusive, and which dependencies remain read-only.

## End-of-task lesson packet

Every handoff contains a `Lessons for other agents` section with:

- invariant: behavior that must remain true;
- failed approach: what looked reasonable but was wrong, and why;
- stable API: callable surface and version/binding expectations;
- test oracle: the smallest test that proves the behavior;
- integration trap: a likely cross-owner failure;
- reusable pattern: code or test structure safe to copy conceptually;
- stale evidence: old assertions or reports invalidated by the completed fix;
- next dependency: the smallest interface another owner must provide.

Do not include hidden chain-of-thought, player secrets, credentials, or large raw logs.

## Immediate cross-agent message

Send a concise coordination message when a discovery affects an active peer. It must contain:

1. observed fact and file/API;
2. severity and concrete failure mode;
3. owner responsible for the fix;
4. required public interface or invariant;
5. tests/evidence already available;
6. explicit statement that the sender will not edit the receiver's files.

## Evidence levels

- `observed`: source inspection or one reproducible failure;
- `focused`: dedicated test passes with failure cases;
- `integrated`: cross-owner focused suite passes;
- `runtime`: Godot 4.7 scene/MCP run passes with clean errors;
- `production`: real main path is connected and player-facing behavior is verified.

Never promote a result above its evidence level. A reference owner Bench is not production evidence. A fail-closed path is not a completed feature.

## Shared-worktree discipline

- Attribute changes using thread file-change history and timestamps, not `git status` alone.
- Never use `git add -A`, bulk rollback, or cleanup on the shared tree.
- Stagger Godot imports and headless runs. Do not kill a process until ownership is known.
- Frozen tests may become stale after an intentional downstream fix. Record the stale assertion; never restore the bug merely to make the old assertion pass.

## Coordinator synthesis

After validating a handoff, the coordinator extracts only stable, evidence-backed lessons into `agent_knowledge_index.md`, links the source handoff, and sends affected lessons to active peers. Superseded lessons remain visible with a replacement link instead of being silently deleted.

## Token-efficiency mode

- Agents report at three normal milestones only: audit boundary, genuine blocker/cross-owner request, and verified handoff. Do not narrate every file edit or obvious next command.
- Search by symbol/path with bounded output. Never dump a whole large controller, report, terminal, or git diff when a matching function or file list is enough.
- Run tests in stages: parse/small focused test, owned suite, changed cross-owner suite, then one final MCP Bench. Do not rerun an unchanged frozen baseline after every edit.
- Full logs go to task-owned evidence files. Messages and handoffs quote only suite name, checks, failures, and the first actionable error.
- The supervisor polls every 15 minutes as a fallback. Completion, blocking, API changes, process contention, and boundary risks are pushed immediately by the owning agent.
- The supervisor calls `list_threads` first and reads a thread only when status or update time changed. Use `turnLimit=1` and `includeOutputs=false`; fetch a tool output only for a concrete failure.
- Supervisor git inspection is path-filtered and name-only. Read a diff hunk only when a changed path crosses ownership or a test regression points to it.
- Static rules live in this protocol; current thread IDs, ownership, and handoff paths live in `reports/coordination/active_agent_tasks.json`. Do not repeat the full common rules in every task message.
- New tasks reference the common protocol and contain only the task delta: objective, exclusive paths, domain invariants, acceptance tests, and handoff.
- Prefer a fresh task thread after accumulated context becomes large, using the prior verified handoff plus the knowledge index as the seed. Thread rotation requires user authorization in the Codex app.

Efficiency targets:

- coordination and polling: at most 10% of total tokens;
- repeated context and duplicate source reading: at most 15%;
- implementation, tests, and evidence: at least 70%;
- routine handoff summary: under 1,500 words, with detailed logs linked rather than pasted.
