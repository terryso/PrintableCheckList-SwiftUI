# PrintableCheckList：AI 驱动的可打印清单

<p align="center">
  <img src="PrintableCheckList/Resources/Assets.xcassets/AppIcon.appiconset/pcl@1024.png" width="128" alt="PrintableCheckList app icon">
</p>

<p align="center">
  <strong>说出一个主题，让 AI 帮你生成、补充和查证清单，然后直接预览或打印。</strong>
</p>

PrintableCheckList 是“闪印”的开源 SwiftUI 项目。无论是旅行准备、采购计划、工作流程，还是电影排行等资料型列表，用户都可以用自然语言描述需求，由 AI 生成结构化清单；结果仍可像普通清单一样编辑、排序、预览和打印。

AI 是提高录入效率的可选能力，而不是使用门槛。所有手工创建、批量粘贴、iCloud 同步和打印功能均可独立使用。

## 用 AI 创建一份清单

1. 输入主题和具体要求，例如“生成一份带孩子去北海道冬季旅行的 20 项清单”。
2. App 根据需要直接生成，或使用 GLM / OpenAI 联网搜索最新资料后再整理。
3. 在保存前检查 AI 结果，按需修改标题、增删项目或重新生成。
4. 保存到本地，继续编辑、补充、预览或打印。

AI 也可以补充已有清单，不必为了漏掉的项目重新创建一份。对于“当前全球票房排行”“最近发布的产品”等时效性主题，可开启自动或始终联网搜索，并在结果页查看参考来源。

## 功能

- 创建、重命名、删除和排序多份清单
- 一次粘贴多行文本，批量添加清单项
- 使用自己的 GLM、OpenAI、DeepSeek 或兼容服务 API Key，通过 AI 生成新清单或补充已有清单
- 使用 GLM 或 OpenAI 联网搜索时效性资料，并展示参考来源
- 编辑、删除和拖动排序清单项
- 生成带勾选框的打印预览
- 使用系统打印控制器直接打印
- 通过 iCloud 键值存储在同一 Apple ID 的设备之间同步
- 支持简体中文和英文
- 支持深色模式、动态字体和 VoiceOver
- 可选的 Supabase 产品统计，只有在用户明确同意后才会上传
- 兼容导入旧版应用保存在本地或 iCloud 中的清单数据

## AI 服务商与联网搜索

用户可以在“设置 → AI 清单生成”中填写自己的模型服务配置：

| 服务商 | AI 生成 | 联网搜索 | 默认 Base URL |
|---|---:|---:|---|
| GLM | ✓ | ✓，使用 GLM Web Search API | `https://open.bigmodel.cn/api/paas/v4` |
| OpenAI | ✓ | ✓，使用 Responses API 的 Web Search | `https://api.openai.com/v1` |
| DeepSeek | ✓ | — | `https://api.deepseek.com` |
| 自定义 OpenAI 兼容服务 | ✓ | — | 用户配置 |

AI 生成统一使用 OpenAI 兼容的 `/chat/completions` 接口。联网搜索并不是所有兼容模型的标准能力，因此目前只对 GLM 和 OpenAI 开放；DeepSeek 和自定义服务仍可正常生成清单。

联网搜索提供三种模式：

- **自动**：识别票房、排行、新闻、天气、价格等可能需要最新信息的主题，仅在必要时搜索。
- **始终搜索**：每次生成前都搜索资料。
- **关闭**：只使用模型已有知识生成清单。

搜索失败时，用户可以重试，或选择不搜索并继续生成。搜索来源只用于本次结果的核对，不会作为清单项保存。

### 自定义提示词

AI 配置页会根据 App 语言显示中文或英文默认提示词，用户可以在本设备上微调或恢复默认。内置提示词会区分待办清单和排行榜、目录、资料列表等内容类型，显式数量要求会优先于默认项目数量。App 还会附加不可编辑的 JSON 返回格式和安全约束，以保证结果能够被稳定解析。

### BYOK 与隐私边界

本项目采用 BYOK（Bring Your Own Key）模式：API Key 仅保存在设备 Keychain 中，不会写入 UserDefaults、iCloud、Supabase、清单文件或日志。AI 请求和必要的搜索查询由设备直接发往用户选择的服务商，不经过开发者的 Supabase。

