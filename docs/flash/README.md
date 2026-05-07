# Bambu Duck — web flasher

Static page that flashes Bambu Duck firmware from a browser via
[ESP Web Tools](https://esphome.github.io/esp-web-tools/). No
ESP-IDF, no Python, no terminal.

**Live at:** `https://ideo.github.io/Rubber-Duck/flash/` once GitHub
Pages is enabled on the repo (Settings → Pages → source = `main`,
folder = `/docs`).

## How it works

- [`index.html`](index.html) — the page itself. Three variant cards
  (ducky / xiao / turnkey), each wired to its manifest with an
  `<esp-web-install-button>` custom element. The button uses
  WebSerial to talk to the duck over USB.
- [`manifests/`](manifests/) — one JSON file per variant. Each
  references a single merged binary at a "latest release" URL so the
  flasher auto-tracks the most recent firmware build without any code
  change.
- [`../../.github/workflows/bambu-firmware-release.yml`](../../.github/workflows/bambu-firmware-release.yml)
  — GitHub Actions workflow that builds all three variants, runs
  `esptool.py merge_bin` on each (so the manifests can reference a
  single offset-0 binary instead of three separate parts), and
  attaches them to a GitHub Release on tag push.

## Releasing a new firmware

```bash
# Tag the commit you want to ship
git tag bambu-v1.2.3
git push origin bambu-v1.2.3
```

The workflow runs, the binaries appear under
[Releases](https://github.com/ideo/Rubber-Duck/releases), and the
flasher page picks them up automatically (the manifest URL is
`/releases/latest/download/...`).

## Browser support

WebSerial is **Chrome / Edge only** today. Safari and Firefox don't
implement the API; mobile browsers don't expose USB serial at all. The
page warns up front so users on unsupported browsers aren't confused.

## When the user wants a true factory reset

Re-flashing through this page does **not** wipe NVS (WiFi creds,
Bambu binding, settings). Two paths for a clean wipe:

1. **Captive portal** — long-press the duck's back button → Factory
   Reset button on the form. Wipes NVS + tells the relay to delete
   the duck's row.
2. **Command line** — `idf.py -p /dev/cu.usbmodem101 erase-flash`.

The web flasher page links to option 1 in its FAQ section because it
covers most use cases without needing IDF.
