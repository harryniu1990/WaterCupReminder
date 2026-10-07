# WaterCupReminder

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](./LICENSE)
[![Platform: macOS 12+](https://img.shields.io/badge/Platform-macOS%2012%2B-blue.svg)](#运行环境)
[![Release](https://img.shields.io/github/v/release/harryniu1990/WaterCupReminder)](https://github.com/harryniu1990/WaterCupReminder/releases)

一个基于 Swift + AppKit 的 macOS 菜单栏喝水提醒工具。

它会在工作时间定时弹出一个可爱的喝水提醒窗口，并随着忽略时间逐渐变大，尽量把“该喝水了”这件事提醒到位。

## 功能特性

- 每天 `10:00 - 18:00` 之间每隔 1 小时触发一次提醒。
- 提醒窗口固定出现在屏幕左上角。
- 水杯带弹跳、气泡、柔和缩放等动效。
- 点击“我喝啦”后立即隐藏提醒。
- 如果不点击，提醒窗口每 30 秒会继续放大，直到接近铺满屏幕。
- 非提醒时段自动隐藏，不会在其他时间打扰你。
- 菜单栏支持手动触发提醒、隐藏提醒和退出应用。

## 运行环境

- macOS 12.0 或更高版本
- Xcode Command Line Tools
- Swift 5.7 或兼容版本

如果你还没有安装命令行工具，可以先执行：

```bash
xcode-select --install
```

## 快速开始

### 构建应用

在项目根目录执行：

```bash
./scripts/build-app.sh
```

构建完成后，应用会生成在：

```text
dist/WaterCupReminder.app
```

### 启动应用

双击 `dist/WaterCupReminder.app` 即可启动。

启动后你会看到：

- 菜单栏出现一个水滴图标
- 到达提醒时间时，屏幕左上角弹出喝水提醒
- 可以通过菜单栏手动控制提醒显示与隐藏

## 项目结构

```text
.
├── LICENSE
├── Package.swift
├── README.md
├── Sources/
│   └── WaterCupReminder/
│       └── main.swift
└── scripts/
    ├── build-app.sh
    └── make-installer.sh
```

## 构建脚本说明

`scripts/build-app.sh` 会完成这些工作：

- 编译 `Sources/WaterCupReminder/main.swift`
- 生成 macOS `.app` 应用包
- 写入应用需要的 `Info.plist`
- 将最终产物输出到 `dist/`

`scripts/make-installer.sh` 用于正式发版，额外做这些事：

- 同时编译 `arm64` 与 `x86_64`，用 `lipo` 合并成 Universal Binary
- 做 ad-hoc 签名，保证在其他 Mac 上可以正常启动
- 产出可分发的 `WaterCupReminder-<版本>.dmg` 与 `.zip`

## 说明

- 仓库默认忽略 `.build/`、`dist/`、`.home/` 等本地构建产物和缓存目录。
- 当前版本更适合个人本地使用，尚未包含自动开机启动、偏好设置或自定义提醒频率等功能。

## 许可证

本项目基于 [MIT License](./LICENSE) 开源。

你可以自由地使用、复制、修改、合并、发布、分发、再许可和/或销售本软件的副本，唯一的要求是在所有副本或实质性部分中保留上述版权声明和许可声明。本软件按「原样」提供，不附带任何形式的担保。

```text
Copyright (c) 2026 harryniu1990
```
