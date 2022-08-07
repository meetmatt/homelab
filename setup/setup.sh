#!/bin/bash

# Prevent setup from restarting after boot
systemctl disable setup

dnf update -y
dnf install -y epel-release
dnf config-manager --enable crb
dnf update -y
dnf install -y centos-release-openstack-yoga
dnf install -y network-scripts lvm2 crudini screen htop
dnf install -y openstack-packstack

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

### TODO: for some reason immediately after installation network cannot be reconfigured right away
### Reboot and reconfigure network manually

reboot now
