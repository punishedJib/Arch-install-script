#!/bin/bash -v

# Setup reflector service to have always uptodate arch mirrors

reflector --latest 5 --protocol https --sort rate --country Germany,France --save /etc/pacman.d/mirrorlist
sed -i '27s/.*/--sort rate/' /etc/xdg/reflector/reflector.conf
echo '--country Germany,France' >> /etc/xdg/reflector/reflector.conf
systemctl enable reflector.timer
systemctl start reflector.timer

# Enable multi downloads in pacman and enable multilib repo
sed -i '37s/.*/ParallelDownloads = 5/' /etc/pacman.conf
sed -i '90s/.*/[multilib]/' /etc/pacman.conf
sed -i "91s/.*/Include = \/etc\/pacman.d\/mirrorlist\/" /etc/pacman.conf

# Write pacman hook to keep uptodate pkglist

echo -e "[Trigger]
Operation = Install
Operation = Remove
Type = Package
Target = *

[Action]
When = PostTransaction
Exec = /bin/sh -c '/usr/bin/pacman -Qqe > /etc/pkglist.txt'"

# Add user and add it to some useful groups

groupadd plugdev
groupadd gamemode
useradd -m -G wheel,plugdev,gamemode,video,audio jebus
passwd -d jebus

# Install everything needed

pacman -Sy
pacman -S --needed --noconfirm - < pkglist.txt

# Add wheel group to no passwd sudo using a file, can't find an elegant solution for using visudo and I can't be bothered right now

echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/99_wheel

# Disable iptables and flush them.
systemctl stop iptables.service
systemctl disable iptables.service
chmod +x iptablesflush.sh
./iptablesflush.sh

# Setup nftables as by arch's regulation for a meaningful firewall
nft flush ruleset
nft add table inet my_table
nft add chain inet my_table input '{ type filter hook input priority 0 ; policy drop ; }'
nft add chain inet my_table forward '{ type filter hook forward priority 0 ; policy drop ; }'
nft add chain inet my_table output '{ type filter hook output priority 0 ; policy accept ; }'
nft add chain inet my_table tcp_chain
nft add chain inet my_table udp_chain
nft add rule inet my_table input ct state related,established accept
nft add rule inet my_table input iif lo accept
nft add rule inet my_table input ct state invalid drop
nft add rule inet my_table input meta l4proto ipv6-icmp accept
nft add rule inet my_table input meta l4proto icmp accept
nft add rule inet my_table input ip protocol igmp accept
nft add rule inet my_table input meta l4proto udp ct state new jump udp_chain
nft add rule inet table my_input 'meta l4proto tcp tcp flags & (fin|syn|rst|ack) == syn ct state new jump tcp_chain'
nft add rule inet my_table input meta l4proto udp reject
nft add rule inet my_table input meta l4proto tcp reject with tcp reset
nft add rule inet my_table input counter reject with icmpx port-unreachable
# Open some useful ports
# SSH
nft add rule inet my_table tcp_chain tcp dport 22 accept
# qBittorrent
nft add rule inet my_table tcp_chain tcp dport 56503 accept
nft add rule inet my_table udp_chain udp dport 56503 accept
# Localsend
nft add rule inet my_table tcp_chain tcp dport 53317 accept
# Enable forwarding for vopono namespaces
nft add rule inet my_table forward iifname "enp9s0" ip daddr 10.200.0.2/16 accept
nft add rule inet my_table forward oifname "enp9s0" ip saddr 10.200.0.2/16 accept
nft list ruleset > /etc/nftables.conf

# Enable firejail
firecfg
rm /usr/bin/chromium

# Give generic machine id

echo "b08dfa6083e7567a1921a715000001fb" > /etc/machine-id
echo "b08dfa6083e7567a1921a715000001fb" > /var/lib/dbus/machine-id


# Add timer to ssh login failed attemps, deny root login and enable key only login

echo 'auth optional pam_faildelay.so delay=4000000' >> /etc/pam.d/system-login
echo 'PermitRootLogin no' >> /etc/ssh/sshd_config.d/20-deny_root.conf
echo 'kernel.kexec_load_disabled = 1' >> /etc/sysctl.d/51-kexec-restrict.conf

# Mouse settings using libinput

echo -e 'Section "InputClass"\n    Identifier "My Mouse"\n    Driver "libinput"\n    MatchIsPointer "yes"\n    Option "AccelProfile" "flat"\n    Option "AccelSpeed" "-0.75"\nEndSection' >> /etc/X11/xorg.conf.d/50-mouse-acceleration.conf

# Load nvidia kernel modules and amd_pstate (this requires amd cppc enabled' using initframs

sed -i '7s/.*/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf

# Set invidia kernel modules settings

echo -e 'options nvidia-drm modeset=1\noptions nvidia NVreg_UsePageAttributeTable=1\noptions nvidia NVreg_EnablePCIeGen3=1' >> /etc/modprobe.d/nvidia.conf

