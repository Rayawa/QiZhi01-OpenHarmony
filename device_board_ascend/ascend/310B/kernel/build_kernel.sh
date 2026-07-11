#!/bin/bash

# Copyright (c) 2023-2025 Ascend Open Source Organization .
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

pushd ${1}
ROOT_DIR=${5}
OUTPUT_IMAGE_PATH=${2}
BUILD_SCRIPT_PATH=${3}
export PRODUCT_PATH=${4}
export DEVICE_COMPANY=${6}
export DEVICE_NAME=${7}
export PRODUCT_COMPANY=${8}
ENABLE_RAMDISK=${9}

KERNEL_SRC_TMP_PATH=${ROOT_DIR}/out/kernel/src_tmp/linux-5.10
KERNEL_OBJ_TMP_PATH=${ROOT_DIR}/out/kernel/OBJ/linux-5.10
KERNEL_SOURCE=${ROOT_DIR}/kernel/linux/Ascend310B-5.10/Ascend310B-source/kernel/kernel/kernel
KERNEL_TOOLS_PATH=${KERNEL_SOURCE}/../../../tools/
KERNEL_PATCH_PATH=${ROOT_DIR}/device/board/${DEVICE_COMPANY}/${DEVICE_NAME}/kernel/kernel_patch/linux-5.10
KERNEL_PATCH=${ROOT_DIR}/device/board/${DEVICE_COMPANY}/${DEVICE_NAME}/kernel/kernel_patch/linux-5.10/${DEVICE_NAME}_patch/
PRESET_DEFCONFIG=${ROOT_DIR}/device/board/${DEVICE_COMPANY}/${DEVICE_NAME}/kernel/kernel_config/linux-5.10/arch/arm64/ascend310B_oh_defconfig

HARMONY_CONFIG_PATH=${ROOT_DIR}/kernel/linux/config/linux-5.10
DEFCONFIG_BASE_FILE=${HARMONY_CONFIG_PATH}/base_defconfig
DEFCONFIG_TYPE_FILE=${HARMONY_CONFIG_PATH}/type/standard_defconfig
DEFCONFIG_ARCH_FILE=${KERNEL_SRC_TMP_PATH}/arch/arm64/configs/ascend310B_defconfig

RAMDISK_ARG=disable_ramdisk
DEFCONFIG_FLAG="preset_config"

HEADER_VERSION="0.0.0.0.0"
ASCEND310B_SOURCE_PATH=${ROOT_DIR}/kernel/linux/Ascend310B-5.10/Ascend310B-source/
DTBIMAGE_OUTPUT_PATH=${ROOT_DIR}/out/310B/packages/phone/images/

#export KBUILD_OUTPUT=${KERNEL_OBJ_TMP_PATH}
if [ ${KBUILD_OUTPUT} ]; then
        KERNEL_DTB_PATH=${KERNEL_OBJ_TMP_PATH}/arch/arm64/boot/dts/ascend
else
        KERNEL_DTB_PATH=${KERNEL_SRC_TMP_PATH}/arch/arm64/boot/dts/ascend
fi

