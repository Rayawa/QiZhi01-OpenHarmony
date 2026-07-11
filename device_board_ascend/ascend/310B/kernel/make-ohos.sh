#!/bin/bash

# Copyright (c) 2025 Ascend Open Source Organization .
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

SCRIPTPATH=$(dirname $realpath "$0")
IMAGE_SIZE=36  # 32M
IMAGE_BLOCKS=4096

KERNEL_TOOLS_PATH=${3}
ROOT_DIR=${4}
HEADER_VERSION="0.0.0.0.0"
CPUs=`sed -n "N;/processor/p" /proc/cpuinfo|wc -l`
MAKE="make CROSS_COMPILE=aarch64-target-linux-gnu-"
BUILD_PATH=boot_linux
EXTLINUX_PATH=${BUILD_PATH}/extlinux
EXTLINUX_CONF=${EXTLINUX_PATH}/extlinux.conf
ASCEND310B_DTB=ascend310B.dtb
IMAGE_OUTPUT_PATH=${ROOT_DIR}/out/310B/packages/phone/images/
if [ ${KBUILD_OUTPUT} ]; then
	OBJ_PATH=${KBUILD_OUTPUT}/
else
	OBJ_PATH=${SCRIPTPATH}/
fi

ID_MODEL=1
ID_ARCH=2
ID_UART=3
ID_DTB=4
ID_IMAGE=5
ID_CONF=6
model_list=(
	"ascend310B arm64 0xfe660000 ascend310B_dtb  Image ascend310B_ohos_defconfig"
)


function help()
{
	echo "Usage: ./make-ohos.sh {BOARD_NAME}"
	echo "e.g."
	for i in "${model_list[@]}"; do
		echo "  ./make-ohos.sh $(echo $i | awk '{print $1}')"
	done
}


function make_extlinux_conf()
{
	dtb_path=$1
	uart=$2
	image=$3
	
	echo "label ascend-kernel-5.10" > ${EXTLINUX_CONF}
	echo "	kernel /extlinux/${image}" >> ${EXTLINUX_CONF}
	echo "	fdt /extlinux/${ASCEND310B_DTB}" >> ${EXTLINUX_CONF}
	cmdline="append earlycon=uart8250,mmio32,${uart} root=PARTUUID=614e0000-0000-4b53-8000-1d28000054a9 rw rootwait rootfstype=ext4"
	echo "  ${cmdline}" >> ${EXTLINUX_CONF}
}

function make_kernel_image()
{
	arch=$1
	conf=$2
        
	${MAKE} ARCH=${arch} ${conf}
	if [ $? -ne 0 ]; then
		echo "FAIL: ${MAKE} ARCH=${arch} ${conf}"
		return -1
	fi

	${MAKE} ARCH=${arch} Image -j${CPUs}
	if [ $? -ne 0 ]; then
		echo "FAIL: ${MAKE} ARCH=${arch} Image"
		return -1
	fi

	${MAKE} ARCH=${arch} modules -j${CPUs}
	if [ $? -ne 0 ]; then
		echo "FAIL: ${MAKE} ARCH=${arch} modules"
		return -1
	fi

	${MAKE} ARCH=${arch} INSTALL_MOD_PATH=${OBJ_PATH}/modules_install modules_install  -j${CPUs}
	if [ $? -ne 0 ]; then
		echo "FAIL: ${MAKE} ARCH=${arch} modules_install"
		return -2
	fi

	return 0
}

function make_ext2_image()
{
	blocks=${IMAGE_BLOCKS}
	block_size=$((${IMAGE_SIZE} * 1024 * 1024 / ${blocks}))

	if [ "`uname -m`" == "aarch64" ]; then
		echo y | sudo mke2fs -b ${block_size} -d boot_linux -i 8192 -t ext2 boot_linux.img ${blocks}
	else
		genext2fs -B ${blocks} -b ${block_size} -d boot_linux -i 8192 -U boot_linux.img
	fi

	return $?
}

function make_boot_linux()
{
	arch=${!ID_ARCH}
	uart=${!ID_UART}
	dtb=${!ID_DTB}
	image=${!ID_IMAGE}
	conf=${!ID_CONF}
	if [ ${arch} == "arm" ]; then
	    # not support
		dtb_path=arch/arm/boot/dts
	else
		dtb_path=arch/arm64/boot/dts/ascend
	fi

	rm -rf ${BUILD_PATH}
	mkdir -p ${EXTLINUX_PATH}

	make_kernel_image ${arch} ${conf}
	if [ $? -ne 0 ]; then
		exit 1
	fi

	IMAGE=${OBJ_PATH}arch/${arch}/boot/${image}
	SIGNED_IMAGE=${OBJ_PATH}arch/${arch}/boot/${image}_signed
	DTB_PATH=${OBJ_PATH}${dtb_path}/${dtb}.img
	TAG_VALUE=uimage

	# add 256 Byte checkHead
	/usr/bin/python3 ${KERNEL_TOOLS_PATH}/signtool/esbc_header/esbc_header.py -raw_img ${IMAGE} -out_img ${IMAGE} -version $HEADER_VERSION -nvcnt 0 -tag $TAG_VALUE -platform hi1910Brc

	#add 8K checkHead
	/usr/bin/python3 ${KERNEL_TOOLS_PATH}/signtool/image_pack/image_pack.py -raw_img ${IMAGE} -out_img ${SIGNED_IMAGE} -platform hi1910Brc -version $HEADER_VERSION
	echo "sign ${IMAGE} success!"

	cp -f ${IMAGE}_signed ${IMAGE_OUTPUT_PATH}
	make_extlinux_conf ${dtb_path} ${uart} ${image}
	cp -f ${SIGNED_IMAGE} ${EXTLINUX_PATH}/
	cp -f ${DTB_PATH} ${EXTLINUX_PATH}/${ASCEND310B_DTB}
	#cp -f logo*.bmp ${EXTLINUX_PATH}/
	if [ "enable_ramdisk" != "${ramdisk_flag}" ]; then
		make_ext2_image
	fi
}

ramdisk_flag=$2
found=0
for i in "${model_list[@]}"; do
	if [ "$(echo $i | awk '{print $1}')" == "$1" ]; then
		make_boot_linux $i
		found=1
	fi
done

