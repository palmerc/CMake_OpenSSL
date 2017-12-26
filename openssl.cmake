include( ExternalProject )

set_property( DIRECTORY PROPERTY EP_BASE third_party )

set( OPENSSL_SCRIPTS_DIR ${PROJECT_SOURCE_DIR} )
set( OPENSSL_URL "http://www.openssl.org/source/openssl-1.0.2-latest.tar.gz" )
set( OPENSSL_SHA1 "" )

if( NOT TARGET_ARCHITECTURES_iphoneos )
    set( TARGET_ARCHITECTURES_iphoneos armv7 armv7s arm64 )
endif()
if( NOT TARGET_ARCHITECTURES_iphonesimulator )
    set( TARGET_ARCHITECTURES_iphonesimulator i386 x86_64 )
endif()

set( CONFIGURE_OPTIONS
        no-tests
        no-deprecated
        no-dtls1
        no-experimental
        no-hw
        no-ssl2
        no-ssl3
        no-camellia
        no-cast
        no-comp
        no-dso
        no-engine
        no-idea
        no-jpake
        no-krb5
        no-md2
        no-md4
        no-mdc2
        no-rc2
        no-rc5
        no-ripemd
        no-seed
        no-srp
        no-store
        no-whirlpool )

function( BuildOpenSSL SDK DEBUG_ENABLED BITCODE_ENABLED INSTALL_DIR )

    set( OPENSSL_TARGETS_${SDK} )
    set( OPENSSL_INCLUDES_${SDK} )
    set( OPENSSL_THIN_CRYPTO_LIBRARIES_${SDK} )
    set( OPENSSL_THIN_SSL_LIBRARIES_${SDK} )
    foreach( TARGET_ARCHITECTURE ${TARGET_ARCHITECTURES_${SDK}} )
        set( OPENSSL_TARGET openssl_${TARGET_ARCHITECTURE} )
        set( TARGET_INSTALL_DIR ${INSTALL_DIR}/${TARGET_ARCHITECTURE} )
        message( STATUS "${OPENSSL_TARGET} - ${TARGET_INSTALL_DIR}" )

        execute_process( COMMAND xcrun --sdk ${SDK} --show-sdk-path
                OUTPUT_VARIABLE XCODE_SDK_PATH
                OUTPUT_STRIP_TRAILING_WHITESPACE )

        set ( OPENSSL_CFLAGS )
        list( APPEND OPENSSL_CFLAGS -arch ${TARGET_ARCHITECTURE} )
        list( APPEND OPENSSL_CFLAGS -fvisibility=hidden )
        list( APPEND OPENSSL_CFLAGS -fvisibility-inlines-hidden )
        list( APPEND OPENSSL_CFLAGS -isysroot ${XCODE_SDK_PATH} )
        list( APPEND OPENSSL_CFLAGS -mios-version-min=8.0 )
        if( BITCODE_ENABLED )
            list( APPEND OPENSSL_CFLAGS -fembed-bitcode )
        endif()

        if( DEBUG_ENABLED )
            list( APPEND OPENSSL_CFLAGS -g )
        endif()

        if( TARGET_ARCHITECTURE STREQUAL x86_64 )
            list( APPEND CONFIGURE_OPTIONS no-asm )
        endif()

        string( REPLACE ";" " " OPENSSL_CFLAGS_STRING "${OPENSSL_CFLAGS}" )
        set( OPENSSL_CFLAGS_FILE ${TARGET_INSTALL_DIR}/openssl-cflags )
        file( WRITE ${OPENSSL_CFLAGS_FILE} ${OPENSSL_CFLAGS_STRING} )

        string( REPLACE ";" " " CONFIGURE_OPTIONS_STRING "${CONFIGURE_OPTIONS}" )
        set( OPENSSL_OPTIONS_FILE ${TARGET_INSTALL_DIR}/openssl-options )
        file( WRITE ${OPENSSL_OPTIONS_FILE} ${CONFIGURE_OPTIONS_STRING} )

        ExternalProject_Add( ${OPENSSL_TARGET}
            URL ${OPENSSL_URL}
            BUILD_IN_SOURCE true
            CONFIGURE_COMMAND ""
            BUILD_COMMAND ${OPENSSL_SCRIPTS_DIR}/openssl-compile.sh
            ${SDK}
            ${TARGET_ARCHITECTURE}
            <SOURCE_DIR>
            <INSTALL_DIR>
            ${OPENSSL_CFLAGS_FILE}
            ${OPENSSL_OPTIONS_FILE}
            INSTALL_COMMAND ""
            INSTALL_DIR ${TARGET_INSTALL_DIR} )

        list( APPEND OPENSSL_TARGETS_${SDK} ${OPENSSL_TARGET} )
        list( APPEND OPENSSL_INCLUDES_${SDK} ${TARGET_INSTALL_DIR}/include )
        list( APPEND OPENSSL_THIN_CRYPTO_LIBRARIES_${SDK} ${TARGET_INSTALL_DIR}/lib/libcrypto.a )
        list( APPEND OPENSSL_THIN_SSL_LIBRARIES_${SDK} ${TARGET_INSTALL_DIR}/lib/libssl.a )
    endforeach( TARGET_ARCHITECTURE )

#    set( OPENSSL_LIBCRYPTO_PATH ${INSTALL_DIR}/lib/${OPENSSL_LIBCRYPTO} )
#    LipoLibrary( "${OPENSSL_THIN_CRYPTO_LIBRARIES}" ${OPENSSL_LIBCRYPTO_PATH} )
#
#    set( OPENSSL_LIBSSL_PATH ${INSTALL_DIR}/lib/${OPENSSL_LIBSSL} )
#    LipoLibrary( "${OPENSSL_THIN_SSL_LIBRARIES}" ${OPENSSL_LIBSSL_PATH} )
#
#    add_custom_target( lipo_openssl ALL
#            DEPENDS ${OPENSSL_LIBCRYPTO_PATH} ${OPENSSL_LIBSSL_PATH} )
#    add_dependencies( lipo_openssl ${OPENSSL_TARGETS} )

    set( OPENSSL_TARGETS_${SDK} ${OPENSSL_TARGETS_${SDK}} PARENT_SCOPE )
    set( OPENSSL_INCLUDES_${SDK} ${OPENSSL_INCLUDES_${SDK}} PARENT_SCOPE )
    set( OPENSSL_THIN_CRYPTO_LIBRARIES_${SDK} ${OPENSSL_THIN_CRYPTO_LIBRARIES_${SDK}} PARENT_SCOPE )
    set( OPENSSL_THIN_SSL_LIBRARIES_${SDK} ${OPENSSL_THIN_SSL_LIBRARIES_${SDK}} PARENT_SCOPE )
endfunction( BuildOpenSSL )

