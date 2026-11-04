# 拾光清单

一个用 Flutter Material 3 编写的中文 Android 待办应用，离线可用，无需账号。

## 功能

- 新建、编辑、删除任务，删除后立即撤销
- 完成任务和恢复待办，完成记录独立查看
- 标题、备注、截止日期、普通／重要／紧急优先级
- 生活、工作、学习、收集箱四个清单
- 今天（含逾期）、计划（有日期）、全部三个视图
- 按标题和备注搜索，按日期、优先级、最近添加排序
- 今日完成进度、逾期标识、跟随系统深浅色主题
- Hive 本地持久化，日期跨天和从后台恢复时自动刷新

截止日期为日期级安排，**1.0 不发送系统通知**。暂不包含账号同步、重复任务、子任务和附件。
数据仅在应用私有目录保存，卸载或清除数据会删除任务。

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

每条任务保存 `schemaVersion: 1`。未来变更须添加显式迁移；未知版本会报错并保留原数据，不自动重置。

## 开发

以 `pubspec.yaml`、`pubspec.lock` 和实际构建记录为准。安装 Flutter 稳定版、JDK 21、Android SDK 后：

```powershell
flutter pub get
dart format .
flutter analyze
flutter test test/data/todo_repository_test.dart test/features/todo/state/todo_state_test.dart test/features/todo/ui/home_screen_test.dart
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

本次验证结果与 APK 摘要见 [验证记录](docs/VALIDATION.md)。源码提交后可运行 `pwsh -File scripts/publish.ps1 -Tag v1.0.0` 推送并发布 APK；使用 Git Credential Manager 的现有 GitHub 登录，凭据不会写入源码或日志。

## 功能参考

参考 [Todoist](https://www.todoist.com/help/todoist/features) 和 [TickTick](https://ticktick.com/features?language=en_us) 的任务、日期、优先级与清单功能，界面和实现为本项目独立编写。
