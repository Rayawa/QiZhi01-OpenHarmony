#!/bin/bash
ASCEND_SECLOG="/var/log/ascend_seclog"
RunlogFile="${ASCEND_SECLOG}/ascend_run_servers.log"
ko_path=""
targetdir="/var/davinci"
param set const.security.developermode.state true
export LD_LIBRARY_PATH=/libaarch64/aarch64-linux-gnu/:/usr/local/Ascend/driver/lib64/:/usr/lib64

log() {
    cur_date=`date +"%Y-%m-%d %H:%M:%S"`
    echo "[Driver] [$cur_date] $1" >> $RunlogFile
}

device_sys_init_log()
{
    echo $1
    cur_time="[$(date +%Y-%m-%d,%H:%M:%S)]"
    echo "$cur_time $1" >> /var/log/device_sys_init.log
}

init_usermemory()
{
    #OOM create cgroup
    if [ ! -d "/sys/fs/cgroup/memory" ]; then
        mkdir /sys/fs/cgroup/memory
        mount -t cgroup -o memory memory /sys/fs/cgroup/memory
        log "[INFO]mkdir and mount /sys/fs/cgroup/memory status: $?"
    fi
    echo "create usermemory cgroup in the memory virtual file system"

    mkdir /sys/fs/cgroup/memory/usermemory
    chmod 755 /sys/fs/cgroup/memory/usermemory

    echo 1 > /sys/fs/cgroup/memory/usermemory/memory.oom_control
    mkdir /sys/fs/cgroup/hugetlb/usermemory
    chmod 755 /sys/fs/cgroup/hugetlb/usermemory

    #aicpu cust op
    mkdir /sys/fs/cgroup/memory/usermemory/cust_aicpu
    chmod 755 /sys/fs/cgroup/memory/usermemory/cust_aicpu
    echo 1 > /sys/fs/cgroup/memory/usermemory/cust_aicpu/memory.oom_control

    mkdir /sys/fs/cgroup/hugetlb/usermemory/cust_aicpu
    chmod 755 /sys/fs/cgroup/hugetlb/usermemory/cust_aicpu
}

init_xshmem()
{
    chown -RPf ${base_user}:${base_group} /dev/xshmem_dev
    chmod -R 660 /dev/xshmem_dev
}

modify_usermem_limit()
{
    echo "modify_usermem_limit"
    #get system free memory
    #local free_mem=`cat /sys/devices/system/node/node0/meminfo | grep MemFree | awk '{ print $4 }'`
    #local cma_free=`cat /proc/meminfo | grep "CmaFree" | awk '{print $2}'`
    local free_mem=14823264
    local cma_free=766608
    local mem_limit=$((free_mem * 1024 - 348 * 1024 * 1024 - cma_free * 1024))
    echo $((mem_limit)) > /sys/fs/cgroup/memory/usermemory/memory.limit_in_bytes
    echo $((mem_limit / 2)) > /sys/fs/cgroup/memory/usermemory/cust_aicpu/memory.limit_in_bytes
}

###############################################
#
#        Load Drivers.
#
###############################################
disable_printk()
{
    echo 0    4    0    7 > /proc/sys/kernel/printk
    echo "disable printk succ"
}

ko_check()
{
    ko=$1

    insmod $ko
    if [ $? -ne 0 ]; then
        echo "[DEBUG] `date` insmod $ko fail"
    else
        echo "[DEBUG] `date` insmod $ko succ"
    fi
}

ko_probe_check()
{
    ko=$1

    modprobe $ko
    if [ $? -ne 0 ]; then
        echo "[DEBUG] `date` modprobe $ko fail"
    else
        echo "[DEBUG] `date` modprobe $ko succ"
    fi
}

config_time_file()
{
    touch /etc/localtime
    chown -R ${dm_user}:${dm_group} /etc/localtime
    chmod -R 644 /etc/localtime
}

load_device_parameters()
{
    config_time_file
}

load_profiling_daemon()
{
    mkdir -p /var/log/npu/profiling
    chown -Rf $username:$usergroup /var/log/npu/profiling
    chmod -f 750 /var/log/npu/profiling
}

