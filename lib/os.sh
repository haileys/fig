archlinux?() {
    grep -q ID=arch /etc/os-release
}

debian?() {
    grep -q ID=debian /etc/os-release
}

if archlinux?; then
    source "$FIG_LIB/os/archlinux.sh"
fi

if debian?; then
    source "$FIG_LIB/os/debian.sh"
fi
