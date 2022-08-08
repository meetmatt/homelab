#!/bin/bash

# Prevent setup from restarting after boot
systemctl disable setup

dnf update -y
dnf install -y epel-release
dnf config-manager --enable crb
dnf update -y

dnf install -y wget

wget https://raw.githubusercontent.com/meetmatt/homelab/master/setup/install.sh -P /root
chmod +x /root/install.sh

HOME=/root /root/install.sh > /root/install.log 2>&1 &
