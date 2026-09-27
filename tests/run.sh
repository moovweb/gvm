#!/usr/bin/env bash
#
# tests/run.sh - run the whole suite.
#
# The old suite needed moovweb's "tf" framework installed separately, shelled out
# to Ruby once per assertion, and downloaded real Go toolchains (go1.4.3,
# go1.6.4, go1.7.6) to test against. These tests need nothing but bash, awk, tar
# and a loopback HTTP server, and they run in a throwaway GVM_ROOT.
#
# Usage: tests/run.sh [pattern...]

set -u

cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

# For the rules about TMPDIR, which both this runner and every test file need to
# agree on: one place, so a runner cannot end up writing somewhere the tests are
# not looking. Sourced before anything else here on purpose - it only defines
# functions and sets variables.
# shellcheck disable=SC1091
. tests/lib.sh

# The suite must never be able to reach the GVM installation of whoever is
# running it. Inheriting GVM_ROOT, GOROOT or a `gvm` on PATH is exactly how the
# old suite ended up testing the wrong thing.
unset GVM_ROOT GOROOT GOPATH GOBIN GOOS GOARCH GVM_VERSION
unset gvm_go_name gvm_pkgset_name GVM_INDEX_FILE GVM_DL_BASE_URL
unset GVM_DL_INDEX_URL GVM_NO_VERIFY GVM_INDEX_TTL GVM_QUIET GVM_DEBUG

RED="" GREEN="" BOLD="" RESET=""
if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ]; then
	RED=$'\033[0;31m'
	GREEN=$'\033[0;32m'
	BOLD=$'\033[1m'
	RESET=$'\033[0m'
fi

if [ "$#" -gt 0 ]; then
	files=()
	for pattern in "$@"; do
		while IFS= read -r match; do
			files+=("$match")
		done < <(find tests -maxdepth 1 -name "*${pattern}*_test.sh" | sort)
	done
else
	# A while-read loop, not `mapfile`: macOS ships bash 3.2, and this runner
	# has to work there for the sake of the 3.2 claim in the README.
	while IFS= read -r match; do
		files+=("$match")
	done < <(find tests -maxdepth 1 -name '[0-9]*_test.sh' | sort)
fi

if [ "${#files[@]}" -eq 0 ]; then
	echo "no test files matched" >&2
	exit 1
fi

total_pass=0
total_fail=0
failed_files=()
start=$SECONDS

for file in "${files[@]}"; do
	printf '%s==> %s%s\n' "$BOLD" "$file" "$RESET"
	# Streamed through tee rather than captured in one $(...): a capture prints
	# nothing at all until the file finishes, so a test file that hangs - or takes
	# ten minutes to fail - shows up as silence with no clue where it stopped.
	# A test that reads stdin must fail, not hang the whole suite.
	log="$(mktemp "$GVM_TEST_TMPBASE/gvm-test-log.XXXXXX")" || {
		printf 'could not write a log file in %s\n' "$GVM_TEST_TMPBASE" >&2
		exit 1
	}
	# A per-file timeout, so one file that hangs costs a minute and reports which
	# test it was on. `timeout` is GNU; macOS has none unless coreutils is
	# installed, where it is called gtimeout.
	runner=""
	timeout_bin="$(command -v timeout 2> /dev/null || command -v gtimeout 2> /dev/null || true)"
	[ -n "$timeout_bin" ] && runner="$timeout_bin -k 5 300"
	progress="$log.progress"
	: > "$progress"
	GVM_TEST_TRACE="$progress" $runner bash "$file" < /dev/null 2>&1 |
		tee "$log" | sed 's/^/    /'
	status="${PIPESTATUS[0]}"
	if [ "$status" = "124" ] || [ "$status" = "137" ]; then
		printf '    TIMEOUT after 300s, last test reached:\n'
		sed 's/^/      /' "$progress"
	fi
	out="$(cat "$log")"
	rm -f "$log" "$progress"
	line="$(printf '%s\n' "$out" | grep -E '^[0-9]+ passed' | tail -1)"
	pass="$(printf '%s' "$line" | sed -n 's/^\([0-9]*\) passed.*/\1/p')"
	fail="$(printf '%s' "$line" | sed -n 's/.*, \([0-9]*\) failed.*/\1/p')"
	total_pass=$((total_pass + ${pass:-0}))
	total_fail=$((total_fail + ${fail:-0}))
	if [ "$status" != "0" ]; then
		failed_files+=("$file")
	elif [ -z "$line" ]; then
		# A file that printed no result line has not reported a result, and
		# scoring that as zero passes is how a broken harness hides a working
		# suite: this runner once reported 0 assertions across every file and
		# exited 0, because its own log file could not be created and every
		# count came back empty.
		printf '    no result line - treating this file as failed\n'
		failed_files+=("$file")
	fi
	printf '\n'
done

elapsed=$((SECONDS - start))
printf '%s%s%s\n' "$BOLD" "----------------------------------------" "$RESET"
if [ "${#failed_files[@]}" -eq 0 ]; then
	printf '%s%d assertions passed, 0 failed%s in %ss across %d files\n' \
		"$GREEN" "$total_pass" "$RESET" "$elapsed" "${#files[@]}"
	exit 0
fi

printf '%s%d assertions passed, %d failed%s in %ss across %d files\n' \
	"$RED" "$total_pass" "$total_fail" "$RESET" "$elapsed" "${#files[@]}"
printf '%sfailed:%s\n' "$RED" "$RESET"
for file in "${failed_files[@]}"; do
	printf '  %s\n' "$file"
done
exit 1
