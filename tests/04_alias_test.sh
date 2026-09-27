#!/usr/bin/env bash
# Aliases: creation, chains, cycles, built-ins, the default.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
gvm_test_sandbox go1.24.13 go1.27.1
trap gvm_test_sandbox_teardown EXIT

tsv="$(mktemp "${TMPDIR:-/tmp}/gvm-index.XXXXXX")"
gvm_test_cleanup_add 'rm -f "$tsv"'
cat > "$tsv" <<'TSV'
V	go1.24.13	stable
V	go1.27.1	stable
V	go1.28.0rc1	unstable
V	go1.5.4	stable
TSV
export GVM_INDEX_FILE="$tsv"

t "creating and resolving a simple alias"
assert_ok "" gvm_alias_create work go1.24.13
assert_eq go1.24.13 "$(gvm_alias_resolve work)"
assert_eq go1.24.13 "$(gvm_alias_raw work)"

t "aliases chain"
assert_ok "" gvm_alias_create daily work
assert_eq go1.24.13 "$(gvm_alias_resolve daily)"

t "gvm_alias_list is sorted and complete"
assert_eq "daily work" "$(gvm_alias_list | tr '\n' ' ' | sed 's/ $//')"

t "a chain that loops is reported, not followed forever"
gvm_alias_create a b 2> /dev/null
assert_fail "" gvm_alias_create b a
assert_eq "" "$(gvm_alias_raw b)"
assert_eq b "$(gvm_alias_raw a)"
gvm_alias_delete a > /dev/null
gvm_alias_delete b > /dev/null 2>&1

t "an alias cannot point at itself"
assert_fail "" gvm_alias_create loop loop
assert_eq "" "$(gvm_alias_raw loop)"

t "a reserved name cannot be shadowed by a file"
assert_fail "" gvm_alias_create default go1.24.13

t "deleting an alias leaves its dependants dangling but harmless"
# A dangling alias resolves to its literal target rather than erroring, which
# is what nvm does; the version layer is what rejects it, because nothing by
# that name is installed.
assert_ok "" gvm_alias_delete work
assert_eq work "$(gvm_alias_resolve daily)"
assert_fail "" gvm_resolve_version daily local
assert_eq "" "$(gvm_alias_raw work)"
gvm_alias_delete daily > /dev/null

t "deleting an alias that does not exist fails"
assert_fail "" gvm_alias_delete nosuchalias

t "built-ins track the index"
# latest and stable are deliberately the same thing: nvm's `nvm version` is the
# newest released stable, and a release candidate is never the sensible default.
assert_eq go1.27.1 "$(gvm_alias_resolve stable)"
assert_eq go1.27.1 "$(gvm_alias_resolve latest)"
assert_eq go1.28.0rc1 "$(gvm_alias_resolve unstable)"
assert_eq go1.28.0rc1 "$(gvm_alias_resolve newest)"
assert_eq go1.5.4 "$(gvm_alias_resolve oldest)"

t "the default alias comes from environments/default"
assert_eq "" "$(gvm_default_recorded)"
cp "$GVM_ROOT/environments/go1.24.13" "$GVM_ROOT/environments/default"
assert_eq go1.24.13 "$(gvm_default_recorded)"
assert_eq go1.24.13 "$(gvm_alias_resolve default)"

t "gvm_alias_resolve rejects an unknown name"
assert_fail "" gvm_alias_resolve nosuchalias

t "a user alias may shadow nothing built-in but may be named like a version"
assert_ok "" gvm_alias_create newstable go1.27.1
assert_eq go1.27.1 "$(gvm_alias_resolve newstable)"

summary
