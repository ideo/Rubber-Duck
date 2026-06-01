# Convenience targets for the hardware variants + build flavors. Each
# combo builds into its own directory so you can flip between them
# without `fullclean`. Source: bambu/docs/MULTI-TENANT-REQ.md and
# issue #49.
#
#   make build-ducky          # default — custom WROOM-1 PCB, full-duplex I2S
#   make build-xiao           # standard XIAO Seeed S3 + cobbled parts
#   make build-turnkey        # ducky PCB + TURNKEY (no ElevenLabs UI)
#   make build-boyband STAGE_URL=ws://<mac>.local:3334
#                             # ducky PCB + BOYBAND puppeteer mode
#   make flash-ducky    PORT=/dev/cu.usbmodem101
#   make flash-xiao     PORT=/dev/cu.usbmodem101
#   make flash-turnkey  PORT=/dev/cu.usbmodem101
#   make flash-boyband  PORT=/dev/cu.usbmodem101 STAGE_URL=ws://<mac>.local:3334
#   make monitor-ducky  PORT=/dev/cu.usbmodem101
#
# Turnkey: hides the ElevenLabs API key + agent ID fields from the
# captive portal. For ducks you flash and hand to people on a relay
# you operate (Fly secrets supply the shared creds). The default
# (build-ducky) keeps those fields exposed so each self-hoster of the
# open-source build brings their own ElevenLabs account.
#
# Boy band: a one-off performance flavor — the duck auto-connects to a
# local Stage app over plain ws://, holds the session forever, and
# ignores tap/button wake events. Requires STAGE_URL to be passed (no
# sensible default since it's per-operator's-Mac). Lives on the
# bambu-boyband-firmware branch.
#
# All targets assume `source ~/esp/esp-idf/export.sh` has been done in
# the calling shell. (Or run `make setup` for a one-shot reminder.)

PORT ?= /dev/cu.usbmodem101

.PHONY: setup build-ducky build-xiao build-turnkey build-boyband \
        flash-ducky flash-xiao flash-turnkey flash-boyband \
        monitor-ducky monitor-xiao monitor-turnkey monitor-boyband \
        clean-ducky clean-xiao clean-turnkey clean-boyband

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

build-turnkey:
	idf.py -B build_turnkey -DBAMBU_DUCK_TURNKEY=1 build

flash-turnkey: build-turnkey
	idf.py -B build_turnkey -p $(PORT) flash

monitor-turnkey:
	idf.py -B build_turnkey -p $(PORT) monitor

clean-turnkey:
	rm -rf build_turnkey

# Boy band — puppeteer-mode flavor. Requires STAGE_URL on the command line:
#   make flash-boyband PORT=/dev/cu.usbmodem101 STAGE_URL=ws://my-mac.local:3334
# The build dir is build_boyband so it doesn't collide with build_turnkey
# even though both pass BAMBU_DUCK_TURNKEY=1 (turnkey strips the captive
# portal's ElevenLabs fields, which boy band also wants).
ifndef STAGE_URL
STAGE_URL_REQUIRED = $(error STAGE_URL is required, e.g. STAGE_URL=ws://my-mac.local:3334)
endif

build-boyband:
	$(if $(STAGE_URL),,$(STAGE_URL_REQUIRED))
	idf.py -B build_boyband \
		-DBAMBU_DUCK_TURNKEY=1 \
		-DBAMBU_DUCK_BOYBAND=1 \
		-DRELAY_BASE_URL=$(STAGE_URL) \
		build

flash-boyband: build-boyband
	idf.py -B build_boyband -p $(PORT) flash

monitor-boyband:
	idf.py -B build_boyband -p $(PORT) monitor

clean-boyband:
	rm -rf build_boyband
