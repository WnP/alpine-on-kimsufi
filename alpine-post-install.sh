#!/usr/bin/env ash

# Alpine post install #############################

## exits if error code returned
set -e

# Configuration ###################################
readonly DISK=/dev/sda
readonly REPO="http://dl-3.alpinelinux.org/alpine/v3.2/main/"
readonly ROOTSIZE=10  # Giga Octet(s), only integer
readonly SWAPSIZE=1024 # Mega Octets, only integer
readonly REBOOT=true
###################################################


main() {
	# set alpine repository
	echo $REPO > /etc/apk/repositories
	# update apk cache
	apk update --quiet
	# install LVM
	apk add lvm2 --quiet

	# needs to probe dm-mod before stoping modloop, for LVM
	modprobe dm-mod

	# unmount device
	/etc/init.d/modloop stop

	# install alpine with LVM setup on disk
	echo "Y Y" | setup-disk -m sys -L -s $SWAPSIZE $DISK

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

	# reboot
	if $REBOOT
	then
		reboot
	fi
}
main
