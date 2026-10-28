#!/usr/bin/env bash
#
# install_linux.sh - one-shot dependency check, build and install for Linux.
#
# Wraps the CMake workflow described in the README (see "Building using CMake")
# so that a release (or debug/experimental) build can be produced and installed
# with a single command.
#
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SRC_DIR/build"
PREFIX="/usr/local"
BUILD_TYPE="Release"
EXPERIMENTAL="OFF"
JOBS=""
WITH_DEPS="auto"

usage() {
    cat <<'EOF'
install_linux.sh - one-shot dependency check, build and install for Linux.

Wraps the CMake workflow described in the README (see "Building using CMake")
so that a release (or debug/experimental) build can be produced and installed
with a single command:

  ./install_linux.sh                     # release build, install to /usr/local
  ./install_linux.sh --prefix ./install  # release build, installed to ./install
  ./install_linux.sh --debug             # debug build
  ./install_linux.sh --experimental      # experimental build variant

Options:
  --prefix DIR        Installation prefix (default: /usr/local)
  --build-dir DIR     CMake build directory (default: ./build)
  --debug             Build in Debug mode instead of Release
  --experimental      Enable EMU_EXPERIMENTAL_BUILD
  --jobs N            Parallel build jobs (default: number of CPUs)
  --deps              Install missing build dependencies with the system
                      package manager (requires sudo)
  --no-deps           Only check for dependencies, never install them
  -h, --help          Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --prefix)     PREFIX="$2"; shift 2 ;;
        --build-dir)  BUILD_DIR="$2"; shift 2 ;;
        --debug)      BUILD_TYPE="Debug"; shift ;;
        --experimental) EXPERIMENTAL="ON"; shift ;;
        --jobs)       JOBS="$2"; shift 2 ;;
        --deps)       WITH_DEPS="yes"; shift ;;
        --no-deps)    WITH_DEPS="no"; shift ;;
        -h|--help)    usage; exit 0 ;;
        *) echo "error: unknown option '$1'" >&2; usage >&2; exit 1 ;;
    esac
done

[[ -z "$JOBS" ]] && JOBS="$(nproc 2>/dev/null || echo 4)"

# CMake resolves a relative CMAKE_INSTALL_PREFIX against the build directory,
# so make the prefix absolute before using it.
PREFIX="$(realpath -m -- "$PREFIX")"

# ---------------------------------------------------------------------------
# Dependency check (and optional install)
# ---------------------------------------------------------------------------
MISSING=()
for tool in cmake git; do
    command -v "$tool" >/dev/null 2>&1 || MISSING+=("$tool")
done
command -v cc >/dev/null 2>&1 || command -v g++ >/dev/null 2>&1 || MISSING+=("a C++ compiler")
command -v protoc >/dev/null 2>&1 || MISSING+=("protoc")
# protobuf development files: headers plus the library, in the usual system
# locations or under any prefix provided via CMAKE_PREFIX_PATH
PROTOBUF_INC_PATTERNS=(/usr/include/google/protobuf/message.h /usr/local/include/google/protobuf/message.h)
PROTOBUF_LIB_PATTERNS=(/usr/lib/*/libprotobuf.so /usr/lib/*/libprotobuf.a
                       /usr/lib/libprotobuf.so /usr/lib/libprotobuf.a
                       /usr/local/lib/libprotobuf.so /usr/local/lib/libprotobuf.a)
IFS=: read -ra _cxx_prefixes <<< "${CMAKE_PREFIX_PATH:-}"
for _p in "${_cxx_prefixes[@]:-}"; do
    PROTOBUF_INC_PATTERNS+=("$_p/include/google/protobuf/message.h")
    PROTOBUF_LIB_PATTERNS+=("$_p/lib/libprotobuf.so" "$_p/lib/libprotobuf.a"
                            "$_p/lib/*/libprotobuf.so" "$_p/lib/*/libprotobuf.a")
done
_pb_inc=0; _pb_lib=0
for _pat in "${PROTOBUF_INC_PATTERNS[@]}"; do
    for _f in $_pat; do [[ -e "$_f" ]] && _pb_inc=1; done
done
for _pat in "${PROTOBUF_LIB_PATTERNS[@]}"; do
    for _f in $_pat; do [[ -e "$_f" ]] && _pb_lib=1; done
done
if [[ $_pb_inc -eq 0 || $_pb_lib -eq 0 ]]; then
    MISSING+=("libprotobuf development files")
fi

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "error: missing dependencies: ${MISSING[*]}" >&2
    if [[ "$WITH_DEPS" == "no" ]]; then
        exit 1
    fi
    if [[ "$WITH_DEPS" != "yes" ]]; then
        echo "hint: re-run with --deps to install them automatically, or install them manually:" >&2
        echo "      apt:   sudo apt install cmake git build-essential libprotobuf-dev protobuf-compiler" >&2
        echo "      dnf:   sudo dnf install cmake git gcc-c++ protobuf-devel protobuf-compiler" >&2
        echo "      pacman: sudo pacman -S cmake git base-devel protobuf" >&2
        exit 1
    fi
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y cmake git build-essential libprotobuf-dev protobuf-compiler
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y cmake git gcc-c++ protobuf-devel protobuf-compiler
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -Sy --needed --noconfirm cmake git base-devel protobuf
    elif command -v zypper >/dev/null 2>&1; then
        sudo zypper install -y cmake git patterns-devel-base-devel_basis libprotobuf-devel protobuf-cmake protobuf
    else
        echo "error: no supported package manager found (apt/dnf/pacman/zypper)" >&2
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Submodules (stb, ingame_overlay)
# ---------------------------------------------------------------------------
if [[ -d "$SRC_DIR/.git" ]]; then
    git -C "$SRC_DIR" submodule update --init --recursive
fi

# ---------------------------------------------------------------------------
# Configure, build, install
# ---------------------------------------------------------------------------
cmake -S "$SRC_DIR" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DEMU_EXPERIMENTAL_BUILD="$EXPERIMENTAL"

cmake --build "$BUILD_DIR" --parallel "$JOBS"

SUDO=()
if ! mkdir -p -- "$PREFIX" 2>/dev/null || [[ ! -w "$PREFIX" ]]; then
    SUDO=(sudo)
fi
"${SUDO[@]+"${SUDO[@]}"}" cmake --install "$BUILD_DIR"

echo
echo "Installed goldberg emulator to: $PREFIX"
echo "Copy (lib)steam_api(64).so from there next to your game's executable,"
echo "see Readme_release.txt for the full usage instructions."
