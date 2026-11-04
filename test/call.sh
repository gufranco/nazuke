#!/bin/sh
[ -n "${ZSH_VERSION:-}" ] && emulate sh

NZ_LIB="$(cd "$(dirname "$0")/../lib" && pwd)" || exit 1

# shellcheck source=SCRIPTDIR/../lib/core.sh
. "${NZ_LIB}/core.sh"
# shellcheck source=SCRIPTDIR/../lib/ui.sh
. "${NZ_LIB}/ui.sh"
# shellcheck source=SCRIPTDIR/../lib/cli.sh
. "${NZ_LIB}/cli.sh"
# shellcheck source=SCRIPTDIR/../lib/doctor.sh
. "${NZ_LIB}/doctor.sh"

"$@"
