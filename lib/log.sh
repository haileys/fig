use-color?() {
    [ -t 1 ] && [ -z "${NO_COLOR:-}" ]
}

# nerf tput if we shouldn't output colors
use-color? || tput() { true; }

# log functions
log-impl() {
    local color="$1"
    local prefix="$2"
    local message="$3"

    local chroot_prefix=
    if [[ -n "${FIG_CHROOT:-}" ]]; then
        chroot_prefix="$(tput setaf 4)[$FIG_CHROOT] $(tput sgr0)"
    fi

    printf "%s%s%s %s%s%s\n" \
        "$chroot_prefix" \
        "$(tput setaf "$color" bold)" \
        "$prefix" \
        "$(tput sgr0)$(tput setaf 15)" \
        "$message" \
        "$(tput sgr0)" >&2
}

log() {
    log-impl 4 "+++" "$1"
}

success() {
    log-impl 2 ">>>" "$1"
}

warn() {
    log-impl 3 "###" "$1"
}

error() {
    log-impl 1 "!!!" "$1"
}

die() {
    error "$1"
    exit 1
}

handle-error() {
    error "command failed: $BASH_COMMAND"

    for ((i = 1; i < ${#FUNCNAME[@]}; i++)); do
        local path="${BASH_SOURCE[$i]}"
        local prefix="$ROOT/"

        if [[ "${path:0:${#prefix}}" == "$prefix" ]]; then
            path="${path:${#prefix}}"
        fi

        echo "    $path:${BASH_LINENO[$i-1]} in ${FUNCNAME[$i]}" >&2
    done

    exit 1
}

install-trap-handler() {
    trap handle-error ERR
}

install-trap-handler
