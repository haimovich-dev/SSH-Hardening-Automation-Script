#!/bin/bash

is_gcc=false
is_make=false
is_wget=false
is_tar=false

echo "checking packet manager"
if apt --version > /dev/null 2>&1;
then echo -e "\033[32m[V]\033[0m > apt was found";
else echo -e "\033[31m[X]\033[0m WITHOUT APT THIS SCRIPT WON'T BE ABLE TO RUN \033[31m[X]\033[0m" && exit 1;
fi

required_packages=('gcc' 'wget' 'tar' 'make')

echo "scanning required packages (gcc,wget,tar,make)"
for pkg in "${required_packages[@]}"; do
    if $pkg --version > /dev/null 2>&1;
    then
        echo -e "\033[32m[V]\033[0m > $pkg was found";
        declare "is_$pkg=true"
    else
        echo -e "\033[31m[X]\033[0m > $pkg was not found";
        echo -e "\033[34m[O]\033[0m > Installing $pkg ...";
        sudo apt install -y $pkg > /dev/null 2>&1;
        exit_code=$?;
        if [ $exit_code -eq 0 ]; then
            echo -e "\033[32m[V]\033[0m > $pkg Installed";
        else
            echo "Installation failed with error code: $exit_code";
        fi
    fi
done

optional_packages=('openssl' 'libedit' 'libpam0g' 'ldns' 'zlib' 'libfido2')

echo "scanning optional packages (openssl,libedit,libpam0g(PAM),ldns,zlib,libfido2)"
for opt_pkg in "${optional_packages[@]}"; do
    full_ver=$(dpkg -l | grep "^ii  $opt_pkg" | awk '{print $3}')
    
    if [ -n "$full_ver" ]; then
        short_ver=$(echo "$full_ver" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1)
        echo -e "\033[32m[V]\033[0m > $opt_pkg $short_ver"
    else
        echo -e "\033[31m[X]\033[0m > $opt_pkg Not Found"
    fi
done