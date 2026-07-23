# PrintableCheckList：AI 驱动的可打印清单

<p align="center">
  <img src="PrintableCheckList/Resources/Assets.xcassets/AppIcon.appiconset/pcl@1024.png" width="128" alt="PrintableCheckList app icon">
</p>

<p align="center">
  <strong>带孩子出发前，先让 AI 补漏，再编辑、预览并打印最终清单。</strong>
</p>

PrintableCheckList 是“闪印”的开源 SwiftUI 项目，当前产品方向聚焦亲子旅行最终打包。用户可以描述旅行情境，由 AI 生成一份可编辑草稿，确认后继续排序、预览和打印；它不是 Todo、提醒或项目管理工具。

AI 是付费解锁的可选能力，而不是使用 App 的门槛。所有手工创建、批量粘贴、本地编辑、iCloud 和系统打印功能均可独立使用。

## 用 AI 创建一份清单

1. 输入主题和具体要求，例如“生成一份带孩子去北海道冬季旅行的 20 项清单”。
2. 在第一次真实 AI 操作前购买一次性 Pro，选择托管 AI 或自带 API Key。
3. 在保存前检查 AI 结果，按需修改标题、增删项目或重新生成。
4. 保存到本地，继续编辑、补充、预览或打印。

AI 也可以补充已有清单，不必为了漏掉的项目重新创建一份。托管 AI 当前提供生成和补充；BYOK 路径可在 GLM 或 OpenAI 支持的情况下执行联网搜索并展示参考来源。

## 功能

- 创建、重命名、删除和排序多份清单
- 一次粘贴多行文本，批量添加清单项
- 一次性 Pro 解锁 AI；每个自然月最多 20 次托管 AI 操作
- 使用自己的 GLM、OpenAI、DeepSeek 或兼容服务 API Key，且 BYOK 不占用托管 AI 月度额度
- 使用 GLM 或 OpenAI 联网搜索时效性资料，并展示参考来源
- 编辑、删除和拖动排序清单项
- 生成带勾选框的打印预览
- 使用系统打印控制器直接打印
- 通过 iCloud 键值存储在同一 Apple ID 的设备之间同步
- 支持简体中文和英文
- 支持深色模式、动态字体和 VoiceOver
- 可选的 Supabase 产品统计，只有在用户明确同意后才会上传
- 兼容导入旧版应用保存在本地或 iCloud 中的清单数据

## AI 访问方式

Pro 是可恢复的非消耗型购买。用户完成主题输入并尝试生成时才会看到付费墙；购买后可以选择：

- **托管 AI**：无需填写 API Key。App 把 StoreKit 交易 JWS 和生成请求发送到产品方服务；服务端验证当前购买状态、执行每月 20 次额度并调用配置的模型。内部模型重试不额外计数。当前托管路径不执行联网搜索。
- **BYOK**：用户自行配置模型服务。仍需 Pro，但不受托管 AI 月度额度限制，请求从设备直接发送给用户选择的服务商。

Debug 构建通过 `MANAGED_AI_SANDBOX_SERVICE_URL` 连接独立的 Sandbox 服务；Release 构建只读取 `MANAGED_AI_PRODUCTION_SERVICE_URL`，并且没有默认托管端点。Production 地址必须通过忽略提交的 `Config/Local.xcconfig` 或 Xcode Cloud 环境变量提供，不能用同一个通用变量覆盖两种环境。

### BYOK 服务商与联网搜索

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

### 隐私边界

BYOK 的 API Key 仅保存在设备 Keychain 中，不会写入 UserDefaults、iCloud、Supabase、清单文件或日志；BYOK 请求和必要的搜索查询从设备直接发往用户选择的服务商。

托管 AI 请求会经过产品方的 Supabase Edge Function、私有 Apple 交易校验服务和模型服务商。服务端凭据只存在于部署环境，绝不进入 App 或仓库。额度账本保存原始交易标识、环境、首次操作时区、操作状态和用于幂等重放的生成响应；不保存请求正文或 StoreKit JWS。完整披露见[中文隐私说明](PRIVACY.md)和[English Privacy Notice](PRIVACY.en.md)。

无论选择哪条路径，只有用户主动点击生成时才会发送请求。生成结果先进入可编辑确认页面，用户保存后才会写入本地清单。

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
Supabase/                    托管 AI、额度账本和可选统计服务
Vercel/                      私有 Apple 交易状态校验服务
docs/                        已确认的产品方向、ADR 和验证门槛
ci_scripts/                  Xcode Cloud 构建脚本
project.yml                  XcodeGen 工程配置
```

应用采用本地优先的数据模型。清单首先保存在设备上；iCloud 是面向用户的跨设备同步方式。Supabase 托管 AI 和可选统计都不是清单备份或恢复服务，应用也不会从 Supabase 下载本地清单。

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

## Supabase 与托管服务配置

Supabase 仅供开发者配置。普通用户不会在 App 内看到或填写项目地址、密钥等后端设置。

如需启用可选产品统计：

1. 创建 Supabase 项目，并在 Authentication 中启用匿名登录。
2. 在 SQL Editor 中执行
   `20260721000000_create_checklist_snapshots.sql` 和
   `20260721010000_allow_snapshot_deletion.sql`。
3. 将 `Config/Local.xcconfig.example` 复制为 `Config/Local.xcconfig`。
4. 填写项目 URL 和 **publishable key**：

```xcconfig
SUPABASE_URL = https:/$()/YOUR_PROJECT_REF.supabase.co
SUPABASE_PUBLISHABLE_KEY = sb_publishable_...
```

不要将 `service_role`、`sb_secret_` 或其他服务端密钥嵌入 App。

只有用户明确同意后，应用才会上传安装范围内的清单快照。数据可能包含清单名称、清单项文本和随机安装标识，仅用于产品统计，不用于跨设备同步。用户可以随时在“设置 → 隐私”中关闭共享并删除已上传的数据。不需要此能力时，保持 Supabase 配置为空即可。

托管 AI 使用同一仓库内的独立服务端组件，但不使用 App 内的 publishable key 进行额度操作：

- `Supabase/functions/managed-ai-checklists/`：校验请求、预留或释放月度额度并调用模型。
- `Supabase/migrations/20260723000000_create_managed_ai_usage.sql` 及后续修复迁移：建立只允许服务端角色访问的额度账本。
- `Supabase/tests/managed_ai_usage.test.sql`：在可丢弃的本地 Supabase 数据库中验证 20 次上限、重复操作、失败释放、时区固定和月界线计算。
- `Vercel/apple-transaction-verifier/`：使用 Apple 官方库和 App Store Server API 校验当前交易状态。

所有 Edge Function、Vercel 和模型凭据必须通过各自部署平台的 secrets 配置。Sandbox 与 Production 必须使用不同的服务部署和账本，不能只切换同一校验器的 `APPLE_ENVIRONMENT`。

## Xcode Cloud

Xcode Cloud 工作流需要配置以下环境变量：

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`
- `MANAGED_AI_SERVICE_URL`（Production 专用 HTTPS 地址）
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
