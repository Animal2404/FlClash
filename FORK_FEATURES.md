# FlClash fork 改造说明：两项功能在哪里、上游更新后怎么快速跟上

> **给接手这个 fork 的任何人 / 任何 AI 会话：先读这一页，再动代码。**
>
> | 项 | 值 |
> | --- | --- |
> | 快照时间 | 2026-10-11 |
> | 上游 | `chen08209/FlClash` main = `4b59eca8`（v0.8.99，2026-10-03 发布） |
> | 本 fork | `Animal2404/FlClash` · 分支 `feat/pinned-nodes` = `b72429a3` |
> | 落后上游 | **0 个提交**（fork 基线就是上游 main 的最新提交） |
> | 已发布 | `v0.8.99-refresh.1`（仅刷新按钮）、`v0.8.99-pin.1`（刷新 + 置顶，累积） |

**结论先说**：上游更新**不会**让这两项功能消失——fork 的分支 / 提交 / tag / Release 都是你自己仓库的对象，上游 push 碰不到它们（GitHub 的 "Sync fork → Update branch" 只会快进 `main`，不碰 feature 分支；千万别用 "Discard commits"）。需要动手只有一种情况：**想跟上上游新版本**，那就照 §3 变基（已实测：两个提交 cherry-pick 到上游 main 上零冲突）。

---

## 0. 30 秒速查（先跑这几条）

```bash
cd <repo>                                   # 本机路径：E:\DeepSeek\zmb\flclash-refresh
git fetch upstream --tags                    # upstream = chen08209/FlClash（没配就先 git remote add upstream https://github.com/chen08209/FlClash.git）
git log --oneline -1 upstream/main           # 上游现在到哪
git log --oneline -3                         # 本地两个功能提交
git diff main --stat                         # 相对上游的全部差异（本 fork = 上游 + 这些）
git show --stat 50875d99                     # 功能一：仪表盘刷新按钮（3 个文件）
git show --stat b72429a3                     # 功能二：节点置顶（20 个文件）
```

两个功能的**代码锚点**（换行号也不用怕，按名字 grep 就能定位）：

```bash
grep -n  "_ServiceRefreshButton"          lib/views/dashboard/widgets/service_status.dart
grep -rn "pinnedProxies"                  lib arb test
grep -rn "togglePinnedProxy\|_ProxyPinMark" lib/views/proxies
grep -rn "\"pin\"\|\"unpin\"\|\"pinNodes\"" arb
```

---

## 1. 功能一：仪表盘「服务状态」卡片就地刷新按钮

- 提交：`50875d99` `feat(dashboard): refresh the shown service from its card`
- 位置：**代理/服务状态卡片**（仪表盘左列那张显示 Gemini/延迟 1789 ms 的卡）右侧数值列，延迟数字**上方**。
- 行为：点一下 = 对当前显示的节点/分组重新测速，**不打开二级窗口**；作用的是既有动作 `ServiceStatus.refresh([target])`（与二级窗口每行 ⟳ 完全相同）。

| 文件 | 改了什么 |
| --- | --- |
| `lib/views/dashboard/widgets/service_status.dart` | 新增 `_ServiceRefreshButton`（`IconButton` + `GlyphIcon(AppGlyphs.refresh)`，测速中换 `CommonCircleLoading` 并禁用）；`_ServiceAside` 增加 `refresh` 参数，把它放在延迟数值上方 |
| `test/views/dashboard/service_status_test.dart` | 新增 3 条聚焦测试；把「窄/宽尺寸」几何测试补到**最短卡片高度 288×80** |

**关键设计（别改回去）**：按钮放在 `_ServiceAside` 的纵向列里，**不占卡片横向宽度**。第一版做成横向尾部按钮时，仓库自带的窄卡片几何门禁（`test/views/dashboard/service_status_test.dart` 里 `fits one row at narrow and wide sizes in every locale`）真实报出 `RenderFlex overflowed`——标题行只剩 17.5px。

---

## 2. 功能二：代理界面「置顶节点」

- 提交：`b72429a3` `feat(proxies): pin nodes to the top of the list`
- 行为：代理页标题栏 **📌 按钮**（常驻，搜索与 ⋮ 之间）→ 按下进入**置顶模式**（图标变「保存」，每张卡片右上角出现角标）→ **点卡片**置顶/取消（置顶模式下点卡片**不切换节点**）→ 再按一下保存退出。置顶节点**排在所属分组列表最上方**（按置顶先后），分组切换/搜索过滤后依然置顶，写入应用设置持久化；分组标签页与列表两种布局都生效。

