# Linux 工具箱 (linux-toolbox)

## 📁 文件结构

```
.
├── install.sh          # 独立的安装/更新脚本
├── tool.sh             # 主执行文件 (交互式入口)
├── lib_utils.sh        # 通用工具函数库
├── lib_system.sh       # 系统管理与检测
├── lib_network.sh      # 网络工具函数库
├── lib_firewall.sh     # 防火墙管理函数库
├── lib_software.sh     # 第三方软件安装函数库
├── VERSION             # 版本信息文件
└── README.md           # 项目说明文档
```

## 🛠️ 功能模块

### 工具箱安装

#### 快速上手

`bash <(curl -sL https://raw.githubusercontent.com/GamblerIX/linux-toolbox/main/install.sh)`

`bash <(curl -sL https://gitee.com/gamblerix/linux-toolbox/raw/main/install.sh)`

#### install.sh 脚本

- **功能**: 安装或更新工具箱
- **执行步骤**：
  1. 判断延迟最低的源是GitHub源还是Gitee源
  2. 连接到低延迟的源中，通过curl逐个下载工具箱相关文件
  3. 如果使用参数`--github`，则强制连接到GitHub源
  4. 如果使用参数`--gitee`，则强制连接到Gitee源
  5. 下载完成后，提示用户启动命令是`tool`

安装成功后，直接执行 `tool` 命令即可启动工具箱。

### lib_toolbox.sh 脚本

- **更新工具箱**: 一键更新工具箱
- **卸载工具箱**: 卸载工具箱相关
- **版本查询**: 查看当前工具箱版本
- **配置管理**: 工具箱配置的查看、编辑、备份、恢复等

### lib_network.sh 脚本

#### 网络速度测试

- **speedtest-cli 测试**: 使用 speedtest-cli 进行网络速度测试
- **Superbench 综合测试**: 集成性能测试，包含网络、CPU、内存等多项指标

#### SSH 安全管理
- **SSH 登录日志查看**: 查看成功/失败的SSH登录记录

#### BBR 网络加速
- **BBR 加速管理**: 启用/禁用 BBR 拥塞控制算法

#### 端口管理
- **端口占用查看**: 列出所有已占用端口及对应进程
- **进程终止**: 根据端口号终止占用进程

### lib_firewall.sh 脚本

- **防火墙状态管理**: 启用/禁用防火墙，查看防火墙状态
- **端口规则管理**: 添加/删除防火墙端口规则

### lib_system.sh 脚本

#### 系统清理
- **垃圾文件清理**: 清理系统临时文件、日志文件、包缓存

#### 用户管理
- **用户账户管理**: 查看所有用户账户，创建、删除用户账户
- **权限管理**: 用户组管理，一键添加指定用户到sudo组

#### 软件源管理
- **软件源更换**: 更换为阿里或腾讯或中科大或谷歌或Azure或AWS软件源
- **核心命令**: 修改 `/etc/apt/sources.list` 或 `/etc/yum.repos.d/`

### lib_software.sh 脚本

> 确认安装后，将退出工具箱以确保安装命令执行成功

#### 宝塔面板
  - LTS 稳定版: `bash <(curl -sSL https://download.bt.cn/install/install_lts.sh)`
  - 最新正式版: `bash <(curl -sSL https://download.bt.cn/install/install_nearest.sh)`
  - 开发版: `bash <(curl -sSL https://download.bt.cn/install/install_panel.sh)`

#### 1Panel
- 国内版: `bash <(curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh)`
- 国际版: `bash <(curl -sSL https://resource.1panel.pro/quick_start.sh)`

#### sing-box-yg 代理工具
- 指令: `bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)`

## ⚠️ 注意事项

- 支持系统: Ubuntu 18.04+, Debian 9+, CentOS 7+
- 中文编码问题，要求编码为utf-8
- 转换符问题，Windows系统下，需要将脚本转换为unix格式，CRLF转换为LF
- Windows作为开发系统时，注意与实际运行系统Debian系统的差别，Windows默认终端是Powershell，不支持`&&`，且无法直接执行脚本，只能通过`bash -n path`来验证脚本语法问题，且脚本路径引用中的 \ 注意要替换为 /