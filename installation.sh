#!/bin/bash

## 1.1 - variables

SUCCESS="\033[0;32m[+]\033[0m"
FAILURE="\033[0;31m[-]\033[0m"
LOADING="\033[0;34m[ ]\033[0m"

required_packages=('gcc' 'make' 'wget' 'tar')

ssh_packages=($(apt list --installed > /dev/null 2>&1 | grep ssh | cut -d/ -f1))
 
ssh_keys_bkp="/tmp/ssh-keys-bkp"

# OpenSSL related variables

openssl_tarrball='https://github.com/openssl/openssl/releases/download/openssl-3.5.1/openssl-3.5.1.tar.gz'
openssl_checksum='529043b15cffa5f36077a4d0af83f3de399807181d607441d734196d889b641f'
openssl_tarball_path='/opt/openssl-3.5.1.tar.gz'
openssl_path='/opt/openssl-3.5.1'

# OpenSSH related variables

openssh_tarball='https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-10.0p2.tar.gz'
openssh_checksum='AhoucJoO30JQsSVr1anlAEEakN3avqgw7VnO+Q652Fw='
openssh_tarball_path='/opt/openssh-10.0p2.tar.gz'
openssh_path='/opt/openssh-10.0p2'

## 1.2 - required packages

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

# downloading

echo -e "$LOADING Downloading OpenSSL 3.5.1 . . . "
if ! sudo wget -P '/opt' $openssl_tarrball > /dev/null 2>&1; then
    echo -e "$FAILURE Download Failed"
    exit 1
else
    if [ "$(sha256sum $openssl_tarball_path | awk '{print $1}')" = "$openssl_checksum" ]; then
        echo -e "$SUCCESS Checksums Match"
    else
        echo -e "$FAILURE Checksums don't match! (possible mitigation attack)"
        exit 1
    fi
    echo -e "$SUCCESS OpenSSL 3.5.1 Downloaded successfully"
fi

# extraction

echo -e "$LOADING Extracting OpenSSL files . . . "

sudo mkdir $openssl_path  > /dev/null 2>&1

if ! sudo tar -xvf $openssl_tarball_path -C $openssl_path --strip-components=1 > /dev/null 2>&1; then
    echo -e "$FAILURE Extraction Failed"
    exit 1
else
    echo -e "$SUCCESS Extraction succeded"

    sudo rm -r $openssl_tarball_path  > /dev/null 2>&1
    echo -e "$SUCCESS OpenSSL tarball successfully removed"
fi

# configuring and building

echo -e "$LOADING Building OpenSSL 3.5.1 . . . "

sudo mkdir /opt/openssl > /dev/null 2>&1

if ! (cd $openssl_path && sudo "./Configure" -fPIC --prefix="/opt/openssl" --openssldir="/etc/ssl/openssl-3.5.1" no-shared > /dev/null 2>&1); then
    echo -e "$FAILURE Configuration Failed"
    exit 1
else
    echo -e "$SUCCESS Configuration succeded"
    echo -e "$LOADING Building Configurations . . ."

    if ! sudo make -C $openssl_path -j"$(nproc)" > /dev/null 2>&1; then
        echo -e "$FAILURE Build Failed"
        exit 1
    else
        echo -e "$SUCCESS Build succeded"
        if ! sudo make -C $openssl_path install > /dev/null 2>&1; then
            echo -e "$FAILURE Installation Failed"
        else
            echo -e "$SUCCESS OpenSSL 3.5.1 was installed successfully"
        fi
    fi
fi

## 1.4 Save current SSH keys and config with .bak

echo -e "$LOADING Backing up current SSH keys"

sudo mkdir $ssh_keys_bkp

