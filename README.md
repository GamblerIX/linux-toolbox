# Linux 工具箱 (linux-toolbox)

企业级 Linux 脚本工具箱，提供系统管理、网络工具、软件安装等功能。代码经过全面优化，语法稳定，支持生产环境部署。

## 🚀 快速上手

只需在你的服务器终端中运行以下命令，即可自动完成工具箱的安装和配置：

```
bash <(curl -sL https://raw.githubusercontent.com/GamblerIX/linux-toolbox/main/install.sh)
```

或者（可选）:

```
bash <(wget -qO- https://raw.githubusercontent.com/GamblerIX/linux-toolbox/main/install.sh)
```

安装成功后，直接执行 `tool` 命令即可启动工具箱。

### 高级用法

```bash
# 直接访问特定功能模块
tool system    # 系统管理菜单
tool network   # 网络与安全菜单
tool install   # 程序安装菜单
tool manage    # 工具箱管理菜单

# 非交互模式运行
tool --non-interactive system

# 启用调试模式
tool --debug

# 查看版本信息
tool --version

# 系统诊断
tool --doctor
```

## 📁 文件结构

新的模块化结构如下：

```
.
├── install.sh          # 独立的安装/更新脚本
├── tool.sh             # 主执行文件 (用户入口)
├── config.sh           # 全局配置文件 (颜色、路径、版本等)
├── VERSION             # 版本信息文件
├── lib_utils.sh        # 通用工具函数库
├── lib_system.sh       # 系统管理与检测函数库
├── lib_ui.sh           # 用户界面与交互函数库
├── lib_install.sh      # 工具箱安装管理函数库
├── lib_network.sh      # 网络工具函数库
├── lib_firewall.sh     # 防火墙管理函数库
├── lib_installer.sh    # 第三方软件安装函数库
├── lib_superbench.sh   # 性能测试函数库
└── README.md           # 项目说明文档
```

## 🏗️ 架构特性

- **企业级稳定性**: 严格模式运行，统一异常处理，确保脚本健壮性
- **智能环境适配**: 自动检测TTY、容器环境，支持非交互模式
- **安全可靠**: SHA256校验、版本管理、配置备份与错误恢复
- **模块化设计**: 按需加载，统一命名空间，便于扩展维护

## 🛠️ 功能模块

#### 🌐 网络与安全
网络测试、SSH日志分析、防火墙管理、BBR加速、端口扫描

#### ⚙️ 系统管理
垃圾清理、用户管理、内核管理、软件源更换

#### 🧩 软件安装
宝塔面板、1Panel、sing-box等常用工具一键部署

## 🤝 贡献

欢迎提交 [Issues](https://github.com/GamblerIX/linux-toolbox/issues) 报告问题或建议功能。

## 📄 许可

[MIT License](https://github.com/GamblerIX/linux-toolbox/blob/main/LICENSE)
