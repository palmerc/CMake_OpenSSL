function( Lipo )
    set( options )
    set( oneValueArgs OUTPUT )
    set( multiValueArgs INPUTS )
    cmake_parse_arguments( Lipo "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN} )

    if( NOT DEFINED Lipo_INPUTS )
        message( "Lipo inputs not defined - skipping" )
        return()
    endif()

    if( NOT DEFINED Lipo_OUTPUT )
        message( "Lipo output not defined - skipping" )
        return()
    endif()

    get_filename_component( FILENAME ${Lipo_OUTPUT} NAME )
    get_filename_component( OUTPUT_DIR ${Lipo_OUTPUT} DIRECTORY )
    add_custom_command( OUTPUT ${Lipo_OUTPUT}
            DEPENDS ${Lipo_INPUTS}
            COMMAND ${CMAKE_COMMAND} -E make_directory ${OUTPUT_DIR}
            COMMAND lipo -output ${Lipo_OUTPUT} -create ${Lipo_INPUTS}
            COMMENT "Lipo ${Lipo_OUTPUT}"
            COMMAND_EXPAND_LISTS )
endfunction( Lipo )
