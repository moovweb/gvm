#!/usr/bin/env bash
# Platform detection and OS/arch mapping.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
gvm_test_sandbox
trap gvm_test_sandbox_teardown EXIT

t "the common Linux and macOS combinations map to go.dev names"
assert_eq linux "$(gvm_platform_map_os Linux)"
assert_eq linux "$(gvm_platform_map_os Linux)"
assert_eq amd64 "$(gvm_platform_map_arch x86_64)"
assert_eq amd64 "$(gvm_platform_map_arch amd64)"
assert_eq arm64 "$(gvm_platform_map_arch aarch64)"
assert_eq arm64 "$(gvm_platform_map_arch arm64)"
assert_eq 386 "$(gvm_platform_map_arch i686)"
assert_eq darwin "$(gvm_platform_map_os Darwin)"

t "Windows is reported as windows, not mingw"
assert_eq windows "$(gvm_platform_map_os MINGW64_NT-10.0)"
assert_eq windows "$(gvm_platform_map_os MSYS_NT-10.0)"
assert_eq windows "$(gvm_platform_map_os CYGWIN_NT-10.0)"

t "the BSDs and Unixes map too"
assert_eq freebsd "$(gvm_platform_map_os FreeBSD)"
assert_eq openbsd "$(gvm_platform_map_os OpenBSD)"
assert_eq netbsd "$(gvm_platform_map_os NetBSD)"
assert_eq solaris "$(gvm_platform_map_os SunOS)"
assert_eq aix "$(gvm_platform_map_os AIX)"
assert_eq plan9 "$(gvm_platform_map_os Plan9)"

t "an unknown architecture is unknown, not silently s390x"
# The old mapping defaulted anything unrecognised to s390x, which produced a
# download of the wrong tarball and a baffling tar error.
assert_eq "" "$(gvm_platform_map_arch sparc64)"
assert_eq "" "$(gvm_platform_map_arch riscv128)"
assert_eq "" "$(gvm_platform_map_os Haiku)"

t "the less common real architectures are not lost"
assert_eq riscv64 "$(gvm_platform_map_arch riscv64)"
assert_eq loong64 "$(gvm_platform_map_arch loongarch64)"
assert_eq s390x "$(gvm_platform_map_arch s390x)"
assert_eq ppc64le "$(gvm_platform_map_arch ppc64le)"
assert_eq armv6l "$(gvm_platform_map_arch armv7l)"

t "the host is detected, and the pair is os and arch separated by a space"
os="$(gvm_platform_os)"
arch="$(gvm_platform_arch)"
assert_eq "$os" "$(gvm_platform_pair | cut -d' ' -f1)"
assert_eq "$arch" "$(gvm_platform_pair | cut -d' ' -f2)"
assert_eq "$os-$arch" "$(gvm_platform_tarball)"

t "gvm_index_has_binary knows which releases have prebuilt binaries"
tsv="$(mktemp "${TMPDIR:-/tmp}/gvm-index.XXXXXX")"
gvm_test_cleanup_add 'rm -f "$tsv"'
cat > "$tsv" <<'TSV'
F	go1.4.3	go1.4.3.linux-amd64.tar.gz	linux	amd64	archive	1	a
V	go1.4.3	stable
F	go1.27.1	go1.27.1.linux-amd64.tar.gz	linux	amd64	archive	1	b
F	go1.27.1	go1.27.1.darwin-arm64.tar.gz	darwin	arm64	archive	1	c
V	go1.27.1	stable
TSV
export GVM_INDEX_FILE="$tsv"
assert_ok "" gvm_index_has_binary go1.4.3 linux amd64
assert_ok "" gvm_index_has_binary go1.27.1 linux amd64
assert_ok "" gvm_index_has_binary go1.27.1 darwin arm64
assert_fail "" gvm_index_has_binary go1.4.3 darwin arm64
assert_fail "" gvm_index_has_binary go9.9.9 linux amd64

t "gvm_index_platforms lists what a release does publish"
assert_eq "darwin/arm64 linux/amd64" "$(gvm_index_platforms go1.27.1 | tr '\n' ' ' | sed 's/ $//')"
assert_eq "" "$(gvm_index_platforms go9.9.9)"

summary
