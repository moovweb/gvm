#!/usr/bin/env bash
# Boolean environment variables. GVM_NO_VERIFY=0 has to mean "verify".
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
gvm_test_sandbox go1.24.13 go1.27.1
trap gvm_test_sandbox_teardown EXIT

t "the obvious values are on"
for value in 1 true TRUE yes on y; do
	gvm_flag_enabled "$value" && _pass || _fail "$value should be on"
done

t "the obvious values are off"
# `[ -n "$V" ]` calls all of these on, which is how GVM_NO_VERIFY=0 came to
# skip checksum verification.
for value in 0 false FALSE no off n ""; do
	gvm_flag_enabled "$value" && _fail "$value should be off" || _pass
done

t "a value that is not a boolean is reported, and treated as off"
out="$(gvm_flag_enabled maybe 2>&1)"
assert_ne 0 "$?"
assert_contains "$out" "Expected a boolean"
assert_contains "$out" "maybe"

t "GVM_NO_VERIFY=0 still verifies"
# The security-relevant case: a CI job that sets it to 0 to be explicit must not
# end up with unverified artifacts.
t2="$GVM_TEST_TMP/fake.bin"
echo "payload" > "$t2"
tsv="$GVM_TEST_TMP/i.tsv"
printf 'V\tgo1.24.13\tstable\n' > "$tsv"
printf 'A\tgo1.24.13\tlinux-amd64\tgo1.24.13.linux-amd64.tar.gz\tdeadbeef\thttps://example.invalid/go.tar.gz\n' >> "$tsv"
export GVM_INDEX_FILE="$tsv"

if GVM_NO_VERIFY=0 gvm_verify_checksum "$t2" deadbeef go1.24.13.linux-amd64.tar.gz > "$GVM_TEST_TMP/verify0.log" 2>&1; then
	_fail "GVM_NO_VERIFY=0 skipped verification"
else
	_pass
fi
assert_contains "$(cat "$GVM_TEST_TMP/verify0.log")" "Checksum mismatch"

if GVM_NO_VERIFY=1 gvm_verify_checksum "$t2" deadbeef go1.24.13.linux-amd64.tar.gz > "$GVM_TEST_TMP/verify1.log" 2>&1; then
	_pass
else
	_fail "GVM_NO_VERIFY=1 did not skip verification"
fi
assert_contains "$(cat "$GVM_TEST_TMP/verify1.log")" "Skipping checksum"

# flag_is <name> <value> <expected: on|off>
flag_is() {
	local result=0
	( export "$1=$2"; gvm_flag_is_set "$1" ) && result=0 || result=1
	if [ "$3" = "on" ]; then
		[ "$result" = "0" ] && _pass || _fail "$1=$2 should be on"
	else
		[ "$result" = "0" ] && _fail "$1=$2 should be off" || _pass
	fi
}

t "GVM_OFFLINE=0 does not mean offline"
flag_is GVM_OFFLINE 0 off
flag_is GVM_OFFLINE false off
flag_is GVM_OFFLINE 1 on
flag_is GVM_OFFLINE yes on

t "GVM_QUIET=0 is not quiet"
flag_is GVM_QUIET 0 off
flag_is GVM_QUIET 1 on

t "GVM_DEBUG=0 does not trace, and a non-number is not a shell error"
for value in 0 false 1 true; do
	out="$(GVM_DEBUG="$value" gvm_flag_is_set GVM_DEBUG 2>&1)"
	assert_not_contains "$out" "integer expression expected"
done
flag_is GVM_DEBUG 0 off
flag_is GVM_DEBUG 1 on
flag_is GVM_DEBUG true on

t "GVM_NO_COLORS=0 still colours"
flag_is GVM_NO_COLORS 0 off
flag_is GVM_NO_COLORS 1 on

t "NO_COLOR keeps its own meaning: any non-empty value"
# no-color.org defines NO_COLOR as present-and-non-empty rather than as a
# boolean, so NO_COLOR=0 still means "no colour" on purpose. It is checked with
# -n in _display_colors, not through gvm_flag_enabled.
plain="$( NO_COLOR=0 display_warning "careful" | cat -v )"
assert_contains "$plain" "WARNING: careful"
assert_not_contains "$plain" "^[["

t "an unset variable is off, not an error"
unset GVM_OFFLINE
gvm_flag_is_set GVM_OFFLINE && _fail "unset should be off" || _pass

t "GVM_DEBUG does not break a command that reads it"
out="$(GVM_DEBUG=maybe gvm doctor 2>&1)"
assert_not_contains "$out" "integer expression expected"

summary
