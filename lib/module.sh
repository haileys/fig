apply-modules() {
    log "Installing bootstrap packages"
    all-module-bootstrap-packages | xargs-function ensure-packages

    # invoke before hook of each module
    module-exec-each :module-invoke-before-packages

    log "Refreshing packages"
    refresh-packages

    log "Installing packages"
    all-module-packages | xargs-function ensure-packages

    # invoke apply step
    module-exec-each :module-invoke-apply
}

apply-user() {
    local user="$1"

    su --shell=/bin/bash \
        --command="cd ${ROOT@Q} && fig/bin/fig apply-user ${module@Q}" \
        "$user"
}

apply-module-user() {
    # usage: apply-module-user <module>
    local module="$1" user="$USER"
    module-exec :module-invoke-apply-user
}

all-module-packages() {
    module-exec-each :module-packages-print | sort | uniq
}

all-module-bootstrap-packages() {
    module-exec-each :module-bootstrap-packages-print | sort | uniq
}

module-exec-each() {
    declare -a -g modules
    local module

    for module in "${modules[@]}"; do
        module-exec "$@"
    done
}

module-exec() {
    (
        install-trap-handler
        cd "modules/$module"
        source "$PWD/module.sh"
        "$@"
    )
}

# these functions run under module-exec in module scope:

:module-packages-print() {
    declare -a -g packages
    :print-args "${packages[@]}"
}

:module-bootstrap-packages-print() {
    declare -a -g bootstrap_packages
    :print-args "${bootstrap_packages[@]}"
}

:print-args() {
    while (( "$#" > 0 )); do
        echo "$1"
        shift
    done
}

:is-function?() {
    [[ "$(type -t "$1")" == function ]]
}

:module-invoke-before-packages() {
    if :is-function? before-packages; then
        log "Running $module before-packages"
        before-packages
    fi
}

:module-invoke-apply() {
    if :is-function? apply; then
        log "Applying $module"
        apply
    fi
}

:module-invoke-apply-user() {
    local apply="apply@$USER"

    :is-function? "$apply" || \
        die "Can't apply $module for user $USER - must define function '$apply'"

    log "Applying $module for user $USER"
    "$apply"
}
