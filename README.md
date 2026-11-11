# 雪糕cheese · Mac 桌宠

一只住在 Mac 桌面上的雪糕cheese。原生 Swift + AppKit，透明置顶，不抢键盘焦点，离线陪伴。

采用高清重绘风格与 **2× Retina 动画资源**，保持小巧显示尺寸，轮廓和服饰细节更清晰。

> 非官方同人项目。与雪糕cheese及其权利人无隶属、合作或代言关系；角色与相关标识权利归原权利人。美术不适用代码的 MIT 许可，详见 [素材说明](Assets/NOTICE.md)。

![动画预览](docs/preview.gif)

![待机、挥手、跳跃与思考工作](docs/actions.png)

[查看全部动作预览](docs/all-states.mp4)

## 一行安装

支持 **macOS 13 Ventura 或更新版本**，Apple Silicon 与 Intel 均可。打开「终端」粘贴：

```bash
/bin/bash -c "$(curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/tzm224/Vtuber-icecream_cheese/main/install.sh)"
```

安装器从本仓库的最新 GitHub Release 下载预编译通用应用，验证 SHA-256 与应用完整性，然后安装到 `~/Applications/CheesePet.app` 并打开。**不需要 sudo、Homebrew、Node、Python 或 Xcode**。重新执行同一命令即可更新；请先从菜单栏退出旧版。旧应用会保留到 `~/Library/Application Support/CheesePet/Backups/`，不会直接删除。

**第一次发布尚未成功时，以上命令不能安装。** 请确认 [Releases](https://github.com/tzm224/Vtuber-icecream_cheese/releases/latest) 中同时存在 `CheesePet-macOS-universal.zip` 与 `SHA256SUMS`。源码提交成功不等于已发布安装包。

不想直接执行网络脚本，可以先保存并检查：

```bash
curl --proto '=https' --tlsv1.2 -fsSLo cheese-install.sh https://raw.githubusercontent.com/tzm224/Vtuber-icecream_cheese/main/install.sh
less cheese-install.sh
bash cheese-install.sh
```

也可以在 [Releases](https://github.com/tzm224/Vtuber-icecream_cheese/releases) 下载 ZIP，解压后把 `CheesePet.app` 放到「应用程序」。

### macOS 安全提示

当前公开构建使用临时签名（ad-hoc），**没有 Apple Developer ID 签名或 Apple 公证**。SHA-256 与签名检查能检测文件损坏，不代表 Apple 已认证开发者。若系统拦截，请先确认下载自本仓库、了解未公证应用的风险，再按 macOS 的「系统设置 → 隐私与安全性」提示决定是否允许打开。不要关闭 Gatekeeper 或 SIP；本项目也不会修改这些设置。受公司管理的 Mac 可能需要管理员批准。

## 怎么玩

- **单击角色**：打招呼和文字气泡。
- **双击角色**：蹦蹦跳跳。
- **拖动角色**：移动到你喜欢的位置，支持多屏；重启记住位置。
- **右键角色 / 菜单栏 ✨**：动作、大小、暂停、隐藏、重置位置和退出。
- **自动散步**：在所在屏幕可见范围内左右闲逛，可关闭。
- **视线跟随鼠标**：16 方向视线，鼠标停止移动后恢复自然待机，可关闭。
- **透明区域点击穿透**：只在角色可见像素处接收点击，背景不挡工作。

包含待机、左/右行走、挥手、跳跃、失落、等待、思考工作、认真查看共 **9 组动作 / 57 帧**，加 **16 个视线方向**。桌宠不出现在 Dock；退出入口在菜单栏 ✨。

不会启动后自动开机运行。需要时，可在 macOS「系统设置 → 通用 → 登录项」手动添加 `CheesePet.app`。

## 隐私

应用不联网、不需要账号、不含分析或遥测、不使用录音/截屏，也不需要辅助功能或屏幕录制权限。鼠标位置仅用于本机视线跟随与透明区点击判断，不读取输入内容。用户偏好保存在 macOS UserDefaults；安装器联网只访问本 GitHub 仓库和 GitHub 发布资源。

## 从源码构建

开发需要 macOS 13+、Swift 5.9+ / Xcode Command Line Tools；最终用户不需要它们。

```bash
git clone https://github.com/tzm224/Vtuber-icecream_cheese.git
cd Vtuber-icecream_cheese
swift test
swift run CheesePet
```

打包同时含 Apple Silicon 与 Intel 的 `.app` 和 ZIP：

```bash
bash scripts/build.sh
open dist/CheesePet.app
```

输出：`dist/CheesePet.app`、`dist/CheesePet-macOS-universal.zip` 和 `dist/SHA256SUMS`。SwiftPM 无第三方依赖；开发者机器已有 Python 3 时还可以执行下列跨平台检查：

```bash
bash -n install.sh scripts/build.sh scripts/uninstall.sh
python3 -m unittest discover -s tests -v
python3 scripts/validate_assets.py
```

### 发布

1. 在 `VERSION` 中填写版本，例如 `1.0.0`，然后推送 `main`。
2. [Checks](https://github.com/tzm224/Vtuber-icecream_cheese/actions) 和 `Release macOS app` 都会在 macOS runner 上检查代码。发布任务独立执行完整测试、通用构建和应用包自检，成功后创建版本 tag 与 Release。
3. 同名版本的 Release 已存在时不会覆盖；要发布更新，请修改 `VERSION` 后提交。初次发布失败后修复代码并再次推送即可重试。
4. 确认 Release 文件与对应提交的 Actions 成功，才能把一行命令发给用户。也支持推送与 `VERSION` 一致的版本 tag。

CI 的启动存活检查不是完整桌面交互测试，发布前建议按 [Mac 验收清单](docs/TESTING.md) 完成实机验证。

## 项目结构

```text
Sources/CheesePet/       AppKit 窗口、菜单、交互、素材加载
Sources/CheeseCore/      动画时序与坐标逻辑
Tests/CheeseCoreTests/   Swift 单元测试
Assets/                 透明 sprite sheet、manifest、图标、权利说明
scripts/                构建、素材校验、卸载
tests/                  安装器的隔离模拟测试
.github/workflows/      检查与发布流水线
```

替换素材时保留 manifest 约定：8 列 × 11 行，每格逻辑大小 192 × 208pt；9 组动作与 16 个视线方向。支持 `pixelRatio: 2` 的 Retina 高清素材，显示尺寸不变。更完整说明见 [美术接口](docs/ASSETS.md)。

## 更新与卸载

更新：先退出，再重跑安装命令。安装指定版本：

```bash
CHEESE_VERSION=v1.0.0 /bin/bash -c "$(curl --proto '=https' --tlsv1.2 -fsSL https://raw.githubusercontent.com/tzm224/Vtuber-icecream_cheese/main/install.sh)"
```

卸载：从菜单栏退出，把 `~/Applications/CheesePet.app` 拖到废纸篓。源码中的 `bash scripts/uninstall.sh` 同样只把应用移到废纸篓，保留偏好与备份。可自行在 Finder 清理不再需要的备份。

## 许可

代码：MIT，见 [LICENSE](LICENSE)。角色形象、PNG/GIF 美术和相关名称标识不包含在该代码许可中；本项目没有获得角色权利人的再许可。不得把本仓库的存在理解为获得商用、官方素材或角色 IP 的授权。
