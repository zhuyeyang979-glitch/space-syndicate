# 下一阶段执行 Prompt：公共图鉴与真实 1280 可玩性 v2

> 基线：本阶段推送后的 `origin/main`，开工前必须记录精确 SHA。
> 策略：本地优先、独立 worktree、原子提交、协调者阶段性同步。
> 禁令：不得为旧测试恢复退役 Main wrapper、第二状态 owner、私密快照或 v0.4/v0.5 兼容农场。

## Codex A / 协调与集成

目标：保持 `main.gd` 继续净删，并把 B/C/D/E 的下一批原子块按依赖顺序集成。A 不与成员并行编辑其所有文件；只负责候选审查、冲突处理、统一 focused 回归、真实红灯分类和阶段性推送。

验收：

- `main.gd` 相对本阶段基线继续净删行与函数，不增加算法 wrapper；
- 每个生产切片同时有公开数据边界、隐私负向门和旧入口零引用门；
- 使用 `tools/invoke_godot_test.ps1 -RefreshImport` 刷新新增 `class_name`，之后串行运行；
- 完整 layout/smoke 即使仍红，也必须记录首个失败、超时、真实 ExitCode和残留进程 0。

## Codex B / Product Codex 公共数据源 sceneization

在新的 B 独立 worktree 上，从本阶段 `origin/main` 开工。先复核 Product Codex 生产调用图，再实现纯数据 allowlist Adapter + scene-owned SourceService + Coordinator 薄代理，物理删除 Main 中只属于 Product Codex browser/detail 的拼装簇。`_product_strategy_scores`、AI、商品经济、市场、仓库、怪兽、天气、存档和私密线索不属于本切片；若无法在不复制这些 owner 的前提下删除，立即缩小范围而不是建 wrapper。

必须证明：跨 viewer 的现金、手牌/弃牌、隐藏 owner、城市猜测、AI 计划变化不改变公开图鉴；合法公开商品目录变化会改变对应字段；旧 Main Product Codex helper 可执行引用为 0；真实 CodexCompendiumSurface browser/detail 有头通过。只做本地 commit，不直接 push。

## Codex C / smoke 角色图鉴与存档 wrapper 退役

在新的 C 独立 worktree 上，以完整 smoke 当前首个失败“角色图鉴公开机械收益”为入口，先写 production-independent focused fixture，判断是陈旧 oracle 还是生产缺口。随后只迁移第一个有明确 owner 接管证据的 `_capture_run_state` 区块；禁止恢复 `_capture_run_state`、`_apply_run_state` 或私密全局快照。

必须输出：精确测试行、owner/fixture 映射、隐私与存档风险、旧 wrapper 调用净减少数量、focused 门和完整 smoke 向前推进证据。没有点对点 owner gate 的区块保持红灯，不凭相似功能删除。

## Codex D / Military layout 解析与历史 oracle 分类

在新的 D 独立 worktree 上，先复现 `military_runtime_characterization_bench.gd` 的 `first/second/observed/pressure` 类型推断错误，以及 layout 对已删除 `calculate_city_gdp`、`characterization_cases` 的调用。只修 bench/test 迁移，不改 Military 规则或 Coordinator 生产 API；以现役 owner gate 替代陈旧接口。

随后重新运行完整 layout，按真实 UI 越界、历史 oracle、脚本解析和配置问题重新分类。TopBar、PlayerBoard、HandRack、MainActionDock 的 1280x720 越界必须保留为产品红灯。继续维护阻塞 runner 的冷/暖/陈旧缓存自测，不关闭其他 worktree 的编辑器。

## Codex E / 1280 主桌密度与地图可读性

在新的 E 独立 worktree 上，只处理真实 `main.tscn` 的 1280x720 可玩性：TopBar、PlayerBoard、HandRack、MainActionDock 必须完整入屏；地图区域名、路线节点、天气卡和怪兽 token 采用层级化降噪，使选中对象仍清晰。不得删除地图边界、路线或天气解释，也不得用隐藏整个系统换绿。

先提交 current/before 截图和 scene-tree 红灯，再做最小 UI 修复；复跑 1280x720、1600x960、1920x1080 以及 forecast/active/dual-active。保持 QA save 隔离、默认存档 hash 不变、机器 ID 0、console error 0。经济总览滚动位置复用另设可复现门，未复现不得宣称修复。

## 集成纪律

1. A/B/C/D/E 各自只使用自己的 worktree；共享文件一次只允许一名 owner 修改。
2. 成员只做本地原子提交并回 SHA；协调者审查、cherry-pick、统一回归后再阶段性推送 `main`。
3. 新 worktree 第一次 Godot 运行使用 GUI 4.7 主可执行文件和 runner 的 `-RefreshImport`；不得使用 `_console.exe` 作为默认 runner。
4. 测试必须阻塞等待真实进程退出，日志写仓库外，只清理同一 exe + 绝对 project path 的运行进程。
5. 旧测试只能在现役 owner 有等价门时退役；真实 1280 越界、隐私泄漏和生产错误不得通过放宽断言消失。
