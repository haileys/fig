# strict mode
set -euo pipefail

ROOT="$PWD"

# find canonical path to fig submodule:
FIG_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIG_LIB="$FIG_PATH/lib"

# load log first
source "$FIG_LIB/log.sh"

# then os
source "$FIG_LIB/os.sh"

# then remaining libs
source "$FIG_LIB/config.sh"
source "$FIG_LIB/ensure.sh"
source "$FIG_LIB/module.sh"
source "$FIG_LIB/util.sh"
