# Space Syndicate Future Roadmap

GENERATED_FROM=SPACE_SYNDICATE_PRODUCT_CONTINUITY_REGISTRY.json


## Registered backlog

| ID | Target | Priority | Design | Implementation | Production | Human play |
| --- | --- | --- | --- | --- | --- | --- |
| future.v076.restore_application_shell | v0.7.6.1 | P1 | AUDIT_REQUIRED | NOT_STARTED | NOT_REACHABLE | NOT_RUN |
| future.v076_adapter_acceptance | v0.7.6 | P1 | REGISTERED | PLANNED | ISOLATED | NOT_RUN |
| future.v076_domain_reducers_and_ports | v0.7.6.1 | P1 | REGISTERED | PLANNED | ISOLATED | NOT_RUN |
| future.v076_end_to_end_acceptance | Alpha0.7_Playtest2 | P0 | REGISTERED | PLANNED | PENDING | PENDING |
| future.v077_save_resume_recovery | v0.7.7 | P1 | FROZEN_REFERENCE | NOT_STARTED | DEFERRED | NOT_RUN |
| future.v076_full_tail_repair | v0.7.6.1 | P0 | DIAGNOSED | BLOCKED_PRODUCT | BLOCKED_PRODUCT | NOT_RUN |


## Rationale
- `future.v076.restore_application_shell` — 旧 MenuRootLobby 等文件存在但当前 main 闭包不可达
- `future.v076_adapter_acceptance` — existing reuse registry pending future domain
- `future.v076_domain_reducers_and_ports` — close remaining cross-domain reducer boundaries
- `future.v076_end_to_end_acceptance` — focused green is not full product green
- `future.v077_save_resume_recovery` — current candidate remains new-game-only and preserves Alpha0.4-C boundary
- `future.v076_full_tail_repair` — handoff 4 inherited sentinel is independently blocked