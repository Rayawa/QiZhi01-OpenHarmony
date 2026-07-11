#!/bin/bash
# ************************Variable*********************************************
ScriptPath="$( cd "$(dirname "$0")" ; pwd -P )""/"
DEV_NAME=$1
MAKECONF="mksd.conf"
FWM_DIR="${ScriptPath}firmware/"
MAKE_IMGPK_FLAG="off"
SD_DEV_MOUNT="${ScriptPath}sd_dev_mount/"
ASCEND_DRIVER_PACKAGE=$2
ASCEND_SECLOG="${SD_DEV_MOUNT}/var/log/ascend_seclog"
logFile="${ASCEND_SECLOG}/ascend_install.log"
Install_Cache_Path_Param="${SD_DEV_MOUNT}/var/Ascend/install_cache"

sectorEnd=`fdisk -l | grep "$DEV_NAME:" | awk -F ' ' '{print $7}'`
sectorSize=`fdisk -l | grep -A 2 "$DEV_NAME:" | grep "Units" | awk -F ' ' '{print $6}'`
if [ $sectorSize -ne 512 ];then
    echo "Failed: sector size is not 512!"
    exit 1
fi

log() {
    cur_date=`date +"%Y-%m-%d %H:%M:%S"`
    if [ "$install_in_sd" == "n" ];then
        echo "[Driver] [$cur_date] $1" >> $logFile
    else
        echo "[Driver] [$cur_date] $1"
    fi
}

function initUbootPartData()
{
    # 822083584 bytes is 784M
    sectorRsv=$[822083584/sectorSize+1]
    #format card need reserver 100 sector
    sectorEnd=$[sectorEnd-100]
    # 16777216 bytes is 16M, reserved for struct info
    BOOTIMG_OFFSET_A=$[16777216/sectorSize]
    #150994944 bytes is 144M, reserved for kernel/dtb/tee
    BOOTIMG_OFFSET_B=$[150994944/sectorSize]
    #285212672 bytes is 272M, reserved for kernel/dtb/tee bak
    RECOVER_BOOTIMG_OFFSET_E=$[285212672/sectorSize]
    #553648128 bytes is 528M, reserved for kernel/dtb/initrd
    RECOVER_BOOTIMG_OFFSET_F=$[553648128/sectorSize]
    #0 30M
    IMAGE_OFFSET=0
    IMAGE_SIZE=71680
    #40M 2M
    DTB_OFFSET=81920
    DTB_SIZE=4096
    #44M 2M
    TEE_OFFSET=90112
    TEE_SIZE=4096
    #48M 80M
    INITRD_OFFSET=98304
    INITRD_SIZE=163840
    # end
    return 0
}

# ************************configure*********************************************
# Description:  configure
# ******************************************************************************
function checkSystemPartConfig()
{
    source ${MAKECONF} || \
        { echo "Failed: ${MAKECONF} may has something wrong, please check and repair." && return 1; }
    echo "record ${MAKECONF}" && cat ${MAKECONF}
    return 0
}

# ************************umount SD Card****************************************
# Description:  check sd card mount, if mounted, umount it
# ******************************************************************************
function checkSDCard()
{
    paths=`df -h | grep "$DEV_NAME" | awk -F ' ' '{print $6}'`
    for path in $paths
    do
        echo "umount $path"
        umount $path
        if [ $? -ne 0 ];then
            echo "Failed: umount $path failed!"
            return 1
        fi
    done
    return 0
}
#end

function DIYFormatSDcard()
{
    cnt=0
    #Five partitions are reserved.
    constPNum=5
    while read line
    do
        flag=`echo "$line" | awk -F "=" '{print $1}'`
        if [ "$flag"x == "OFFSIZE"x ];then
            offsize=`echo "$line" | awk '{print $1}' | awk -F "=" '{print $2}'`
            end=`echo "$line" | awk '{print $2}' | awk -F "=" '{print $2}'`
            if [[ "$offsize" -gt "0" ]] && [[ "$end" -gt "$offsize" ]];then
                DIYOffset=$[offsize*sectorOffset_1M]
                DIYEnd=$[end*sectorOffset_1M-1]
                if [[ $DIYEnd -ge $sectorEnd ]];then
                    echo "Failed: SD/eMMC capacity is less than user Configuration, please reconfigure and make later"
                    return 1;
                fi
                cnt=$[cnt+1]
                p_num=$[constPNum+cnt]

                add_list+=" mkpart p$p_num $DIYOffset$sectorUnit $DIYEnd$sectorUnit "
            fi
        fi
    done < ${MAKECONF}
}

