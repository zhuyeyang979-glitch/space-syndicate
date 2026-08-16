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
| 新 Head Canonical Import | NOT_AVAILABLE_IN_FORMAL_CLONE | Clone 无 `.godot/global_script_class_cache.cfg`；Manifest 引用旧 Head Import Evidence |
| 新 Head Formal Attempt 001 | RUNNER_BLOCKED | execution count 1；Attempt consumed；Gate 1 Godot started once |
| 新 Head Gate 1 Raw Invocation | FAILED_ENVIRONMENT_PRECONDITION | exit 1；timeout false；1,158 个缺失 class_name 解析错误；Raw SHA `fc7fea93e7e097892959b25493f51d7dd12239c3885880476217c60750f36736` |
| 新 Head Gate 1 Product Authority | NOT_ATTESTED | Raw `diagnostics` 为 object；Normalizer fail closed：`product_executor_diagnostics_wrong_type` |
| 新 Head Gate 2—79 | NOT_STARTED | Gate 1 后 Runner 无法继续；不得自动重跑 |
| 79/79 Aggregate | NOT_RUN | 阻塞 |
| Review/MCP/Viewport/Headless/2,000 | NOT_RUN | 阻塞 |
| PR merge/tag | NOT_RUN | 阻塞 |

旧 Head Gate 16 的四项失败均属于 submission rollback/exact-once 产品断言。修复恢复最小 Combat Owner 的既有 fallback，没有改变真实 typed Owner 路径、规则、数值、测试或 Canonical Manifest。

历史 blocker 保持原样冻结：Blocker Evidence SHA `ba70bec044b245338f94c6efd5eb04664ee8adc3708cf393713a56c95339b7df`，Exhaustion Audit SHA `17500b45a0c5362fe425d2666cebd68595c947f462bdb23a47ce39b7df`。

新合同的正式计划为 Gate 1—79，Plan SHA `55323dab888060b0214c00c81c43993af9b69c28a28939f84f34b569f0b78e85`；Manifest SHA `1be88a6b41e9e2154a4f59c85c30095767379f2c01ef3d9fada0fd363493e68c`；Worker SHA `675f5ad470fb26bc377731e1ba9e7380c9852d33b4200fdca0c72ac6f9a5d8bd`；Projector SHA `f9dc0a85ddc2861eb14645044aef8bcfa3f32c103558a29a65a53a3547cc0509`；Preflight Report SHA `38c434c83247180afe4051ea15e53f52ddccae4857473ae257ae852036f278ae`。

正式 Attempt 001 已消费且永久冻结。`execution-start.json` SHA 为 `dc7cf44a053fac2095ca6e1b29f72216b437f578bcf948f88ff53e6776c9deda`；Raw Result SHA 为 `fc7fea93e7e097892959b25493f51d7dd12239c3885880476217c60750f36736`；Summary SHA 为 `7579e862f42ecead8e78885c6b079b7e647a6d9b54bc6b8268ac5dae0446114b`。Summary 正式状态是 `RUNNER_BLOCKED`，`product_started_count=1`、`product_completed_count=0`、`product_pass_count=0`、`product_fail_count=0`，首 Runner 失败为 `PRODUCT_EXECUTOR_INVALID / product_executor_diagnostics_wrong_type`。

Raw Godot 日志说明产品进程确实退出 1，但不能据此证明 PR #90 产品代码回归：Acceptance Clone 没有 `.godot` 或 global class cache，首批所有“找不到类型”的 class_name 均在当前 Head 源码中真实声明。下一任务必须同时修复 Head-bound Import Cache provisioning 和 Raw diagnostics array cardinality，并在新的预检中证明无缓存 clone 会 fail closed、有效当前 Head 缓存会通过到可判定产品结果。当前 Godot/Worker/7576/7586 均为 0，Clone Head/Tree 未变且工作树干净；不授权自动运行新的产品 Attempt。
