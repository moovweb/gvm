#!/usr/bin/env bash
# `gvm install`, end to end, against a local mirror serving a synthetic
# artifact. Nothing here touches go.dev, so the test needs no network.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
gvm_test_sandbox
trap gvm_test_sandbox_teardown EXIT

FAKE_VERSION="1.99.1"
FAKE_NAME="go$FAKE_VERSION"
OS="$(gvm_platform_os)"
ARCH="$(gvm_platform_arch)"
TARBALL="$FAKE_NAME.$OS-$ARCH.tar.gz"
MIRROR="$GVM_TEST_TMP/mirror"
INDEX="$GVM_TEST_TMP/index.tsv"

# A minimal but structurally real Go tree: the installer unpacks the tarball,
# then trusts VERSION and bin/go to decide whether the install worked.
build_artifact() {
	local root="$GVM_TEST_TMP/build/go"
	mkdir -p "$root/bin" "$root/pkg/tool/linux_amd64" "$root/src/fmt" "$root/api"
	printf 'go%s\ntime 2026-01-01T00:00:00Z\n' "$FAKE_VERSION" > "$root/VERSION"
	cat > "$root/bin/go" <<'GO'
#!/bin/sh
case "$1" in
	version) echo "go version $GVM_FAKE_VERSION linux/amd64" ;;
	env)
		case "$2" in
			GOROOT) echo "$GVM_FAKE_ROOT" ;;
			*) exit 1 ;;
		esac
		;;
	*) exit 1 ;;
esac
GO
	chmod +x "$root/bin/go"
	echo "package fmt" > "$root/src/fmt/print.go"
	echo "package api" > "$root/api/go1.txt"
	tar -C "$GVM_TEST_TMP/build" -czf "$MIRROR/$TARBALL" go
}

start_mirror() {
	mkdir -p "$MIRROR"
	build_artifact
	local sha size
	# gvm's own gvm_checksum_file, not sha256sum: macOS has shasum and no
	# sha256sum, and a pipeline through cut hides the failure, so the index
	# ended up with an empty checksum and every install against it failed.
	sha="$(gvm_checksum_file "$MIRROR/$TARBALL")"
	size="$(wc -c < "$MIRROR/$TARBALL" | tr -d ' ')"
	SHA="$sha"
	SIZE="$size"
	cat > "$INDEX" <<TSV
F	$FAKE_NAME	$TARBALL	$OS	$ARCH	archive	$SIZE	$sha
V	$FAKE_NAME	stable
TSV
	# Ask python which port is free and pass it in, rather than starting on
	# port 0 and scraping the number out of the log line: the wording of that
	# line is python's, not ours, and when it changed the test sat there for
	# ten seconds and gave up on a server that was running fine.
	PORT="$(python3 -c 'import socket
s = socket.socket()
s.bind(("127.0.0.1", 0))
print(s.getsockname()[1])
s.close()')"
	(cd "$MIRROR" && exec python3 -u -m http.server "$PORT" --bind 127.0.0.1) \
		> "$GVM_TEST_TMP/mirror.log" 2>&1 &
	MIRROR_PID=$!
	# Poll by connecting, not by reading the log. /dev/tcp is in bash itself,
	# so this needs nothing the runner might not have.
	local tries=0
	while [ "$tries" -lt 100 ]; do
		if (exec 3<>/dev/tcp/127.0.0.1/"$PORT") 2> /dev/null; then
			break
		fi
		tries=$((tries + 1))
		sleep 0.1
	done
	if [ "$tries" -ge 100 ]; then
		echo "mirror did not start on port $PORT; its log said:" >&2
		cat "$GVM_TEST_TMP/mirror.log" >&2
		exit 1
	fi
	export GVM_DL_BASE_URL="http://127.0.0.1:$PORT"
}

stop_mirror() {
	[ -n "${MIRROR_PID:-}" ] && kill "$MIRROR_PID" 2> /dev/null
	MIRROR_PID=""
	return 0
}

