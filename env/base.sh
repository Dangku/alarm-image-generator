#!/bin/bash

alarm_install_package() {
    package=$(ls /mods/packages/$1*.pkg.tar.* | sort | tail -n1)
    yes | pacman -U "$package"
}

alarm_pacman() {
    yes | pacman -S --needed --noconfirm $@
}

# Include environment hooks
if [ -e /env.sh ]; then
    source /env.sh
fi

if [ -e /platform.sh ]; then
    source /platform.sh
fi

#
# Try to set locale before installing packages.
#
sed -i 's/#en_US\.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
locale-gen
localectl set-locale en_US.UTF-8

#
# PACMAN SETUP
#
pacman-key --init
pacman-key --populate archlinuxarm

#
# Add custom repo for some extra packages
#
alarm_install_package archlinuxdroid-repo
alarm_install_package dangku-repo

#
# Sync pacman databases
#
pacman -Suy --noconfirm

# Devel
alarm_pacman base-devel cmake git arch-install-scripts

# Bluetooth
alarm_pacman bluez bluez-utils

# Network
alarm_pacman iw inetutils \
    wireless_tools wireless-regdb net-tools netctl whois wget openssh \
    samba smbclient cifs-utils links wpa_supplicant

# System
alarm_pacman pciutils sudo cpupower usbutils ntfs-3g \
    neofetch lsb-release nano dialog terminus-font

# Shell
alarm_pacman zsh zsh-autosuggestions zsh-completions \
    zsh-syntax-highlighting

# Realtime priviliges for audio recording
alarm_pacman realtime-privileges


#
# INSTALL CUSTOM PACKAGES
#
alarm_install_package yay-bin


#
# Initial alarm user account setup
#
usermod -G audio,tty,video,input,wheel,network,realtime -a alarm
cp /mods/etc/sudoers.d/wheel /etc/sudoers.d/
cp /mods/home/alarm/.makepkg.conf /home/alarm/
chown -R alarm:alarm /home/alarm


#
# SETUP HOOKS
#
if type "platform_chroot_setup" 1>/dev/null ; then
    echo "Executing platform chroot setup hook..."
    platform_chroot_setup
fi

if type "env_chroot_setup" 1>/dev/null ; then
    echo "Executing environment chroot setup hook..."
    env_chroot_setup
fi


#
# TWEAKS
#

# Fix domain resolution issue
cp /mods/etc/systemd/resolved.conf /etc/systemd/

# Add initial setup script
cp /mods/etc/systemd/system/initial-setup.service /etc/systemd/system/
cp /mods/usr/bin/initial-img-setup /usr/bin/


#
# CUSTOMIZATIONS
#
cp /mods/etc/fstab /etc/
chsh -s /usr/bin/zsh alarm
cp /mods/etc/sysctl.d/general.conf /etc/sysctl.d/general.conf
cp /mods/etc/default/cpupower /etc/default/
cp /mods/etc/vconsole.conf /etc/
if [ ! -e "/mods/packages/.oh-my-zsh" ]; then
    git clone -c core.eol=lf -c core.autocrlf=false \
        -c fsck.zeroPaddedFilemode=ignore \
        -c fetch.fsck.zeroPaddedFilemode=ignore \
        -c receive.fsck.zeroPaddedFilemode=ignore \
        --depth=1 --branch "master" \
        "https://github.com/ohmyzsh/ohmyzsh" \
        /mods/packages/.oh-my-zsh
fi
cp -a /mods/packages/.oh-my-zsh /home/alarm/
cp /home/alarm/.oh-my-zsh/templates/zshrc.zsh-template /home/alarm/.zshrc

chown -R alarm:alarm /home/alarm


#
# SYSTEM SERVICES
#
systemctl enable sshd
systemctl enable bluetooth
systemctl enable cpupower
systemctl enable systemd-resolved
systemctl enable systemd-timesyncd
systemctl enable initial-setup


#
# Exit HOOKS
#
if type "platform_chroot_setup_exit" 1>/dev/null ; then
    echo "Executing platform chroot setup exit hook..."
    platform_chroot_setup_exit
fi

exit