# Pacman hook to update initframs after each nvidia update

mkdir /etc/pacman.d/hooks/
echo -e "[Trigger]\nOperation=Install\nOperation=Upgrade\nOperation=Remove\nType=Package\nTarget=nvidia\nTarget=linux-zen\n# Change the linux part above and in the Exec line if a different kernel is used\n\n[Action]\nDescription=Update NVIDIA module in initcpio/nDepends=mkinitcpio\nWhen=PostTransaction\nNeedsTargets\nExec=/bin/sh -c 'while read -r trg; do case \$trg in linux) exit 0; esac; done; /usr/bin/mkinitcpio -P'" > /etc/pacman.d/hooks/nvidia.hook


# Dnscrypt setup
sed -i '79s/.*/require_dnssec = true/' /etc/dnscrypt-proxy/dnscrypt-proxy.toml
sed -i '82s/.*/require_nolog = true/' /etc/dnscrypt-proxy/dnscrypt-proxy.toml
sed -i '85s/.*/require_nofilter = true/' /etc/dnscrypt-proxy/dnscrypt-proxy.toml
sed -i '42s/.*/listen_addresses = ['\''127.0.0.1:53'\'', '\''[::1]:53'\'']/' /etc/dnscrypt-proxy/dnscrypt-proxy.toml
echo '' > /etc/resolv.conf
echo -e 'nameserver ::1\nnameserver 127.0.0.1\noptions edns0' > /etc/resolv.conf
# Stop NetworkManager from modifying resolv.conf
echo -e '[main]\ndns=none' >> /etc/NetworkManager/NetworkManager.conf
systemctl enable dnscrypt-proxy.service
systemctl start dnscrypt-proxy.service

# Chrony setup

sed -i '30s/.*/server 0.europe.pool.ntp.org/' /etc/chrony.conf
sed -i '31s/.*/server 1.europe.pool.ntp.org/' /etc/chrony.conf
sed -i '32s/.*/server 2.europe.pool.ntp.org/' /etc/chrony.conf
sed -i '33s/.*/server 3.europe.pool.ntp.org/' /etc/chrony.conf
sed -i '123s/.^//' /etc/chrony.conf
sed -i '295s/.^//' /etc/chrony.conf
sed -i '317s/.*/! rtcsync/' /etc/chrony.conf
mkdir /etc/sysconfig/
echo "OPTIONS='-r -s'" > /etc/sysconfig/chronyd
echo -e 'dumponexit' >> /etc/chrony.conf
systemctl enable chronyd.service
systemctl start chronyd.service
chronyc online

# Disable core dumps

echo 'kernel.core_pattern=/dev/null' > /etc/sysctl.d/50-coredump.conf

# Improve network performance (?)
echo 'net.ipv4.tcp_fastopen = 3' >> /etc/sysctl.d/99-sysctl.conf
echo -e 'net.core.default_qdisc = cake\nnet.ipv4.tcp_congestion_control = bbr' >> /etc/sysctl.d/99-sysctl.conf

# Disable watchdog and change grub wallpaper

sed -i '6s/.*/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet nowatchdog tsc=reliable clocksource=tsc amd_pstate=active amd_pstate.shared_mem=1"/' /etc/default/grub
sed -i '46s|.*|GRUB_BACKGROUND="/home/jebus/Pictures/Wallpapers/Pokemon_may_waterfall/1d920581-c76c-40f3-b340-9fa34e013c7c_maywaterfalldesktophd.png"|' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable fstrim.timer

# Kernel tweaks from arch/gaming

echo '#    Path                  Mode UID  GID  Age Argument' >> /etc/tmpfiles.d/consistent-response-time-for-gaming.conf
echo 'w /proc/sys/vm/compaction_proactiveness - - - - 0' >> /etc/tmpfiles.d/consistent-response-time-for-gaming.conf
echo 'w /proc/sys/vm/min_free_kbytes - - - - 838860' >> /etc/tmpfiles.d/consistent-response-time-for-gaming.conf
echo 'w /proc/sys/vm/swappiness - - - - 10' >> /etc/tmpfiles.d/consistent-response-time-for-gaming.conf
echo 'w /sys/kernel/mm/lru_gen/enabled - - - - 5' >> /etc/tmpfiles.d/consistent-response-time-for-gaming.conf
echo 'w /proc/sys/vm/zone_reclaim_mode - - - - 0' >> /etc/tmpfiles.d/consistent-response-time-for-gaming.conf
echo 'w /proc/sys/vm/page_lock_unfairness - - - - 1' >> /etc/tmpfiles.d/consistent-response-time-for-gaming.conf

# Enable paccache.timer to clean all cache except the most recent 3 packages

systemctl enable paccache.timer

# Run third part of the script as jebus to make things easier

chown jebus arch-install2.sh
chmod +x arch-install2.sh
mv arch-install2.sh /home/jebus/
mv aurpkglist.txt /home/jebus/
