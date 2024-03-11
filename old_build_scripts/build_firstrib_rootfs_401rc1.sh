#!/bin/sh
## Build_firstrib_rootfs script to create
#    FirstRib rootfs (structure and contents)
# Uses busybox static plus relevant native package manager or debootstrap code
# Revision Date: 06 Dec 2021
# Copyright wiak (William McEwan) 30 May 2019+; Licence: currently for appointed WeeDogLinux developers use only

##### Just run this script from an empty directory to create firstrib_rootfs
# NOTE: You should run this from appropriate Linux host architecture relevant to the build required
# It uses 32-bit busybox static for all system architectures
# ----------------------------------------------------------
version="4.0.1"; revision="-rc1"
export CONNECTION_TIMEOUT=-1

#wiak maintenance: update the following url to follow upstream releases and architecture required
busybox_url="https://busybox.net/downloads/binaries/1.31.0-i686-uclibc/busybox"
ubuntu_url="http://archive.ubuntu.com/ubuntu/pool/main/d/debootstrap/debootstrap_1.0.124_all.deb"
debian_url="http://ftp.debian.org/debian/pool/main/d/debootstrap/debootstrap_1.0.123_all.deb"
devuan_url="http://pkgmaster.devuan.org/devuan/pool/main/d/debootstrap/debootstrap_1.0.123+devuan3_all.deb"

trap _trapcleanup INT TERM ERR

#### variables-used-in-script:
# re: script commandline arguments $1 $2 $3 $4 $5
distro="$1"; release="$2"; arch="$3"	
export distro release arch

# where distro is currently one of void, ubuntu, debian, devuan, arch or
#   vmini (xbps-static cmdline base Void system) or vnopm (no package manager, just busybox and wiakwifi script).
# release is one of oldstable, stable, testing, or unstable.
# arch is currently one of i386 (i686 for Void), amd64 (x86_64 for Void), or arm64

firstribplugin="f_00.plug"			# contains extra commandlines to execute in chroot during build
									# e.g. xbps-install -y package_whatever (for Void flavour)
									# e.g. apt install -y package_whatever (for deb-based flavour)
									# e.g. pacman -Sy package_whatever (for Arch-Linux-based flavour)
[ "$4" ] && firstribplugin="$4"		# optional fourth parameter specifies alternative f_00 plugin name
firstribplugin01="f_01.plug"		# This second plugin will be sourced immediately after main firstribplugin has finished its work
[ "$5" ] && firstribplugin01="$5"	# optional fifth parameter specifies alternative f_01 plugin name
#### ----------------- end of variables used

#### functions-used-in-script:
_trapcleanup (){
	# Just a quick attempt to clean up some possible chroot-related mounts
	umount -l firstrib_rootfs/proc && umount -l firstrib_rootfs/sys && umount -l firstrib_rootfs/dev/pts && umount -l firstrib_rootfs/dev
	exit
}

_usage (){
	case "$1" in
		'-v'|'--version') printf "Build FirstRib firstrib_rootfs Revision ${version}${revision}\n";exit;;

		''|'-h'|'--help'|'-?') printf '
Usage:
./build_firstrib_rootfsX.sh distro release arch [filename.plug(s)]

where distro is currently one of void, ubuntu, debian, devuan, [a|A]rch,
vmini (xbps-static cmdline Void system), or vnopm (no package manager)
Architecture (arch) can currently be one of amd64 or i686.
For distro void or Arch, "release" can be "default".
For example:
./build_firstrib_rootfsX.sh arch default amd64 f_00_Arch_amd64-XXX.plug
All f_*.plug files automatically get copied into firstrib_rootfs/tmp
If it exists, the commands in optional primary plugin, f_00XX.plug are
automatically executed in a chroot after the core build is complete.
If it exists, additional plugin f_01XX.plug is then similarly sourced.
Either f_00, or f_01 plugin can of course themselves be used to access
other f_XX plugins that were copied into firstrib_rootfs/tmp (for
example: other f_XX lists of commands, or image files or whatever).
NOTE WELL that f_XX plugins (e.g. f_00XX.plug) are not exec scripts.
Rather they should simply contain a list of valid shell commandlines
without any hash bang shell header.
-v --version    display version information and exit
-h --help -?    display this help and exit
';exit;;
		"-*") echo "option $1 not available";exit;;
	esac
}
_usage "$1"  # check if - or --cmdarg (e.g. --version or -h for help)

