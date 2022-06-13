#!/bin/sh
## Build_weedog_initrd_208 script to create
#    WeeDog Linux initrd from pre-created firstrib_rootfs
# Revision Date: 07Jun2020
# Copyright wiak (William McEwan) 30 May 2019+; Licence MIT (aka X11 license)

# This script tested with void, arch, ubuntu, debian, and devuan firstrib_rootfs
# It should alternatively work as a hybrid system with, e.g., BionicPup vmlinuz and processed zdrv.

#### variables-used-in-script:
# script commandline arguments $1 $2 $3 $4
# "$1" is distro (e.g. void); "$2" is optional mksquashfs compression (or "default");
# "$3" is optional "huge" initrd (or "default" being normal); $4 is optional busybox url to use
version="2.0.8"; revision="-rc7"
kernel="$1"
case "$1" in
	'-v'|'--version') printf "Build WeeDog initrd ${version}${revision}\n";exit;;
	'-h'|'--help'|'-?') printf '
Usage:
./build_weedog_initrd_NNN.sh [OPTIONS]
-v --version    	display version information and exit
-h --help -?    	display this help and exit
distro_name		(i.e. void, arch, ubuntu, debian, or devuan)
			auto-insert Linux distro modules/firmware into
			initrd and output associated Linux kernel;
			all of which must be pre-installed into
			firstrib_rootfs build.
Optional second argument is mksquashfs compression (or "default")
Optional third argument is "huge" (or "default" being normal) initrd
"huge" includes 01firstrib_rootfs.sfs inside initrd/boot/initrdNN
Optional fourth argument is busybox_url (in case, e.g. arm64 required)
fourth argument can optionally also be "default"
Optional fifth argument is "nosfs" for no 01firstrib_rootfs.sfs wanted
EXAMPLES: 
./build_weedog_initrd_NNN.sh void # or arch, debian, ubuntu, devuan
./build_weedog_initrd_NNN.sh void "-comp lz4 -Xhc"
./build_weedog_initrd_NNN.sh void default huge
NOTES: Prior to running this script make sure shadow passwords have been
set up in firstrib_rootfs and REMEMBER to set: passwd root
For more details visit https://gitlab.com/weedog/weedoglinux
';exit;;
esac

# If using $1 option distro_name (e.g. void), ensure kernel exists in firstrib_rootfs
if [ ! "$kernel" == "" ]; then
	kernels="`ls firstrib_rootfs/boot/vmlinuz*`"
	kcount=`echo "$kernels" | wc -w`
	if [ $kcount -gt 1 ];then
		printf '
firstrib_rootfs contains more than one kernel/modules combination.
By default the alphabetically last of these will be used for WeeDog
initrd. If you wish to remove any of these kernels (using for
example mount_chrootXXX.sh and "vkpurge rm" command followed by
umount_chrootXX.sh) you can do so now.
Once you are ready to continue, please Enter the number
of the kernel you wish to use with your initrd
or simply press Enter to use most recent available kernel
'
		ls -1 firstrib_rootfs/boot/vmlinuz* | cat -n
		 read
	fi
	kernel1="`ls -1 firstrib_rootfs/boot/vmlinuz* | sed -n ${REPLY:-${kcount}}p`"
	[ ! -f "$kernel1" ] && printf "\nfirstrib_rootfs needs to at least include:\nlinuxX.XX, ncurses-base, and linux-firmware-network,\nand optional small extra wifi-firmware.\nOr simply install ncurses-base, and template: linux\n(which, if Void, also brings nvidia, amd, i915 and more graphics drivers)\n" && exit
	kernel_version="${kernel1##*vmlinuz-}"  # for use copying /usr/lib/modules/"${kernel_version}"	
fi

case "$2" in
	'default'|'') comp="";;  # use default compression for mksquashfs of firstrib_rootfs
	*) comp="$2";;
esac
case "$3" in
	'default'|'') huge="false";;
	'huge') huge="true";;  # 01firstrib_rootfs.sfs gets copied to initrd/boot/initrdNN
esac
case "$4" in
	'default'|'') busybox_url="https://busybox.net/downloads/binaries/1.30.0-i686/busybox";;
	*) busybox_url="$4";;
esac
# ----------------------------------------------------- end-of-variables-used-in-build-script

