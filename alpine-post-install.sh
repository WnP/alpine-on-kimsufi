#!/usr/bin/env ash

# Alpine post install #############################

## exits if error code returned
set -e

# Configuration ###################################
readonly GPT=true
readonly DISK=/dev/sda
readonly REPO="http://dl-3.alpinelinux.org/alpine/v3.2/main/"
readonly ROOTSIZE=10  # Giga Octet(s), only integer
readonly SWAPSIZE=1024 # Mega Octets, only integer
readonly REBOOT=false
###################################################


install_dependencies() {
	# set alpine repository
	echo $REPO > /etc/apk/repositories
	# update apk cache
	apk update --quiet
	# install LVM
	if $GPT
	then
		apk add -U lvm2 gptfdisk e2fsprogs syslinux --quiet
	else
		apk add -U lvm2 --quiet
	fi
}

detach_overlay() {
	# needs to probe dm-mod before stoping modloop, for LVM
	modprobe dm-mod
	# unmount device
	/etc/init.d/modloop stop
}

setup_disk() {
	# delete all partition except legacy bios partition
	for volume in `ls "$DISK"*`
		# we preserve de legacy BIOS part
		do if [ $volume != $DISK ] && [ $volume != "$DISK"1 ]
		then
			# and remove all others
			sgdisk $DISK -d `echo $volume|rev|cut -c1`
		fi
	done

	# create new partition
	sgdisk $DISK -n 2::+40M -t 2:8300 -n 3:: -t 3:8300 -A 2:set:2 -p -A 2:show

	# create Logical Volumes
	pvcreate "$DISK"3
	vgcreate vg0 "$DISK"3
	lvcreate -n lv_root -L "$ROOTSIZE"G vg0
	lvcreate -n lv_swap -C y -L "$SWAPSIZE"M vg0
	rc-update add lvm
	vgchange -ay

	# format volumes
	echo "y" | mkfs.ext4 "$DISK"2
	echo "y" | mkfs.ext4 /dev/vg0/lv_root
	echo "y" | mkswap /dev/vg0/lv_swap

	# mount volumes for install
	mount /dev/vg0/lv_root /mnt
	mkdir /mnt/boot
	mount "$DISK"2 /mnt/boot
}

fix_root_size() {
	# When we reduce the size it’s critical that the new size
	# is greater than or equal to the size of the file system.
	# 90% looks a good option
	local tmpsize=`expr $ROOTSIZE \* 90`
	tmpsize=`expr $tmpsize / 100`
	# resize root device
	vgchange -a y                                     # get changes in virtual group
	e2fsck -f /dev/vg0/lv_root                        # force a file system check on the volume
	resize2fs /dev/vg0/lv_root "$tmpsize"G               # resize the actual file system
	echo "y" | lvreduce -L "$ROOTSIZE"G /dev/vg0/lv_root # reduce the size of the logical volume
	# grow the file system so that it uses all available space on the logical volume
	resize2fs /dev/vg0/lv_root
}

install_alpine() {
	if $GPT
	then
		setup_disk
		# install alpine
		echo "Y Y" | MBR=/usr/share/syslinux/gptmbr.bin setup-disk -m sys /mnt
		echo "/dev/vg0/lv_swap        swap    swap    defaults        0 0" >> /mnt/etc/fstab

		umount /mnt/boot
		umount /mnt
	else
		echo "Y Y" | setup-disk -m sys -L -s $SWAPSIZE $DISK

		fix_root_size
	fi
}

main() {

	install_dependencies
	detach_overlay
	install_alpine

	# reboot
	if $REBOOT
	then
		reboot
	fi
}
main