mkdir_for_upgrade()
{
    #local _device_num=`ls /dev | grep -Ewc "davinci[0-7]"`
    local _device_num=1
    if [ ${_device_num} -eq 0 ];then
        return
    fi

    if [ ! -d /home/drv/upgrade ];then
        mkdir /home/drv/upgrade
    fi
    chmod 755 /home/drv/upgrade

    if [ ! -d /home/drv/upgrade/firmware ];then
        mkdir /home/drv/upgrade/firmware
    fi
    chmod 750 /home/drv/upgrade/firmware
    chown -f ${dm_user}:${dm_group} /home/drv/upgrade/firmware

    rm -rf /home/drv/upgrade/firmware/*
    #_device_num=`expr ${_device_num} - 1`
    _device_num=0
    # for i in $(seq 0 ${_device_num})
    # do
    #     su - -s /bin/bash $dm_user -c "mkdir -m 750 /home/drv/upgrade/firmware/device${i}"
    # done
    mkdir -m 750 /home/drv/upgrade/firmware/device0
    chown $dm_user:$dm_user /home/drv/upgrade/firmware/device0
}

create_folder()
{
    mkdir -p /home/drv
    chmod 755 /home/drv
    chown root:root /home/drv

    mkdir_for_upgrade
}

load_dmp_daemon()
{
    mkdir -p /var/driver
    chmod -Rf 750 /var/driver
    chown -f ${username}:${usergroup} /var/driver

    rm -rf /var/dmp
    rm -rf /dev/shm/dmp
    mkdir -p /dev/shm/dmp -m 750
    chown -Rf ${dm_user}:${dm_group} /dev/shm/dmp
}

load_device_services()
{
    echo "load_device_services"
    load_slogd
    load_profiling_daemon
    load_dmp_daemon
}

init_mem_waterline()
{
    #disable panic on oom
    echo 0 > /proc/sys/vm/panic_on_oom
    echo 0 > /proc/sys/vm/enable_oom_killer

    #always allow memory overcommit
    echo 1 > /proc/sys/vm/overcommit_memory
}

init_file_pagecache()
{
    # mini-rc use SD to mount rootfs. When there's a lot of IO request, such as tar, logd, read/write
    # It may block the process. Should reduce the backgroud queue.
    # dirty_background_ratio(default 10) change to 1
    # dirty_ratio(default 20) change to 2

    echo 1 > /proc/sys/vm/dirty_background_ratio
    echo 2 > /proc/sys/vm/dirty_ratio
}

COMMON_INIT_FILE="/var/davinci/scripts/ascend_common_init.sh"
source "${COMMON_INIT_FILE}"

init_cpusets()
{
    if [ ! -d "/sys/fs/cgroup" ]; then
        mount -t tmpfs cgroup_root /sys/fs/cgroup
    fi
    if [ ! -d "/sys/fs/cgroup/cpuset" ]; then
        mkdir /sys/fs/cgroup/cpuset
        mount -t cgroup -ocpuset cpuset /sys/fs/cgroup/cpuset
        log "[INFO]mkdir & mount /sys/fs/cgroup/cpuset status: $?"
    fi
    echo "create CtrlCPU and AICPU cgroup in the cpuset virtual file system"
    # local MaxCpuID=`cat /proc/cpuinfo | grep "processor" | tail -1 | tr -cd "[0-9]"`

    mkdir /sys/fs/cgroup/cpuset/CtrlCPU
    mkdir /sys/fs/cgroup/cpuset/AICPU
    mkdir /sys/fs/cgroup/cpuset/DataCPU

    chmod 755 /sys/fs/cgroup/cpuset/CtrlCPU
    chmod 755 /sys/fs/cgroup/cpuset/AICPU
    chmod 755 /sys/fs/cgroup/cpuset/DataCPU

    mkdir /home/${username}/aicpu_kernels
    chown -RPf ${username}:${usergroup} /home/${username}/aicpu_kernels
    chmod -R 750 /home/${username}/aicpu_kernels

    mkdir /usr/lib64/aicpu_kernels
    chown -RPf root:root /usr/lib64/aicpu_kernels
    chmod -R 445 /usr/lib64/aicpu_kernels
    chmod 745  /usr/lib64/aicpu_kernels

    cat /sys/fs/cgroup/cpuset/cpuset.mems > /sys/fs/cgroup/cpuset/CtrlCPU/cpuset.mems
    cat /sys/fs/cgroup/cpuset/cpuset.mems > /sys/fs/cgroup/cpuset/AICPU/cpuset.mems
    cat /sys/fs/cgroup/cpuset/cpuset.mems > /sys/fs/cgroup/cpuset/DataCPU/cpuset.mems
    chmod 640 /sys/fs/cgroup/cpuset/CtrlCPU/cpuset.cpus
    chmod 640 /sys/fs/cgroup/cpuset/AICPU/cpuset.cpus
    chmod 640 /sys/fs/cgroup/cpuset/DataCPU/cpuset.cpus

    set_cgroup_cpuset "ai_cpu_static" "unlimit_aicpu"
}

attach_tasks()
{
    echo "make all non-AI tasks attach to CtrlCPU cgroup"
    while read line
    do
        echo $line >> /sys/fs/cgroup/cpuset/CtrlCPU/tasks 2> /dev/null
    done < /sys/fs/cgroup/cpuset/tasks
}

change_dev_mode()
{
    cd /dev/
    chmod -f 660 davinci0 davinci_manager upgrade svm0 vb sys logmpp rgn vpc vdec venc pngd ts_aisle dvpp_cmdlist poll_adapt
    chmod -f 660 vi isp_dev vpss hi_mipi_rx i2c-0 i2c-1 i2c-2 i2c-3 spidev3.0 spidev4.0 gdc vgs motionfusion
    chmod -f 600 hisi_bbox* user_config
    chmod -f 660 aio ai ao aenc adec acodec
    chmod -f 660 vo hdmi ot_mipi_tx ot_tde fb*
    chmod -f 440 prof_drv
    chmod -f 400 log_drv
    chown -f ${username}:${usergroup} log_drv prof_drv davinci* hisi_bbox* svm0 ts_aisle vb sys logmpp rgn vpc vdec venc pngd dvpp_cmdlist poll_adapt
    chown -f ${username}:${usergroup} aio ai ao aenc adec acodec
    chown -f ${username}:${usergroup} vo hdmi ot_mipi_tx ot_tde fb*
    chown -f ${username}:${usergroup} vi isp_dev vpss hi_mipi_rx i2c-0 i2c-1 i2c-2 i2c-3 spidev3.0 spidev4.0 gdc vgs motionfusion
    chown -f ${base_user}:${base_group} davinci_manager upgrade
    chown -f ${dm_user}:${dm_group} ascend_manager
    # For rc docker
    chmod -f 660 davinci_manager_docker
    chown -f ${username}:${usergroup} davinci_manager_docker
    # root:root
    chmod -f 444 random urandom
}

hdc_ppc_create()
{
    if [ "${user_exist_flag}" = "y" ]; then
        su - -s /bin/bash ${dm_user} -c "mkdir -p /home/${dm_user}/hdc_ppc -m 750 >& /dev/null"
        su - -s /bin/bash ${base_user} -c "mkdir -p /home/${base_user}/hdc_ppc -m 750 >& /dev/null"
        mkdir -p /root/hdc_ppc -m 750 >& /dev/null
    else
        mkdir -p /root/hdc_ppc -m 750 >& /dev/null
    fi
}

change_dev_mode_pre()
{
    cd /dev/
    chown -f ${dm_user}:${dm_group}  user_config
}

load_itrustee_client_daemon()
{
    echo "start itrustee client daemon"
    device_sys_init_log "start itrustee client daemon"
    nohup /var/teecd >/dev/null 2>&1 &

    echo "start itrustee tlogcat"
    device_sys_init_log "start itrustee tlogcat"
    nohup /var/tlogcat -f >/dev/null 2>&1 &
}

kbox_ko_check()
{
    mkdir -p /var/log/kbox
    insmod ${ko_path}/kbox.ko product="hi1910Brc" config=0x5f
    if [ $? -ne 0 ]; then
        echo "[DEBUG] `date` insmod kbox.ko fail"
    else
        echo "[DEBUG] `date` insmod kbox.ko succ"
    fi
}

sysmonitor_ko_check()
{
    insmod ${ko_path}/sysmonitor.ko sigcatchmask=0x3ffe
    if [ $? -ne 0 ]; then
        echo "[DEBUG] `date` insmod sysmonitor.ko fail"
    else
        echo "[DEBUG] `date` insmod sysmonitor.ko succ"
    fi
    if [ -f /proc/sysmonitor ]; then
        chmod -f 440 /proc/sysmonitor
        chown -f ${username}:${usergroup} /proc/sysmonitor
    fi
}

watchdog_ko_check()
{
	insmod ${ko_path}/sbsa_gwdt.ko action=1
	if [ $? -ne 0 ]; then
		echo "[DEBUG] `date` insmod sbsa_gwdt.ko fail"
	else
		echo "[DEBUG] `date` insmod sbsa_gwdt.ko succ"
	fi
}

davinci_intf_ko_check()
{
    COMMON_GROUP_ID0=`id -g ${username}`
    COMMON_GROUP_ID1=`id -g ${dm_user}`
    COMMON_GROUP_ID2=`id -g ${base_user}`
    insmod ${ko_path}/drv_davinci_intf.ko g_authorized_group_id=${COMMON_GROUP_ID0},${COMMON_GROUP_ID1},${COMMON_GROUP_ID2}
    if [ $? -ne 0 ]; then
        echo "[DEBUG] `date` insmod drv_davinci_intf.ko fail"
    else
        echo "[DEBUG] `date` insmod drv_davinci_intf.ko succ"
    fi
}

dvpp_vdec_ko_check()
{
    insmod ${ko_path}/drv_vdec.ko deployment=1
    if [ $? -ne 0 ]; then
        echo "[DEBUG] `date` insmod drv_vdec.ko fail"
    else
        echo "[DEBUG] `date` insmod drv_vdec.ko succ"
    fi
}

usb_function_config()
{
    func=$1
    usbc_id=$2
    echo "0x12d1" > idVendor
    echo "0x107E" > idProduct
    mkdir strings/0x409
    echo "HISILICON" > strings/0x409/manufacturer
    echo "310b-${usbc_id}" > strings/0x409/serialnumber
    mkdir configs/c.1
    mkdir configs/c.1/strings/0x409

    if [ "${func}" == "ecm" ]; then
        echo "Ethernet Gadget" > strings/0x409/product
        echo "CDC" > configs/c.1/strings/0x409/configuration
        mkdir functions/ecm.usb0
        ln -s functions/ecm.usb0 configs/c.1/f1
    elif [ "${func}" == "rndis" ]; then
        echo "Ethernet Gadget" > strings/0x409/product
        echo "CDC" > configs/c.1/strings/0x409/configuration
        mkdir functions/rndis.usb0
        ln -s functions/rndis.usb0 configs/c.1/f1
    elif [ "${func}" == "udisk" ]; then
        echo "Mass Storage" > strings/0x409/product
        echo "MSC" > configs/c.1/strings/0x409/configuration
        mkdir functions/mass_storage.usb0
        if [ "${usbc_id}" == "1" ]; then
            echo /var/udisk1  > functions/mass_storage.usb0/lun.0/file
        elif [ "${usbc_id}" == "2" ]; then
            echo /var/udisk2  > functions/mass_storage.usb0/lun.0/file
        elif [ "${usbc_id}" == "3" ]; then
            echo /var/udisk3  > functions/mass_storage.usb0/lun.0/file
        fi
        ln -s functions/mass_storage.usb0 configs/c.1
    fi
}

usb_func_init()
{
    cur_path=`pwd`
    func=$1
    if [ ! -d /sys/kernel/config/usb_gadget ];then
        mount -t configfs none /sys/kernel/config/
    fi
    if [ "${func}" == "udisk" ]; then
        if [ ! -e /var/udisk1 ]; then
            dd if=/dev/zero of=/var/udisk1 count=1 bs=1M
        fi
        if [ ! -e /var/udisk2 ]; then
            dd if=/dev/zero of=/var/udisk2 count=1 bs=1M
        fi
        if [ ! -e /var/udisk3 ]; then
            dd if=/dev/zero of=/var/udisk3 count=1 bs=1M
        fi
    fi
    for i in $(seq 1 3)
    do
        mkdir /sys/kernel/config/usb_gadget/g${i}
        cd /sys/kernel/config/usb_gadget/g${i}
        usb_function_config ${func} ${i}
    done
    cd $cur_path
}

load_dbl_modules()
{
    ko_check ${ko_path}/ascend_uda.ko
    ko_check ${ko_path}/dbl_board_config.ko
    ko_check ${ko_path}/dbl_cfg_persistent.ko
    ko_check ${ko_path}/dbl_algorithm.ko
    ko_check ${ko_path}/dbl_dev_identity.ko
    ko_check ${ko_path}/dbl_runenv_config.ko
    ko_check ${ko_path}/dbl_chip_config.ko
}

load_trs_modules()
{
    device_sys_init_log "load trs modules stars"
    ko_check ${ko_path}/ascend_trs_stars.ko
    ko_check ${ko_path}/ascend_trs_id_pool.ko
    ko_check ${ko_path}/ascend_trs_id_allocator.ko
    ko_check ${ko_path}/ascend_trs_nvme_chan.ko
    ko_check ${ko_path}/ascend_event_sched.ko
    ko_check ${ko_path}/ascend_trs_core.ko
    # ko_check ${ko_path}/ascend_trs_cdqm.ko
    ko_check ${ko_path}/ascend_trs_pm_adapt.ko
    ko_check ${ko_path}/ascend_trs_mia_adapt.ko
    device_sys_init_log "load trs modules end"
}

load_dvpp_and_qos_modules()
{
    device_sys_init_log "load dvpp modules stars"
    ko_check ${ko_path}/drv_dvpp_comm.ko
    ko_check ${ko_path}/drv_dcc.ko
    ko_check ${ko_path}/drv_chnl.ko
    ko_check ${ko_path}/drv_vpc.ko
    ko_check ${ko_path}/vpc.ko
    ko_check ${ko_path}/drv_vfmw.ko
    ko_check ${ko_path}/drv_vdec_adapt.ko
    ko_check ${ko_path}/drv_jpegd.ko
    dvpp_vdec_ko_check
    ko_check ${ko_path}/drv_rc.ko
    ko_check ${ko_path}/drv_venc.ko
    ko_check ${ko_path}/drv_vedu.ko
    ko_check ${ko_path}/drv_h264e.ko
    ko_check ${ko_path}/drv_h265e.ko
    ko_check ${ko_path}/drv_jpege.ko
    ko_check ${ko_path}/drv_pngd.ko
    ko_check ${ko_path}/drv_qos.ko
    device_sys_init_log "load dvpp modules end"
}

load_media_modules()
{
    device_sys_init_log "load media modules stars"
    # ko_check ${ko_path}/drv_mipi_rx.ko
    # ko_check ${ko_path}/drv_vi.ko
    # ko_check ${ko_path}/drv_isp.ko
    ko_check ${ko_path}/drv_vpss.ko
    ko_check ${ko_path}/drv_sensor_i2c.ko
    ko_check ${ko_path}/drv_vgs.ko
    ko_check ${ko_path}/drv_gdc.ko
    ko_check ${ko_path}/drv_dis.ko
    ko_check ${ko_path}/ascend_camera_gyrodis.ko
    ko_check ${ko_path}/ascend_camera_motionfusion.ko
    # ko_check ${ko_path}/drv_aio.ko
    # ko_check ${ko_path}/drv_ao.ko
    # ko_check ${ko_path}/drv_ai.ko
    # ko_check ${ko_path}/drv_codec.ko
    # ko_check ${ko_path}/drv_aenc.ko
    # ko_check ${ko_path}/drv_adec.ko
    # ko_check ${ko_path}/drv_acodec.ko
    ko_check ${ko_path}/drv_vo.ko
    ko_check ${ko_path}/drv_hdmi.ko
    ko_check ${ko_path}/drv_mipi_tx.ko
    ko_check ${ko_path}/drv_tde.ko
    ko_check ${ko_path}/ascend_vdp_hifb.ko
    ko_check ${ko_path}/ascend_310b_codec.ko
    ko_check ${ko_path}/ascend_310b_platform_m.ko
    ko_check ${ko_path}/ascend_310b_machine.ko
    ko_check ${ko_path}/videobuf2-dma-sg.ko
    ko_check ${ko_path}/v4l2-fwnode.ko
    ko_check ${ko_path}/ascend_vdp_v4l2.ko
    ko_check ${ko_path}/imx219_v4l2.ko
    device_sys_init_log "load media modules end"
}

load_device_modules()
{
    echo "load device modules"
    ko_path="${targetdir}"/driver

    # bootdot and bbox insmod at first
    ko_check ${ko_path}/ascend_bootdot.ko

    ko_check ${ko_path}/svm.ko
    davinci_intf_ko_check
    load_dbl_modules
	
	ko_check ${ko_path}/mntn_bbox.ko
    ko_check ${ko_path}/drv_gpio_uniform.ko &
    ko_check ${ko_path}/drv_sys_ctrl_uniform.ko &
    ko_check ${ko_path}/drv_i2c_uniform.ko
    ko_check ${ko_path}/drv_spi_uniform.ko

    # support i2c module
    ko_check ${ko_path}/i2c-dev.ko &
    ko_check ${ko_path}/spidev.ko &
    # support usb/sata module
    ko_check ${ko_path}/usb-storage.ko &

    watchdog_ko_check

    sysmonitor_ko_check &

    ko_check ${ko_path}/tzdriver.ko
    load_itrustee_client_daemon
    ko_check ${ko_path}/hsm_firmware_update.ko
    ko_check ${ko_path}/hsm_flash.ko
    ko_check ${ko_path}/hsm_heartbeat.ko
    ko_check ${ko_path}/ascend_hsm_tpm.ko

    ko_check ${ko_path}/drv_ascend_ctl.ko &
    ko_check ${ko_path}/drv_user_cfg.ko
    ko_check ${ko_path}/drv_ascend_devmng.ko
    change_dev_mode_pre
    init_cpusets

    ko_check ${ko_path}/ascend_soc_resmng.ko
    ko_check ${ko_path}/drv_dfm.ko
    ko_check ${ko_path}/ascend_urd.ko
    ko_check ${ko_path}/drv_serdes.ko &
    ko_check ${ko_path}/drv_pcierc_sr.ko
    ko_check ${ko_path}/ipc_drv.ko
    ko_check ${ko_path}/drv_icm.ko
    ko_check ${ko_path}/ascend_dms_dtm.ko
    ko_check ${ko_path}/ascend_trs_tsmng.ko
    ko_check ${ko_path}/drv_pkicms.ko
    ko_check ${ko_path}/ascend_virtmng_dev.ko
    ko_check ${ko_path}/drv_fpdc.ko
    ko_check ${ko_path}/ascend_dms_smf.ko
    ko_check ${ko_path}/ascend_dms_mng.ko
    ko_check ${ko_path}/drv_devmng.ko
    ko_check ${ko_path}/drv_subsys_fault.ko
    ko_check ${ko_path}/ascend_qos.ko
    ko_check ${ko_path}/drv_e2prom.ko
    ko_check ${ko_path}/hnae3.ko
    ko_check ${ko_path}/hns3.ko
	ko_check ${ko_path}/ascend_lpm.ko
    ko_check ${ko_path}/hclgeplf.ko &
    ko_check ${ko_path}/8021q.ko &
    ko_check ${ko_path}/bonding.ko &
    ko_check ${ko_path}/drv_mttcan.ko &
    ko_check ${ko_path}/drv_soft_fault.ko &
    ko_check ${ko_path}/drv_dp_proc_mng.ko &
    ko_check ${ko_path}/drv_ipcm.ko
    load_trs_modules
	ko_check ${ko_path}/ascend_soc_platform.ko
    ko_check ${ko_path}/drv_platform.ko
    ko_check ${ko_path}/drv_prof.ko &
    ko_check ${ko_path}/drv_log.ko &
    #ko_check ${ko_path}/drv_devdrv.ko
    ko_check ${ko_path}/ascend_xsmem.ko
    ko_check ${ko_path}/drv_ts.ko &
    ko_check ${ko_path}/drv_upgrade.ko &
    ko_check ${ko_path}/drv_soc_misc.ko &
    ko_check ${ko_path}/drv_memory.ko
    ko_check ${ko_path}/ts_agent.ko
    ko_check ${ko_path}/drv_osal.ko anony=1 mmz_allocator=hisi mmz=anonymous,0,0x940000000,3072M
    ko_check ${ko_path}/media_drval.ko
    ko_check ${ko_path}/drv_base.ko
    ko_check ${ko_path}/drv_sys.ko
    ko_check ${ko_path}/drv_region.ko
    ko_check ${ko_path}/drv_dvpp_cmdlist.ko

    load_media_modules

    ko_check ${ko_path}/drv_lpm_fault.ko
    ko_check ${ko_path}/drv_lpm_devmng.ko
    ko_check ${ko_path}/drv_pm.ko
    ko_check ${ko_path}/drv_xshmem.ko

    load_dvpp_and_qos_modules &

    # hiusbc
    ko_check ${ko_path}/udc-core.ko
    ko_check ${ko_path}/libcomposite.ko
    ko_check ${ko_path}/u_ether.ko
    ko_check ${ko_path}/usb_f_ecm.ko
    ko_check ${ko_path}/usb_f_rndis.ko
    ko_check ${ko_path}/usb_f_mass_storage.ko
    ko_check ${ko_path}/usb_f_fs.ko
    #usb_func_init rndis
    ko_check ${ko_path}/drv_hiusbc.ko
    ko_check ${ko_path}/xhci-hcd.ko
    ko_check ${ko_path}/xhci-plat-hcd.ko &

    ko_check ${ko_path}/hsm_ras.ko

    ko_check ${ko_path}/kbox_init.ko
    ko_check ${ko_path}/ascend_abl_qos.ko
    kbox_ko_check &

    echo "finish load device modules"
    # /var/device_sys_init_ext.sh
}

load_slogd()
{
    SLOGD_SIZE_16M=16777216
    SLOGD_SIZE_2M=2097152
    SLOGD_DGRAM_QLEN=512000
    sysctl -w net.core.wmem_max=$SLOGD_SIZE_2M >/dev/null 2>&1
    sysctl -w net.core.rmem_max=$SLOGD_SIZE_16M >/dev/null 2>&1
    sysctl -w net.unix.max_dgram_qlen=$SLOGD_DGRAM_QLEN >/dev/null 2>&1
    slog_path="/usr/slog"
    mkdir -p $slog_path
    chmod 750 $slog_path
    grep "^$username" /etc/passwd >/dev/null 2>&1
    if [ $? -eq 0 ];then
        chown -Rf $username:$usergroup $slog_path
    fi

    mkdir -p /var/log/npu/slog/slogd
    chmod 750 /var/log/npu
    chmod 750 /var/log/npu/slog
    chmod 750 /var/log/npu/slog/slogd
    chown $username:$usergroup /var/log/npu
    chown -Rf $username:$usergroup /var/log/npu/slog

    chmod -f 644 /dev/kmsg
    sysctl -w kernel.dmesg_restrict=0 >/dev/null 2>&1
    sed -i 's/kernel.dmesg_restrict=1/kernel.dmesg_restrict=0/' /etc/sysctl.conf
}

toolkit_security_configuration() {
    local set_write_flag="false"
    if [ ! -w "/etc/sudoers" ];then
        chmod u+w /etc/sudoers
        set_write_flag="true"
    fi

    grep -q "HwHiAiUser" /etc/sudoers
    if [ $? -eq 0 ];then
        sed -i '/HwHiAiUser/c\HwHiAiUser ALL=(ALL) ALL' /etc/sudoers
    else
        echo "HwHiAiUser ALL=(ALL) ALL" >> /etc/sudoers
    fi

    if [ $set_write_flag = "true" ];then
        chmod u-w /etc/sudoers
    fi
    unset set_write_flag
    if [ -d /home/CustAiCpuUser ]; then
        chmod -R 770 /home/CustAiCpuUser
    fi
    return 0
}

load_soft_link()
{
    ln -sf /usr/lib64/aicpu_kernels/libtensorflow.so /usr/lib64/libtensorflow.so
    ln -sf /usr/lib64/aicpu_kernels/libcpu_kernels_context.so /usr/lib64/libcpu_kernels_context.so
    ln -sf /usr/lib64/libascend_hal.so /usr/lib64/libts.so
}

pre_init_services()
{
    device_sys_init_log "Current Time remount:`date`"
    /bin/mount -o rw,remount /
}

chk_secure()
{
    echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_all
    echo 1 > /proc/sys/net/ipv4/tcp_syncookies
    echo 2 > /proc/sys/kernel/kptr_restrict

    rm -rf /sbin/userdel
    rm -rf /sbin/groupdel

    rm -rf /sbin/reboot
    rm -rf /usr/sbin/reboot

    chmod 000 /etc/shadow
    chmod 000 /etc/shadow-
    chmod 440 /etc/sudoers
}

close_numa_balance()
{
       echo "disable numa_balance"
       echo 0 > /proc/sys/kernel/numa_balancing
}

restore_selinux_policy()
{
    mkdir -p /dev/shm/iam/ -m 1777
    mkdir -p /dev/shm/iam/easy_comm/ -m 1777
}

load_process_manager()
{
    echo "change group owner bin mode"
    chown ${base_user}:${base_group} /usr/bin/mdc/base-plat/process-manager/proc_launcher
    chown ${base_user}:${base_group} /usr/bin/mdc/base-plat/aosservice/iammgr

    if [ -e /usr/bin/mdc/base-plat/process-manager/robotmiddleware_env_init.bash ]; then
        echo "robot middleware env init start"
        source /usr/bin/mdc/base-plat/process-manager/robotmiddleware_env_init.bash
        echo "robot middleware env init end"
    fi

    echo "begin to start process-manager"
    export LD_LIBRARY_PATH=/usr/lib64/:${LD_LIBRARY_PATH}
    #/usr/bin/mdc/base-plat/process-manager/process-manager /etc/mdc/base-plat/process-manager/startup_procmgr.yaml &
    #/var/slogd -n &
    #/var/sklogd -n &
    #/var/log-daemon -n  &
    #/var/dmp_daemon -I -M -U 8087 &
    #/usr/bin/mdc/base-plat/process-manager/proc_launcher  &
    #/usr/bin/mdc/base-plat/aosservice/iammgr &
    #/var/teecd  &
    #/var/tlogcat -f  &
    echo "finish starting process-manager"
}

check_pm_heartbeat()
{
    sleep 1

    # make a scheduled-task for process-manager
    mkdir -p /var/spool/cron/crontabs/ && touch /var/spool/cron/crontabs/root
    if [ -e /etc/init.d/services/crond ]; then
        /etc/init.d/services/crond start && echo "[/etc/init.d/services/crond] start success"
        echo -n '*/1 * * * * ps -ef | grep -v grep | grep -Eq "process-manager/process-manager|pm_child" || ' > /var/spool/cron/crontabs/root
        echo "/usr/bin/mdc/base-plat/process-manager/pm_child" >> /var/spool/cron/crontabs/root
    else
        echo "/etc/init.d/services/crond doesn't exist"
    fi
}

