# ARTIK Fedora ARTIK Build System
## Contents
1. [Introduction](#1-introduction)
2. [Environment Setup](#2-environment-setup)
3. [Preparation to build](#3-preparation-to-build)
4. [Build](#4-build)

## 1. Introduction
This repository helps to create an ARTIK fedora package through
arm chroot environment. You can build or install a program without
ARM native machine. It uses qemu-arm-static user emulation and binfmt
technology.

---
## 2. Environment Setup
### Host Linux PC
Ubuntu 64bit 14.04 or higher version
### Download fed-artik-tools package from release
Go to release tab and download the latest release package
### Package installation from prebuilt binary
```
sudo apt-get install build-essential qemu-user-static createrepo libguestfs-tools git sudo
sudo dpkg -i fed-artik-tools_1.2.15_amd64.deb
```
### Build fed-artik-tools(Optional)
```
sudo apt-get install devscripts debhelper
cd fed-artik-tools
debuild -us -uc
cd ..
sudo apt-get install build-essential qemu-user-static createrepo libguestfs-tools git sudo
sudo dpkg -i fed-artik-tools_1.2.15_amd64.deb
```

---
## 3. Preparation to build
### Initialize host environment
+ Run fed-artik-host-init-buildsys with fedora arm tarball(ex: fedora-arm-artik5-rootfs-0520GC0F-3AF-01Q6-20160928.203457-0e632fcf9ee1badf5724751af6bd0670.tar.gz)
https://github.com/SamsungARTIK/fedora-spin-kickstarts/releases
```
fed-artik-host-init-buildsys -I fedora-arm-artik5-rootfs-0520GC0F-3AF-01Q6-20160928.203457-0e632fcf9ee1badf5724751af6bd0670.tar.gz

Host setting is done
BUILDROOT -> /home/cometzero/FED_ARTIK_ROOT
SCRATCH_ROOT -> /home/cometzero/FED_ARTIK_ROOT/BUILDROOT
Local Repo -> /home/cometzero/FED_ARTIK_ROOT/repos/f24/armv7hl/RPMS
```
+ You can find the setting from ~/.fed-artik-build.conf
If you want to change the configurations, you should re-create environment through fed-artik-host-init-buildsys with -C option
The default configurations are below:
```
BUILDROOT=~/FED_ARTIK_ROOT
BUILDARCH=armv7hl
FEDORA_VER=24
USE_DISTCC=0
USE_OFFICIAL_REPO=0
```
### Initialize chroot environment
+ This command will initialize fedora arm chroot environment(~/FED_ARTIK_ROOT/BUILDROOT) before build.
+ This command will require long time to synchronize rpmdb. You may wait about 5 minutes.
```
$ fed-artik-init-buildsys
### You may need to wait long time(>5 minutes) to synchronize rpmdb
Disable sslverify option of fedora
cachedir: /var/cache/dnf
DNF version: 1.1.6
RPM Fusion for Fedora 24 - Free - Updates 6.4 MB/s | 166 kB 00:00
not found deltainfo for: RPM Fusion for Fedora 24 - Free - Updates
not found updateinfo for: RPM Fusion for Fedora 24 - Free - Updates
Fedora 24 - armhfp 16 MB/s | 37 MB 00:02
not found deltainfo for: Fedora 24 - armhfp
not found updateinfo for: Fedora 24 - armhfp
.... < Snip >...
Complete!
group persistor: saving.
### fedora artik build system has been created
```
+ Now, you can build a source code with rpmbuild and spec file

--
## 4. Build
### Build an rpm source package
+ First of all, fed-artik-build will generate a rpm file from source and spec file. You should write a spec file and put into ./packaging/ directory. The build is quite slow because it emulates arm environment.
+ If you want to write your own spec file, please refer a guide from fedora
https://fedoraproject.org/wiki/How_to_create_an_RPM_package
+ The fed-artik-build identifies below directory structure as its git repository.
<pre>
| GIT root / sources
├── packaging
│   └── libdrm.spec
</pre>
The tool will archive the git source files as source tarball which will be identified by rpmbuild.
It will copy the tarball and the spec file inside the chroot environment.
+ Run the fed-artik-build in your git source directory. Below command will not include uncommitted changes.
```
$ fed-artik-build
[sudo] password for cometzero: Disable sslverify option of fedora
Spawning worker 0 with 2 pkgs
Spawning worker 1 with 2 pkgs
Spawning worker 2 with 2 pkgs
Spawning worker 3 with 2 pkgs
Spawning worker 4 with 2 pkgs
Spawning worker 5 with 2 pkgs
Spawning worker 6 with 2 pkgs
Spawning worker 7 with 2 pkgs
Workers Finished
Saving Primary metadata
Saving file lists metadata
Saving other metadata
Generating sqlite DBs
Sqlite DBs complete
Fedora-Local 1.8 MB/s | 7.6 kB 00:00
Metadata cache created.
umask 022
cd /root/rpmbuild/BUILD
cd nx-renderer-0.0.1
/usr/bin/rm -rf /root/rpmbuild/BUILDROOT/nx-renderer-0.0.1-0.arm
exit 0
Build is done. Please find your rpm from /home/cometzero/FED_ARTIK_ROOT/repos/f24/armv7hl/RPMS
```
You can find your rpm from your directory(~/FED_ARTIK_ROOT/repos/f24/armv7hl/RPMS)
+ If you want to include uncommitted changes on your git stash, please run with --include-all option
```
$ fed-artik-build --include-all
```

### Jump to chroot environment
+ If you want to enter chroot, please use the "fed-artik-chroot" command
```
$ fed-artik-chroot
[sudo] password for cometzero:
Disable sslverify option of fedora
[root@cometzero-ubuntu /]#
```

### Generate a fedora rootfs(Optional)
+ This is only for a person who want to make own fedora rootfs. It takes long time(>=10 minutes) to make it.
+ You will need spin-kickstarts source codes and prebuilt rpm files of artik specific packages.
```
usage: fed-artik-creator [options] kickstart

-h              Print this help message
-B BUILDROOT	BUILDROOT directory, if not specified read from ~/.fed-artik-build.conf
-C conf		Build configurations(If not specified, use default .fed-artik-build.conf
-o OUTPUT_DIR	Output directory
-H [hosts]	Hosts file to bind /etc/hosts
--output-file	Output file name
--copy-dir	Copy directory under kickstart file
--copy-rpm-dir	Copy all rpms from the directory
--copy-kickstart-dir	Copy whole kickstart directory
--ks-file KS	Kickstart file
--no-proxy list	No proxy
```
To build a fedora rootfs, please refer the build_fedora.sh of the build-artik.
```
mkdir output
fed-artik-creator -o ./output --copy-kickstart-dir ./spin-kickstarts --ks-file ./spin-kickstarts/fedora-arm-artik710.ks
```
