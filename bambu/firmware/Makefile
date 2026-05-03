# Convenience targets for the two hardware variants. Each variant builds
# into its own directory so you can flip back and forth without
# `fullclean` between switches. Source: bambu/docs/MULTI-TENANT-REQ.md
# and issue #49.
#
#   make build-ducky          # default — custom WROOM-1 PCB, full-duplex I2S
#   make build-xiao           # standard XIAO Seeed S3 + cobbled parts
#   make flash-ducky PORT=/dev/cu.usbmodem101
#   make flash-xiao  PORT=/dev/cu.usbmodem101
#   make monitor-ducky PORT=/dev/cu.usbmodem101
#
# All targets assume `source ~/esp/esp-idf/export.sh` has been done in
# the calling shell. (Or run `make setup` for a one-shot reminder.)

PORT ?= /dev/cu.usbmodem101

.PHONY: setup build-ducky build-xiao flash-ducky flash-xiao \
        monitor-ducky monitor-xiao clean-ducky clean-xiao

setup:
	@echo "Run: source ~/esp/esp-idf/export.sh"

build-ducky:
	idf.py -B build_ducky build

build-xiao:
	DUCK_VARIANT=XIAO idf.py -B build_xiao build

flash-ducky: build-ducky
	idf.py -B build_ducky -p $(PORT) flash

flash-xiao: build-xiao
	DUCK_VARIANT=XIAO idf.py -B build_xiao -p $(PORT) flash

monitor-ducky:
	idf.py -B build_ducky -p $(PORT) monitor

monitor-xiao:
	idf.py -B build_xiao -p $(PORT) monitor

clean-ducky:
	rm -rf build_ducky

clean-xiao:
	rm -rf build_xiao
