chroot /mnt/rescue-root << EOF 
mv -f /etc/fstab{,.copy} 
cat /etc/fstab.copy | awk '/\/ /{print}' >> /etc/fstab 
cat /etc/fstab.copy | awk '/\/boot /{print}' >> /etc/fstab 
cat /etc/fstab 
exit 
EOF