只有用户主动点击生成时才会发送请求。生成结果先进入可编辑的确认页面，用户保存后才会写入本地清单。未配置 AI 时，所有手工创建、编辑、预览、打印和 iCloud 功能仍可正常使用。

## 系统要求

- macOS 和 Xcode
- iOS 17.0 或更高版本
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.46 或更高版本
- 真机运行、iCloud 验证和归档需要有效的 Apple Developer 签名

## 本地运行

克隆仓库后，生成 Xcode 工程并构建：

```bash
git clone https://github.com/terryso/PrintableCheckList-SwiftUI.git
cd PrintableCheckList-SwiftUI
./Scripts/generate.sh
./Scripts/build.sh
```

运行测试：

```bash
./Scripts/test.sh
```

构建、安装并启动模拟器版本：

```bash
./Scripts/run-simulator.sh
```

模拟器名称和系统版本可以通过环境变量覆盖：

```bash
SIMULATOR_NAME="iPhone 16 Pro" SIMULATOR_OS="18.5" ./Scripts/run-simulator.sh
```

这些脚本使用 Xcode 提供的 SDK、编译器和模拟器，但不要求打开 Xcode 图形界面。

## 工程结构

```text
PrintableCheckList/          App 源代码、资源和隐私清单
PrintableCheckListTests/     单元测试
PrintableCheckListUITests/   UI 自动化测试
Config/                      构建配置和 Swift Package 锁定文件
Scripts/                     生成、构建、测试、运行及归档脚本
Supabase/migrations/         可选统计服务的数据库迁移
ci_scripts/                  Xcode Cloud 构建脚本
project.yml                  XcodeGen 工程配置
```

应用采用本地优先的数据模型。清单首先保存在设备上；iCloud 是面向用户的跨设备同步方式。Supabase 统计不是备份或恢复服务，应用也不会从 Supabase 下载清单。

## 签名与 iCloud

需要真机运行或归档时，复制本地配置示例并填写 Apple Developer Team ID：

```bash
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

```xcconfig
DEVELOPMENT_TEAM = YOUR_TEAM_ID
```

然后执行：

```bash
./Scripts/archive.sh
```

`Config/Local.xcconfig` 已被 Git 忽略，不应提交到仓库。生产 iCloud 容器需要签名后的真机构建；未签名的模拟器构建无法完成真实 iCloud 端到端验证。

## 可选的 Supabase 产品统计

Supabase 仅供开发者配置。普通用户不会在 App 内看到或填写项目地址、密钥等后端设置。

如需启用：

1. 创建 Supabase 项目，并在 Authentication 中启用匿名登录。
2. 在 SQL Editor 中依次执行 `Supabase/migrations/` 下的迁移文件。
3. 将 `Config/Local.xcconfig.example` 复制为 `Config/Local.xcconfig`。
4. 填写项目 URL 和 **publishable key**：

```xcconfig
SUPABASE_URL = https:/$()/YOUR_PROJECT_REF.supabase.co
SUPABASE_PUBLISHABLE_KEY = sb_publishable_...
```

不要将 `service_role`、`sb_secret_` 或其他服务端密钥嵌入 App。

只有用户明确同意后，应用才会上传安装范围内的清单快照。数据可能包含清单名称、清单项文本和随机安装标识，仅用于产品统计，不用于跨设备同步。用户可以随时在“设置 → 隐私”中关闭共享并删除已上传的数据。不需要此能力时，保持 Supabase 配置为空即可。

## Xcode Cloud

Xcode Cloud 工作流需要配置以下环境变量：

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- `APPLE_DEVELOPMENT_TEAM`（可选，用于覆盖默认 Team ID）

`ci_scripts/ci_post_clone.sh` 会生成本地构建配置、安装缺失的 XcodeGen、生成 Xcode 工程，并复制已锁定的 Swift Package 版本。

## 隐私

项目的 Privacy Manifest 位于 `PrintableCheckList/PrivacyInfo.xcprivacy`。公开隐私政策：

<https://blog.terryso.dev/PrintableCheckList-Privacy/>

仓库同时提供本次版本对应的[中文隐私说明](PRIVACY.md)和[English Privacy Notice](PRIVACY.en.md)，用于同步公开隐私政策和 App Store Connect 披露。

## 参与开发

欢迎通过 [Issues](https://github.com/terryso/PrintableCheckList-SwiftUI/issues) 报告问题或提出建议。提交代码前请运行：

```bash
./Scripts/test.sh
```