function formatSDcard310B()
{
    sectorOffset_1M=$[1024*1024/sectorSize]
    #p1 need reserved 100M space
    sectorRsvP1=$[100*sectorOffset_1M]
    # End1:100M+784M-1
    sectorOffset1=$sectorRsv
    sectorEnd1=$[sectorRsvP1+sectorOffset1-1]
    # End2: SYSTEM_PART_SIZE + 884M - 1
    sectorOffset2=$[sectorEnd1+1]
    sectorEnd2=$[sectorOffset2+SYSTEM_PART_SIZE*sectorOffset_1M-1]
    # End3: SYSTEM_PART_SIZE*2 + 884M - 1
    sectorOffset3=$[sectorEnd2+1]
    sectorEnd3=$[sectorOffset3+SYSTEM_PART_SIZE*sectorOffset_1M-1]
    if [ "$FS_BACKUP_FLAG"x = "off"x ];then
        #reserved 100M space for p3
        sectorEnd3=$[sectorOffset3+100*sectorOffset_1M-1]
    fi
    # End4: SYSTEM_PART_SIZE + p3 + VENDOR_PART_SIZE + 884M - 1
    sectorOffset4=$[sectorEnd3+1]
    sectorEnd4=$[sectorOffset4+VENDOR_PART_SIZE*sectorOffset_1M-1]
    # End5: SYSTEM_PART_SIZE + p3 + VENDOR_PART_SIZE + USERDATA_PART_SIZE + 884M - 1
    sectorOffset5=$[sectorEnd4+1]
    sectorEnd5=$[sectorOffset5+USERDATA_PART_SIZE*sectorOffset_1M-1]

    # End6: SYSTEM_PART_SIZE + p3 + VENDOR_PART_SIZE + USERDATA_PART_SIZE + UPDATER_PART_SIZE + 884M - 1
    sectorOffset6=$[sectorEnd5+1]
    sectorEnd6=$[sectorOffset6+UPDATER_PART_SIZE*sectorOffset_1M-1]

    # End7: SYSTEM_PART_SIZE + p3 + VENDOR_PART_SIZE + USERDATA_PART_SIZE + UPDATER_PART_SIZE + RESERVE_PART_SIZE + 884M - 1
    sectorOffset7=$[sectorEnd6+1]
    sectorEnd7=$[sectorOffset7+RESERVE_PART_SIZE*sectorOffset_1M-1]
    

    sectorUnit="s"
    parted $DEV_NAME -s mklabel gpt
    ex_p_n=`parted $DEV_NAME -s p | sed -n '/p2/,$p' | awk '{print $1}'`
    for i in $ex_p_n
    do
        rm_list+="rm ${i}"
    done
    echo rm_list: ${rm_list}
    add_list+="mkpart p1 $sectorOffset1$sectorUnit $sectorEnd1$sectorUnit "
    add_list+="mkpart p2 $sectorOffset2$sectorUnit $sectorEnd2$sectorUnit "
    add_list+="mkpart p3 $sectorOffset3$sectorUnit $sectorEnd3$sectorUnit "
    add_list+="mkpart p4 $sectorOffset4$sectorUnit $sectorEnd4$sectorUnit "
    add_list+="mkpart p5 $sectorOffset5$sectorUnit $sectorEnd5$sectorUnit "
    add_list+="mkpart p6 $sectorOffset6$sectorUnit $sectorEnd6$sectorUnit "
    add_list+="mkpart p7 $sectorOffset7$sectorUnit $sectorEnd7$sectorUnit "

    DIYFormatSDcard
    echo add_list: ${add_list}
    parted $DEV_NAME -s ${rm_list} ${add_list}
    ret=$?
    if [ $ret -ne 0 ];then
        echo "Failed: parted $DEV_NAME -s ${rm_list} ${add_list} failed !"
        return 1
    fi
    ext4_list=`parted $DEV_NAME -s p | sed -n '/p2/,$p' | awk '{print $1}'`
    for i in $ext4_list
    do
        mkfs.ext4 -F $DEV_NAME${i}
        if [[ $? -ne 0 ]];then
            echo "Failed: Format SDcard${i} failed!"
            return 1;
        fi
    done
}