#### functions-used-in-build-script:
_modprobe_modules (){
	# appending modprobe code for initrd/init
	# The following gets inserted into init between CODE_FOR_INITRD_INITa and CODE_FOR_INITRD_INITc
	cat >> 00weedog_initrd/init << "CODE_FOR_INITRD_INITb"
# Modules need loaded by initrd when using kernel from Void Linux
for m in mbcache aufs exportfs ext4 fat vfat fuse isofs nls_cp437 nls_iso8859-1 nls_utf8 reiserfs squashfs xfs libata ahci libahci sata_sil24 pdc_adma sata_qstor sata_sx4 ata_piix sata_mv sata_nv sata_promise sata_sil sata_sis sata_svw sata_uli sata_via sata_vsc pata_ali pata_amd pata_artop pata_atiixp pata_atp867x pata_cmd64x pata_cs5520 pata_cs5530 pata_cs5535 pata_cs5536 pata_efar pata_hpt366 pata_hpt37x pata_it8213 pata_it821x pata_jmicron pata_marvell pata_netcell pata_ns87415 pata_oldpiix pata_pdc2027x pata_pdc202xx_old pata_rdc pata_sc1200 pata_sch pata_serverworks pata_sil680 pata_sis pata_triflex pata_via pata_isapnp pata_mpiix pata_ns87410 pata_opti pata_rz1000 ata_generic loop cdrom hid hid_generic usbhid mptscsih mptspi mptsas tifm_core cb710 mmc_block mmc_core sdhci sdhci-pci wbsd tifm_sd cb710-mmc via-sdmmc vub300 sdhci-pltfm scsi_mod scsi_transport_spi scsi_transport_sas sd_mod sr_mod usb-common usbcore ehci-hcd ehci-pci ohci-hcd uhci-hcd xhci-pci xhci-hcd usb-storage xts uas;do
	[ $w_debug -eq 0 ] && echo "loading module $m"
	[ "$m" != "$w_rmmodule" ] && modprobe $m 2>/dev/null
done
[ "$w_addmodule" != "" ] && modprobe $w_addmodule 2>/dev/null
# need delay for usb modules load to succeed but function
# _find_fs should do it anyway so w_usbwait shouldn't be required:
if [ "$w_usbwait" ]; then echo "w_usbwait... delay of $w_usbwait seconds"; sleep $w_usbwait;fi

CODE_FOR_INITRD_INITb
}

# Stage1: Create root filesystem for inside the initrd:

mkdir -p 00weedog_initrd
cd 00weedog_initrd
mkdir -p boot/kernel dev/pts etc/skel etc/udhcpc etc/xbps.d home/void media mnt opt proc root run sys tmp usr/bin usr/lib/modules usr/include usr/lib32 usr/libexec usr/local/bin usr/local/include usr/local/lib usr/local/sbin usr/local/share usr/share/udhcpc usr/share/xbps.d usr/src var/log var/lock

# The following is per Void Linux structure. e.g. puts most all binaries in /bin and most all libs in /usr/lib:
ln -sT usr/bin bin; ln -sT usr/lib lib; ln -sT usr/sbin sbin
ln -sT bin usr/sbin; ln -sT usr/lib lib64

# Using i686 32-bit busybox, even in x86_64 build
wget -c -nc "$busybox_url" -P usr/bin && chmod +x usr/bin/busybox

# Make the command applet hardlinks for busybox
cd usr/bin; for i in `./busybox --list`; do ln -s busybox $i; done; cd ../..

# cd to where we started this build (i.e. immediately outside of firstrib_rootfs):
cd ..

# Stage2: Create the initrd/init, and main root filesystem inittab and /etc/rc.d/rc.sysinit scripts:

# Create /init script for inside main weedog_initrd build (can modify to simple call /sbin/init)
# using a cat heredocument to redirect the code lines into init:
cat > 00weedog_initrd/init << "CODE_FOR_INITRD_INITa"
#!/bin/sh
# initrd/init(05): simple switch_root init with overlay filesystem set up.
# Copyright William McEwan (wiak) 26 July 2019+; Licence MIT (aka X11 license)
# Revision 2.0.8  Date: 26 Apr 2020
# YMD 20191003: implemented seaside's wait on bootpartition idea

# prevent all messages on console, except emergency (panic) messages
dmesg -n 1

# mount kernel required virtual filesystems and populate /dev
mount -t proc -o nodev,noexec,nosuid proc /proc
mount -t sysfs -o nodev,noexec,nosuid sysfs /sys
mount -t devtmpfs -o mode=0755 none /dev

# Familiarise yourself with the following key variables used prior to reading this script:

# kernel : distro vmlinuz and modules/firmware that will be used
# w_bootfrom  : vmlinuz/initrd.gz location
# w_changes  		# none, RAM, readonly, path2dir
# w_altNN : alternative/additional location for NNfiles for mounting to the NN overlay layers
# w_debug			# Debugging off (boolean 1 means false)
# w_rmmodule		# Name of module from main list you don't want loaded
# w_addmodule		# Name of extra module to load (modprobe)
# w_usbwait			# wait seconds for slow devices
grep -q w_copy2ram /proc/cmdline 2>/dev/null; w_copy2ram=$?  # w_copy2ram is boolean 0(true) or 1(false)
grep -q w_debug /proc/cmdline 2>/dev/null; w_debug=$?  # w_debug is boolean 0(true) or 1(false)

