#!/bin/bash

# Get up to date arch mirrors

reflector --latest 200 --protocol http,https --sort rate --save /etc/pacman.d/mirrorlist

# Install arch and some useful programs

pacstrap -k /mnt base linux-zen linux-zen-headers linux-firmware base-devel networkmanager vim nvim man-db man-pages texinfo grub efibootmgr amd-ucode reflector git

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt

ln -sf /usr/share/zoneifno/Europe/Zurich /etc/localtime

hwclock --systohc

sed -i '171s/^.//' /etc/locale.gen

locale-gen

echo 'LANG=en_US.UTF-8' >> /etc/locale.conf

echo 'jebus-desktop' >> /etc/hostname

systemctl start NetworkManager.service
systemctl enable NetworkManager.service

passwd stefan98

# Install grub

grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=GRUB

grub-mkconfig -i /boot/grub/grub.cfg

reboot
