#!/bin/bash

# Variables
#export UBUNTU_DISTRO="true"
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
export isXFS="false"
export isLVM="false"
export efi_part=""
export osNotSupported="true" # set to true by default, gets changed to false if this is the case
export tmp_dir=""
export global_error="false"

export actions="fstab initrd kernel" # These are the basic actions at the moment

# Functions START

recover_action() {
    cd "${tmp_dir}"
    case "$1" in
    fstab)
        recover_action="$1"
        ;;
    kernel)
        recover_action="$1"
        ;;
    initrd)
        recover_action="$1"
        ;;
    esac

    # simple retry logic with a loop
    while true; do
        #wget -q --no-cache "https://raw.githubusercontent.com/malachma/azure-auto-recover/master/${recover_action}.sh"
        wget -q --no-cache "https://raw.githubusercontent.com/malachma/azure-auto-recover/ubuntu-image/${recover_action}.sh"
        if [[ $? -eq 0 ]]; then
            echo "File ${recover_action}.sh was fetched"
            break # the file got fetched, otherwise we try this again
        fi
    done


    if [[ -f "${tmp_dir}/${recover_action}.sh" ]]; then
        echo "Starting recover action:  ${recover_action}"
        chmod 700 "${tmp_dir}/${recover_action}.sh"
        chroot /mnt/rescue-root "${tmp_dir}/${recover_action}.sh"
        echo "Recover action:  ${recover_action} finished"
    else
        echo "File ${recover_action}.sh does not exist. Exiting ALAR"
        global_error="true"
    fi

    [[ ${global_error} == "true" ]] && return 11
}

isInAction() {
    #be quiet, just let us know this action exists
    grep -q "$1" <<<"$actions"
    return "$?"
}

# Funtions END

#
# Start of the script
#

echo "Paramter passed over to base.sh: count=$# args=$@"

# Create tmp dir in order to store our files we download
tmp_dir="$(mktemp -d)"
cd "${tmp_dir}"

echo "TMP_DIR is: ${tmp_dir}"
echo""

# Filename for the distro verification
distro_test="distro-test.sh"

# Global redirection for ERR to STD
exec 2>&1

# simple retry logic with a loop
while true; do
    wget -q --no-cache https://raw.githubusercontent.com/malachma/azure-auto-recover/ubuntu-image/"${distro_test}"
    if [[ $? -eq 0 ]]; then
        echo "File ${distro-test} fetched"
        break # the file got fetched, otherwise we try this again
    fi
    sleep 1
done

#
# What OS we need to recover?
#

#  cp distro-test.sh ${tmp_dir}
#    . /home/rescue/distro-test.sh

if [[ -f "$tmp_dir/${distro_test}" ]]; then
    chmod 700 "${tmp_dir}/${distro_test}"
    . ${distro_test} # invoke the distro test
else
    logger -s "File ${distro_test}.sh could not be fetched. Exiting"
    exit 1
fi

#Mount the root part
#====================
if [[ ! -d /mnt/rescue-root ]]; then
    mkdir /mnt/rescue-root
fi

if [[ "${isRedHat}" == "true" || "${isSuse}" == "true" ]]; then
    # noouid is valid for XFS only
    if [[ "${isExt4}" == "true" ]]; then
        mount -n "${rescue_root}" /mnt/rescue-root
    elif [[ "${isXFS}" == "true" ]]; then
        mount -n -o nouuid "${rescue_root}" /mnt/rescue-root
    fi
fi

if [[ "$isUbuntu" == "true" ]]; then
    mount -n "$rescue_root" /mnt/rescue-root
fi

#Mount the boot part
#===================
if [[ ! -d /mnt/rescue-root/boot ]]; then
    mkdir /mnt/rescue-root/boot
fi

if [[ "$isRedHat" == "true" || "$isSuse" == "true" ]]; then
    # noouid is valid for XFS only
    if [[ "${isExt4}" == "true" || "${isExt3}" == "true" ]]; then
        mount "${boot_part}" /mnt/rescue-root/boot
    elif [[ "${isXFS}" == "true" ]]; then
        mount -o nouuid "${boot_part}" /mnt/rescue-root/boot
    fi
fi

# Mount the EFI part if Suse
if [[ "${isSuse}" == "true" ]]; then
    if [[ ! -d /mnt/rescue-root/boot/efi ]]; then
        mkdir /mnt/rescue-root/boot/efi
    fi
    mount "${efi_part}" /mnt/rescue-root/boot/efi
fi

#Mount the support filesystems
#==============================
#see also http://linuxonazure.azurewebsites.net/linux-recovery-using-chroot-steps-to-recover-vms-that-are-not-accessible/
for i in dev proc sys tmp dev/pts; do
    if [[ ! -d /mnt/rescue-root/"$i" ]]; then
        mkdir /mnt/rescue-root/"$i"
    fi
    mount -o bind /"$i" /mnt/rescue-root/"$i"
done

if [[ "${isUbuntu}" == "true" || "${isSuse}" == "true" ]]; then
    if [[ ! -d /mnt/rescue-root/run ]]; then
        mkdir /mnt/rescue-root/run
    fi
    mount -o bind /run /mnt/rescue-root/run
fi

# Reformat the action value
#action_value=$(echo $1 | tr ',' ' ')
action_value="fstab"
recover_status=""
# What action has to be performed now?
for k in $action_value; do
    if [[ "$(isInAction $k)" -eq 0 ]]; then
        case "${k,,}" in
        fstab)
            echo "We have fstab as option"
            recover_status=recover_action "$k"
            ;;
        kernel)
            echo "We have kernel as option"
            recover_status=recover_action "$k"
            ;;
        initrd)
            echo "We have initrd as option"
            recover_status=recover_action "$k"
            ;;
        esac
    fi
done

#Clean up everything
cd /
for i in dev/pts proc tmp sys dev; do umount /mnt/rescue-root/"$i"; done

if [[ "$isUbuntu" == "true" || "$isSuse" == "true" ]]; then
    #is this really needed for Suse?
    umount /mnt/rescue-root/run
    if [[ -d /mnt/rescue-root/boot/efi ]]; then
        umount /mnt/rescue-root/boot/efi
    fi
fi

if [[ "$isUbuntu" == "false" ]]; then
    umount /mnt/rescue-root/boot #may throw an erro on Ubuntu, but can be ignored
fi

umount /mnt/rescue-root
rm -fr /mnt/rescue-root
rm -fr "$tmp_dir/$FSTAB"

if [[ ${recover_status} -eq 11 ]]; then
    logger -s "The recover action throwed an error"
    exit 1
else
    exit 0
fi
