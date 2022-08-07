#!/bin/bash

. keystonerc_admin

# Create external network
openstack network create external_network --provider:network_type flat --provider:physical_network extnet --router:external

# Create public subnet
openstack subnet create --name public_subnet --enable_dhcp=False --allocation-pool=start=10.0.1.100,end=10.0.1.200 --gateway=10.0.0.1 external_network 10.0.0.1/16

# Create router
openstack router create router
# Set router gateway to external network
openstack router set --external-gateway external_network router
# Create private network
openstack network create private_network
# Create private subnet
openstack subnet create --network private_network --subnet-range 192.168.0.1/24 --dhcp private_subnet
# Attach private subnet to router
openstack router add subnet router private_subnet

# Assign ownership of /srv/node/device1 to swift user
chown swift:swift /srv/node/device1

# Import Cirros image
curl -L http://download.cirros-cloud.net/0.5.2/cirros-0.5.2-x86_64-disk.img | glance image-create --name='cirros 0.5.2' --visibility=public --container-format=bare --disk-format=qcow2

# Create project
# openstack project create --enable internal
# Create user
# openstack user create --project internal --password qweasd --email internal@cloud.golikov.lu --enable internal

# TODO: launch instance
# TODO: allocate floating IP
# TODO: assign floating IP
# TODO: test connectivity
