#!/bin/bash

BASE_DISTRO=$(grep "^ID_LIKE=" /etc/os-release | cut -d= -f2 | tr -d '"')
PKGMGR=""
PKGMGRTL=""

if [ "$BASE_DISTRO" = "" ]; then
    echo "/etc/os-release was not found, looks like your system does not use systemd"
else
    if [ "$BASE_DISTRO" = "debian" ]; then
        echo "[$(date)]>Debian based distribution detected"
        if [ -x /bin/apt ]; then
            PKGMGR="apt"
            echo "[$(date)]>apt was found"
        fi
        if [ -x /bin/dpkg ]; then
            PKGMGRTL="dpkg"
            echo "[$(date)]>dpkg was found"
        fi
    elif [ "$BASE_DISTRO" = "fedora" ]; then
        echo "[$(date)]>Fedora based distribution detected"
        if [ -x /bin/dnf ]; then
            PKGMGR="dnf"
            echo "[$(date)]>dnf was found"
        fi
        if [ -x /bin/rpm ]; then
            PKGMGRTL="rpm"
            echo "[$(date)]>rpm was found"
        fi
    fi
fi

packages=("wget" "gcc" "tar" "make")

for pkg in "${packages[@]}"; do
    if [ -x "/bin/$pkg" ]; then
        echo "$pkg found under /bin"
    else
        sudo $PKGMGR install $pkg > /dev/null 2>&1
        echo "$pkg" was installed
    fi
done