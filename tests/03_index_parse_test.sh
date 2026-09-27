#!/usr/bin/env bash
# The JSON -> TSV index parser, plus the index query layer on top of it.
#
# A fixture rather than the live index: this must pass with no network, and it
# has to be able to exercise the awkward shapes (a release with no files, a
# pre-release, a non-linux platform) that the real feed only shows by accident.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
gvm_test_sandbox
trap gvm_test_sandbox_teardown EXIT

json="$(mktemp "${TMPDIR:-/tmp}/gvm-index.XXXXXX")"
tsv="$(mktemp "${TMPDIR:-/tmp}/gvm-index.XXXXXX")"
gvm_test_cleanup_add 'rm -f "$json" "$tsv"'

# Deliberately compact: the parser follows brace depth, not indentation.
cat > "$json" <<'JSON'
[
  {
    "version": "go1.24.13",
    "stable": true,
    "files": [
      {"filename": "go1.24.13.src.tar.gz", "os": "", "arch": "", "version": "go1.24.13", "sha256": "aaa1", "size": 30802752, "kind": "source"},
      {"filename": "go1.24.13.linux-amd64.tar.gz", "os": "linux", "arch": "amd64", "version": "go1.24.13", "sha256": "bbb2", "size": 78709986, "kind": "archive"},
      {"filename": "go1.24.13.darwin-arm64.tar.gz", "os": "darwin", "arch": "arm64", "version": "go1.24.13", "sha256": "ccc3", "size": 67600000, "kind": "archive"},
      {"filename": "go1.24.13.windows-amd64.msi", "os": "windows", "arch": "amd64", "version": "go1.24.13", "sha256": "ddd4", "size": 1, "kind": "installer"}
    ]
  },
  {
    "version": "go1.25.0rc1",
    "stable": false,
    "files": [
      {"filename": "go1.25.0rc1.linux-amd64.tar.gz", "os": "linux", "arch": "amd64", "version": "go1.25.0rc1", "sha256": "eee5", "size": 78000000, "kind": "archive"}
    ]
  },
  {
    "version": "go1.4.3",
    "stable": true,
    "files": []
  }
]
JSON

awk -f "$GVM_ROOT/scripts/function/_gvm_index_parse.awk" "$json" > "$tsv"
export GVM_INDEX_FILE="$tsv"

record() { grep -m1 "	$1	" "$tsv" | tr '\t' '|'; }

t "every release gets a record, including one with no files"
assert_eq 3 "$(grep -c '^V	' "$tsv")"
assert_eq "V|go1.24.13|stable" "$(grep -m1 '^V	go1.24.13	' "$tsv" | tr '\t' '|')"
assert_eq "V|go1.25.0rc1|unstable" "$(grep -m1 '^V	go1.25.0rc1	' "$tsv" | tr '\t' '|')"
assert_eq "V|go1.4.3|stable" "$(grep -m1 '^V	go1.4.3	' "$tsv" | tr '\t' '|')"

t "installer files are indexed out; gvm never installs one"
assert_eq 4 "$(grep -c '^F	' "$tsv")"
assert_not_contains "$(cat "$tsv")" "windows-amd64.msi"

t "os and arch are empty for a source tarball"
assert_eq "F|go1.24.13|go1.24.13.src.tar.gz|||source|30802752|aaa1" "$(record go1.24.13.src.tar.gz)"

t "gvm_index_file_for finds the linux/amd64 archive with its checksum"
assert_eq "go1.24.13.linux-amd64.tar.gz 78709986 bbb2" \
	"$(gvm_index_file_for go1.24.13 linux amd64 archive)"

t "gvm_index_file_for finds the source when os and arch are empty"
assert_eq "go1.24.13.src.tar.gz 30802752 aaa1" "$(gvm_index_file_for go1.24.13 '' '' source)"

t "gvm_index_file_for returns nothing for an unpublished platform"
assert_eq "" "$(gvm_index_file_for go1.24.13 plan9 sparc archive)"

t "gvm_index_file_for returns nothing for a release with no files"
assert_eq "" "$(gvm_index_file_for go1.4.3 linux amd64 archive)"

t "gvm_index_has_binary"
assert_ok "" gvm_index_has_binary go1.24.13 linux amd64
assert_fail "" gvm_index_has_binary go1.4.3 linux amd64

t "gvm_index_versions filters by stability"
assert_eq "go1.4.3 go1.24.13" "$(gvm_index_versions stable | tr '\n' ' ' | sed 's/ $//')"
assert_eq "go1.25.0rc1" "$(gvm_index_versions prerelease)"
assert_eq 3 "$(gvm_index_versions all | wc -l | tr -d ' ')"

t "gvm_index_versions honours a glob, newest last"
assert_eq "go1.24.13" "$(gvm_index_versions all 'go1.24*')"
assert_eq "" "$(gvm_index_versions all 'go1.99*')"

t "gvm_index_latest prefers the newest overall, latest_stable ignores rc"
assert_eq go1.25.0rc1 "$(gvm_index_latest)"
assert_eq go1.24.13 "$(gvm_index_latest_stable)"

t "gvm_index_is_stable"
assert_ok "" gvm_index_is_stable go1.24.13
assert_fail "" gvm_index_is_stable go1.25.0rc1

t "gvm_index_has_release"
assert_ok "" gvm_index_has_release go1.4.3
assert_fail "" gvm_index_has_release go1.99.0

t "gvm_index_release_count"
assert_eq 3 "$(gvm_index_release_count)"

t "a pinned GVM_INDEX_FILE that does not exist is an error, not a fetch"
GVM_INDEX_FILE=/nonexistent/releases.tsv gvm_index_refresh 2> /dev/null
assert_ne 0 "$?"

t "a malformed index is rejected rather than half-parsed"
bad="$(mktemp "${TMPDIR:-/tmp}/gvm-bad.XXXXXX")"
printf '[{"version":"go1.9.0","stable":true}]' > "$bad"
assert_fail "" env GVM_INDEX_FILE="$bad" gvm_index_refresh
rm -f "$bad"

summary
