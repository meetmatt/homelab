#!/bin/bash

. keystonerc_admin

# Create external network
openstack network create external_network --provider-network-type flat --provider-physical-network extnet --share --external

# Create public subnet
openstack subnet create --no-dhcp \
--allocation-pool=start=10.0.1.100,end=10.0.1.200 \
--gateway=10.0.0.1 \
--network external_network \
--subnet-range 10.0.0.0/16 \
public_subnet

# Create router
openstack router create router
# Set router gateway to external network
openstack router set --external-gateway external_network --enable-snat router
# Create private network
openstack network create private_network
# Create private subnet
openstack subnet create --network private_network --subnet-range 10.20.0.0/24 --dhcp private_subnet
# Attach private subnet to router
openstack router add subnet router private_subnet

# Import Cirros image
curl -L http://download.cirros-cloud.net/0.6.0/cirros-0.6.0-x86_64-disk.img | glance image-create --name='cirros 0.6.0' --visibility=public --container-format=bare --disk-format=qcow2

# Create project
# openstack project create --enable internal
# Create user
# openstack user create --project internal --password qweasd --email internal@cloud.golikov.lu --enable internal

# TODO: launch instance
# TODO: allocate floating IP
# TODO: assign floating IP
# TODO: test connectivity
