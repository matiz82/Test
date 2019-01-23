#!/bin/bash
# 1. Redhat Subscription Registration
#subscription-manager register --username=fin.plat.ops --password='!F1n3ng!'
#subscription-manager unregister
#subscription-manager attach --pool=8a85f9865d315d36015d3164e9cf1f03
# 1. Time and Date setting for hosts
timedatectl set-timezone Europe/Stockholm
echo "server 169.254.169.123 prefer iburst" >> /etc/ntp.conf
# 2. Installing Hana Specific packages
yum update --security -y
yum install lvm2* -y
yum -y install ntp ntpdate
yum install tcsh -y
yum install -y compat-sap-c++ xfsprogs uuidd nfs-utils cifs-utils
yum install compat-sap-c++-6 -y
service uuidd start
chkconfig uuidd on
# 3. Create volumes for HANA:
pvcreate /dev/xvdb
pvcreate /dev/xvdc
pvcreate /dev/xvdd
pvcreate /dev/xvde
# 4. Set the I/O Scheduling option for AWS
# echo “noop” > /sys/block/xvdb/queue/scheduler
# echo “noop” > /sys/block/xvdc/queue/scheduler
# echo “noop” > /sys/block/xvdd/queue/scheduler
# echo “noop” > /sys/block/xvde/queue/scheduler
# echo “noop” > /sys/block/xvdf/queue/scheduler
# 5. Create Volume Groups and Logical Volumes for HANA
vgcreate vg00 /dev/xvdb
vgcreate vg01 /dev/xvdc
vgcreate vg02 /dev/xvdd
vgcreate vg03 /dev/xvde
vgcreate vg04 /dev/xvdf
lvcreate -l 100%FREE -n hana_shared vg00
lvcreate -l 100%FREE -n hana_data vg01
lvcreate -l 100%FREE -n hana_log vg02
lvcreate -l 100%FREE -n usr_sap vg03
lvcreate -l 100%FREE -n backup vg04
# 4. Format the volumes in to xfs  file systems:
mkfs -t xfs -b size=4096 -d su=64k,sw=2 /dev/vg00/hana_shared
mkfs -t xfs -b size=4096 -d su=64k,sw=2 /dev/vg01/hana_data
mkfs -t xfs -b size=4096 -d su=64k,sw=2 /dev/vg02/hana_log
mkfs -t xfs -b size=4096 -d su=64k,sw=2 /dev/vg03/usr_sap
mkfs -t xfs -b size=4096 -d su=64k,sw=2 /dev/vg04/backup
# 5. Create directories and set permisson:
mkdir -p /sapmnt
mkdir -p /usr/sap
mkdir -p /usr/sap/data
# 6. Create symbolic link for compat c++.
mkdir -p /usr/sap/lib
ln -s /opt/rh/SAP/lib64/compat-sap-c++.so /usr/sap/lib/libstdc++.so.6
ln -s /usr/lib64/libssl.so.1.0.1e /usr/lib64/libssl.so.1.0.1
ln -s /usr/lib64/libcrypto.so.1.0.1e /usr/lib64/libcrypto.so.1.0.1
# 7. Create_mntpts - Mount the file systems:
mount /dev/vg00/usr_sap /usr/sap
mount /dev/vg01/usr_sap_data /usr/sap/data
mount /dev/vg02/sapmnt /sapmnt
# 8. Print_fstab - Print mounts in the fstab:
echo "/dev/vg00/usr_sap /usr/sap xfs defaults 1 3" >> /etc/fstab
echo "/dev/vg01/usr_sap_data /usr/sap/data xfs defaults 1 3" >> /etc/fstab
echo "/dev/vg02/sapmnt /sapmnt xfs defaults 1 3" >> /etc/fstab
mount -a
# 9. Create_usrgrp - Create user/group:
groupadd sapsys -g 79
useradd -u 550 -g 79 bapadm
chsh -s /bin/csh bapadm
# 10. Set hostname - Short "hostname" that requires for sap installations.
hostnamectl set-hostname --static sapafi-p-a1
echo "preserve_hostname: true" >> /etc/cloud/cloud.cfg
# 11. Disable SELinux for HANA system on RedHat
setenforce 0
# 12. SAP Specific Kernel Parameter settings
echo "kernel.sem=1250 256000 100 1024" >> /etc/sysctl.d/sap.conf
echo "vm.max_map_count=2000000" >> /etc/sysctl.d/sap.conf
sysctl --system

