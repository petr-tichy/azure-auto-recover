#!/bin/bash

#
# recover logic for handling and initrd or kernel problem
#

recover_suse() {
    kernel_version="$(ls -t /lib/modules | head -n 1)"
    mkinitrd /boot/initrd-"${kernel_version}" "$kernel_version"
    grub2-mkconfig -o /boot/grub2/grub.cfg
}

recover_ubuntu() {
    kernel_version="$(ls -t /lib/modules | head -n 1)"
    update-initramfs -k "$kernel_version" -c
    update-grub

}

#
# Should handle all redhat based distros
#
recover_redhat() {
    kernel_version="$(ls -t /lib/modules | head -n 1)"
    if [[ "$isRedHat6" == "true" ]]; then
        # verify the grub.conf and correct it if needed
        cd "$tmp_dir"
        wget -q --no-cache https://raw.githubusercontent.com/malachma/azure-support-scripts/master/grub.awk
        awk -f grub.awk /boot/grub/grub.conf
        # rebuild the initrd
        dracut -f /boot/initramfs-"${kernel_version}".img "$kernel_version"
    else
        depmod ${kernel_version}
        mkinitrd --force /boot/initramfs-"${kernel_version}".img "$kernel_version"
        grub2-mkconfig -o /boot/grub2/grub.cfg
    fi

}

if [[ "$isRedHat" == "true" ]]; then
    recover_redhat
fi

if [[ "$isSuse" == "true" ]]; then
    recover_suse
fi

if [[ "$isUbuntu" == "true" ]]; then
    recover_ubuntu
fi
