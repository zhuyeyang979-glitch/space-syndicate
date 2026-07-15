# 下一阶段执行 Prompt：全仓回归恢复 v1

> 基线：`origin/main@6b23a31`
> 策略：本地优先、独立 worktree、原子提交、阶段性同步。
> 禁令：不得为旧测试恢复退役 Main wrapper、第二状态 owner、私密快照或 v0.4/v0.5 兼容农场。

## Codex A / 协调者

目标：恢复完整 `smoke_test.gd` 的第一段现役运行链。先删除测试对 Main `product_market` Dictionary 形状的依赖，改为消费现役 ProductMarket owner 或 owner-focused fixture；不得改价格、商品、天气、存档或 AI 规则。阻塞式运行完整 smoke，定位并只处理下一个有明确 owner 接管证据的陈旧断言。记录每个红灯属于测试迁移还是生产 bug；任何生产修改必须有独立复现。

验收：

- `smoke_test.gd` 不再在旧 `product_market` 强转处崩溃；
- 旧 Main shape 引用物理删除，不增加兼容 API；
- ProductMarket focused gate、Godot engine `--check-only`、`git diff --check` 通过；
- 每次测试真实等待退出，超时只回收本工作树子进程，headless 余量为 0。

## Codex B / Monster Codex 公共数据源

唯一工作树：`space-syndicate-b-next`。把 Monster Codex 的 browser/detail 来源迁到
scene-owned SourceService + 纯数据 allowlist Adapter，并由 Monster owner 暴露窄 public
catalog API。物理删除 Main 的旧 Monster Codex 构造簇；禁止读取 roster、私有目标权重、
RNG、玩家现金/手牌/归属、市场报价、镜头或存档。只做本地原子提交，不 push。

## Codex C / Monster Codex 独立验收

唯一工作树：`space-syndicate-c-next`。先建立 production-independent acceptance 红灯，覆盖
跨 viewer 私密状态不变性、递归 sentinel、严格公开白名单、scene 唯一性、旧 Main helper
退役及合法公开变化正例。C 不修改 production；当前生产缺口必须表现为有限、可复现的红灯。

## Codex D / 回归与测试基础设施

唯一工作树：`space-syndicate-d`。维护 Godot 4.7 阻塞式 runner、真实 ExitCode、逐项 timeout、
仓库外日志和本 worktree 进程清理；随后按现役 owner gate 原子退役历史 smoke/layout oracle。
禁止恢复 Main wrapper 或第二状态 owner。

## Codex E / 视觉与有头验收

唯一工作树：`space-syndicate-e`。用真实 `main.tscn` 完成 1280x720、1600x960、
1920x1080 的 MapView、天气、区域详情、经济总览、手牌与 RightInspector 截图矩阵。
只修公开 ViewModel 到 UI 的展示问题，不改规则、经济、AI、怪兽、天气 owner 或存档。

## Team Layout Worker

唯一写入范围：`tests/layout_scene_smoke_test.gd` 的 CityDevelopment 历史簇。用现役 owner 与 focused gate 替换旧 Main/scene composition oracle；不改 production 或其他失败组。完整 layout 前后对比，提交本地 SHA，不 push。

## Team Runner Worker

唯一写入范围：`tools/` 下阻塞式 Godot 4.7 PowerShell runner、独立说明与自测。必须使用非 console 主可执行文件、逐项 timeout、真实 ExitCode、独立日志、机器可读结果，并且只清理自己创建的进程树。不得改游戏或测试语义。

## Team Smoke Auditor

只读映射 full smoke 在 ProductMarket 之后最早的五个 Main shape/wrapper 阻塞：测试行、生产 owner、现有 focused gate、隐私/存档风险和最小迁移方案。不得运行 Godot或编辑文件。

## Team Layout Auditor

只读把当前 59 个 layout 红灯按 CityDevelopment、Save、Economy、Military、Victory、TableSnapshot/RightInspector、MCP/config 和其他分组，给出精确测试行、现役 owner gate、退役可行性与优先级。不得与 Layout Worker 重复实现。

## 集成纪律

1. 每个写入任务使用独立 worktree 和分支，不直接改协调者工作树。
2. 两个 worker 只做本地 commit，不 push；协调者审查 SHA 后再 cherry-pick。
3. 共享文件一次只允许一名 owner 修改；发生冲突立即停止并报告。
4. 所有 Godot 调用串行，禁止使用会提前返回的 console wrapper 作为默认 runner。
5. 完整 layout/smoke 的历史红灯必须如实报告，不能用放宽断言或恢复旧接口换绿。
