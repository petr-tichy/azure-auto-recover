

#
# recover logic for handling and initrd or kernel problem
#

recover_suse() {

}

recover_ubuntu() {

}

#
# Should handle all redhat based distros
#
recover_redhat() {

}

set_grub_default() {
    sed -i "s/GRUB_DEFAULT=[[:digit:]]/GRUB_DEFAULT=saved/" /etc/default/grub
}

get_menue_entries () {
    declare -a menuentry
    mapfile -t menuentry < <( grep -Ei 'submenu|menuentry ' /boot/grub2/grub.cfg | sed -re "s/(.? )'([^']+)'.*/\1 \2/" | awk '{print $5}' )    
}

Output Suse
-------------
sudo grep -Ei 'submenu|menuentry ' /boot/grub*/grub.cfg | sed -re "s/(.? )'([^']+)'.*/\1 \2/" | awk '/[[:digit:]]/ {print $}'
awk: cmd. line:1: /[[:digit:]]/ {print $}
awk: cmd. line:1:                       ^ syntax error
mla@suse12:~> sudo grep -Ei 'submenu|menuentry ' /boot/grub*/grub.cfg | sed -re "s/(.? )'([^']+)'.*/\1 \2/" | awk '/[[:digit:]]/ {print $0}'
menuentry  SLES 12-SP4
submenu  Advanced options for SLES 12-SP4
        menuentry  SLES 12-SP4, with Linux 4.12.14-95.24-default
        menuentry  SLES 12-SP4, with Linux 4.12.14-95.24-default (recovery mode)


Output Ubuntu 18
--------------

mla@ubuntu18:~$ grep -Ei 'submenu|menuentry ' /boot/grub*/grub.cfg | sed -re "s/(.? )'([^']+)'.*/\1 \2/" | awk '/[[:digit:]]/ {print $0}'
        menuentry  Ubuntu, with Linux 5.0.0-1014-azure
        menuentry  Ubuntu, with Linux 5.0.0-1014-azure (recovery mode)
        menuentry  Ubuntu, with Linux 4.18.0-1025-azure
        menuentry  Ubuntu, with Linux 4.18.0-1025-azure (recovery mode)
        menuentry  Ubuntu, with Linux 4.18.0-1024-azure
        menuentry  Ubuntu, with Linux 4.18.0-1024-azure (recovery mode)

Output Redhat 6
-----------------
[mla@red2 ~]$ sudo grep -Ei 'submenu|menuentry|title' /boot/grub*/grub*.conf | sed -re "s/(.? )'([^']+)'.*/\1 \2/" | awk '/[[:digit:]]/ {print $0}'
title Red Hat Enterprise Linux Server (2.6.32-696.18.7.el6.x86_64)
title Red Hat Enterprise Linux 6 (2.6.32-696.el6.x86_64)
[mla@red2 ~]$ uname -r
2.6.32-696.18.7.el6.x86_64
[mla@red2 ~]$ uname -a
Linux red2 2.6.32-696.18.7.el6.x86_64 #1 SMP Thu Dec 28 20:15:47 EST 2017 x86_64 x86_64 x86_64 GNU/Linux
[mla@red2 ~]$ cat /etc/os-release
cat: /etc/os-release: No such file or directory
[mla@red2 ~]$ sudo cat /etc/re
readahead.conf          redhat-access-insights/ redhat-lsb/             redhat-release          request-key.conf        request-key.d/          resolv.conf
[mla@red2 ~]$ sudo cat /etc/redhat-release
Red Hat Enterprise Linux Server release 6.9 (Santiago)


Output Redhat 7.5
------------------
sudo grep -Ei 'submenu|menuentry|title' /boot/grub2/grub.cfg | sed -re "s/(.? )'([^']+)'.*/\1 \2/" | awk '/[[:digit:]]/ {print $0}'
menuentry  CentOS Linux (3.10.0-957.27.2.el7.x86_64) 7 (Core)
menuentry  CentOS Linux (3.10.0-862.11.6.el7.x86_64) 7 (Core)

Output Ubuntu 16
-----------------
mla@ansible-test:~$ sudo grep -Ei 'submenu|menuentry|title' /boot/grub/grub.cfg | sed -re "s/(.? )'([^']+)'.*/\1 \2/" | awk '/[[:digit:]]/ {print $0}'
        menuentry  Ubuntu, with Linux 4.15.0-1055-azure
        menuentry  Ubuntu, with Linux 4.15.0-1055-azure (recovery mode)
        menuentry  Ubuntu, with Linux 4.15.0-1052-azure
        menuentry  Ubuntu, with Linux 4.15.0-1052-azure (recovery mode)
        menuentry  Ubuntu, with Linux 4.15.0-1046-azure
        menuentry  Ubuntu, with Linux 4.15.0-1046-azure (recovery mode)
        menuentry  Ubuntu, with Linux 4.15.0-1045-azure
        menuentry  Ubuntu, with Linux 4.15.0-1045-azure (recovery mode)
        menuentry  Ubuntu, with Linux 4.15.0-1042-azure
        menuentry  Ubuntu, with Linux 4.15.0-1042-azure (recovery mode)

SIEHE AUCH HIER --> https://www.linuxsecrets.com/2815-grub2-submenu-change-boot-order

# From the man page
#Set the default boot menu entry for GRUB.  This requires setting GRUB_DEFAULT=saved in /etc/default/grub

saved_entry=$(grub2-editenv - list| cut -d '=' -f2)
if [[ ${#saved_entry} -gt 1 ]];
then 
    echo "No index"
    echo ${saved_entry}
else 
    echo "Index is used"
    echo "Index is: $saved_entry"
fi


abhängig ob Index odernicht muss die Logik aufgebaut werden

