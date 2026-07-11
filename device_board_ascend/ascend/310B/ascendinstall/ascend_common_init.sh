#!/bin/sh
##################################################
# common initialization func for device
#################################################

# set cgroup cpuset related process
ascend_ctl_sysfs_path="/sys/davinci"
ctrl_cpu_cfg=''
data_cpu_cfg=''
aicpu_cfg=''
flash_ctrl_cpu_num=''
flash_data_cpu_num=''
flash_aicpu_num=''
dts_ctrl_cpu_num=''
dts_data_cpu_num=''
dts_aicpu_num=''

check_cpu_cfg_validity() {
    local ctrl_cpu_num=$1
    local data_cpu_num=$2
    local aicpu_num=$3
    local total_cpu_num=$4
    local check_type=$5
    echo "check_cpu_cfg_validity "
    echo "$ctrl_cpu_num"
    echo "$data_cpu_num"
    echo "$aicpu_num"

    #cpu_num_sum=`expr $ctrl_cpu_num + $data_cpu_num + $aicpu_num`
    cpu_num_sum=4
    #if [ $cpu_num_sum -ne $total_cpu_num ];then
    #    return 1
    #fi

    # if [ "$check_type" == "unlimit_aicpu" ];then
    #     if [ $ctrl_cpu_num -lt 1 ];then
    #         echo "cpu cfg is not vaild"
    #         return 1
    #     fi
    # else
    #     if [[ $ctrl_cpu_num -lt 1 || $aicpu_num -lt 1 ]];then
    #         echo "cpu cfg is not vaild"
    #         return 1
    #     fi
    # fi
    return 0
}

set_dev_cpuset() {
    local ctrl_cpu_num=$1 #3
    local data_cpu_num=$2 #0
    local aicpu_num=$3 #1
    local dev_index=$4 #0
    local total_cpu_num=$5 #4
    echo "set_dev_cpuset "
    echo "$dev_index"
    echo "$ctrl_cpu_num"
    echo "$data_cpu_num"
    echo "$aicpu_num"
    # if [ $dev_index -ne 0 ];then
    #     if [ $ctrl_cpu_num -ne 0 ];then
    #         ctrl_cpu_cfg="$ctrl_cpu_cfg,"
    #     fi

    #     if [ $data_cpu_num -ne 0 ];then
    #         data_cpu_cfg="$data_cpu_cfg,"
    #     fi

    #     if [ $aicpu_num -ne 0 ];then
    #         aicpu_cfg="$aicpu_cfg,"
    #     fi
    # fi

    #set ctrl cpu cpuset
    # start_num=`expr $dev_index \* $total_cpu_num`
    start_num=0
    # if [ $ctrl_cpu_num -ne 0 ];then
    #     if [ $ctrl_cpu_num -eq 1 ];then
    #         ctrl_cpu_cfg="$ctrl_cpu_cfg$start_num"
    #     else
    #         ctrl_cpu_cfg="$ctrl_cpu_cfg$start_num-`expr $start_num + $ctrl_cpu_num - 1`"
    #     fi
    # fi
    ctrl_cpu_cfg="$ctrl_cpu_cfg$start_num-2"

    #set data cpu cpuset
    #start_num=`expr $start_num + $ctrl_cpu_num`
    start_num=3
    # if [ $data_cpu_num -ne 0 ];then
    #     if [ $data_cpu_num -eq 1 ];then
    #         data_cpu_cfg="$data_cpu_cfg$start_num"
    #     else
    #         data_cpu_cfg="$data_cpu_cfg$start_num-`expr $start_num + $data_cpu_num - 1`"
    #     fi
    # fi

    #set aicpu cpuset
    # start_num=`expr $start_num + $data_cpu_num`
    start_num=0
    # if [ $aicpu_num -ne 0 ];then
    #     if [ $aicpu_num -eq 1 ];then
    #         aicpu_cfg="$aicpu_cfg$start_num"
    #     else
    #         aicpu_cfg="$aicpu_cfg$start_num-`expr $start_num + $aicpu_num - 1`"
    #     fi
    # fi
    aicpu_cfg="$aicpu_cfg$start_num"
    return 0
}

