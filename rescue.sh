#!/bin/bash

# Author : Marcus Lachmanez (malachma@microsoft.com Azure Linux Escalation Team)
# Date : June 2019

# Author : Sriharsha B S (sribs@microsoft.com, Azure Linux Escalation Team),  Dinesh Kumar Baskar (dibaskar@microsoft.com, Azure Linux Escalation Team)
# Date : 13th August 2018
# Description : BASH form of New-AzureRMRescueVM powershell command.

# What is the Distro type?
DISTRO_NAME=$(cat /etc/os-release | awk "/^NAME/" | sed -e 's/NAME=//')
DISTRO_NAME=${DISTRO_NAME//\"}

# At first verify we have the jq tool/package installed
if [[ $DISTRO_NAME == "Ubuntu" || $DISTRO_NAME == "Debian GNU/Linux" ]];
then
    dpkg-query -l jq 2> /dev/null | grep ii 2>&1 > /dev/null
else
    rpmquery jq 2>&1 > /dev/null
fi

if [[ $? -ne 0 ]];
then
    echo "Please install the 'jq' tool first
          For Ubuntu/Debian: sudo apt-get install jq
          For RedHat/Centos: sudo yum install jq
         "
    exit 1
fi

# Second verify we have the azure cli package installed
if [[ $DISTRO_NAME == "Ubuntu" || $DISTRO_NAME == "Debian GNU/Linux" ]];
then
    #dpkg-query -l azure-cli 2> /dev/null | grep ii 2>&1 > /dev/null
    dpkg-query -l azure-cli 2>&1 > /dev/null
else
    rpmquery azure-cli 2>&1 > /dev/null
fi


if [[ $? -ne 0 ]];
then
    echo "Please install the 'azure-cli' tool first
          To do this please consult this documentation: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli-yum?view=azure-cli-latest
          Or simply use the cloud-shell: https://docs.microsoft.com/en-us/azure/cloud-shell/overview
         "
    exit 1
fi


help="\n
========================================================================================\n
Description\n
========================================================================================\n\n
You may run this script if you may require a temporary (Rescue VM) for troubleshooting of the OS Disk.\n
This Script Performs the following operation :\n
1. Stop and Deallocate the Problematic Original VM\n
2. Make a OS Disk Copy of the Original Problematic VM depending on the type of Disks\n
3. Create a Rescue VM (based on the Original VM's Distribution and SKU) and attach the OS Disk copy to the Rescue VM\n
4. Start the Rescue VM for troubleshooting.\n\n\n

=========================================================================================\n
Arguments and Usage\n
=========================================================================================\n\n
All the arguments are mandatory. However, arguments may be passed in any order\n
1. --rescue-vm-name : Name of the Rescue VM Name\n
2. -u or --username : Rescue VM's Username\n
3. -g or --resource-group : Problematic Original VM's Resource Group\n
4. -n or --name : Problematic Original VM\n
5. -p or --password : Rescue VM's Password\n
6. -s or --subscription : Subscription Id where the respective resources are present.\n\n

Usage Example: ./rescue.sh --recue-vm-name rescue1 -g debian -n debian9 -s  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx -u rescue -p microsoftWelcome1!\n\n\n
"

POSITIONAL=()
if [[ $# -ne 14 ]]
then
    echo -e $help
    exit;
fi
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -g|--resource-group)
    g="$2"
    shift # past argument
    shift # past value
    ;;
    -n|--name)
    vm="$2"
    shift # past argument
    shift # past value
    ;;
    -s|--subscription)
    subscription="$2"
    shift # past argument
    shift # past value
    ;;
    -u|--username)
    user="$2"
    shift # past argument
    shift # past value
    ;;
    --rescue-vm-name)
    rn="$2"
    shift # past argument
    shift
    ;;
    -p|--password)
    password="$2"
    shift # past argument
    shift
    ;;
    --action)
    action="$2"
    shift # past argument
    shift
    ;;
    *)    # unknown option
    echo -e $help
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    exit;
    ;;
esac
done



