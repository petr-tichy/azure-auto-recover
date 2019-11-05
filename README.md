# Azure Linux Auto Recover

This is not production ready!!
**BETA!!**
Still to be further tested!!

The Azurer Linux Auto Recover (ALAR) tool is a set of bash scripts that allow a Linux VM to be automatically recovered
if the OS does not boot correct. 
The most common scenarios which are covered by ALAR are at the moment are:

* malformed /etc/fstab 
  * syntax error
  * missing disk
* damaged initrd or missing initrd line in the /boot/grub/grub.cfg
* last installed kernel is not bootable

For each scenario exists at least one file that contains the recovery logic for a specific scenario.
### FSTAB
This script does strip off any lines in the /etc/fstab file which are not needed to boot a system
It makes a copy of the original file first. So after the start of the OS the admin is able to edit the fstab again and correct any errors which didn’t allow a reboot of the system before

### Kernel
This script does change the default kernel.
It modifies the configuration so that the previous kernel version gets booted

### Initrd
This script corrects two issues that can happen when a new kernel gets installed
   1: The grub.cfg file is missing an “initrd” line or is missing the file to be used
   2: The initrd image is missing
So it either fixes the grub.cfg file and/or creates a new initrd image 

### Bird's-eye overview how it works
In order to do the auto recovery a new VM is created which uses the same OS and VM type.
The failed VM gets stopped first and a copy of the OS disk is created.
This disk gets attached to the recovery VM then. With the help of the custom script engine the auto recovery for each scenario is executed. After the recovery-scenario the OS-Disk copy is removed from the recovery VM. Next step is to swap the original OS-Disk with the copy disk and start the VM again. The tool makes havey use of the Azure CLI.

### How can I recover my failed VM?
The rescue script can be only executed in a Linux environment which has also azure cli installed.
To do this please consult this documentation: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest
Or simply use the cloud-shell: https://docs.microsoft.com/en-us/azure/cloud-shell/overview

Another prerequisite is the tool 'jq'.
If it is missing it needs to be installed.
- For Ubuntu/Debian: sudo apt-get install jq
- For RedHat/Centos: sudo yum install jq

If all of the above is met download the script "rescue.sh" from the repository. 
Make it executable: chmod 755 rescue.sh

To recover a failed vm it can be invoked with the following options to get the initrd corrected


All the options are mandatory

1. --rescue-vm-name : Name of the Rescue VM Name\n
2. -u or --username : Rescue VM's Username\n
3. -g or --resource-group : Problematic Original VM's Resource Group\n
4. -n or --name : Problematic Original VM\n
5. -p or --password : Rescue VM's Password\n
6. -s or --subscription : Subscription Id where the respective resources are present.\n\n
7. --action : The action to be performed [fstab,kernel, initrd]

Example

`./rescue.sh --rescue-vm-name suse-15-recover2 -u rescue -g sles15_rg -n suse15-test -p Welcome1Microsoft! -s c98141ca-e173-46dd-9395-xxxxxxxxxxxxx --action initrd`

You can also do two or all of the three recoveries. To do this separate the arguments, for the --action option, with commas i.e.
`--action kernel,fstab`or `--action kernel,initrd,fstab`
