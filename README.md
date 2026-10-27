# QiZhi01-OpenHarmony

English | [简体中文](README_zh.md)

OpenHarmony board integration, drivers and build tools for the QiZhi01 Ascend 310B kit.

## Overview

The repository integrates board, SoC and vendor code with an external OpenHarmony source tree. It includes system patches, graphics/camera/audio adaptations, Ascend runtime support and hardware test utilities. Complete images depend on separately obtained source, drivers and firmware packages.

## Technology and Dependencies

OpenHarmony 5.0.3 Release, Ascend 310B and HDK 24.1.RC2 form the documented baseline. Build scripts require a Linux host, the OpenHarmony toolchain and the packages listed in `package/readme.md`. CANN tests require the corresponding runtime and models.

## Repository Structure

- `device_board_ascend/` — board integration, patches and tests
- `device_soc_ascend/` — SoC integration
- `vendor_ascend/` — product configuration
- `package/` — external package instructions
- `ascend_env.sh` — source-tree integration
- `build.sh` — build orchestration

## Quick Start

1. Prepare a Linux OpenHarmony build host and review [package/readme.md](package/readme.md) for separately distributed inputs.
2. Read `build.sh` and `ascend_env.sh`, then select a dedicated OpenHarmony workspace for source download, integration and build outputs.
3. The documented build entry is `sudo ./build.sh /path/to/openharmony-workspace`; inspect the script's privileged operations and package requirements before invoking it.
4. Review the board-specific image/SD-card instructions only after a successful build. Hardware tests are documented under `device_board_ascend/tests/`.

This repository is not a standalone desktop application, and copying the board code alone does not produce a bootable system.
