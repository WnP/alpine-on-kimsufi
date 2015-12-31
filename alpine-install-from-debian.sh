#!/usr/bin/env bash

###########
# Install script to install Alpine Linux on a kimsufi server with debian 7.5 (Wheezy) (Oldstable) (64bits)
###

## exits if error code returned
set -e

## Configuration ########################################
readonly ALPINESOURCE=http://wiki.alpinelinux.org/cgi-bin/dl.cgi/v3.2/releases/x86_64/alpine-3.2.3-x86_64.iso
readonly DOWLOADSOURCE=true # if you don't want to download from an external server set false and put iso file in $PWD

readonly GPT=false
readonly MBR=sda
readonly ROOTVOLUME=sda1
readonly OVERLAY=$PWD/overlay

# if true configuration is copied from /etc/netword/interfaces
readonly NETAUTO=true
# else network configuration is created with
readonly ADDRESS=192.168.122.43
readonly NETMASK=255.255.255.0
readonly GATEWAY=192.168.122.1

# root ssh key
readonly SSHKEY="insert your ssh public key here"

readonly REBOOT=true # set false if you don't want to reboot after install
#########################################################


install_dependencies() {
	apt-get install syslinux -y
	apt-get install extlinux -y
}

create_overlay() {
	mkdir -p $OVERLAY/etc/ssh \
		$OVERLAY/etc/network \
		$OVERLAY/etc/runlevels/{default,boot,sysinit,shutdown} \
		$OVERLAY/root/.ssh \
		$OVERLAY/etc/lbu
}

keep_host_identities() {
	cp -a /etc/{passwd,group,shadow,gshadow,hostname,resolv.conf,network/interfaces,ssh} $OVERLAY/etc/
}

config_network() {
	if $NETAUTO
	then
		cp /etc/network/interfaces $OVERLAY/etc/network
	else
		cat > $OVERLAY/etc/network/interfaces <<- EOF
		auto lo
		iface lo inet loopback

		auto eth0
		iface eth0 inet static
		      address $ADDRESS
		      netmask $NETMASK
		      gateway $GATEWAY
		EOF
	fi
}

set_ssh_authorized_keys() {
	cat > $OVERLAY/root/.ssh/authorized_keys <<- EOF
	$SSHKEY
	EOF
	echo "/root/.ssh" > $OVERLAY/etc/lbu/include
}

fix_root_shell() {
	sed -i -e '/^root:/s:/bin/bash:/bin/ash:' $OVERLAY/etc/passwd
}

create_world() {
	mkdir -p $OVERLAY/etc/apk
	echo "alpine-base iproute2 openssh" > $OVERLAY/etc/apk/world
}

keep_essential_services() {
	pushd $OVERLAY
	ln -s /etc/init.d/{hwclock,modules,sysctl,hostname,bootmisc,syslog} etc/runlevels/boot/
	ln -s /etc/init.d/{devfs,dmesg,mdev,hwdrivers} etc/runlevels/sysinit/
	ln -s /etc/init.d/{networking,sshd} etc/runlevels/default/
	ln -s /etc/init.d/{mount-ro,killprocs,savecache} etc/runlevels/shutdown/
	popd
}

create_overlay_archive() {
	pushd $OVERLAY
	tar czf $(hostname).apkovl.tar.gz *
	# just printing in case of debug needs
	tar tzvf $(hostname).apkovl.tar.gz
	mv $(hostname).apkovl.tar.gz /
	popd
}

get_alpine_iso() {
	if $DOWLOADSOURCE
	then
		wget $ALPINESOURCE
	fi
	mkdir /cdrom
	mount alpine*.iso /cdrom -o loop
	cp -a /cdrom/* /
}

install_bootloader() {
	if $GPT
	then
		dd bs=440 conv=notrunc count=1 if=/usr/lib/syslinux/gptmbr.bin of=/dev/$MBR
		apt-get install gdisk -y
		sgdisk /dev/sda --attributes=2:set:2
		# just for debug
		sgdisk /dev/sda --attributes=2:show
	else
		dd if=/usr/lib/syslinux/mbr.bin of=/dev/$MBR
	fi

	## Make sure that /boot dir has a symlink pointing to itself. This is to handle the case when /boot is on separate partition.
	ln -sf / /boot/boot

	## Create /boot/extlinux.conf
	cat > /boot/extlinux.conf <<- EOF
	TIMEOUT 20
	PROMPT 1
	DEFAULT grsec
	LABEL grsec
		KERNEL /boot/vmlinuz-grsec
		APPEND initrd=/boot/initramfs-grsec alpine_dev=UUID=$(blkid |grep $ROOTVOLUME|cut -d '"' -f 2):ext4 modules=loop,squashfs,sd-mod,usb-storage,sr-mod quiet
	EOF

	## Finally make the /boot partition bootable by extlinux.
	extlinux -i /boot
}

main() {
	install_dependencies
	create_overlay
	keep_host_identities
	config_network
	set_ssh_authorized_keys
	fix_root_shell
	create_world
	keep_essential_services
	create_overlay_archive
	get_alpine_iso
	install_bootloader

	if $REBOOT
	then
		reboot
	fi
}

main
