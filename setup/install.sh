#!/bin/bash

curl https://api.magicbell.com/notifications \
  --request POST \
  --header 'accept: application/json' \
  --header 'content-type: application/json' \
  --header 'X-MAGICBELL-API-SECRET: vqG5Eb0pHIECX36nUWW0ea7jujn5GH1nXx5G1zJs' \
  --header 'X-MAGICBELL-API-KEY: 5bd4a218f16f459fe25ab455dc20c9ec10b5d134' \
  --data '{
    "notification": {
        "title": "Installation started",
        "content": "Openstack installation started",
        "category": "new_message",
        "recipients": [{
            "email": "iurii.golikov@gmail.com"
        }]
    }
  }'

dnf update -yq
dnf install -yq epel-release
dnf config-manager --enable crb
dnf update -yq
dnf install -yq centos-release-openstack-yoga
dnf install -yq lvm2 crudini screen htop btop wget
dnf install -yq openstack-packstack

# Allow SSH on all IPs
echo ListenAddress 0.0.0.0 >> /etc/ssh/sshd_config
service sshd restart

# Generate root ssh key and add to authorized_keys
mkdir -m 700 /root/.ssh
ssh-keygen -t rsa -q -f "/root/.ssh/id_rsa" -N ""
cat /root/.ssh/id_rsa.pub > /root/.ssh/authorized_keys
chmod 600 /root/.ssh/*

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

# Replace NetworkManager with legacy ifup-style network scripts
dnf update -yq
dnf install -yq network-scripts

systemctl disable NetworkManager
systemctl stop NetworkManager
systemctl enable network
systemctl start network

# Bug: adjust network interfaces BEFORE INSTALLATION, otherwise it will hang at neutron-openvswitch-agent not able to start
# with error: ERROR neutron.plugins.ml2.drivers.openvswitch.agent.ovs_neutron_agent [-] Tunneling can't be enabled with invalid local_ip '10.0.1.1'. IP couldn't be found on this host's interfaces.

# Enable enp5s0
tee /etc/sysconfig/network-scripts/ifcfg-enp5s0 >/dev/null << EOL
DEVICE=enp5s0
NAME=enp5s0
ONBOOT=yes
BOOTPROTO=static
PREFIX=16
IPADDR=10.0.1.1
GATEWAY=10.0.0.1
DNS1=10.0.0.1
DNS2=1.1.1.1
EOL

# Enable enp6s0 with WOL
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

# Bug: create swift user and assign ownership of /srv/node/device1; before installation
useradd -UM -s /bin/false -g 160 -u 160 swift
mkdir -p -m 755 /srv/node/device1
chown -R swift:swift /srv/node

# Install openstack via packstack

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

# Move enp5s0's IP to br-ex
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

service network restart

curl https://api.magicbell.com/notifications \
  --request POST \
  --header 'accept: application/json' \
  --header 'content-type: application/json' \
  --header 'X-MAGICBELL-API-SECRET: vqG5Eb0pHIECX36nUWW0ea7jujn5GH1nXx5G1zJs' \
  --header 'X-MAGICBELL-API-KEY: 5bd4a218f16f459fe25ab455dc20c9ec10b5d134' \
  --data '{
    "notification": {
        "title": "Installation finished",
        "content": "Openstack installation finished",
        "category": "new_message",
        "action_url": "http://10.0.1.1",
        "recipients": [{
            "email": "iurii.golikov@gmail.com"
        }]
    }
  }'

# TODO: fix packstack failing to provision itself at 10.0.1.1 after OVS moving the interface behind the br-ex
# The solution was to wait until it gets stuck at network host ssh puppet phase (can be seen in htop)
# then move the 10.0.1.1 to enp6s0 with network-scripts, wait for the puppet to finish and then move the IPs back
# Somehow it doesn't happen with simple packstack --allinone, but happens when overriding the answers...
# Probably it's a bug. May be I need to set the network host to 10.0.2.1, but afraid that the configs will get screwed up.

# TODO: Another issue is nova and swift daemons trying to bind to exact IP (10.0.1.1) instead of simply 0.0.0.0
# Manually changing it to bind 0.0.0.0 solves it, but not sustainable and almost impossible to automate cleanly...