# Check whether user has an azure account
has_az_account () {
    acc=$(az account show)
    if [[ -z $acc ]];
    then
        echo "Please login using az login command"
        exit 1;
    fi
}

# Check if user has a valid azure subscription. If yes, select the subscription as the default subscription
has_valid_subscription () {
    subvalid=$(az account list | jq ".[].id" | grep -i $subscription)
    if [[ $(echo "${subvalid//\"}") != "$subscription" || -z $subvalid ]];
    then
        echo "No Subscription $subscription exists"
        exit 1;
    else
        az account set --subscription $subscription
    fi
}

stop_damaged_vm () {
    echo "Stopping and deallocating the Problematic Original VM"
    az vm deallocate -g $g -n $vm 2>&1 > /dev/null
    echo "VM is stopped" 
}

get_vm_properties () {
    vm_details=$(az vm show -g $g -n $vm)
    location=$(echo $vm_details | jq '.location' | tr -d '"')
    resource_group=$g
    os_disk=$(echo $vm_details| jq ".storageProfile.osDisk")
    managed=$(echo $os_disk | jq ".managedDisk")
    offer=$(echo $vm_details | jq ".storageProfile.imageReference.offer")
    publisher=$(echo $vm_details | jq ".storageProfile.imageReference.publisher")
    sku=$(echo $vm_details | jq ".storageProfile.imageReference.sku")
    version=$(echo $vm_details | jq ".storageProfile.imageReference.version")
    urn=$(echo "${publisher//\"}:${offer//\"}:${sku//\"}:${version//\"}")
    disk_uri="null"
}

