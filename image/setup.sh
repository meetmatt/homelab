#!/bin/bash

dnf update -yq
dnf install -yq epel-release
dnf config-manager --enable crb
dnf update -yq
dnf install -yq wget

wget https://raw.githubusercontent.com/meetmatt/homelab/master/setup/install.sh -P /root
chmod +x /root/install.sh

HOME=/root /root/install.sh

# Prevent setup from restarting after boot
systemctl disable setup

reboot now