layers_base=/mnt/layers			# making this a variable in case useful to move somewhere else
mkdir -p ${layers_base}/RAM		# for (upper_)w_changes=RAM and w_copy2ram storage in tmpfs


# Functions ----------------------------------------------------------

# find filesystem boot partition (bootmnt) location when UUID or LABEL used for grub...
_find_fs(){
	echo -e "\e[33mSeeking boot partition\nDelay will be variable up to timeout of 30 seconds ...\e[0m" >/dev/console
	printf "Please wait: "
	c=0  # timeout counter for findfs ...
	while ! bootmnt="`findfs ${w_bootfrom%=*} 2>/dev/null`"; do
		c=$((c+1))
		[ $c -gt 60 ] && break
		printf "."
		sleep .5
	done
	[ $c -gt 30 ] && _w_rdsh seek_timeout debug
	bootmnt="`echo "$bootmnt" | sed 's/dev/mnt/'`"
	echo "boot partition is $bootmnt"
}

# find (alternative) numbered sfs (altNNmnt) partition location when UUID or LABEL used for grub...
_find_fs_altNN(){
	echo -e "\e[33mSeeking alternative sfs files partition\nDelay will be variable up to timeout of 30 seconds ...\e[0m" >/dev/console
	printf "Please wait: "
	c=0  # timeout counter for findfs ...
	while ! altNNmnt="`findfs ${w_altNN%=*} 2>/dev/null`"; do
		c=$((c+1))
		[ $c -gt 60 ] && break
		printf "."
		sleep .5
	done
	[ $c -gt 30 ] && _w_rdsh seek_timeout debug
	altNNmnt="`echo "$altNNmnt" | sed 's/dev/mnt/'`"
	echo "alternative sfs files partition is $altNNmnt"
}

# find (alternative) changes partition (changesmnt) location when UUID or LABEL used for grub...
_find_fs_changes(){
	echo -e "\e[33mSeeking changes partition\nDelay will be variable up to timeout of 30 seconds ...\e[0m" >/dev/console
	printf "Please wait: "
	c=0  # timeout counter for findfs ...
	while ! changesmnt="`findfs ${w_changes%=*} 2>/dev/null`"; do
		c=$((c+1))
		[ $c -gt 60 ] && break
		printf "."
		sleep .5
	done
	[ $c -gt 30 ] && _w_rdsh seek_timeout debug
	changesmnt="`echo "$changesmnt" | sed 's/dev/mnt/'`"
	echo "changes partition is $changesmnt"
}

# process any grub linux/kernel line w_rdshN argument or "debug" instruction for source plugin or debug sh
_w_rdsh (){
	[ -s "${mountfrom}"/${1}.plug ] && . "${mountfrom}"/${1}.plug
	if grep -q $1 /proc/cmdline || [ "$2" == "debug" ]; then
			# Start a busybox job control debug shell at initrd/init w_rdsh break point
			# Note that this cttyhack sh debug process doesn't work with Arch Linux flavour somehow
			echo "In initrd/init at $1. Enter exit to continue boot:"
			setsid cttyhack sh
	fi
}

# mount any NNsfs files or NNdir(s) to layers_base/NN layer
# and add to overlay "lower" list
_addlayer (){
  for addlayer in *; do
	NN="${addlayer:0:2}" # gets first two characters and below checks they are numeric (-gt 00)
	if [ "$NN" -gt 0 ] 2>/dev/null; then
		if [ "${addlayer##*.}" == "sfs" ]; then
			# layer to mount is an sfs file
			lower="${NN} ${lower}"
			mkdir -p "${layers_base}/$NN"
			# umount any previous lower precedence mount
			mountpoint -q "${layers_base}/$NN" && umount "${layers_base}/$NN"
			mount "${addlayer}" "${layers_base}/$NN"
		elif [ -d "$addlayer" ]; then
			# layer to mount is an uncompressed directory
			lower="${NN} ${lower}"
			mkdir -p "${layers_base}/$NN"
			# umount any previous lower precedence mount
			mountpoint -q "${layers_base}/$NN" && umount "${layers_base}/$NN"
			mount --bind "${addlayer}" "${layers_base}/$NN"
		fi
	fi
  done
  sync
  echo -e "\e[95mCurrent directory is `pwd`\e[0m" >/dev/console
  echo -e "\e[95mlower_accumulated is ${lower:-empty list}\e[0m" >/dev/console
}

# --------------------------------------------------------------------
CODE_FOR_INITRD_INITa

