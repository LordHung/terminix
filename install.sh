#!/usr/bin/env sh

if [ -z  "$1" ]; then
    export PREFIX=/usr
else
    export PREFIX=$1
fi

if [ "$PREFIX" = "/usr" ] && [ "$(id -u)" != "0" ]; then
    # Make sure only root can run our script
    echo "This script must be run as root" 1>&2
    exit 1
fi

if [ ! -f terminix ]; then
    echo "The terminix executable does not exist, please run 'dub build --build=release' before using this script"
    exit 1
fi

# Check availability of required commands
COMMANDS="install glib-compile-schemas glib-compile-resources msgfmt desktop-file-validate xdg-desktop-menu gtk-update-icon-cache"
PACKAGES="coreutils glib2 glib2 gettext desktop-file-utils xdg-utils gtk-update-icon-cache"
i=0
for COMMAND in $COMMANDS; do
    type $COMMAND >/dev/null 2>&1 || {
        j=0
        for PACKAGE in $PACKAGES; do
            if [ $i = $j ]; then
                break
            fi
            j=$(( $j + 1 ))
        done
        echo "Your system is missing command $COMMAND, please install $PACKAGE"
        exit 1
    }
    i=$(( $i + 1 ))
done

echo "Installing to prefix ${PREFIX}"

# Copy and compile schema
echo "Copying and compiling schema..."
install -d ${PREFIX}/share/glib-2.0/schemas
install -m 644 data/gsettings/com.gexperts.Terminix.gschema.xml ${PREFIX}/share/glib-2.0/schemas/
glib-compile-schemas ${PREFIX}/share/glib-2.0/schemas/

export TERMINIX_SHARE=${PREFIX}/share/terminix

install -d ${TERMINIX_SHARE}/resources ${TERMINIX_SHARE}/schemes ${TERMINIX_SHARE}/scripts

# Copy and compile icons
cd data/resources

echo "Building and copy resources..."
glib-compile-resources terminix.gresource.xml
install -m 644 terminix.gresource ${TERMINIX_SHARE}/resources/

cd ../..

# Copy shell integration script
echo "Copying scripts..."
install -m 755 data/scripts/* ${TERMINIX_SHARE}/scripts/

# Copy color schemes
echo "Copying color schemes..."
install -m 644 data/schemes/* ${TERMINIX_SHARE}/schemes/

# Create/Update LINGUAS file
find po -name "*\.po" -printf "%f\\n" | sed "s/\.po//g" | sort > po/LINGUAS

# Compile po files
echo "Copying and installing localization files"
for f in po/*.po; do
    echo "Processing $f"
    LOCALE=$(basename "$f" .po)
    msgfmt $f -o "${LOCALE}.mo"
    install -d ${PREFIX}/share/locale/${LOCALE}/LC_MESSAGES
    install -m 644 "${LOCALE}.mo" ${PREFIX}/share/locale/${LOCALE}/LC_MESSAGES/terminix.mo
    rm -f "${LOCALE}.mo"
done

# Generate desktop file
msgfmt --desktop --template=data/pkg/desktop/com.gexperts.Terminix.desktop.in -d po -o data/pkg/desktop/com.gexperts.Terminix.desktop
if [ $? -ne 0 ]; then
    echo "Note that localizating appdata requires a newer version of xgettext, copying instead"
    cp data/pkg/desktop/com.gexperts.Terminix.desktop.in data/pkg/desktop/com.gexperts.Terminix.desktop
fi

desktop-file-validate data/pkg/desktop/com.gexperts.Terminix.desktop

# Generate appdata file, requires xgettext 0.19.7
msgfmt --xml --template=data/appdata/com.gexperts.Terminix.appdata.xml.in -d po -o data/appdata/com.gexperts.Terminix.appdata.xml
if [ $? -ne 0 ]; then
    echo "Note that localizating appdata requires xgettext 0.19.7 or later, copying instead"
    cp data/appdata/com.gexperts.Terminix.appdata.xml.in data/appdata/com.gexperts.Terminix.appdata.xml
fi

# Copying Nautilus extension
echo "Copying Nautilus extension"
install -d ${PREFIX}/share/nautilus-python/extensions/
install -m 644 data/nautilus/open-terminix.py ${PREFIX}/share/nautilus-python/extensions/

# Copy D-Bus service descriptor
install -d ${PREFIX}/share/dbus-1/services
install -m 644 data/dbus/com.gexperts.Terminix.service ${PREFIX}/share/dbus-1/services/

# Copy man page
install -d ${PREFIX}/share/man/man1
install -m 644 data/man/terminix ${PREFIX}/share/man/man1/terminix.1
gzip -f /usr/share/man/man1/terminix.1

# Copy Icons
cd data/icons/hicolor

find -type f | while read f; do
    install -d "${PREFIX}/share/icons/hicolor/$(dirname "$f")"
    install -m 644 "$f" "${PREFIX}/share/icons/hicolor/${f}"
done

cd ../../..

# Copy executable, desktop and appdata file
install -d ${PREFIX}/bin
install -m 755 terminix ${PREFIX}/bin/

install -d ${PREFIX}/share/applications ${PREFIX}/share/metainfo/
install -m 644 data/pkg/desktop/com.gexperts.Terminix.desktop ${PREFIX}/share/applications/
install -m 644 data/appdata/com.gexperts.Terminix.appdata.xml ${PREFIX}/share/metainfo/

# Update icon cache if Prefix is /usr
if [ "$PREFIX" = '/usr' ] || [ "$PREFIX" = "/usr/local" ]; then
    echo "Updating desktop file cache"
    xdg-desktop-menu forceupdate --mode system

    echo "Updating icon cache"
    gtk-update-icon-cache -f ${PREFIX}/share/icons/hicolor/
fi
