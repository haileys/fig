ensure-packages() {
    local packages=()
    local packages_confold=()

    while (( $# > 0 )); do
        local package confold=
        :ensure-packages-parse-package-with-option "$1"
        shift

        if [[ -z "$confold" ]]; then
            packages+=("$package")
        else
            packages_confold+=("$package")
        fi
    done

    :apt-install "${packages[@]}"
    :apt-install -o Dpkg::Options::="--force-confold" "${packages_confold[@]}"
}

:apt-install() {
    (( "$#" == 0 )) || \
        DEBIAN_FRONTEND=noninteractive apt install --no-install-recommends -y "$@"
}

:ensure-packages-parse-package-with-option() {
    if [[ "$1" =~ ^([^\[]+)(\[(.*)\])?$ ]]; then
        package="${BASH_REMATCH[1]}"

        # read options, split by ,
        local options=()
        IFS=, read -ra options <<< "${BASH_REMATCH[3]}"

        :ensure-packages-parse-options "${options[@]}"
    else
        package="$1"
    fi
}

:ensure-packages-parse-options() {
    while (( $# > 0 )); do
        case "$1" in
        force-confold)
            confold=1
            ;;
        *)
            die "unknown package option: $1"
            ;;
        esac

        shift
    done
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
