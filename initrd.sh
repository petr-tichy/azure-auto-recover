

#
# recover logic for handling and initrd or kernel problem
#

recover_suse() {
    true
}

recover_ubuntu() {
     # update-initramfs: Generating /boot/initrd.img-4.15.0-1055-azure
     update-initramfs -k $(ls -t /lib/modules | head -1) -c
     update-grub

}

#
# Should handle all redhat based distros
#
recover_redhat() {
    if [[ $isRedHat6 == "true" ]]; then
        awk -f grub.awk 
    else
        mkinitrd --force /boot/initramfs-$(ls -t /lib/modules | head -1).img $(ls -t /lib/modules | head -1)
        grub2-mkconfig  -o /boot/grub2/grub.cfg
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