_void_repo_mirrors (){
	if [ -s "./firstrib.repo" ];then
		. "./firstrib.repo"
		# i.e. If firstrib.repo exists then source it to change build repo from above default
		# For example, for "us" repo, firstrib.repo text file should just contain the single commandline
		#     repo="https://alpha.us.repo.voidlinux.org"
	elif [ "$distro" = "vnopm" ];then
		repo="https://alpha.de.repo.voidlinux.org"
	else
		while :
		do
			printf '
Tier 1 mirrors
1 https://alpha.de.repo.voidlinux.org  EU: Germany
2 https://alpha.us.repo.voidlinux.org  USA: Kansas City
3 https://mirror.clarkson.edu          USA: New York
4 https://mirrors.servercentral.com    USA: Chicago
Tier 2 mirrors
5 https://mirror.aarnet.edu.au         AU: Canberra
6 https://ftp.swin.edu.au              AU: Melbourne
7 https://ftp.acc.umu.se               EU: Sweden
8 https://mirrors.dotsrc.org           EU: Denmark
9 https://void.webconverger.org      APAN: Singapore
10 https://youngjin.io               APAN: South Korea
11 https://ftp.lysator.liu.se          EU: Sweden
12 https://mirror.yandex.ru            RU: Russia
13 https://void.cijber.net             EU: Amsterdam, NL
q for quit this firstrib_rootfs build

Please make your choice '
			read choice
			case $choice in
				'1'|'01') repo="https://alpha.de.repo.voidlinux.org";break;;
				'2'|'02') repo="https://alpha.us.repo.voidlinux.org";break;;
				'3'|'03') repo="https://mirror.clarkson.edu/voidlinux";break;;
				'4'|'04') repo="https://mirrors.servercentral.com/voidlinux";break;;
				'5'|'05') repo="https://mirror.aarnet.edu.au/pub/voidlinux";break;;
				'6'|'06') repo="https://ftp.swin.edu.au/voidlinux";break;;
				'7'|'07') repo="https://ftp.acc.umu.se/mirror/voidlinux.eu";break;;
				'8'|'08') repo="https://mirrors.dotsrc.org/voidlinux";break;;
				'9'|'09') repo="https://void.webconverger.org";break;;
				'10') repo="https://youngjin.io/voidlinux/";break;;
				'11') repo="https://ftp.lysator.liu.se/pub/voidlinux";break;;
				'12') repo="https://mirror.yandex.ru/mirrors/voidlinux";break;;
				'13') repo="https://void.cijber.net";break;;
				'q'|'Q') echo "build terminated";exit 0;;
				*) 
					echo "The choice you made is not available."
					echo "Press enter to return to this menu"
					read choice
				;;
			esac
		done
	fi
}

_arch_repo_mirrors (){
	if [ -s "./firstrib.repo" ];then
		. "./firstrib.repo"
		# i.e. If firstrib.repo exists then source it to change build repo from above default
		# For example, for one South African mirror, firstrib.repo text file could just contain the single commandline
		#     repo="https://mirrors.urbanwave.co.za/archlinux"
	else
		while :
		do
			printf '
Some Arch Linux Repository Mirrors
For many more mirrors refer to: https://www.archlinux.org/mirrorlist/
1 https://mirror.rackspace.com        Worldwide
2 https://mirror.netcologne.de        EU: Germany
3 https:// uk.mirror.allworldit.com   EU: UK
4 https://ftp.lysator.liu.se          EU: Sweden
5 https://mirrors.xtom.nl             EU: Netherlands
6 https://mirror.fsmg.org.nz          NZ 
7 https://mirror.aarnet.edu.au        AUS
8 https://mirrors.kernel.org          USA
9 https://mirrors.ocf.berkeley.edu    USA: California
10 https://ftp.lanet.kr               South Korea
11 https://ftp.jaist.ac.jp            Japan
12 https://www.caco.ic.unicamp.br     Brazil
13 https://mirror.rol.ru              Russia
14 https://mirrors.ustc.edu.cn        China
q for quit this firstrib_rootfs build
https://salsa.debian.org/installer-team/debootstrap.git
Please make your choice '
			read choice
			case $choice in
				'1'|'01') repo="https://mirror.rackspace.com/archlinux";break;;
				'2'|'02') repo="https://mirror.netcologne.de/archlinux";break;;
				'3'|'03') repo="https://archlinux.uk.mirror.allworldit.com/archlinux";break;;
				'4'|'04') repo="https://ftp.lysator.liu.se/pub/archlinux";break;;
				'5'|'05') repo="https://mirrors.xtom.nl/archlinux";break;;
				'6'|'06') repo="https://mirror.fsmg.org.nz/archlinux";break;;
				'7'|'07') repo="https://mirror.aarnet.edu.au/pub/archlinux";break;;
				'8'|'08') repo="https://mirrors.kernel.org/archlinux";break;;
				'9'|'09') repo="https://mirrors.ocf.berkeley.edu/archlinux";break;;
				'10') repo="https://ftp.lanet.kr/pub/archlinux";break;;
				'11') repo="https://ftp.jaist.ac.jp/pub/Linux/ArchLinux";break;;
				'12') repo="https://www.caco.ic.unicamp.br/archlinux";break;;
				'13') repo="https://mirror.rol.ru/archlinux";break;;
				'14') repo="https://mirrors.ustc.edu.cn/archlinux";break;;
				'q'|'Q') echo "build terminated";exit 0;;
				*) 
					echo "The choice you made is not available."
					echo "Press enter to return to this menu"
					read choice
				;;
			esac
		done
	fi
}

