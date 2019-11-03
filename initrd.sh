#!/bin/bash

#
# recover logic for handling and initrd or kernel problem
#

recover_suse() {
    mkinitrd /boot/initrd-$(ls /lib/modules | sort -V | tail -1) $(ls /lib/modules | sort -V | tail -1)
    grub2-mkconfig -o /boot/grub2/grub.cfg
}

recover_ubuntu() {
    update-initramfs -k $(ls /lib/modules | sort -V | tail -1) -c
    update-grub

}

#
# Should handle all redhat based distros
#
recover_redhat() {
    if [[ $isRedHat6 == "true" ]]; then
        cd $tmp_dir
        wget -q --no-cache https://raw.githubusercontent.com/malachma/azure-support-scripts/master/grub.awk
        awk -f grub.awk /boot/grub/grub.conf
    else
        mkinitrd --force /boot/initramfs-$(ls /lib/modules | sort -V | tail -1).img $(ls /lib/modules | sort -V | tail -1)
        grub2-mkconfig -o /boot/grub2/grub.cfg
    fi

}

if [[ $isRedHat == "true" ]]; then
    recover_redhat
fi

if [[ $isSuse == "true" ]]; then
    recover_suse
fi

if [[ $isUbuntu == "true" ]]; then
    recover_ubuntu
fi

exit 0
