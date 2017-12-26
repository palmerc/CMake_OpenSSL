
function( LipoLibrary INPUT_LIBRARIES OUTPUT_LIBRARY )
    get_filename_component( FILENAME ${OUTPUT_LIBRARY} NAME )
    get_filename_component( OUTPUT_DIRECTORY ${OUTPUT_LIBRARY} DIRECTORY )
    add_custom_command( OUTPUT ${OUTPUT_LIBRARY}
            COMMAND ${CMAKE_COMMAND} -E make_directory ${OUTPUT_DIRECTORY}
            COMMAND lipo -output ${OUTPUT_LIBRARY} -create ${INPUT_LIBRARIES}
            COMMENT "Lipo ${OUTPUT_LIBRARY}"
            COMMAND_EXPAND_LISTS )
endfunction( LipoLibrary )