_void_x86_64 (){
	export XBPS_ARCH=x86_64
	_void_repo_mirrors # Choose Void repo to use for build
	# build firstrib_rootfs
	mkdir -p firstrib_rootfs
	cd firstrib_rootfs
	# make rootfilesystem directory structure
	mkdir -p boot/kernel dev/pts etc/skel etc/udhcpc etc/xbps.d home/void media mnt opt proc root run sys tmp usr/bin usr/lib usr/include usr/lib32 usr/libexec usr/local/bin usr/local/include usr/local/lib usr/local/sbin usr/local/share usr/share/udhcpc usr/share/xbps.d usr/src var/log

	# The following is per Void Linux structure. e.g. puts most all binaries in /bin and most all libs in /usr/lib:
	ln -sT usr/bin bin; ln -sT usr/lib lib; ln -sT usr/sbin sbin; ln -sT bin usr/sbin; ln -sT usr/lib lib64
	ln -sT usr/lib32 lib32         # In i686 version /usr/lib32 is just a symlink to /lib and there is no /lib32
	# ln -sT usr/lib usr/local/lib # Seems required in i686 32bit version but not I think in this one

	# Using i686 32-bit busybox to begin with, even in x86_64 build (user can install coreutils later if so wanted)
	wget -c -nc "$busybox_url" -P bin && chmod +x bin/busybox	
	# Make the command applet symlinks for busybox
	for i in `bin/busybox --list-full`; do ln -s /bin/busybox ${i}; done; mv bin/getty bin/gettyDISABLED

	# Fetch busybox udhcpc example simple.script renamed to etc/udhcpc/default.script 
	# For ethernet connection simply then need enter command: udhcpc -i <interface_name> 
	# You can find interface names with command: ip link, or ip address (for example eth0, eno1, ... etc, for ethernet)
	# Note that for wifi (interface_name: wlan0, wls1, etc), prior to obtaining dhcp lease you 
	# need to install, configure and run wpa_supplicant using following two wpa commands:
	# wpa_passphrase <wifiSSID> <wifiPassword> >> /etc/wpa_supplicant/wpa_supplicant.conf
	# wpa_supplicant -B -i <device> -c /etc/wpa_supplicant/wpa_supplicant.conf (option -B means run daemon in Background)
	# Note well that the provided simple network script /usr/local/bin/wiakwifi does the above for you if you wish to use it
	wget -c https://git.busybox.net/busybox/plain/examples/udhcp/simple.script -O etc/udhcpc/default.script && chmod +x etc/udhcpc/default.script
	sed -i 's/\$((metric++))/\$metric; metric=\$((metric+1))/' etc/udhcpc/default.script  # thanks rockedge for url of fix
	# But this static busybox udhcpc needs default.script in /usr/share/udhcpc (unlike debian shared busybox):
	mkdir -p usr/share/udhcpc && cp etc/udhcpc/default.script usr/share/udhcpc/default.script

	if [ "$distro" != "vnopm" ];then
		# The following puts xbps static binaries in firstrib_rootfs/usr/bin
		wget -c ${repo}/static/xbps-static-latest.i686-musl.tar.xz
		tar xJvf xbps-static-latest.i686-musl.tar.xz && rm xbps-static-latest.i686-musl.tar.xz

		# Default void repos use usr/share/xbps.d https repos, so ssl certs needed for these:
		echo "repository=${repo}/current" > usr/share/xbps.d/00-repository-main.conf
		echo "repository=${repo}/current/nonfree" > usr/share/xbps.d/10-repository-nonfree.conf
		# If no sslcertificates available can use insecure temporary /etc/xbps.d non-https repos:
		# But here we download/install sslcerts instead, from weedoglinux github repo, for higher build security:
#		wget -c https://gitlab.com/weedog/weedoglinux/-/raw/master/build_resources/sslcerts.tar.xz
#		tar xJf sslcerts.tar.xz && rm sslcerts.tar.xz
	fi

	# Install wiakwifi (can autostart on boot via /etc/profile/profile.d)
	wget -c https://gitlab.com/weedog/weedoglinux/-/raw/master/build_resources/wiakwifi -O usr/local/bin/wiakwifi
	chmod +x usr/local/bin/wiakwifi
	# Install wd_mount
	wget -c https://gitlab.com/weedog/weedoglinux/-/raw/master/build_resources/wd_mount -O usr/local/bin/wd_mount
	chmod +x usr/local/bin/wd_mount
	# cd to where we started this build (i.e. immediately outside of firstrib_rootfs):
	cd ..

	# Copy any firstrib plugins (f_*.plug) into firstrib_rootfs/tmp to be used (e.g. sourced) in chroot build part
	# The plugin file should contain any extra commandlines you want executed in chroot during build
	# e.g. For Void Linux might be: xbps-install -y package_whatever
	# NOTE WELL (for Void) the -y above, since chroot needs answer supplied
	# also note that the primary plugin is not a script, simply a list
	# of commandlines without any hash bang shell header
	cp -a f_* firstrib_rootfs/tmp

	# Next part of script does bind mounts (not really required unless using I/O) for chroot and installs extras required
	mount --bind /proc firstrib_rootfs/proc && mount --bind /sys firstrib_rootfs/sys && mount --bind /dev firstrib_rootfs/dev && mount -t devpts devpts firstrib_rootfs/dev/pts && cp /etc/resolv.conf firstrib_rootfs/etc/resolv.conf

	# The following commands gets done inside firstrib_rootfs (via here_document pipe to chroot):
cat << INSIDE_CHROOT | LC_ALL=C chroot firstrib_rootfs sh
export PATH=/sbin:/usr/sbin:/bin:/usr/bin
case "$distro" in
	vnopm)
		# The optional f_XXX plugin text files named in "$firstribplugin" and "$firstribplugin01"
		# should each simply contain a list of extra commands
		[ -s /tmp/"${firstribplugin}" ] && . /tmp/"${firstribplugin}"
		[ -s /tmp/"${firstribplugin01}" ] && . /tmp/"${firstribplugin01}"
	;;
	vmini)
		SSL_NO_VERIFY_PEER=1 xbps-install -Suy xbps-triggers 
		# make sure xbps continues to use desired main and non-free repos
		echo "repository=${repo}/current" > usr/share/xbps.d/00-repository-main.conf
		echo "repository=${repo}/current/nonfree" > usr/share/xbps.d/10-repository-nonfree.conf
		sleep 1  # to give time for package installs to settle... maybe not required
		[ -s /tmp/"${firstribplugin}" ] && . /tmp/"${firstribplugin}"
		[ -s /tmp/"${firstribplugin01}" ] && . /tmp/"${firstribplugin01}"
	;;
	*)	# include base, and full non-static xbps
		SSL_NO_VERIFY_PEER=1 xbps-install -Suy xbps-triggers base-files xbps
		# make sure xbps continues to use desired main and non-free repos
		sleep 1  # to give time for xbps static to complete above installs
		echo "repository=${repo}/current" > usr/share/xbps.d/00-repository-main.conf
		echo "repository=${repo}/current/nonfree" > usr/share/xbps.d/10-repository-nonfree.conf
		rm /usr/bin/xbps*.static  # Since dynamic xbps now installed
		sleep 1  # to give time to make sure shared lib xbps will be used

		# NOTE WELL: if you want udev hotplug device/modules-autoload management daemon (most will)
		# and/or wpasupplicant you need to apt install them in an f_XXX build plugin
		# For example: xbps-install -y eudev wpa_supplicant
		# For a bootable system you'll also want linux kernel and appropriate firmware.
		# You may also need to configure system for use of other repos (e.g. non-free).
		# For some detailed examples, refer to already provided WDL FirstRib f_XXX plugin files available on download site.
		[ -s /tmp/"${firstribplugin}" ] && . /tmp/"${firstribplugin}"
		[ -s /tmp/"${firstribplugin01}" ] && . /tmp/"${firstribplugin01}"
	;;
