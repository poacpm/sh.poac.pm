#!/bin/bash

# Copyright 2016 The Rust Project Developers. See the COPYRIGHT
# file at the top-level directory of this distribution and at
# http://rust-lang.org/COPYRIGHT.
#
# Licensed under the Apache License, Version 2.0 <LICENSE-APACHE or
# http://www.apache.org/licenses/LICENSE-2.0> or the MIT license
# <LICENSE-MIT or http://opensource.org/licenses/MIT>, at your
# option. This file may not be copied, modified, or distributed
# except according to those terms.

set -u

usage() {
    cat 1>&2 <<EOF
poac-setup 0.0.5
An installer for poac

USAGE:
    poac-setup [OPTIONS]

OPTIONS:
    -h, --help              Prints help information
EOF
}

main() {
    need_cmd uname
    need_cmd mktemp
    need_cmd chmod
    need_cmd mkdir
    need_cmd rm
    # Build requirements
    need_cmd cmake
    need_cmd make

    parse_args $@

    local _arch="$(get_architecture)"
    case "$_arch" in

        x86_64-apple-darwin)
            say "This set-up script will install as a HEAD formula from the master branch because Poac is currently in development, and all previous releases are broken due to breaking changes."
            ensure brew install --HEAD poacpm/tap/poac
            ;;

        *)
            err "Poac is not yet supported except for macOS. Please build Poac manually following https://github.com/poacpm/poac#manual-install-build."

    esac
}

parse_args() {
    # check if we have to use /dev/tty to prompt the user
    local need_tty=yes
    for arg in "$@"; do
        case "$arg" in
            -h|--help)
                usage
                exit 0
                ;;
            -y)
                # user wants to skip the prompt -- we don't need /dev/tty
                need_tty=no
                ;;
            *)
                ;;
        esac
    done
}

get_architecture() {
    local _ostype="$(uname -s)"
    local _cputype="$(uname -m)"

    if [ "$_ostype" = Linux ]; then
        if [ "$(uname -o)" = Android ]; then
            local _ostype=Android
        fi
    fi

    if [ "$_ostype" = Darwin -a "$_cputype" = i386 ]; then
        # Darwin `uname -s` lies
        if sysctl hw.optional.x86_64 | grep -q ': 1'; then
            local _cputype=x86_64
        fi
    fi

    case "$_ostype" in

        Android)
            local _ostype=linux-android
            ;;

        Linux)
            local _ostype=unknown-linux-gnu
            ;;

        FreeBSD)
            local _ostype=unknown-freebsd
            ;;

        NetBSD)
            local _ostype=unknown-netbsd
            ;;

        DragonFly)
            local _ostype=unknown-dragonfly
            ;;

        Darwin)
            local _ostype=apple-darwin
            ;;

        MINGW* | MSYS* | CYGWIN*)
            local _ostype=pc-windows-gnu
            ;;

        *)
            err "unrecognized OS type: $_ostype"
            ;;

    esac

    case "$_cputype" in

        i386 | i486 | i686 | i786 | x86)
            local _cputype=i686
            ;;

        xscale | arm)
            local _cputype=arm
            if [ "$_ostype" = "linux-android" ]; then
                local _ostype=linux-androideabi
            fi
            ;;

        armv6l)
            local _cputype=arm
            if [ "$_ostype" = "linux-android" ]; then
                local _ostype=linux-androideabi
            else
                local _ostype="${_ostype}eabihf"
            fi
            ;;

        armv7l | armv8l)
            local _cputype=armv7
            if [ "$_ostype" = "linux-android" ]; then
                local _ostype=linux-androideabi
            else
                local _ostype="${_ostype}eabihf"
            fi
            ;;

        aarch64)
            local _cputype=aarch64
            ;;

        x86_64 | x86-64 | x64 | amd64)
            local _cputype=x86_64
            ;;

        mips)
            local _cputype="$(get_endianness $_cputype "" 'el')"
            ;;

        mips64)
            local _bitness="$(get_bitness)"
            if [ $_bitness = "32" ]; then
                if [ $_ostype = "unknown-linux-gnu" ]; then
                    # 64-bit kernel with 32-bit userland
                    # endianness suffix is appended later
                    local _cputype=mips
                fi
            else
                # only n64 ABI is supported for now
                local _ostype="${_ostype}abi64"
            fi

            local _cputype="$(get_endianness $_cputype "" 'el')"
            ;;

        ppc)
            local _cputype=powerpc
            ;;

        ppc64)
            local _cputype=powerpc64
            ;;

        ppc64le)
            local _cputype=powerpc64le
            ;;

        *)
            err "unknown CPU type: $_cputype"

    esac

    # Detect 64-bit linux with 32-bit userland
    if [ $_ostype = unknown-linux-gnu -a $_cputype = x86_64 ]; then
        if [ "$(get_bitness)" = "32" ]; then
            local _cputype=i686
        fi
    fi

    # Detect armv7 but without the CPU features Rust needs in that build,
    # and fall back to arm.
    # See https://github.com/rust-lang-nursery/rustup.rs/issues/587.
    if [ $_ostype = "unknown-linux-gnueabihf" -a $_cputype = armv7 ]; then
        if ensure grep '^Features' /proc/cpuinfo | grep -q -v neon; then
            # At least one processor does not have NEON.
            local _cputype=arm
        fi
    fi

    local _arch="$_cputype-$_ostype"

    # Return value
    echo -n "$_arch"
}

say() {
    echo "poac-setup: $@"
}

say_err() {
    say "$@" >&2
}

err() {
    say "$@" >&2
    exit 1
}

need_cmd() {
    if ! check_cmd "$1"; then
        err "need '$1' (command not found)"
    fi
}

need_ok() {
    if [ $? != 0 ]; then err "$1"; fi
}

# Run a command that should never fail. If the command fails execution
# will immediately terminate with an error showing the failing
# command.
ensure() {
    "$@"
    need_ok "command failed: $*"
}

check_cmd() {
    command -v "$1" >/dev/null 2>&1
    return $?
}

main "$@" || exit 1
