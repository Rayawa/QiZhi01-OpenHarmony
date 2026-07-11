#!/bin/bash


DEVICE_NAME=$1
IMAGE_NAME=$2


sectorEnd=`fdisk -l | grep "$DEVICE_NAME:" | awk -F ' ' '{print $7}'`
sectorSize=`fdisk -l | grep -A 2 "$DEVICE_NAME:" | grep "Units" | awk -F ' ' '{print $6}'`
if [ $sectorSize -ne 512 ];then
    echo "Failed: sector size is not 512!"
    exit 1
fi

function main()
{
	
	if [ ! -f ${IMAGE_NAME} ];then
        echo "failed: ${IMAGE_NAME} no exist"
        return 1
    fi
	
	if ! fdisk -l | grep -q "$DEVICE_NAME"; then
		echo "Error! the device $DEVICE_NAME does not exit!"
		return 1
    fi

	case $IMAGE_NAME in
		system.img)
		echo "start install system ${DEVICE_NAME}"
		dd if=system.img of=${DEVICE_NAME}2 bs=4M status=progress
		sync
		;;
		vendor.img)
		echo "start install vendor"
		dd if=vendor.img of=${DEVICE_NAME}4 bs=4M status=progress
		sync
		;;
		userdata.img)
		echo "start install userdata"
		dd if=userdata.img of=${DEVICE_NAME}5 bs=4M status=progress
		sync
		;;
		updater.img)
		echo "start install updater"
		dd if=updater.img of=${DEVICE_NAME}6 bs=4M status=progress
		sync
		;;
		Image*)
		echo "start install $IMAGE_NAME"
		dd if=$IMAGE_NAME of=${DEVICE_NAME} count=81920 seek=32768 bs=512
		sync
		;;
		dt*.img)
		echo "start install $IMAGE_NAME"
		dd if=$IMAGE_NAME of=${DEVICE_NAME} count=4096 seek=114688 bs=512
		dd if=$IMAGE_NAME of=${DEVICE_NAME} count=4096 seek=376832 bs=512
		sync
		;;
	esac
}

main "$@"