esac
exit
INSIDE_CHROOT

	# Finished doing the INSIDE_CHROOT stuff so can now clean up the chroot bind mounts:
	umount -l firstrib_rootfs/proc && umount -l firstrib_rootfs/sys && umount -l firstrib_rootfs/dev/pts && umount -l firstrib_rootfs/dev
	rm -rf firstrib_rootfs/tmp/*
}

_void_i686 (){
	export XBPS_ARCH=i686
	_void_repo_mirrors # Choose Void repo to use for build
	# build firstrib_rootfs
	mkdir -p firstrib_rootfs
	cd firstrib_rootfs
	# make rootfilesystem directory structure
	mkdir -p boot/kernel dev/pts etc/skel etc/udhcpc etc/xbps.d home/void media mnt opt proc root run sys tmp usr/bin usr/lib usr/include usr/libexec usr/local/bin usr/local/include usr/local/lib usr/local/sbin usr/local/share usr/share/udhcpc usr/share/xbps.d usr/src var/log

	# The following is per Void Linux structure. e.g. puts most all binaries in /bin and most all libs in /usr/lib:
	ln -sT usr/bin bin; ln -sT usr/lib lib; ln -sT usr/sbin sbin; ln -sT bin usr/sbin
	# ln -sT usr/lib lib64       # Required in x86_64 version but not I think in this one
	ln -sT lib usr/lib32         # In x86_64 version /usr/lib32 is an actual directory not a symlink
	ln -sT usr/lib usr/local/lib # Seems to be required in i686 version - nah, gives irrelevant error, but just leave in case

	# Using i686 32-bit busybox to begin with (user can install coreutils later if so wanted)
	wget -c -nc "$busybox_url" -P bin && chmod +x bin/busybox	
	# Make the command applet symlinks for busybox
	for i in `bin/busybox --list-full`; do ln -s /bin/busybox ${i}; done; mv bin/getty bin/gettyDISABLED

	# Fetch busybox udhcpc example simple.script renamed to etc/udhcpc/default.script 
	wget -c https://git.busybox.net/busybox/plain/examples/udhcp/simple.script -O etc/udhcpc/default.script && chmod +x etc/udhcpc/default.script
	sed -i 's/\$((metric++))/\$metric; metric=\$((metric+1))/' etc/udhcpc/default.script  # thanks rockedge for url of fix
	# But this static busybox udhcpc needs default.script in /usr/share/udhcpc (unlike debian shared busybox):
	mkdir -p usr/share/udhcpc && cp etc/udhcpc/default.script usr/share/udhcpc/default.script

	if [ "$distro" != "vnopm" ];then
		# The following puts xbps static binaries in firstrib_rootfs/usr/bin
		wget -c ${repo}/static/xbps-static-latest.i686-musl.tar.xz
		tar xJvf xbps-static-latest.i686-musl.tar.xz && rm xbps-static-latest.i686-musl.tar.xz

		# Default void repos use usr/share/xbps.d https repos, so ssl certs needed for these:
		echo "repository=${repo}/current" > usr/share/xbps.d/00-repository-main.conf
		echo "repository=${repo}/current/nonfree" > usr/share/xbps.d/10-repository-nonfree.conf
		# If no sslcertificates available can use insecure temporary /etc/xbps.d non-https repos:
		# But here we download/install sslcerts instead, from weedoglinux github repo, for higher build security:
#		wget -c https://gitlab.com/weedog/weedoglinux/-/raw/master/build_resources/sslcerts.tar.xz
#		tar xJf sslcerts.tar.xz && rm sslcerts.tar.xz
	fi

	# Install wiakwifi (can autostart on boot via /etc/profile/profile.d)
	wget -c https://gitlab.com/weedog/weedoglinux/-/raw/master/build_resources/wiakwifi -O usr/local/bin/wiakwifi
	chmod +x usr/local/bin/wiakwifi
	# Install wd_mount
	wget -c https://gitlab.com/weedog/weedoglinux/-/raw/master/build_resources/wd_mount -O usr/local/bin/wd_mount
	chmod +x usr/local/bin/wd_mount
	# cd to where we started this build (i.e. immediately outside of firstrib_rootfs):
	cd ..

	# Copy any firstrib plugins (f_*.plug) into firstrib_rootfs/tmp to be used (e.g. sourced) in chroot build part
	cp -a f_* firstrib_rootfs/tmp

	# Next part of script does bind mounts (not really required unless using I/O) for chroot and installs extras required
	mount --bind /proc firstrib_rootfs/proc && mount --bind /sys firstrib_rootfs/sys && mount --bind /dev firstrib_rootfs/dev && mount -t devpts devpts firstrib_rootfs/dev/pts && cp /etc/resolv.conf firstrib_rootfs/etc/resolv.conf

	# The following commands gets done inside firstrib_rootfs (via here_document pipe to chroot):
cat << INSIDE_CHROOT | LC_ALL=C chroot firstrib_rootfs sh
export PATH=/sbin:/usr/sbin:/bin:/usr/bin
case "$distro" in
	vnopm)
		# The optional f_XXX plugin text files named in "$firstribplugin" and "$firstribplugin01"
		# should each simply contain a list of extra commands
		[ -s /tmp/"${firstribplugin}" ] && . /tmp/"${firstribplugin}"
		[ -s /tmp/"${firstribplugin01}" ] && . /tmp/"${firstribplugin01}"
	;;
	vmini)
		SSL_NO_VERIFY_PEER=1 xbps-install -Suy xbps-triggers 
		# make sure xbps continues to use desired main and non-free repos
		echo "repository=${repo}/current" > usr/share/xbps.d/00-repository-main.conf
		echo "repository=${repo}/current/nonfree" > usr/share/xbps.d/10-repository-nonfree.conf
		sleep 1  # to give time for package installs to settle... maybe not required
		[ -s /tmp/"${firstribplugin}" ] && . /tmp/"${firstribplugin}"
		[ -s /tmp/"${firstribplugin01}" ] && . /tmp/"${firstribplugin01}"
	;;
	*)	# include base, and full non-static xbps
		SSL_NO_VERIFY_PEER=1 xbps-install -Suy xbps-triggers base-files xbps
		# make sure xbps continues to use desired main and non-free repos
		sleep 1  # to give time for xbps static to complete above installs
		echo "repository=${repo}/current" > usr/share/xbps.d/00-repository-main.conf
		echo "repository=${repo}/current/nonfree" > usr/share/xbps.d/10-repository-nonfree.conf
		rm /usr/bin/xbps*.static  # Since dynamic xbps now installed
		sleep 1  # to give time to make sure shared lib xbps will be used
		[ -s /tmp/"${firstribplugin}" ] && . /tmp/"${firstribplugin}"
		[ -s /tmp/"${firstribplugin01}" ] && . /tmp/"${firstribplugin01}"

		# NOTE WELL: if you want udev hotplug device/modules-autoload management daemon (most will)
		# and/or wpasupplicant you need to apt install them in an f_XXX build plugin
		# For a bootable system you'll also want linux kernel and appropriate firmware.
		# You may also need to configure system for use of other repos (e.g. non-free).
		# For some detailed examples, refer to already provided WDL FirstRib f_XXX plugin files available on download site.
	;;
esac
exit
INSIDE_CHROOT

	# Finished doing the INSIDE_CHROOT stuff so can now clean up the chroot bind mounts and clean /tmp:
	umount -l firstrib_rootfs/proc && umount -l firstrib_rootfs/sys && umount -l firstrib_rootfs/dev/pts && umount -l firstrib_rootfs/dev
	rm -rf firstrib_rootfs/tmp/*
}

_debian (){
	# If you want a variant other than minbase set env variable DBTSTRP_VARIANT to variant you desire
	# For example: export DBTSTRP_VARIANT=buildd (Refer: man debootstrap)
	debootstrap_url="$1"; distro_url="$2"; export distro_url

	# build firstrib_rootfsDBTSTRP
	mkdir -p firstrib_rootfsDBTSTRP
	cd firstrib_rootfsDBTSTRP
	# make rootfilesystem directory structure
	mkdir -p bin boot/kernel dev/pts etc/apt etc/skel etc/udhcpc home/debian lib media mnt opt proc root sbin sys tmp usr/bin usr/include usr/lib32 usr/libexec usr/lib/debootstrap usr/local/bin usr/local/include usr/local/lib usr/local/sbin usr/local/share usr/sbin usr/share/udhcpc usr/src var/log

	# Using i686 32-bit busybox to begin with (user can install coreutils later if so wanted)
	wget -c -nc "$busybox_url" -P bin && chmod +x bin/busybox
	# Make the command applet symlinks for busybox
	for i in `bin/busybox --list-full`; do ln -s /bin/busybox ${i}; done
	
	# Install Debian debootstrap into debian-based-build /usr hierarchy
	mkdir -p work
	cd work
	wget -c "$debootstrap_url"

	ar -x "${debootstrap_url##*/}"  # ar -x filename
	cd ..
	zcat work/data.tar.gz | tar xv && rm -rf work
	# Download pkgdetails from wiak github repo, for debootstrap
	wget -c https://raw.githubusercontent.com/firstrib/firstrib/master/pkgdetails_uclibc_i686_static_wiak -O usr/lib/debootstrap/pkgdetails && chmod +x usr/lib/debootstrap/pkgdetails

	# cd to where we started this build (i.e. immediately outside of firstrib_rootfsDBTSTRP):
	cd ..

	# Next part of script does bind mounts (not really required unless using I/O) for chroot used for debootstrap build
	mount --bind /proc firstrib_rootfsDBTSTRP/proc && mount --bind /sys firstrib_rootfsDBTSTRP/sys && mount --bind /dev firstrib_rootfsDBTSTRP/dev && mount -t devpts devpts firstrib_rootfsDBTSTRP/dev/pts && cp /etc/resolv.conf firstrib_rootfsDBTSTRP/etc/resolv.conf

	# debootstrap build is created inside firstrib_rootfsDBTSTRP (via here_document pipe to chroot):
	# Host Linux system does not need debootstrap installed (or perl)
