set -euo pipefail

# Xcode runs build phases in a non-login shell, so Cargo/Rustup may not be on PATH.
export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:/usr/local/bin:${PATH:-/usr/bin:/bin:/usr/sbin:/sbin}"
if [ -f "$HOME/.cargo/env" ]; then
    # shellcheck disable=SC1090
    . "$HOME/.cargo/env"
fi

if ! command -v cargo >/dev/null 2>&1; then
    echo "cargo not found; install Rust or add cargo to PATH" >&2
    exit 127
fi

if ! command -v rustup >/dev/null 2>&1; then
    echo "rustup not found; install Rust or add rustup to PATH" >&2
    exit 127
fi

MY_CRATE=rustylib
SWIFT_APP=swiftyapp
SWIFT_PROJECT=swiftyrustlib
SWIFT_PROJECT_NAME=RustyLib
SWIFT_CORE_NAME=RustyCore
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$SCRIPT_DIR/$MY_CRATE"

rm -rf out "${MY_CRATE}_framework.xcframework"

# step 1 - compile rust library and generate bindings
HEADERPATH="$PWD/out/${MY_CRATE}FFI.h"
TARGETDIR="$(cargo metadata --no-deps --format-version 1 | tr -d '\n' | sed -n 's/.*"target_directory":"\([^"]*\)".*/\1/p')"
TARGETDIR="${TARGETDIR:-target}"
RELDIR="release"
STATIC_LIB_NAME="lib${MY_CRATE}.a"
NEW_HEADER_DIR="$PWD/out/include"
XCFRAMEWORK_PATH="$PWD/${MY_CRATE}_framework.$$.xcframework"

case "$(uname -m)" in
    arm64)
        CATALYST_TARGET="aarch64-apple-ios-macabi"
        ;;
    x86_64)
        CATALYST_TARGET="x86_64-apple-ios-macabi"
        ;;
    *)
        echo "Unsupported host architecture: $(uname -m)" >&2
        exit 1
        ;;
esac

targets=("${CATALYST_TARGET}")

for target in "${targets[@]}"; do
    rustup target add ${target}
            cargo build --target "${target}" --release -j8
            cargo run --bin uniffi-bindgen generate --library "${TARGETDIR}/${target}/${RELDIR}/${STATIC_LIB_NAME}" --language swift --out-dir out
        done
# step 2 - create xcframework
mkdir -p "${NEW_HEADER_DIR}"
cp "${HEADERPATH}" "${NEW_HEADER_DIR}/"
cp "$PWD/out/${MY_CRATE}FFI.modulemap" "${NEW_HEADER_DIR}/module.modulemap"

rm -rf "${XCFRAMEWORK_PATH}"

xcodebuild -create-xcframework \
    -library "${TARGETDIR}/${CATALYST_TARGET}/${RELDIR}/${STATIC_LIB_NAME}" -headers "${NEW_HEADER_DIR}" \
    -output "${XCFRAMEWORK_PATH}"

rm -rf "${NEW_HEADER_DIR}"

cd "$SCRIPT_DIR"

SWIFT_LIB_PATH="$SCRIPT_DIR/${SWIFT_APP}/Lib/${SWIFT_PROJECT}"
SWIFT_ARTIFACTS_PATH="${SWIFT_LIB_PATH}/artifacts"
SWIFT_SOURCES_PATH="${SWIFT_LIB_PATH}/Sources/${SWIFT_PROJECT_NAME}"

# step 3 - move to SwiftLib artifacts
mkdir -p "${SWIFT_ARTIFACTS_PATH}"
rm -rf "${SWIFT_ARTIFACTS_PATH}/${SWIFT_CORE_NAME}.xcframework"
cp -R "${XCFRAMEWORK_PATH}" "${SWIFT_ARTIFACTS_PATH}/${SWIFT_CORE_NAME}.xcframework"

rm -rf "${XCFRAMEWORK_PATH}"

# step 4 - move to SwiftLib Sources
mkdir -p "${SWIFT_SOURCES_PATH}"
cp "$SCRIPT_DIR/$MY_CRATE/out/${MY_CRATE}.swift" "${SWIFT_SOURCES_PATH}/${SWIFT_PROJECT_NAME}.swift"
