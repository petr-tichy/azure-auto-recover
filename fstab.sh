#!/bin/bash
mv -f /etc/fstab{,.copy}
awk '/[[:space:]]+\/[[:space:]]+/ {print}' /etc/fstab.copy >>/etc/fstab
awk '/[[:space:]]+\/boot[[:space:]]+/ {print}' /etc/fstab.copy >>/etc/fstab
#For Suse
awk '/[[:space:]]+\/boot\/efi[[:space:]]+/ {print}' /etc/fstab.copy >>/etc/fstab
cat /etc/fstab
exit 0
