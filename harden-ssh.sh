#!/bin/bash

required_packages=('gcc' 'make' 'wget' 'tar')

ssh_packages=($(apt list --installed > /dev/null 2>&1 | grep ssh | cut -d/ -f1))
 
ssh_keys_bkp="/tmp/ssh-keys-bkp"

source "config.conf"

# OpenSSL related variables

openssl_version="$(echo "$OPENSSL_TARBALL_URL" | grep -oP 'openssl-\K[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
openssl_tarball_path="/opt/openssl-${openssl_version}.tar.gz"
openssl_path="/opt/openssl-${openssl_version}"

# OpenSSH related variables

openssh_tarball='https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-10.0p2.tar.gz'
openssh_checksum='AhoucJoO30JQsSVr1anlAEEakN3avqgw7VnO+Q652Fw='
openssh_version="$(echo "$openssh_tarball" | grep -oP 'openssh-\K[0-9]+\.[0-9]+p[0-9]+')"
openssh_tarball_path="/opt/openssh-${openssh_version}.tar.gz"
openssh_path="/opt/openssh-${openssh_version}"

LOG_FILE="/home/danil/scripts/SSH-Hardening-Automation-Script/log"

# description: cleans up all the remained files from the system
# return: nothing
function cleanup(){
    #openssl
    sudo rm -r $openssl_tarball_path &>/dev/null
    write_log 1 "$openssl_tarball_path successfully removed"
    sudo rm -r '/opt/openssl' &>/dev/null
    write_log 1 "/opt/openssl successfully removed"
    sudo rm -r $openssl_path &>/dev/null
    write_log 1 "$openssl_path successfully removed"
}

# description: saves logs
# arguments:
#   $1 - code
#   $2 - desc
# return: nothing
function write_log(){
    local code="$1"
    local desc="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ${desc}" >> "$LOG_FILE"
    
    #verbosity
    local prefix=""
    case "$code" in
        1)
            prefix="\033[0;32m[ + ]\033[0m" # success
        ;;
        2)
            prefix="\033[0;31m[ - ]\033[0m" # fail
        ;;
        3)
            prefix="\033[0;34m[ o ]\033[0m" # wait
        ;;
    esac
    echo -e "${prefix} ${desc}"
}

# description: checks for privilleges
# return: exit code (nothing for success, non-zero for failure)
function privileges(){
    write_log 3 "Checking privileges"
    current_user="$(whoami)"
    if [ "$current_user" != "root" ]; then
        write_log 2 "Current user is not root"
        if ! command -v sudo &>/dev/null; then
            write_log 2 "Sudo is not installed"
            echo -e "\033[0;31mRUN THE SCRIPT AS A PRIVILEGED USER\033[0m"
        exit 1
        else
            write_log 1 "Sudo package is installed"
            fi
    else
        write_log 1 "Current User is root"
        if ! command -v sudo &>/dev/null; then
            write_log 2 "Sudo is not installed"
            write_log 3 "Installing sudo package"
            if ! apt install -y sudo &>/dev/null; then
                write_log 2 "Failed to install sudo"
                exit 1
            else
                write_log 1 "sudo installed successfully"
            fi
        else
            write_log 1 "Sudo package is already installed"
        fi
    fi
}

# description: scans for required packages
# return: exit code (nothing for success, non-zero for failure)
function packages(){
    write_log 3 "Installing packages"
    for pkg in "${required_packages[@]}"; do
        if command -v "$pkg" &>/dev/null; then
            write_log 1 "${pkg} is Installed"
        else
            write_log 2 "${pkg} is Missing"
            write_log 3 "Installing ${pkg}"
            if ! sudo apt install -y "$pkg" &>/dev/null; then
                write_log 2 "Failed to install ${pkg}"
                exit 1
            else
                write_log 1 "${pkg} installed successfully"
            fi
        fi
    done
}

# description: fetching, extraction, configuring and building OpenSSL 
# return: exit code (nothing for success, non-zero for failure)
function openssl_build(){
    write_log 3 "Downloading OpenSSL ${openssl_version}"
    if ! sudo wget -P '/opt' $OPENSSL_TARBALL_URL &>/dev/null; then
        write_log 2 "Download Failed"
        exit 1
    else
        if [ "$(sha256sum "$openssl_tarball_path" | awk '{print $1}')" = "$OPENSSL_CHECKSUM" ]; then
            write_log 1 "Checksums Match"
        else
            write_log 2 "Checksums don't match! (possible mitigation attack)"
            exit 1
        fi
        write_log 1 "OpenSSL ${openssl_version} Downloaded and verified successfully"
    fi

    write_log 3 "Creating extraction path"
    if ! sudo mkdir $openssl_path  &>/dev/null; then
        write_log 2 "Failed to create ${$openssl_path}"
        exit 1
    else
        write_log 1 "${$openssl_path} created"
    fi

    write_log 3 "Extracting OpenSSL files"
    if ! sudo tar -xvf $openssl_tarball_path -C $openssl_path --strip-components=1 &>/dev/null; then
        write_log 2 "Extraction Failed"
        exit 1
    else
        write_log 1 "Extraction succeded"
    fi

    write_log 3 "Creating /opt/openssl"
    if ! sudo mkdir /opt/openssl &>/dev/null; then
        write_log 2 "Failed to create /opt/openssl"
        exit 1
    else
        write_log 1 "/opt/openssl created"
    fi

    write_log 3 "Building OpenSSL ${openssl_version}"
    if ! (cd $openssl_path && sudo "./Configure" -fPIC --prefix="/opt/openssl" --openssldir="/etc/ssl/openssl-${openssl_version}" no-shared &>/dev/null); then
        write_log 2 "Configuration Failed"
        exit 1
    else
        write_log 1 "Configuration succeded"
        write_log 3 "Building Configurations"
        if ! sudo make -C $openssl_path -j"$(nproc)" &>/dev/null; then
            write_log 2 "Build Failed"
            exit 1
        else
            write_log 1 "Build succeded"
            if ! sudo make -C $openssl_path install &>/dev/null; then
                write_log 2 "Installation Failed"
                exit 1
            else
                write_log 1 "OpenSSL ${openssl_version} was installed successfully"
            fi
        fi
    fi
}

#privileges
#packages
#openssl_build