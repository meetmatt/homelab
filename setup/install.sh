#!/bin/bash

dnf update -yq
dnf install -yq centos-release-openstack-yoga
dnf install -yq lvm2 crudini screen htop
dnf install -yq openstack-packstack

# Allow SSH on all IPs
echo ListenAddress 0.0.0.0 >> /etc/ssh/sshd_config
service sshd restart

# Passwordless sudo for user
echo 'user ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/user

# Kernel tweaks
echo fs.inotify.max_queued_events=1048576 >> /etc/sysctl.conf
echo fs.inotify.max_user_instances=1048576 >> /etc/sysctl.conf
echo fs.inotify.max_user_watches=1048576 >> /etc/sysctl.conf
echo vm.max_map_count=262144 >> /etc/sysctl.conf
echo vm.swappiness=1 >> /etc/sysctl.conf

# Delete LVM
lvremove -fy swift-volumes
vgremove -fy swift-volumes
vgremove -fy cinder-volumes

# Create 2 partitions /dev/sdc1 /dev/sdc2, 50/50
sfdisk /dev/sdc << EOL
/dev/sdc1 : start=        2048, size=  1887436800, type=lvm
/dev/sdc2 : start=  1887438848, size=  1887436800, type=lvm
EOL

# Create LVM for Cinder and Swift
vgcreate cinder-volumes /dev/sdc1
vgcreate swift-volumes /dev/sdc2
lvcreate -y -n swift-lvs -l 100%FREE swift-volumes
mkfs.ext4 /dev/swift-volumes/swift-lvs

# Download post install
wget https://raw.githubusercontent.com/meetmatt/homelab/master/setup/post-install.sh -P /root
chmod +x /root/post-install.sh

# Not running the post-install from systemd due to not being able to SSH to itself as root
# Searching for solutions didn't lead anywhere, so I'll probably have to embrace the manual ssh + post-install.sh :/

reboot now
