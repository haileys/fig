apply-config() {
    local path="$1"

    declare -a -g modules
    source "$path"

    # allow modules override
    if [ "$#" -gt 0 ]; then
        modules=("$@")
    fi

    apply-modules
}
