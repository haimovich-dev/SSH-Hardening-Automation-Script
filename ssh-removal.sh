#!/bin/bash

SUCCESS="\033[0;32m[+]\033[0m"
FAILURE="\033[0;31m[-]\033[0m"
LOADING="\033[0;34m[ ]\033[0m"

ssh_packages=($(apt list --installed 2>/dev/null | grep ssh | cut -d/ -f1))

for pkg in "${ssh_packages[@]}"; do
    echo -e "$LOADING Removing $pkg"
    sudo apt purge -y $pkg > /dev/null 2>&1
    echo -e "$SUCCESS $pkg Has been successfully removed"
done

