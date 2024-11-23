ensure-packages() {
    if (( "$#" > 0 )); then
        DEBIAN_FRONTEND=noninteractive apt install --no-install-recommends -y "$@"
    fi
}

ensure-keyring() {
    local keyring="$1"
    local pubkey="$2"

    gpg --no-default-keyring \
        --keyring "$keyring" \
        --import "$pubkey"
}

refresh-packages() {
    apt update
}
