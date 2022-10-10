#!/bin/bash

dnf update -y
dnf install -y systemd-container

# Download installation script
curl -s https://raw.githubusercontent.com/meetmatt/homelab/master/setup/install.sh -O /root/install.sh
chmod +x /root/install.sh

# Install openstack
machinectl shell root@.host /root/install.sh

# Prevent setup from restarting after boot
systemctl disable setup
