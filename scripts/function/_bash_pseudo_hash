# bash_pseudo_hash.sh
#
# shellcheck shell=bash
# vi: set ft=bash
#
# Implements "fake" associative arrays suitable for use with bash(1) versions
# that precede 4.0 (with native hash table support) and zsh(1).
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

# source once and only once!
[[ ${BASH_PSEUDO_HASH:-} -eq 1 ]] && return || readonly BASH_PSEUDO_HASH=1

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
# <pre>@textblock
#   hash=()
#   key1="Phrase1"
#   val1="1000 pounds of spaghetti"
#   key2="Phrase2"
#   val2="And a bottle of beer."
#   hash=( $(setValueForKeyFakeAssocArray "${key1}" "${val1}" "${hash[*]}") )
#   hash=( $(setValueForKeyFakeAssocArray "${key2}" "${val2}" "${hash[*]}") )
# @/textblock</pre>
# @param target_key Key to retrieve
# @param new_value New or updated value
# @param target_ary Indexed array to scan
# @return Returns new array with updated key (status 0) or an empty array
#   (status 1) on failure.
# */
setValueForKeyFakeAssocArray()
{
    # parameter list supports empty arguments!
    local target_key="$1"; shift
    local new_value="$1"; shift # @todo: need to support setting nil values!
    local target_ary; target_ary=()
    local defaultIFS="$IFS"
    local IFS="$defaultIFS"
    local found=false

    IFS=$' ' target_ary=( $(printf "%s" "${1}") ) IFS="$defaultIFS"

    [[ -z "${target_key}" ]] && echo "" && return 1

    local _target_ary_length=${#target_ary[@]}
    local _encoded_new_value="$(_encode "${new_value}")"
    local i
    for (( i=0; i<${_target_ary_length}; i++ ))
    do
        local __val="${target_ary[i]}"

        if [[ "${__val%%:*}" == "${target_key}" ]]
        then
            target_ary[$i]="${__val%%:*}:${_encoded_new_value}"
            found=true
            break
        fi

        unset __val
    done
    unset i _target_ary_length

    # key not found, append
    [[ "${found}" == false ]] && target_ary+=( "${target_key}:${_encoded_new_value}" )

    printf "%s" "${target_ary[*]}"

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
# <pre>@textblock
#   hash=() # hash returned previously by setValueForKeyFakeAssocArray()
#   key1="Phrase1"
#   key2="Phrase2"
#   val1="$(valueForKeyFakeAssocArray "${key1}" "${hash[*]}")"
#   val2="$(valueForKeyFakeAssocArray "${key2}" "${hash[*]}")"
# @/textblock</pre>
# @param target_key Key to retrieve
# @param target_ary Indexed array to scan
# @return Returns string containing value (status 0) or an empty string
#   (status 1) on failure.
# */
valueForKeyFakeAssocArray()
{
    local target_key="$1"
    local target_ary; target_ary=()
    local defaultIFS="$IFS"
    local IFS="$defaultIFS"
    local value=""

    IFS=$' ' target_ary=( $(printf "%s" "${2}") ) IFS="$defaultIFS"

    [[ -z "${target_key}" || ${#target_ary[@]} -eq 0 ]] && echo "" && return 1

    local _item
    for _item in "${target_ary[@]}"
    do
        if [[ "${_item%%:*}" == "${target_key}" ]]
        then
          value="$(_decode "${_item#*:}")" # @todo: need to support returning nil values!
          break
        fi
    done
    unset _item

    printf "%b" "${value}"

    return 0
}

# keysForFakeAssocArray()
# /*!
# @abstract Returns list of keys in fake associative array
# @discussion
# Iterates over target_ary (an indexed array) and extracts key component from
#   each element.
# @param target_ary Indexed array to scan
# @return Returns string of space separated keys (status 0) or an empty string
#   (status 1) on failure.
# */
keysForFakeAssocArray() {
    local target_ary; target_ary=()
    local target_ary_keys; target_ary_keys=()
    local defaultIFS="$IFS"
    local IFS="$defaultIFS"

    IFS=$' ' target_ary=( $(printf "%s" "${1}") ) IFS="$defaultIFS"

    [[ ${#target_ary[@]} -eq 0 ]] && echo "" && return 1

    local _item
    for _item in "${target_ary[@]}"
    do
        _item=$_item
        target_ary_keys+=( "${_item%%:*}" )
    done
    unset _item

    printf "%s" "${target_ary_keys[*]}"

    if [[ "${#target_ary_keys[@]}" -eq 0 ]]
    then
        return 1
    fi

    return 0
}

# prettyDumpFakeAssocArray()
# /*!
# @abstract Output a pretty-printed dump of fake associative array contents
# @discussion
# Iterates over target_ary (an indexed array) and extracts keys and values from
#   each element. Pretty prints the output in the following format:
# <pre>@textblock
#   [key]: value
# /@textblock</pre>
# @param target_ary Indexed array to scan
# @return Returns formatted string of key/values (status 0) or an empty string
#   (status 1) on failure.
# */
prettyDumpFakeAssocArray() {
    local target_ary; target_ary=()
    local defaultIFS="$IFS"
    local IFS="$defaultIFS"

    IFS=$' ' target_ary=( $(printf "%s" "${1}") ) IFS="$defaultIFS"

    [[ ${#target_ary[@]} -eq 0 ]] && echo "" && return 1

    local _item
    for _item in "${target_ary[@]}"
    do
        local __key="${_item%%:*}"
        local __val="$(valueForKeyFakeAssocArray "${__key}" "${target_ary[*]}")"
        printf "  [%s]: %s\n" "${__key}" "${__val}"
        unset __key __val
    done
    unset _item
}

# _encode()
# /*!
# @internal
# */
_encode()
{
    local string="$1"
    local new_string=""
    local LC_COLLATE=C

    [[ -z "${string}" ]] && echo "" && return 1

    local _string_len=${#string}
    local i
    for (( i = 0; i<${_string_len}; i++ ))
    do
        local __char="${string:$i:1}"
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

    printf "%s" "${new_string}"

    if [[ -z "${new_string}" ]]
    then
        return 1
    fi

    return 0
}

# _decode()
# /*!
# @internal
# */
_decode()
{
    local string="$1"
    local new_string

    [[ -z "${string}" ]] && echo "" && return 1

    new_string="$(printf '%b' "${string//%/\\x}")"
    printf "%b" "${new_string}"

    if [[ -z "${new_string}" ]]
    then
        return 1
    fi

    return 0
}
