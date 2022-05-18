#!/bin/bash

RELEASE_DIR=$1
ANDROID_NDK_ROOT=$2
OPENSSL_ROOT=$3
ANDROID_ABI=$4
API_LEVEL=$5

if [[ -z $SAIPM_BUILD_MODE ]]; then
    echo "Value of 'SAIPM_BUILD_MODE' is not set"
    exit 1
else
    BUILD_MODE=$SAIPM_BUILD_MODE # set by saipm
fi

echo "Release Dir: $RELEASE_DIR"
echo "Android NDK Root: $ANDROID_NDK_ROOT"
echo "OpenSSL Root: $OPENSSL_ROOT"

WORK_ROOT=$(pwd)
echo "Work root: $WORK_ROOT"

# CPU count for parallel build
if [[ "$OSTYPE" == "darwin"* ]]; then
    NCPU=$(($(sysctl -n hw.ncpu) - 1))
else
    NCPU=$(($(nproc) - 1))
fi
if [ $NCPU -le 0 ]; then
    NCPU=1
fi
echo "Parallel Jobs: $NCPU"

# Initialize android specific configs
ANDROID_STL=c++_static # c++, gnustl, stlport, system, none
echo "Android STL: $ANDROID_STL"
echo

case $ANDROID_ABI in
arm64-v8a | armeabi-v7a)
    echo "Building for $ANDROID_ABI ..."
    ;;
*)
    echo "Unknown abi. Try arm64-v8a|armeabi-v7a"
    ;;
esac

DEBUG_ACCESS=0
if [[ "$BUILD_MODE" == "Debug" ]]; then
    DEBUG_ACCESS=1
fi

echo "Created new build directory..."
BUILD_DIR=${RELEASE_DIR}.android
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

set -x
cmake \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake" \
    -DCMAKE_ANDROID_NDK="$ANDROID_NDK_ROOT" \
    -DCMAKE_ANDROID_ARCH_ABI=$ANDROID_ABI \
    -DANDROID_NDK="$ANDROID_NDK_ROOT" \
    -DANDROID_ABI=$ANDROID_ABI \
    -DANDROID_PLATFORM=android-$API_LEVEL \
    -DANDROID_NATIVE_API_LEVEL=$API_LEVEL \
    -DCMAKE_SYSTEM_VERSION=$API_LEVEL \
    -DANDROID_STL=$ANDROID_STL \
    -DCMAKE_ANDROID_STL_TYPE=$ANDROID_STL \
    -DANDROID_TOOLCHAIN=clang \
    -DCMAKE_SYSTEM_NAME=Android \
    -DCMAKE_BUILD_TYPE=$BUILD_MODE \
    -DANDROID=1 \
    -DOPENSSL_ROOT_DIR="$OPENSSL_ROOT" \
    -DOPENSSL_INCLUDE_DIR="$OPENSSL_ROOT"/include \
    -DOPENSSL_CRYPTO_LIBRARY="$OPENSSL_ROOT/$ANDROID_ABI/lib/libcrypto.a" \
    -DOPENSSL_SSL_LIBRARY="$OPENSSL_ROOT/$ANDROID_ABI/lib/libssl.a" \
    -DUSE_NICE=0 \
    -DNO_WEBSOCKET=ON \
    -DNO_MEDIA=ON \
    "$WORK_ROOT"
RET_CODE=$?

set +x
if [[ $RET_CODE -ne 0 ]]; then
    exit $RET_CODE
else
    echo "[libdatachannel] cmake... Done."
fi

set -x
make -j$NCPU
RET_CODE=$?
set +x
if [[ $RET_CODE -ne 0 ]]; then
    exit $RET_CODE
else
    echo "[libdatachannel] make... Done."
fi
echo

echo "Copying files to release directory..."
LIBRARY_DIR=$RELEASE_DIR/lib/$ANDROID_ABI
INCLUDE_DIR=$RELEASE_DIR/include
mkdir -p "$RELEASE_DIR" "$LIBRARY_DIR" "$INCLUDE_DIR"

cp -r "$WORK_ROOT/include/rtc" "$INCLUDE_DIR"
cp "$BUILD_DIR/libdatachannel.so" "$LIBRARY_DIR"

touch "$RELEASE_DIR/API_level_$API_LEVEL"

echo "done"
