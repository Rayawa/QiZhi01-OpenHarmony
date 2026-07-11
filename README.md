# 310b_rc_24.1.rc2_5.0.3

## 概述
310b_rc_24.1.rc2_5.0.3，是基于昇腾310B rc形态[Ascend HDK 24.1.RC2](https://support.huawei.com/enterprise/zh/ascend-computing/ascend-hdk-pid-252764743/software/262029946?idAbsPath=fixnode01%7C23710424%7c251366513%7c22892968%7c252764743)、开源鸿蒙[OpenHamony 5.0.3 release](https://gitcode.com/openharmony/docs/blob/OpenHarmony-5.0.3-Release/zh-cn/release-notes/OpenHarmony-v5.0.3-release.md)的适配代码，在昇腾310B rc形态24.1.RC2的芯片上运行开源鸿蒙OpenHamony 5.0.3 release版本。

310b_rc_24.1.rc2_5.0.3支持以下功能
- GPU图形加速
- Linux kernel 5.10
- usb hdc
- usb camera
- mipi camera
- alsa音频、hdmi音频
- hdmi双屏异显
- CANN推理

## 目录结构

```
├── device_board_ascend    #昇腾310B代码仓库
├── device_soc_ascend      #昇腾310B芯片代码仓库
├── vendor_ascend          #昇腾310B方案定制代码仓库
├── ascend_env.sh          #自动化合patch脚本
├── build.sh               #自动化编译脚本
├── FAQ                    #编译集成常见问题
```
<BR/>

## 搭建开发环境

310b_rc_24.1.rc2_5.0.3支持由源码编译，进行源码编译前，请根据如下步骤完成相关环境准备。

1. **硬件环境**

    准备装有ubuntu系统X86的环境，系统硬盘大于200G

2. **安装库和工具集**

    请参考官方 [相关链接](https://gitcode.com/openharmony/docs/blob/master/zh-cn/device-dev/quick-start/quickstart-pkg-install-package.md)

3. **配置git账户信息**

    ```bash
    git config --global user.name "your-name"
    git config --global user.email "your-email-address"
    git config --global credential.helper store
    ```

4. **安装码云repo工具，可以执行如下命令**

    ```bash
    mkdir ~/bin
    curl https://raw.gitcode.com/gitcode-dev/repo/raw/main/repo-py3 -o ~/bin/repo 
    chmod a+x ~/bin/repo
    pip3 install -i https://repo.huaweicloud.com/repository/pypi/simple requests
    # 将repo添加到环境变量
    vim ~/.bashrc 
    export PATH=~/bin:$PATH 
    source ~/.bashrc 
    ```

5. **安装编译内核交叉工具链**

    上传Ascend-hdk-310b-sdk-soc_24.1.rc2.zip [Ascend HDK 24.1.RC2](https://ascend-repo.obs.cn-east-2.myhuaweicloud.com/Ascend%20HDK/Ascend%20HDK%2024.1.RC2/Ascend-hdk-310b-sdk-soc_24.1.rc2.zip) 中的toolchain.tar.gz至`/opt`

    ```bash
    mkdir /opt/compiler
    echo "export PATH=/opt/compiler/toolchain/bin:\$PATH: " >> /etc/profile
    source /etc/profile
    cp toolchain/ /opt/compiler/ -rf
    ```

## 源码下载

执行如下命令，下载310b_rc_24.1.rc2_5.0.3仓源码：
通过repo + ssh 下载（需注册公钥，请参考码云帮助中心）。

1. 从版本分支获取源码。可获取该版本分支的最新源码，包括版本发布后在该分支的合入。

    ```bash
    repo init -u git@gitee.com:openharmony/manifest.git -b OpenHarmony-5.0.3-Release --no-repo-verify
    repo sync -c
    repo forall -c 'git lfs pull'
    ```

2. 从版本发布Tag节点获取源码。可获取与版本发布时完全一致的源码。

    ```bash
    repo init -u git@gitee.com:openharmony/manifest.git -b refs/tags/OpenHarmony-v5.0.3-Release --no-repo-verify
    repo sync -c
    repo forall -c 'git lfs pull'
    ```

## 文件替换
下载package/Ascend-hdk-310b-npu-driver-soc_24.1.rc2_linux-aarch64.run文件

[文件下载地址](https://pan.baidu.com/s/1p-qdAfgIWjiZqohhval7ow?pwd=6755)

下载package/Ascend310B-source-bjjc-ohos.tar.gz文件

[文件下载地址](https://pan.baidu.com/s/191oiOvTvmKQqhmU0iJesTA?pwd=ys5p)

下载device_board_ascend/ascend/310B/ascendinstall/libaarch64.tar.gz文件

[文件下载地址](https://pan.baidu.com/s/1MStN-BV0YdoS2XotxhFWFw?pwd=sbr4)

## 执行预构建脚本

进入源码目录，执行以下命令，这里以/opt/ohos为例：（可以替换为读者的源码目录）

  ```bash

  cd /opt/ohos/build

  ./prebuilts_download.sh

  ```

## 编译制作镜像

1. 编译

    310b_rc_24.1.rc2_5.0.3仓提供一键式编译安装能力，进入本源码仓代码根目录，执行build.sh，后面跟OpenHamony源码根目录，这里以/opt/ohos为例：

    ```bash
    sudo ./build.sh /opt/ohos
    ```

    编译完成后会在`/opt/ohos/out/310B/packages/phone/images`目录下生成Ascend-hdk-310b-soc_24.1.rc2-harmony_5.0.3-aarch64.zip包。

  `提示`：编译失败的处理方式   
    (1). 编译失败，可能需要打入下面的patch：
    
    https://gitee.com/phytium_embedded/phytium-openharmony-device/blob/5.x_release/device_board_phytium/common/patch/0032=foundation-arkui-napi=fix_libjsvm_may_compile_fail.patch

  (2).如果在编译过程中提示'aarch64-target-linux-gnu-gcc'等相关的aarch64-target-linux-*错误

  ```
  [OHOS ERROR] scripts/Kconfig.include:39: compiler 'aarch64-target-linux-gnu-gcc' not found

  [OHOS ERROR] make[1]: *** [scripts/kconfig/Makefile:88: ascend310B_ohos_defconfig] Error 1

  [OHOS ERROR] make: *** [Makefile:634: ascend310B_ohos_defconfig] Error 2

  ```

  创建软链接到系统 PATH 目录,将编译内核交叉工具链,链接到 /usr/local/bin（系统默认 PATH）  
  ```
  sudo ln -sf /opt/compiler/toolchain/bin/aarch64-target-linux-gnu-* /usr/local/bin/
  ```

  注意：需要将/opt/compiler/toolchain/bin替换为读者安装时对应的目录。

2. 镜像制作
    下载制卡工程`device_board_ascend/310BFormatTest`到ubuntu环境

    将编译生成镜像Ascend-hdk-310b-soc_24.1.rc2-harmony_5.0.3-aarch64.zip解压到`310BFormatTest/firmware`     
    在310BFormatTest/firmware目录中，修改Image_signed文件的名称为Image   

    将sd卡连上虚拟机或者服务器，执行如下命令：

    ```bash
    cd 310BFormatTest
    ./formatSD310B.sh /dev/sdX
    ```

## 将hboot2内核大小限制从30M升为40M

由于310B适配OpenHarmony的过程中，内核打开了CONFIG_HILOG、CONFIG_HISYSEVENT、CONFIG_BLACKBOX等开关，
导致内核大小超过30M，需要更新hboot2将内核大小限制从30M升为40M

将device_board_ascend/tools/boot-firmware-40M/boot-firmware-40M-BJJC.run拷贝到ubuntu的板子上
```
./boot-firmware-40M-BJJC.run --full
reboot
```

## 升级hboot2和atf说明(废弃，直接用上面的即可)

    由于310B适配OpenHarmony的过程中，内核打开了CONFIG_HILOG、CONFIG_HISYSEVENT、CONFIG_BLACKBOX等开关，导致内核大小超过30M，需要更新hboot2将内核大小限制从30M升为40M。

将`device_board_ascend/tools/boot-firmware-40M/`下的文件拷贝到ubuntu的板子上，启动后执行以下命令：

```bash
/var/davinci/driver/upgrade-tool --device_index -1 --component hboot2 --path ./AS310B_HBOOT2_UEFI.fd
/var/davinci/driver/upgrade-tool --device_index -1 --component atf --path ./TrustedFirmware.bin
```

## 设备首次启动操作(废弃)

    将烧写好的sd卡和调试串口线，连接到开发板上。上位机的串口调试工具波特率设置为115200。
    设备首次启动后执行以下命令：

```bash
mount -o remount,rw /
cd /system/var
chmod +x init.sh
./init.sh
reboot
```


## 其他修改说明
    单独编译kernel命令
```bash
cd out/310B && bash ../../device/board/ascend/310B/kernel/build_kernel.sh ../../kernel/linux/linux-5.10 /root/code/ohos_5.0.3/out/310B/packages/phone/images /root/code/ohos_5.0.3/device/board/ascend/310B vendor/ascend/310B /root/code/ohos_5.0.3 ascend 310B ascend

#烧写镜像
dd if=Image_signed of=/dev/sda count=71680 seek=32768 bs=512
```

    如果需要支持U盘安装hap程序，需要使能console控制台权限，修改/system/etc/init/console.cfg文件内容如下
```bash
{
    "services" : [{
            "name" : "console",
            "path" : ["/system/bin/sh"],
            "start-mode" : "condition",
            "disabled" : 1,
            "console" : 1,
            "sandbox" : 0,
            "uid" : "root",
            "gid" : ["shell", "log", "readproc"],
            "ondemand" : true,
            "jobs" : {
                "on-start" : "services:console"
            },
            "secon" : "u:r:console:s0",
            "permission" : [
                "ohos.permission.INSTALL_BUNDLE"
            ],
            "permission_acls" : [
                "ohos.permission.INSTALL_BUNDLE"
            ]
        }
    ]
}
```
    使用wq!强制保存

    U盘安装hap程序命令为
```
bm install -p Browser.hap
```

## 命令说明
    支持fdisk命令，可使用fdisk -l参看磁盘挂在情况，可挂载U盘
 ```bash
cd /bin
ln -s busybox fdisk

#挂载U盘
mkdir /mnt/sdcard
mount /dev/sda1 /mnt/sdcard

#卸载U盘
umount /mnt/sdcard
 ```

    查看音频设备列表
```bash
arecord -l
aplay -l
```

    查看npu信息
```bash
/var/Ascend/install_cache/npu-smi info
/var/Ascend/install_cache/npu-smi info -t pwm-duty-ratio
```

    串口调试命令
```bash
#最好在hdc终端运行，支持ctrl+c退出
hdc shell
microcom -s 115200 /dev/ttyAMA1
```

    独立编译kernel
```bash
cd out/310B && bash ../../device/board/ascend/310B/kernel/build_kernel.sh ../../kernel/linux/linux-5.10 /root/code/ohos_5.0.3/out/310B/packages/phone/images /root/code/ohos_5.0.3/device/board/ascend/310B vendor/ascend/310B /root/code/ohos_5.0.3 ascend 310B ascend

cd out/310B/packages/phone/images/

dd if=Image_signed of=/dev/sda count=71680 seek=32768 bs=512
```