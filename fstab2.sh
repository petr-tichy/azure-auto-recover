#This file contains the logic to create a very minimalist fstab file which allows a boot of the VM
#in case it contains malformed lines
#To do this only the root part and if required the boot part will be added to this file
# The file gets passed over a here-string to chroot, thus the last command is an exit command
#Each line has also to end with a semicolon to be formating agnostic

mv -f /etc/fstab{,.copy};
cat /etc/fstab.copy | awk '/[[:space:]]+\/[[:space:]]+/ {print}' >> /etc/fstab;
cat /etc/fstab.copy | awk '/[[:space:]]+\/boot[[:space:]]+/ {print}' >> /etc/fstab;
cat /etc/fstab;
exit;