set_cgroup_cpuset() {
    rm davinci_tmp.info
    touch davinci_tmp.info
    chmod 600 davinci_tmp.info
    default_cpu_adapt_way=$1
    cpu_cfg_limit_type=$2

    if [ -e $ascend_ctl_sysfs_path/davinci0/device_info ];then
        cat $ascend_ctl_sysfs_path/davinci0/device_info > davinci_tmp.info
        #smp_dev_num=$(cat davinci_tmp.info | grep "smp_dev_num" | tr -cd "[0-9]")
        #if [ $smp_dev_num -gt 4 ];then
        #    echo "smp device number[$smp_dev_num] is out of range\n"
        #    smp_dev_num=1
        #fi
        smp_dev_num=1
    else
        smp_dev_num=1
    fi
    echo "set_cgroup_cpuset"
    echo "$smp_dev_num"
    #actual_cpu_num=`expr $(cat /proc/cpuinfo | grep "processor" | wc -l) / $smp_dev_num`
    actual_cpu_num=4
    num=0
    #while [ $num -lt $smp_dev_num ]
    #do
    # get device info
    if [ -e $ascend_ctl_sysfs_path/davinci$num/device_info ];then
        #if [ $num -ne 0 ];then
        #    cat $ascend_ctl_sysfs_path/davinci$num/device_info > davinci_tmp.info
        #fi

        # flash_ctrl_cpu_num=$(cat davinci_tmp.info | grep "flash_ctrl_cpu_num" | tr -cd "[0-9]")
        # flash_data_cpu_num=$(cat davinci_tmp.info | grep "flash_data_cpu_num" | tr -cd "[0-9]")
        # flash_aicpu_num=$(cat davinci_tmp.info | grep "flash_aicpu_num" | tr -cd "[0-9]")
        # dts_ctrl_cpu_num=$(cat davinci_tmp.info | grep "dts_ctrl_cpu_num" | tr -cd "[0-9]")
        # dts_data_cpu_num=$(cat davinci_tmp.info | grep "dts_data_cpu_num" | tr -cd "[0-9]")
        # dts_aicpu_num=$(cat davinci_tmp.info | grep "dts_aicpu_num" | tr -cd "[0-9]")
        flash_ctrl_cpu_num=3
        flash_data_cpu_num=0
        flash_aicpu_num=1
        dts_ctrl_cpu_num=3
        dts_data_cpu_num=0
        dts_aicpu_num=1
    else
        flash_ctrl_cpu_num=0
        dts_ctrl_cpu_num=0
    fi

    # 1. check flash cpu cfg, if it's valid, set to cpuset file
    # 2. if flash cfg is invalid, check dts cpu cfg, if it's valid, set to cpuset file
    # 3. if flash and dts cfg is invalid, set ctrl cpu num to 1, remain for aicpu.
    check_cpu_cfg_validity $flash_ctrl_cpu_num $flash_data_cpu_num $flash_aicpu_num $actual_cpu_num $cpu_cfg_limit_type
    # if [ $? -eq 0 ];then
    #     set_dev_cpuset $flash_ctrl_cpu_num $flash_data_cpu_num $flash_aicpu_num $num $actual_cpu_num
    # else
    #     check_cpu_cfg_validity $dts_ctrl_cpu_num $dts_data_cpu_num $dts_aicpu_num $actual_cpu_num $actual_cpu_num $cpu_cfg_limit_type
    #     if [ $? -eq 0 ];then
    #         set_dev_cpuset $dts_ctrl_cpu_num $dts_data_cpu_num $dts_aicpu_num $num $actual_cpu_num
    #     else
    #         if [ "$default_cpu_adapt_way" == "ctrl_cpu_static" ];then
    #             dts_ctrl_cpu_num=1
    #             dts_data_cpu_num=0
    #             dts_aicpu_num=`expr $actual_cpu_num - $dts_ctrl_cpu_num - $dts_data_cpu_num`
    #         else
    #             dts_aicpu_num=1
    #             dts_data_cpu_num=0
    #             dts_ctrl_cpu_num=`expr $actual_cpu_num - $dts_aicpu_num - $dts_data_cpu_num`
    #         fi
    #         set_dev_cpuset $dts_ctrl_cpu_num $dts_data_cpu_num $dts_aicpu_num $num $actual_cpu_num
    #     fi
    # fi
    #    num=`expr $num + 1`
    #done
    set_dev_cpuset $flash_ctrl_cpu_num $flash_data_cpu_num $flash_aicpu_num $num $actual_cpu_num
    echo "$ctrl_cpu_cfg" > /sys/fs/cgroup/cpuset/CtrlCPU/cpuset.cpus
    echo "$data_cpu_cfg" > /sys/fs/cgroup/cpuset/DataCPU/cpuset.cpus
    echo "$aicpu_cfg" > /sys/fs/cgroup/cpuset/AICPU/cpuset.cpus
    
    return 0;
}