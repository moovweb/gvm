g_path_script="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && /bin/pwd)"
. "${g_path_script}/../scripts/function/resolve_fallback_pkgset" || return 1

## Setup expectation
expectedPkgset="global"

## Execute command
pkgset="$(__gvm_resolve_fallback_pkgset)"

## Evaluate result
[[ "${pkgset}" == "${expectedPkgset}" ]] # status=0
