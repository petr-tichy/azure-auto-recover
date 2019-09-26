# The main intention is to roll back to the previous working kernel
# We do this by altering the grub configuration


# From the man page
# Set the default boot menu entry for GRUB.  This requires setting GRUB_DEFAULT=saved in /etc/default/grub
set_grub_default() {
    # if not set to saved, replace it
    chroot /mnt/rescue-root sed -i "s/GRUB_DEFAULT=[[:digit:]]/GRUB_DEFAULT=saved/" /etc/default/grub
}

# at first alter the grub configuration to set GRUB_DEFAULT=saved if needed
set_grub_default

# set the default kernel accordingly
# This is different for RedHat and Ubuntu/SUSE distros
# Ubuntu and SLES use sub-menues

# the variables are defined in base.sh
if [[ $isRedHat == "true" ]]; then
       chroot /mnt/rescue-root grub2-set-default 2 # This is the last previous kernel
       chroot /mnt/rescue-root grub-mkconfig -o /boot/grub2/grub.cfg
fi 

if [[ $isUbuntu == "true" ]]; then
        chroot /mnt/rescue-root grub-set-default "(1>2)"
        chroot /mnt/rescue-root update-grub
fi

if [[  $isSuse == "true" ]]; then
        chroot /mnt/rescue-root  grub2-set-default "(1>2)"
        chroot /mnt/rescue-root grub2-mkconfig -o /boot/grub2/grub.cfg
fi




# SIEHE AUCH HIER --> https://www.linuxsecrets.com/2815-grub2-submenu-change-boot-order


