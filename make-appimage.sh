#!/bin/sh
set -eu

VERSION=$(grep -m 1 "version:" source/meson.build | cut -d"'" -f2)
export VERSION
export ARCH=$(uname -m)
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=/usr/share/icons/hicolor/scalable/apps/com.gitlab.guillermop.MasterKey.svg
export DESKTOP=/usr/share/applications/com.gitlab.guillermop.MasterKey.desktop

PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')

sudo sed -i "s|pkgdatadir = ['\"].*/share/master-key['\"]|pkgdatadir = os.path.join(os.environ.get('APPDIR', '/'), 'usr/share/master-key')|g" /usr/bin/master-key
sudo sed -i "2i import os, sys; sys.path.insert(0, os.path.join(os.environ.get('APPDIR', '/'), 'usr/lib/python$PY_VER/site-packages')); os.environ['GSETTINGS_SCHEMA_DIR'] = os.path.join(os.environ.get('APPDIR', '/'), 'usr/share/glib-2.0/schemas')" /usr/bin/master-key

sudo glib-compile-schemas /usr/share/glib-2.0/schemas/

# Deploy dependencies
quick-sharun /usr/bin/master-key

# Additional changes can be done in between here
SITE_PACKAGES="AppDir/usr/lib/python$PY_VER/site-packages"
mkdir -p "$SITE_PACKAGES"
pip install --target="$SITE_PACKAGES" pycryptodome zxcvbn

mkdir -p AppDir/usr/lib
DEPS="libpwquality.so.1 libsqlcipher.so.0 libtcl8.6.so"
for LIB in $DEPS; do
    FILE=$(find /usr/lib -name "$LIB*" | head -n 1)
    if [ -n "$FILE" ]; then
        cp -L "$FILE" AppDir/usr/lib/
        BASE=$(basename "$FILE")
        if [ "$BASE" != "$LIB" ]; then
            ln -sf "$BASE" "AppDir/usr/lib/$LIB"
        fi
    fi
done

mkdir -p AppDir/usr/share/master-key
if [ -d "/usr/share/master-key" ]; then
    cp -r /usr/share/master-key/* AppDir/usr/share/master-key/
fi

mkdir -p AppDir/usr/share/glib-2.0/schemas/
cp /usr/share/glib-2.0/schemas/gschemas.compiled AppDir/usr/share/glib-2.0/schemas/

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --test ./dist/*.AppImage
