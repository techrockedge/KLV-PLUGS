#!/bin/sh
# Creation Date: 23May2019; Revision Date: 30Aug2021
# Copyright wiak (William McEwan) 23May2019+; Licence MIT (aka X11 license)
progname="modify_initrd_gz.sh"; version="4.0.0"; revision="-rc1"

case "$1" in
	'') printf "initrd name must be specified\n";exit;;
	'--version') printf "$progname ${version}${revision}\n"; exit 0;;
	'-h'|'--help'|'-?') printf "Run this script from location of gz-compressed initrd with command:
  $progname <filename>
  For example: ./modify_initrd_gz.sh initrd.gz\n";exit 0;;
	"-*") printf "option $1 not available\n";exit 0;;
esac
if [ ! -f "$1" ];then printf "No such file exists\n";exit 0;fi  
initrd=${1%.*}
mkdir -p ${initrd}_decompressed
cd ${initrd}_decompressed
zcat ../${1} | cpio -idm
printf "File ${1} has been decompressed into directory ${initrd}_decompressed
and a cd command to that directory has been made.
At this stage, you can use this new shell or another shell terminal
or gui program to modify the initrd contents.
For example, you can edit the initrd/init shell script if you wish,
or add/remove contents from/to this ${initrd}_decompressed directory
via shell commands or your favourite filemanager.
Once you have completed your modifications, simply type: exit
A new date-stamped ${initrd} gz will then be created in same directory
as the original ${1} and this ${initrd}_decompressed directory
will be automatically deleted.
Alternatively, if you simply want ${initrd}_decompressed, close this terminal.
"
sh
echo "Result being compressed. Please wait patiently ..."
datestamp=`date +%Y_%m_%d_%H%M%S`
find . | cpio -oH newc 2>/dev/null | gzip > ../${initrd}_${datestamp}.gz 
cd ..
sync
rm -rf ${initrd}_decompressed
printf "Finished. 
File ${initrd}_${datestamp}.gz has been created.
"
exit 0
