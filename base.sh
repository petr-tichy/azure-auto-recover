#!/bin/bash


# Variables
amount_of_partitions=0 
UBUNTU_DISTRO="true"
export isRedHat="false"
export isRedHat6="false"
export isSuse="false"
export isUbuntu="false"
tmp_dir=""
recover_action=""

actions="fstab initrd kernel" # These are the basic actions at the moment



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
    wget -q --no-cache -O $recover_action   https://raw.githubusercontent.com/malachma/azure-support-scripts/master/${recover_action}.sh
    if [[ -f $tmp_dir/$recover_action  ]]; then
        chmod 700 $tmp_dir/$recover_action
        chroot /mnt/rescue-root/ $tmp_dir/$recover_action
    else
        logger -s "File ${recover_action}.sh could not be fetched. Exiting"
        exit 1
    fi

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




#get boot flaged partition
#-------------------------
#boot_part=$(fdisk -l /dev/sdc | awk '$2 ~ /\*/ {print $1}')
boot_part=$(fdisk -l $(readlink -f /dev/disk/azure/scsi1/lun0 | grep -v -E "[0-9]+") | awk  '$2 ~ /\*/ {print $1}')

#get partitions of the data-disk (the OS-disk to be recovered)
#---------------------
#partitions=$(fdisk -l /dev/sdc | awk '/^\/dev\/sdc/ {print $1}')
partitions=$(ls $(readlink -f /dev/disk/azure/scsi1/lun0)* | grep -E "[0-9]+")

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
if [[ $isRedHat == "true" ]]; then
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
    # noouid is valid for XFS only
    if [[ $is_ext4 == "true" ]]; then
        mount $boot_part /mnt/rescue-root/boot
    else
        mount -o nouuid $boot_part /mnt/rescue-root/boot
    fi
fi



#Mount the support filesystems
#==============================
#see also http://linuxonazure.azurewebsites.net/linux-recovery-using-chroot-steps-to-recover-vms-that-are-not-accessible/

for i in dev proc sys tmp dev/pts; do mount -o bind /$i /mnt/rescue-root/$i; done
if [[ $isUbuntu == "true" ]];
then
    mount -o bind /run /mnt/rescue-root/run
fi

# What action has to be performed now?
for k in $1; do 
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
            echo "We have initrd as option";
            recover_action $k
            ;; 
    esac
fi
done


#Clean up everything
cd /
for i in dev/pts proc tmp sys dev; do umount  /mnt/rescue-root/$i; done

if [[ $isUbuntu == "true" ]];
then
    umount /mnt/rescue-root/run
fi
umount /mnt/rescue-root/boot #may throw an erro on Ubuntu, but can be ignored
umount /mnt/rescue-root                                                                                                                                                                              
rm -fr /mnt/rescue-root
rm -fr $tmp_dir/$FSTAB







