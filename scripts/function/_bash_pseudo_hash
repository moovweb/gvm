# bash_pseudo_hash.sh
#
# -*- Shell-Unix-Generic -*-
#
# Implements "fake" associative arrays suitable for use with bash(1) versions
# that precede 4.0 (with native hash table support).
#
# Author : Mark Eissler (moe@markeissler.org) https://about.me/markeissler
# Website: https://github.com/markeissler/bash-pseudo-hash
#
# The MIT License (MIT)
#
# Copyright (C) 2015-2016 Mark Eissler. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# setValueForKeyFakeAssocArray()
# /*!
# @abstract Set value for key from a fake associative array
# @discussion
# Iterates over target_ary (an indexed array), searching for target_key, if the
#   key is found its value is set to new_value otherwise the target_key and
#   new_value are appended to the array.
#
#   The indexed array values must conform to this format:
#     "key:value"
#   Where key and value are separated by a single colon character.
#
#   Specify empty values as an empty, quoted string.
#
#   So-called "fake" associative arrays are useful for environments where the
#   installed version of bash(1) precedes 4.0.
# @example
#   hash=()
#   key1="Phrase1"
#   val1="1000 pounds of spaghetti"
#   key2="Phrase2"
#   val2="And a bottle of beer."
#   hash=( $(setValueForKeyFakeAssocArray "${key1}" "${val1}" "${hash[*]}") )
#   hash=( $(setValueForKeyFakeAssocArray "${key2}" "${val2}" "${hash[*]}") )
# @param target_key Key to retrieve
# @param new_value New or updated value
# @param target_ary Indexed array to scan
# @return Returns new array with updated key (status 0) or an empty array
#   (status 1) on failure.
# */
setValueForKeyFakeAssocArray() {
    # parameter list supports empty arguments!
    local target_key="$1"; shift
    local new_value="$1"; shift
    local target_ary=()
    local defaultIFS="$IFS"
    local IFS="$defaultIFS"
    local found=false

    IFS=$' ' target_ary=( $1 ) IFS="$defaultIFS"

    [[ -z "${target_key}" ]] && echo "" && return 1

    local _target_ary_length="${#target_ary[@]}"
    local _encoded_new_value="$(_encode "${new_value}")"
    local i
    for (( i=0; i<"${_target_ary_length}"; i++ )); do
        local __val="${target_ary[$i]}"

        if [[ "${__val%%:*}" == "${target_key}" ]]; then
            target_ary[$i]="${__val%%:*}:${_encoded_new_value}"
            found=true
            break
        fi

        unset __val
    done
    unset i _target_ary_length

    # key not found, append
    [[ "${found}" == false ]] && target_ary+=( "${target_key}:${_encoded_new_value}" )

    printf "%s" "${target_ary[*]}"; return 0

    return 0
}

# valueForKeyFakeAssocArray()
# /*!
# @abstract Fetch value for key from a fake associative array
# @discussion
# Iterates over target_ary (an indexed array), searching for target_key, if the
#   key is found its value is returned.
#
#   The indexed array values must conform to this format:
#     "key:value"
#   Where key and value are separated by a single colon character.
#
#   So-called "fake" associative arrays are useful for environments where the
#   installed version of bash(1) precedes 4.0.
# @example
#   hash=() # hash returned previously by setValueForKeyFakeAssocArray()
#   key1="Phrase1"
#   key2="Phrase2"
#   val1="$(valueForKeyFakeAssocArray "${key1}" "${hash[*]}")"
#   val2="$(valueForKeyFakeAssocArray "${key2}" "${hash[*]}")"
# @param target_key Key to retrieve
# @param target_ary Indexed array to scan
# @return Returns string containing value (status 0) or an empty string
#   (status 1) on failure.
# */
valueForKeyFakeAssocArray() {
    local target_key="$1"
    local target_ary=()
    local defaultIFS="$IFS"
    local IFS="$defaultIFS"
    local value=""

    IFS=$' ' target_ary=( $2 ) IFS="$defaultIFS"

    [[ -z "${target_key}" || "${#target_ary[@]}" -eq 0 ]] && echo "" && return 1

    local t
    for t in "${target_ary[@]}"; do
        if [[ "${t%%:*}" == "${target_key}" ]]; then
          value="$(_decode "${t#*:}")"
          break
        fi
    done
    unset t

    echo -e "${value}"; return 0
}

_encode() {
    local string="$1"
    local new_string=""
    local LC_COLLATE=C

    [[ -z "${string}" ]] && echo "" && return 1

    local _string_len="${#string}"
    local i
    for (( i = 0; i<"${_string_len}"; i++ )); do
        local __char="${string:i:1}"
        case $__char in
            [A-Za-z0-9.~_-])
                new_string+="$__char"
                ;;
            *)
                hex="$(echo -n "$__char" | hexdump -e '1 1 "!%02x"')"
                new_string+="${hex//!/%}"
                ;;
        esac
    done
    unset i _string_len

    echo "${new_string}"

    if [[ -z "${new_string}" ]]
    then
        return 1
    fi

    return 0
}

_decode() {
    local string="$1"
    local new_string

    [[ -z "${string}" ]] && echo "" && return 1

    printf -v new_string '%b' "${string//%/\\x}"
    echo -e "${new_string}"

    if [[ -z "${new_string}" ]]
    then
        return 1
    fi

    return 0
}
