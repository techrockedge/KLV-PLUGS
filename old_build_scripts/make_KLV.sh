#!/bin/sh
echo "start KLV-Airedale build....."
wget --continue https://rockedge.org/kernels/data/Kernels/64bit/5.16.14-KLV-no_AUFS/5.16.14-KLV/vmlinuz
wget --continue https://rockedge.org/kernels/data/Kernels/64bit/5.16.14-KLV-no_AUFS/5.16.14-KLV/01firmware-5.16.14-KLV.sfs
wget --continue https://rockedge.org/kernels/data/Kernels/64bit/5.16.14-KLV-no_AUFS/5.16.14-KLV/00modules-5.16.14-KLV.sfs
wget --continue https://rockedge.org/kernels/data/KLV-initrd/initrd.gz
wget --continue https://rockedge.org/kernels/data/KLV-initrd/w_init
wget --continue https://rockedge.org/kernels/data/KLV-initrd/10gtkdialogGTK3_filemnt64.sfs

mkdir 07dummy_rootfs

./build_firstrib_rootfs_401rc1.sh  void rolling amd64 f_00_Void_KLV_XFCE_no-kernel_WDLteam-RC5.plug
sleep 1
mv firstrib_rootfs upper_changes

echo "KLV-Airedale build finished......"
