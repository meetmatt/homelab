#!/bin/bash

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
PREFIX=24
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
PREFIX=22
IPADDR=10.0.2.1
GATEWAY=10.0.0.1
DNS1=10.0.0.1
DNS2=1.1.1.1
ETHTOOL_OPTS="wol g"
EOL

service network restart

sleep 10

# Shutdown and test wake-on-lan and network
shutdown now
