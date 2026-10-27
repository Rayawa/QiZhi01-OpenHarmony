# QiZhi01-OpenHarmony

[English](README.md) | 简体中文

面向启智01昇腾310B套件的 OpenHarmony 板级适配、驱动与构建工具。

## 项目概述

仓库将板级、SoC 和厂商代码集成到外部 OpenHarmony 源码树，包含系统补丁、图形/相机/音频适配、Ascend 运行支持及硬件测试工具。完整镜像依赖另行获取的源码、驱动和固件包。

## 技术栈与依赖

文档基线为 OpenHarmony 5.0.3 Release、Ascend 310B 与 HDK 24.1.RC2。构建脚本需要 Linux 主机、OpenHarmony 工具链及 `package/readme.md` 所列文件。CANN 测试另需对应运行时和模型。

## 文件结构

- `device_board_ascend/` — 板级适配、补丁与测试
- `device_soc_ascend/` — SoC 适配
- `vendor_ascend/` — 产品配置
- `package/` — 外部依赖包说明
- `ascend_env.sh` — 源码树整合
- `build.sh` — 构建编排

## 快速上手

1. 准备 Linux OpenHarmony 构建主机，按 [package/readme.md](package/readme.md) 获取需单独分发的文件。
2. 阅读 `build.sh` 和 `ascend_env.sh`，选择独立 OpenHarmony 工作区用于源码下载、整合及构建输出。
3. 文档构建入口为 `sudo ./build.sh /path/to/openharmony-workspace`，执行前确认脚本的提权操作和依赖包要求。
4. 构建成功后再按板级说明处理镜像与 SD 卡；硬件测试说明位于 `device_board_ascend/tests/`。

本仓库不是独立桌面应用，仅复制板级代码不能直接生成可启动系统。
