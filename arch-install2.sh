#!/bin/bash -v
# User side of the program
# Install Paru

cd /home/jebus/ || exit

xdg-user-dirs-update

git clone https://aur.archlinux.org/paru.git
cd paru || exit
makepkg -si --noconfirm --needed
cd /home/jebus/ || exit

# Set up git bare directory and syncronize with git repo

mkdir .dotfiles
cd .dotfiles || exit
git init --bare
echo -e '[remote "master"]
    url = git@github.com:Jebusthebus/dotfiles.git
    fetch = +refs/heads/*:refs/remotes/master/*
[pull]
    rebase = true
[branch "master"]
	remote = master
	merge = refs/heads/master' >> .dotfiles/config
/usr/bin/git --git-dir="$HOME"/.dotfiles/ --work-tree="$HOME" pull
cd /home/jebus/ || exit

# Install aur packages

paru -S --needed - < aurpkglist.txt

# Install ananicy, it should at worst be ineffective

sudo systemctl enable --now ananicy-cpp.service

# Configure profilesync daemon and run it

psd
sed -i '15s/.*/USE_OVERLAYFS="yes"/' ~/.config/psd/psd.conf
sed -i '56s/.*/BROWSERS=(chromium)/' ~/.config/psd/psd.conf
systemctl --user --now enable psd.service

## Increase size of the runtime dir (is stored in memory), this is safe because it will only use what is stored in it instead of preallocating memory space

sudo sed -i '44s/.*/RuntimeDirectorySize=30%/' /etc/systemd/logind.conf

# Set xdg-desktop-portal-gtk as fallback

echo -e '[preferred]\ndefault=gtk' > .config/xdg-desktop-portal/portals.conf


# Setup pipewire and wireplumber

systemctl --user enable --now pipewire.service
systemctl --user enable --now pipewire-pulse.service
systemctl --user enable --now wireplumber.service

# Setup bash git prompt

git clone https://github.com/magicmonty/bash-git-prompt.git ~/git/bash-git-prompt --depth=1

# Enable syncthing

systemctl --user enable --now syncthing.service

# Enable cleanup units
systemctl --user enable --now cleanup.timer
systemctl --user enable --now profile-cleaner.service
systemctl --user enable --now orphan-remover.service

#Move some files around to clean the /home/

mkdir .config/git
mv .gitconfig .config/git/

mkdir .config/pulse
mv .pulse-cookie .config/pulse
