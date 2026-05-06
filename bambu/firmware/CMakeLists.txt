cmake_minimum_required(VERSION 3.16)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)

project(bambu_duck)

# Third-party libopus inside esphome/micro-opus has a few strict-
# warning trips that ESP-IDF's default -Werror catches (e.g.
# 'maybe-uninitialized' in silk/NLSF2A.c). We don't own the source
# so suppress -Werror for THAT component only — our own code keeps
# the strict default.
if(TARGET __idf_esphome__micro-opus)
    target_compile_options(__idf_esphome__micro-opus PRIVATE
        -Wno-error=maybe-uninitialized
        -Wno-error=stringop-overflow
        -Wno-error=array-bounds
    )
endif()
