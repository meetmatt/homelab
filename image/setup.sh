#!/bin/bash

dnf update -yq
dnf install -yq epel-release
dnf config-manager --enable crb
dnf update -yq
dnf install -yq wget

# Download installation script
wget -q https://raw.githubusercontent.com/meetmatt/homelab/master/setup/install.sh -P /root
chmod +x /root/install.sh

# Install openstack
machinectl shell root@.host /root/install.sh

# Prevent setup from restarting after boot
systemctl disable setup
