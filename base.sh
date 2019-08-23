#!/bin/bash


# Variables
amount_of_partitions=0 
UBUNTU_DISTRO="true"
isRedHat="false"
isSuse="false"
isUbuntu="false"

actions="fstab initrd kernel" # These are the basic actions at the moment

# Functions START

recover_fstab() {
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
}

isInAction() { 
    #be quiet, just let us know this action exists
    grep -q $1 <<< $actions
    return $?
}

###########
#test_actions="initrd fstab bla kernel"
#mla@DE-MALACHMA03:~$ unset new_actions
#mla@DE-MALACHMA03:~$ for i in $test_actions; do
#> if isInAction $i; then
#> new_actions="$new_actions $i"
#> fi
#> done
#mla@DE-MALACHMA03:~$ echo $new_actions
#initrd fstab kernel
##########

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

# Determine what distro we have to recover
#if [[ $amount_of_partitions -gt 1 ]]; 
#then
    # This is a RedHat based OS-Disk
 #   UBUNTU_DISTRO="false"

#else
 #   # This is an Ubuntu/Debian based OS-Disk
    # only one partion exists
  #  rescue_root=$boot_part
   # UBUNTU_DISTRO="true"
#fi

if [[ $(lsblk -fl | grep -E "^${rescue_root##*/}" | cut -d' ' -f2) == "ext4" ]]; then
    is_ext4="true"
fi

#is_ext4=$(lsblk -fl | awk '$1 ~/^sdc[0-9]/ && $2 == "ext4" {print "true"}')
#is_ext4=$(echo $is_ext4 | cut -d ' ' -f1)

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

# What action has to be performed now?
# INFO NOT FULLY IMPLEMENTED YET!!!
for key in .... 
case $key in 
    fstab) 
        echo "fstab action";
     ;;
     initrd)
        echo "initrd action"; 
     ;; 
     kernel) 
        echo "kernel action"; 
     ;; 
esac

if [[ $1 == "fstab" ]]; then
    recover_fstab
else
    echo "No option. Performing default recovery"
fi

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







