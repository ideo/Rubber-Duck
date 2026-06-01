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

# Turnkey build — `idf.py -DBAMBU_DUCK_TURNKEY=1 build`. For ducks
# being handed out to people on a relay you operate where the
# ElevenLabs creds are already configured as Fly secrets. Strips the
# captive portal's ElevenLabs key + agent ID fields so end users only
# need to enter WiFi + Bambu credentials. Default (unset) is the
# self-hosted distributable build that exposes those fields so each
# self-hoster brings their own ElevenLabs account.
if(DEFINED BAMBU_DUCK_TURNKEY AND "${BAMBU_DUCK_TURNKEY}" STREQUAL "1")
    target_compile_definitions(${COMPONENT_LIB} PRIVATE BAMBU_DUCK_TURNKEY=1)
    message(STATUS "Building TURNKEY duck (no ElevenLabs creds in captive portal)")
endif()

# Compile-time RELAY_BASE_URL — `idf.py -DRELAY_BASE_URL=wss://your.fly.dev`.
# Bakes the relay URL into the binary so a turnkey or boy-band duck doesn't
# need to be re-onboarded for the URL alone. The runtime NVS-stored URL
# (set by the captive portal) still wins over this at runtime. Pattern
# mirrors BAMBU_DUCK_AGENT_ID above. The chip's RELAY_BASE_URL #ifdef in
# config.h picks this up identically to the turnkey default.
if(DEFINED RELAY_BASE_URL)
    target_compile_definitions(${COMPONENT_LIB} PRIVATE
        "RELAY_BASE_URL=\"${RELAY_BASE_URL}\"")
    message(STATUS "Compile-time RELAY_BASE_URL=${RELAY_BASE_URL}")
endif()

# Boy band build — `idf.py -DBAMBU_DUCK_BOYBAND=1 -DRELAY_BASE_URL=ws://...`.
# A puppeteer-mode flavor for the four boy-band performance ducks: skips
# the wake gate (auto-opens session at boot), skips the notify channel,
# and lets the (still-spawned but never enabled) mic task idle without
# emitting frames upstream. See bambu-boyband-firmware branch and the
# Mac-side Stage app (`boyband/stage/` on feature/boy-band) for the
# other half of the system.
if(DEFINED BAMBU_DUCK_BOYBAND AND "${BAMBU_DUCK_BOYBAND}" STREQUAL "1")
    target_compile_definitions(${COMPONENT_LIB} PRIVATE BAMBU_DUCK_BOYBAND=1)
    message(STATUS "Building BOYBAND duck (puppeteer mode — auto-connect, no wake gate, no notify)")
endif()

# Optional volume override for BOYBAND builds. Boy band has no working
# volume button (no wake gate), so the boot-time volume can't be
# adjusted on stage. Default in audio.c is step 3 ("Very Quiet" 0.05).
# Override at build time: `make flash-boyband ... VOL_STEP=2`
# Steps: 0=Loud(0.75) 1=Normal(0.50) 2=Quiet(0.25) 3=Very Quiet(0.05) 4=Mute
if(DEFINED BAMBU_DUCK_BOYBAND_VOL_STEP)
    target_compile_definitions(${COMPONENT_LIB} PRIVATE
        "BAMBU_DUCK_BOYBAND_VOL_STEP=${BAMBU_DUCK_BOYBAND_VOL_STEP}")
    message(STATUS "BOYBAND boot volume step: ${BAMBU_DUCK_BOYBAND_VOL_STEP}")
endif()
