# utility functions

sha256-match() {
    local filename="$1"
    local sha256="$2"

    echo "$sha256  $filename" | sha256sum -c >/dev/null
}

check-commands() {
    local err=

    while [ "$#" -gt 0 ]; do
        if ! command -v "$1" >/dev/null; then
            error "command not found in PATH: $1"
            err=1
        fi

        shift
    done

    [ -z "$err" ] || exit 1
}

xargs-function() {
    local line args=()

    while read -r line; do
        args+=("$line")
    done

    "$@" "${args[@]}"
}
