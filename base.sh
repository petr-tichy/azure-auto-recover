#!/bin/bash

# Variables
export amount_of_partition=0
export UBUNTU_DISTRO="true"
export isRedHat="false"
export isRedHat6="false"
export isSuse="false"
export isUbuntu="false"
export tmp_dir=""
export recover_action=""
export boot_part=""
export rescue_root=""
export isExt4="false"
export isExt3="false"

export actions="fstab initrd kernel" # These are the basic actions at the moment

# Functions START

# Create tmp dir in order to store our files we download
tmp_dir=$(mktemp -d)

recover_action() {
    cd $tmp_dir
    case $1 in
    fstab)
        recover_action=$1
        ;;
    kernel)
        recover_action=$1
        ;;
    initrd)
        recover_action=$1
        ;;
    esac
    wget -q --no-cache -O $recover_action https://raw.githubusercontent.com/malachma/azure-auto-recover/master/${recover_action}.sh
    if [[ -f $tmp_dir/$recover_action ]]; then
        chmod 700 $tmp_dir/$recover_action
        chroot /mnt/rescue-root $tmp_dir/$recover_action
    else
        logger -s "File ${recover_action}.sh could not be fetched. Exiting"
        exit 1
    fi

}

isInAction() {
    #be quiet, just let us know this action exists
    grep -q $1 <<<$actions
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
else
    if [[ -e /etc/redhat-release ]]; then
        PRETTY_NAME=$(cat /etc/redhat-release)
        isRedHat6="true"
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

#
# Identify the corret boot and root partitions
#
if [[ $isSuse == "true" ]]; then
    suse_version=$(grep VERSION_ID /etc/os-release)
    suse_version=$(tr -d \" <<<${suse_version##*=})
    if [[ $suse_version == "12.4" ]]; then
        # This works well for SLES 12sp4 but not for SP3 THIS IS A BUG!!!! couldbe also a problem of the GPT which is not supported got managed OS disks
        boot_part=/dev/disk/azure/scsi1/lun0-part$(parted $(readlink -f /dev/disk/azure/scsi1/lun0) print | grep p.lxboot | cut -d ' ' -f2)
        rescue_root=/dev/disk/azure/scsi1/lun0-part$(parted $(readlink -f /dev/disk/azure/scsi1/lun0) print | grep p.lxroot | cut -d ' ' -f2)
    else
        #boot_part=/dev/disk/azure/scsi1/lun0-part$(parted $(readlink -f /dev/disk/azure/scsi1/lun0) print | awk '/boot/ {print $1}')
        #partitions=$(ls /dev/disk/azure/scsi1/* | grep -E "part[0-9]$")
        #rescue_root=$(echo $partitions | sed "s|$boot_part ||g")
        boot_part=/dev/disk/azure/scsi1/lun0-part$(lsblk -lf $(readlink -f /dev/disk/azure/scsi1/lun0) | grep -i boot | cut -b4)
        rescue_root=/dev/disk/azure/scsi1/lun0-part$(lsblk -lf $(readlink -f /dev/disk/azure/scsi1/lun0) | grep -i root | cut -b4)
    fi
fi

if [[ $isRedHat == "true" ]]; then
    # parted can not be used on RedHat 7.x there is a problemn that even a read opeartion causes the devices not ot exist anymore
    #boot_part=/dev/disk/azure/scsi1/lun0-part$(parted $(readlink -f /dev/disk/azure/scsi1/lun0) print | grep boot | cut -d ' ' -f2)

    boot_part=$(fdisk -l $(readlink -f /dev/disk/azure/scsi1/lun0) | awk '/^\/dev.*\*/ {print $1}')
    partitions=$(ls $(readlink -f /dev/disk/azure/scsi1/*) | grep -e "[0-9]$")
    rescue_root=$(echo $partitions | sed "s|$boot_part ||g")
fi

if [[ $isUbuntu == "true" ]]; then
    rescue_root=$(fdisk -l $(readlink -f /dev/disk/azure/scsi1/lun0) | awk '/^\/dev\/sd.1 / {print $1}')
fi

if [[ $(lsblk -fn $rescue_root | cut -d' ' -f2) == "ext4" ]]; then
    isExt4="true"
fi

if [[ $(lsblk -fn $rescue_root | cut -d' ' -f2) == "ext3" ]]; then
    isExt3="true"
fi

#Mount the root part
#====================
mkdir /mnt/rescue-root
if [[ $isRedHat == "true" || $isSuse == "true" ]]; then
    # noouid is valid for XFS only
    if [[ $isExt4 == "true" ]]; then
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
if [[ ! -d /mnt/rescue-root/boot ]]; then
    mkdir /mnt/rescue-root/boot
fi

if [[ $isRedHat == "true" || $isSuse == "true" ]]; then
    # noouid is valid for XFS only
    if [[ $isExt4 == "true" || $isExt3 == "true" ]]; then
        mount $boot_part /mnt/rescue-root/boot
    else
        mount -o nouuid $boot_part /mnt/rescue-root/boot
    fi
fi

# Mount the EFI part if Suse
if [[ $isSuse == "true" ]]; then
    efi_part=/dev/disk/azure/scsi1/lun0-part$(lsblk -lf $(readlink -f /dev/disk/azure/scsi1/lun0) | grep -i EFI | cut -b4)
    mount $efi_part /mnt/rescue-root/boot/efi
fi
#Mount the support filesystems
#==============================
#see also http://linuxonazure.azurewebsites.net/linux-recovery-using-chroot-steps-to-recover-vms-that-are-not-accessible/
for i in dev proc sys tmp dev/pts; do
    if [[ ! -d /mnt/rescue-root/$i ]]; then
        mkdir /mnt/rescue-root/$i
    fi
    mount -o bind /$i /mnt/rescue-root/$i
done

if [[ $isUbuntu == "true" || $isSuse == "true" ]]; then
    if [[ ! -d /mnt/rescue-root/run ]]; then
        mkdir /mnt/rescue-root/run
    fi
    mount -o bind /run /mnt/rescue-root/run
fi


# Reformat the action value
action_value=$(echo $1 | tr ',' ' ')
# What action has to be performed now?
for k in $action_value; do
    if [[ $(isInAction $k) -eq 0 ]]; then
        case ${k,,} in
        fstab)
            echo "We have fstab as option"
            recover_action $k
            ;;
        kernel)
            echo "We have kernel as option"
            recover_action $k
            ;;
        initrd)
            echo "We have initrd as option"
            recover_action $k
            ;;
        esac
    fi
done

# why do we have this in this file???
#if [[ $isSuse == "true" ]]; then
#        #grub2-set-default "1>2"
#        grub2-mkconfig -o /boot/grub2/grub.cfg
#fi

#Clean up everything
cd /
for i in dev/pts proc tmp sys dev; do umount /mnt/rescue-root/$i; done

if [[ $isUbuntu == "true" || $isSuse == "true" ]]; then
    #is this really needed for Suse?
    umount /mnt/rescue-root/run
    if [[ -d /mnt/rescue-root/boot/efi ]]; then
        umount /mnt/rescue-root/boot/efi
    fi
fi

if [[ $isUbuntu == "false" ]]; then
    umount /mnt/rescue-root/boot #may throw an erro on Ubuntu, but can be ignored
fi

umount /mnt/rescue-root
rm -fr /mnt/rescue-root
rm -fr $tmp_dir/$FSTAB
