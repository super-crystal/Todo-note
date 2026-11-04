# 拾光清单 1.2.0 验证记录

日期：2026-11-04。

## 构建产物

- Flutter 3.47.9 stable / Dart 3.13.7；JDK 21.0.9、Gradle 9.3.1、Android Gradle Plugin 9.1.0
- Android SDK 36 / NDK 28.2.13676358
- 包名：`cn.shiguang.shiguang_todo`，版本：`1.2.0+3`
- 最低 Android API 24，目标 API 36；通用 arm64-v8a / armeabi-v7a / x86_64 APK
- 原发布签名，APK Signature Scheme v2 验证通过，可覆盖升级
- 文件：`output/shiguang-todo-1.2.0.apk`
- 大小：56467728 字节
- SHA-256：e7bff011aa10cda09112d3db76047fe9f33357ee5c2aad87b86911c98a3da9ef

## 自动检查

`dart format .` 已执行，`flutter analyze` 无问题；本次相关的 20 项测试通过。

- 旧记录缺少时间/提醒字段时按 `false` 读取，原日期保留
- 精确时间持久化、时间级逾期和完成后的逾期判断
- 区分通知权限和准点权限，普通状态查询不发起授权请求
- 新增、改期、完成、恢复待办、删除、撤销及移除时间后的提醒快照同步
- 拒绝新设过去时间的提醒，保持已保存任务不变
- 日历日期、标签、范围、分类、优先级和状态查询的相关回归用例
- 全部页状态按钮选中背景与动画，点击搜索展开新页面
- 搜索页关键词/标签组合、筛选、重置、清空和键盘收起

## Android 运行验证

在独立 Android 16（API 36）x86_64 模拟器使用发布签名 APK 验证：

- 从 1.1.0 覆盖升级，原有标题、备注、日期、完成状态和标签保留，旧任务不自动开启提醒
- 系统时间选择器支持 24 小时输入，保存后任务卡片显示时分与提醒图标
- 首次出现通知权限弹窗，准点权限未授权时显示提示并可跳转“闹钟和提醒”设置
- 授权后，`dumpsys alarm` 显示 `RTC_WAKEUP`、`window=0`、`exactAllowReason=permission`
- 应用退到后台，实际在设定时间收到标题为 `Reminder_QA` 的系统通知；通知记录的投递时间约为截止时间后 253 毫秒（单次模拟器观察，不代表设备时延保证）
- 终止后台应用进程后点击通知，冷启动直接打开对应任务编辑详情，日期、时间及提醒状态正确
- 已投递任务改期后只保留一个未来闹钟，新时间正确
- 完成任务后有效闹钟数从 1 变为 0，恢复待办后为 1
- 删除后有效闹钟数为 0，撤销删除后为 1
- 重启模拟器后，在再次打开应用前有效闹钟数已恢复为 1，时间与改期结果一致
- 搜索页可组合关键词和标签，筛选入口只在展开页面内；未设日期筛选结果正确
- 应用筛选后系统输入法 `mInputShown=false`，按钮保留“筛选任务”无障碍名称

测试样例仅保存在专用模拟器，未打包到 APK。未进行实体手机、所有 Android 版本、厂商省电策略和长时间闲置的兼容性实测。系统强制停止后需重新打开应用，勿扰模式及通知设置由用户控制。

## 实现依据

- [Android 闹钟与重启恢复](https://developer.android.com/develop/background-work/services/alarms)
- [Android 通知权限](https://developer.android.com/develop/ui/compose/notifications/notification-permission)
- [Flutter SearchAnchor 搜索过渡](https://api.flutter.dev/flutter/material/SearchAnchor-class.html)
