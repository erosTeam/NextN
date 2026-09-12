# NextN CI OPEN: shared reader-kit CI 依赖（step 9 OHPM）

Status: OPEN - 已知项，不绕过，等待 device-acceptance 切片完成后再处置。

## 现象

GitHub Actions "Build OHOS"（.github/workflows/build.yml）在 step 9 "Install OHPM dependencies"
（ohpm install --all）失败：

    ohpm ERROR: 00608002 File Not Found
    Error Message: Missing file "oh-package.json5" in "/__w/NextN/reader-kit/reader-core".

- 首个被该点拦截的 run：34707625634（main @ ca699648，run #70，2026-09-13）。
- 此前 main 上所有 push 均先被 step 6 persistence inventory contract 拦截；
  ca699648 修复 inventory 后，该 OPEN 项成为新的失败点。
- 本地 contract 验证：node scripts/test_persistence_inventory_contract.mjs 通过。

## 根因

entry/oh-package.json5 与 feature/reader/oh-package.json5 通过 file: 依赖引用
@reader-kit/core、@reader-kit/ui（相对路径 ../../reader-kit/...）。reader-kit 是
独立本地 sibling 仓库 /Users/honjow/git/reader-kit，未跟踪进本仓库
（git ls-files reader-kit 为空；.gitmodules 仅有 third_party/reader-enhancement；
erosTeam/reader-kit 远程尚不存在，404）。CI 全新 clone 不含该 sibling 目录，
ohpm install 必然失败。

该依赖由 2026-09-06 的 ee9223c9（feat(reader): add optional shared reader D1 integration）
提交进 main，与本仓库 release 无关。NextE / Koma 的同类 file: 依赖未提交进各自 main，
故仅 NextN 的 CI 受影响。

## 决定（owner：共享阅读器重构进度任务）

选 C（长期）：reader-kit 保持独立仓库，三宿主（NextN / NextE / Koma）固定到
明确 revision 的 git submodule。

- 不选 A：CI 与真实发布编译面分叉。
- 不选 B：会让三端共享实现重新漂移。
- D（ohpm 包）暂不作为第一步。

前置约束：

1. reader-kit 当前有在验证中的共享阅读器改动；完成当前设备验收切片之前，
   不改动 NextN 的依赖接线，也不做 vendor。
2. 建立远程仓库属于外部资源创建，需待可用的 repo / 权限明确后再落 submodule。
3. 在此之前，不为了 CI 绿灯绕过该依赖（例如从 CI 编译面剥离 reader-kit 接线）。

## 判定口径

- NextN 出现只停在 step 9 OHPM 的 run（step 1–8 全过）视为"预期内红"，
  不作为回归处理，不要求本仓库主动修复。
- 该 run 的 Publish 等后续 step 的结论不参与验收判定。
- 其余 step（合同检查、构建、产物检查）出现新的失败不属于本 OPEN 项，需另行处理。
