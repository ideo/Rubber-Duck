# Spoken-onboarding phrases (#34) only compile if all the .opus blobs
# have been generated — bambu/firmware/scripts/gen_phrases.py uses
# ElevenLabs TTS to produce them. The build is otherwise the same;
# unset HAS_PHRASES = no phrases.c, no opus_decoder.cpp, no embed.
set(PHRASE_FILES
    "phrases/tap_to_start.opus"
    "phrases/wifi_up.opus"
    "phrases/wifi_connected.opus"
)
set(HAS_PHRASES TRUE)
foreach(p ${PHRASE_FILES})
    if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${p}")
        set(HAS_PHRASES FALSE)
    endif()
endforeach()

set(PHRASES_SRCS "")
set(PHRASES_EMBED "")
if(HAS_PHRASES)
    set(PHRASES_SRCS "phrases.c" "opus_decoder.cpp")
    set(PHRASES_EMBED ${PHRASE_FILES})
    message(STATUS "Onboarding phrases enabled (opus blobs present)")
else()
    message(STATUS "Onboarding phrases disabled — run "
                   "scripts/gen_phrases.py to generate .opus blobs")
endif()

idf_component_register(
    SRCS
        "main.c"
        "wifi.c"
        "provision.c"
        "agent.c"
        "audio.c"
        "servo.c"
        "wake.c"
        "duck_id.c"
        ${PHRASES_SRCS}
    EMBED_FILES ${PHRASES_EMBED}
    INCLUDE_DIRS "."
    REQUIRES
        nvs_flash
        esp_wifi
        esp_event
        esp_netif
        esp_websocket_client
        esp_http_server
        mbedtls
        json
        driver
        esp_driver_i2s
)
if(HAS_PHRASES)
    target_compile_definitions(${COMPONENT_LIB} PRIVATE PHRASES_ENABLED=1)
endif()

# Allow `idf.py -DBAMBU_DUCK_AGENT_ID=agent_xxx` to inject the agent ID at
# compile time without editing config.h.
if(DEFINED BAMBU_DUCK_AGENT_ID)
    target_compile_definitions(${COMPONENT_LIB} PRIVATE
        "BAMBU_DUCK_AGENT_ID=\"${BAMBU_DUCK_AGENT_ID}\"")
endif()

# Hardware variant selector — `DUCK_VARIANT=XIAO idf.py build` (env var)
# or `idf.py -DDUCK_VARIANT=XIAO build` (cmake var) flips the build to the
# standard XIAO Seeed S3 + cobbled mic+amp pin map and split-I2S topology.
# Default (unset) = ducky PCB.
if(NOT DEFINED DUCK_VARIANT AND DEFINED ENV{DUCK_VARIANT})
    set(DUCK_VARIANT $ENV{DUCK_VARIANT})
endif()
if(DEFINED DUCK_VARIANT AND "${DUCK_VARIANT}" STREQUAL "XIAO")
    target_compile_definitions(${COMPONENT_LIB} PRIVATE DUCK_VARIANT_XIAO=1)
    message(STATUS "Building for DUCK_VARIANT=XIAO (standard Seeed XIAO S3)")
endif()
