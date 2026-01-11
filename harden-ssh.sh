#!/bin/bash

VERBOSE=true
BACKUP=true

PARENT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${PARENT_DIR}/config.conf"
LOG_FILE="${PARENT_DIR}/script.log"

source "${CONFIG_FILE}" &>/dev/null

required_packages=('gcc' 'make' 'wget' 'tar')

ssh_packages=($(apt list --installed 2>/dev/null | grep ssh | cut -d/ -f1))

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
    
    if [[ "$VERBOSE" == true ]]; then
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
    fi
}

# description: extract given tarball file
# arguments:
#   $1 - full path to tarball
#   $2 - destination path
# return: exit code (nothing for success, non-zero for failure).
function extract(){
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
    fi
    write_log 1 "Config file used: $CONFIG_FILE"

    local parameters=(
        OPENSSL_TARBALL_URL
        OPENSSL_CHECKSUM
        OPENSSL_INSTALLATION_DIR
        OPENSSH_TARBALL_URL
        OPENSSH_CHECKSUM
        OPENSSH_INSTALLATION_DIR
        OPENSSH_KEYS_BKP_PATH
    )

    for param in "${parameters[@]}"; do
        if [[ -z "${!param-}" ]]; then
            write_log 2 "FATAL: Config variable '$param' is missing or empty"
            exit 1
        fi
    done
    write_log 1 "Config file $CONFIG_FILE validated successfully"
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
    sudo rm -r /etc/ssh &>/dev/null
    sudo rm -r /lib/systemd/system/sshd-keygen@.service.d &>/dev/null
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
        if [ "$(sudo openssl dgst --sha256 "$openssl_tarball_path" | awk '{print $2}')" = "$OPENSSL_CHECKSUM" ]; then
            write_log 1 "Checksums Match"
        else
            write_log 2 "Checksums don't match! (possible mitigation attack)"
            exit 1
        fi
        write_log 1 "OpenSSL ${openssl_version} Downloaded and verified successfully"
    fi

    extract $openssl_tarball_path $openssl_path

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

# description: a function that is responsible for backing up current SSH keys and sshd_config file
# return: exit code (nothing for success, non-zero for failure)
function backup_env(){
    write_log 3 "Backing up current SSH keys"

    if ! sudo mkdir $OPENSSH_KEYS_BKP_PATH  &>/dev/null; then
        write_log 2 "Failed to create ${dst_path}"
        exit 1
    fi

    for pub_key in /etc/ssh/*.pub; do
        local key="${pub_key%.pub}"
        if ! sudo cp "$key" "$key.pub" $OPENSSH_KEYS_BKP_PATH; then
            write_log 3 "$key and "$key.pub" could not be backedup"
            exit 1
        else
            write_log 1 "$key and "$key.pub" was saved to $OPENSSH_KEYS_BKP_PATH"
        fi
    done

    if ! sudo cp /etc/ssh/sshd_config $OPENSSH_KEYS_BKP_PATH/sshd_config.bak; then
        write_log 3 "could not copy /etc/ssh/sshd_config into ${OPENSSH_KEYS_BKP_PATH}"
        exit 1
    else
        write_log 1 "sshd_config was successfully copied into ${OPENSSH_KEYS_BKP_PATH}"
    fi
}

# description: OpenSSH fetching, extraction, configuring and building, 
#              backing up keys, removing previous installations, migrating keys
#              sshd user creation.
# return: exit code (nothing for success, non-zero for failure)
function openssh_deployment(){
    if [[ "$BACKUP" == true ]]; then
        backup_env
    fi

    local current_version="$(ssh -V 2>&1)"
    write_log 3 "Removing current SSH dependencies OpenSSH_${current_version}"
    for pkg in "${ssh_packages[@]}"; do
        write_log 3 "Removing ${pkg}"
        if ! sudo apt purge -y $pkg &>/dev/null; then
            write_log 2 "Unable to remove ${pkg}"
        else
            write_log 1 "$pkg Has been successfully removed"
        fi
    done

    write_log 3 "Removing current SSH environment"
    if ! sudo rm -rf /etc/ssh/*;then
        write_log 2 "unable to remove current SSH environment"
    else
        write_log 1 "SSH environment was removed"
    fi

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
    
    extract $openssh_tarball_path $openssh_path

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
            --with-ssl-dir="${OPENSSL_INSTALLATION_DIR}" \
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

    if ! sudo cat /etc/passwd | grep sshd &>/dev/null; then
        write_log 2 "User sshd does not exist"

        write_log 3 "Trying to create sshd user"
        if ! sudo useradd sshd --gid 65534 -b /run --shell /usr/sbin/nologin &>/dev/null; then
            write_log 2 "Wasn't able to create user sshd"
            exit 1
        else
            write_log 1 "User sshd was created successfully"
        fi
    else
        write_log 1 "User sshd exists"
    fi

    if [[ "$BACKUP" == true ]]; then
        for pub_key in $OPENSSH_KEYS_BKP_PATH/*.pub; do
        local key="${pub_key%.pub}"
            if ! sudo mv "$pub_key" "$key" "/etc/ssh" &>/dev/null; then
                write_log 3 "$key and "$key.pub" could not be move to /etc/ssh"
            else
                write_log 1 "$key and "$key.pub" was move to /etc/ssh"
            fi
        done

        if ! sudo cp $OPENSSH_KEYS_BKP_PATH/sshd_config.bak /etc/ssh; then
            write_log 3 "could not copy ${OPENSSH_KEYS_BKP_PATH}/sshd_config into /etc/ssh"
        else
            write_log 1 "${OPENSSH_KEYS_BKP_PATH}/sshd_config was successfully copied into /etc/ssh"
        fi

        if ! sudo rm -rf $OPENSSH_KEYS_BKP_PATH;then
            write_log 2 "unable to remove ${OPENSSH_KEYS_BKP_PATH}"
        else
            write_log 1 "${OPENSSH_KEYS_BKP_PATH} was removed"
        fi
    fi
}

function services(){
    return 0
}

function main(){
    config_validation
    privileges
    packages
    openssl_deployment
    openssh_deployment
    services
    exit 0
}
main