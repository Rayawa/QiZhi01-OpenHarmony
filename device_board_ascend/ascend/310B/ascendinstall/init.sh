#!/bin/sh
devmem 0xc42e0000 8 0x0
mount -o remount,rw /
DEFAULT_DRIVER_PACKAGE=$(ls /system/var/Ascend*310*driver*.*)
Ascend_sdk=$1

bash_env_init() {
    chmod +x /system/bin/busybox
    chmod +x /system/bin/bash
    rm -rf /system/bin/vi
    ln -s /system/bin/busybox /system/bin/vi
    rm -rf /system/bin/modprobe
    ln -s /system/bin/busybox /system/bin/modprobe
    rm -rf /system/bin/awk
    ln -s /system/bin/busybox /system/bin/awk
    rm -rf /system/bin/mkdir
    ln -s /system/bin/busybox /system/bin/mkdir
    rm -rf /system/bin/grep
    ln -s /system/bin/busybox /system/bin/grep
    rm -rf /system/bin/tr
    ln -s /system/bin/busybox /system/bin/tr
    rm -rf /system/bin/sha256sum
    ln -s /system/bin/busybox /system/bin/sha256sum
    rm -rf /system/bin/expr
    ln -s /system/bin/busybox /system/bin/expr
    rm -rf /Ascend_hdk
}

ascend_init() {
    if [ -e "$Ascend_sdk" ]; then
        echo "install ${Ascend_sdk} hdk run"
        bash "$Ascend_sdk" --noexec --extract=/Ascend_hdk
    elif [ -e "$DEFAULT_DRIVER_PACKAGE" ]; then
        echo "install ${DEFAULT_DRIVER_PACKAGE} hdk run"
        bash "$DEFAULT_DRIVER_PACKAGE" --noexec --extract=/Ascend_hdk
    else
        echo "没有可用的hdk run"
        exit 1
    fi
    cp /system/var/Ascend_hdk_install.sh /Ascend_hdk/scripts/install.sh
    cd /Ascend_hdk
    ./scripts/install.sh -- -- --full
    cd /system/var/
    cp install_filelists.sh /var/Ascend/install_cache
    cp install_dev.sh /var/Ascend/install_cache
    cp minirc_sys_init.sh /var/Ascend/install_cache/scripts
    cp ascend_common_init.sh /var/Ascend/install_cache/scripts
    cd /var/Ascend/install_cache
    sh install_filelists.sh && sh install_dev.sh

    pgrep slogd && kill -9 $(pgrep slogd)
    cp /var/slogd /bin/slogd
    pgrep sklogd && kill -9 $(pgrep sklogd)
    cp /var/sklogd /bin/sklogd
    pgrep log-daemon && kill -9 $(pgrep log-daemon)
    cp /var/log-daemon /bin/log-daemon
    pgrep dmp_daemon && kill -9 $(pgrep dmp_daemon)
    cp /var/dmp_daemon /bin/dmp_daemon
    chown HwDmUser:HwDmUser /bin/dmp_daemon
    pgrep proc_launcher && kill -9 $(pgrep proc_launcher)
    cp /usr/bin/mdc/base-plat/process-manager/proc_launcher /bin/proc_launcher
    pgrep iammgr && kill -9 $(pgrep iammgr)
    cp /usr/bin/mdc/base-plat/aosservice/iammgr /bin/iammgr
    pgrep teecd && kill -9 $(pgrep teecd)
    cp /var/teecd /bin/teecd
    pgrep tlogcat && kill -9 $(pgrep tlogcat)
    cp /var/tlogcat /bin/tlogcat

    cd /var/davinci/
    rm -fr scripts
    ln -s /var/Ascend/install_cache/scripts scripts
    cd -

    mkdir -p /dev/shm/dmp -m 750 && chown -Rf HwDmUser:HwDmUser /dev/shm/dmp
    chown -Rf HwDmUser:HwDmUser /etc/sys_version.conf
    cp /var/Ascend/install_cache/*ko /var/davinci/driver

    tar -xvf /system/var/libaarch64.tar.gz -C /
    rm /system/var/libaarch64.tar.gz

    cp /libaarch64/aarch64-linux-gnu/ld-linux-aarch64.so.1 /system/lib64
    cp /libaarch64/aarch64-linux-gnu/ld-linux-aarch64.so.1 /system/lib
    mv /system/var/davinci/driver/* /var/davinci/driver/
    
    cp /system/var/ws73_cfg.ini /etc
    mkdir -p /etc/ws73
    cp /system/var/btc_cali.bin /etc/ws73
    cp /system/var/wifi_cali.bin /etc/ws73
    cp /system/var/wow.bin /etc/ws73
    cp /system/var/ws73.bin /etc/ws73
    
    mkdir -p /opt
    mv /system/var/qizhi_test.tar.gz /opt
    cd /opt
    tar -xzvf qizhi_test.tar.gz
    rm qizhi_test.tar.gz
}

ohos_modify() {
    mv -f /system/var/init.cfg /etc
    mv /system/etc/Camera.hap /system/app/com.ohos.camera/
    mv /system/etc/Music_Demo.hap /system/app/com.ohos.distributedmusicplayer/
}

bash_env_init

ohos_modify

ascend_init