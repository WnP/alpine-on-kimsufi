# Install alpine linux on kimsufi server

Those script are mostly inspirated by the [alpine wiki - Replacing non-Alpine Linux with Alpine remotely](http://wiki.alpinelinux.org/wiki/Replacing_non-Alpine_Linux_with_Alpine_remotely) and should work on many other restricted hosting service.

# Steps

- install `debian 7.5 (Wheezy) (Oldstable) (64bits)` image provided by kimsufi
- copy, configure and run `alpine-install-from-debian.sh` script on your host using [scp](http://linux.die.net/man/1/scp)

Don't forget to setup your ssh public key in the script configuration, or you will not be able to log on your server after installation

- reboot -normaly the script reboot on success, depending on provided configuration
- copy, configure and run `alpine-post-install.sh` script on your host using [scp](http://linux.die.net/man/1/scp)
- reboot -normaly the script reboot on success, depending on provided configuration
- done

# How it works

## alpine-install-from-debian.sh

Install alpine in an diskless mode, tweaking configuration at the begining of the script file let you choose:

- which alpine version to install
- on which volume install the bootloader
- your network configuration
- which ssh public key is authorized
- if you want to reboot on install success

## alpine-post-install.sh

Must be run after a successful install using `alpine-install-from-debian.sh`

Install alpine in `sys` mode using LVM, tweaking configuration at the begining of the script file let you choose:

- on which volume you want to install
- setup you apk repository
- the size -in Go- for your root logical volume
- the size -in Mo- for your swap partition
- if you want to reboot on install success

# Contribution

Pull requests and issues are welcome.
