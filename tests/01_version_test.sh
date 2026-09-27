#!/usr/bin/env bash
# Version parsing, comparison and ordering.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
gvm_test_sandbox go1.2.2 go1.9.7 go1.10.1 go1.24.12 go1.24.13
trap gvm_test_sandbox_teardown EXIT

t "gvm_version_is_valid accepts real releases"
assert_eq ok "$(gvm_version_is_valid go1.24.13 && echo ok)" "go1.24.13"
assert_eq ok "$(gvm_version_is_valid go1.2 && echo ok)" "go1.2"
assert_eq ok "$(gvm_version_is_valid go1.24rc1 && echo ok)" "go1.24rc1"

t "gvm_version_is_valid rejects nonsense"
assert_fail "" gvm_version_is_valid master
assert_fail "" gvm_version_is_valid stable
assert_fail "" gvm_version_is_valid ""

t "a release candidate sorts before its own final release"
# `sort -V` gets this backwards: it orders go1.2.2 before go1.2.2rc1, so the
# candidate looks newer than the release it was a candidate for. GNU's sort is
# only the reference point here - it is not installed everywhere, and macOS's
# is BSD - so it is only compared where there is one to compare with.
if printf 'go1.1\n' | sort -V > /dev/null 2>&1; then
	assert_eq "go1.2.2 go1.2.2rc1" "$(printf 'go1.2.2rc1\ngo1.2.2\n' | sort -V | tr '\n' ' ' | sed 's/ $//')"
fi
assert_eq "go1.2.2rc1 go1.2.2" "$(printf 'go1.2.2rc1\ngo1.2.2\n' | gvm_versions_sorted | tr '\n' ' ' | sed 's/ $//')"

t "sort -V is also wrong for 1.9 vs 1.10"
keyed="$(printf 'go1.10.1\ngo1.9.7\n' | gvm_versions_sorted | tr '\n' ' ')"
assert_eq "go1.9.7 go1.10.1 " "$keyed"

t "full ordering across majors, minors and pre-releases"
keyed="$(printf 'go1.24.13\ngo1.2.2\ngo1.10.1\ngo1.24rc1\ngo1.24.0\ngo1.9.7\ngo1.24.2\n' |
	gvm_versions_sorted | tr '\n' ' ')"
assert_eq "go1.2.2 go1.9.7 go1.10.1 go1.24rc1 go1.24.0 go1.24.2 go1.24.13 " "$keyed"

t "descending order"
keyed="$(printf 'go1.2.2\ngo1.24.13\ngo1.9.7\n' | gvm_versions_sorted desc | tr '\n' ' ')"
assert_eq "go1.24.13 go1.9.7 go1.2.2 " "$keyed"

t "gvm_version_compare reports through its exit status, like compare_version"
# 0 equal, 1 first is greater, 2 first is less
assert_rc 0 gvm_version_compare go1.24.13 go1.24.13
assert_rc 1 gvm_version_compare go1.24.13 go1.24.2
assert_rc 2 gvm_version_compare go1.2.2 go1.10.1
assert_rc 2 gvm_version_compare go1.2.2rc1 go1.2.2

t "gvm_version_is_at_least"
assert_ok "" gvm_version_is_at_least go1.24.6 go1.24.6
assert_ok "" gvm_version_is_at_least go1.25.0 go1.24.6
assert_fail "" gvm_version_is_at_least go1.24.0 go1.24.6
assert_fail "" gvm_version_is_at_least go1.2.2 go1.9.7

t "gvm_version_is_prerelease"
assert_ok "" gvm_version_is_prerelease go1.24rc1
assert_ok "" gvm_version_is_prerelease go1.24beta1
assert_fail "" gvm_version_is_prerelease go1.24.13
assert_fail "" gvm_version_is_prerelease go1.2

t "gvm_version_candidates expands a partial version"
assert_eq "go1.24.* go1.24" "$(gvm_version_candidates 1.24 | tr '\n' ' ' | sed 's/ $//')"
assert_eq "go1.2.* go1.2" "$(gvm_version_candidates 1.2 | tr '\n' ' ' | sed 's/ $//')"
assert_eq "go1.* go1" "$(gvm_version_candidates 1 | tr '\n' ' ' | sed 's/ $//')"
assert_eq "go1.24.13" "$(gvm_version_candidates 1.24.13)"
assert_eq "go1.* go1" "$(gvm_version_candidates go1 | tr '\n' ' ' | sed 's/ $//')"

t "1.2 must not expand to something that matches go1.24"
assert_eq "go1.2.* go1.2" "$(gvm_version_candidates 1.2 | tr '\n' ' ' | sed 's/ $//')"
assert_fail "" gvm_pattern_matches "go1.2.*" "go1.24.13"

t "a caller's own glob keeps its shape but gains the go prefix"
assert_eq "go1.24.1?" "$(gvm_version_candidates '1.24.1?')"
assert_eq "go1.24*" "$(gvm_version_candidates 'go1.24*')"
assert_eq "go1.24*" "$(gvm_version_candidates '1.24*')"

t "non-version queries are passed through untouched"
assert_eq stable "$(gvm_version_candidates stable)"
assert_eq system "$(gvm_version_candidates system)"

t "gvm_pattern_matches honours ? and *"
assert_ok "" gvm_pattern_matches "go1.24*" "go1.24.13"
assert_ok "" gvm_pattern_matches "go1.24.1?" "go1.24.13"
assert_fail "" gvm_pattern_matches "go1.24.1?" "go1.24.13a"
assert_fail "" gvm_pattern_matches "go1.25*" "go1.24.13"

t "gvm_version_stable and major_minor"
assert_eq go1.24.0 "$(gvm_version_stable go1.24rc1)"
assert_eq go1.24.13 "$(gvm_version_stable go1.24.13)"
assert_eq 1.24 "$(gvm_version_major_minor go1.24.13)"
assert_eq 1.9 "$(gvm_version_major_minor go1.9.7)"

t "gvm_versions_latest picks the newest match"
assert_eq go1.24.13 "$(gvm_versions_installed | gvm_versions_latest)"
assert_eq go1.24.13 "$(gvm_versions_installed | gvm_versions_latest 'go1.24*')"
assert_eq go1.10.1 "$(gvm_versions_installed | gvm_versions_latest 'go1.10*')"

t "sorting is stable under repeated nested use (mktemp, not \$\$)"
out="$(for i in 1 2 3 4 5; do
	(printf 'go1.2.2\ngo1.24.13\ngo1.9.7\n' | gvm_versions_sorted | tr '\n' ' ')
done | sort -u | wc -l | tr -d ' ')"
assert_eq 1 "$out"

summary
