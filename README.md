# QiZhi01-OpenHarmony — 310B RC 24.1.RC2 / OpenHarmony 5.0.3 Release

English | [简体中文](README_zh.md)


## Overview

An Ascend 310B adaptation repository based on [Ascend HDK 24.1.RC2](https://support.huawei.com/enterprise/zh/ascend-computing/ascend-hdk-pid-252764743/software/262029946) and [OpenHarmony 5.0.3 Release](https://gitcode.com/openharmony/docs/blob/OpenHarmony-5.0.3-Release/zh-cn/release-notes/OpenHarmony-v5.0.3-release.md). Merging the `device_board_ascend`, `device_soc_ascend`, and `vendor_ascend` subrepositories into the OpenHarmony source tree enables the complete OpenHarmony standard system to run on the **QiZhi 01 Developer Kit (Ascend 310B)**.

### Hardware platform

| Item | Specification |
|------|------|
| SoC | Ascend 310B (DaVinci V300 NPU, 20 TOPS INT8) |
| CPU | TAISHAN V200M quad-core ARM Cortex-A55 @1.6GHz |
| GPU | ARM Mali G52 (open-source Panfrost driver) |
| Memory | 24 GB LPDDR4X |
| NPU | DaVinci V300，20 TOPS INT8 |
| Display | HDMI 1080P with independent dual-display output |

### Supported features

- **GPU graphics acceleration**: Open-source Panfrost driver + Mesa3D (OpenGL ES 2.0/3.x), supporting a hardware-accelerated desktop
- **Linux Kernel 5.10**: Includes 43 OpenHarmony system patches and 6 device tree patches
- **USB HDC debugging**: Supports DevEco Studio development and debugging
- **MIPI / USB cameras**: IMX219 MIPI and UVC USB cameras through V4L2
- **ALSA and HDMI audio**: Audio codec drivers with playback/recording support
- **Independent dual HDMI displays**: Mirrored or extended output with mouse movement across screens
- **CANN inference**: CANN 8.2.RC1 Toolkit and NPU drivers, supporting PyTorch NPU and AscendCL inference
- **WiFi / Bluetooth**: Realtek RTL8192CU WiFi and dual-mode BLE/SLE Bluetooth
- **RGA 2D hardware acceleration**: Image scaling, cropping, rotation, and format conversion
- **x264 software encoding**: H.264 video encoder

## Directory structure

```
QiZhi01-OpenHarmony/
│
├── README.md                          # Project documentation
├── build.sh                           # One-command build (download → patch → build → package)
├── ascend_env.sh                      # Source integration (copy adaptation code and apply patches)
│
├── package/                           # External dependency packages (download separately)
│   ├── Ascend-hdk-310b-npu-driver-soc_24.1.rc2_linux-aarch64.run  # NPU driver
│   ├── Ascend310B-source-bjjc-ohos.tar.gz   # Customized Ascend 310B kernel source
│   └── readme.md
│
├── device_board_ascend/               # Ascend 310B board adaptation
│   ├── 310BFormatTest/                # SD card creation tools
│   │   ├── formatSD310B.sh            # SD card flashing script
│   │   ├── formatImg310B.sh           # Standalone image generation script
│   │   ├── mksd.conf                  # SD partitions (system 20G / vendor 4G / userdata 8G)
│   │   ├── firmware/                  # Firmware (generated images)
│   │   └── tools/                     # SD creation toolchain
│   │
│   ├── tools/
│   │   └── boot-firmware-40M/         # hboot2 update (kernel limit 30M → 40M)
│   │
│   ├── patch/                         # OpenHarmony system patches (43)
│   │   ├── 0001~0014                  # Build system, GPU, SELinux, power management
│   │   ├── 0015~0024                  # V4L2 camera and ALSA audio adaptation
│   │   ├── 0025~0032                  # Sandbox, independent displays, HDC fixes
│   │   └── 0033~0043                  # V4L2 improvements and EGL fixes
│   │
│   ├── ascend/310B/                   # Core 310B board adaptation
│   │   ├── ascendinstall/             # First-boot initialization (init.sh, busybox, bash port)
│   │   ├── audio_alsa/                # ALSA audio HAL (vendor_render.c / vendor_capture.c)
│   │   ├── bootanimation/             # Boot animation (720P + 1080P)
│   │   ├── camera/                    # V4L2 camera adaptation (IMX600 + ASISPV5 ISP)
│   │   ├── cfg/                       # System initialization (fstab, USB mode)
│   │   ├── kernel/                    # Kernel build and drivers
│   │   │   ├── build_kernel.sh        # Kernel build script
│   │   │   ├── kernel_config/         # Kernel defconfig
│   │   │   ├── kernel_driver/         # Prebuilt kernel modules (.ko)
│   │   │   └── kernel_patch/          # Kernel patches (kernel.patch + DTB patches)
│   │   └── updater/                   # System updater configuration
│   │
│   └── tests/                         # Functional tests
│       ├── audio/                     # Audio tests
│       ├── cann/                      # CANN inference demo (ResNet50 + setup documentation)
│       └── multiscreen/               # Independent multi-display tests (with test app)
│
├── device_soc_ascend/                 # Ascend 310B SoC adaptation
│   └── ascend/310B/hardware/
│       ├── display/                   # Display subsystem (DRM/KMS + GBM + VSync + composition)
│       │   └── src/
│       │       ├── display_device/     # Display core (drm_connector/crtc/plane/vsync/hdi_composer)
│       │       ├── display_gfx/        # Low-level GFX implementation
│       │       └── display_gralloc/    # GBM graphics memory allocator
│       ├── gpu/                       # GPU driver (Panfrost + Mesa3D)
│       │   ├── lib64/                 # libEGL、libGLESv2、libgbm、libgallium_dri
│       │   └── 0001-display-mesa3d-init.patch
│       ├── rga/                       # RGA 2D acceleration (librga.z.so)
│       └── x264/                      # x264 software encoder
│
└── vendor_ascend/                     # Ascend 310B solution customization (vendor configuration)
    └── ascend/310B/
        ├── config.json                # Product configuration (310B name and subsystem component features)
        ├── default_app_config/        # Default app configuration
        ├── etc/param/                 # Product/hardware parameters
        ├── hdf_config/                # HDF configuration (userspace uhdf + kernel khdf)
        ├── hals/audio/                # Audio HAL configuration (adapter/paths/effect/policy)
        ├── image_conf/                # Image partition configuration
        ├── preinstall-config/         # Preinstalled app configuration
        ├── resourceschedule/          # Resource scheduling (cgroup/SoC performance)
        ├── security_config/           # Security configuration (critical processes)
        ├── window_config/             # Window management (display/window manager XML)
        └── updater_config/            # Updater configuration
```

## Development environment setup

### 1. Hardware environment

- Ubuntu 20.04 / 22.04 LTS x86_64, system disk ≥ 200 GB, memory ≥ 16 GB

### 2. Install build dependencies

Follow the [official OpenHarmony documentation](https://gitcode.com/openharmony/docs/blob/master/zh-cn/device-dev/quick-start/quickstart-pkg-install-package.md) to install the required libraries and tools. Key dependencies include:

```bash
sudo apt-get install -y git-lfs git curl python3-pip ccache \
  mtd-utils gcc g++ libssl-dev zlib1g-dev flex bison \
  device-tree-compiler bc u-boot-tools genext2fs e2fsprogs \
  dosfstools mtools libtinfo5 openjdk-11-jdk
```

### 3. Configure Git and Repo

```bash
git config --global user.name "your-name"
git config --global user.email "your-email"

# Install Repo
mkdir ~/bin
curl https://raw.gitcode.com/gitcode-dev/repo/raw/main/repo-py3 -o ~/bin/repo
chmod a+x ~/bin/repo
export PATH=~/bin:$PATH
```

### 4. Install the cross-compilation toolchain

Download the SDK from [Ascend HDK 24.1.RC2](https://ascend-repo.obs.cn-east-2.myhuaweicloud.com/Ascend%20HDK/Ascend%20HDK%2024.1.RC2/Ascend-hdk-310b-sdk-soc_24.1.rc2.zip) and extract its `toolchain.tar.gz`:

```bash
mkdir -p /opt/compiler
tar -xzf toolchain.tar.gz -C /opt/compiler/
echo "export PATH=/opt/compiler/toolchain/bin:\$PATH" >> /etc/profile
source /etc/profile

# Create symlinks so the compiler can be found during builds
sudo ln -sf /opt/compiler/toolchain/bin/aarch64-target-linux-gnu-* /usr/local/bin/
```

## Obtain and build the source

### 1. Download OpenHarmony source

```bash
mkdir -p /opt/ohos && cd /opt/ohos
repo init -u git@gitee.com:openharmony/manifest.git \
  -b refs/tags/OpenHarmony-v5.0.3-Release --no-repo-verify
repo sync -c
repo forall -c 'git lfs pull'
```

### 2. Download prebuilt toolchains

```bash
cd /opt/ohos/build
./prebuilts_download.sh
```

### 3. Place external dependency packages

Put the following three files in the corresponding locations (see the original README document for Baidu Netdisk links):

| File | Location | Description |
|------|----------|------|
| `Ascend-hdk-310b-npu-driver-soc_24.1.rc2_linux-aarch64.run` | `package/` | NPU driver installer |
| `Ascend310B-source-bjjc-ohos.tar.gz` | `package/` | Customized Ascend 310B kernel source |
| `libaarch64.tar.gz` | `device_board_ascend/ascend/310B/ascendinstall/` | ARM64 runtime libraries |

### 4. Run the one-command build

```bash
cd /path/to/QiZhi01-OpenHarmony
sudo ./build.sh /opt/ohos
```

The build process automatically:
1. Checks whether `/opt/ohos` exists (runs `repo init + sync` automatically if absent).
2. Extracts `Ascend310B-source-bjjc-ohos.tar.gz` to `kernel/linux/Ascend310B-5.10/`.
3. Runs `ascend_env.sh` to integrate sources (copies board/SoC/vendor code and applies 43 system patches + 6 DTB patches).
4. Runs `./build.sh --product-name 310B --ccache` for a full build.

The completed build produces `Ascend-hdk-310b-soc_24.1.rc2-harmony_5.0.3-aarch64.zip` in `out/310B/packages/phone/images/`.

### Build outputs

| Image file | Description |
|----------|------|
| `system.img` | System partition image |
| `vendor.img` | Vendor partition image |
| `userdata.img` | User data partition image |
| `updater.img` | Update-mode image |
| `Image_signed` | Signed kernel image |
| `dt.img` | Device tree image |

### Common build issues

- **`'aarch64-target-linux-gnu-gcc' not found`**: Recreate symlinks with `sudo ln -sf /opt/compiler/toolchain/bin/aarch64-target-linux-gnu-* /usr/local/bin/`.
- **Long first build (3–5 hours) / insufficient memory**: Enable build caching with `--ccache`; reduce parallelism or increase swap.
- **Prebuilt toolchain download fails**: Configure a proxy and retry, or copy the `prebuilts` directory from another machine.
- **GN syntax errors**: Use spaces only, never tab indentation; special templates such as `ohos_bpf` do not accept external `cflags`.

## Flash and boot images

### 1. Create and flash the SD card

```bash
# Extract build outputs into the SD creation project
unzip Ascend-hdk-310b-soc_24.1.rc2-harmony_5.0.3-aarch64.zip \
  -d 310BFormatTest/firmware/
mv 310BFormatTest/firmware/*/Image_signed 310BFormatTest/firmware/*/Image

# Flash the SD card
cd 310BFormatTest
./formatSD310B.sh /dev/sdX   # Replace /dev/sdX with the actual SD card device
```

### 2. Upgrade hboot2

Enabling HILOG/HISYSEVENT/BLACKBOX and other features makes the adapted kernel exceed 30 MB. Upgrade hboot2 to raise the kernel partition limit from 30M to 40M:

```bash
./boot-firmware-40M-BJJC.run --full
reboot
```

### 3. First boot

Insert the SD card into the board and connect an HDMI monitor, USB keyboard/mouse, and serial debugging cable (115200 baud). After powering on, check for:
- Kernel boot logs on the serial port
- OpenHarmony boot animation followed by the graphical desktop over HDMI

After startup, verify:

```bash
hdc list targets          # Confirm device connection
hdc shell                  # Enter the shell

# Verify display
ls /dev/dri/                         # Expected: card0
cat /sys/class/drm/card0-HDMI-A-1/status  # Expected: connected

# Verify NPU
/var/Ascend/install_cache/npu-smi info
```

## Install the CANN inference engine

To install CANN 8.2.RC1 Toolkit, copy the installer to the device using a USB drive and run `install_cann.sh`. See the documents in `device_board_ascend/tests/cann/` for detailed steps.

Verify after installation:

```bash
source /etc/profile.d/cann_env.sh

# Verify NPU devices
/var/Ascend/install_cache/npu-smi info

# Verify Python ACL
python3.10 -c "import acl; print('ACL version:', acl.__version__)"

# Verify PyTorch NPU
python3.10 -c "import torch; import torch_npu; print('NPU available:', torch.npu.is_available())"
```

## Architecture details

### Display subsystem

The display driver uses Linux DRM/KMS and the HiSilicon VDP (Video Display Processor) DRM driver (`ascend_vdp_drm.ko`). The userspace Display HDI layer is implemented through HDF.

Core components:
- `hdi_composer`: Main HDI Composer interface
- `drm_connector/crtc/plane/encoder`: DRM device management
- `drm_vsync_worker`: VSync signal synchronization
- `display_gralloc_gbm`: GBM-based graphics memory allocator
- `hi_gbm`: GBM wrapper for the HiSilicon platform

Supports HDMI 1080P output and independent multi-display output (patches 0029–0031).

### GPU graphics acceleration

- **Panfrost kernel driver** (`panfrost.ko`): Open-source Mali G52 GPU driver
- **Mesa3D userspace libraries**: `libEGL.so`, `libGLESv2.so`, `libgbm.so`, `libgallium_dri.so`
- **GPU initialization patch**: `0001-display-mesa3d-init.patch` ensures proper EGL context initialization

### Audio system

Based on ALSA, with the following drivers:
- `ascend_310b_codec.ko`: Audio codec driver
- `ascend_310b_platform_m.ko`: Platform DMA driver
- `ascend_310b_machine.ko`: Machine driver (ALSA sound card registration entry point)

The userspace audio HAL is in `device_board_ascend/ascend/310B/audio_alsa/`; audio policy configuration is in `vendor_ascend/ascend/310B/hals/audio/`.

### Camera system

Based on V4L2:
- `imx219_v4l2.ko`: IMX219 MIPI camera sensor driver
- `ascend_vdp_v4l2.ko`: HiSilicon VDP video capture driver
- Camera HDI Pipeline: codec_node (encoding/decoding), exif_node (EXIF information), face_node (face detection), scale_node (scaling)

### Kernel driver modules

| Category | Module | Function |
|------|------|------|
| Display | `ascend_vdp_drm.ko` | VDP DRM display driver |
| GPU | `panfrost.ko` | Mali G52 GPU driver |
| Audio | `ascend_310b_codec/machine/platform_m.ko` | Audio codec / platform DMA |
| WiFi | `rtl8192cu.ko`、`rtlwifi.ko`、`cfg80211.ko`、`mac80211.ko` | Realtek USB WiFi |
| Bluetooth | `bluetooth.ko`, `ble_soc.ko`, `sle_soc.ko` | Dual-mode BLE/SLE Bluetooth |
| Camera | `imx219_v4l2.ko`, `ascend_vdp_v4l2.ko` | Camera sensor / VDP capture |
| USB | `usb_f_fs.ko` | USB FunctionFS（HDC） |
| Other | `pwm.ko`, `svm.ko`, `rfkill.ko` | PWM / shared virtual memory / RF control |

### System patches (43 patches)

| Subsystem | Patch count | Main changes |
|--------|-----------|----------|
| Build system (build) | 3 | Ascend device build allowlist, camera subsystem allowlist, and build scripts |
| Driver framework (drivers/HDF) | 14 | Remove kernel SEC_FUNCTION, V4L2 camera compatibility, and ALSA audio configuration |
| Base services (base) | 6 | HwUser group, disabling SELinux, power management, and device permissions |
| Graphics and multimedia (foundation) | 16 | GPU EGLImage, Framebuffer format fixes, independent multi-display output, and EGL function fixes |
| Development tools (developtools) | 1 | HDC small-stream transfer policy fix |

## Related documentation

- [Official OpenHarmony 5.0.3 Release documentation](https://gitcode.com/openharmony/docs/blob/OpenHarmony-5.0.3-Release/zh-cn/readme.md)
- [Official Ascend HDK 24.1.RC2 documentation](https://support.huawei.com/enterprise/zh/ascend-computing/ascend-hdk-pid-252764743)
- Accompanying technical documents are the `.docx` files in the parent directory.
- See `device_board_ascend/tests/cann/` for the CANN inference environment setup.
- See `device_board_ascend/tests/audio/` for audio tests.
- See `device_board_ascend/tests/multiscreen/` for multi-display tests.
