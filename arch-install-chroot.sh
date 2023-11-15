#!/bin/bash -v

ln -sf /usr/share/zoneifno/Europe/Zurich /etc/localtime

hwclock --systohc

sed -i '171s/^.//' /etc/locale.gen

locale-gen

echo 'LANG=en_US.UTF-8' >> /etc/locale.conf

echo 'jebus-desktop' >> /etc/hostname

systemctl start NetworkManager.service
systemctl enable NetworkManager.service

echo 'root:stefan98' | changepasswd

# Install grub

grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id=GRUB

grub-mkconfig -o /boot/grub/grub.cfg

exit