# Modules need to be loaded by initrd/init if distro_name kernel being used
case "$kernel" in
	void)
		# Copy in Void Linux kernel modules and firmware from firstrib_rootfs,
		# and copy out Void kernel vmlinuz for later copying to /mnt/bootpartition/bootdir
		echo "Copying Void Linux modules to initrd build. Please wait patiently..."
		cp -af firstrib_rootfs/usr/lib/modules/"${kernel_version}" 00weedog_initrd/usr/lib/modules
		cp -a "${kernel1}" .

		# initrd/init needs to load sufficient modules to boot system
		_modprobe_modules
	  ;;
	arch)
		# Copy in Arch Linux kernel modules and firmware from firstrib_rootfs,
		# and copy out Arch kernel vmlinuz for later copying to /mnt/bootpartition/bootdir
		echo "Copying Arch Linux modules to initrd build. Please wait patiently..."
		cp -af firstrib_rootfs/usr/lib/modules/* 00weedog_initrd/usr/lib/modules
		cp -a "${kernel1}" .

		# initrd/init needs to load sufficient modules to boot system
		_modprobe_modules
	  ;;
	ubuntu|debian|devuan)
		# Copy in deb-based Linux kernel modules and firmware from firstrib_rootfs,
		# and copy out deb-based kernel vmlinuz for later copying to /mnt/bootpartition/bootdir
		echo "Copying Void Linux modules to initrd build. Please wait patiently..."
		cp -af firstrib_rootfs/lib/modules/"${kernel_version}" 00weedog_initrd/usr/lib/modules
		cp -a "${kernel1}" .

		# initrd/init needs to load sufficient modules to boot system
		_modprobe_modules
	  ;;
esac

cat >> 00weedog_initrd/init << "CODE_FOR_INITRD_INITc"
## MAIN

# The following accepts kernel args of the form: w_bootfrom=/dev/sdXX, or
# w_bootfrom=UUID=xxx, w_bootfrom=LABEL=xxx
if `echo "$w_bootfrom" | grep -q 'UUID'`; then
	_find_fs  # e.g. /mnt/sda1
	from_path="${w_bootfrom##*=}"
	w_bootfrom="${bootmnt}""${from_path}"
elif `echo "$w_bootfrom" | grep -q 'LABEL'`; then
	_find_fs
	from_path="${w_bootfrom##*=}"
	w_bootfrom="${bootmnt}""${from_path}"
else
	:  # bootmnt=`echo "$w_bootfrom" | awk -F "/" '{print "/"$2"/"$3}'`  # but not required
fi

mountfrom="${w_bootfrom}" # where layers are mounted from. e.g. w_bootfrom dir or from layers_base/RAM
bootpartition=`echo "$w_bootfrom" | cut -d/ -f3` # extract partition name

# inram_sz=NNN[%]  # (from: man mount - tmpfs option size=): Override default maximum size of the filesystem. The size is given in bytes, and rounded up to entire pages. The default is half of the memory. The size parameter also accepts a suffix % to limit this tmpfs instance to that percentage of your physical RAM: the default, when neither size nor nr_blocks is specified, is size=50%

[ ! "$inram_sz" == "" ] && inram_sz=",size=${inram_sz}" || inram_sz=",size=100%"  # size of tmpfs inram for layers_base/RAM
mount -o mode=1777,nosuid,nodev${inram_sz} -n -t tmpfs inram ${layers_base}/RAM  # for w_changes=RAM;w_copy2ram

mkdir -p /mnt/${bootpartition}
echo -e "\e[33mAttempting to mount partition\nDelay will be variable up to timeout of 30 seconds ...\e[0m" >/dev/console
printf "Please wait: "
c=0  # timeout counter for attempt to mount bootpartition
while ! mount /dev/${bootpartition} /mnt/${bootpartition} 2>/dev/null; do
	c=$((c+1))
	[ $c -gt 60 ] && break
	printf "."
	sleep .5
done
[ $c -gt 30 ] && _w_rdsh seek_timeout debug

_w_rdsh w_rdsh0  # Source w_rdsh0.plug if it exists. Thereafter, if grub kernel-line w_rdsh0 specified start busybox debug shell
_w_rdsh w_inram00  # Source w_inram00 plugin, for example to set up swap space or zram

cd "${w_bootfrom}" # where the NN files/dirs and w_rdshN.plug files are
if	[ $w_copy2ram -eq 0 ]; then
	echo -e "\e[33mCopying all NNsfs, NNdirs and w_rdsh plugins to RAM. Please wait patiently...\e[0m" >/dev/console
	mountfrom="${layers_base}/RAM"  # which is tmpfs in RAM
	# copy all NNsfs, NNdirectories and any w_rdsh plugin files to RAM ready for mounting to layers
	for addlayer in *; do
		NN="${addlayer:0:2}" # gets first two characters and below checks they are numeric (-ge 00)
		if [ "$NN" -ge 0 ] 2>/dev/null; then cp -a "$addlayer" "${mountfrom}"; fi
	done
	cp -a w_rdsh*.plug "${mountfrom}" 2>/dev/null
	cp -a modules_remove.plug "${mountfrom}" 2>/dev/null
	cp -a w_pre_switch_root.plug "${mountfrom}" 2>/dev/null
	cp -a w_inram00.plug "${mountfrom}" 2>/dev/null  # probably not needed here but ok
	cp -a seek_timeout.plug "${mountfrom}" 2>/dev/null  # probably not needed here but ok
	sync; sync; cd /  # so can umount bootpartion
fi

# Different filesystems use different inode numbers. xino provides translation to fix the issue
# but often doesn't work if w_changes filesystem different from rootfs (so then need unpreferred xino=off)
#xino=`egrep -o "xino=[^ ]+" /proc/cmdline | cut -d= -f2`  # can force xino value at grub kernel line
[ "$xino" == "" ] || xino=",xino=$xino"

_w_rdsh w_rdsh1  # Source w_rdsh1.plug if it exists. Thereafter, if grub kernel-line w_rdsh0 specified start busybox debug shell

# There are four alternative "w_changes=" modes: empty arg, w_changes=RAM, w_changes=readonly, w_changes="path2dir"
# 1. No w_changes argument on grub kernel line: Use upper_changes in /mnt/bootpartition/bootdir
# 2. RAM: All changes go to RAM only (layers_base/RAM/upper_changes). i.e. non-persistent
# 3. readonly: overlay filesystem is rendered read only so it cannot be written to at all
# 4. path2dir: store upper_changes in specified path/directory at upper_changes subdirectory
if [ -z $w_changes ]; then
	# xino seems to default to off but if desired can later try to force xino=on using grub kernel line
	mkdir -p "${w_bootfrom}"/upper_changes "${w_bootfrom}"/work  # for rw persistence
	upper_work="upperdir=""${w_bootfrom}""/upper_changes,workdir=""${w_bootfrom}""/work${xino}"
elif [ "$w_changes" == "RAM" ]; then
	[ $w_copy2ram -eq 0 ] && umount_bootdevice="allowed"  # since everything in RAM can umount bootdevice
	mkdir -p ${layers_base}/RAM/upper_changes ${layers_base}/RAM/work
	upper_work="upperdir=${layers_base}/RAM/upper_changes,workdir=${layers_base}/RAM/work${xino}"
elif [ "$w_changes" == "readonly" ]; then
	[ $w_copy2ram -eq 0 ] && umount_bootdevice="allowed"  # since everything in RAM can umount bootdevice
	upper_work=""
else
	if `echo "$w_changes" | grep -q 'UUID'`; then
		_find_fs_changes  # e.g. /mnt/sdc3
		from_path="${w_changes##*=}"
		w_changes="${changesmnt}""${from_path}"
	elif `echo "$w_changes" | grep -q 'LABEL'`; then
		_find_fs_changes
		from_path="${w_changes##*=}"
		w_changes="${changesmnt}""${from_path}"
	else
		:  # changesmnt=`echo "$w_changes" | awk -F "/" '{print "/"$2"/"$3}'`  # but not required
	fi
	# Mount partition to be used for upper_changes
	changes_partition=`echo "$w_changes" | cut -d/ -f3` # extract partition name
	mkdir -p /mnt/${changes_partition} && mount /dev/${changes_partition} /mnt/${changes_partition}
	mkdir -p "${w_changes}"/upper_changes "${w_changes}"/work
	[ "$xino" == "" ] && xino=",xino=off"  # But can later try to force xino=on, if desired, using grub
	upper_work="upperdir=""${w_changes}""/upper_changes,workdir=""${w_changes}""/work${xino}"
	[ $w_copy2ram -eq 0 ] && umount_bootdevice="allowed"  # as long as changes_partition different to bootpartition can umount bootdevice
fi

# Make sfs mount and layers directories and bind and mount them appropriately as follows:

mkdir -p ${layers_base}/merged  # For the combined overlay result

# make lower overlay a series of mounts of either sfs files or 
# uncompressed directories named in the form NNfilename.sfs or NNdirectoryname
# NN numeric value determines order of overlay loading. 01 is lowest layer.
# 00firstrib_firmware_modules.sfs is handled separately
lower=""  # Initialise overlay 'lower' list

# Mount any NNsfs files in initrd to appropriate NN overlays
# If there are any they must be stored in initrd dir /boot/initrdNN
mkdir -p /boot/initrdNN; cd /boot/initrdNN
# mount any NNsfs files or NNdir(s) to layers_base/NN layer
_addlayer	# and add (lowest priority) to overlay "lower" layers list

# Mount any NNsfs files in mountfrom to appropriate NN overlays
cd "${mountfrom}"  # i.e. w_bootfrom dir or layers_base/RAM
_addlayer  # add/replace mounts (middle priority) and add to overlay "lower" layers list

# If w_altNN=path2dir specified on commandline
if [ ! -z $w_altNN ]; then
	if `echo "$w_altNN" | grep -q 'UUID'`; then
		_find_fs_altNN  # e.g. /mnt/sda1
		from_path="${w_altNN##*=}"
		w_altNN="${altNNmnt}""${from_path}"
	elif `echo "$w_altNN" | grep -q 'LABEL'`; then
		_find_fs_altNN
		from_path="${w_altNN##*=}"
		w_altNN="${altNNmnt}""${from_path}"
	else
		:  # altNNmnt=`echo "$w_altNN" | awk -F "/" '{print "/"$2"/"$3}'`  # but not required
	fi
	# Mount partition containing w_altNN location
	w_altNN_partition=`echo "$w_altNN" | cut -d/ -f3` # extract partition name
	mkdir -p /mnt/${w_altNN_partition} && mount /dev/${w_altNN_partition} /mnt/${w_altNN_partition}
	cd "$w_altNN"
	_addlayer  # add/replace mounts (highest priority) and add to overlay "lower" layers list
fi

_w_rdsh w_rdsh2  # Source w_rdsh2.plug if it exists. Thereafter, if grub kernel-line w_rdsh2 specified start busybox debug shell

# Sort resulting overlay 'lower' layers list
# add new NN item to overlay \$lower list, reverse sort the list, and mount NNfirstrib_rootfs	
lower="`for i in $lower; do echo $i; done | sort -ru`"  # sort the list and remove duplicates

# If using 00firstrib_firmware_modules.sfs do the following
# Otherwise, if using Void Linux kernel, you need to make sure needed /usr/lib/firmware and modules
# are in firstrib_rootfs build via xbps-install linuxX.XX, ncurses-base, linux-firmware-network etc
firmware_modules_sfs=""
if [ -s "${mountfrom}"/00firstrib_firmware_modules.sfs ];then
	firmware_modules_sfs="00firmware_modules:"
	mkdir -p ${layers_base}/00firmware_modules /usr/lib/modules
	mount "${mountfrom}"/00firstrib_firmware_modules.sfs ${layers_base}/00firmware_modules
	sleep 1  # may not be required
	mount --bind ${layers_base}/00firmware_modules/usr/lib/modules /usr/lib/modules  # needed for overlayfs module
fi

# Load module to allow overlay filesystem functionality
modprobe overlay && umount /usr/lib/modules 2>/dev/null  # modules to be reloaded during overlay merge 
sync

# compress whitespace and remove leading/trailing and put required colons into ${lower} layers list
lower="`echo $lower | awk '{$1=$1;print}'`"; lower=${lower// /:} # ${var//spacePattern/colonReplacement}

echo -e "\e[95mw_bootfrom is ${w_bootfrom:-ERROR}\e[0m" >/dev/console
echo -e "\e[95mmountfrom is ${mountfrom:-ERROR}\e[0m" >/dev/console
echo -e "\e[95mw_altNN is ${w_altNN:-not defined on grub kernel line}\e[0m" >/dev/console
echo -e "\e[95mlower (sorted/unique) is ${lower:-ERROR}\e[0m" >/dev/console
echo -e "\e[95mupper_work is ${upper_work:-readonly}\e[0m" >/dev/console

_w_rdsh w_rdsh3  # Source w_rdsh3.plug if it exists. Thereafter, if grub kernel-line w_rdsh3 specified start busybox debug shell

cd ${layers_base}	# Since this is where the overlay mountpoints are
# Combine the overlays with result in ${layers_base}/merged
mount -t overlay -o lowerdir=${firmware_modules_sfs}${lower},"${upper_work}" overlay_result merged

_w_rdsh w_rdsh4  # Source w_rdsh4.plug if it exists. Thereafter, if grub kernel-line w_rdsh4 specified start busybox debug shell

# Prior to switch_root need to --move main mounts to new rootfs merged:
mkdir -p merged/mnt/${bootpartition} merged${layers_base}/RAM
mountpoint -q /mnt/${bootpartition} && mount --move /mnt/${bootpartition} merged/mnt/${bootpartition}
if [ ! -z "$changes_partition" ];then mkdir -p merged/mnt/${changes_partition} && mount --move /mnt/${changes_partition} merged/mnt/${changes_partition};fi

# Make tmpfs RAM available in overlay merged
mount --move ${layers_base}/RAM merged${layers_base}/RAM

if [ -f merged"${mountfrom}"/modules_remove.plug ]; then  # source modules_remove plugin
	. merged"${mountfrom}"/modules_remove.plug
else
	# Remove unused modules to save memory
	modprobe -r `lsmod | cut -d' ' -f1 | grep -Ev 'ehci|xhci|sdhci|uas|usbhid'` 2>/dev/null  # keep ehci,xhci,sdhci,uas,usbhid
fi

# If grub kernel-line w_rdsh5 specified then start busybox debug shell
_w_rdsh w_rdsh5

[ "$umount_bootdevice" == "allowed" ] && echo -e "\e[96mYou can now umount bootdevice if you wish\e[0m" >/dev/console

# if w_pre_switch_root.plug exists in w_bootfrom directory source it
[ -s merged"${mountfrom}"/w_pre_switch_root.plug ] && . merged"${mountfrom}"/w_pre_switch_root.plug

# Unmount virtual filesystems prior to making switch_root to main merged root filesystem
umount /dev && umount /sys && umount /proc && sync
exec switch_root merged /sbin/init
CODE_FOR_INITRD_INITc
# make firstrib_rootfs_for_initrd/init script executable:
chmod +x 00weedog_initrd/init

if [ "$kernel" == "void" ]; then # do this section only if kernel=void
	# Create inittab file for inside main firstrib_rootfs build
	cat > firstrib_rootfs/etc/inittab << "CODE_FOR_ROOTFS_INITTAB"
::sysinit:/etc/rc.d/rc.sysinit
::ctrlaltdel:/sbin/reboot -f
CODE_FOR_ROOTFS_INITTAB
	# Note that inittab causes the switch_root called busybox (sysv)init to
	# run script /etc/rc.d/rc.sysinit, which is coded below

	# Create rc.sysinit script for inside main firstrib_rootfs build
	mkdir -p firstrib_rootfs/etc/rc.d
	cat > firstrib_rootfs/etc/rc.d/rc.sysinit << "CODE_FOR_ROOTFS_RC_SYSINIT"
#!/bin/sh
# rc.sysinit: Copyright William McEwan (wiak) 16 July 2019; Licence MIT (aka X11 license)
# Revision 2.0.8 26 Apr 2020

# In simplest FirstRib initrd this rc.sysinit script is called
# via /sbin/init being, via /usr/bin/init, a symlink to /usr/bin/busybox (sysv)init,
# which automatically reads /etc/inittab file whose first line says to run this script.
# Should runit-void package be installed, /usr/bin/init should be modified
# to become instead a symlink to /usr/bin/runit-init. Then /etc/runit
# scripts will be used automatically by runit services instead,
# and this script will not be used.
# If you want to run without any init, just modify /usr/bin/init to be a symlink to /etc/rc.d/rc.sysinit

# The first part of the following is modified/skeleton extract from
# Void Linux /etc/runit/core-services/00-pseudofs.sh
# so we partly know what to expect should we later move to runit-init system

#msg "Mounting pseudo-filesystems..."
mountpoint -q /proc || mount -o nosuid,noexec,nodev -t proc proc /proc
mountpoint -q /sys || mount -o nosuid,noexec,nodev -t sysfs sys /sys
mountpoint -q /run || mount -o mode=0755,nosuid,nodev,size=$((`free | grep 'Mem: ' | tr -s ' ' | cut -f 4 -d ' '`/4))k -t tmpfs run /run  # this version needs entry in /etc/fstab like in Void Linux
mountpoint -q /dev || mount -o mode=0755,nosuid -t devtmpfs dev /dev
mkdir -p -m0755 /run/runit /run/lvm /run/user /run/lock /run/log /dev/pts /dev/shm
mountpoint -q /dev/pts || mount -o mode=0620,gid=5,nosuid,noexec -n -t devpts devpts /dev/pts
mountpoint -q /dev/shm || mount -o mode=1777,nosuid,nodev,size=$((`free | grep 'Mem: ' | tr -s ' ' | cut -f 4 -d ' '`/4))k -n -t tmpfs shm /dev/shm
mountpoint -q /tmp || mount -t tmpfs -o mode=1777,nosuid,nodev,size=$((`free | grep 'Mem: ' | tr -s ' ' | cut -f 4 -d ' '`/4))k tmpfs /tmp
mountpoint -q /sys/kernel/security || mount -n -t securityfs securityfs /sys/kernel/security
# end of modified/skeleton extract from Void /etc/runit/core-services/00-pseudofs.sh

[ -x /etc/rc.local ] && /etc/rc.local	# If /etc/rc.local script exists and is executable, run it
										# User can add custom commands into that script
echo "Starting udev and waiting for devices to settle..." >/dev/console
udevd --daemon
udevadm trigger --action=add --type=subsystems
udevadm trigger --action=add --type=devices
udevadm settle

printf "\e[44mWelcome to this FirstRib WeeDog (Void Linux flavour)\e[0m
\e[34mhttps://github.com/firstrib/firstrib
http://weedog.com\e[0m
" >/dev/console
										
# Don't really need busybox (sysv)init in this version
# since just running a simple shell in endless loop
while true # Do forever loop
do
	# this while loop means exit of shell always restarts new shell
	setsid sh -c 'exec sh </dev/tty1 >/dev/tty1 2>&1'
done
# Never reaches here:
exit
CODE_FOR_ROOTFS_RC_SYSINIT
	# make firstrib_rootfs/etc/rc.d/rc.sysinit script executable:
	chmod +x firstrib_rootfs/etc/rc.d/rc.sysinit
fi  # end of kernel=void only code section

#Stage3: create 01firstrib_rootfs.sfs and initrd.gz:

# Squash up filesystem firstrib_rootfs
# For high compression can use args: -comp xz -b 524288 -Xdict-size 524288 -Xbcj x86
# Some alternative mksquashfs compression possibilities:
# comp="-noX -noI -noD -noF"  # or simply use uncompressed NNdirectory
# comp="-comp lzo"
# comp="-comp lz4 -Xhc"
# comp="-comp xz -b 524288 -Xdict-size 524288 -Xbcj x86"
if [ "$5" != "nosfs" ];then
	mksquashfs firstrib_rootfs 01firstrib_rootfs.sfs -noappend $comp -wildcards -e 'var/cache/pacman/pkg/*' 'boot/*' # wildcards tip thanks fredx181
	if [ "$huge" == "true" ];then  # initrd to include 01firstrib_rootfs.sfs
		mkdir -p 00weedog_initrd/boot/initrdNN
		cp -a 01firstrib_rootfs.sfs 00weedog_initrd/boot/initrdNN
	fi
else
	if [ "$huge" == "true" ];then
		printf 'You cannot use option "huge" together with option "nosfs".
Making normal initrd instead.\n'
		huge="false"
	fi
fi
# If you want to copy extra sfs into initrd, or to simply do or
# create anything extra at this stage, you can code/source plugin below
if [ -s ./"weedog_extra_sfs.plug" ];then . ./"weedog_extra_sfs.plug";fi
# Next is simple mkinitrd code
# which does the actual creation of the initrd required for booting
cd 00weedog_initrd
# make a gz compressed cpio archive of weedog_rootfs naming it initrd.gz
if [ "$huge" == "true" ];then
	echo "Creating uncompressed initrd. Please wait patiently..."
	find . | cpio -oH newc > ../initrd  # uncompressed if huge initrd
else
	echo "Creating compressed initrd. Please wait patiently..."
	find . | cpio -oH newc 2>/dev/null | gzip > ../initrd.gz
fi
cd ..  # cd to immediately outside firstrib_rootfs directory
sync
printf '
initrd.gz and, unless "nosfs", 01firstrib_rootfs.sfs are now ready and, 
if $1 is distro_name, a copy of the vmlinuz-XXX kernel of that distro.
Copy these to your chosen boot partition/directory if not already in it.
You need either NNfirstrib_rootfs.sfs, renamed from the automatically
created 01firstrib_rootfs.sfs, OR:
a copy of the uncompressed firstrib_rootfs directory renamed to
NNfirstrib_rootfs, where NN should usually be 01 (lowest layer) but can
be 01 up to 99 (depending on layer position required).
You can also copy additional sfs files named NNsomething.sfs (or an 
unsquashed directory, of any such sfs, named NNsomething).
Finally create appropriate grub.cfg or grub4dos menu.lst boot entry
using kernel-line bootparams:
w_bootfrom=/mnt/partition/directory, or e.g. w_bootfrom=PARTUUID=xxx...
optional w_usbwait=duration. Required for slow devices when using UUID
optional w_rdshN arguments (where N=0,1,2,3,4 or 5) to force debug sh,
optional w_rdshN.plug files, which will be sourced by initrd/init,
optional w_inram00.plug, which will be sourced by initrd/init,
optional w_pre_switch_root.plug, which will be sourced by initrd/init,
optional w_copy2ram, to copy all NNsfs, NNdirs, w_rdshN.plug to RAM,
optional w_changes=[option] where option can be: RAM for no persistence,
readonly for no writes, or /mnt/partition/dir for dir location
where upper_changes subdir will be stored.
optional w_altNN=path2dir for alternative location for NNsfs/dirs.
Example grub4dos menu.lst if files installed to /mnt/sda4/WeeDogArch:
title WeeDogArch
root (hd0,3)  # or use, for example: uuid xxx-xxx-xxx-xxx
kernel /WeeDogArch/vmlinuz-linux w_bootfrom=/mnt/sda4/WeeDogArch
initrd /WeeDogArch/initrd.gz
Or use w_bootfrom=UUID=xxx-xxx.../dir or w_bootfrom=LABEL=xxx.../dir  
'
exit
