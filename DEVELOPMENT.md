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

1.2 新增可选 `hasDueTime`、`reminderEnabled` 布尔字段，旧记录缺失字段时均为 `false`。日期仍保存本地 ISO 字符串，具体时间保留到分钟，日期级任务不会变成零点提醒。日历与日期范围筛选仍按天比较，有具体时间的任务按时分排序及判断逾期。

Android 通知使用原生 `AlarmManager`、`BroadcastReceiver`、`NotificationManager`，通过 MethodChannel 与状态层连接，无新增包。Hive 为任务的唯一来源；状态层串行同步有效提醒快照，原生 SharedPreferences 仅保留系统重启恢复所需的提醒和已投递标记。完成、删除、移除时间或关闭提醒会取消系统闹钟及已有通知；撤销删除恢复提醒。每条任务的 PendingIntent URI 唯一，通知使用任务 ID 作 tag，避免 ID 哈希碰撞。

首次设置具体时间时默认开启提醒并按需请求通知权限；Android 12+ 检查准点权限，缺失时使用允许闲置的非精确闹钟并显示设置入口。启动、恢复前台、系统重启、应用覆盖更新、时钟或时区变化及准点权限授予后重新安排；按手机本地时区解释墙上时间。已到期且未投递的提醒恢复后补发一次，已投递记录避免重复。通知点击通过任务 ID 打开编辑详情。系统强制停止、勿扰和厂商省电限制仍受 Android 控制。

## 开发

以 `pubspec.yaml`、`pubspec.lock` 和实际构建记录为准。安装 Flutter 稳定版、JDK 21、Android SDK 后：

```powershell
flutter pub get
dart format .
flutter analyze
flutter test test/data/todo_repository_test.dart test/data/task_tags_test.dart test/features/todo/state/todo_state_test.dart test/features/todo/state/calendar_state_test.dart test/features/todo/state/task_search_test.dart test/features/todo/state/reminder_service_test.dart test/features/todo/ui/home_screen_test.dart
flutter run
```

若 Windows 上 Java 报 `Unable to establish loopback connection`，且异常指向 `UnixDomainSockets.connect`，可在当前构建终端设置 `$env:JAVA_TOOL_OPTIONS='-Djdk.net.unixdomain.tmpdir=E:/Todoapp/.tools/no-unix-sockets'`。该目录须不存在，让 Java 自动使用 TCP 管道，避免受本机 Unix socket 故障影响。此设置只影响构建工具。

## APK 构建

```powershell
pwsh -ExecutionPolicy Bypass -File scripts/build.ps1
```

脚本首次创建本地发布签名，保存在 `.signing/` 和 `android/key.properties`；它们已被 Git 忽略。请妥善保管签名以便以后覆盖升级。使用新签名安装到已有应用上可能需要卸载，卸载会删除数据。

Android 沿用 Flutter 稳定版模板的 SDK / NDK / Gradle 版本。Gradle 使用官方直连的二进制发行包并固定 SHA-256，以减少首次下载和避免跳转连接故障。JVM 最大堆为 3 GB，便于与模拟器同时运行。

构建成功后仅在 `output/shiguang-todo-1.2.0.apk` 保留当前交付版本，文件名自动读取 `pubspec.yaml` 的版本；复制成功后清理旧的本地 APK。上传到 GitHub 的文件名同样包含版本号。标准 Flutter `build/` 为忽略的构建缓存，不作为版本归档。GitHub Release 保存历史版本。

本次验证结果与 APK 摘要见 [验证记录](docs/VALIDATION.md)。源码提交后可运行 `pwsh -File scripts/publish.ps1` 推送并发布 APK，标签自动与应用版本一致；使用 Git Credential Manager 的现有 GitHub 登录，凭据不会写入源码或日志。上传校验大小和 SHA-256，通过后发布草稿。
