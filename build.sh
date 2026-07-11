#!/bin/bash
#初始化目录结构
ScriptPath="$( cd "$(dirname "$0")" ; pwd -P )""/"
OPENHARMONY_ROOT=$1
ASCEND_KERNEL_TAR_PATH=${ScriptPath}/package/Ascend310B-source-bjjc-ohos.tar.gz
ASCEND_KERNEL_OPENHARMONY=${OPENHARMONY_ROOT}/kernel/linux/Ascend310B-5.10
OPENHARMONY_VERSION="OpenHarmony-5.0.3-Release"
IMAGE_GENERATE_PATH=${OPENHARMONY_ROOT}/out/310B/packages/phone/images
ASCEND_OPENHARMONY_IMAGE_VERSION="Ascend-hdk-310b-soc_24.1.rc2-harmony_5.0.3-aarch64"

generate_image_zip() {
	if [ ! -e "$IMAGE_GENERATE_PATH" ]; then
		echo "${IMAGE_GENERATE_PATH} 不存在！"
		exit 1
	fi
	cd ${IMAGE_GENERATE_PATH}
	mkdir ${ASCEND_OPENHARMONY_IMAGE_VERSION}
	mv {system.img,vendor.img,userdata.img,updater.img,Image_signed,dt.img} ${ASCEND_OPENHARMONY_IMAGE_VERSION}
	zip -r "${ASCEND_OPENHARMONY_IMAGE_VERSION}.zip" ${ASCEND_OPENHARMONY_IMAGE_VERSION}
}

if [ $# -lt 1 ]; then
    echo "请提供OpenHarmony源码根目录！"
    exit 1
fi

if [ ! -e "$OPENHARMONY_ROOT" ]; then
	#获取OpenHarmony源码
	mkdir -p ${OPENHARMONY_ROOT}
	cd ${OPENHARMONY_ROOT}
	repo init -u https://gitcode.com/openharmony/manifest -b ${OPENHARMONY_VERSION} --no-repo-verify
	repo sync -c
	repo forall -c 'git lfs pull'

	#下载预编译工具链
    cd ${OPENHARMONY_ROOT}
    rm ../openharmony_prebuilts -rf
    bash build/prebuilts_download.sh
fi

if [ ! -e "${ASCEND_KERNEL_OPENHARMONY}" ]; then
	#解压ascend内核源码
	mkdir -p ${ASCEND_KERNEL_OPENHARMONY}
	if [ ! -e "${ASCEND_KERNEL_TAR_PATH}" ]; then
        echo "\033[31mMake sure the ${ASCEND_KERNEL_TAR_PATH} exist! \033[0m"
        exit 1
	fi
	tar -xvf ${ASCEND_KERNEL_TAR_PATH} -C ${ASCEND_KERNEL_OPENHARMONY}
fi

#整合ascend源码
chmod +x ${ScriptPath}/ascend_env.sh
if [ $? -ne 0 ]; then
	echo "ascend_env.sh 异常退出！"
	exit 1
fi
${ScriptPath}/ascend_env.sh ${OPENHARMONY_ROOT}

cd ${OPENHARMONY_ROOT}
./build.sh --product-name 310B --ccache
if [ $? -ne 0 ]; then
	echo "执行build.sh 异常退出！"
	exit 1
fi
generate_image_zip
