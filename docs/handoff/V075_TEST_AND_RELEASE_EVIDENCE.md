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
| 新 Head Acceptance Clone | PASS | exact Head/Tree；clean；Windows long-path enabled |
| 新 Head Canonical Import | NOT_RUN | pre-product Manifest blocker 前未消耗 |
| 新 Head Formal Gate 1—79 | NOT_STARTED | execution count 0；Godot starts 0 |
| 79/79 Aggregate | NOT_RUN | 阻塞 |
| Review/MCP/Viewport/Headless/2,000 | NOT_RUN | 阻塞 |
| PR merge/tag | NOT_RUN | 阻塞 |

旧 Head Gate 16 的四项失败均属于 submission rollback/exact-once 产品断言。修复恢复最小 Combat Owner 的既有 fallback，没有改变真实 typed Owner 路径、规则、数值、测试或 Canonical Manifest。

新 Head pre-product blocker：Revision 002 Worker SHA `dbb27a69d4c94d27f437d4dd12b4910f4ff363c3cfa9139539d2c6341415259d` 的 Manifest 无条件要求同 Head Gate 1 reuse。新 Head 没有可合法复用的 Raw Gate 1 Result，且完整计划必须新跑 Gate 1。Blocker Evidence SHA `ba70bec044b245338f94c6efd5eb04664ee8adc3708cf393713a56c95339b7df`。

只读穷尽审计进一步证明不存在可直接使用的密封入口：Revision 001/002 都有无条件 Gate 1 reuse 合同，旧 full-range Worker 则缺失 plan-bound 首记账与 Product Executor／Evidence Projector 解耦。Exhaustion Audit SHA `17500b45a0c5362fe425d2666cebd68595c947f462bdb23a47ce39b7df`，状态 `NO_AUTHORIZED_EXISTING_ENTRYPOINT`。

当前 Godot/Worker/7576/7586 均为 0。必须先获得一次明确的 post-repair Tooling Revision 授权；预检完成后再单独请求一次完整 1—79 产品 Attempt 授权。
