#!/bin/bash

# 获取脚本的第一个参数作为 ohos_rootdir
ohos_rootdir=$1

# 定义 Ascend310Bkernel 和 patch_dir
Ascend310Bkernel=$ohos_rootdir/kernel/linux/Ascend310B-5.10/Ascend310B-source/
AscendPWD="$( cd "$(dirname "$0")" ; pwd -P )""/"
ohos_patch_dir=${AscendPWD}device_board_ascend/patch
kernel_patch_dir=${AscendPWD}device_board_ascend/ascend/310B/kernel/kernel_patch/linux-5.10/310B_patch/
driver_package=${AscendPWD}package/Ascend-hdk-310b-npu-driver-soc_24.1.rc2_linux-aarch64.run
CLEAN=0

function print_help(){
 echo -e "\033[31m Help Info\033[0m"
 echo -e "\033[31m USAGE: ascend_env.sh OHOS_PATH_ROOT\033[0m"
 echo -e "\033[31m OHOS_PATH_ROOT: absolute path of openharmony root path\033[0m"
 echo -e "\033[31m example: ./ascend_env.sh /home/ascend/OpenHarmony\033[0m"
}

function get_git_path(){
    local path=$1
    path=${path#*=}
    path=${path%=*}
    path=${path//-/\/}
    echo $path
}

function apply_ohos_git_patch(){
    for file in `ls $1`
    do
	if [[ ! $file =~ ".patch" ]] &&  [[ ! $file =~ ".diff" ]]; then
            continue
        fi

        git_path=$(get_git_path $file)/
        if [ ! -d $ohos_rootdir/$git_path ];then
            echo -e "\033[31m$git_path not exit \033[0m"
            continue
        fi

        cd $ohos_rootdir/$git_path
        if [ $CLEAN -eq 0 ];then
            echo -e "\n\033[32m#### git apply $file #### \033[0m"
            git apply $1/$file
            echo -e "\033[32m#### git apply $file end#### \033[0m"
        else
            echo -e "\n\033[32m#### git reset $git_path #### \033[0m"
            git clean -df
            git checkout .
            git lfs checkout
            echo -e "\033[32m#### git reset $git_path end #### \033[0m"
        fi
        #git status
    done
}

function apply_kernel_git_patch(){
    if [ ! -d $Ascend310Bkernel ];then
        echo -e "\033[31m$Ascend310Bkernel not exit \033[0m"
        exit 1
    fi
    git_path=$Ascend310Bkernel
    for file in `ls $1`
    do
	if [[ ! $file =~ ".patch" ]] &&  [[ ! $file =~ ".diff" ]]; then
            continue
        fi
        
        if [ ! -d $git_path ];then
            echo -e "\033[31m$git_path not exit \033[0m"
            continue
        fi

        cd $git_path
        if [ $CLEAN -eq 0 ];then
            echo -e "\n\033[32m#### git apply $file    #### \033[0m"
            git apply $1/$file
            echo -e "\033[32m#### git apply $file end#### \033[0m"
        else
            echo -e "\n\033[32m#### git reset $git_path    #### \033[0m"
            git clean -df
            git checkout .
            git lfs checkout
            echo -e "\033[32m#### git reset $git_path end #### \033[0m"
        fi
        #git status
    done
}

#sync device code
function rm_path(){
  if [ -d $1 ];then
    rm $1 -r
    echo -e "\033[32m #### remove path $1 #### \033[0m"
  fi
}

#check input parameters
if [ $# -lt 1 ];then
 print_help
 exit 1;
fi

# 检查 ohos_rootdir 是否存在
if [ ! -e "$ohos_rootdir" ]; then
    echo "\033[31mMake sure  the ohos_rootdir($ohos_rootdir) exist! \033[0m"
    exit 1
fi

# 检查 Ascend 310 driver 包是否存在
if [ ! -e "$driver_package" ]; then
    echo "\033[31mMake sure  the Ascend 310 driver: $driver_package exist! \033[0m"
    exit 1
fi

echo -e "\033[32mTHE OHOS_PATH_ROOT: $ohos_rootdir \033[0m"
echo -e "\033[32mTHE DEVICE:         310B \033[0m"
echo -e "\033[32m #### sync ascend env start! #### \033[0m"

# 拷贝定制目录
rm_path $ohos_rootdir/device/soc/ascend
rm_path $ohos_rootdir/device/board/ascend
rm_path $ohos_rootdir/vendor/ascend

cp -rf ${AscendPWD}device_board_ascend/ascend "$ohos_rootdir/device/board"
cp -rf ${AscendPWD}device_soc_ascend/ascend "$ohos_rootdir/device/soc"
cp -rf ${AscendPWD}vendor_ascend/ascend "$ohos_rootdir/vendor"

# 拷贝Ascend 310 driver
cp ${driver_package} "$ohos_rootdir/device/board/ascend/310B/kernel/kernel_driver"

echo -e ""
echo -e "######################################################################"
echo -e "#### \033[32m Auto apply ascend_ohos patchs start !\033[0m"
echo -e "#### \033[32m OHOS_PATH_ROOT     : $ohos_rootdir \033[0m"
echo -e "#### \033[32m OHOS_PATCH_PATH    : $ohos_patch_dir \033[0m"
echo -e "#### \033[32m KERNEL_PATCH_PATH  : $kernel_patch_dir \033[0m"
echo -e "#### \033[32m DEVICE             : 310B \033[0m"
echo -e "######################################################################"

# 应用定制内核dtb补丁
dtb_patch_path=$(realpath "$kernel_patch_dir/dtb")
apply_kernel_git_patch $dtb_patch_path

# 应用定制ohos补丁
apply_ohos_git_patch $ohos_patch_dir

echo "执行成功"
