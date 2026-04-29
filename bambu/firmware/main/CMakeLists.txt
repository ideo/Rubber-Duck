idf_component_register(
    SRCS
        "main.c"
        "wifi.c"
        "agent.c"
        "audio.c"
    INCLUDE_DIRS "."
    REQUIRES
        nvs_flash
        esp_wifi
        esp_event
        esp_netif
        esp_websocket_client
        mbedtls
        driver
        esp_driver_i2s
)

# Allow `idf.py -DBAMBU_DUCK_AGENT_ID=agent_xxx` to inject the agent ID at
# compile time without editing config.h.
if(DEFINED BAMBU_DUCK_AGENT_ID)
    target_compile_definitions(${COMPONENT_LIB} PRIVATE
        "BAMBU_DUCK_AGENT_ID=\"${BAMBU_DUCK_AGENT_ID}\"")
endif()
