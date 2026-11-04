# 快捷指令：经典 App Intents

闪印（Flash，`com.wehack.PrintableCheckList`）在 iOS 17 上提供经典 App Intents，给可打印的打包清单用。这些动作出现在「快捷指令」里，也可以用当前的 Siri 短语唤起。它们不是提醒事项，也不是通用待办。

部署目标保持 iOS 17.0。本阶段不使用 iOS 27.3 的 Siri AI `@AppIntent(.tool)` / skills。

## 动作

| 快捷指令动作 | 行为 |
| --- | --- |
| List Packing Checklists | 列出这台设备上的打包清单 |
| List Packing Items | 列出某一份打包清单里的物品 |
| Show Packing Checklist | 打开 App，进入该清单 |
| Create Packing Checklist | 按名称新建打包清单，物品可以留空，或按一行一个填写 |
| Add Packing Items | 向一份已有打包清单追加物品 |
| Export Print-Ready PDF | 返回与预览相同的打印就绪 PDF 文件 |
| Show Print Preview | 打开 App，进入该清单的打印预览 |

导出 PDF 不会在后台调用 `UIPrintInteractionController`。快捷指令拿到的是 PDF 文件，可以再接到「共享」或「存储文件」。需要系统打印面板时，用「打开打印预览」，在预览页里导出或打印。清单超过两页时导出失败，并提示缩短、删除或拆分，不会悄悄截断。

没有提醒、通知、截止日期、完成状态、通用待办，也没有通过 Siri 触发生成或内购。否定短语（Remind me / Add a reminder / Add a todo / Set a notification）明确不指向本 App。

## 在快捷指令里测试

1. 用 Xcode 把 App 装到 iOS 17 或更高的模拟器或真机，并至少打开一次，让系统索引快捷指令。
2. 打开「快捷指令」，在动作库搜索 Flash，或搜索 Packing / 打包。
3. 新建快捷指令，加入「Create Packing Checklist」，名称填 `Seaside packing`，物品填两行，运行后回 App 能看到这份清单。
4. 加入「Add Packing Items」，选择刚创建的清单，再追加一行物品。
5. 加入「Export Print-Ready PDF」。运行后的输出应是 PDF。可以再接「存储文件」或「共享」。不要预期它自己弹出系统打印面板。
6. 加入「Show Print Preview」或「Show Packing Checklist」。运行后 App 应来到前台，并打开对应清单或打印预览。
7. 对一份长到超过两页的清单运行导出，应看到放不下的错误，而不是一份缺项的 PDF。

Siri 短语必须包含 App 名称。当前显示名是 Flash；短语里的应用名由系统替换。简体中文文案在 `zh-Hans.lproj/AppShortcuts.strings`。

英文短语示例：

- “Create a packing checklist in Flash”
- “Make a printable packing list in Flash”
- “Add packing items in Flash”
- “Add items to a printable checklist in Flash”
- “Show a packing checklist in Flash”
- “Export a printable packing list from Flash”
- “Open the print preview in Flash”
- “List my packing checklists in Flash”

对应的中文说法是「在 Flash 新建打包清单」「在 Flash 添加打包物品」「在 Flash 打开打包清单」「从 Flash 导出可打印打包清单」「在 Flash 打开打印预览」「在 Flash 列出我的打包清单」。

## 延后的 Siri AI（iOS 27.3）

`PrintableCheckList/Intents/SiriAIIntentExtensionPoint.swift` 记下了下一阶段的接入点。等采用 iOS 27.3 SDK 之后，用 `@available(iOS 27.3, *)` 给现有的打包清单意图补 assistant tool / skills 元数据，不要再做一套清单模型。

这一阶段明确不做：

- `@AppIntent(.tool)` 与 skills
- 通过 Siri 调用 AI 生成或补漏
- 通过 Siri 发起 Pro 内购
- 把部署目标抬到 27.3