| 文件 | 关键符号 | 说明 |
| --- | --- | --- |
| `lib/models/config.dart` | `@Default([]) List<String> pinnedProxies` | 持久化字段（在 `AppSettingProps` 的 `serviceOrder`/`disabledServices` 旁边） |
| `lib/models/generated/config.freezed.dart`、`config.g.dart` | — | **生成文件**，改模型后重跑 build_runner |
| `lib/providers/state/proxies.dart` | `_pinnedFirst(...)`、`filterGroupsState` | 置顶排序的**唯一出口**（tab/list 两种布局共用；`proxyGroupSelectorState` 与仪表盘分组卡不受影响） |
| `lib/views/proxies/proxies.dart` | `_isPinning`、`_handleTogglePinning`、`actions: [FadeRotationScaleBox(IconButton(...))]` | 标题栏按钮。**用 `actions:`（widget）而不是 `iconActions:`（数据）**，否则会被 app bar 的折叠逻辑塞进 ⋮ 菜单 |
| `lib/views/proxies/card.dart` | `togglePinnedProxy()`、`_ProxyPinMark`、`ProxyCard.pinning` | 卡片右上角角标（`IconButton.filled` 已置顶 / `filledTonal` 未置顶，24×24，`Clip.none` 悬出角）；置顶模式下卡片 `onPressed` 改为切换置顶 |
| `lib/views/proxies/tab.dart`、`list.dart` | `pinning` 参数 | 把置顶模式从页面透传到两种布局的卡片 |
| `arb/intl_{en,zh_CN,ja,ru}.arb` + `lib/l10n/**` | `pin` / `unpin` / `pinNodes` | **四语言都要加**，然后重跑 intl 生成 |
| `test/views/proxies_pin_test.dart` | — | 4 条聚焦测试：排序、搜索后仍置顶、置顶-保存-取消、列表布局 |

---

## 3. 上游更新后，把两项功能快速搬过去（推荐 rebase）

```bash
git fetch upstream --tags
git log --oneline main..upstream/main                 # 上游新增了什么
git log -1 --format='%H %ad %s' upstream/main

# ① 先看上游有没有动到我们的热点文件（没有的话变基基本是自动的）
git diff --name-only main upstream/main | grep -E 'views/proxies|dashboard/widgets/service_status|models/config|arb/|l10n/'

# ② 变基（把两个提交重新落到上游最新之上）
git switch feat/pinned-nodes
git rebase upstream/main

# ③ 冲突处理规则（见下方"冲突热点"）
# ④ 重新生成 + 校验（关键：生成文件永远不要手工合并）
dart run build_runner build --delete-conflicting-outputs
dart run intl_utils:generate
dart format lib test
flutter analyze --no-fatal-infos
flutter test test/views/ test/l10n/ test/lint/

# ⑤ 推回去（历史被改写，必须强推，但要带 lease 防误覆盖）
git push --force-with-lease origin feat/pinned-nodes
```

**实测结论（2026-10-11）**：`git cherry-pick 50875d99 b72429a3` 到上游 `main` 之上**零冲突**，结果树与 `feat/pinned-nodes` 完全一致，且 `flutter analyze` 无问题——说明这两个提交是自洽的（生成文件也在提交里），**单独 cherry-pick 到任意新基线上都够用**。

**冲突热点（按概率排序）与处理**：

| 冲突文件 | 处理办法 |
| --- | --- |
| `lib/**/generated/*.dart`、`lib/l10n/**`、`lib/l10n/intl/**` | **别手工合并**：`git checkout --ours`/`--theirs` 随便留一个，解决源文件后重跑 build_runner + intl 生成，生成结果自然正确 |
| `arb/*.arb` | 保留上游改动，重新加回四语言的 `pin` / `unpin` / `pinNodes` |
| `lib/views/proxies/card.dart`、`proxies.dart`、`tab.dart`、`list.dart` | 上游改动 + 我方以 `pinnedProxies` / `pinning` / `_ProxyPinMark` / `_ServiceRefreshButton` 为锚点重新贴回，通常几行 |
| `lib/models/config.dart` | 只在 `AppSettingProps` 里加一行 `@Default([]) List<String> pinnedProxies,` |
| `lib/providers/state/proxies.dart` | `filterGroupsState` 里保留上游逻辑 + 包一层 `_pinnedFirst(...)` |
| `.github/workflows/fork-windows.yaml` | 新文件，不会冲突（上游没有同名文件） |

**备选方案**：不想改写历史就 `git merge upstream/main`（不用强推），代价是每次多一个 merge 提交。

---

## 4. 本地校验（踩过的坑都在这）

