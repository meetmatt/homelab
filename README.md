# Home Lab

Random scripts for home lab

## Hardware

* ZOTAC ZBOX
* Intel 10750H 2.6GHz, 6c/12t
* 32G DDR4
* 512G NVMe
* 2TB SSD
* RTX 2070 8G
* 2 NICs: 10.0.1.1/16, 10.0.2.1/16
* Home router 10.0.0.1/8
* Home DHCP 10.0.0.1/24

## Contents

1. USB ISO drive burner for MacOS.
2. CentOS.
3. Kickstart script.
4. Openstack setup script (via packstack).

## Setup

1. Download [CentOS iso](https://www.centos.org/download/) and untar under ./iso directory.
2. Insert USB stick and run ./make.sh.
3. Wait for it to finish burning, eject, insert into Zotac.
4. Start, F8, select to boot from EUFI USB.
5. Wait 15-30 minutes and check for machine to boot.
6. Run network.sh, test network, wake-on-lan, etc.
7. Run openstack.sh, test everything else.
8. Experiment and fix issues.