start_mirror
trap 'stop_mirror; gvm_test_sandbox_teardown' EXIT
export GVM_INDEX_FILE="$INDEX"
# The fake `go` needs to find its own tree.
export GVM_FAKE_VERSION="$FAKE_VERSION"

t "a binary install unpacks, verifies, records and wires up the environment"
capture out gvm install "$FAKE_VERSION"
assert_eq 0 "$CAPTURE_STATUS"
assert_contains "$out" "$FAKE_NAME successfully installed"
assert_ok "" test -x "$GVM_ROOT/gos/$FAKE_NAME/bin/go"
assert_eq "$FAKE_NAME" "$(head -1 "$GVM_ROOT/gos/$FAKE_NAME/VERSION")"
assert_eq "$GVM_ROOT/gos/$FAKE_NAME" "$GVM_ROOT/gos/$FAKE_NAME"
assert_ok "" test -f "$GVM_ROOT/environments/$FAKE_NAME@global"
want_goroot="export GOROOT; GOROOT=\"\$GVM_ROOT/gos/$FAKE_NAME\""
assert_contains "$(cat "$GVM_ROOT/environments/$FAKE_NAME@global")" "$want_goroot"
assert_ok "" test -d "$GVM_ROOT/pkgsets/$FAKE_NAME/global/overlay/bin"
assert_ok "" test -f "$GVM_ROOT/gos/$FAKE_NAME/manifest"
assert_contains "$(cat "$GVM_ROOT/gos/$FAKE_NAME/manifest")" "./pkg/tool/linux_amd64"

t "the first install becomes the default"
assert_eq "$FAKE_NAME" "$(gvm_default_recorded)"
assert_eq "$FAKE_NAME" "$(gvm_alias_resolve default)"

t "the downloaded artifact is cached, and named for go.dev"
assert_ok "" test -f "$GVM_ROOT/cache/downloads/$TARBALL"
assert_eq "$SIZE" "$(wc -c < "$GVM_ROOT/cache/downloads/$TARBALL" | tr -d ' ')"

t "a second install is a no-op success, as nvm does it"
capture out gvm install "$FAKE_VERSION"
assert_eq 0 "$CAPTURE_STATUS"
assert_contains "$out" "already installed"

t "--force replaces the existing install"
assert_ok "" gvm install "$FAKE_VERSION" --force
assert_ok "" test -x "$GVM_ROOT/gos/$FAKE_NAME/bin/go"

t "a reinstall keeps the package set"
# Reinstalling is how you recover from a broken GOROOT, and the module cache and
# built packages live in the pkgset. This used to go through `uninstall`, which
# runs `go clean -modcache` and deletes the pkgset - so the fix for a corrupted
# install was to lose the download cache along with it.
mkdir -p "$GVM_ROOT/pkgsets/$FAKE_NAME/global/pkg/mod/cache/download"
printf 'a module I downloaded\n' > "$GVM_ROOT/pkgsets/$FAKE_NAME/global/pkg/mod/cache/download/keepme"
assert_ok "" gvm install "$FAKE_VERSION" --force
assert_ok "" test -f "$GVM_ROOT/pkgsets/$FAKE_NAME/global/pkg/mod/cache/download/keepme"
assert_ok "" test -x "$GVM_ROOT/gos/$FAKE_NAME/bin/go"

t "reinstalling refreshes a default that pointed at the same version"
# `default` is a copy of a version's environment file. Reinstalling that version
# rewrites the original, and the copy has to follow: on a machine upgraded from
# an older gvm, `default` kept settings (no GOTOOLCHAIN) that `gvm use` no
# longer reported, so a new shell quietly behaved differently from an old one.
stale="$GVM_ROOT/environments/default"
grep -v 'GOTOOLCHAIN' "$GVM_ROOT/environments/$FAKE_NAME" > "$stale"
assert_ok "" test -f "$stale"
assert_not_contains "$(cat "$stale")" "GOTOOLCHAIN"
capture out gvm install "$FAKE_VERSION" --force
assert_contains "$out" "refreshed environments/default"
assert_contains "$(cat "$stale")" "GOTOOLCHAIN"

