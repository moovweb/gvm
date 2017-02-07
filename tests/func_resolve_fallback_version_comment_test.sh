g_path_script="$(builtin cd "$(dirname "${BASH_SOURCE[0]}")" && /bin/pwd)"
. "${g_path_script}/../scripts/function/resolve_fallback_version" || return 1

## Setup expectation
expectedVersion="go1.4"

## Execute command
version="$(__gvm_resolve_fallback_version)"

## Evaluate result
[[ "${version}" == "${expectedVersion}" ]] # status=0
