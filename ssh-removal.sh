ssh_packages=($(apt list --installed 2>/dev/null | grep ssh | cut -d/ -f1))

for pkg in "${ssh_packages[@]}"; do
    echo -e "$LOADING Removing $pkg"
    sudo apt purge -y $pkg
    echo -e "$SUCCESS $pkg Has been successfully removed"
done

