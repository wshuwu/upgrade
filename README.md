# upgrade
用于ESCCU设备升级，QT界面搭配install.sh升级脚本


# Qt 运行时依赖安装说明

本文档说明在 Ubuntu/Debian 系统上运行 Qt 应用程序所需安装的系统依赖库。

## 适用场景

- 目标系统为 **Ubuntu 18.04 / 20.04** 等基于 Debian 的 Linux 发行版
- Qt 应用使用 **XCB** 平台插件（桌面 X11 环境）
- 仅需运行时依赖，不包含编译 Qt 源码所需的 `-dev` 开发包

## 安装依赖库

### 基础库

```bash
sudo apt update
sudo apt install -y \
    libmtdev1 \
    libinput10 \
    libxkbcommon0 \
    libdouble-conversion3 \
    libicu66 \
    libharfbuzz0b \
    libwebpdemux2 \
    libwebpmux3 \
    libfontconfig1 \
    libfreetype6
```

**注意：** `libdouble-conversion` 和 `libicu` 的包名后缀随 Ubuntu 版本变化（如 `libdouble-conversion1`/`libdouble-conversion3`、`libicu60`/`libicu66`/`libicu70`）。如果安装失败，请使用 `apt search libdouble-conversion` 和 `apt search libicu` 确认当前系统可用的包名。

### XCB 平台插件依赖

```bash
sudo apt install -y \
    libxcb-icccm4 \
    libxcb-image0 \
    libxcb-shm0 \
    libxcb-keysyms1 \
    libxcb-render0 \
    libxcb-render-util0 \
    libxcb-shape0 \
    libxcb-sync1 \
    libxcb-xfixes0 \
    libxcb-xinerama0 \
    libxcb-xkb1 \
    libxcb-randr0 \
    libsm6 \
    libice6 \
    libxkbcommon-x11-0
```

### 显示环境变量

如果运行在本地桌面终端中，通常不需要手动设置 `DISPLAY`。

如果从 SSH、systemd 服务、Docker 或非图形终端启动，可尝试：

```bash
export DISPLAY=:0
```

## 环境变量配置

将以下内容写入 `/etc/profile.d/qt_env.sh` 或用户的 `~/.bashrc`：

```bash
export QT_QPA_PLATFORM=xcb
```

**说明：** `QT_QPA_EGLFS_INTEGRATION=XCB_EGL` 仅在 XCB 平台插件编译时启用了 EGL 后端且需要强制使用 EGL 而非 GLX 时才需要设置。大多数桌面 X11 环境下无需配置此项，保留默认即可。如果你的应用确实需要在 XCB 下使用 EGL 后端，可额外添加：

## 验证安装

运行以下命令检查 XCB 插件依赖是否完整：

```bash
ldd $QTDIR/plugins/platforms/libqxcb.so | grep "not found"
```

如果没有输出，说明依赖已满足。

## 版本适配参考

| Ubuntu 版本 | libicu 包名 | libdouble-conversion 包名 |
| ------ |------ |------ |
| 18.04 | `libicu60` | `libdouble-conversion1` |
| 20.04 | `libicu66` | `libdouble-conversion3` |
| 22.04 | `libicu70` | `libdouble-conversion3` |
| 24.04 | `libicu74` | `libdouble-conversion3` |

