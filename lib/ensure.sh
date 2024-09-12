# enables and starts service, waiting for service to activate before returning
ensure-service() {
    local unit="$1"
    systemctl enable "$unit"
    systemctl start "$unit"
}

absolute-path?() {
    local path="$1"
    [[ "${path:0:1}" == "/" ]]
}

ensure-file() {
    # usage: ensure-file <path> [source=<source>] [chown=<chown>] [chmod=<chmod>]
    local path="$1" "${@:2}" source chown chmod

    absolute-path? "$path" || die "ensure-file: path must be absolute"

    local source="${source:-"files$path"}"
    local dest="$path"

    # ensure parent dir exists
    mkdir -p "$(dirname "$dest")"

    # copy file to temp path in same dir
    cp "$source" "$dest+"

    # apply permissions
    [ -n "${chown:-}" ] && chown "$chown" "$dest+"
    [ -n "${chmod:-}" ] && chmod "$chmod" "$dest+"

    # atomically rename in place
    mv "$dest+" "$dest"

    echo "file: $dest" >&2
}

ensure-gen() {
    # usage: ensure-gen <path> [template=<template>] [chown=<chown>] [chmod=<chmod>]
    local path="$1" "${@:2}" template chown chmod

    absolute-path? "$path" || die "ensure-gen: path must be absolute"

    local template="${template:-"gen$path"}"
    local dest="$path"

    # ensure parent dir exists
    mkdir -p "$(dirname "$dest")"

    # run template
    "$template" > "$dest+"

    # apply permissions
    [ -n "${chown:-}" ] && chown "$chown" "$dest+"
    [ -n "${chmod:-}" ] && chmod "$chmod" "$dest+"

    # atomically rename in place
    mv "$dest+" "$dest"

    echo "gen: $dest" >&2
}

ensure-url() {
    # usage: ensure-url <path> <url> sha256=<sha256> [chown=<chown>] [chmod=<chmod>]
    # sha256 kwarg is mandatory
    local path="$1" url="$2" "${@:3}"

    absolute-path? "$path" || die "ensure-url: path must be absolute"

    if [ -f "$path" ]; then
        if sha256-match? "$path" "$sha256"; then
            echo "file: $path unchanged"
            return 0
        else
            warn "checksum mismatch: $path; re-downloading from $url"
        fi
    else
        echo "file: $path downloading from $url"
    fi

    # ensure parent dir exists
    mkdir -p "$(dirname "$path")"

    # download file
    curl -Lo "$path+" "$url"
    sha256-match? "$path+" "$sha256" || die "checksum mismatch downloading $url"

    # apply permissions
    [ -n "${chown:-}" ] && chown "$chown" "$path+"
    [ -n "${chmod:-}" ] && chmod "$chmod" "$path+"

    # atomically rename into place
    mv "$path+" "$path"
}

ensure-dir() {
    # usage: ensure-dir <path> [chown=<chown>] [chmod=<chmod>]
    local path="$1" "${@:2}"

    absolute-path? "$path" || die "ensure-file: path must be absolute"

    # make dir
    mkdir -p "$path"

    # apply permissions
    [ -n "${chown:-}" ] && chown "$chown" "$path"
    [ -n "${chmod:-}" ] && chmod "$chmod" "$path"

    echo "dir: $path" >&2
}

ensure-user() {
    local user="$1" "${@:2}"

    local args=()
    [ -n "${groups:-}" ] && args+=(--groups "$groups")
    [ -n "${usergroup:-}" ] && args+=(--user-group)
    [ -n "${homedir:-}" ] && args+=(--home-dir "$homedir")
    [ -n "${createhome:-}" ] && args+=(--create-home)
    [ -n "${shell:-}" ] && args+=(--shell "$shell")
    [ -n "${uid:-}" ] && args+=(--uid "$uid")
    [ -n "${gid:-}" ] && args+=(--gid "$gid")

    getent passwd "$user" >/dev/null ||
        useradd "${args[@]}" "$user"
}

ensure-group() {
    local group="$1" "${@:2}"

    local args=()
    [ -n "${gid:-}" ] && args+=(--gid "$gid")

    getent group "$group" >/dev/null ||
        groupadd "${args[@]}" "$group"
}

sha256-match?() {
    local file="$1"
    local sha256="$2"
    echo "$sha256 $file" | sha256sum -c &>/dev/null
}

ensure-ssh-keygen() {
    local user="$1" type= file= "${@:2}"

    # default values
    : "${type:=ed25519}"
    : "${file:="/home/$user/.ssh/id_$type"}"

    [ -f "$file" ] || su --login --shell=/bin/bash \
        --command="ssh-keygen -t ${type@Q} -f ${file@Q} </dev/null" \
        "$user"

    echo "ssh-keygen: $file"
}

ensure-git-repo() {
    local remote="$1" path="$2" user="$USER" "${@:3}"

    [ -d "$path" ] || su --login --shell=/bin/bash \
        --command="git clone ${remote@Q} ${path@Q}" \
        "$user"

    echo "git-repo: $remote $path"
}

ensure-debian-chroot() {
    local distro="$1" path="$2" name= include= "${@:3}"

    # defaults
    [[ "${name:-}" ]] && name="${path##*/}"

    [ -d "$path" ] || {
        local args=()
        [ -n "${include:-}" ] && args+=(--include="$include")

        debootstrap "${args[@]}" "$distro" "$path"

        # small fixup, sudo prints warning without this config:
        echo "$name" > "$path/etc/hostname"
        echo "$name 127.0.0.1" >> "$path/etc/hosts"
    }

    echo "ensure-debian-chroot: $distro $path"
}

ensure-chroot-modules() {
    local chroot="$1" separator="${2:-}" modules=("${@:3}")
    [[ -z "$separator" ]] || :check-separator

    :chroot-exec -- /.fig/fig/bin/fig apply "${modules[@]}"
}

ensure-chroot-packages() {
    local chroot="$1" separator="$2" packages=("${@:3}")
    :check-separator

    :chroot-exec -- /.fig/fig/bin/fig ensure-packages -y "${packages[@]}"
}

ensure-machine-modules() {
    local name="$1" separator="${2:-}" modules=("${@:3}")
    [[ -z "$separator" ]] || :check-separator

    machinectl copy-to --force "$name" "$ROOT" "/.fig"
    :machine-exec /.fig/fig/bin/fig apply "${modules[@]}"
}

ensure-machine-packages() {
    local name="$1" separator="$2" packages=("${@:3}")
    :check-separator

    machinectl copy-to --force "$name" "$ROOT" "/.fig"
    :machine-exec /.fig/fig/bin/fig ensure-packages "${packages[@]}"
}

:check-separator() {
    [[ "$separator" == "--" ]] || die "${FUNCNAME[1]}: must pass -- after chroot path"
}

:chroot-exec() {
    local nspawn_args=(
        --quiet
        --as-pid2
        --directory "$chroot"
        --bind-ro "$ROOT:/.fig"
        --setenv FIG_CHROOT="$chroot"
    )

    systemd-nspawn "${nspawn_args[@]}" "$@"
}

:machine-exec() {
    machinectl shell \
        --setenv FIG_CHROOT="$name" \
        "root@$name" "$@"
}