watchdog_shield()
{
    # shield watchdog
    rm -rf /dev/watchdog
    rm -rf /dev/watchdog0
}

310B_init()
{
    ko_check ${ko_path}/rfkill.ko
    ko_check ${ko_path}/cfg80211.ko
    ko_check ${ko_path}/mac80211.ko
    ko_check ${ko_path}/rtlwifi.ko
    ko_check ${ko_path}/rtl_usb.ko
    ko_check ${ko_path}/rtl8192c-common.ko
    ko_check ${ko_path}/rtl8192cu.ko
    ko_check ${ko_path}/8821cu.ko
    ko_check ${ko_path}/ecc.ko
    ko_check ${ko_path}/ecdh_generic.ko
    ko_check ${ko_path}/bluetooth.ko
    ko_check ${ko_path}/btrtl.ko
    ko_check ${ko_path}/btintel.ko
    ko_check ${ko_path}/btbcm.ko
    ko_check ${ko_path}/bnep.ko
    ko_check ${ko_path}/rfcomm.ko
    ko_check ${ko_path}/btusb.ko

    ko_check ${ko_path}/fusb302.ko
	ko_check ${ko_path}/ascend_vdp_drm.ko
	ko_check ${ko_path}/panfrost.ko

    #rfkill unblock all
    #ifconfig wlan0 up

    gpio_operate set_direction 7 11 1
    gpio_operate set_value 7 11 0
    sleep 1
    gpio_operate set_value 7 11 1

    echo core > /sys/power/pm_test
    echo s2idle > /sys/power/mem_sleep

    #nmcli con up usb0-static

    #设置HDMI1为默认音频输出
    service_control stop audio_server
    amixer set Deviceid 3
    service_control start audio_server
}