cat << INSIDE_CHROOT | LC_ALL=C chroot firstrib_rootfsDBTSTRP /bin/sh
export PATH=/sbin:/usr/sbin:/bin:/usr/bin
variant="minbase"
[ "\$DBTSTRP_VARIANT" ] && variant="\$DBTSTRP_VARIANT"  # man debootstrap to see variants available
# Maybe --include apt-transport-https for older distro apt, but new distros (bionic) baulk since not needed
/usr/sbin/debootstrap --extractor=ar --arch=\$arch --variant=\$variant --include=ca-certificates \$release distro_root "\$distro_url"
exit
INSIDE_CHROOT

	# Finished doing the INSIDE_CHROOT stuff so can now clean up the chroot bind mounts:
	umount -l firstrib_rootfsDBTSTRP/proc && umount -l firstrib_rootfsDBTSTRP/sys && umount -l firstrib_rootfsDBTSTRP/dev/pts && umount -l firstrib_rootfsDBTSTRP/dev

	if [ ! -d firstrib_rootfsDBTSTRP/distro_root ]; then printf "\ndebootstrap download failed, please check its url\n";exit;fi
	cd firstrib_rootfsDBTSTRP/distro_root  # to add extra packages to debian-based filesystem
	mkdir -p etc/udhcpc
	# Fetch busybox udhcpc example simple.script renamed to etc/udhcpc/default.script 
	wget -c https://git.busybox.net/busybox/plain/examples/udhcp/simple.script -O etc/udhcpc/default.script && chmod +x etc/udhcpc/default.script
	sed -i 's/\$((metric++))/\$metric; metric=\$((metric+1))/' etc/udhcpc/default.script  # thanks rockedge for url of fix
	# But this static busybox udhcpc needs default.script in /usr/share/udhcpc (unlike debian shared busybox): wiak remove but maybe not here
	mkdir -p usr/share/udhcpc && cp etc/udhcpc/default.script usr/share/udhcpc/default.script  # wiak remove but maybe not needed here

	# Install wiakwifi (can remove these simple extras if not using them)
	wget -c https://gitlab.com/weedog/weedoglinux/-/raw/master/build_resources/wiakwifi -O usr/local/bin/wiakwifi
	chmod +x usr/local/bin/wiakwifi
	# Install wd_mount
	wget -c https://gitlab.com/weedog/weedoglinux/-/raw/master/build_resources/wd_mount -O usr/local/bin/wd_mount
	chmod +x usr/local/bin/wd_mount
	# cd to where we started this build (i.e. immediately outside of firstrib_rootfsDBTSTRP):
	cd ../..

	# Extract distro_root, the debian-based firstrib_rootfs build out of firstrib_rootfsDBTSTRP
	mv firstrib_rootfsDBTSTRP/distro_root firstrib_rootfs

	# Copy any firstrib plugins (f_*.plug) into firstrib_rootfs/tmp to be used (e.g. sourced) in chroot build part
	cp -a f_* firstrib_rootfs/tmp

	# Next part of script does bind mounts (not really required unless using I/O) for chroot used to
	# directly install extras required or by means of f_00.plug
	mount --bind /proc firstrib_rootfs/proc && mount --bind /sys firstrib_rootfs/sys && mount --bind /dev firstrib_rootfs/dev && mount -t devpts devpts firstrib_rootfs/dev/pts && cp /etc/resolv.conf firstrib_rootfs/etc/resolv.conf

	# The following commands gets done inside firstrib_rootfs (via here_document pipe to chroot):
