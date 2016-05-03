# ARTIK Fedora Chroot Environment
## Contents
1. [Introduction](#1-introduction)
2. [Environment Setup](#2-environment-setup)
3. [Chroot](#3-chroot)
4. [Known issues](#4-known-issues)
5. [Appendix](#5-appendix)

## 1. Introduction
This repository helps to create an ARTIK fedora arm chroot environment.
You can build or install a program without ARM native machine. It uses
qemu-arm-static user emulation and binfmt technology.

---
## 2. Environment Setup
### Host Linux PC
Ubuntu 64bit 14.04 or higher version
### Package installation
sudo apt-get install build-essential qemu-user-static libguest-tools xz
### Directory setup
+ I assume you work this setup in the /opt/fedora directory
```
mkdir /opt/fedora
sudo chown -R {YOUR_ID}:{YOUR_GROUP} /opt/fedora
```
+ Move the helper scripts(extract_fedora.sh, chroot_fedora.sh) into /opt/fedora/
```
cp *.sh /opt/fedora/
cd /opt/fedora
```
### Prepare a fedora arm root file system
+ You can retrieve the rootfs from artik10_sdfuse.img and put it into /opt/fedora directory
+ Create a destination directory for qemu chroot
```
mkdir /opt/fedora/fedora_root
```
+ Extract the rootfs using extract_fedora.sh
```
sudo ./extract_fedora.sh artik10_sdfuse.img ./fedora_root
```
+ Environment setup for chroot
sudo visudo (or you can edit /etc/sudoers using your editor)
```
Defaults        always_set_home
Defaults        env_keep += "http_proxy"
Defaults        env_keep += "https_proxy"
Defaults        env_keep += "no_proxy"
```

---
## 3. Chroot
### Chroot setup
arm binary can be emulated through qemu-arm-static and binfmt hook.
Copy the attached "prebuilt/qemu-arm-static" file into "fedora_root/usr/bin/qemu-arm-static"
```
sudo cp prebuilt/qemu-arm-static fedora_root/usr/bin/qemu-arm-static
```
+ If you want to build the qemu-arm-static, please refer appendix

### Chroot into fedora_root
```
sudo ./chroot_fedora.sh ./fedora_root
Disable sslverify option of fedora
cometzero@cometzero-ubuntu:/$
```
The shell is able to log in by your Host's account and /home/{YOUR_ID} will be automatically connected to your chroot directory.
You can also bind your directory inside of chroot

### To exit from chroot
```
cometzero@cometzero-ubuntu:/$ exit
exit
```

### To add bind directories between Host PC and chroot
+ Edit chroot_fedora.sh using editor
Edit BIND_MOUNTS like below:
```
BIND_MOUNTS=(
"/opt/test"
"/data/test"
)
```
+ The directories will be automatically mounted inside chroot

### Set up sudo environment
To use "sudo" command, you'll need to install "sudo" package and configure your account.
+ Enter fedora chroot using chroot_fedora.sh and change root account
```
cometzero@cometzero-ubuntu:/$ su
Password:  <- “root”
qemu: Unsupported syscall: 311
[root@cometzero-ubuntu /]#
```
+ Install sudo package(If your network does not allow https, please refer known issue.)
```
dnf install sudo
```
+ Run visudo and add your account and environment settings
```
visudo
Defaults        always_set_home
Defaults        env_keep += "http_proxy"
Defaults        env_keep += "https_proxy"
Defaults        env_keep += "no_proxy"
YOUR_ID         ALL=(ALL)       NOPASSWD:       ALL
```
Now, your account can use "sudo" command like below:
```
sudo dnf install vim
```

---
## 4. Known issues
### git clone is hang inside chroot
+ Do not clone the repository inside chroot environment
+ Please download the source in Host environment
### qemu: Unsupported syscall: 311
+ Please ignore this message
### If your network setting doesn?t allow https connection, you have to change repository from https to http
+ Run below command inside chroot
```
sed -i 's/metalink/#metalink/g' /etc/yum.repos.d/fedora*
sed -i 's/mirrorlist/#mirrorlist/g' /etc/yum.repos.d/rpmfusion*
sed -i 's/#baseurl/baseurl/g' /etc/yum.repos.d/*
```
### 'dnf install' was stopped or hang
+ Please wait 2 or 3 minutes to update rpmdb.
```
dnf install sudo
RPM Fusion for Fedora 22 - Free - Updates                       258 kB/s | 166 kB     00:00
Fedora 22 - armhfp                                               15 MB/s |  37 MB     00:02
Fedora 22 - armhfp - Updates                                    7.7 MB/s |  20 MB     00:02
```
---
## 5. Appendix
### 5.1 Set up distcc to accelerate build
#### Host Machine
+ Download linaro cross compiler
```
wget https://releases.linaro.org/components/toolchain/binaries/latest-5/arm-linux-gnueabihf/gcc-linaro-5.3-2016.02-x86_64_arm-linux-gnueabihf.tar.xz
tar xf gcc-linaro*.tar.xz
sudo mv gcc-linaro-* /usr/local
sudo ln -sf /usr/local/gcc-linaro-* /usr/local/gcc
```
+ Install distcc
```
sudo apt-get install distcc
sudo mkdir -p /usr/local/lib/distcc
cd /usr/local/lib/distcc
sudo ln -sf /usr/local/gcc-linaro-arm/bin/arm-linux-gnueabihf-gcc gcc
sudo ln -sf /usr/local/gcc-linaro-arm/bin/arm-linux-gnueabihf-gcc g++
sudo ln -sf /usr/local/gcc-linaro-arm/bin/arm-linux-gnueabihf-gcc cc
sudo ln -sf /usr/local/gcc-linaro-arm/bin/arm-linux-gnueabihf-gcc c++
```
+ Setting /etc/default/distcc(Change below setting and add PATH for distcc)
```
sudo vi /etc/default/distcc
STARTDISTCC="true"
JOBS="10"
ZEROCONF="true"
PATH=/usr/local/lib/distcc:$PATH
```
+ Restart distcc service
```
sudo service distcc restart
```

#### Fedora arm chroot
+ Install distcc and create symbolic links
```
sudo dnf install distcc
cd /usr/local/bin
sudo ln -sf /usr/bin/distcc gcc
sudo ln -sf /usr/bin/distcc g++
sudo ln -sf /usr/bin/distcc cc
sudo ln -sf /usr/bin/distcc c++
sudo ln -sf /usr/bin/distcc cpp
```
+ Set up distcc host IP
```
sudo vi /etc/distcc/hosts
127.0.0.1
```

### 5.2 Build qemu-static-arm
+ Download qemu source and build
```
git clone http://git.qemu.org/git/qemu.git
mkdir qemu.install
cd qemu
./configure --static --disable-system --target-list=arm-linux-user --prefix=`pwd`/../qemu.install --disable-libssh2
make -j8
make install
```
+ Copy the qemu-arm file into fedora_root
```
sudo cp qemu.install/bin/qemu-arm fedora_root/usr/bin/qemu-arm-static
sudo chmod 755 fedora_root/usr/bin/qemu-arm-static
```
