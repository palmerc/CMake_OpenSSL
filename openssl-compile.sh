#!/bin/bash

XCODE_SDK="$1"
TARGET_ARCHITECTURE="$2"
SOURCE_DIR="$3"
INSTALL_DIR="$4"
BUILD_SHARED="$5"
BITCODE_ENABLED="$6"
OPENSSL_CFLAGS_FILE="$7"
OPENSSL_OPTIONS_FILE="$8"

PLATFORM_LIBRARY_PREFIX="lib"
STATIC_LIBRARY_SUFFIX=".a"
SHARED_LIBRARY_SUFFIX=".dylib"
OPENSSL_MODULES=( "crypto" "ssl" )
CONFIGURE_SWITCH="iphoneos-cross"
NCPU=8

OPENSSL_LIBRARIES=()
for OPENSSL_MODULE in "${OPENSSL_MODULES[@]}"; do
    OPENSSL_LIBRARIES+=( "${PLATFORM_LIBRARY_PREFIX}${OPENSSL_MODULE}${STATIC_LIBRARY_SUFFIX}" )
    if [ "${BUILD_SHARED}" ]; then
        OPENSSL_LIBRARIES+=( "${PLATFORM_LIBRARY_PREFIX}${OPENSSL_MODULE}${SHARED_LIBRARY_SUFFIX}" )
    fi
done

echo "OpenSSL ${TARGET_ARCHITECTURE} - locating build tools"
XCODE_SDK_PATH=$( xcrun --sdk "${XCODE_SDK}" --show-sdk-path )
XCODE_SDK_PLATFORM_PATH=$( xcrun --sdk "${XCODE_SDK}" --show-sdk-platform-path )
XCODE_CLANG=$( xcrun --sdk "${XCODE_SDK}" --find clang )
XCODE_RANLIB=$( xcrun --sdk "${XCODE_SDK}" --find ranlib )

echo "OpenSSL ${TARGET_ARCHITECTURE} - setting results directory"
pushd "${INSTALL_DIR}" || exit
INSTALL_DIR=$( pwd )
popd || exit

echo "OpenSSL ${TARGET_ARCHITECTURE} - setting source directory"
pushd "${SOURCE_DIR}" || exit
SOURCE_DIR=$( pwd )

echo "OpenSSL ${TARGET_ARCHITECTURE} - sourcing options"
export CFLAGS
CFLAGS=$( < "${OPENSSL_CFLAGS_FILE}" )
if [ "${BITCODE_ENABLED}" ]; then
    CFLAGS+=( "-fembed-bitcode" )
fi
if [ ! "${BUILD_SHARED}" ]; then
    CFLAGS+=( "-fvisibility=hidden" )
    CFLAGS+=( "-fvisibility-inlines-hidden" )
fi

OPTIONS=$( < "${OPENSSL_OPTIONS_FILE}" )
if [ "${BUILD_SHARED}" ]; then
    OPTIONS+=( "shared" )
fi

export CC
CC="${XCODE_CLANG} ${CFLAGS[*]}"
export RANLIB
RANLIB="${XCODE_RANLIB}"

export CROSS_TOP
CROSS_TOP="${XCODE_SDK_PLATFORM_PATH}/Developer"

export CROSS_SDK
CROSS_SDK=$( basename "${XCODE_SDK_PATH}" )

echo "OpenSSL ${TARGET_ARCHITECTURE} - patching"
export LC_ALL=C
sed -ie 's/"iphoneos-cross","llvm-gcc:-O3/"iphoneos-cross","clang:-O3/g' 'Configure'
sed -ie 's/CC= cc/CC= clang/g' 'Makefile.org'
sed -ie 's/CFLAG= -O/CFLAG= -O3/g' 'Makefile.org'
sed -ie 's/MAKEDEPPROG=makedepend/MAKEDEPPROG=$(CC) -M/g' 'Makefile.org'

if [[ "${TARGET_ARCHITECTURE}" == armv7* ]]; then
    sed -ie 's/ *-fomit-frame-pointer */ /' 'Configure'
    sed -ie 's/ *-fomit-frame-pointer */ /' 'Configuree'
fi


echo "OpenSSL ${TARGET_ARCHITECTURE} - configuring"

CONFIGURE_COMMAND="${SOURCE_DIR}/Configure ${CONFIGURE_SWITCH} ${OPTIONS[*]} --prefix=${INSTALL_DIR} --openssldir=${INSTALL_DIR}"
echo "${CONFIGURE_COMMAND}"
eval "${CONFIGURE_COMMAND}"

echo "OpenSSL ${TARGET_ARCHITECTURE} - building"

make depend
make -j"${NCPU}" build_libcrypto build_libssl

LIB_INSTALL_DIR="${INSTALL_DIR}/lib"
INCLUDE_INSTALL_DIR="${INSTALL_DIR}/include"
mkdir -p "${LIB_INSTALL_DIR}"
mkdir -p "${INCLUDE_INSTALL_DIR}"

echo "OpenSSL ${TARGET_ARCHITECTURE} - validating and installing"
OPENSSL_INCLUDE_DIR="${SOURCE_DIR}/include"
SUCCESS=1
for OPENSSL_LIBRARY in "${OPENSSL_LIBRARIES[@]}"; do
    OPENSSL_LIBRARY_PATH=$( find "${SOURCE_DIR}" -name "${OPENSSL_LIBRARY}" -print | head -n 1 )
    lipo "${OPENSSL_LIBRARY_PATH}" -verify_arch "${TARGET_ARCHITECTURE}"
    SUCCESS=$?
    if [ "${SUCCESS}" -ne 0 ]; then
        break
    fi

    cp "${OPENSSL_LIBRARY_PATH}" "${LIB_INSTALL_DIR}"
done
cp -LR "${OPENSSL_INCLUDE_DIR}/" "${INCLUDE_INSTALL_DIR}/"

RESULT="success"
if [ "${SUCCESS}" -ne 0 ]; then
    RESULT="failure"
fi
echo "OpenSSL ${TARGET_ARCHITECTURE} - ${RESULT}"

popd || exit

exit "${SUCCESS}"