cat << INSIDE_CHROOT2 | LC_ALL=C chroot firstrib_rootfs /bin/sh
export PATH=/sbin:/usr/sbin:/bin:/usr/bin
# The optional f_XXX plugin text files named in "$firstribplugin" and "$firstribplugin01"
# should each simply contain a list of extra commands
[ -s /tmp/"${firstribplugin}" ] && . /tmp/"${firstribplugin}"
[ -s /tmp/"${firstribplugin01}" ] && . /tmp/"${firstribplugin01}"

# NOTE WELL: if you want udev hotplug device/modules-autoload management daemon (most will)
# and/or wpasupplicant you need to apt install them in an f_XXX build plugin
# For a bootable system you'll also want linux kernel and appropriate firmware.
# You may also need to configure system for use of other repos (e.g. non-free).
# For some detailed examples, refer to already provided WDL FirstRib f_XXX plugin files available on download site.
exit
INSIDE_CHROOT2

	# Finished doing the INSIDE_CHROOT2 stuff so can now clean up the chroot bind mounts:
	umount -l firstrib_rootfs/proc && umount -l firstrib_rootfs/sys && umount -l firstrib_rootfs/dev/pts && umount -l firstrib_rootfs/dev
	rm -rf firstrib_rootfs/tmp/*
	# Clean up no longer required build assembly
	rm -rf firstrib_rootfsDBTSTRP
}

_arch_amd64 (){
	# Currently auto-downloading and using arch-bootstrap to create the base Arch rootfs build.
	# However, arch_bootstrap has several dependencies: 
	# bash >= 4, coreutils, wget, sed, gawk, tar, gzip, chroot, xz
	# so for simplicity building Arch base outside of chroot and relying on host system to provide these
	_arch_repo_mirrors # Choose Arch Linux repo to use for build

    mkdir -p firstrib_rootfs
    cd firstrib_rootfs
	# If no sslcertificates available can use insecure temporary /etc/xbps.d non-https repos:
	# But here we download/install sslcerts instead, from weedoglinux github repo, for higher build security:
#	wget -c https://gitlab.com/weedog/weedoglinux/-/raw/master/build_resources/sslcerts.tar.xz
#	tar xJf sslcerts.tar.xz && rm sslcerts.tar.xz
    cd ..  # to immediately outside of firstrib_rootfs
	# build firstrib_rootfs
	# Download arch_debootstrap scripts:
	wget -c https://gitlab.com/weedog/weedoglinux/-/raw/master/build_resources/arch-bootstrap.sh && chmod +x arch-bootstrap.sh
	./arch-bootstrap.sh -a $arch -r "${repo}" firstrib_rootfs
	cd firstrib_rootfs

	mkdir -p etc/udhcpc # needed to receive udhcpc default.script
	# Fetch busybox udhcpc example simple.script renamed to etc/udhcpc/default.script 
	wget -c https://git.busybox.net/busybox/plain/examples/udhcp/simple.script -O etc/udhcpc/default.script && chmod +x etc/udhcpc/default.script
	sed -i 's/\$((metric++))/\$metric; metric=\$((metric+1))/' etc/udhcpc/default.script  # thanks rockedge for url of fix
	# udhcpc sometimes needs default.script in /usr/share/udhcpc:
	mkdir -p usr/share/udhcpc && cp etc/udhcpc/default.script usr/share/udhcpc/default.script
	# Install wiakwifi and autostart on boot via /etc/profile/profile.d
	wget -c https://gitlab.com/weedog/weedoglinux/-/raw/master/build_resources/wiakwifi -O usr/local/bin/wiakwifi
	chmod +x usr/local/bin/wiakwifi
	# Install wd_mount
	wget -c https://gitlab.com/weedog/weedoglinux/-/raw/master/build_resources/wd_mount -O usr/local/bin/wd_mount
	chmod +x usr/local/bin/wd_mount
	cd .. # to immediately outside of firstrib_rootfs

	# Copy any firstrib plugins (f_*.plug) into firstrib_rootfs/tmp to be used (e.g. sourced) in chroot build part
	cp -a f_* firstrib_rootfs/tmp

	# Next part of script does bind mounts (not really required unless using I/O) for chroot and installs extras required
	mount --bind /proc firstrib_rootfs/proc && mount --bind /sys firstrib_rootfs/sys && mount --bind /dev firstrib_rootfs/dev && mount -t devpts devpts firstrib_rootfs/dev/pts && cp /etc/resolv.conf firstrib_rootfs/etc/resolv.conf

	# The following commands gets done inside firstrib_rootfs (via here_document pipe to chroot):
cat << INSIDE_CHROOT | LC_ALL=C chroot firstrib_rootfs sh
export PATH=/sbin:/usr/sbin:/bin:/usr/bin
# The optional f_XXX plugin text files named in "$firstribplugin" and "$firstribplugin01"
# should each simply contain a list of extra commands
[ -s /tmp/"${firstribplugin}" ] && . /tmp/"${firstribplugin}"
[ -s /tmp/"${firstribplugin01}" ] && . /tmp/"${firstribplugin01}"

# NOTE WELL: if you want udev hotplug device/modules-autoload management daemon (most will)
# and/or wpasupplicant you need to apt install them in an f_XXX build plugin
# For a bootable system you'll also want linux kernel and appropriate firmware.
# You may also need to configure system for use of other repos (e.g. non-free).
# For some detailed examples, refer to already provided WDL FirstRib f_XXX plugin files available on download site.
exit
INSIDE_CHROOT

	# Finished doing the INSIDE_CHROOT stuff so can now clean up the chroot bind mounts:
	umount -l firstrib_rootfs/proc && umount -l firstrib_rootfs/sys && umount -l firstrib_rootfs/dev/pts && umount -l firstrib_rootfs/dev
	rm -rf firstrib_rootfs/tmp/*
}

_arch_i686 (){ # wiak remove later: under dev/test/not-yet-released
	:
}
#### ----------------- end of functions used

case "$distro" in
	void|Void|vmini|vnopm)
		case "$arch" in
			amd64)
				_void_x86_64	# call build Void amd64 function
			;;
			i686)
				_void_i686		# call build Void i386 function
			;;
			arm64)
				echo "arch $arch is supported by Void but not yet FirstRib";_usage "--help";exit
			;;
			*) # no such arch catered for
				echo "$distro $release $arch not currently available from FirstRib";_usage "--help";exit
			;;
		esac
	;;
	ubuntu|Ubuntu)
		case "$release" in
			oldstable|stable|testing|unstable|xenial|bionic|focal|dingo)
				case "$arch" in
					amd64|i386|arm64) # wiak: I have no arm64 hardware, so arm untested and for development only
						debootstrap_url="$ubuntu_url"
						distro_url="http://archive.ubuntu.com/ubuntu/"
						_debian "$debootstrap_url" "$distro_url"  # call build debian function
					;;
					*) # no such arch catered for
						echo "$distro $release $arch not currently available from FirstRib";_usage "--help";exit
					;;
				esac
			;;
			*) # no such release catered for
				echo "$distro $release not currently available from FirstRib";_usage "--help";exit
			;;
		esac
	;;
	debian|Debian)
		case "$release" in
			oldstable|stable|testing|unstable|stretch|buster|sid)
				case "$arch" in
					amd64|i386|arm64) # wiak: I have no arm64 hardware, so arm untested and for development only
						debootstrap_url="$debian_url"
						distro_url="http://ftp.us.debian.org/debian/"
						_debian "$debootstrap_url" "$distro_url"  # call build debian function
					;;
					*) # no such arch catered for
						echo "$distro $release $arch not currently available from FirstRib";_usage "--help";exit
					;;
				esac
			;;
			*) # no such release catered for
				echo "$distro $release not currently available from FirstRib";_usage "--help";exit
			;;
		esac
	;;
	devuan|Devuan)
		case "$release" in
			oldstable|stable|testing|unstable|ascii|beowulf|ceres)
				case "$arch" in
					amd64|i386|arm64) # wiak: I have no arm64 hardware, so arm untested and for development only
						debootstrap_url="$devuan_url"
						distro_url="http://pkgmaster.devuan.org/merged/"
						_debian "$debootstrap_url" "$distro_url"  # call build debian function
					;;
					*) # no such arch catered for
						echo "$distro $release $arch not currently available from FirstRib";_usage "--help";exit
					;;
				esac
			;;
			*) # no such release catered for
				echo "$distro $release not currently available from FirstRib";_usage "--help";exit
			;;
		esac
	;;
	arch|Arch)  # wiak remove later: Arch Linux - under development
		case "$arch" in
			amd64)
				arch=x86_64
				_arch_amd64  # call build Arch amd64 function
			;;
			i686)
				_arch_i686  # call build Arch i686 function
			;;
			*) # no such arch catered for
				echo "$distro $release $arch not currently available from FirstRib";_usage "--help";exit
			;;
		esac
	;;
	*) # no such distro catered for
	echo "distro $distro not currently available from FirstRib";_usage "--help";exit
	;;
esac
sync
printf "
Assuming no errors have occurred above,
firstrib_rootfs flavour $distro $release $arch is now ready.
If you wish, you can now use it via convenience script,
./mount_chrootXXX.sh and after such use, exit, and, IMPORTANT:
run ./umount_chrootXXX.sh to clean up temporary mounts.
Or, you can make it bootable via WeeDog initramfs by running:
./build_weedog_initrdXXX.sh <distroname> [OPTIONS], and then
frugal install it by copying the resultant initrdXX, vmlinuz,
and 01firstrib_rootfs.sfs (or 01firstrib_rootfs directory) into
/mnt/bootpartition/bootdir and configuring grub to boot it.
More details on booting at end of build_weedog_initrd script.
Refer to WeeDog documentation if you wish to use optional plugins.
"
exit
