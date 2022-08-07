#!/bin/bash

VOL=${1:-OEMDRV}

mkisofs -o ../image.iso \
  -b isolinux/isolinux.bin \
  -joliet \
  -rock \
  -l -v -quiet \
  -c isolinux/boot.cat \
  -no-emul-boot \
  -boot-load-size 4 \
  -boot-info-table \
  -eltorito-platform efi \
  -eltorito-boot images/efiboot.img \
  -no-emul-boot \
  -graft-points \
  -volid $VOL \
  -jcharset utf-8 .