function updateStructInfo()
{
    if [ ! -f ${ScriptPath}tools/emmc-head ];then
        echo "failed: emmctool no exist"
        return 1
    fi

    if [ -f ${ScriptPath}boot_image_info ]; then
        rm ${ScriptPath}boot_image_info
    fi
	
    if [ -f ${FWM_DIR}Image_signed ];then
        mv ${FWM_DIR}Image_signed ${FWM_DIR}Image
    fi
    uuid2=`blkid ${DEV_NAME}2 -s PARTUUID | awk -F ' ' '{print $2}' | sed 's/\"//g'`
    uuid3=`blkid ${DEV_NAME}3 -s PARTUUID | awk -F ' ' '{print $2}' | sed 's/\"//g'`
    echo "test=========${uuid2} ${uuid3}"
    ${ScriptPath}tools/emmc-head ${ScriptPath}firmware/ ${uuid2} ${uuid2}
    if [[ $? -ne 0 ]];then
        echo "failed: updateStructInfo failed"
        return 1
    fi

}

function writeStructInfo()
{
    DEST_DEV=${DEV_NAME}
    if [ "$MAKE_IMGPK_FLAG"x = "on"x ];then
        DEST_DEV=$loopdevice
    fi
    if [ ! -f ${ScriptPath}parttion_head_info ];then
        echo "failed: parttion_head_info no exist"
        return 1
    fi
    if [ ! -f ${ScriptPath}boot_image_info ];then
        echo "failed: boot_image_info no exist"
        return 1
    fi

    #1M
    HEAD_OFFSET=2048
    #1M+64K
    HEAD_BAK_OFFSET=2176
    #1M+128K
    BOOTIMGDIR_OFFSET=2304
    #2M+128K
    BOOTCRL_OFFSET=4352

    dd if=${ScriptPath}parttion_head_info of=${DEST_DEV} seek=$[HEAD_OFFSET] count=2 bs=512
    dd if=${ScriptPath}parttion_head_info of=${DEST_DEV} seek=$[HEAD_BAK_OFFSET]  count=2 bs=512
    dd if=${ScriptPath}boot_image_info of=${DEST_DEV} seek=$[BOOTIMGDIR_OFFSET] count=8 bs=512
}

function write310BComponents()
{
    FWM_DIR="${ScriptPath}firmware/"
    OF_DIR=$1
    DEST_DEV=${DEV_NAME}

    if [ ! -f ${FWM_DIR}Image ];then
        echo "failed: kernel Image no exist"
        return 1
    fi

    if [ ! -f ${FWM_DIR}dt.img ];then
        echo "failed: dt.img no exist"
        return 1
    fi

    if [ ! -f ${FWM_DIR}itrustee.img ];then
        echo "failed: itrustee.img no exist"
        return 1
    fi

    dd if=${FWM_DIR}Image of=${DEST_DEV} count=$IMAGE_SIZE seek=$[OF_DIR+IMAGE_OFFSET] bs=$sectorSize
    if [ $? -ne 0 ];then
        echo "failed: $OF_DIR Image"
        return 1
    fi
    dd if=${FWM_DIR}dt.img of=${DEST_DEV} count=$DTB_SIZE seek=$[OF_DIR+DTB_OFFSET] bs=$sectorSize
    if [ $? -ne 0 ];then
        echo "failed: $OF_DIR dt"
        return 1
    fi
    dd if=${FWM_DIR}itrustee.img of=${DEST_DEV} count=$TEE_SIZE seek=$[OF_DIR+TEE_OFFSET] bs=$sectorSize
    if [ $? -ne 0 ];then
        echo "failed: $OF_DIR itrustee"
        return 1
    fi
    if [[ $OF_DIR =~ "RECOVER" ]];then
        dd if=${FWM_DIR}initrd of=${DEST_DEV} count=$INITRD_SIZE seek=$[OF_DIR+INITRD_OFFSET] bs=$sectorSize
        if [ $? -ne 0 ];then
            echo "failed: $OF_DIR initrd"
            return 1
        fi
    fi

}

