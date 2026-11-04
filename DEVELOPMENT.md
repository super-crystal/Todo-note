# 开发与本地构建

本文件包含拾光清单的开发环境、项目结构、本地构建和发布说明。应用介绍与功能见 [README](README.md)。

## 技术和目录

Flutter 3.47.9（稳定版）/ Dart 3.13.7、Riverpod、Hive。`path_provider` 用于定位私有数据目录，`flutter_localizations` 提供中文系统组件。依赖版本保存在 `pubspec.lock`。

```
lib/core/                主题、文案与间距
lib/data/                不可变模型与 Hive 仓库
lib/features/todo/state/ 状态与筛选排序规则
lib/features/todo/ui/    页面、编辑器与任务卡片
test/                    对应业务测试
scripts/                 本地构建脚本
```

每条任务保存 `schemaVersion: 1`。1.1 新增可选的 `tags` 字符串数组，读取旧记录时缺失字段按空标签处理；已有标题、备注、日期和完成状态保持不变，后续保存时写入新字段，无需清空 Hive 数据。标签去重、数量和长度校验统一由数据层处理。未来不兼容变更须添加显式迁移；未知版本会报错并保留原数据，不自动重置。

## 开发

以 `pubspec.yaml`、`pubspec.lock` 和实际构建记录为准。安装 Flutter 稳定版、JDK 21、Android SDK 后：

```powershell
flutter pub get
dart format .
flutter analyze
flutter test test/data/todo_repository_test.dart test/data/task_tags_test.dart test/features/todo/state/todo_state_test.dart test/features/todo/state/calendar_state_test.dart test/features/todo/state/task_search_test.dart test/features/todo/ui/home_screen_test.dart
flutter run
```

若 Windows 上 Java 报 `Unable to establish loopback connection`，且异常指向 `UnixDomainSockets.connect`，可在当前构建终端设置 `$env:JAVA_TOOL_OPTIONS='-Djdk.net.unixdomain.tmpdir=E:/Todoapp/.tools/no-unix-sockets'`。该目录须不存在，让 Java 自动使用 TCP 管道，避免受本机 Unix socket 故障影响。此设置只影响构建工具。

## APK 构建

```powershell
pwsh -ExecutionPolicy Bypass -File scripts/build.ps1
```

脚本首次创建本地发布签名，保存在 `.signing/` 和 `android/key.properties`；它们已被 Git 忽略。请妥善保管签名以便以后覆盖升级。使用新签名安装到已有应用上可能需要卸载，卸载会删除数据。

Android 沿用 Flutter 稳定版模板的 SDK / NDK / Gradle 版本。Gradle 使用官方直连的二进制发行包并固定 SHA-256，以减少首次下载和避免跳转连接故障。JVM 最大堆为 3 GB，便于与模拟器同时运行。

构建成功后仅在 `output/shiguang-todo-latest.apk` 保留当前交付版本。标准 Flutter `build/` 为忽略的构建缓存，不作为版本归档。GitHub Release 保存历史版本。

本次验证结果与 APK 摘要见 [验证记录](docs/VALIDATION.md)。源码提交后可运行 `pwsh -File scripts/publish.ps1 -Tag v1.1.0` 推送并发布 APK；使用 Git Credential Manager 的现有 GitHub 登录，凭据不会写入源码或日志。
