#!/bin/bash

# Get up to date arch mirrors

reflector --latest 5 --protocol https --sort rate --country Germany,France --save /etc/pacman.d/mirrorlist

# Install arch and some useful programs

pacstrap -K /mnt base linux-zen linux-zen-headers linux-firmware base-devel networkmanager vim nvim man-db man-pages texinfo grub efibootmgr amd-ucode reflector git

genfstab -U /mnt >> /mnt/etc/fstab

# Run the chroot part of the script
chmod +x arch-install-chroot.sh
mv arch-install-chroot.sh /mnt
arch-chroot /mnt /bin/bash arch-install-chroot.sh

reboot
