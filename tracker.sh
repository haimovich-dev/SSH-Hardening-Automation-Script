#!/bin/bash

## 1.1 - variables

## 1.2 - required packages + privilegs

## 1.3 - OpenSSL static installation

## 1.4 Save current SSH keys and config with .bak

## 1.6 OpenSSH Installation

## 1.7 - migrate SSH keys to config path

#removal

# copying

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