qizhi01_init()
{
    echo "qizhi01 init start"
    ko_check ${ko_path}/plat_soc.ko
    ko_check ${ko_path}/sle_soc.ko
    ko_check ${ko_path}/bluetooth.ko
    ko_check ${ko_path}/ble_soc.ko
    ko_check ${ko_path}/wifi_soc.ko
    echo "qizhi01 init finish"
}

load_atlas_default()
{
	ko_probe_check ip_tables
	ko_probe_check fuse
    ko_probe_check rtc-rv8803
	ko_probe_check dm_mod
	ko_probe_check dm_multipath
	ko_probe_check libcrc32c
	ko_probe_check nf_defrag_ipv4
	ko_probe_check nf_defrag_ipv6
	ko_probe_check nf_conntrack
	ko_probe_check nf_nat
	ko_probe_check xt_MASQUERADE
	ko_probe_check st
	ko_probe_check iptable_filter
	ko_probe_check usbserial
	ko_probe_check pl2303
	ko_probe_check sunrpc
	ko_probe_check uio
	ko_probe_check uio_pdrv_genirq
	ko_probe_check fat
	ko_probe_check vfat
	ko_probe_check tunnel4
	ko_probe_check sha1_ce
	ko_probe_check xfrm4_tunnel
	ko_probe_check tun
	ko_probe_check sha256_arm64
	ko_probe_check esp4
	ko_probe_check ah4
	ko_probe_check sha2_ce
	ko_probe_check af_key
	ko_probe_check ghash_ce
	ko_probe_check sch_fq_codel
	ko_probe_check aes_ce_cipher
	ko_probe_check xt_nat
    ko_probe_check cryptd
    ko_probe_check veth
    ko_probe_check xt_addrtype
    ko_probe_check xt_conntrack
    ko_probe_check crypto_simd
    ko_probe_check llc
    ko_probe_check stp
	ko_probe_check aes_ce_blk
	ko_probe_check bridge
    ko_probe_check br_netfilter
    ko_probe_check nfnetlink
    ko_probe_check nf_conntrack_netlink
	ko_probe_check overlay
	ko_probe_check iptable_nat
	ko_probe_check slhc
    ko_probe_check ppp_generic
    ko_probe_check ppp_mppe
    ko_probe_check ppp_async
	ko_probe_check ppp_synctty
	ko_probe_check ppp_deflate
	ko_probe_check bsd_comp
    ko_probe_check sg
	ko_probe_check usb-storage
    ko_probe_check mii
    ko_probe_check usbnet
    ko_probe_check cdc_ether
    ko_probe_check usb_wwan
    ko_probe_check option
    
    ko_probe_check cdc_wdm
    ko_probe_check mtd
    ko_probe_check ubi
	ko_probe_check gluebi
    ko_probe_check mc
	ko_probe_check videodev
    ko_probe_check videobuf2_common
    ko_probe_check videobuf2_v4l2
    ko_probe_check videobuf2_memops
	ko_probe_check videobuf2_vmalloc
	ko_probe_check uvcvideo
    ko_probe_check ntfs
	ko_probe_check ntfs3
    ko_probe_check exfat
    ko_probe_check sbsa_gwdt
    ko_probe_check ascend_bootdot
    ko_probe_check mntn_bbox
    ko_probe_check loop
    ko_probe_check svm
    ko_probe_check squashfs
    ko_probe_check drv_davinci_intf
	ko_probe_check realtek
	ko_probe_check rtc_rv8803

}

