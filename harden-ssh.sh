#!/bin/bash

PARENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${PARENT_DIR}/config.conf"
LOG_FILE="${PARENT_DIR}/script.log"

source "${CONFIG_FILE}" &>/dev/null

required_packages=('gcc' 'make' 'wget' 'tar')

ssh_packages=($(apt list --installed > /dev/null 2>&1 | grep ssh | cut -d/ -f1))

# OpenSSL related variables

openssl_version="$(echo "$OPENSSL_TARBALL_URL" | grep -oP 'openssl-\K[0-9]+\.[0-9]+\.[0-9]+' | head -n1)"
openssl_tarball_path="/opt/openssl-${openssl_version}.tar.gz"
openssl_path="/opt/openssl-${openssl_version}"

# OpenSSH related variables

openssh_version="$(echo "$OPENSSH_TARBALL_URL" | grep -oP 'openssh-\K[0-9]+\.[0-9]+p[0-9]+')"
openssh_tarball_path="/opt/openssh-${openssh_version}.tar.gz"
openssh_path="/opt/openssh-${openssh_version}"

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

# description: extract given tarball file
# arguments:
#   $1 - full path to tarball
#   $2 - destination path
# return: exit code (nothing for success, non-zero for failure).
function exract(){
    local tarball="$1"
    local dst_path="$2"

    write_log 3 "Creating extraction path ${dst_path}"
    if ! sudo mkdir $dst_path  &>/dev/null; then
        write_log 2 "Failed to create ${dst_path}"
        exit 1
    fi

    write_log 1 "${dst_path} created"

    write_log 3 "Extracting OpenSSL files to ${dst_path}"
    if ! sudo tar -xvf $tarball -C $dst_path --strip-components=1 &>/dev/null; then
        write_log 2 "FAILED: ${tarball} extraction failed"
        exit 1
    fi
    write_log 1 "${tarball} extracted to ${dst_path}"
}

# description: valifates config file existence and key/value pairs
# return: exit code (nothing for success, non-zero for failure)
function config_validation(){
    if [[ ! -f "$CONFIG_FILE" ]]; then
        write_log 2 "FATAL: Config file not found: $CONFIG_FILE"
        exit 1
    else
        write_log 1 "Config file used: $CONFIG_FILE"
    fi
}

# description: cleans up all the remained files from the system
# return: nothing
function cleanup(){
    
    #openssl
    sudo rm -r $openssl_tarball_path &>/dev/null
    write_log 1 "$openssl_tarball_path successfully removed"
    sudo rm -r "${OPENSSL_INSTALLATION_DIR}" &>/dev/null
    write_log 1 "${OPENSSL_INSTALLATION_DIR} successfully removed"
    sudo rm -r $openssl_path &>/dev/null
    write_log 1 "$openssl_path successfully removed"
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

# description: OpenSSL fetching, extraction, configuring and building
# return: exit code (nothing for success, non-zero for failure)
function openssl_deployment(){
    write_log 3 "Downloading OpenSSL ${openssl_version}"
    if ! sudo wget -P '/opt' $OPENSSL_TARBALL_URL &>/dev/null; then
        write_log 2 "Download Failed"
        exit 1
    else
        if [ "$(sudo openssl dgst --sha256 | awk '{print $2}')" = "$OPENSSL_CHECKSUM" ]; then
            write_log 1 "Checksums Match"
        else
            write_log 2 "Checksums don't match! (possible mitigation attack)"
            exit 1
        fi
        write_log 1 "OpenSSL ${openssl_version} Downloaded and verified successfully"
    fi

    exract $openssl_tarball_path $openssl_path

    write_log 3 "Creating ${OPENSSL_INSTALLATION_DIR}"
    if ! sudo mkdir "${OPENSSL_INSTALLATION_DIR}" &>/dev/null; then
        write_log 2 "Failed to create ${OPENSSL_INSTALLATION_DIR}"
        exit 1
    else
        write_log 1 "${OPENSSL_INSTALLATION_DIR} created"
    fi

    write_log 3 "Building OpenSSL ${openssl_version}"
    if ! (cd $openssl_path && sudo "./Configure" -fPIC --prefix="${OPENSSL_INSTALLATION_DIR}" --openssldir="/etc/ssl/openssl-${openssl_version}" no-shared &>/dev/null); then
        write_log 2 "OpenSSL ${openssl_version} configuration Failed"
        exit 1
    else
        write_log 1 "OpenSSL ${openssl_version} configuration succeded"
        write_log 3 "Building OpenSSL ${openssl_version}"
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

# description: OpenSSH fetching, extraction, configuring and building, 
#              backing up keys, removing previous installations, migrating keys
#              sshd user creation.
# return: exit code (nothing for success, non-zero for failure)
function openssh_deployment(){
    local current_version=$(ssh -V)
    write_log 3 "Removing current SSH installation ${current_version}"
    for pkg in "${ssh_packages[@]}"; do
        write_log 3 "Removing ${pkg}"
        sudo apt purge -y $pkg &>/dev/null
        echo -e "$SUCCESS $pkg Has been successfully removed"
    done
    sudo rm -r /etc/ssh  > /dev/null 2>&1
    sudo rm -r /lib/systemd/system/sshd-keygen@.service.d  > /dev/null 2>&1

    write_log 3 "Downloading OpenSSH ${openssh_version} . . . "
    if ! sudo wget -P '/opt' $OPENSSH_TARBALL_URL &>/dev/null; then
        write_log 2 "Download Failed"
        exit 1
    else
        if [ "$(openssl dgst -sha256 -binary "$openssh_tarball_path" | openssl base64)" = "$OPENSSH_CHECKSUM" ]; then
            write_log 1 "Checksums Match"
        else
            write_log 2 "Checksums don't match! (possible mitigation attack)"
            exit 1
        fi
        write_log 1 "OpenSSH ${openssh_version} Downloaded and verified successfully"
    fi
    
    exract $openssh_tarball_path $openssh_path

    write_log 3 "Creating ${OPENSSH_INSTALLATION_DIR}"
    if ! sudo mkdir "${OPENSSH_INSTALLATION_DIR}" &>/dev/null; then
        write_log 2 "Failed to create ${OPENSSH_INSTALLATION_DIR}"
        exit 1
    else
        write_log 1 "${OPENSSH_INSTALLATION_DIR} created"
    fi

    write_log 3 "Building OpenSSH ${openssh_version}"
    if ! (cd $openssh_path && \
            sudo "./configure" \
            --with-ssl-dir="${OPENSSH_INSTALLATION_DIR}" \
            --bindir="/bin" \
            --sbindir="/sbin" \
            --sysconfdir="/etc/ssh" \
            --with-pid-dir="/run" \
            --with-linux-memlock-onfault \
            --without-zlib \
            &>/dev/null); then
        write_log 2 "OpenSSH ${openssh_version} configuration Failed"
        exit 1
    else
        write_log 1 "OpenSSH ${openssh_version} configuration succeded"
        write_log 3 "Building OpenSSH ${openssh_version}"
        if ! sudo make -C $openssh_path -j"$(nproc)" &>/dev/null; then
            write_log 2 "Build Failed"
            exit 1
        else
            write_log 1 "Build succeded"
            if ! sudo make -C $openssh_path install &>/dev/null; then
                write_log 2 "Installation Failed"
                exit 1
            else
                write_log 1 "OpenSSH ${openssh_version} was installed successfully"
            fi
        fi
    fi
}

function main(){
    config_validation
    privileges
    packages
    openssl_deployment
    openssh_deployment
    exit 0
}
main