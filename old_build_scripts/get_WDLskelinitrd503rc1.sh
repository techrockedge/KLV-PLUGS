#!/bin/sh
# Creation Date: 20Jun2020; Revision Date: 10mar2022
# Copyright wiak (William McEwan) 20Jun2020+; Licence MIT (aka X11 license)
progname="get_WDLskelinitrd.sh"; version="503"; revision="-rc1"
resource=${progname#get_}; resource=${resource%.sh}

case "$1" in
	'--help'|'-h'|'-?') printf "Simply execute this script with command:
./${progname}
to download $resource
to the current directory\n"; exit 0;;
	'--version') printf "$progname ${version}${revision}\n"; exit 0;;
esac

printf "\nPress Enter to download $resource\nor press Ctrl-C to abort download\n" 
read  # Stop here until the Enter key is pressed or Ctrl-C to abort
wget -c http://owncloud.rockedge.org/index.php/s/HRZhsnouSm3Gpf3/download -O modify_initrd_gz.sh && chmod +x modify_initrd_gz.sh
wget -c http://owncloud.rockedge.org/index.php/s/GuKX83bGLZpolvG/download -O initrd_v${version}${revision}.gz
wget -c http://owncloud.rockedge.org/index.php/s/2Wd1ZUZUS7hvl9o/download -O w_init_${version}${revision}.sh

exit 0
