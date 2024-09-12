ensure-packages() {
    if (( "$#" > 0 )); then
        pacman --sync --noconfirm --needed "$@"
    fi
}

refresh-packages() {
    pacman --sync --refresh
}
