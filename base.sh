#!/bin/bash


# Variables
amount_of_partitions=0 
UBUNTU_DISTRO="true"

#get boot flaged partition
#-------------------------
boot_part=$(fdisk -l /dev/sdc | awk '$2 ~ /\*/ {print $1}')

#get partitions of sdc
#---------------------
partitions=$(fdisk -l /dev/sdc | awk '/^\/dev\/sdc/ {print $1}')

for i in $partitions; do 
    ((amount_of_partitions++));
done

# Determine what distro we have to recover
if [[ $amount_of_partitions -gt 1 ]]; 
then
    # This is a RedHat baased OS-Disk
    rescue_root=$(echo $partitions | sed "s|$boot_part||g")
    UBUNTU_DISTRO="false"

else
    # This is an Ubuntu/Debian based OS-Disk
    # only one partion exists
    rescue_root=$boot_part
    UBUNTU_DISTRO="true"
fi

is_ext4=$(lsblk -fl | awk '$1 ~/^sdc[0-9]/ && $2 == "ext4" {print "true"}')
is_ext4=$(echo $is_ext4 | cut -d ' ' -f1)

#Mount the root part
#====================
mkdir /mnt/rescue-root
if [[ $UBUNTU_DISTRO == "false" ]];
then
    # noouid is valid for XFS only
    if [[ $is_ext4 ]]; then
        mount $rescue_root /mnt/rescue-root
    fi
    mount -o nouuid $rescue_root /mnt/rescue-root
else
    mount $rescue_root /mnt/rescue-root
fi

#Mount the boot part
#===================
if [[ $UBUNTU_DISTRO == "false" ]];
then
    mount -o nouuid $boot_part /mnt/rescue-root/boot
fi



#Mount the support filesystems
#==============================
#see also http://linuxonazure.azurewebsites.net/linux-recovery-using-chroot-steps-to-recover-vms-that-are-not-accessible/

for i in dev proc sys dev/pts; do mount -o bind /$i /mnt/rescue-root/$i; done
if [[ $UBUNTU_DISTRO == "true" ]];
then
    mount -o bind /run /mnt/rescue-root/run
fi

# Here comes the core logic to get a basic fstab only

#chroot /mnt/rescue-root << EOF
#mv -f /etc/fstab{,.copy}
#cat /etc/fstab.copy | awk '/\/ /{print}' >> /etc/fstab
#cat /etc/fstab.copy | awk '/\/boot /{print}' >> /etc/fstab
#cat /etc/fstab
#exit
#EOF

#in order tu use the remote script one has to use a here string and pass it over to bash.
#eval can not be used in this case
#The cache control header is necessary tobe sure we always get the latest version
chroot /mnt/rescue-root/ <<< $(curl -s -H 'Cache-Control: no-cache' https://raw.githubusercontent.com/malachma/azure-support-scripts/master/fstab2.sh)

#Clean up everything
cd /
for i in dev/pts proc sys dev; do umount  /mnt/rescue-root/$i; done

if [[ $UBUNTU_DISTRO == "true" ]];
then
    umount /mnt/rescue-root/run
fi
umount /mnt/rescue-root/boot
umount /mnt/rescue-root                                                                                                                                                                              
rm -fr /mnt/rescue-root







