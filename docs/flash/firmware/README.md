# Same-origin firmware binaries

Auto-committed by the release workflows on every `cc-v*` / `bambu-v*` tag.
The web flasher (`docs/flash/index.html`) fetches these via *relative*
URLs (`firmware/cc-ducky.bin`) so the browser treats them as same-origin
and never hits CORS.

**Don't edit by hand.** These get overwritten by:

- `.github/workflows/cc-firmware-release.yml` → `cc-ducky.bin`, `cc-xiao.bin`
- `.github/workflows/bambu-firmware-release.yml` → `bambu-duck-ducky.bin`, `bambu-duck-xiao.bin`

**Why not just point manifests at GitHub Releases?** Because the
`releases/latest/download/<asset>` URL 302-redirects to
`objects.githubusercontent.com`, and the redirect target doesn't reliably
include `Access-Control-Allow-Origin: *`. ESP Web Tools' cross-origin
`fetch()` then fails with a CORS error mid-flash, after chip detection
already succeeded. Hosting the binaries on the same origin as the page
(github.io) sidesteps the entire CORS path.

The GitHub Release still gets created — that's where command-line users
go (`esptool.py write_flash`) and where release notes live. The
`docs/flash/firmware/` copy exists purely for the browser flasher's
benefit.