t "a default pointing at another version is left alone"
other="$GVM_ROOT/environments/default"
printf '# the default is some other version\nexport gvm_go_name; gvm_go_name="go1.20.5"\n' > "$other"
capture out gvm install "$FAKE_VERSION" --force
assert_not_contains "$out" "refreshed environments/default"
assert_contains "$(cat "$other")" "go1.20.5"

t "progress messages never contaminate captured output"
# The installer shadows the display functions to send them to stderr; if that
# regresses, the message would land in the path that tar is about to read.
out="$(gvm install "$FAKE_VERSION" --force 2>/dev/null)"
assert_not_contains "$out" "Downloading"
assert_not_contains "$out" "successfully installed"

t "a checksum mismatch is refused and the bad file is discarded"
BAD="$GVM_TEST_TMP/bad.tsv"
# The SHA is the last field, so it is rewritten by position, not by pattern.
awk -F'\t' -v OFS='\t' 'NR == 1 { $8 = sprintf("%064d", 0) } { print }' \
	"$INDEX" > "$BAD"
assert_fails_with "Checksum mismatch" env GVM_INDEX_FILE="$BAD" gvm install "$FAKE_VERSION" --force
assert_fail "" test -f "$GVM_ROOT/cache/downloads/$TARBALL"
assert_fail "" test -d "$GVM_ROOT/gos/$FAKE_NAME"

t "GVM_NO_VERIFY=1 is the only way past verification"
out="$(GVM_NO_VERIFY=1 GVM_INDEX_FILE="$BAD" gvm install "$FAKE_VERSION" --force 2>&1)"
assert_contains "$out" "$FAKE_NAME successfully installed"
assert_contains "$out" "Skipping checksum verification"
gvm uninstall "$FAKE_NAME" --force > /dev/null 2>&1

t "a release with no artifact for this platform explains itself"
EMPTY="$GVM_TEST_TMP/empty.tsv"
printf 'V\tgo9.9.9\tstable\n' > "$EMPTY"
assert_fails_with "No $OS/$ARCH binary is published for go9.9.9" \
	env GVM_INDEX_FILE="$EMPTY" gvm install 9.9.9

t "a published-platform list is offered when the artifact is missing"
cat > "$GVM_TEST_TMP/some.tsv" <<TSV
F	go9.9.9	go9.9.9.darwin-arm64.tar.gz	darwin	arm64	archive	1	$SHA
V	go9.9.9	stable
TSV
assert_fails_with "darwin/arm64" \
	env GVM_INDEX_FILE="$GVM_TEST_TMP/some.tsv" gvm install 9.9.9

t "an unreachable mirror fails with a proxy hint and leaves no debris"
rm -f "$GVM_ROOT/cache/downloads/$TARBALL"
capture out env GVM_DL_BASE_URL="http://127.0.0.1:1" gvm install "$FAKE_VERSION"
assert_contains "$out" "Failed to download"
assert_contains "$out" "http_proxy"
assert_fail "" test -d "$GVM_ROOT/gos/$FAKE_NAME"

t "an unknown version is rejected before anything is downloaded"
assert_fails_with "No published Go release matches" gvm install 42.42.42

t "--no-cache forces a fresh index and skips reuse"
assert_ok "" gvm install "$FAKE_VERSION" --no-cache --force
rm -f "$GVM_ROOT/cache/downloads/$TARBALL"
assert_ok "" gvm install "$FAKE_VERSION" --no-cache --force
assert_ok "" test -f "$GVM_ROOT/cache/downloads/$TARBALL"

summary
