#!/bin/bash

## 1.1 - variables

## 1.2 - required packages + privilegs

## 1.3 - OpenSSL static installation

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

## 1.8 - Checking sshd user existence

if ! sudo cat /etc/passwd | grep sshd > /dev/null 2>&1; then
    echo -e "$FAILURE User sshd does not exist"
    echo -e "$LOADING Trying to create sshd user"

    if ! sudo useradd sshd --gid 65534 -b /run --shell /usr/sbin/nologin > /dev/null 2>&1; then
        echo -e "$FAILURE Wasn't able to create user sshd"
        exit 1
    else
        echo -e "$SUCCESS User sshd was created successfully"
    fi
else
    echo -e "$SUCCESS User sshd exists"
fi

## 1.9 - systemd - service configuration

echo -e "$LOADING Disabling Systemd ssh.socket"
sudo systemctl disable ssh.socket > /dev/null 2>&1
echo -e "$LOADING Stopping Systemd ssh.socket"
sudo systemctl stop ssh.socket > /dev/null 2>&1
echo -e "$LOADING Enabling SSH service"
sudo systemctl enable ssh > /dev/null 2>&1
echo -e "$LOADING Restarting Systemd SSH service"
sudo systemctl restart ssh > /dev/null 2>&1
echo -e "$SUCCESS Installation completed SSH 10.0 patch 2 was installed successfully"