load_device_ext_modules()
{
    echo "load device ext modules"
    ko_check ${ko_path}/pwm.ko
    ko_check ${ko_path}/drv_mem_ctrl.ko
    ko_check ${ko_path}/drv_power_off.ko
    ko_check ${ko_path}/vrd.ko
    ko_check ${ko_path}/drv_hsm_efuse.ko

    echo "finish load device ext modules"
}

###############################################
#
# main process
#
###############################################

device_sys_init_log "minirc sys init start"
username=HwHiAiUser
usergroup=HwHiAiUser
sys_user=HwSysUser
sys_group=HwSysUser
dm_user=HwDmUser
dm_group=HwDmUser
base_user=HwBaseUser
base_group=HwBaseUser

#if [ ! -e "/var/debug_version" ];then
#    disable_printk
#fi
pre_init_services
chage -M 99999 root
chage -M 99999 HwHiAiUser

device_sys_init_log "load device modules start"
load_atlas_default
load_device_modules
load_device_ext_modules
device_sys_init_log "load device modules end"

create_folder
init_mem_waterline
init_file_pagecache
load_soft_link
init_usermemory
init_xshmem
restore_selinux_policy
load_device_parameters
watchdog_shield
change_dev_mode
toolkit_security_configuration
hdc_ppc_create
device_sys_init_log "load device services start"
load_device_services
device_sys_init_log "load device services end"

# chk_secure
attach_tasks
device_sys_init_log "load process manager start"
load_process_manager
check_pm_heartbeat &
device_sys_init_log "load process manager end"

modify_usermem_limit
disable_printk
close_numa_balance
device_sys_init_log "minirc sys init end"

310B_init

qizhi01_init
