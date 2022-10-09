#!/bin/bash

dnf update -yq
dnf install -yq network-scripts

systemctl disable NetworkManager
systemctl stop NetworkManager
systemctl enable network
systemctl start network

# Generate answer file
packstack --allinone --gen-answer-file=/root/answers.txt

# Create override file
tee /root/override.txt >/dev/null << EOL
[general]
CONFIG_PROVISION_DEMO=n
CONFIG_CEILOMETER_INSTALL=n
CONFIG_LBAAS_INSTALL=y

CONFIG_DEFAULT_PASSWORD=qweasd
CONFIG_KEYSTONE_ADMIN_PW=qweasd

CONFIG_COMPUTE_HOSTS=10.0.2.1

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
packstack --answer-file=/root/answers.txt

# Download openstack setup script
wget https://raw.githubusercontent.com/meetmatt/homelab/master/setup/openstack.sh -P /root
chmod +x /root/openstack.sh

# TODO: fix packstack failing to provision itself at 10.0.1.1 after OVS moving the interface behind the br-ex
# The solution was to wait until it gets stuck at network host ssh puppet phase (can be seen in htop)
# then move the 10.0.1.1 to enp6s0 with network-scripts, wait for the puppet to finish and then move the IPs back
# Somehow it doesn't happen with simple packstack --allinone, but happens when overriding the answers...
# Probably it's a bug. May be I need to set the network host to 10.0.2.1, but afraid that the configs will get screwed up.

# TODO: Another issue is nova and swift daemons trying to bind to exact IP (10.0.1.1) instead of simply 0.0.0.0
# Manually changing it to bind 0.0.0.0 solves it, but not sustainable and almost impossible to automate cleanly...

# Adjust network interfaces
tee /etc/sysconfig/network-scripts/ifcfg-enp5s0 >/dev/null << EOL
DEVICE=enp5s0
NAME=enp5s0
DEVICETYPE=ovs
TYPE=OVSPort
OVS_BRIDGE=br-ex
ONBOOT=yes
BOOTPROTO=none
EOL

tee /etc/sysconfig/network-scripts/ifcfg-br-ex >/dev/null << EOL
DEVICE=br-ex
DEVICETYPE=ovs
NAME=br-ex
ONBOOT=yes
PEERDNS=no
NM_CONTROLLED=no
NOZEROCONF=yes
OVSBOOTPROTO=none
TYPE=OVSBridge
OVS_EXTRA="set bridge br-ex fail_mode=standalone"
BOOTPROTO=static
PREFIX=16
IPADDR=10.0.1.1
GATEWAY=10.0.0.1
DNS1=10.0.0.1
DNS2=1.1.1.1
EOL

tee /etc/sysconfig/network-scripts/ifcfg-enp6s0 >/dev/null << EOL
DEVICE=enp6s0
NAME=enp6s0
ONBOOT=yes
BOOTPROTO=static
PREFIX=16
IPADDR=10.0.2.1
GATEWAY=10.0.0.1
DNS1=10.0.0.1
DNS2=1.1.1.1
ETHTOOL_OPTS="wol g"
EOL

service network restart

shutdown now