function write310BOHimg()
{
    FWM_DIR="${ScriptPath}firmware/"
    DEST_DEV=${DEV_NAME}

    if [ ! -f ${FWM_DIR}system.img ];then
        echo "failed: system.img no exist"
        return 1
    fi

    if [ ! -f ${FWM_DIR}vendor.img ];then
        echo "failed: vendor.img no exist"
        return 1
    fi

    if [ ! -f ${FWM_DIR}userdata.img ];then
        echo "failed: userdata.img no exist"
        return 1
    fi

    if [ ! -f ${FWM_DIR}updater.img ];then
        echo "failed: updater.img no exist"
        return 1
    fi

    dd if=${FWM_DIR}system.img of=${DEST_DEV}2 bs=4M status=progress
    if [ $? -ne 0 ];then
        echo "failed: ${DEST_DEV}2 system.img"
        return 1
    fi

    dd if=${FWM_DIR}vendor.img of=${DEST_DEV}4 bs=4M status=progress
    if [ $? -ne 0 ];then
        echo "failed: ${DEST_DEV}4 vendor.img"
        return 1
    fi

    dd if=${FWM_DIR}userdata.img of=${DEST_DEV}5 bs=4M status=progress
    if [ $? -ne 0 ];then
        echo "failed: ${DEST_DEV}5 userdata.img"
        return 1
    fi

    dd if=${FWM_DIR}updater.img of=${DEST_DEV}6 bs=4M status=progress
    if [ $? -ne 0 ];then
        echo "failed: ${DEST_DEV}6 updater.img"
        return 1
    fi
}

function expandPartedSD()
{
	SYSTEM_SIZE=$[SYSTEM_PART_SIZE/1024]
	e2fsck -f ${DEST_DEV}2
	resize2fs ${DEST_DEV}2 ${SYSTEM_SIZE}G
}

function config310BComponents()
{
    writeStructInfo

    write310BComponents BOOTIMG_OFFSET_A
    if [ $? -ne 0 ];then
        echo "Failed: writeComponents BOOTIMG_A"
        return 1
    fi
    write310BComponents BOOTIMG_OFFSET_B
    if [ $? -ne 0 ];then
        echo "Failed: writeComponents BOOTIMG_B"
        return 1
    fi
}

function mountSystemLocal()
{
    if [ ! -d ${SD_DEV_MOUNT} ]; then
        mkdir -p ${SD_DEV_MOUNT}
    fi
    mount -o rw ${DEST_DEV}2 ${SD_DEV_MOUNT}
    if [[ $? -ne 0 ]];then
        echo "Failed: mount ${DEST_DEV}2 ${SD_DEV_MOUNT} fail!"
        return 1;
    fi

    return 0
}

function cancelMountSystemLocal()
{
    cd ${ScriptPath}
	umount ${SD_DEV_MOUNT}
    if [[ $? -ne 0 ]];then
        echo "Failed: unmount ${SD_DEV_MOUNT} fail!"
        return 1;
    fi
}

function bash_env_init() {
    cd ${SD_DEV_MOUNT}/system/bin
    chmod +x busybox
    chmod +x bash
    rm -rf vi
    ln -s busybox vi
    rm -rf modprobe
    ln -s busybox modprobe
    rm -rf awk
    ln -s busybox awk
    rm -rf mkdir
    ln -s busybox mkdir
    rm -rf grep
    ln -s busybox grep
    rm -rf tr
    ln -s busybox tr
    rm -rf sha256sum
    ln -s busybox sha256sum
    rm -rf expr
    ln -s busybox expr
    cd -
}

function createFolder() {
    if [ ! -d ${SD_DEV_MOUNT}/var/log ]; then
        mkdir -p ${SD_DEV_MOUNT}/var/log
        chmod 755 ${SD_DEV_MOUNT}/var/log
    fi

    if [ ! -d "${ASCEND_SECLOG}" ]; then
        mkdir -p ${ASCEND_SECLOG}
        chmod 750 ${ASCEND_SECLOG}
    fi
}

function changeLogMode() {
    if [ ! -f $logFile ]; then
        touch $logFile
    fi
    chmod 640 $logFile
}

