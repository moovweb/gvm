#!/usr/bin/env bash
# How gvm talks to the user: prefixes, streams, and exit statuses.
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
gvm_test_sandbox go1.24.13
trap gvm_test_sandbox_teardown EXIT

t "errors always say ERROR, whatever TERM is"
# The old helpers only printed the prefix when TERM was exactly "xterm", so in
# tmux, in screen, or under TERM=xterm-256color a warning looked like output.
for term in dumb xterm xterm-256color screen ""; do
	out="$(TERM="$term" NO_COLOR=1 display_error "boom" 2>&1)"
	assert_contains "$out" "ERROR: boom"
done

t "warnings always say WARNING, whatever TERM is"
for term in dumb xterm xterm-256color screen ""; do
	out="$(TERM="$term" NO_COLOR=1 display_warning "careful" 2>&1)"
	assert_contains "$out" "WARNING: careful"
done

t "warnings survive TERM being unset entirely"
out="$(unset TERM; NO_COLOR=1 display_warning "careful" 2>&1)"
assert_contains "$out" "WARNING: careful"

t "NO_COLOR removes the colour but keeps the prefix"
out="$(NO_COLOR=1 display_warning "careful" | cat -v)"
assert_contains "$out" "WARNING: careful"
assert_not_contains "$out" "^[["

t "GVM_NO_COLORS does the same"
out="$(GVM_NO_COLORS=1 display_warning "careful" | cat -v)"
assert_contains "$out" "WARNING: careful"
assert_not_contains "$out" "^[["

t "display_warning returns 0"
# It used to return 1, so `[ -n "$x" ] && display_warning "..."` failed quietly
# and warnings vanished from the middle of functions.
display_warning "careful" && _pass || _fail "display_warning returned non-zero"
( display_warning "careful" ) && _pass || _fail "subshell saw non-zero"

t "display_message returns 0"
display_message "hello" && _pass || _fail "display_message returned non-zero"
( display_message "hello" ) && _pass || _fail "subshell saw non-zero"

t "display_error returns 1"
display_error "boom" 2> /dev/null && _fail "display_error returned 0" || _pass

t "display_fatal exits 1"
( display_fatal "boom" 2> /dev/null ) && _fail "display_fatal did not exit" || _pass

t "errors go to stderr, so captured stdout stays machine-readable"
out="$(display_error "boom" 2> /dev/null)"
assert_eq "" "$out"
assert_contains "$(display_error "boom" 2>&1)" "ERROR: boom"

t "messages go to stdout"
out="$(display_message "hello" 2> /dev/null)"
assert_eq "hello" "$out"

t "a multi-line message keeps its newlines"
out="$(display_message "one
two")"
assert_eq "one
two" "$out"

t "display helpers work with GVM_ROOT unset"
# They source _display_colors, which used to be a plain file; a wrong GVM_ROOT
# must not stop gvm from reporting a problem.
out="$(unset GVM_ROOT; NO_COLOR=1 display_message "hello" 2>&1)"
assert_contains "$out" "hello"

t "a gvm install failure is reported, not swallowed"
capture out gvm install 9.9.9
assert_ne 0 "$CAPTURE_STATUS"
assert_contains "$out" "9.9.9"

t "help output has no stray colour escapes when piped"
out="$(gvm help 2>&1 | cat -v)"
assert_not_contains "$out" "^[["

t "gvm ls output is plain when piped"
out="$(gvm ls 2>&1 | cat -v)"
assert_not_contains "$out" "^[["

summary
