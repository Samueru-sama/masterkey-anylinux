#!/bin/sh
set -eu

# Setup
VERSION=$(grep -m 1 "version:" source/meson.build | cut -d"'" -f2)
export VERSION
export ARCH=$(uname -m)
export OUTPATH=./dist
export ADD_HOOKS="self-updater.hook"
export UPINFO="gh-releases-zsync|${GITHUB_REPOSITORY%/*}|${GITHUB_REPOSITORY#*/}|latest|*$ARCH.AppImage.zsync"
export ICON=/usr/share/icons/hicolor/scalable/apps/com.gitlab.guillermop.MasterKey.svg
export DESKTOP=/usr/share/applications/com.gitlab.guillermop.MasterKey.desktop

PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
LIB_DIR="AppDir/usr/lib"
SITE_PACKAGES="$LIB_DIR/python$PY_VER/site-packages"
SCHEMA_DIR="AppDir/usr/share/glib-2.0/schemas"
DATA_DIR="AppDir/usr/share/master-key"

sudo glib-compile-schemas /usr/share/glib-2.0/schemas/

# Deploy dependencies
quick-sharun /usr/bin/master-key

# Additional changes can be done in between here
mkdir -p "$SITE_PACKAGES" "$LIB_DIR" "$SCHEMA_DIR" "$DATA_DIR"

if [ -d "/usr/share/master-key" ]; then
    cp -r /usr/share/master-key/* "$DATA_DIR/"
fi

cp /usr/share/glib-2.0/schemas/com.gitlab.guillermop.MasterKey.gschema.xml "$SCHEMA_DIR/" 2>/dev/null || true
glib-compile-schemas "$SCHEMA_DIR/"

pip install --target="$SITE_PACKAGES" pycryptodome zxcvbn

DEPS="libpwquality.so.1 libsqlcipher.so.0 libtcl8.6.so"
for LIB in $DEPS; do
    FILES=$(find /usr/lib -name "$LIB*" 2>/dev/null)
    for FILE in $FILES; do
        if [ -f "$FILE" ]; then
            cp -L "$FILE" "$LIB_DIR/"
            BASE=$(basename "$FILE")
            # Create a symlink to the base library name if it includes a version suffix
            NAME_ONLY=$(echo "$LIB" | cut -d. -f1-2)
            if [ "$BASE" != "$NAME_ONLY" ]; then
                ln -sf "$BASE" "$LIB_DIR/$NAME_ONLY"
            fi
        fi
    done
done

mv AppDir/bin/master-key AppDir/bin/master-key.real

sed -i "s|pkgdatadir = .*|import os; pkgdatadir = os.path.join(os.environ.get('APPDIR', '/'), 'usr/share/master-key')|g" AppDir/bin/master-key.real
sed -i "s|localedir = .*|localedir = os.path.join(os.environ.get('APPDIR', '/'), 'usr/share/locale')|g" AppDir/bin/master-key.real

cat << 'EOF' > AppDir/bin/master-key
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
export APPDIR="${HERE%/*}"
PY_VER=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')

export LD_LIBRARY_PATH="$APPDIR/usr/lib:$LD_LIBRARY_PATH"
export PYTHONPATH="$APPDIR/usr/lib/python$PY_VER/site-packages:$PYTHONPATH"
export GSETTINGS_SCHEMA_DIR="$APPDIR/usr/share/glib-2.0/schemas"

exec python3 "$HERE/master-key.real" "$@"
EOF

chmod +x AppDir/bin/master-key

# Turn AppDir into AppImage
quick-sharun --make-appimage

# Test the app for 12 seconds, if the test fails due to the app
# having issues running in the CI use --simple-test instead
quick-sharun --test ./dist/*.AppImage
