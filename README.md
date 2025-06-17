# Linux 工具箱 (linux-toolbox) 

这是一个模块化的 Linux 脚本工具箱，旨在作为宝塔面板的补充，同时提供清晰、可扩展的脚本框架。

##  ✨ 项目亮点

- **完全模块化**: 代码被拆分为核心、库、配置等多个文件，逻辑清晰，易于维护和二次开发。
- **轻量便捷**: 通过独立的 `install.sh` 一键安装，之后可在任意路径通过 `tool` 命令启动。
- **强大兼容**: 核心功能在 `Ubuntu`, `Debian`, `CentOS 7` 主流发行版上经过测试。
- **自由开放**: 项目基于 MIT 协议开源，可以自由使用、修改和分发。

## 🚀 快速上手

只需在你的服务器终端中运行以下命令，即可自动完成工具箱的安装和配置：

```
bash <(curl -sL https://raw.githubusercontent.com/GamblerIX/linux-toolbox/main/install.sh)
```

或者使用 `wget`:

```
bash <(wget -qO- https://raw.githubusercontent.com/GamblerIX/linux-toolbox/main/install.sh)
```

安装成功后，直接执行 `tool` 命令即可启动工具箱。

## 📁 文件结构

新的模块化结构如下：

```
.
├── install.sh          # 独立的安装/更新脚本
├── tool.sh             # 主执行文件 (用户入口)
├── config.sh           # 全局配置文件 (颜色、路径等)
├── lib_utils.sh        # 通用工具函数库
├── lib_system.sh       # 系统管理函数库
├── lib_network.sh      # 网络工具函数库
├── lib_firewall.sh     # 防火墙管理函数库
├── lib_installer.sh    # 第三方软件安装函数库
└── README.md           # 项目说明文档
```

## 🛠️ 功能列表

脚本提供一个简单易用的菜单，包含了以下核心功能：

#### 🌐 网络与安全

- **网络性能测试**: 一键测试服务器网络速度。
- **SSH 日志分析**: 快速分析 `sshd` 登录日志。
- **防火墙管理**: （UFW/Firewalld）便捷管理端口和规则。
- **BBR 加速**: 一键安装并启用 Google BBR。
- **端口扫描**: 查看当前被占用的端口。

#### ⚙️ 系统管理

- **系统垃圾清理**: 深度清理系统缓存和临时文件。
- **用户管理**: 创建、删除、修改用户。
- **内核管理**: 查看和管理系统内核。
- **软件源更换**: 一键切换到国内主流镜像源（阿里/腾讯/中科大）。

#### 🧩 一键安装

- **常用面板**: 宝塔、1Panel 等面板的一键安装。
- **代理工具**: sing-box 等常用工具的快速部署。

## 🤝 如何贡献

我们非常欢迎你为这个项目做出贡献！

**报告 Issue**: 如果你发现任何 Bug 或有功能建议，请在 [Issues](https://github.com/GamblerIX/linux-toolbox/issues) 页面提交。

## 📄 开源许可

本项目采用 [MIT License](https://github.com/GamblerIX/linux-toolbox/blob/main/LICENSE) 开源许可。
