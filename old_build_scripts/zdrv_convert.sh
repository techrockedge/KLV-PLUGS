#!/bin/sh
# zdrv_convert.sh: Convert Pup zdrv /lib format to Void_FirstRib /usr/lib format
# Copyright wiak (William McEwan) 25 July 2019+; Licence MIT (aka X11 license)
# Revision 0.0.1 Date: 25 July 2019

usage (){
case "$1" in
	'-v'|'--version')	echo "Convert Pup zdrv /lib format to Void_FirstRib /usr/lib format. Revision 001"
						echo "This is for initramfs03 use (initramfs02 simply used renamed zdrv)";exit;;
	'-h'|'--help'|'-?') echo "Run this script from location of Puppy zdrv with command:"
						echo "./zdrv_convert.sh <filename of Puppy zdrv>"
						echo "For more details visit webpage: https://github.com/firstrib/firstrib";exit;;
esac
}
# ----------------------------------------------------- end-of-variables-used-in-script
usage "$1"
if [ -s "$1" ];then 
	[ -d /tmp/firstrib_zdrv ] && rm -rf /tmp/firstrib_zdrv
	mkdir -p /tmp/original_zdrv /tmp/firstrib_zdrv/usr
	mount ./${1} /tmp/original_zdrv # Mount file $1, which should be relevant zdrv name
	# cd to /tmp/firstrib and store original dir path on stack for later popd (return)
	pushd /tmp/original_zdrv 2>&1 >/dev/null
	echo "Copying original zdrv/lib to firstrib_zdrv/usr/lib. Please wait patiently..."
	cp -a lib ../firstrib_zdrv/usr/		# removes all but needed lib directory and puts in usr/lib
										# Void Linux puts most all libs in /usr/lib
	popd 2>&1 >/dev/null # return back to directory script was run from
	# You may need to change the compression options below depending on needs and system xz support
	mksquashfs /tmp/firstrib_zdrv 00firstrib_firmware_modules.sfs -comp xz -b 524288 -Xbcj x86
	sync
	umount /tmp/original_zdrv
	rm -rf /tmp/original_zdrv /tmp/firstrib_zdrv
	printf "
00firstrib_firmware_modules.sfs is now ready.
Copy it to your chosen boot partition/directory for use with initramfs03.gz
"
else
	printf "\nFilename provided as argument is empty or doesn't exist.\n"
	usage "-h"
fi
exit
