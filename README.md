# KLV-PLUGS

FirstRib-KLV build script PLUG files

The first two PLUG projects are the *KLV-Airedale* and *KLV-Spectr* build script .plug file that accompanies the FirstRib build system script that will construct the rootfs for an operating system *KLV-Airedale*.

example use of a .plug file:

./build_firstrib_rootfs_latest.sh void default amd64 f_00_Void_KLV_XFCE_kernel_FRteam-rc8.plug

PLUG **f_00_Void_KLV_XFCE_kernel_WDLteam-rc8.plug** builds the **rootfs** for a Void Linux based XFCE4 desktop operating system similar to *KLV-Airedale*.

To create a complete distro all of the other utilites, tools and configurations are downloaded from a central location and installed either as a .tar.gz or .xbps package. 

A wrapper script to assemble a distro could automate this process.