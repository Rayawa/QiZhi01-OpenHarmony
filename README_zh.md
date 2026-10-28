# QiZhi01-OpenHarmony — 310B RC 24.1.RC2 / OpenHarmony 5.0.3 Release

[English](README.md) | 简体中文


## 概述

本项目是基于 [Ascend HDK 24.1.RC2](https://support.huawei.com/enterprise/zh/ascend-computing/ascend-hdk-pid-252764743/software/262029946) 与 [OpenHarmony 5.0.3 Release](https://gitcode.com/openharmony/docs/blob/OpenHarmony-5.0.3-Release/zh-cn/release-notes/OpenHarmony-v5.0.3-release.md) 的昇腾310B芯片适配代码仓库。通过将 `device_board_ascend`、`device_soc_ascend`、`vendor_ascend` 三个子仓库合并到 OpenHarmony 源码树中，实现 OpenHarmony 标准系统在 **启智01开发者套件（昇腾310B）** 上的完整运行。

### 硬件平台

| 项目 | 规格 |
|------|------|
| SoC | 昇腾310B（DaVinci V300 NPU，20 TOPS INT8） |
| CPU | TAISHAN V200M 四核 ARM Cortex-A55 @1.6GHz |
| GPU | ARM Mali G52（Panfrost 开源驱动） |
| 内存 | 24GB LPDDR4X |
| NPU | DaVinci V300，20 TOPS INT8 |
| 显示 | HDMI 1080P，支持双屏异显 |

### 支持功能

- **GPU 图形加速**：Panfrost 开源驱动 + Mesa3D（OpenGL ES 2.0/3.x），支持硬件加速图形桌面
- **Linux Kernel 5.10**：带 43 个 OpenHarmony 系统补丁和 6 个设备树补丁
- **USB HDC 调试**：支持 DevEco Studio 开发调试
- **MIPI / USB 摄像头**：IMX219 MIPI 摄像头 + UVC USB 摄像头，基于 V4L2 框架
- **ALSA 音频 + HDMI 音频**：音频编解码器驱动，支持播放/录音
- **HDMI 双屏异显**：多屏同显 / 异显，鼠标跨屏切换
- **CANN 推理**：CANN 8.2.RC1 Toolkit + NPU 驱动，支持 PyTorch NPU、AscendCL 推理
- **WiFi / 蓝牙**：Realtek RTL8192CU WiFi + BLE/SLE 双模蓝牙
- **RGA 2D 硬件加速**：图像缩放、裁剪、旋转、格式转换
- **x264 软件编码**：H.264 视频编码器

## 目录结构

```
QiZhi01-OpenHarmony/
│
├── README.md                          # 项目说明文档
├── build.sh                           # 一键编译脚本（源码下载→合patch→编译→打包）
├── ascend_env.sh                      # 源码整合脚本（拷贝适配代码、合入patch）
│
├── package/                           # 外部依赖包存放目录（需自行下载）
│   ├── Ascend-hdk-310b-npu-driver-soc_24.1.rc2_linux-aarch64.run  # NPU驱动
│   ├── Ascend310B-source-bjjc-ohos.tar.gz   # 昇腾310B定制内核源码
│   └── readme.md
│
├── device_board_ascend/               # 昇腾310B 板级适配代码
│   ├── 310BFormatTest/                # SD卡制卡工具
│   │   ├── formatSD310B.sh            # SD卡烧写脚本
│   │   ├── formatImg310B.sh           # 独立镜像生成脚本
│   │   ├── mksd.conf                  # SD卡分区配置（system 20G / vendor 4G / userdata 8G）
│   │   ├── firmware/                  # 固件目录（存放编译生成的镜像文件）
│   │   └── tools/                     # 制卡工具链
│   │
│   ├── tools/
│   │   └── boot-firmware-40M/         # hboot2 升级包（内核分区限制 30M→40M）
│   │
│   ├── patch/                         # OpenHarmony 系统级补丁（43个）
│   │   ├── 0001~0014                  # 构建系统、GPU、SELinux、电源管理
│   │   ├── 0015~0024                  # 摄像头V4L2、音频ALSA适配
│   │   ├── 0025~0032                  # sandbox、多屏异显、HDC修复
│   │   └── 0033~0043                  # V4L2完善、EGL函数修复
│   │
│   ├── ascend/310B/                   # 310B板级核心适配代码
│   │   ├── ascendinstall/             # 系统首次启动初始化（init.sh、busybox、bash移植）
│   │   ├── audio_alsa/                # ALSA音频HAL（vendor_render.c / vendor_capture.c）
│   │   ├── bootanimation/             # 开机动画（720P + 1080P）
│   │   ├── camera/                    # 相机V4L2驱动适配（IMX600 + ASISPV5 ISP）
│   │   ├── cfg/                       # 系统初始化配置（fstab、USB模式）
│   │   ├── kernel/                    # 内核构建与驱动
│   │   │   ├── build_kernel.sh        # 内核编译脚本
│   │   │   ├── kernel_config/         # 内核defconfig
│   │   │   ├── kernel_driver/         # 预编译内核驱动模块（.ko）
│   │   │   └── kernel_patch/          # 内核补丁（kernel.patch + DTB补丁）
│   │   └── updater/                   # 系统升级器配置
│   │
│   └── tests/                         # 功能测试
│       ├── audio/                     # 音频功能测试
│       ├── cann/                      # CANN推理Demo（ResNet50 + 环境搭建文档）
│       └── multiscreen/               # 多屏异显测试（含测试App）
│
├── device_soc_ascend/                 # 昇腾310B SoC芯片级代码
│   └── ascend/310B/hardware/
│       ├── display/                   # 显示子系统（DRM/KMS + GBM + VSync + 图层合成）
│       │   └── src/
│       │       ├── display_device/     # 显示设备核心（drm_connector/crtc/plane/vsync/hdi_composer）
│       │       ├── display_gfx/        # GFX底层实现
│       │       └── display_gralloc/    # GBM图形内存分配器
│       ├── gpu/                       # GPU驱动（Panfrost + Mesa3D库）
│       │   ├── lib64/                 # libEGL、libGLESv2、libgbm、libgallium_dri
│       │   └── 0001-display-mesa3d-init.patch
│       ├── rga/                       # RGA 2D加速库（librga.z.so）
│       └── x264/                      # x264软件编码器
│
└── vendor_ascend/                     # 昇腾310B 方案定制（vendor级配置）
    └── ascend/310B/
        ├── config.json                # 产品核心配置（310B 产品名、子系统组件特性列表）
        ├── default_app_config/        # 默认应用配置
        ├── etc/param/                 # 产品/硬件参数
        ├── hdf_config/                # HDF驱动框架配置（用户态uhdf + 内核态khdf）
        ├── hals/audio/                # 音频HAL配置（adapter/paths/effect/policy）
        ├── image_conf/                # 镜像分区配置
        ├── preinstall-config/         # 预装应用配置
        ├── resourceschedule/          # 资源调度配置（cgroup/SoC性能提升）
        ├── security_config/           # 安全配置（关键进程列表）
        ├── window_config/             # 窗口管理配置（display/window manager XML）
        └── updater_config/            # 升级器配置
```

## 开发环境搭建

### 1. 硬件环境

- Ubuntu 20.04 / 22.04 LTS x86_64，系统硬盘 ≥ 200GB，内存 ≥ 16GB

### 2. 安装编译依赖

请参考 [OpenHarmony 官方文档](https://gitcode.com/openharmony/docs/blob/master/zh-cn/device-dev/quick-start/quickstart-pkg-install-package.md) 安装所需库和工具集。关键依赖包括：

```bash
sudo apt-get install -y git-lfs git curl python3-pip ccache \
  mtd-utils gcc g++ libssl-dev zlib1g-dev flex bison \
  device-tree-compiler bc u-boot-tools genext2fs e2fsprogs \
  dosfstools mtools libtinfo5 openjdk-11-jdk
```

### 3. 配置 Git 与 Repo

```bash
git config --global user.name "your-name"
git config --global user.email "your-email"

# 安装 Repo 工具
mkdir ~/bin
curl https://raw.gitcode.com/gitcode-dev/repo/raw/main/repo-py3 -o ~/bin/repo
chmod a+x ~/bin/repo
export PATH=~/bin:$PATH
```

### 4. 安装交叉编译工具链

从 [Ascend HDK 24.1.RC2](https://ascend-repo.obs.cn-east-2.myhuaweicloud.com/Ascend%20HDK/Ascend%20HDK%2024.1.RC2/Ascend-hdk-310b-sdk-soc_24.1.rc2.zip) 下载 SDK，解压其中的 `toolchain.tar.gz`：

```bash
mkdir -p /opt/compiler
tar -xzf toolchain.tar.gz -C /opt/compiler/
echo "export PATH=/opt/compiler/toolchain/bin:\$PATH" >> /etc/profile
source /etc/profile

# 创建软链接，避免编译时找不到编译器
sudo ln -sf /opt/compiler/toolchain/bin/aarch64-target-linux-gnu-* /usr/local/bin/
```

## 源码获取与编译

### 1. 下载 OpenHarmony 源码

```bash
mkdir -p /opt/ohos && cd /opt/ohos
repo init -u git@gitee.com:openharmony/manifest.git \
  -b refs/tags/OpenHarmony-v5.0.3-Release --no-repo-verify
repo sync -c
repo forall -c 'git lfs pull'
```

### 2. 下载预编译工具链

```bash
cd /opt/ohos/build
./prebuilts_download.sh
```

### 3. 放置外部依赖包

将以下三个文件放置到对应位置（百度网盘链接见 README 原文档）：

| 文件 | 放置路径 | 说明 |
|------|----------|------|
| `Ascend-hdk-310b-npu-driver-soc_24.1.rc2_linux-aarch64.run` | `package/` | NPU 驱动安装包 |
| `Ascend310B-source-bjjc-ohos.tar.gz` | `package/` | 昇腾310B定制内核源码 |
| `libaarch64.tar.gz` | `device_board_ascend/ascend/310B/ascendinstall/` | ARM64 运行时依赖库 |

### 4. 执行一键编译

```bash
cd /path/to/QiZhi01-OpenHarmony
sudo ./build.sh /opt/ohos
```

编译流程自动化执行：
1. 检查 `/opt/ohos` 目录是否存在（不存在则自动 `repo init + sync`）
2. 解压 `Ascend310B-source-bjjc-ohos.tar.gz` 到 `kernel/linux/Ascend310B-5.10/`
3. 调用 `ascend_env.sh` 完成源码整合（拷贝板级/芯片/供应商代码、合入 43 个系统 patch + 6 个 DTB patch）
4. 调用 `./build.sh --product-name 310B --ccache` 执行全量编译

编译完成后在 `out/310B/packages/phone/images/` 目录生成 `Ascend-hdk-310b-soc_24.1.rc2-harmony_5.0.3-aarch64.zip`。

### 编译输出物

| 镜像文件 | 说明 |
|----------|------|
| `system.img` | 系统分区镜像 |
| `vendor.img` | 厂商分区镜像 |
| `userdata.img` | 用户数据分区镜像 |
| `updater.img` | 升级模式镜像 |
| `Image_signed` | 签名的内核镜像 |
| `dt.img` | 设备树镜像 |

### 编译常见问题

- **`'aarch64-target-linux-gnu-gcc' not found`**：重新创建软链接 `sudo ln -sf /opt/compiler/toolchain/bin/aarch64-target-linux-gnu-* /usr/local/bin/`
- **首次编译耗时长（3-5 小时）/ 内存不足**：使用 `--ccache` 启用编译缓存；减少并行数或增加 swap
- **预构建工具链下载失败**：配置代理后重试，或从其他机器复制 `prebuilts` 目录
- **GN 语法报错**：严禁使用 Tab 缩进，仅使用空格；`ohos_bpf` 等特殊模板不接收外部 `cflags`

## 镜像烧写与启动

### 1. 制卡烧写

```bash
# 解压编译产物到制卡工程
unzip Ascend-hdk-310b-soc_24.1.rc2-harmony_5.0.3-aarch64.zip \
  -d 310BFormatTest/firmware/
mv 310BFormatTest/firmware/*/Image_signed 310BFormatTest/firmware/*/Image

# 烧写到 SD 卡
cd 310BFormatTest
./formatSD310B.sh /dev/sdX   # /dev/sdX 替换为实际 SD 卡设备节点
```

### 2. 升级 hboot2

适配后内核因开启 HILOG/HISYSEVENT/BLACKBOX 等特性超过 30MB，需升级 hboot2 将内核分区限制从 30M 提升至 40M：

```bash
./boot-firmware-40M-BJJC.run --full
reboot
```

### 3. 首次启动

将 SD 卡插入开发板，连接 HDMI 显示器、USB 键鼠、串口调试线（115200 波特率）。上电后观察：
- 串口输出内核启动日志
- HDMI 输出 OpenHarmony 开机动画 → 图形桌面

启动完成后验证：

```bash
hdc list targets          # 确认设备连接
hdc shell                  # 进入 shell

# 验证显示
ls /dev/dri/                         # 应显示 card0
cat /sys/class/drm/card0-HDMI-A-1/status  # 应显示 connected

# 验证 NPU
/var/Ascend/install_cache/npu-smi info
```

## CANN 推理引擎安装

CANN 8.2.RC1 Toolkit 安装需将安装包通过 U 盘复制到设备，执行 `install_cann.sh` 脚本。具体步骤参考 `device_board_ascend/tests/cann/` 目录下的文档。

安装完成后的验证：

```bash
source /etc/profile.d/cann_env.sh

# 验证 NPU 设备
/var/Ascend/install_cache/npu-smi info

# 验证 Python ACL
python3.10 -c "import acl; print('ACL version:', acl.__version__)"

# 验证 PyTorch NPU
python3.10 -c "import torch; import torch_npu; print('NPU available:', torch.npu.is_available())"
```

## 架构详解

### 显示子系统

基于 Linux DRM/KMS 框架实现显示驱动，使用海思 VDP（Video Display Processor）DRM 驱动（`ascend_vdp_drm.ko`），用户态通过 HDF 框架实现 Display HDI 层。

核心组件：
- `hdi_composer`：HDI Composer 主接口
- `drm_connector/crtc/plane/encoder`：DRM 设备管理
- `drm_vsync_worker`：VSync 信号同步
- `display_gralloc_gbm`：基于 GBM 的图形内存分配器
- `hi_gbm`：海思平台 GBM 封装

支持 HDMI 1080P 输出和多屏异显（patch 0029-0031）。

### GPU 图形加速

- **Panfrost 内核驱动**（`panfrost.ko`）：开源 Mali G52 GPU 驱动
- **Mesa3D 用户态库**：`libEGL.so`、`libGLESv2.so`、`libgbm.so`、`libgallium_dri.so`
- **GPU 初始化补丁**：`0001-display-mesa3d-init.patch` 确保 EGL 上下文正确初始化

### 音频系统

基于 ALSA 框架，驱动层包括：
- `ascend_310b_codec.ko`：音频编解码器驱动
- `ascend_310b_platform_m.ko`：平台 DMA 驱动
- `ascend_310b_machine.ko`：Machine 驱动（ALSA 声卡注册入口）

用户态音频 HAL 位于 `device_board_ascend/ascend/310B/audio_alsa/`，音频策略配置位于 `vendor_ascend/ascend/310B/hals/audio/`。

### 摄像头系统

基于 V4L2 框架：
- `imx219_v4l2.ko`：IMX219 MIPI 摄像头传感器驱动
- `ascend_vdp_v4l2.ko`：海思 VDP 视频采集驱动
- Camera HDI Pipeline：codec_node（编解码）、exif_node（EXIF信息）、face_node（人脸检测）、scale_node（缩放）

### 内核驱动模块一览

| 类别 | 模块 | 功能 |
|------|------|------|
| 显示 | `ascend_vdp_drm.ko` | VDP DRM 显示驱动 |
| GPU | `panfrost.ko` | Mali G52 GPU 驱动 |
| 音频 | `ascend_310b_codec/machine/platform_m.ko` | 音频编解码器/平台 DMA |
| WiFi | `rtl8192cu.ko`、`rtlwifi.ko`、`cfg80211.ko`、`mac80211.ko` | Realtek USB WiFi |
| 蓝牙 | `bluetooth.ko`、`ble_soc.ko`、`sle_soc.ko` | BLE/SLE 双模蓝牙 |
| 摄像头 | `imx219_v4l2.ko`、`ascend_vdp_v4l2.ko` | 摄像头传感器/VDP采集 |
| USB | `usb_f_fs.ko` | USB FunctionFS（HDC） |
| 其他 | `pwm.ko`、`svm.ko`、`rfkill.ko` | PWM/共享虚拟内存/RF控制 |

### 系统补丁体系（43 个 Patch）

| 子系统 | Patch 数量 | 主要修改 |
|--------|-----------|----------|
| 构建系统（build） | 3 | 添加 ascend 设备编译白名单、相机子系统白名单、构建脚本 |
| 驱动框架（drivers/HDF） | 14 | 删除内核 SEC_FUNCTION、V4L2 摄像头兼容、ALSA 音频配置 |
| 系统基础服务（base） | 6 | HwUser 用户组、SELinux 关闭、电源管理、设备权限 |
| 图形与多媒体（foundation） | 16 | GPU EGLImage、Framebuffer 格式修复、多屏异显、EGL 函数修复 |
| 开发工具（developtools） | 1 | HDC 小流传输策略修复 |

## 相关文档

- [OpenHarmony 5.0.3 Release 官方文档](https://gitcode.com/openharmony/docs/blob/OpenHarmony-5.0.3-Release/zh-cn/readme.md)
- [Ascend HDK 24.1.RC2 官方文档](https://support.huawei.com/enterprise/zh/ascend-computing/ascend-hdk-pid-252764743)
- 项目配套技术文档位于上级目录的 `.docx` 系列文件
- CANN 推理环境搭建详见 `device_board_ascend/tests/cann/`
- 音频测试详见 `device_board_ascend/tests/audio/`
- 多屏异显测试详见 `device_board_ascend/tests/multiscreen/`