create_rescue_vm () {
    if [[ $managed == "null" ]];    
    then
        disk_uri=$(echo $os_disk | jq ".vhd.uri")
        disk_uri=$(echo "${disk_uri//\"}")

        #see http://mywiki.wooledge.org/BashFAQ/073 for further information about the next lines
        original_disk_name=${disk_uri##*/}
        original_disk_name=${original_disk_name%.*}  
        target_disk_name=$original_disk_name-copy
        storage_account=${disk_uri%%.*} 
        storage_account=${storage_account#*//}

        echo "creating a copy of the OS disk"
        az storage blob copy start --destination-blob $target_disk_name.vhd --destination-container vhds --account-name $storage_account --source-uri $disk_uri 2>&1 >> recover.log


        echo "Creating the rescue VM $rn"
        az vm create --use-unmanaged-disk --name $rn -g $g --location $location --admin-username $user --admin-password $password --image $urn --storage-sku Standard_LRS 2>&1 >> recover.log 
        echo "New VM is created"

        # We wait for all other functions to complete before we perform the attach
        wait
        echo "Attach the OS-Disk copy to the rescue VM:$rn"
        az vm unmanaged-disk attach --vm-name $rn -g $g --name origin-os-disk  --vhd-uri "https://$storage_account.blob.core.windows.net/vhds/$target_disk_name.vhd" 2>&1 >> recover.log

    else
        disk_uri=$(echo $os_disk | jq ".managedDisk.id")
        disk_uri=$(echo "${disk_uri//\"}")
        #see http://mywiki.wooledge.org/BashFAQ/073 for further information about the next lines
        original_disk_name=${disk_uri##*/}
        original_disk_name=${original_disk_name%.*}  
        target_disk_name=$original_disk_name-copy

        echo "Create a snapshot of the origine-os-disk: $original_disk_name"
        az snapshot create -g $resource_group -n $original_disk_name-snap --source $original_disk_name -l $location 2>&1 >> recover.log


        echo "Create a disk from the snapshot"
        snapshotId=$(az snapshot show --name $original_disk_name-snap --resource-group $resource_group | jq ".id" )
        az disk create --resource-group $resource_group --name $target_disk_name -l $location --sku Standard_LRS --source ${snapshotId//\"} 2>&1 >> recover.log


        echo "Creating the rescue VM: $rn"
        az vm create --name $rn -g $g --location $location --admin-username $user --admin-password $password --image $urn --storage-sku Standard_LRS 2>&1 >> recover.log
        echo "VM created. Attaching the OS-Disk to be recovered"
        az vm disk attach -g $g --vm-name $rn --disk  $target_disk_name 2>&1 >> recover.log

    fi
}


# get the OS disk uri for the problematic os disk from the Rescue VM which is currently attached to the rescue VM
get_os_disk_uri () {
    echo "Inside get_os_disk_uri"
    datadisks=$(az vm show -g $g -n $rn | jq ".storageProfile.dataDisks")
    managed=$(echo $datadisks | jq ".[0].managedDisk")
    disk_uri="null"
    disk_name="null"
    if [[ $managed == "null" ]];
    then
        disk_uri=$(echo $datadisks | jq ".[].vhd.uri" | sed s/\"//g)
        disk_name=$(az vm show -g $g -n $rn | jq ".storageProfile.dataDisks[0].name" | sed s/\"//g )
    else
        disk_uri=$(echo $datadisks | jq ".[].managedDisk.id" | sed s/\"//g)
        disk_name=$(az vm show -g $g -n $rn | jq ".storageProfile.dataDisks[0].name" | sed s/\"//g )
        echo "disk_uri: $disk_uri"
        echo "disk_name: $disk_name"

    fi
}

# Detach the Problematic OS disk from the Rescue VM
detach_os_disk () {
    echo "Detaching the failed OS disk from the rescue VM"

    get_os_disk_uri

    if [[ $managed == "null" ]];
    then
    	az vm unmanaged-disk detach -g $g --vm-name $rn -n $disk_name 2>&1 >> recover.log
    else
    	az vm disk detach -g $g --vm-name $rn -n $disk_name 2>&1 >> recover.log
    fi
}

# OS Disk Swap 
swap_os_disk () {
    echo "Preparing for OS disk swap"
    # Stop the Problematic VM
    echo "Stopping and deallocating the problematic original VM"
    az vm deallocate -g $g -n $vm 2>&1 >> recover.log

    # Perform the disk swap and verify
    echo "Performing the OS disk Swap"

    if [[ $managed == "null" ]];
    then
        #
        # We do this for the unmanged VM via a break lease operation
        #
        az storage blob lease break -c vhds --account-name $storage_account -b $original_disk_name.vhd 2>&1 >> recover.log
        az storage blob copy start  -c vhds -b $original_disk_name.vhd --source-container vhds --source-blob $target_disk_name.vhd --account-name $storage_account 2>&1 >> recover.log
    else
        az vm update -g $g -n $vm --os-disk $target_disk_name 2>&1 >> recover.log
    fi
}

# Start the Fixed VM after disk swap
start_fixedvm () {
    echo "Successfully swapped the OS disk. Now starting the Problematic VM with OS disk $swap"
    az vm start -g $g -n $vm
    echo "Start of the VM $vm Successful"
}

build_json_string () {
  # option $1 contains the additional function we would like to execute  
  printf "'%s'" "{\"fileUris\": [\"https://raw.githubusercontent.com/malachma/azure-support-scripts/master/base.sh\"], \"commandToExecute\": \"./base.sh $1\"}"
}

# End of function definition
# Start with main execution part
has_az_account
has_valid_subscription
get_vm_properties 
# Testing out whether a create_rescue_vm can be performed first before the damged VM gets stopped. As the stop operation takes some times. 
# This time can be better used if the stop operation is performed in the background 
stop_damaged_vm 
create_rescue_vm 

#
# Connect to the recovery VM. Load the file as defined in build_json_string() and execute the desired recovery option 
# INFO RECOVERY OPTIONS ARE NOT FULLY IMPLEMENTED YET
#
echo "Start recovery operation/s"
# eval is needed to get the expansion correct
eval az vm extension set --verbose --debug --resource-group $g   --vm-name $rn --name customScript   --publisher Microsoft.Azure.Extensions  --protected-settings $(build_json_string $action)
echo "Recovery finished"
read -p "Press Enter to continue"
read -p "Please press Enter again if you would like to end"

# Recovery finished and we are all set, ready to clean up 
detach_os_disk
swap_os_disk
start_fixedvm
