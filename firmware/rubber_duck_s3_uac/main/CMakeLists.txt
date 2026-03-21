idf_component_register(
    SRCS
        "rubber_duck_s3_uac.cpp"
        "USBAudio.cpp"
        "AudioI2S.cpp"
        "SerialProtocol.cpp"
        "ServoControl.cpp"
        "StatusLED.cpp"
        "Easing.cpp"
    INCLUDE_DIRS "."
    REQUIRES
        espressif__arduino-esp32
        espressif__usb_device_uac
)
