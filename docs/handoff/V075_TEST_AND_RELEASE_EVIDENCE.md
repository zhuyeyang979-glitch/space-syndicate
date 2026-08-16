# V0.7.5 测试与 Release Evidence

## 当前身份

- PR #90 Head：`1e948a15e17faffe648722fd596fac01a4525426`
- Tree：`8508df4e900a73c058566f00fc556ec1d11e08ca`
- CI：Run `31956611702`，SUCCESS
- PR：OPEN DRAFT，MERGEABLE

## 关键结果

| 项目 | 结果 | 说明 |
|---|---|---|
| 旧 Head Release Gate 2—15 | 14/14 PASS | Continuation 002；正式 Raw Authority/Receipt 已保存 |
| 旧 Head Release Gate 16 | PRODUCT FAIL | Raw SHA `a72f48f06175286e38c5d82a6d4c08f15ee53e3eec7a1a91b8a63e9db7268b9b` |
| 唯一产品修复 | COMMITTED | `1e948a15`；仅 `v075_runtime_owner.gd` |
| 修复后定向 Gate 15 | PASS | Result SHA `6d785b3ebd605460690f2ea5deeef1cabdad935bcc1a70f975c4cc22a05b80e8` |
| 修复后定向 Gate 16 | PASS | Result SHA `e96b8ffa965dbfc3020180b56d3d44c387deed819cfaf4f19aa61b25e7eea101` |
| 修复后定向 Gate 60 | PASS | Result SHA `aa456b28c7320da83b479cc641a4cb78da624d214c7247104b9c38c50ad2c1ba` |
| 新 Head CI | PASS | Run `31956611702` |
| Revision 002 ReleaseRunPlan Dry Run | 6/6 PASS | 1—79、2—79、3—79、60—79、仅 79、非连续；无 Godot |
| 现有 Runner full-plan 穷尽审计 | NO AUTHORIZED ENTRYPOINT | 6 个候选实例／5 个唯一 Worker SHA；只读、无 Godot |
| Gate 1 Source Contract V2 Revision | PASS | 唯一 post-repair Tooling Revision；产品文件 0 |
| 最终 Preflight Attempt 003 | 18/18 PASS | Worker Dry Run 6/6；Manifest 负例 8/8；Aggregate 负例 4/4 |
| Full-formal Aggregate fixture | PASS | 79 当前来源；79 Receipt；0 reuse |
| Frozen-reuse Aggregate fixture | PASS | 1 真实冻结复用 + 78 当前来源；78 Receipt |
| 真实冻结 Result 投影 | PASS | Raw Result → Normalize → Row → Receipt |
| 新 Head Acceptance Clone | PASS | exact Head/Tree；clean；Windows long-path enabled |
| 新 Head Canonical Import | NOT_RUN | pre-product Manifest blocker 前未消耗 |
| 新 Head Formal Gate 1—79 | NOT_STARTED | execution count 0；Godot starts 0 |
| 79/79 Aggregate | NOT_RUN | 阻塞 |
| Review/MCP/Viewport/Headless/2,000 | NOT_RUN | 阻塞 |
| PR merge/tag | NOT_RUN | 阻塞 |

旧 Head Gate 16 的四项失败均属于 submission rollback/exact-once 产品断言。修复恢复最小 Combat Owner 的既有 fallback，没有改变真实 typed Owner 路径、规则、数值、测试或 Canonical Manifest。

历史 blocker 保持原样冻结：Blocker Evidence SHA `ba70bec044b245338f94c6efd5eb04664ee8adc3708cf393713a56c95339b7df`，Exhaustion Audit SHA `17500b45a0c5362fe425d2666cebd68595c947f462bdb23a47ce39b7df`。

新合同的正式计划为 Gate 1—79，Plan SHA `55323dab888060b0214c00c81c43993af9b69c28a28939f84f34b569f0b78e85`；Manifest SHA `1be88a6b41e9e2154a4f59c85c30095767379f2c01ef3d9fada0fd363493e68c`；Worker SHA `675f5ad470fb26bc377731e1ba9e7380c9852d33b4200fdca0c72ac6f9a5d8bd`；Projector SHA `f9dc0a85ddc2861eb14645044aef8bcfa3f32c103558a29a65a53a3547cc0509`；Preflight Report SHA `38c434c83247180afe4051ea15e53f52ddccae4857473ae257ae852036f278ae`。

当前 Godot/Worker/7576/7586 均为 0，Canonical Import 与 Formal Execution 均为 0，产品 Attempt 未消耗。Runner-only 任务已经完成；必须单独授权 `PR90_REPAIRED_HEAD_FULL_GATE1_79_FORMAL_ATTEMPT_001` 才能启动第一个产品 Godot 进程。