function patch_kernel()
{
    #get base kernel
    UNTAR_DIR=${KERNEL_SRC_TMP_PATH}/../untar
    mkdir -p ${UNTAR_DIR}
    tar zxf ${KERNEL_SOURCE}/kernel.tar.gz -C ${UNTAR_DIR}
    mv -f ${UNTAR_DIR}/kernel/* ${KERNEL_SRC_TMP_PATH}/
    rm -rf ${UNTAR_DIR}

    #patch ascend kernel patch
    cp -rf ${KERNEL_SOURCE}/../../../abl/libc_sec ${KERNEL_SRC_TMP_PATH}/../../ 2>/dev/null || true
    cp -rf ${KERNEL_SOURCE}/kbuild/defconfigs/* ${KERNEL_SRC_TMP_PATH}
    APPLY_PATCH_BIN=${KERNEL_SOURCE}/kbuild/apply-patches
    ${APPLY_PATCH_BIN} ${KERNEL_SOURCE}/series.conf ${KERNEL_SOURCE} && echo "apply patches successfully to ${KERNEL_SRC_TMP_PATH}" || (echo "apply patches to ${KERNEL_SRC_TMP_PATH} failed" && exit 1)
    ${APPLY_PATCH_BIN} ${KERNEL_SOURCE}/product_series.conf ${KERNEL_SOURCE} && echo "apply product patches successfully to ${KERNEL_SRC_TMP_PATH}" || (echo "apply product patches failed" && exit 1)

    KASAN_PATCH=${KERNEL_SOURCE}/0001-kasan-Support-for-gcc-version-8.3.patch
    if [ "x$kasan" == "xtrue" ]; then
            echo "Apply patch for KASAN"
            patch -s -E -p1 --no-backup-if-mismatch -i ${KASAN_PATCH} && echo "apply ${KASAN_PATCH} successfully" || (echo "apply ${KASAN_PATCH} failed" && exit 1)
    fi
   
    #emmc patch
    patch -E -Rp1 --no-backup-if-mismatch -i ${KERNEL_SOURCE}/patches/hisi/0001-ascend-add-emmc-patch-for-mini.patch
    patch -E -p1 --no-backup-if-mismatch -i ${KERNEL_SOURCE}/patches/hisi/0001-ascend-add-emmc-patch-for-ascend-310B.patch

    #patch ohos kernel path
    patch -p1 < ${KERNEL_PATCH}/kernel.patch

    #patch HDF patch
    bash ${ROOT_DIR}/drivers/hdf_core/adapter/khdf/linux/patch_hdf.sh ${ROOT_DIR} ${KERNEL_SRC_TMP_PATH} ${KERNEL_PATCH_PATH} ${DEVICE_NAME}

    if [ ! -d "${KERNEL_SRC_TMP_PATH}/.git" ]; then
            echo "+" > "${KERNEL_SRC_TMP_PATH}/localversion"
    fi
    
    patch -E -p1 --no-backup-if-mismatch -i ${KERNEL_PATCH}/0001-add-drivers-gpu-drm-panfrost.patch
    patch -E -p1 --no-backup-if-mismatch -i ${KERNEL_PATCH}/0002-support-mesa3d-pitch.patch
    
    cp -r ${KERNEL_SOURCE}/../../libc_sec ${KERNEL_SRC_TMP_PATH}/
    cp -r ${KERNEL_SOURCE}/spmi_hisi ${KERNEL_SRC_TMP_PATH}/../
    cp ${KERNEL_SOURCE}/kbuild/publickey/ELF_Common_RSA4096_CN_20191009_Huawei.der ${KERNEL_SRC_TMP_PATH}/certs/ELF_Common_RSA4096_CN_20191009_Huawei.der
    
    #bash ${ROOT_DIR}/kernel/linux/linux-5.10/scripts/kconfig/merge_config.sh -O ${KERNEL_SRC_TMP_PATH}/arch/arm64/configs/ -m ${DEFCONFIG_BASE_FILE} ${DEFCONFIG_TYPE_FILE} ${DEFCONFIG_ARCH_FILE}
    if [ "${DEFCONFIG_FLAG}" != "preset_config" ]; then
        #mv ${KERNEL_SRC_TMP_PATH}/arch/arm64/configs/.config ${KERNEL_SRC_TMP_PATH}/arch/arm64/configs/ascend310B_ohos_defconfig
        echo "get config"
    else
	echo "dst = ${KERNEL_SRC_TMP_PATH}/arch/arm64/configs/ascend310B_ohos_defconfig"
        echo "src = ${PRESET_DEFCONFIG}"
        cp -rf ${PRESET_DEFCONFIG} ${KERNEL_SRC_TMP_PATH}/arch/arm64/configs/ascend310B_ohos_defconfig
    fi
}

#build dt.img
function gen_dtimage()
{
    echo "start generate dt.img......."
    cd ${ASCEND310B_SOURCE_PATH}/dtb/dtbtool
    sed -i 's/\/tools\/customize/\/dtb/g' CMakeLists.txt
    rm -rf tmp
    mkdir tmp
    cd tmp
    #generate dt.img
    cmake .. -DTOP_DIR=${ASCEND310B_SOURCE_PATH} -DPRODUCT=ascend310Brc && make device_dtb
	mkdir -p ${DTBIMAGE_OUTPUT_PATH}
    cp -f dt.img ${DTBIMAGE_OUTPUT_PATH}
    echo "generate ${DTBIMAGE_OUTPUT_PATH}/dt.img success!"
}

#sign dt.img
function sign_image()
{
    image_name=$1
    tag_value=$2

    #add 256 checksum header
   /usr/bin/python3 ${KERNEL_TOOLS_PATH}/signtool/esbc_header/esbc_header.py -raw_img ${DTBIMAGE_OUTPUT_PATH}/${image_name} -out_img ${DTBIMAGE_OUTPUT_PATH}/${image_name} -version $HEADER_VERSION -nvcnt 0 -tag $tag_value -platform hi1910Brc

    #add 8k checksum header
    /usr/bin/python3 ${KERNEL_TOOLS_PATH}/signtool/image_pack/image_pack.py -raw_img ${DTBIMAGE_OUTPUT_PATH}/${image_name} -out_img ${DTBIMAGE_OUTPUT_PATH}/${image_name} -platform hi1910Brc -version $HEADER_VERSION
    echo "sign ${DTBIMAGE_OUTPUT_PATH}/${image_name} success!"
}


for i in "$@"
do
    case $i in
        enable_ramdisk)
            RAMDISK_ARG=enable_ramdisk
            ;;
    esac
done

#clear workspace
if [ -d "${KERNEL_SRC_TMP_PATH}" ]; then
    rm -rf ${KERNEL_SRC_TMP_PATH}
fi
mkdir -p ${KERNEL_SRC_TMP_PATH}

if [ -d "${KERNEL_OBJ_TMP_PATH}" ]; then
    rm -rf ${KERNEL_OBJ_TMP_PATH}
fi
mkdir -p ${KERNEL_OBJ_TMP_PATH}

cd ${KERNEL_SRC_TMP_PATH}

patch_kernel

cp -rf ${BUILD_SCRIPT_PATH}/kernel/make*.sh ${KERNEL_SRC_TMP_PATH}/

#precompiled dtb.img
if [ ! -d "${KERNEL_DTB_PATH}" ]; then
    mkdir -p ${KERNEL_DTB_PATH}
fi

gen_dtimage
sign_image dt.img dtimg

cp -rf ${BUILD_SCRIPT_PATH}/kernel/ascend310B_dtb.img ${KERNEL_DTB_PATH}/

cd ${KERNEL_SRC_TMP_PATH}

eval ${KERNEL_SRC_TMP_PATH}/make-ohos.sh ascend310B ${RAMDISK_ARG} ${KERNEL_TOOLS_PATH} ${ROOT_DIR}

if [ ! -d "${OUTPUT_IMAGE_PATH}" ]; then
    mkdir -p ${OUTPUT_IMAGE_PATH}
fi

#cp ${KERNEL_OBJ_TMP_PATH}/resource.img ${OUTPUT_IMAGE_PATH}/
popd

bash ${KERNEL_SRC_TMP_PATH}/make-boot.sh ..

echo "kernel compile finish."
