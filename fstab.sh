#!/bin/bash
mv -f /etc/fstab{,.copy};
cat /etc/fstab.copy | awk '/[[:space:]]+\/[[:space:]]+/ {print}' >> /etc/fstab;
cat /etc/fstab.copy | awk '/[[:space:]]+\/boot[[:space:]]+/ {print}' >> /etc/fstab;
cat /etc/fstab;
exit 0;