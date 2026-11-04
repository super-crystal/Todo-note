# 拾光清单 1.3.0 验证记录

日期：2026-11-04。

## 构建产物

- Flutter 3.47.9 stable / Dart 3.13.7；JDK 21.0.9、Gradle 9.3.1、Android Gradle Plugin 9.1.0
- Android SDK 36 / NDK 28.2.13676358
- 包名 `cn.shiguang.shiguang_todo`；版本 `1.3.0+4`
- 最低 API 24，目标 API 36；通用 arm64-v8a / armeabi-v7a / x86_64
- 原发布签名，APK v2 签名验证通过；证书 SHA-256 为 `8814edd30214ddd7cdc30d566ab0b703387b4089b5ba3309ee2809d1f79c61ae`
- 文件 `output/shiguang-todo-1.3.0.apk`
- 大小 56500700 字节
- SHA-256 `a4b1d0b5eb422b16f40cd9b9c336221c018beec85e4ef1ebf3021ea507eee636`

## 已完成的检查

已执行 `dart format .`，`flutter analyze` 无问题。

26 项相关 Flutter 测试通过，涵盖：

- 老记录缺失提前时长、每日模式和完成日期字段时使用兼容默认值
- 自定义提前天／小时／分钟的组合、分量和总时长边界
- 新设提前提醒时拒绝已过去的触发时间，保存／改期保留提醒配置
- 每日完成日期持久化和不可变性、同一天撤销、第二天自动恢复、历史日期互不影响
- 每日任务当天完成后仍保留用于后续日期的提醒配置，并同步完成日期供系统跳过
- 今日展示未来截止、逾期、长期与每日任务，排除历史完成项和未开始的每日任务；进度计算一致
- 计划月历的每日圆点、开始日期边界及按所选日期筛选完成状态
- 编辑器“长期”和“每天重复”切换，保存后今日展示及完成行为
- 自定义提醒对话框校验、保存、取消保留原值和常用提前 1 天选项
- 日历、存储、标签和组合搜索的相关回归检查

`pwsh -File scripts/test-reminder-timing.ps1` 通过 3 项原生检查，直接编译执行 APK 使用的 `ReminderTiming.java`，无需新依赖：

1. 截止前 1 天和自定义 1 天 2 小时 30 分钟，跨年减算正确。
2. 每日提醒跳过已完成和已投递日期，尊重未来开始日期，今天已过时间时安排下一天。
3. America/New_York 夏令时前进时保持每日 09:00，跨日实际间隔为 23 小时。

正式 release APK 构建、包名／版本检查、签名验证通过。PowerShell 构建、原生检查和发布脚本语法检查通过。

## 本次运行验证限制

专用 Android 16 模拟器多次启动失败，Windows WHPX 返回 `Failed to setup partition, hr=80070005`；关闭硬件加速的软件模式也退出，ADB 未出现可用设备。因此本版本未进行 Android 实际安装运行、覆盖升级、系统通知显示、后台逐日续排、重启恢复或运行日志验证。上一版本已有的通知实测不能代替本次验证。

Flutter Widget 测试已运行应用和相关编辑／搜索界面，无测试捕获的布局或运行异常；这不代表 Android 系统服务已经实测。旧数据兼容由模型和仓库用例验证，签名一致已静态核对；实体手机、厂商省电和权限变化下的表现仍需实际设备验证。

## 实现依据

- [Android 闹钟、重复精度限制与重启恢复](https://developer.android.com/develop/background-work/services/alarms)
- [Android 通知权限](https://developer.android.com/develop/ui/compose/notifications/notification-permission)
