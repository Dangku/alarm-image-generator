#!/bin/bash

platform_variables() {
    echo "WAYLAND: set to 1 to install wayland GL libraries instead of fbdev."
    echo "MAINLINE_KERNEL: set to 1 to use mainline kernel."
}

platform_pre_chroot() {
    echo "Platform pre-chroot..."

    if [ "${MAINLINE_KERNEL}x" = "x" ]; then
        alarm_build_package linux-odroid-n2plus
    else
        alarm_build_package dkms-mali-bifrost
    fi

    if [ "${WAYLAND}x" = "x" ]; then
        alarm_build_package odroid-n2-libgl-fb
        alarm_build_package odroid-gl4es
    else
        alarm_build_package odroid-n2-libgl-wl
    fi

    alarm_build_package uboot-odroid-n2plus
}

platform_chroot_setup() {
    echo "Platform chroot-setup..."

    # Kernel
    yes | pacman -R uboot-odroid-n2

    if [ "${MAINLINE_KERNEL}x" != "x" ]; then
        yes | pacman -S --noconfirm linux-aarch64 linux-aarch64-headers

        yes | pacman -S --noconfirm dkms

        # Wireless
        yes | pacman -S --noconfirm dkms-8812au

        # GPU kernel driver
        alarm_install_package dkms-mali-bifrost
    else
        alarm_install_package linux-odroid-n2plus-4.9
        alarm_install_package linux-odroid-n2plus-headers
    fi

    # Updated uboot
    alarm_install_package uboot-odroid-n2plus

    if [ "${WAYLAND}x" = "x" ]; then
        alarm_install_package odroid-n2-libgl-fb
        alarm_install_package odroid-n2-gl4es
    fi

    # Customizations
    if [ "${MAINLINE_KERNEL}x" != "x" ]; then
        echo "Copy boot.ini adapted for mainline kernel..."
        cp /mods/boot/boot.n2.mainline.ini /boot/boot.ini
    else
        echo "Copy boot.ini adapted for n2+..."
        cp /mods/boot/boot.n2plus.hardkernel.ini /boot/boot.ini
    fi
}

platform_chroot_setup_exit() {
    echo "Platform chroot-setup-exit..."
    # Install at last since this causes issues
    if [ "${WAYLAND}x" != "x" ]; then
        alarm_install_package odroid-n2-libgl-wl
    fi
}

platform_post_chroot() {
    echo "Platform post-chroot..."

    echo "Flashing U-Boot..."
    sudo dd if=root/boot/u-boot.bin of=${LOOP} conv=fsync,notrunc bs=512 seek=1
    sync
}
