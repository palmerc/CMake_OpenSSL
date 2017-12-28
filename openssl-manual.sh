#!/bin/bash

SDK="iphonesimulator"
if [ "${SDK}" == "iphoneos" ]; then
    ARCH="arm64"
else
    ARCH="x86_64"
fi

XCODE_SDK_PATH=$( xcrun --sdk "${SDK}" --show-sdk-path )
XCODE_SDK_PLATFORM_PATH=$( xcrun --sdk "${SDK}" --show-sdk-platform-path )
SYSROOT=$( xcrun -sdk "${SDK}" --show-sdk-path )

export CROSS_SDK
CROSS_SDK=$( basename "${XCODE_SDK_PATH}" )
export CROSS_TOP
CROSS_TOP="${XCODE_SDK_PLATFORM_PATH}/Developer"

export CC
CC="$( xcrun --sdk "${SDK}" --find clang ) -arch ${ARCH}"

export RANLIB
RANLIB=$( xcrun --sdk "${SDK}" --find ranlib )

make distclean
./Configure iphoneos-cross no-asm no-deprecated no-dtls1 no-experimental no-hw no-ssl2 no-ssl3 no-camellia no-cast no-comp no-dso no-engine no-idea no-jpake no-krb5 no-md2 no-md4 no-mdc2 no-rc2 no-rc5 no-ripemd no-seed no-srp no-store no-whirlpool no-tests shared

make depend
make -j8