for pub_key in /etc/ssh/*.pub; do
    key="${pub_key%.pub}"
    sudo cp "$key" "$key.pub" $ssh_keys_bkp
    echo -e "$SUCCESS $key Pair was saved to $ssh_keys_bkp"
done

sudo cp /etc/ssh/sshd_config $ssh_keys_bkp/sshd_config.bak

## 1.5 Completley remove current SSH

for pkg in "${ssh_packages[@]}"; do
    echo -e "$LOADING Removing $pkg"
    sudo apt purge -y $pkg > /dev/null 2>&1
    echo -e "$SUCCESS $pkg Has been successfully removed"
done
sudo rm -r /etc/ssh  > /dev/null 2>&1
sudo rm -r /lib/systemd/system/sshd-keygen@.service.d  > /dev/null 2>&1

## 1.6 OpenSSH Installation

# downloading

echo -e "$LOADING Downloading OpenSSH 10.0p2 . . . "
if ! sudo wget -P '/opt' $openssh_tarball > /dev/null 2>&1; then
    echo -e "$FAILURE Download Failed"
    exit 1
else
    if [ "$(sha256sum $openssh_tarball_path | awk '{print $1}' | xxd -r -p | base64)" = "$openssh_checksum" ]; then
        echo -e "$SUCCESS Checksums Match"
    else
        echo -e "$FAILURE Checksums don't match! (possible mitigation attack)"
        exit 1
    fi
    echo -e "$SUCCESS OpenSSH 10.0p2 Downloaded successfully"
fi

# extraction

echo -e "$LOADING Extracting OpenSSH files . . . "

sudo mkdir $openssh_path  > /dev/null 2>&1

if ! sudo tar -xvf $openssh_tarball_path -C $openssh_path --strip-components=1 > /dev/null 2>&1; then
    echo -e "$FAILURE Extraction Failed"
    exit 1
else
    echo -e "$SUCCESS Extraction succeded"
    sudo rm -r $openssh_tarball_path  > /dev/null 2>&1
    echo -e "$SUCCESS OpenSSH tarball successfully removed"
fi

# configuring and building

echo -e "$LOADING Building OpenSSH 10.0 patch 2 . . . "
if ! (cd $openssh_path && \
        sudo "./configure" \
        --with-ssl-dir="/opt/openssl" \
        --bindir="/bin" \
        --sbindir="/sbin" \
        --sysconfdir="/etc/ssh" \
        --with-pid-dir="/run" \
        --with-linux-memlock-onfault \
        --without-zlib \
        > /dev/null 2>&1); then
    echo -e "$FAILURE Configuration Failed"
    exit 1
else
    echo -e "$SUCCESS Configuration succeded"
    echo -e "$LOADING Building Configurations . . ."

    if ! sudo make -C $openssh_path -j"$(nproc)" > /dev/null 2>&1; then
        echo -e "$FAILURE Build Failed"
        exit 1
    else
        echo -e "$SUCCESS Build succeded"
        if ! sudo make -C $openssh_path install > /dev/null 2>&1; then
            echo -e "$FAILURE Installation Failed"
            exit 1
        else
            echo -e "$SUCCESS OpenSSH 10.0p2 was installed successfully"
        fi
    fi
fi

## 1.7 - migrate SSH keys to config path

#removal

for pub_key in /etc/ssh/*.pub; do
    key="${pub_key%.pub}"
    sudo rm "$pub_key"
    sudo rm "$key"
done
sudo rm /etc/ssh/sshd_config

# copying

for pub_key in $ssh_keys_bkp/*.pub; do
    key="${pub_key%.pub}"
    sudo mv "$pub_key" "$key" "/etc/ssh" > /dev/null
done

sudo cp $ssh_keys_bkp/sshd_config.bak /etc/ssh

sudo rm -r $ssh_keys_bkp

## 1.8 - Final steps

echo -e "$LOADING Disabling Systemd ssh.socket"
sudo systemctl disable ssh.socket > /dev/null 2>&1
echo -e "$LOADING Stopping Systemd ssh.socket"
sudo systemctl stop ssh.socket > /dev/null 2>&1
echo -e "$LOADING Enabling SSH service"
sudo systemctl enable ssh > /dev/null 2>&1
echo -e "$LOADING Restarting Systemd SSH service"
sudo systemctl restart ssh > /dev/null 2>&1
echo -e "$SUCCESS Installation completed SSH 10.0 patch 2 was installed successfully"