#!/bin/sh
set -eu
ARCH=$(uname -m)

echo "Installing package dependencies..."
echo "---------------------------------------------------------------"
sudo pacman -Syy --noconfirm archlinux-keyring
#Build
sudo pacman -S --noconfirm --needed git base-devel meson blueprint-compiler
#Needed
sudo pacman -S --noconfirm --needed libadwaita python-gobject libpwquality sqlcipher tcl python-pip python-pycryptodome python-zxcvbn
#Check
sudo pacman -S --noconfirm --needed appstream-glib desktop-file-utils


echo "Installing debloated packages..."
echo "---------------------------------------------------------------"
get-debloated-pkgs --add-common --prefer-nano

echo "Installing masterkey from source packages..."
echo "---------------------------------------------------------------"
git clone https://gitlab.com/guillermop/master-key.git ./master-key
cd ./master-key
meson setup build --prefix=/usr
meson compile -C build
sudo meson install -C build
awk -F":|'" '/version:/{print $3; exit}' ./meson.build > ~/version


# Comment this out if you need an AUR package
#make-aur-package PACKAGENAME

# If the application needs to be manually built that has to be done down here

# if you also have to make nightly releases check for DEVEL_RELEASE = 1
#
# if [ "${DEVEL_RELEASE-}" = 1 ]; then
# 	nightly build steps
# else
# 	regular build steps
# fi
