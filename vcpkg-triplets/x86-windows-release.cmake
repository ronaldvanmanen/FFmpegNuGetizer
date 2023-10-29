set(VCPKG_TARGET_ARCHITECTURE x86)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_BUILD_TYPE release)

if(${PORT} MATCHES "aom")
    # Note: In order for aom to build on Windows x86 we need to increase
    # virtual memory and limit the concurrency, otherwise the aom build
    # will fail due to the compiler running out of heap space.
    #
    # See the following issues:
    # #28389: https://github.com/microsoft/vcpkg/issues/28389
    # #31823: https://github.com/microsoft/vcpkg/issues/31823
    set(ENV{VCPKG_MAX_CONCURRENCY} "1")
    string(APPEND VCPKG_C_FLAGS " /Zm2000 ")
    string(APPEND VCPKG_CXX_FLAGS " /Zm2000 ")
endif()
