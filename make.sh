#!/bin/bash

ISODIR=${1:-iso}
LABEL=${2:-OEMDRV}

if [[ -z $3 ]]; then
  DISK=$(./disk.sh)
else
  DISK=${3}
fi

if [[ -z $DISK ]]; then
  echo 'Please reinsert USB flash'
  exit 1
fi

rm image.iso

cp ./image/grub.cfg      ${ISODIR}/EFI/BOOT/grub.cfg
cp ./image/ks.cfg        ${ISODIR}/ks.cfg
cp ./image/setup.service ${ISODIR}/isolinux/setup.service
cp ./image/setup.sh      ${ISODIR}/isolinux/setup.sh

cd ${ISODIR}

sudo true

../mkisofs.sh ${LABEL}

cd ..

sudo perl isohybrid.pl image.iso

sudo balena local flash image.iso --drive ${DISK} --yes
