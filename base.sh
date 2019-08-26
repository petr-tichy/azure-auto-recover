#!/bin/bash


# Variables
amount_of_partitions=0 
UBUNTU_DISTRO="true"
isRedHat="false"
isSuse="false"
isUbuntu="false"

actions="fstab initrd kernel" # These are the basic actions at the moment

# Functions START

recover_action() {
chroot /mnt/rescue-root/ <<< $(curl -s -H 'Cache-Control: no-cache' https://raw.githubusercontent.com/malachma/azure-support-scripts/master/$1)
}

isInAction() { 
    #be quiet, just let us know this action exists
    grep -q $1 <<< $actions
    return $?
}


# Funtions END

#
# What OS we need to recover?
#

# RedHat 6 does not have os-release
if [[ -e /etc/os-release ]]; then 
    PRETTY_NAME=$(grep PRETTY_NAME /etc/os-release)
    PRETTY_NAME=${PRETTY_NAME##*=}
else if [[ -e /etc/redhat-release ]]; then 
    PRETTY_NAME=$(cat /etc/redhat-release) 
    fi
fi

case ${PRETTY_NAME} in 
    *CentOS* | *Red\ Hat*) 
        echo "Ist CentOS"
        isRedHat="true"
        ;;
    *Ubuntu*)
        echo "Ist Ubuntu"
        isUbuntu="true"
        ;;
    *SUSE*)
        echo "Ist Suse"
        isSuse="true"
        ;;
esac




#get boot flaged partition
#-------------------------
#boot_part=$(fdisk -l /dev/sdc | awk '$2 ~ /\*/ {print $1}')
boot_part=$(fdisk -l $(readlink -f /dev/disk/azure/scsi1/* | grep -v -E "[0-9]+") | awk  '$2 ~ /\*/ {print $1}')

#get partitions of the data-disk (the OS-disk to be recovered)
#---------------------
#partitions=$(fdisk -l /dev/sdc | awk '/^\/dev\/sdc/ {print $1}')
partitions=$(readlink -f /dev/disk/azure/scsi1/* | grep -E "[0-9]+")

for i in $partitions; do 
    ((amount_of_partitions++));
done


if [[ $isRedHat == "true" ]]; then
    rescue_root=$(echo $partitions | sed "s|$boot_part||g")
else if [[ $isUbuntu == "true" ]]; then
    rescue_root=$boot_part
fi
fi

if [[ $(lsblk -fl | grep -E "^${rescue_root##*/}" | cut -d' ' -f2) == "ext4" ]]; then
    is_ext4="true"
fi

#is_ext4=$(lsblk -fl | awk '$1 ~/^sdc[0-9]/ && $2 == "ext4" {print "true"}')
#is_ext4=$(echo $is_ext4 | cut -d ' ' -f1)

#Mount the root part
#====================
mkdir /mnt/rescue-root
if [[ $isRedHat == "true" ]];
then
    # noouid is valid for XFS only
    if [[ $is_ext4 == "true" ]]; then
        mount -n $rescue_root /mnt/rescue-root
    else
        mount -n -o nouuid $rescue_root /mnt/rescue-root
    fi
fi

if [[ $isUbuntu == "true" ]]; then
    mount -n $rescue_root /mnt/rescue-root
fi

#Mount the boot part
#===================
if [[ $isRedHat == "true" ]]; then
    mount -o nouuid $boot_part /mnt/rescue-root/boot
fi



#Mount the support filesystems
#==============================
#see also http://linuxonazure.azurewebsites.net/linux-recovery-using-chroot-steps-to-recover-vms-that-are-not-accessible/

for i in dev proc sys dev/pts; do mount -o bind /$i /mnt/rescue-root/$i; done
if [[ $isUbuntu == "true" ]];
then
    mount -o bind /run /mnt/rescue-root/run
fi

# What action has to be performed now?
# INFO NOT FULLY IMPLEMENTED YET!!!
for k in $1; do 
if [[ $(isInAction $k) -eq 0 ]]; then
    case $k in 
        fstab) 
            echo "We have fstab as option"
            recover_action "fstab.sh"
            ;; 
        kernel)
            echo "We have kernel as option"
            ;;
        initrd)
            echo "We have initrd as option";
            ;; 
    esac
fi
done


#Clean up everything
cd /
for i in dev/pts proc sys dev; do umount  /mnt/rescue-root/$i; done

if [[ $isUbuntu == "true" ]];
then
    umount /mnt/rescue-root/run
fi
umount /mnt/rescue-root/boot
umount /mnt/rescue-root                                                                                                                                                                              
rm -fr /mnt/rescue-root







