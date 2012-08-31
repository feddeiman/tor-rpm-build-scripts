#!/bin/bash

#####
#
# Script creates directory structure with RPM metadata in suitable form for yum.
#
# arg1 - source directory with built RPM files
# arg2 - target directory where repodata and dir structure with RPMs should be created
#

if [ -z "$2" ]; then
    echo "$0 source_dir dest_dir"
    exit 1
fi

SRC="$1"
DEST="$2"

mkdir -p "$DEST"

for I in "$SRC"/tor-*.rpm; do
    OS=$(echo "$I"| sed 's/^.*\.\([^\.]*\)\.[^\.]*\.rpm$/\1/')
    ARCH=$(echo "$I"| sed 's/^.*[^\.]*\.\([^\.]*\)\.rpm$/\1/')

    case "$ARCH" in
        src) ARCH_DIR=SRPMS
            ;;
        *) ARCH_DIR="$ARCH"
            ;;
    esac

    case "$OS" in
        rh16) OS_DIR=fc/16
            ;;
        rh17) OS_DIR=fc/17
            ;;
        rh5_*) OS_DIR=el/5
            ;;
        rh6_*) OS_DIR=el/6
            ;;
        *) echo "Unknown OS/distro"; exit 2
    esac
    
    DESTDIR="$DEST/$OS_DIR/$ARCH_DIR"
    mkdir -p "$DESTDIR"
    echo Processing $I == OS: $OS, ARCH: $ARCH, DIR: $DESTDIR
    cp -a "$I" "$DESTDIR"

    if [ "$ARCH_DIR" = "i686" ]; then
        #$basearch in yum.repo file will be i386, so symlink i386->i686
        LINKNAME="$DESTDIR/../i386"
        if [ '!' -e "$LINKNAME" ]; then
            ln -s i686 "$LINKNAME"
        fi
    fi
done

for REPO in "$DEST"/*/*/{i386,i686,x86_64,SRPMS}; do 
    #EL5 needs to get older hash for checksums specified
    CREATEREPO_ARGS=""
    if [ $(echo "$REPO" | grep -c "el/5") -gt 0 ]; then 
        echo " - Using sha checksum for repo $REPO"
        CREATEREPO_ARGS="-s sha"
    fi

    echo "Metadata for $REPO"
    createrepo $CREATEREPO_ARGS "$REPO"
done
