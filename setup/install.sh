#!/bin/bash

dnf update -yq
dnf install -yq centos-release-openstack-yoga
dnf install -yq network-scripts lvm2 crudini screen htop
dnf install -yq openstack-packstack

# Allow SSH on all IPs
echo ListenAddress 0.0.0.0 >> /etc/ssh/sshd_config

# Passwordless sudo for user
echo 'user ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/user

# Kernel tweaks
echo fs.inotify.max_queued_events=1048576 >> /etc/sysctl.conf
echo fs.inotify.max_user_instances=1048576 >> /etc/sysctl.conf
echo fs.inotify.max_user_watches=1048576 >> /etc/sysctl.conf
echo vm.max_map_count=262144 >> /etc/sysctl.conf
echo vm.swappiness=1 >> /etc/sysctl.conf

# Delete LVM
wipefs -a /dev/swift-volumes/swift-lvs
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
lvcreate -n swift-lvs -l 100%FREE swift-volumes
mkfs.ext4 /dev/swift-volumes/swift-lvs

systemctl disable NetworkManager
systemctl stop NetworkManager
systemctl enable network
systemctl start network

# Generate answer file
HOME=/root packstack --allinone --gen-answer-file=/root/answers.txt

# Create override file
tee /root/override.txt >/dev/null << EOL
[general]
CONFIG_PROVISION_DEMO=n
CONFIG_CEILOMETER_INSTALL=n
CONFIG_LBAAS_INSTALL=y

CONFIG_DEFAULT_PASSWORD=qweasd
CONFIG_KEYSTONE_ADMIN_PW=qweasd

CONFIG_CONTROLLER_HOST=10.0.1.1
CONFIG_STORAGE_HOST=10.0.1.1
CONFIG_NETWORK_HOSTS=10.0.1.1
CONFIG_COMPUTE_HOSTS=10.0.1.1

# Storage
CONFIG_GLANCE_BACKEND=swift
CONFIG_SWIFT_STORAGES=/dev/swift-volumes/swift-lvs
CONFIG_CINDER_VOLUMES_CREATE=n

# Configure Neutron
CONFIG_NEUTRON_L2_AGENT=openvswitch
CONFIG_NEUTRON_ML2_MECHANISM_DRIVERS=openvswitch
CONFIG_NEUTRON_ML2_TYPE_DRIVERS=vxlan,flat
CONFIG_NEUTRON_ML2_TENANT_NETWORK_TYPES=vxlan
CONFIG_NEUTRON_OVS_BRIDGE_IFACES=br-ex:enp5s0
EOL

# Merge custom answers file with generated
crudini --merge /root/answers.txt < /root/override.txt

# Install openstack
HOME=/root packstack --answer-file=/root/answers.txt

# Download openstack setup script
wget https://raw.githubusercontent.com/meetmatt/homelab/master/setup/openstack.sh -P /root
chmod +x /root/openstack.sh

tee /etc/sysconfig/network-scripts/ifcfg-enp6s0 >/dev/null << EOL
DEVICE=enp6s0
NAME=enp6s0
ONBOOT=yes
BOOTPROTO=static
PREFIX=16
IPADDR=10.0.1.2
GATEWAY=10.0.0.1
DNS1=10.0.0.1
DNS2=1.1.1.1
ETHTOOL_OPTS="wol g"
EOL

service network restart

sleep 60

# Reboot to test network, hopefully remotely
reboot now