| 项 | 要求 |
| --- | --- |
| Flutter | **必须是 3.47.4**（CI 固定值）。本机 3.44.9 会因 `freezed 4.x` 要求 Dart ≥3.13 直接解析失败；本项目实测用 `E:\flutter-3474\flutter\bin\flutter.bat` |
| 变更模型/提供者 | 必须重跑 `dart run build_runner build --delete-conflicting-outputs` |
| 改文案 | 必须改 `arb/` 四个文件再 `dart run intl_utils:generate`；生成后**补跑 `dart format lib`**（生成器输出不是格式化结果） |
| 本地跑测试 | `flutter test` 会触发 Go/Rust 构建钩子。子模块 `core/Clash.Meta` 没克隆齐时，临时把 `pubspec.yaml` 的 `hooks.user_defines.setup.build_assets` 置 `false`（**绝不提交**），CI 的 checks job 也是这么干的 |
| `flutter test` 卡住不动 | `.dart_tool` 里残留了钩子失败留下的锁（`setup_build_cache/*.lock`、`hooks_runner/**/.lock`），进程会空转等锁而不是编译。停掉进程后 `find .dart_tool -name '*.lock' -type f -delete` 再跑（`fork-sync.sh` 已内置）。清锁后实测 31 秒跑完 |
| Windows 已知假阳性 | `test/lint/` 里 5 个用正斜杠比较路径的用例在 Windows 必挂（`design_package` / `dynamic_message_key` / `platform_layering` / `disposable_field` / `icon_button_tooltip`），**以 Linux CI 为准** |
| 测试字体陷阱 | 测试用 Flutter 测试字体（字形≈方块、文本宽近 2 倍），窄卡片几何门禁比真机苛刻得多；改动卡片布局时先跑 `flutter test test/views/dashboard/service_status_test.dart` |
| 角标要注意 | 代理页**没有** `DeferredPointerHandler`，角标别包 `DeferPointer`（会 assert）；改用整张卡片可点 + 角标显示状态 |

---

## 5. 云端编译与发布

- 工作流：`.github/workflows/fork-windows.yaml`（fork 专属，**新文件不会与上游冲突**）
  - 触发：推送到 `feat/**` 分支 / `v*-refresh*` tag / 手动
  - job 1 `Dart checks`（ubuntu）：pub get → `dart format --set-exit-if-changed lib test` → `flutter analyze --no-fatal-infos` →（跳过 Go 钩子）→ `flutter test test/views/ test/l10n/ test/lint/`
  - job 2 `Windows packages`（windows-2022 + Flutter 3.47.4）：`dart setup.dart windows --env stable -v` → 上传 `dist/`（`FlClash-0.8.99-windows-amd64-setup.exe` + `.zip`）+ 启动冒烟截图
- 上游自带 `build.yaml` 也会在 fork 上跑（全量测试 + 覆盖率门槛 + 三平台编译），**它全绿才算真稳**。
- 发 Release（`--target` 必须给**分支名**，给 SHA 会 422）：

```bash
gh run download <run-id> -R Animal2404/FlClash -D dist
gh release create v0.8.99-<后缀>.N -R Animal2404/FlClash \
  --target feat/pinned-nodes \
  --title "FlClash v0.8.99 + <本次内容>（个人 fork 构建）" \
  --notes-file notes.md \
  dist/flclash-windows-refresh/FlClash-0.8.99-windows-amd64-setup.exe \
  dist/flclash-windows-refresh/FlClash-0.8.99-windows-amd64.zip
```

- 发布后自查：`curl -sSIL <资产直链>` 应 `302 → 200` 且 `Content-Length` 与本地文件一致；Release 页 `200`。

---

## 6. 给下一个会话的最短路径（可直接粘的 prompt）

> 这个仓库是 FlClash 的个人 fork，相对上游只加了两项功能（仪表盘刷新按钮、代理界面节点置顶）。
> 先读仓库根目录的 `FORK_FEATURES.md`，再按 §0 的三条命令确认落点；
> 要跟上上游就按 §3 变基（生成文件不要手工合并，重跑 build_runner + intl_utils）；
> 要出包就推 `feat/**` 分支走 GitHub Actions，然后按 §5 发 Release。

自动化脚本：仓库根目录 `fork-sync.sh`（拉上游 → 变基 → 重新生成 → 格式/静态检查/测试，见脚本头部注释）。

---

## 7. 现状、分支与证据

| 项 | 位置 |
| --- | --- |
| fork 分支 | `feat/dashboard-quick-refresh`（功能一）、`feat/pinned-nodes`（功能二，**含功能一**，发布用这条） |
| Release | https://github.com/Animal2404/FlClash/releases （`v0.8.99-refresh.1`、`v0.8.99-pin.1`） |
| 代码差异补丁 | 会话工作区 `flclash-evidence/pin-patch.patch`（相对上游 main 的完整 diff） |
| 渲染证据 | `flclash-evidence/pin-shots/*.png`（代理页普通/置顶/浅色）、`card_*.png`（服务卡深浅色） |
| 上游同步 | `git remote add upstream https://github.com/chen08209/FlClash.git`（本机**已配好**） |
