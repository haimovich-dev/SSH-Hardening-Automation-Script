#!/bin/bash

SUCCESS="\033[0;32m[V]\033[0m"
FAILURE="\033[0;31m[X]\033[0m"
LOADING="\033[0;34m[O]\033[0m"

## 1.2 - required packages

required_packages=('gcc' 'make' 'wget' 'tar')

for pkg in "${required_packages[@]}"; do
    #declare ""
    if command -v "$pkg" >/dev/null 2>&1; then
        echo -e "$SUCCESS $pkg is Installed"
    else
        echo -e "$FAILURE $pkg is Missing"
        echo -e "$LOADING Installing $pkg . . . "
        if ! sudo apt install -y "$pkg" > /dev/null 2>&1; then
            echo -e "$FAILURE Failed to install $pkg"
            exit 1
        else
            echo -e "$SUCCESS $pkg installed successfully"
        fi
    fi
done

## 1.3 - OpenSSL static installation

openssl_tarrball='https://github.com/openssl/openssl/releases/download/openssl-3.5.1/openssl-3.5.1.tar.gz'
openssl_checksum='529043b15cffa5f36077a4d0af83f3de399807181d607441d734196d889b641f'

# downloading

echo -e "$LOADING Downloading OpenSSL 3.5.1 . . . "
if ! sudo wget -P '/opt' $openssl_tarrball > /dev/null 2>&1; then
    echo -e "$FAILURE Download Failed"
    exit 1
else
    if [ "$(sha256sum /opt/openssl-3.5.1.tar.gz | awk '{print $1}')" = "$openssl_checksum" ]; then
        echo -e "$SUCCESS Checksums Match"
    else
        echo -e "$FAILURE Checksums don't match! (possible mitigation attack)"
        exit 1
    fi
    echo -e "$SUCCESS OpenSSL 3.5.1 Downloaded successfully"
fi

# extraction

echo -e "$LOADING Extracting OpenSSL files . . . "
if ! sudo tar -xvf /opt/openssl-3.5.1.tar.gz -C /opt > /dev/null 2>&1; then
    echo -e "$FAILURE Extraction Failed"
    exit 1
else
    echo -e "$SUCCESS Extraction succeded"
fi

# configuring and building

echo -e "$LOADING Building OpenSSL 3.5.1 . . . "
if ! (cd "/opt/openssl-3.5.1" && sudo "./Configure" -fPIC --prefix="/opt/openssl" --openssldir="/opt/openssl" no-shared > /dev/null 2>&1); then
    echo -e "$FAILURE Configuration Failed"
else
    echo -e "$SUCCESS Configuration succeded"
    echo -e "$LOADING Building Configurations . . ."

    date
    if ! (cd "/opt/openssl-3.5.1" && sudo make -j"$(nproc)" > /dev/null 2>&1); then
        echo -e "$FAILURE Build Failed"
    else
        date
        echo -e "$SUCCESS Build succeded"
        if ! (cd "/opt/openssl-3.5.1" && sudo make install > /dev/null 2>&1); then
            echo -e "$FAILURE Installation Failed"
        else
            echo -e "$SUCCESS OpenSSL 3.5.1 was installed successfully"
        fi
    fi
fi

# 1.4 Completley remove current SSH

sudo apt purge -y openssh-server openssh-client ssh-import-id openssh-sftp-server libssh4
sudo truncate /home/*/.ssh/authorized_keys --size 0

# 1.5 OpenSSH Installation

openssh_tarball='https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-10.0p2.tar.gz'
openssh_checksum='AhoucJoO30JQsSVr1anlAEEakN3avqgw7VnO+Q652Fw='

# downloading

echo -e "$LOADING Downloading OpenSSH 10.0p2 . . . "
if ! sudo wget -P '/opt' $openssh_tarball > /dev/null 2>&1; then
    echo -e "$FAILURE Download Failed"
    exit 1
else
    if [ "$(sha256sum /opt/openssh-10.0p2.tar.gz | awk '{print $1}' | xxd -r -p | base64)" = "$openssh_checksum" ]; then
        echo -e "$SUCCESS Checksums Match"
    else
        echo -e "$FAILURE Checksums don't match! (possible mitigation attack)"
        exit 1
    fi
    echo -e "$SUCCESS OpenSSH 10.0p2 Downloaded successfully"
fi

# extraction

echo -e "$LOADING Extracting OpenSSH files . . . "
if ! sudo tar -xvf /opt/openssh-10.0p2.tar.gz -C /opt > /dev/null 2>&1; then
    echo -e "$FAILURE Extraction Failed"
    exit 1
else
    echo -e "$SUCCESS Extraction succeded"
fi