function extrack_package() {
    if [ -d $Install_Cache_Path_Param ]; then
        rm -rf $Install_Cache_Path_Param
        log "[INFO]Exsit install cache directory, delete the original directory."
    fi
    mkdir -p $Install_Cache_Path_Param
    cp -rf ${SD_DEV_MOUNT}/Ascend_hdk/* $Install_Cache_Path_Param/
    if [ $? -ne 0 ]; then
        return 1
    else
        log "[INFO]Extrack package success."
        return 0
    fi
}

function copy_ascend_services() {
    cp ${SD_DEV_MOUNT}/var/slogd ${SD_DEV_MOUNT}/system/bin/slogd
    chroot ${SD_DEV_MOUNT} /system/bin/sh -c "chown HwHiAiUser:HwHiAiUser /system/bin/slogd"
    cp ${SD_DEV_MOUNT}/var/sklogd ${SD_DEV_MOUNT}/system/bin/sklogd
    chroot ${SD_DEV_MOUNT} /system/bin/sh -c "chown HwHiAiUser:HwHiAiUser /system/bin/sklogd"
    cp ${SD_DEV_MOUNT}/var/log-daemon ${SD_DEV_MOUNT}/system/bin/log-daemon
    chroot ${SD_DEV_MOUNT} /system/bin/sh -c "chown HwHiAiUser:HwHiAiUser /system/bin/log-daemon"
    cp ${SD_DEV_MOUNT}/var/dmp_daemon ${SD_DEV_MOUNT}/system/bin/dmp_daemon
    chroot ${SD_DEV_MOUNT} /system/bin/sh -c "chown HwDmUser:HwHiAiUser /system/bin/dmp_daemon"
    cp ${SD_DEV_MOUNT}/usr/bin/mdc/base-plat/process-manager/proc_launcher ${SD_DEV_MOUNT}/system/bin/proc_launcher
    chroot ${SD_DEV_MOUNT} /system/bin/sh -c "chown HwBaseUser:HwBaseUser /system/bin/proc_launcher"
    cp ${SD_DEV_MOUNT}/usr/bin/mdc/base-plat/aosservice/iammgr ${SD_DEV_MOUNT}/system/bin/iammgr
    chroot ${SD_DEV_MOUNT} /system/bin/sh -c "chown HwBaseUser:HwBaseUser /system/bin/iammgr"
    
    cp ${SD_DEV_MOUNT}/var/teecd ${SD_DEV_MOUNT}/system/bin/teecd
    cp ${SD_DEV_MOUNT}/var/tlogcat ${SD_DEV_MOUNT}/system/bin/tlogcat
}

function updateDriverRun()
{
    mountSystemLocal
    res=$(echo $?)
	if [[ ${res} != "0" ]];then
        echo "mountSystemLocal fail, error code:${res}"
        return 1
    fi
    DEFAULT_DRIVER_PACKAGE=$(ls ${SD_DEV_MOUNT}/system/var/Ascend*310*driver*.*)
    if [ -e "$ASCEND_DRIVER_PACKAGE" ]; then
        echo "install ${ASCEND_DRIVER_PACKAGE} hdk run"
        rm -rf ${SD_DEV_MOUNT}/Ascend_hdk
        bash "$ASCEND_DRIVER_PACKAGE" --noexec --extract=${SD_DEV_MOUNT}/Ascend_hdk
    elif [ -e "$DEFAULT_DRIVER_PACKAGE" ]; then
        echo "install ${DEFAULT_DRIVER_PACKAGE} hdk run"
        rm -rf ${SD_DEV_MOUNT}/Ascend_hdk
        bash "$DEFAULT_DRIVER_PACKAGE" --noexec --extract=${SD_DEV_MOUNT}/Ascend_hdk
    else
        echo "没有可用的hdk run"
	cancelMountSystemLocal
        exit 1
    fi
    bash_env_init
    createFolder
    changeLogMode
    extrack_package
    chmod 550 $Install_Cache_Path_Param/scripts/*
    mkdir -p ${SD_DEV_MOUNT}/usr/local/scripts/

    rm -rf ${SD_DEV_MOUNT}/system/lib/modules/5.10.0+
    mkdir -p ${SD_DEV_MOUNT}/system/lib/modules/
    tar --no-same-owner -xvf ${Install_Cache_Path_Param}/modules.tar.gz -C ${SD_DEV_MOUNT}/system/lib/modules/ >/dev/null 2>&1
    rm -rf ${SD_DEV_MOUNT}/system/lib/modules/5.10.0+/kernel/drivers/watchdog/sbsa_gwdt.ko
    mkdir -p ${SD_DEV_MOUNT}/var/Ascend/install_cache
    cp -rf $Install_Cache_Path_Param/* ${SD_DEV_MOUNT}/var/Ascend/install_cache/

    cd ${SD_DEV_MOUNT}/system/var/
    
    cp ws73_cfg.ini ${SD_DEV_MOUNT}/system/etc
    mkdir -p ${SD_DEV_MOUNT}/system/etc/ws73
    cp btc_cali.bin ${SD_DEV_MOUNT}/system/etc/ws73
    cp wifi_cali.bin ${SD_DEV_MOUNT}/system/etc/ws73
    cp wow.bin ${SD_DEV_MOUNT}/system/etc/ws73
    cp ws73.bin ${SD_DEV_MOUNT}/system/etc/ws73
    
    mkdir -p ${SD_DEV_MOUNT}/opt
    mv qizhi_test.tar.gz ${SD_DEV_MOUNT}/opt
    cd ${SD_DEV_MOUNT}/opt
    tar --no-same-owner -xzvf qizhi_test.tar.gz
    rm qizhi_test.tar.gz
    
    cd ${SD_DEV_MOUNT}/system/var/
    cp install_filelists.sh ${SD_DEV_MOUNT}/var/Ascend/install_cache
    cp install_dev.sh ${SD_DEV_MOUNT}/var/Ascend/install_cache
    cp minirc_sys_init.sh ${SD_DEV_MOUNT}/var/Ascend/install_cache/scripts
    cd ${SD_DEV_MOUNT}/var/Ascend/install_cache
    sh install_filelists.sh ${SD_DEV_MOUNT} && sh install_dev.sh ${SD_DEV_MOUNT}
    copy_ascend_services

    rm -fr ${SD_DEV_MOUNT}/var/davinci/scripts
    chroot ${SD_DEV_MOUNT} /system/bin/sh -c "cd /var/davinci/ && ln -s /var/Ascend/install_cache/scripts scripts"

    mkdir -p ${SD_DEV_MOUNT}/dev/shm/dmp -m 750 && chroot ${SD_DEV_MOUNT} /system/bin/sh -c "chown -Rf HwDmUser:HwDmUser /dev/shm/dmp"
    chroot ${SD_DEV_MOUNT} /system/bin/sh -c "chown -Rf HwDmUser:HwDmUser /etc/sys_version.conf"
    cp ${SD_DEV_MOUNT}/var/Ascend/install_cache/*ko ${SD_DEV_MOUNT}/var/davinci/driver

    mv ${SD_DEV_MOUNT}/system/var/libaarch64.tar.gz ${SD_DEV_MOUNT}/
    chroot ${SD_DEV_MOUNT} /system/bin/sh -c "tar -xvf libaarch64.tar.gz"
    rm ${SD_DEV_MOUNT}/libaarch64.tar.gz

    cp ${SD_DEV_MOUNT}/libaarch64/aarch64-linux-gnu/ld-linux-aarch64.so.1 ${SD_DEV_MOUNT}/system/lib64
    cp ${SD_DEV_MOUNT}/libaarch64/aarch64-linux-gnu/ld-linux-aarch64.so.1 ${SD_DEV_MOUNT}/system/lib
    mv ${SD_DEV_MOUNT}/system/var/davinci/driver/* ${SD_DEV_MOUNT}/var/davinci/driver/
    
    mv -f ${SD_DEV_MOUNT}/system/var/init.cfg ${SD_DEV_MOUNT}/system/etc
    mv ${SD_DEV_MOUNT}/system/etc/Camera.hap ${SD_DEV_MOUNT}/system/app/com.ohos.camera/
    mv ${SD_DEV_MOUNT}/system/etc/Music_Demo.hap ${SD_DEV_MOUNT}/system/app/com.ohos.distributedmusicplayer/
    echo "start sync"
    sync
    echo "sync finish"
    cancelMountSystemLocal
}

function main()
{
    # ********************** check chiptype **************************
    initUbootPartData

    # ********************** check configuration **************************
    checkSystemPartConfig || return 1

    # ************************umount dev_name***************************************
    checkSDCard
    if [ $? -ne 0 ];then
        return 1
    fi
	
    formatSDcard310B
    if [ $? -ne 0 ];then
        return 1
    fi
	
	updateStructInfo
    if [ $? -ne 0 ];then
        return 1
    fi
	
    config310BComponents
	
    write310BOHimg
	
    expandPartedSD

    updateDriverRun
    echo "Finished!"
    return 0
}

main $*
ret=$?

if [[ ret -ne 0 ]];then
    echo "===================Failed==================="
    exit 1
fi
echo "===================Success==================="
exit 0