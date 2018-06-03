## LibreSSL

If you haven't heard of [LibreSSL](http://www.libressl.org) it is a drop-in replacement for OpenSSL forked from OpenSSL and builds with CMake. Consider using LibreSSL before using OpenSSL with CMake.

It is just this easy:

    target_link_libraries( MyTarget PRIVATE ssl crypto )

## Building OpenSSL for iOS

I've seen a number of solutions to getting OpenSSL built for iOS. I wanted a simple, standalone way of getting an OpenSSL library into an Xcode project without downloading pre-built binaries or adopting a dependency manager like Hunter.

Furthermore, getting CMake to not suck is pretty hard when it comes to building things outside of CMake's control. I had to go to a great amount of trouble to compile OpenSSL only when it updates, and check the servers each time. Generally speaking this means you cannot use anything but `add_custom_command` because the second you use ExternalProject_add or add_custom_target you end up with some undesirable features like always downloading and compiling.

If you want to reduce the number of architectures built you can define the `OPENSSL_TARGET_ARCHITECTURES_${SDK}` variables and list the specific architectures that should be built for each. 


### CMakeLists.txt

    set( OPENSSL_TARGET_ARCHITECTURES_iphoneos arm64 )
    set( OPENSSL_TARGET_ARCHITECTURES_iphonesimulator x86_64 )


### openssl.cmake

You can adjust the version of OpenSSL built and define a SHA1 checksum with these variables

    set( OPENSSL_URL "http://www.openssl.org/source/openssl-1.0.2-latest.tar.gz" )
    set( OPENSSL_SHA1 "" )


### Build OpenSSL Latest

  1. Checkout to openssl/ 
  2. mkdir openssl-build/
  3. cd openssl-build/
  4. cmake -GNinja ../openssl
  5. cmake --build .
