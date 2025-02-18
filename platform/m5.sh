#!/bin/bash

NAME="ArchLinuxARM-odroid-n2-latest"
IMAGE="ArchLinuxARM-bananapi-m5"

platform_variables() {
    echo "WAYLAND: set to 1 to install mali wayland GL libraries instead of fbdev."
    echo "DISABLE_MALIGL: set to 1 to disable installation of mali libraries."
    echo "TOBETTER_KERNEL: set to 1 to use tobetter kernel branch."
    echo "CHEWITT_KERNEL: set to 1 to use chewitt kernel branch."
}

platform_pre_chroot() {
    echo "Platform pre-chroot..."
}

platform_chroot_setup() {
    echo "Platform chroot-setup..."

    # Kernel
    yes | pacman -Rcs linux-odroid-n2
    yes | pacman -Rcs uboot-odroid-n2

    if [ "${CHEWITT_KERNEL}" = "1" ]; then
        alarm_pacman linux-amlogic-512
        alarm_pacman linux-amlogic-512-headers
        alarm_pacman dkms
    elif [ "${TOBETTER_KERNEL}" = "1" ]; then
        alarm_pacman linux-bananapi-512
        alarm_pacman linux-bananapi-512-headers
        alarm_pacman dkms
    else
        alarm_pacman linux-bananapi-g12
        alarm_pacman linux-bananapi-g12-headers
    fi

    # Updated uboot
    alarm_pacman uboot-bananapi-m5

    # Audio support
    alarm_pacman odroid-alsa

    if [ "${DISABLE_MALIGL}" != "1" ]; then
        if [ "${WAYLAND}" != "1" ]; then
            alarm_pacman odroid-c4-libgl-fb
            alarm_pacman odroid-gl4es
        fi
    else
        # mesa git for panfrost
        alarm_pacman mesa-devel-git

        if [ "${TOBETTER_KERNEL}" = "1" ] || [ "${CHEWITT_KERNEL}" = "1" ]; then
            echo "MOZ_X11_EGL=1" >> /etc/environment
        fi
    fi

    # Customizations
    cp /mods/boot/boot-logo.alarm.bmp.gz /boot/boot-logo.bmp.gz

    if [ "${TOBETTER_KERNEL}" = "1" ] || [ "${CHEWITT_KERNEL}" = "1" ]; then
        echo "Copy boot.ini adapted for mainline kernel..."
        cp /mods/boot/boot.m5.mainline.ini /boot/boot.ini

        if [ "${DISABLE_MALIGL}" = "1" ]; then
            echo "Enable panfrost-performance service..."
            cp /mods/etc/systemd/system/panfrost-performance.service /etc/systemd/system/
            systemctl enable panfrost-performance
        fi
    else
        echo "Copy boot.ini adapted for m5..."
        cp /mods/boot/boot.m5.bananapi.ini /boot/boot.ini
    fi
}

platform_chroot_setup_exit() {
    echo "Platform chroot-setup-exit..."
    # Install at last since this causes issues
    if [ "${DISABLE_MALIGL}" != "1" ]; then
        if [ "${WAYLAND}" = "1" ]; then
            alarm_pacman odroid-c4-libgl-wl
        fi
    fi

    cp /mods/etc/default/cpupower.c4 /etc/default/cpupower
}

platform_post_chroot() {
    echo "Platform post-chroot..."

    if [ "${TOBETTER_KERNEL}" = "1" ] || [ "${CHEWITT_KERNEL}" = "1" ]; then
        # Wireless
        alarm_yay_install rtl88xxau-aircrack-dkms-git
    fi

    echo "Setting boot.ini UUID"
    local loopname=$(echo "${LOOP}" | sed "s/\/dev\///g")

    local uuidboot=$(lsblk -o uuid,name | grep ${loopname}p1 | awk "{print \$1}")
    local uuidroot=$(lsblk -o uuid,name | grep ${loopname}p2 | awk "{print \$1}")

    sudo sed -i "s/root=\/dev\/mmcblk\${devno}p2/root=UUID=${uuidroot}/g" \
        root/boot/boot.ini

    sudo sed -i "s/setenv bootlabel \"ArchLinux\"/setenv bootlabel \"ArchLinux ${ENV_NAME}\"/g" \
        root/boot/boot.ini

    sudo echo "UUID=${uuidboot}  /boot  vfat  defaults,noatime,discard  0  0" \
        | sudo tee --append root/etc/fstab

    echo "Flashing U-Boot..."
    sudo dd if=root/boot/u-boot.bin of=${LOOP} conv=fsync,notrunc bs=512 seek=1
    sync
}
