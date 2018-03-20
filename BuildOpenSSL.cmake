set( OPENSSL_SCRIPTS_DIR ${CMAKE_SOURCE_DIR} )
set( OPENSSL_TARBALL openssl-1.0.2n.tar.gz )
set( OPENSSL_URL "http://www.openssl.org/source/${OPENSSL_TARBALL}" )
set( OPENSSL_SHA1 "0ca2957869206de193603eca6d89f532f61680b1" )

if( NOT OPENSSL_STANDARD_ARCHITECTURES_iphoneos )
    set( OPENSSL_STANDARD_ARCHITECTURES_iphoneos armv7 armv7s arm64 )
endif()
if( NOT OPENSSL_STANDARD_ARCHITECTURES_iphonesimulator )
    set( OPENSSL_STANDARD_ARCHITECTURES_iphonesimulator i386 x86_64 )
endif()

set( OPENSSL_STANDARD_OPTIONS
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

function( BuildOpenSSL )
    set( options FRAMEWORK DYLIB BITCODE )
    set( oneValueArgs SDK SDK_PATH INSTALL_DIR )
    set( multiValueArgs TARGET_ARCHITECTURES OPTIONS )
    cmake_parse_arguments( BuildOpenSSL "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )

    set( SDK ${BuildOpenSSL_SDK} )
    set( XCODE_SDK_PATH ${BuildOpenSSL_SDK_PATH} )
    set( TARGET_ARCHITECTURES ${BuildOpenSSL_TARGET_ARCHITECTURES} )
    set( INSTALL_DIR ${BuildOpenSSL_INSTALL_DIR} )
    set( COMMON_OPTIONS ${BuildOpenSSL_OPTIONS} )

    if( BuildOpenSSL_FRAMEWORK )
        set( GENERATE_FRAMEWORK true )
    endif()
    if( BuildOpenSSL_DYLIB )
        set( BUILD_SHARED true )
    endif()
    if( BuildOpenSSL_BITCODE )
        set( BITCODE_ENABLED true )
    endif()

    set( OPENSSL_LIBCRYPTO_STATIC ${CMAKE_STATIC_LIBRARY_PREFIX}crypto${CMAKE_STATIC_LIBRARY_SUFFIX} )
    set( OPENSSL_LIBSSL_STATIC ${CMAKE_STATIC_LIBRARY_PREFIX}ssl${CMAKE_STATIC_LIBRARY_SUFFIX} )
    if( BUILD_SHARED )
        message( STATUS "Build shared library" )
        set( OPENSSL_LIBCRYPTO_SHARED ${CMAKE_SHARED_LIBRARY_PREFIX}crypto${CMAKE_SHARED_LIBRARY_SUFFIX} )
        set( OPENSSL_LIBSSL_SHARED ${CMAKE_SHARED_LIBRARY_PREFIX}ssl${CMAKE_SHARED_LIBRARY_SUFFIX} )
    endif()

    set( OPENSSL_THIN_CRYPTO_STATIC_LIBS_${SDK} )
    set( OPENSSL_THIN_SSL_STATIC_LIBS_${SDK} )
    set( OPENSSL_THIN_CRYPTO_SHARED_LIBS_${SDK} )
    set( OPENSSL_THIN_SSL_SHARED_LIBS_${SDK} )
    foreach( TARGET_ARCHITECTURE ${TARGET_ARCHITECTURES} )
        set( OPENSSL_CFLAGS )
        list( APPEND OPENSSL_CFLAGS -mios-version-min=9.0 )
        list( APPEND OPENSSL_CFLAGS -arch ${TARGET_ARCHITECTURE} )

        set( OPENSSL_TARGET openssl_${SDK}_${TARGET_ARCHITECTURE} )
        set( TARGET_INSTALL_DIR ${INSTALL_DIR}/${TARGET_ARCHITECTURE} )

        set( OPENSSL_OPTIONS_${TARGET_ARCHITECTURE} ${COMMON_OPTIONS} )
        if( TARGET_ARCHITECTURE STREQUAL x86_64 )
            list( APPEND OPENSSL_OPTIONS_${TARGET_ARCHITECTURE} no-asm )
        endif()

        ## CFLAGS Check
        string( REPLACE ";" " " CFLAGS_STRING "${OPENSSL_CFLAGS}" )
        set( CFLAGS_FILE_PATH ${TARGET_INSTALL_DIR}/openssl-cflags )
        file( WRITE ${CFLAGS_FILE_PATH} ${CFLAGS_STRING} )

        ## Options Check
        string( REPLACE ";" " " OPTIONS_STRING "${OPENSSL_OPTIONS_${TARGET_ARCHITECTURE}}" )
        set( OPTIONS_FILE_PATH ${TARGET_INSTALL_DIR}/openssl-options )
        file( WRITE ${OPTIONS_FILE_PATH} ${OPTIONS_STRING} )

        set( OPENSSL_SOURCE_DIR ${CMAKE_CURRENT_BINARY_DIR}/build/Source/${OPENSSL_TARGET} )
        set( OPENSSL_LIBCRYPTO_STATIC_${SDK} ${TARGET_INSTALL_DIR}/lib/${OPENSSL_LIBCRYPTO_STATIC} )
        set( OPENSSL_LIBSSL_STATIC_${SDK} ${TARGET_INSTALL_DIR}/lib/${OPENSSL_LIBSSL_STATIC} )
        if( BUILD_SHARED )
            set( OPENSSL_LIBCRYPTO_SHARED_${SDK} ${TARGET_INSTALL_DIR}/lib/${OPENSSL_LIBCRYPTO_SHARED} )
            set( OPENSSL_LIBSSL_SHARED_${SDK} ${TARGET_INSTALL_DIR}/lib/${OPENSSL_LIBSSL_SHARED} )
        endif()

        execute_process( COMMAND ${CMAKE_COMMAND} -E make_directory ${OPENSSL_SOURCE_DIR} )

        ### This is key
        ### A dependency that is never satisfied drives the next command to always check if OpenSSL is up-to-date
        ### without needing add_custom_target. It is marked symbolic so it doesn't add restat=1 to build.ninja
        set( CMAKE_RUN ${OPENSSL_SOURCE_DIR}/cmake_run.txt )
        add_custom_command( OUTPUT ${CMAKE_RUN} COMMAND true
                COMMENT "Starting OpenSSL build for ${OPENSSL_TARGET}" )
        set_source_files_properties( ${CMAKE_RUN} PROPERTIES SYMBOLIC true )

        set( OPENSSL_TARBALL_PATH ${OPENSSL_SOURCE_DIR}/${OPENSSL_TARBALL} )

        if( OVERRIDE_TIMESTAMP_CHECK )
            set( OVERRIDE_TIMESTAMP test -s ${OPENSSL_TARBALL} || )
        endif()

        ### Download the tarball if it has changed using the current copy for the timestamp
        add_custom_command( OUTPUT ${OPENSSL_TARBALL_PATH}
                WORKING_DIRECTORY ${OPENSSL_SOURCE_DIR}
                DEPENDS ${CMAKE_RUN}
                COMMAND ${OVERRIDE_TIMESTAMP} curl --time-cond ${OPENSSL_TARBALL_PATH} -o ${OPENSSL_TARBALL} --silent --location ${OPENSSL_URL}
                COMMENT "Downloading OpenSSL source, if needed, for ${OPENSSL_TARGET}" )

        ### Untar and build
        add_custom_command( OUTPUT
                ${OPENSSL_LIBCRYPTO_STATIC_${SDK}}
                ${OPENSSL_LIBSSL_STATIC_${SDK}}
                ${OPENSSL_LIBCRYPTO_SHARED_${SDK}}
                ${OPENSSL_LIBSSL_SHARED_${SDK}}
            DEPENDS ${OPENSSL_TARBALL_PATH}
            WORKING_DIRECTORY ${OPENSSL_SOURCE_DIR}
            COMMAND tar xfz ${OPENSSL_TARBALL} --strip-components 1 -C ${OPENSSL_SOURCE_DIR}
            COMMAND ${OPENSSL_SCRIPTS_DIR}/openssl-compile.sh
                ${SDK}
                ${TARGET_ARCHITECTURE}
                ${OPENSSL_SOURCE_DIR}
                ${TARGET_INSTALL_DIR}
                ${BUILD_SHARED}
                ${BITCODE_ENABLED}
                ${CFLAGS_FILE_PATH}
                ${OPTIONS_FILE_PATH} )

        list( APPEND OPENSSL_INCLUDES_${SDK} ${TARGET_INSTALL_DIR}/include )
        list( APPEND OPENSSL_THIN_CRYPTO_STATIC_LIBS_${SDK} ${OPENSSL_LIBCRYPTO_STATIC_${SDK}} )
        list( APPEND OPENSSL_THIN_SSL_STATIC_LIBS_${SDK} ${OPENSSL_LIBSSL_STATIC_${SDK}} )
        if( BUILD_SHARED )
            list( APPEND OPENSSL_THIN_CRYPTO_SHARED_LIBS_${SDK} ${OPENSSL_LIBCRYPTO_SHARED_${SDK}} )
            list( APPEND OPENSSL_THIN_SSL_SHARED_LIBS_${SDK} ${OPENSSL_LIBSSL_SHARED_${SDK}} )
        endif()
    endforeach( TARGET_ARCHITECTURE )

    set( INSTALL_DIR_LIB ${INSTALL_DIR}/lib )
    set( INSTALL_DIR_INCLUDE ${INSTALL_DIR}/include )

    set( INSTALL_PATH_CRYPTO_STATIC ${INSTALL_DIR_LIB}/${OPENSSL_LIBCRYPTO_STATIC} )
    set( INSTALL_PATH_SSL_STATIC ${INSTALL_DIR_LIB}/${OPENSSL_LIBSSL_STATIC} )
    Lipo( INPUTS ${OPENSSL_THIN_CRYPTO_STATIC_LIBS_${SDK}} OUTPUT ${INSTALL_PATH_CRYPTO_STATIC} )
    Lipo( INPUTS ${OPENSSL_THIN_SSL_STATIC_LIBS_${SDK}} OUTPUT ${INSTALL_PATH_SSL_STATIC} )

    if( BUILD_SHARED )
        set( INSTALL_PATH_CRYPTO_SHARED ${INSTALL_DIR_LIB}/${OPENSSL_LIBCRYPTO_SHARED} )
        set( INSTALL_PATH_SSL_SHARED ${INSTALL_DIR_LIB}/${OPENSSL_LIBSSL_SHARED} )
        Lipo( INPUTS ${OPENSSL_THIN_CRYPTO_SHARED_LIBS_${SDK}} OUTPUT ${INSTALL_PATH_CRYPTO_SHARED} )
        Lipo( INPUTS ${OPENSSL_THIN_SSL_SHARED_LIBS_${SDK}} OUTPUT ${INSTALL_PATH_SSL_SHARED} )
    endif()

    list( GET OPENSSL_INCLUDES_${SDK} 0 OPENSSL_INCLUDES_DIR )
    set( OPENSSL_INCLUDES_STAMP_${SDK} ${INSTALL_DIR}/openssl_include.stamp)
    add_custom_command( OUTPUT ${OPENSSL_INCLUDES_STAMP_${SDK}}
            DEPENDS
                ${INSTALL_PATH_CRYPTO_STATIC}
                ${INSTALL_PATH_SSL_STATIC}
                ${INSTALL_PATH_CRYPTO_SHARED}
                ${INSTALL_PATH_SSL_SHARED}
            COMMAND ${CMAKE_COMMAND} -E copy_directory ${OPENSSL_INCLUDES_DIR} ${INSTALL_DIR_INCLUDE}
            COMMAND touch ${OPENSSL_INCLUDES_STAMP_${SDK}}
            COMMENT "Copying OpenSSL ${OPENSSL_INCLUDES_DIR} to ${INSTALL_DIR_INCLUDE}" )

    set( OPENSSL_INCLUDES_STAMP_${SDK} ${OPENSSL_INCLUDES_STAMP_${SDK}} PARENT_SCOPE )
    set( OPENSSL_INCLUDES_${SDK} ${INSTALL_DIR_INCLUDE} PARENT_SCOPE )
    set( OPENSSL_THIN_CRYPTO_STATIC_LIB_${SDK} ${INSTALL_PATH_CRYPTO_STATIC} PARENT_SCOPE )
    set( OPENSSL_THIN_SSL_STATIC_LIB_${SDK} ${INSTALL_PATH_SSL_STATIC} PARENT_SCOPE )
    if( BUILD_SHARED )
        set( OPENSSL_THIN_CRYPTO_SHARED_LIB_${SDK} ${INSTALL_PATH_CRYPTO_SHARED} PARENT_SCOPE )
        set( OPENSSL_THIN_SSL_SHARED_LIB_${SDK} ${INSTALL_PATH_SSL_SHARED} PARENT_SCOPE )
    endif()
endfunction( BuildOpenSSL )

