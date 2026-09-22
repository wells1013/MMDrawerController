#!/usr/bin/env bash
# lume —— 一键编译 & 运行脚本
# 用法: ./build.sh         编译 release 并运行
# 用法: ./build.sh build   只编译 release
# 用法: ./build.sh run     运行已编译的二进制
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

BINARY=".build/release/lume"

build() {
    echo "==> Checking prerequisites..."
    if ! command -v swift &>/dev/null; then
        echo "ERROR: swift not found. Install Xcode 12.4+ or Command Line Tools:"
        echo "       xcode-select --install"
        exit 1
    fi

    local SWIFT_VER
    SWIFT_VER=$(swift --version 2>&1 | head -1)
    echo "==> $SWIFT_VER"
    echo "==> Target macOS: 12.0+    Arch: x86_64 (Intel)"
    echo ""
    echo "==> swift build -c release"

    # macOS 12 + Intel x86_64 架构显式指定，避免 Rosetta/Apple Silicon 混淆
    swift build -c release -Xlinker -arch -Xlinker x86_64

    echo ""
    echo "==> Build succeeded: $BINARY"
    ls -lh "$BINARY"
}

run() {
    if [ ! -f "$BINARY" ]; then
        echo "Binary not found, building first..."
        build
    fi
    echo "==> Launching lume (Ctrl+C to stop)..."
    "$BINARY"
}

case "${1:-run}" in
    build) build ;;
    run)   run ;;
    *)     echo "Usage: $0 [build|run]" ; exit 1 ;;
esac
