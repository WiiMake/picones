cmake_minimum_required(VERSION 3.13...3.27)

# Update git submodules
find_package(Git QUIET)
if(GIT_FOUND)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/.git")
        message(STATUS "Updating git submodules...")
        execute_process(
            COMMAND ${GIT_EXECUTABLE} submodule update --init --recursive
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            RESULT_VARIABLE _git_submodule_update_result
        )
        if(NOT _git_submodule_update_result EQUAL 0)
            message(WARNING "git submodule update --init --recursive failed (exit ${_git_submodule_update_result})")
        endif()
    endif()
else()
    message(STATUS "Git not found; skipping submodule update")
endif()

# Replace submodule famistudio_ca65.s file with updated version in source
# (it's a pain to get it to build otherwise)
file(COPY ${CMAKE_CURRENT_SOURCE_DIR}/src/famistudio_ca65.s
     DESTINATION ${CMAKE_CURRENT_SOURCE_DIR}/externals/FamiStudio/SoundEngine/
     FILE_PERMISSIONS OWNER_READ OWNER_WRITE GROUP_READ WORLD_READ) 

# Assemble and link BadApple using ca65/ld65
add_custom_target(build_BadApple ALL
    COMMAND ca65 ${CMAKE_CURRENT_SOURCE_DIR}/src/BadApple.asm -o ${CMAKE_CURRENT_SOURCE_DIR}/src/BadApple.o
    COMMAND ld65 -C ${CMAKE_CURRENT_SOURCE_DIR}/src/config.cfg ${CMAKE_CURRENT_SOURCE_DIR}/src/BadApple.o -o ${CMAKE_CURRENT_SOURCE_DIR}/src/BadApple.nes
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR})

# For clangd
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Find Python executable
find_package(Python3 COMPONENTS Interpreter REQUIRED)

# Use the rp2350 processor
set(PICO_BOARD pico2)

# initialize pico-sdk from submodule
include(externals/pico-sdk/pico_sdk_init.cmake)

project(picones)

# initialize the Raspberry Pi Pico SDK
pico_sdk_init()

# Custom target to generate ROM header
add_custom_target(
    generate_rom_header ALL
    COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/generate_rom_header.py
            ${CMAKE_CURRENT_SOURCE_DIR}/rom.nes
            ${CMAKE_CURRENT_BINARY_DIR}/rom.h
    BYPRODUCTS ${CMAKE_CURRENT_BINARY_DIR}/rom.h
    COMMENT "Generating ROM header from rom.nes"
    WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
)

# Create the executable
add_executable(picones
    src/main.c
)

# Make picones depend on the ROM header generation
add_dependencies(picones generate_rom_header)

# Add the build directory to include path so rom_header.h can be found
target_include_directories(picones PRIVATE ${CMAKE_CURRENT_BINARY_DIR})

# Enable printf to USB
pico_enable_stdio_usb(picones 1)

# Generate PIO headers AFTER the executable target exists
pico_generate_pio_header(picones ${CMAKE_CURRENT_LIST_DIR}/src/sm.pio)

# Link libraries
target_link_libraries(picones
    pico_stdlib
    hardware_pio
    hardware_irq
    hardware_gpio
    hardware_clocks
)

# Copy all info from flash to RAM on boot to avoid SPI flash limitations
pico_set_binary_type(picones copy_to_ram)

# create map/bin/hex/uf2 file in addition to ELF
pico_add_extra_outputs(picones)
