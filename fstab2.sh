echo "starting to create chroot environment"
chroot /mnt/rescue-root << EOF 
echo "In chroot"
mv -f /etc/fstab{,.copy} 
cat /etc/fstab.copy | awk '/\/ /{print}' >> /etc/fstab 
cat /etc/fstab.copy | awk '/\/boot /{print}' >> /etc/fstab 
cat /etc/fstab 
exit 
EOF

